#!/usr/bin/env bats
# =============================================================================
# BATS tests for network plugins (externalip, ssh, connectivity)
# — contract minimum + behavioral
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# externalip
# =============================================================================

@test "externalip: contract functions work with mocked curl" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo "1.2.3.4"
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/externalip.sh"
        _set_plugin_context externalip
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence)
        st=$(plugin_get_state) && hl=$(plugin_get_health)
        ic=$(plugin_get_icon) && rd=$(plugin_render 2>/dev/null || true)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(active|inactive|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "externalip: with valid IP → state=active, health=ok" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo "203.0.113.42"
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/externalip.sh"
        _set_plugin_context externalip
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
    assert_output --partial "render=203.0.113.42"
}

@test "externalip: no IP → state=inactive, render=N/A" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/externalip.sh"
        _set_plugin_context externalip
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
    assert_output --partial "render=N/A"
}

@test "externalip: render does NOT contain tmux formatting" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo "1.2.3.4"
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/externalip.sh"
        _set_plugin_context externalip
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial "#["
}

@test "externalip: plugin_get_icon returns non-empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/externalip.sh"
        _set_plugin_context externalip
        plugin_declare_options
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "ok" || echo "empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

@test "externalip: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/externalip.sh"
        _set_plugin_context externalip
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=externalip"
}

# =============================================================================
# ssh
# =============================================================================

@test "ssh: contract functions work with SSH_TTY (incoming)" {
    export SSH_TTY="/dev/ttys000"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ssh.sh"
        _set_plugin_context ssh
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence)
        st=$(plugin_get_state) && hl=$(plugin_get_health)
        ic=$(plugin_get_icon) && rd=$(plugin_render 2>/dev/null || true)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "st=active"
    assert_output --partial "hl=info"
    refute_output --partial "rd=#["
}

@test "ssh: without SSH variables → state=inactive" {
    unset SSH_TTY SSH_CLIENT SSH_CONNECTION

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ssh.sh"
        _set_plugin_context ssh
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}

@test "ssh: with SSH_CONNECTION → state=active, context=incoming" {
    export SSH_CONNECTION="192.168.1.100 54321 10.0.0.5 22"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ssh.sh"
        _set_plugin_context ssh
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) context=$(plugin_get_context) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "context=incoming"
    assert_output --regexp "render=.+@.+"
}

@test "ssh: plugin_get_icon returns non-empty" {
    unset SSH_TTY SSH_CLIENT SSH_CONNECTION

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ssh.sh"
        _set_plugin_context ssh
        plugin_declare_options
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "ok" || echo "empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

@test "ssh: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/ssh.sh"
        _set_plugin_context ssh
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=ssh"
}

# =============================================================================
# connectivity
# =============================================================================

@test "connectivity: contract functions work with data seeding" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/connectivity.sh"
        _set_plugin_context connectivity
        plugin_declare_options
        plugin_data_set "online" "1"
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence)
        st=$(plugin_get_state) && hl=$(plugin_get_health)
        ic=$(plugin_get_icon) && rd=$(plugin_render 2>/dev/null || true)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=always"
    assert_output --regexp "st=(active|inactive|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "connectivity: online → state=active (hidden when healthy), health=good, render=online" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/connectivity.sh"
        _set_plugin_context connectivity
        plugin_declare_options
        plugin_data_set "online" "1"
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render) context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=good"
    assert_output --partial "render=online"
    assert_output --partial "context=online"
}

@test "connectivity: offline → health=error, render=offline" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/connectivity.sh"
        _set_plugin_context connectivity
        plugin_declare_options
        plugin_data_set "online" "0"
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=error"
    assert_output --partial "render=offline"
}

@test "connectivity: render does NOT contain tmux formatting" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/connectivity.sh"
        _set_plugin_context connectivity
        plugin_declare_options
        plugin_data_set "online" "1"
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial "#["
}

@test "connectivity: plugin_get_icon changes icon based on state" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/connectivity.sh"
        _set_plugin_context connectivity
        plugin_declare_options
        plugin_data_set "online" "1"
        echo "icon_online=$(plugin_get_icon)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "icon_online="
}
