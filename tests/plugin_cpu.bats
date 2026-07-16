#!/usr/bin/env bats
# =============================================================================
# BATS tests for cpu plugin
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
    mock_dir=$(create_mock_path)
    cat >"$mock_dir/uname" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "-s" ]] && printf 'Darwin\n' || command uname "$@"
EOF
    chmod +x "$mock_dir/uname"
    export PATH="$mock_dir:$PATH"
}

# =============================================================================
# Contract Minimum
# =============================================================================

@test "contract: all required functions exist and return valid enums" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/top" <<'EOF'
#!/usr/bin/env bash
echo "CPU usage: 5.23% user, 10.01% sys, 84.76% idle"
EOF
    chmod +x "$mock_dir/top"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cpu.sh"
        _set_plugin_context cpu
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

@test "cpu: ~15% usage → health=ok" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/top" <<'EOF'
#!/usr/bin/env bash
echo "CPU usage: 5.23% user, 10.01% sys, 84.76% idle"
EOF
    chmod +x "$mock_dir/top"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cpu.sh"
        _set_plugin_context cpu
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
}

@test "cpu: ~80% usage → health=warning" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/top" <<'EOF'
#!/usr/bin/env bash
echo "CPU usage: 45.00% user, 35.00% sys, 20.00% idle"
EOF
    chmod +x "$mock_dir/top"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cpu.sh"
        _set_plugin_context cpu
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=warning"
}

@test "cpu: ~95% usage → health=error" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/top" <<'EOF'
#!/usr/bin/env bash
echo "CPU usage: 50.00% user, 45.00% sys, 5.00% idle"
EOF
    chmod +x "$mock_dir/top"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cpu.sh"
        _set_plugin_context cpu
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=error"
}

@test "cpu: render returns percentage with percent sign" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/top" <<'EOF'
#!/usr/bin/env bash
echo "CPU usage: 25.00% user, 15.00% sys, 60.00% idle"
EOF
    chmod +x "$mock_dir/top"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cpu.sh"
        _set_plugin_context cpu
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp '[0-9 ]+%'
}

@test "cpu: render does NOT contain tmux formatting" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/top" <<'EOF'
#!/usr/bin/env bash
echo "CPU usage: 30.00% user, 10.00% sys, 60.00% idle"
EOF
    chmod +x "$mock_dir/top"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cpu.sh"
        _set_plugin_context cpu
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "cpu: plugin_get_icon returns non-empty string" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/top" <<'EOF'
#!/usr/bin/env bash
echo "CPU usage: 30.00% user, 10.00% sys, 60.00% idle"
EOF
    chmod +x "$mock_dir/top"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cpu.sh"
        _set_plugin_context cpu
        plugin_declare_options
        plugin_collect
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "icon_ok" || echo "icon_empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon_ok"
}

@test "cpu: fallback to iostat when top fails" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/top" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$mock_dir/top"
    cat >"$mock_dir/iostat" <<'EOF'
#!/usr/bin/env bash
echo "            CPU     %user  %nice    %sys %iowait    %idle
               0.00    0.00    0.00    0.00  100.00
               0.00    0.00    0.00    0.00  100.00
          34.72    0.00   12.07    9.96   43.25"
EOF
    chmod +x "$mock_dir/iostat"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cpu.sh"
        _set_plugin_context cpu
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
}

@test "cpu: plugin_get_context returns cpu_load prefix" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/top" <<'EOF'
#!/usr/bin/env bash
echo "CPU usage: 5.23% user, 10.01% sys, 84.76% idle"
EOF
    chmod +x "$mock_dir/top"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cpu.sh"
        _set_plugin_context cpu
        plugin_declare_options
        plugin_collect
        echo "context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "context=cpu_load"
}

@test "cpu: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cpu.sh"
        _set_plugin_context cpu
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=cpu"
}
