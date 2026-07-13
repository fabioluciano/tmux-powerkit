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
