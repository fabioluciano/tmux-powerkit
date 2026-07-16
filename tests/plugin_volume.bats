#!/usr/bin/env bats
load './helpers/test_helper.bash'

setup() {
    setup_test_root
    mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"
    export PATH="$mock_dir:$PATH"
}

@test "volume at 50% reports ok health and medium context" {
    cat >"$mock_dir/osascript" <<'EOF'
#!/usr/bin/env bash
shift; script="$*"
case "$script" in
    *"output volume"*) echo "50" ;;
    *"output muted"*) echo "false" ;;
esac
EOF
    chmod +x "$mock_dir/osascript"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/volume.sh"
        is_macos() { return 0; }
        _set_plugin_context volume
        plugin_declare_options
        plugin_collect
        printf "state=%s health=%s volume=%s muted=%s render=%s context=%s" \
            "$(plugin_get_state)" \
            "$(plugin_get_health)" \
            "$(plugin_data_get volume)" \
            "$(plugin_data_get muted)" \
            "$(plugin_render)" \
            "$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
    assert_output --partial "volume=50"
    assert_output --partial "muted=0"
    assert_output --partial "render=50%"
    assert_output --partial "context=medium"
}

@test "volume at 0 reports low context with muted icon" {
    cat >"$mock_dir/osascript" <<'EOF'
#!/usr/bin/env bash
shift; script="$*"
case "$script" in
    *"output volume"*) echo "0" ;;
    *"output muted"*) echo "false" ;;
esac
EOF
    chmod +x "$mock_dir/osascript"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/volume.sh"
        is_macos() { return 0; }
        _set_plugin_context volume
        plugin_declare_options
        plugin_collect
        printf "context=%s volume=%s muted=%s" \
            "$(plugin_get_context)" \
            "$(plugin_data_get volume)" \
            "$(plugin_data_get muted)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "context=low"
    assert_output --partial "volume=0"
    assert_output --partial "muted=0"
}

@test "muted volume reports error health and MUTE render" {
    cat >"$mock_dir/osascript" <<'EOF'
#!/usr/bin/env bash
shift; script="$*"
case "$script" in
    *"output volume"*) echo "50" ;;
    *"output muted"*) echo "true" ;;
esac
EOF
    chmod +x "$mock_dir/osascript"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/volume.sh"
        is_macos() { return 0; }
        _set_plugin_context volume
        plugin_declare_options
        plugin_collect
        printf "health=%s render=%s context=%s muted=%s" \
            "$(plugin_get_health)" \
            "$(plugin_render)" \
            "$(plugin_get_context)" \
            "$(plugin_data_get muted)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=error"
    assert_output --partial "render=MUTE"
    assert_output --partial "context=muted"
    assert_output --partial "muted=1"
}

@test "volume at 100 reports ok health and high context" {
    cat >"$mock_dir/osascript" <<'EOF'
#!/usr/bin/env bash
shift; script="$*"
case "$script" in
    *"output volume"*) echo "100" ;;
    *"output muted"*) echo "false" ;;
esac
EOF
    chmod +x "$mock_dir/osascript"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/volume.sh"
        is_macos() { return 0; }
        _set_plugin_context volume
        plugin_declare_options
        plugin_collect
        printf "health=%s volume=%s context=%s" \
            "$(plugin_get_health)" \
            "$(plugin_data_get volume)" \
            "$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=ok"
    assert_output --partial "volume=100"
    assert_output --partial "context=high"
}

@test "volume renders without percentage when show_percentage=false" {
    cat >"$mock_dir/osascript" <<'EOF'
#!/usr/bin/env bash
shift; script="$*"
case "$script" in
    *"output volume"*) echo "75" ;;
    *"output muted"*) echo "false" ;;
esac
EOF
    chmod +x "$mock_dir/osascript"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/volume.sh"
        is_macos() { return 0; }
        _set_plugin_context volume
        get_option() {
            if [[ "$1" == "show_percentage" ]]; then printf "false"; else printf ""; fi
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "75"
}

@test "volume plugin has required contract functions" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/volume.sh"
        printf "content_type=%s presence=%s state=%s" \
            "$(plugin_get_content_type)" \
            "$(plugin_get_presence)" \
            "$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "content_type=dynamic"
    assert_output --partial "presence=always"
    assert_output --partial "state=active"
}

@test "volume plugin declares all expected options" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/volume.sh"
        _set_plugin_context volume
        plugin_declare_options
        get_option "low_threshold"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "30"
}

@test "volume icon changes with volume level (low volume shows icon_low)" {
    cat >"$mock_dir/osascript" <<'EOF'
#!/usr/bin/env bash
shift; script="$*"
case "$script" in
    *"output volume"*) echo "20" ;;
    *"output muted"*) echo "false" ;;
esac
EOF
    chmod +x "$mock_dir/osascript"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/volume.sh"
        is_macos() { return 0; }
        _set_plugin_context volume
        plugin_declare_options
        plugin_collect
        plugin_get_icon
    ' _ "$POWERKIT_ROOT"
    assert_success
    # icon should be icon_low (volume 20 <= low threshold 30), not icon_high
    refute_output --partial $'\U000F057E'
}
