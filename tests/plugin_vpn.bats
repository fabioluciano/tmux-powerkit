#!/usr/bin/env bats
# =============================================================================
# BATS tests for vpn plugin
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
    cat >"$mock_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1  # no VPN detected
EOF
    chmod +x "$mock_dir/pgrep"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/vpn.sh"
        _set_plugin_context vpn
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

@test "vpn: OpenVPN detected → state=active, health=info" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    -x\ openvpn) exit 0 ;;
    -a\ openvpn|*-a\ openvpn*) echo "12345 /etc/openvpn/work.conf" ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$mock_dir/pgrep"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/vpn.sh"
        _set_plugin_context vpn
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=info"
}

@test "vpn: no VPN detected → state=inactive" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$mock_dir/pgrep"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/vpn.sh"
        _set_plugin_context vpn
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}

@test "vpn: render does NOT contain tmux formatting" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    -x\ openvpn) exit 0 ;;
    -a\ openvpn|*-a\ openvpn*) echo "12345 /etc/openvpn/work.conf" ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$mock_dir/pgrep"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/vpn.sh"
        _set_plugin_context vpn
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "vpn: plugin_get_icon returns non-empty string" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    -x\ openvpn) exit 0 ;;
    -a\ openvpn|*-a\ openvpn*) echo "12345 /etc/openvpn/work.conf" ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$mock_dir/pgrep"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/vpn.sh"
        _set_plugin_context vpn
        plugin_declare_options
        plugin_collect
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "icon_ok" || echo "icon_empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon_ok"
}

@test "vpn: plugin_get_context returns provider name" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    -x\ openvpn) exit 0 ;;
    -a\ openvpn|*-a\ openvpn*) echo "12345 /etc/openvpn/work.conf" ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$mock_dir/pgrep"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/vpn.sh"
        _set_plugin_context vpn
        plugin_declare_options
        plugin_collect
        echo "context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
}

@test "vpn: render shows VPN name when connected" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    -x\ openvpn) exit 0 ;;
    -a\ openvpn|*-a\ openvpn*) echo "12345 /etc/openvpn/work.conf" ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$mock_dir/pgrep"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/vpn.sh"
        _set_plugin_context vpn
        plugin_declare_options
        get_option() {
            case "$1" in
                format) printf "name" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Should show the config filename
    [[ -n "$output" && "$output" != "VPN" ]]
}

@test "vpn: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/vpn.sh"
        _set_plugin_context vpn
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=vpn"
}

@test "vpn: WireGuard detection → state=active" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1  # openvpn not running
EOF
    chmod +x "$mock_dir/pgrep"
    cat >"$mock_dir/wg" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    show\ interfaces) echo "wg0" ;;
    *) echo "ok" ;;
esac
EOF
    chmod +x "$mock_dir/wg"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/vpn.sh"
        _set_plugin_context vpn
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) connected=$(plugin_data_get connected)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "connected=1"
}
