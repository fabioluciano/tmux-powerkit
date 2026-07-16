#!/usr/bin/env bats
# =============================================================================
# BATS tests for hostname plugin
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
    cat >"$mock_dir/hostname" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -s) echo "myhost" ;;
    -f) echo "myhost.local" ;;
    *) echo "myhost" ;;
esac
EOF
    chmod +x "$mock_dir/hostname"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/hostname.sh"
        _set_plugin_context hostname
        plugin_declare_options
        plugin_collect
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=always"
    assert_output --partial "st=active"
    assert_output --partial "hl=ok"
    assert_output --regexp "cx=(local|remote)"
    refute_output --partial "rd=#"
}

# =============================================================================
# Behavioral Tests
# =============================================================================

@test "hostname: short format returns short hostname" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/hostname" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -s) echo "workstation" ;;
    -f) echo "workstation.example.com" ;;
    *) echo "workstation" ;;
esac
EOF
    chmod +x "$mock_dir/hostname"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/hostname.sh"
        _set_plugin_context hostname
        plugin_declare_options
        get_option() {
            case "$1" in format) printf "short" ;; *) printf "" ;; esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "workstation"
}

@test "hostname: full format returns full hostname" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/hostname" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -s) echo "workstation" ;;
    -f) echo "workstation.example.com" ;;
    *) echo "workstation" ;;
esac
EOF
    chmod +x "$mock_dir/hostname"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/hostname.sh"
        _set_plugin_context hostname
        plugin_declare_options
        get_option() {
            case "$1" in format) printf "full" ;; *) printf "" ;; esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "workstation.example.com"
}

@test "hostname: SSH session detection returns remote context" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/hostname" <<'EOF'
#!/usr/bin/env bash
echo "myhost"
EOF
    chmod +x "$mock_dir/hostname"

    export SSH_CONNECTION="192.168.1.1 12345 10.0.0.1 22"
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/hostname.sh"
        _set_plugin_context hostname
        echo "context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "context=remote"
    unset SSH_CONNECTION
}

@test "hostname: no SSH variables returns local context" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/hostname" <<'EOF'
#!/usr/bin/env bash
echo "myhost"
EOF
    chmod +x "$mock_dir/hostname"

    unset SSH_CONNECTION SSH_CLIENT SSH_TTY
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/hostname.sh"
        _set_plugin_context hostname
        echo "context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "context=local"
}

@test "hostname: render does NOT contain tmux formatting" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/hostname" <<'EOF'
#!/usr/bin/env bash
echo "myhost"
EOF
    chmod +x "$mock_dir/hostname"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/hostname.sh"
        _set_plugin_context hostname
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "hostname: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/hostname.sh"
        _set_plugin_context hostname
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=hostname"
}

@test "hostname: plugin_get_state always returns active" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/hostname" <<'EOF'
#!/usr/bin/env bash
echo "myhost"
EOF
    chmod +x "$mock_dir/hostname"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/hostname.sh"
        _set_plugin_context hostname
        plugin_get_state
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "active"
}
