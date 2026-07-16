#!/usr/bin/env bats
load './helpers/test_helper.bash'

setup() {
    setup_test_root
    mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"
    export PATH="$mock_dir:$PATH"
}

@test "loadavg format=1 shows only 1-minute load" {
    cat >"$mock_dir/sysctl" <<'SYSCTL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"hw.ncpu"*) echo "8" ;;
    *"vm.loadavg"*) echo "{ 0.80 0.60 0.50 }" ;;
esac
SYSCTL_EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/loadavg.sh"
        is_linux() { return 1; }
        is_macos() { return 0; }
        get_option() {
            case "$1" in
                format) printf "1" ;;
                separator) printf " | " ;;
                warning_threshold_multiplier) printf "1" ;;
                critical_threshold_multiplier) printf "4" ;;
                icon) printf "LA" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context loadavg
        plugin_declare_options
        plugin_collect
        printf "result=%s state=%s" \
            "$(plugin_data_get result)" \
            "$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "result=0.80"
    assert_output --partial "state=active"
}

@test "loadavg format=5 shows only 5-minute load" {
    cat >"$mock_dir/sysctl" <<'SYSCTL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"hw.ncpu"*) echo "4" ;;
    *"vm.loadavg"*) echo "{ 0.10 0.80 0.60 }" ;;
esac
SYSCTL_EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/loadavg.sh"
        is_linux() { return 1; }
        is_macos() { return 0; }
        get_option() {
            case "$1" in
                format) printf "5" ;;
                separator) printf " | " ;;
                warning_threshold_multiplier) printf "1" ;;
                critical_threshold_multiplier) printf "4" ;;
                icon) printf "LA" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context loadavg
        plugin_declare_options
        plugin_collect
        printf "result=%s" "$(plugin_data_get result)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "result=0.80"
}

@test "loadavg format=all shows all 3 values" {
    cat >"$mock_dir/sysctl" <<'SYSCTL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"hw.ncpu"*) echo "8" ;;
    *"vm.loadavg"*) echo "{ 1.20 0.90 0.70 }" ;;
esac
SYSCTL_EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/loadavg.sh"
        is_linux() { return 1; }
        is_macos() { return 0; }
        get_option() {
            case "$1" in
                format) printf "all" ;;
                separator) printf " | " ;;
                warning_threshold_multiplier) printf "1" ;;
                critical_threshold_multiplier) printf "4" ;;
                icon) printf "LA" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context loadavg
        plugin_declare_options
        plugin_collect
        printf "result=%s" "$(plugin_data_get result)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "1.20 | 0.90 | 0.70"
}

@test "loadavg low load reports health=ok" {
    cat >"$mock_dir/sysctl" <<'SYSCTL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"hw.ncpu"*) echo "8" ;;
    *"vm.loadavg"*) echo "{ 0.50 0.40 0.30 }" ;;
esac
SYSCTL_EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/loadavg.sh"
        is_linux() { return 1; }
        is_macos() { return 0; }
        get_option() {
            case "$1" in
                format) printf "1" ;;
                separator) printf " | " ;;
                warning_threshold_multiplier) printf "1" ;;
                critical_threshold_multiplier) printf "4" ;;
                icon) printf "LA" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context loadavg
        plugin_declare_options
        plugin_collect
        printf "health=%s num_cores=%s" \
            "$(plugin_get_health)" \
            "$(plugin_data_get num_cores)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=ok"
    assert_output --partial "num_cores=8"
}

@test "loadavg high load above warning threshold reports warning" {
    cat >"$mock_dir/sysctl" <<'SYSCTL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"hw.ncpu"*) echo "8" ;;
    *"vm.loadavg"*) echo "{ 9.00 5.00 3.00 }" ;;
esac
SYSCTL_EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/loadavg.sh"
        is_linux() { return 1; }
        is_macos() { return 0; }
        get_option() {
            case "$1" in
                format) printf "1" ;;
                separator) printf " | " ;;
                warning_threshold_multiplier) printf "1" ;;
                critical_threshold_multiplier) printf "4" ;;
                icon) printf "LA" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context loadavg
        plugin_declare_options
        plugin_collect
        printf "health=%s" "$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=warning"
}

@test "loadavg critical load above critical threshold reports error" {
    cat >"$mock_dir/sysctl" <<'SYSCTL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"hw.ncpu"*) echo "4" ;;
    *"vm.loadavg"*) echo "{ 20.00 15.00 12.00 }" ;;
esac
SYSCTL_EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/loadavg.sh"
        is_linux() { return 1; }
        is_macos() { return 0; }
        get_option() {
            case "$1" in
                format) printf "1" ;;
                separator) printf " | " ;;
                warning_threshold_multiplier) printf "1" ;;
                critical_threshold_multiplier) printf "4" ;;
                icon) printf "LA" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context loadavg
        plugin_declare_options
        plugin_collect
        printf "health=%s context=%s" \
            "$(plugin_get_health)" \
            "$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=error"
    assert_output --partial "critical_load"
}

@test "loadavg context reflects health level (normal)" {
    cat >"$mock_dir/sysctl" <<'SYSCTL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"hw.ncpu"*) echo "8" ;;
    *"vm.loadavg"*) echo "{ 0.30 0.20 0.10 }" ;;
esac
SYSCTL_EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/loadavg.sh"
        is_linux() { return 1; }
        is_macos() { return 0; }
        get_option() {
            case "$1" in
                format) printf "1" ;;
                separator) printf " | " ;;
                warning_threshold_multiplier) printf "1" ;;
                critical_threshold_multiplier) printf "4" ;;
                icon) printf "LA" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context loadavg
        plugin_declare_options
        plugin_collect
        plugin_get_context
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "normal_load"
}

@test "loadavg format=15 shows only 15-minute load" {
    cat >"$mock_dir/sysctl" <<'SYSCTL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"hw.ncpu"*) echo "4" ;;
    *"vm.loadavg"*) echo "{ 0.10 0.50 2.30 }" ;;
esac
SYSCTL_EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/loadavg.sh"
        is_linux() { return 1; }
        is_macos() { return 0; }
        get_option() {
            case "$1" in
                format) printf "15" ;;
                separator) printf " | " ;;
                warning_threshold_multiplier) printf "1" ;;
                critical_threshold_multiplier) printf "4" ;;
                icon) printf "LA" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context loadavg
        plugin_declare_options
        plugin_collect
        printf "result=%s" "$(plugin_data_get result)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "result=2.30"
}
