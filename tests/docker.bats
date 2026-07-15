#!/usr/bin/env bats

load './helpers/test_helper.bash'

setup() {
    setup_test_root
    runtime_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$runtime_dir"
    export PATH="$runtime_dir:$PATH"
}

@test "docker plugin reports unhealthy containers from a Docker-compatible runtime" {
    cat >"$runtime_dir/docker" <<'EOF'
#!/usr/bin/env bash
case "$1:$2" in
info:) exit 0 ;;
ps:-q) printf 'one\ntwo\n' ;;
ps:-aq) printf 'one\ntwo\nthree\n' ;;
ps:--filter) printf 'two\n' ;;
esac
EOF
    chmod +x "$runtime_dir/docker"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        get_option() {
            case "$1" in runtime) printf docker ;; show_stopped) printf true ;; show_when_empty) printf false ;; *) printf "" ;; esac
        }
        _set_plugin_context docker
        plugin_collect && printf "%s|%s|%s" "$(plugin_data_get running)" "$(plugin_data_get stopped)" "$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "2|1|error"
}

@test "docker plugin is inactive when no runtime is available" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        get_option() { case "$1" in runtime) printf docker ;; show_when_empty) printf false ;; *) printf "" ;; esac; }
        has_cmd() { return 1; }
        _set_plugin_context docker
        plugin_collect
        plugin_get_state
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "inactive"
}

@test "docker plugin detects podman runtime when docker is absent" {
    cat >"$runtime_dir/podman" <<'EOF'
#!/usr/bin/env bash
case "$1:$2" in
info:) exit 0 ;;
ps:-q) printf 'c1\nc2\n' ;;
ps:-aq) printf 'c1\nc2\n' ;;
ps:--filter) printf '' ;;
esac
EOF
    chmod +x "$runtime_dir/podman"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        get_option() { case "$1" in runtime) printf auto ;; show_stopped) printf false ;; show_when_empty) printf false ;; *) printf "" ;; esac; }
        has_cmd() { [[ "$1" == "podman" ]] && return 0; [[ "$1" == "docker" ]] && return 1; return 1; }
        _set_plugin_context docker
        plugin_collect
        printf "%s|%s|%s|%s|%s" \
            "$(plugin_data_get runtime)" \
            "$(plugin_data_get running)" \
            "$(plugin_data_get stopped)" \
            "$(plugin_data_get unhealthy)" \
            "$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "podman|2|0|0|good"
}

@test "docker plugin: show_stopped=true shows stopped containers" {
    cat >"$runtime_dir/docker" <<'EOF'
#!/usr/bin/env bash
case "$1:$2" in
info:) exit 0 ;;
ps:-q) printf 'c1\n' ;;
ps:-aq) printf 'c1\nc2\nc3\nc4\n' ;;
ps:--filter) printf '' ;;
esac
EOF
    chmod +x "$runtime_dir/docker"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        get_option() { case "$1" in runtime) printf docker ;; show_stopped) printf true ;; show_when_empty) printf false ;; *) printf "" ;; esac; }
        _set_plugin_context docker
        plugin_collect
        printf "running=%s stopped=%s health=%s" \
            "$(plugin_data_get running)" \
            "$(plugin_data_get stopped)" \
            "$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "running=1"
    assert_output --partial "stopped=3"
    assert_output --partial "health=warning"
}

@test "docker plugin: show_when_empty=false hides when no containers" {
    cat >"$runtime_dir/docker" <<'EOF'
#!/usr/bin/env bash
case "$1:$2" in
info:) exit 0 ;;
ps:-q) printf '' ;;
ps:-aq) printf '' ;;
ps:--filter) printf '' ;;
esac
EOF
    chmod +x "$runtime_dir/docker"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        get_option() { case "$1" in runtime) printf docker ;; show_stopped) printf false ;; show_when_empty) printf false ;; *) printf "" ;; esac; }
        _set_plugin_context docker
        plugin_collect
        plugin_get_state
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "inactive"
}

@test "docker plugin: show_when_empty=true shows even when no containers" {
    cat >"$runtime_dir/docker" <<'EOF'
#!/usr/bin/env bash
case "$1:$2" in
info:) exit 0 ;;
ps:-q) printf '' ;;
ps:-aq) printf '' ;;
ps:--filter) printf '' ;;
esac
EOF
    chmod +x "$runtime_dir/docker"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        get_option() { case "$1" in runtime) printf docker ;; show_stopped) printf false ;; show_when_empty) printf true ;; *) printf "" ;; esac; }
        _set_plugin_context docker
        plugin_collect
        printf "state=%s running=%s" "$(plugin_get_state)" "$(plugin_data_get running)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "running=0"
}

@test "docker plugin: health=good when all containers running" {
    cat >"$runtime_dir/docker" <<'EOF'
#!/usr/bin/env bash
case "$1:$2" in
info:) exit 0 ;;
ps:-q) printf 'c1\nc2\nc3\n' ;;
ps:-aq) printf 'c1\nc2\nc3\n' ;;
ps:--filter) printf '' ;;
esac
EOF
    chmod +x "$runtime_dir/docker"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        get_option() { case "$1" in runtime) printf docker ;; show_stopped) printf false ;; show_when_empty) printf false ;; *) printf "" ;; esac; }
        _set_plugin_context docker
        plugin_collect
        printf "health=%s running=%s stopped=%s unhealthy=%s" \
            "$(plugin_get_health)" \
            "$(plugin_data_get running)" \
            "$(plugin_data_get stopped)" \
            "$(plugin_data_get unhealthy)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=good"
    assert_output --partial "running=3"
    assert_output --partial "stopped=0"
    assert_output --partial "unhealthy=0"
}

@test "docker plugin: render shows stopped count when show_stopped=true" {
    cat >"$runtime_dir/docker" <<'EOF'
#!/usr/bin/env bash
case "$1:$2" in
info:) exit 0 ;;
ps:-q) printf 'c1\nc2\n' ;;
ps:-aq) printf 'c1\nc2\nc3\n' ;;
ps:--filter) printf '' ;;
esac
EOF
    chmod +x "$runtime_dir/docker"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        get_option() { case "$1" in runtime) printf docker ;; show_stopped) printf true ;; show_when_empty) printf false ;; *) printf "" ;; esac; }
        _set_plugin_context docker
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "2 running, 1 stopped"
}

@test "docker plugin: show_stopped=false only shows running count" {
    cat >"$runtime_dir/docker" <<'EOF'
#!/usr/bin/env bash
case "$1:$2" in
info:) exit 0 ;;
ps:-q) printf 'c1\nc2\n' ;;
ps:-aq) printf 'c1\nc2\nc3\n' ;;
ps:--filter) printf '' ;;
esac
EOF
    chmod +x "$runtime_dir/docker"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        get_option() { case "$1" in runtime) printf docker ;; show_stopped) printf false ;; show_when_empty) printf false ;; *) printf "" ;; esac; }
        _set_plugin_context docker
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "2 running"
}

@test "docker plugin: context returns runtime name" {
    cat >"$runtime_dir/docker" <<'EOF'
#!/usr/bin/env bash
case "$1:$2" in
info:) exit 0 ;;
ps:-q) printf 'c1\n' ;;
ps:-aq) printf 'c1\n' ;;
ps:--filter) printf '' ;;
esac
EOF
    chmod +x "$runtime_dir/docker"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        get_option() { case "$1" in runtime) printf auto ;; *) printf "" ;; esac; }
        _set_plugin_context docker
        plugin_collect
        printf "context=%s runtime=%s" "$(plugin_get_context)" "$(plugin_data_get runtime)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "context=docker"
}

@test "docker plugin: contract functions" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/docker.sh"
        printf "content_type=%s presence=%s" \
            "$(plugin_get_content_type)" \
            "$(plugin_get_presence)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "content_type=dynamic"
    assert_output --partial "presence=conditional"
}
