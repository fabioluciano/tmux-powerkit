#!/usr/bin/env bats
# =============================================================================
# BATS tests for memory plugin
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Contract Minimum
# =============================================================================

@test "contract: all required functions exist and return valid enums" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/memory_pressure" <<'EOF'
#!/usr/bin/env bash
echo "The system has 4147483648 (4.00 GB) of 8589934592 (8.00 GB) physical memory."
echo "System-wide memory free percentage: 50%"
EOF
    chmod +x "$mock_dir/memory_pressure"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *hw.memsize*) echo 8589934592 ;;
    *hw.pagesize*) echo 4096 ;;
    *) echo 0 ;;
esac
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/memory.sh"
        _set_plugin_context memory
        plugin_declare_options
        plugin_collect
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(active|inactive|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    assert_output --partial "rd="
    refute_output --partial "rd=#"
}

# =============================================================================
# Behavioral Tests
# =============================================================================

@test "memory: 50% used → health=ok" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/memory_pressure" <<'EOF'
#!/usr/bin/env bash
echo "The system has 4147483648 (4.00 GB) of 8589934592 (8.00 GB) physical memory."
echo "System-wide memory free percentage: 50%"
EOF
    chmod +x "$mock_dir/memory_pressure"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *hw.memsize*) echo 8589934592 ;;
    *hw.pagesize*) echo 4096 ;;
    *) echo 0 ;;
esac
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/memory.sh"
        _set_plugin_context memory
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
}

@test "memory: 85% used → health=warning" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/memory_pressure" <<'EOF'
#!/usr/bin/env bash
echo "The system has 7074897920 (7.00 GB) of 8589934592 (8.00 GB) physical memory."
echo "System-wide memory free percentage: 15%"
EOF
    chmod +x "$mock_dir/memory_pressure"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *hw.memsize*) echo 8589934592 ;;
    *hw.pagesize*) echo 4096 ;;
    *) echo 0 ;;
esac
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/memory.sh"
        _set_plugin_context memory
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=warning"
}

@test "memory: 95% used → health=error" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/memory_pressure" <<'EOF'
#!/usr/bin/env bash
echo "The system has 7933741056 (7.60 GB) of 8589934592 (8.00 GB) physical memory."
echo "System-wide memory free percentage: 5%"
EOF
    chmod +x "$mock_dir/memory_pressure"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *hw.memsize*) echo 8589934592 ;;
    *hw.pagesize*) echo 4096 ;;
    *) echo 0 ;;
esac
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/memory.sh"
        _set_plugin_context memory
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=error"
}

@test "memory: format=percent renders with percent sign" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/memory_pressure" <<'EOF'
#!/usr/bin/env bash
echo "The system has 4147483648 (4.00 GB) of 8589934592 (8.00 GB) physical memory."
echo "System-wide memory free percentage: 55%"
EOF
    chmod +x "$mock_dir/memory_pressure"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *hw.memsize*) echo 8589934592 ;;
    *hw.pagesize*) echo 4096 ;;
    *) echo 0 ;;
esac
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/memory.sh"
        _set_plugin_context memory
        plugin_declare_options
        get_option() {
            case "$1" in
                format) printf "percent" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp '[0-9 ]+%'
}

@test "memory: format=usage renders with slash" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/memory_pressure" <<'EOF'
#!/usr/bin/env bash
echo "The system has 4147483648 (4.00 GB) of 8589934592 (8.00 GB) physical memory."
echo "System-wide memory free percentage: 55%"
EOF
    chmod +x "$mock_dir/memory_pressure"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *hw.memsize*) echo 8589934592 ;;
    *hw.pagesize*) echo 4096 ;;
    *) echo 0 ;;
esac
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/memory.sh"
        _set_plugin_context memory
        plugin_declare_options
        get_option() {
            case "$1" in
                format) printf "usage" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp '[0-9.]+[GM]/[0-9.]+[GM]'
}

@test "memory: plugin_get_icon returns non-empty string" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/memory_pressure" <<'EOF'
#!/usr/bin/env bash
echo "The system has 4147483648 (4.00 GB) of 8589934592 (8.00 GB) physical memory."
echo "System-wide memory free percentage: 50%"
EOF
    chmod +x "$mock_dir/memory_pressure"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *hw.memsize*) echo 8589934592 ;;
    *hw.pagesize*) echo 4096 ;;
    *) echo 0 ;;
esac
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/memory.sh"
        _set_plugin_context memory
        plugin_declare_options
        plugin_collect
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "icon_ok" || echo "icon_empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon_ok"
}

@test "memory: no render tmux formatting" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/memory_pressure" <<'EOF'
#!/usr/bin/env bash
echo "The system has 4147483648 (4.00 GB) of 8589934592 (8.00 GB) physical memory."
echo "System-wide memory free percentage: 50%"
EOF
    chmod +x "$mock_dir/memory_pressure"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *hw.memsize*) echo 8589934592 ;;
    *hw.pagesize*) echo 4096 ;;
    *) echo 0 ;;
esac
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/memory.sh"
        _set_plugin_context memory
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "memory: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/memory.sh"
        _set_plugin_context memory
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=memory"
}

@test "memory: plugin_get_context returns meaningful context" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/memory_pressure" <<'EOF'
#!/usr/bin/env bash
echo "The system has 4147483648 (4.00 GB) of 8589934592 (8.00 GB) physical memory."
echo "System-wide memory free percentage: 50%"
EOF
    chmod +x "$mock_dir/memory_pressure"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *hw.memsize*) echo 8589934592 ;;
    *hw.pagesize*) echo 4096 ;;
    *) echo 0 ;;
esac
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/memory.sh"
        _set_plugin_context memory
        plugin_declare_options
        plugin_collect
        echo "context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp 'context=(normal_load|high_load|critical_load)'
}
