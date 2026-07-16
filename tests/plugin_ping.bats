#!/usr/bin/env bats
# =============================================================================
# BATS tests for ping plugin
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
    cat >"$mock_dir/ping" <<'EOF'
#!/usr/bin/env bash
echo "PING 8.8.8.8 (8.8.8.8): 56 data bytes"
echo "64 bytes from 8.8.8.8: icmp_seq=0 ttl=117 time=15.123 ms"
echo ""
echo "--- 8.8.8.8 ping statistics ---"
echo "1 packets transmitted, 1 packets received, 0.0% packet loss"
echo "round-trip min/avg/max/stddev = 15.123/15.123/15.123/0.000 ms"
EOF
    chmod +x "$mock_dir/ping"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ping.sh"
        _set_plugin_context ping
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
    refute_output --partial "rd=#"
}

# =============================================================================
# Behavioral Tests
# =============================================================================

@test "ping: 15ms latency → state=active, health=ok" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/ping" <<'EOF'
#!/usr/bin/env bash
echo "PING 8.8.8.8 (8.8.8.8): 56 data bytes"
echo "64 bytes from 8.8.8.8: icmp_seq=0 ttl=117 time=15.123 ms"
echo ""
echo "--- 8.8.8.8 ping statistics ---"
echo "1 packets transmitted, 1 packets received, 0.0% packet loss"
echo "round-trip min/avg/max/stddev = 15.123/15.123/15.123/0.000 ms"
EOF
    chmod +x "$mock_dir/ping"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ping.sh"
        _set_plugin_context ping
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
    assert_output --partial "render=15ms"
}

@test "ping: 150ms latency → health=warning" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/ping" <<'EOF'
#!/usr/bin/env bash
echo "PING 8.8.8.8 (8.8.8.8): 56 data bytes"
echo "64 bytes from 8.8.8.8: icmp_seq=0 ttl=117 time=150.456 ms"
echo ""
echo "--- 8.8.8.8 ping statistics ---"
echo "1 packets transmitted, 1 packets received, 0.0% packet loss"
echo "round-trip min/avg/max/stddev = 150.456/150.456/150.456/0.000 ms"
EOF
    chmod +x "$mock_dir/ping"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ping.sh"
        _set_plugin_context ping
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=warning"
    assert_output --partial "render=150ms"
}

@test "ping: 350ms latency → health=error" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/ping" <<'EOF'
#!/usr/bin/env bash
echo "PING 8.8.8.8 (8.8.8.8): 56 data bytes"
echo "64 bytes from 8.8.8.8: icmp_seq=0 ttl=117 time=350.789 ms"
echo ""
echo "--- 8.8.8.8 ping statistics ---"
echo "1 packets transmitted, 1 packets received, 0.0% packet loss"
echo "round-trip min/avg/max/stddev = 350.789/350.789/350.789/0.000 ms"
EOF
    chmod +x "$mock_dir/ping"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ping.sh"
        _set_plugin_context ping
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=error"
    assert_output --partial "render=351ms"
}

@test "ping: unreachable host → state=inactive, render=N/A" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/ping" <<'EOF'
#!/usr/bin/env bash
echo "PING 10.0.0.99 (10.0.0.99): 56 data bytes"
echo ""
echo "--- 10.0.0.99 ping statistics ---"
echo "1 packets transmitted, 0 packets received, 100.0% packet loss"
EOF
    chmod +x "$mock_dir/ping"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ping.sh"
        _set_plugin_context ping
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
    assert_output --partial "render=N/A"
}

@test "ping: render does NOT contain tmux formatting" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/ping" <<'EOF'
#!/usr/bin/env bash
echo "PING 8.8.8.8 (8.8.8.8): 56 data bytes"
echo "64 bytes from 8.8.8.8: icmp_seq=0 ttl=117 time=25.123 ms"
echo ""
echo "--- 8.8.8.8 ping statistics ---"
echo "1 packets transmitted, 1 packets received, 0.0% packet loss"
echo "round-trip min/avg/max/stddev = 25.123/25.123/25.123/0.000 ms"
EOF
    chmod +x "$mock_dir/ping"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ping.sh"
        _set_plugin_context ping
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "ping: plugin_get_icon returns non-empty string" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/ping" <<'EOF'
#!/usr/bin/env bash
echo "PING 8.8.8.8 (8.8.8.8): 56 data bytes"
echo "64 bytes from 8.8.8.8: icmp_seq=0 ttl=117 time=10.000 ms"
echo ""
echo "--- 8.8.8.8 ping statistics ---"
echo "1 packets transmitted, 1 packets received, 0.0% packet loss"
echo "round-trip min/avg/max/stddev = 10.000/10.000/10.000/0.000 ms"
EOF
    chmod +x "$mock_dir/ping"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ping.sh"
        _set_plugin_context ping
        plugin_declare_options
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "icon_ok" || echo "icon_empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon_ok"
}

@test "ping: plugin_get_context returns correct category for low latency" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/ping" <<'EOF'
#!/usr/bin/env bash
echo "PING 8.8.8.8 (8.8.8.8): 56 data bytes"
echo "64 bytes from 8.8.8.8: icmp_seq=0 ttl=117 time=10.000 ms"
echo ""
echo "--- 8.8.8.8 ping statistics ---"
echo "1 packets transmitted, 1 packets received, 0.0% packet loss"
echo "round-trip min/avg/max/stddev = 10.000/10.000/10.000/0.000 ms"
EOF
    chmod +x "$mock_dir/ping"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ping.sh"
        _set_plugin_context ping
        plugin_declare_options
        plugin_collect
        echo "context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "context=excellent"
}

@test "ping: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ping.sh"
        _set_plugin_context ping
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=ping"
}
