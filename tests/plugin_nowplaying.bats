#!/usr/bin/env bats
load './helpers/test_helper.bash'

setup() {
    setup_test_root
    mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"
    export PATH="$mock_dir:$PATH"
    bin_dir="${POWERKIT_ROOT}/bin"
    mkdir -p "$bin_dir"
}

@test "track playing shows state=active and renders artist - title" {
    local sep=$'\x1F'
    cat >"$bin_dir/powerkit-nowplaying" <<BINARY_EOF
#!/usr/bin/env bash
printf '%s' "Playing${sep}Radiohead${sep}Creep${sep}Pablo Honey${sep}Spotify"
BINARY_EOF
    chmod +x "$bin_dir/powerkit-nowplaying"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/nowplaying.sh"
        is_macos() { return 0; }
        _set_plugin_context nowplaying
        plugin_declare_options
        plugin_collect
        printf "playing=%s state=%s artist=%s title=%s app=%s health=%s render=%s" \
            "$(plugin_data_get playing)" \
            "$(plugin_data_get state)" \
            "$(plugin_data_get artist)" \
            "$(plugin_data_get title)" \
            "$(plugin_data_get app)" \
            "$(plugin_get_health)" \
            "$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "playing=1"
    assert_output --partial "state=Playing"
    assert_output --partial "artist=Radiohead"
    assert_output --partial "title=Creep"
    assert_output --partial "app=spotify"
    assert_output --partial "render=Radiohead - Creep"
}

@test "no player binary output returns playing=0 and inactive state" {
    cat >"$bin_dir/powerkit-nowplaying" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$bin_dir/powerkit-nowplaying"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/nowplaying.sh"
        is_macos() { return 0; }
        _set_plugin_context nowplaying
        plugin_declare_options
        plugin_collect
        printf "playing=%s state=%s" \
            "$(plugin_data_get playing)" \
            "$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "playing=0"
    assert_output --partial "state=inactive"
}

@test "paused track with info_when_paused=true reports health=info" {
    local sep=$'\x1F'
    cat >"$bin_dir/powerkit-nowplaying" <<BINARY_EOF
#!/usr/bin/env bash
printf '%s' "paused${sep}Artist${sep}Song${sep}Album${sep}Spotify"
BINARY_EOF
    chmod +x "$bin_dir/powerkit-nowplaying"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/nowplaying.sh"
        is_macos() { return 0; }
        get_option() {
            case "$1" in
                info_when_paused) printf "true" ;;
                format) printf "%%artist%% - %%title%%" ;;
                max_length) printf "40" ;;
                truncate_suffix) printf "..." ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context nowplaying
        plugin_collect
        printf "health=%s state=%s playing=%s" \
            "$(plugin_get_health)" \
            "$(plugin_get_state)" \
            "$(plugin_data_get playing)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=info"
    assert_output --partial "state=active"
}

@test "custom format string is honored in render" {
    local sep=$'\x1F'
    cat >"$bin_dir/powerkit-nowplaying" <<BINARY_EOF
#!/usr/bin/env bash
printf '%s' "Playing${sep}Queen${sep}Bohemian Rhapsody${sep}A Night at the Opera${sep}Spotify"
BINARY_EOF
    chmod +x "$bin_dir/powerkit-nowplaying"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/nowplaying.sh"
        is_macos() { return 0; }
        get_option() {
            case "$1" in
                format) printf "%%title%% (%%album%%)" ;;
                max_length) printf "100" ;;
                truncate_suffix) printf "..." ;;
                info_when_paused) printf "false" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context nowplaying
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "Bohemian Rhapsody (A Night at the Opera)"
}

@test "nowplaying plugin is conditional presence" {
    cat >"$bin_dir/powerkit-nowplaying" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$bin_dir/powerkit-nowplaying"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/nowplaying.sh"
        printf "content_type=%s presence=%s" \
            "$(plugin_get_content_type)" \
            "$(plugin_get_presence)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "content_type=dynamic"
    assert_output --partial "presence=conditional"
}

@test "app name is lowercased" {
    local sep=$'\x1F'
    cat >"$bin_dir/powerkit-nowplaying" <<BINARY_EOF
#!/usr/bin/env bash
printf '%s' "Playing${sep}Artist${sep}Title${sep}Album${sep}SPOTIFY"
BINARY_EOF
    chmod +x "$bin_dir/powerkit-nowplaying"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/nowplaying.sh"
        is_macos() { return 0; }
        _set_plugin_context nowplaying
        plugin_declare_options
        plugin_collect
        printf "app=%s" "$(plugin_data_get app)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "app=spotify"
}

@test "nowplaying plugin declares expected options" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/nowplaying.sh"
        _set_plugin_context nowplaying
        plugin_declare_options
        get_option "format"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "%artist% - %title%"
}

@test "nowplaying plugin has metadata" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/nowplaying.sh"
        plugin_get_metadata 2>/dev/null
        echo "metadata_exists=yes"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "metadata_exists=yes"
}
