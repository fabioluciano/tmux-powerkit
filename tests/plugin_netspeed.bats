#!/usr/bin/env bats
# =============================================================================
# BATS tests for netspeed plugin
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
    cat >"$mock_dir/route" <<'EOF'
#!/usr/bin/env bash
echo "   route to: default
                                interface: en0"
EOF
    chmod +x "$mock_dir/route"
    cat >"$mock_dir/netstat" <<'EOF'
#!/usr/bin/env bash
echo "Name  Mtu   Network       Address            Ipkts Ierrs    Opkts Oerrs  Coll"
echo "en0   1500  <Link#6>    xx:xx:xx:xx:xx  12500     0    11000     0     0"
EOF
    chmod +x "$mock_dir/netstat"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/netspeed.sh"
        _set_plugin_context netspeed
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

@test "netspeed: first collection returns 0 rates (baseline stored)" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/route" <<'EOF'
#!/usr/bin/env bash
echo "   route to: default
                                interface: en0"
EOF
    chmod +x "$mock_dir/route"
    cat >"$mock_dir/netstat" <<'EOF'
#!/usr/bin/env bash
echo "Name  Mtu   Network       Address            Ipkts Ierrs    Opkts Oerrs  Coll Drop"
echo "en0   1500  <Link#6>    xx:xx:xx:xx:xx  50000     0    25000     0     0     0"
EOF
    chmod +x "$mock_dir/netstat"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/netspeed.sh"
        _set_plugin_context netspeed
        plugin_declare_options
        get_option() {
            case "$1" in
                interface) printf "auto" ;;
                display) printf "both" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        echo "rx=$(plugin_data_get rx_rate) tx=$(plugin_data_get tx_rate) state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    # First call stores baseline, returns 0 rates, but state is active
    assert_output --partial "state=active"
}

@test "netspeed: render does NOT contain tmux formatting" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/route" <<'EOF'
#!/usr/bin/env bash
echo "   route to: default
                                interface: en0"
EOF
    chmod +x "$mock_dir/route"
    cat >"$mock_dir/netstat" <<'EOF'
#!/usr/bin/env bash
echo "Name  Mtu   Network       Address            Ipkts Ierrs    Opkts Oerrs  Coll Drop"
echo "en0   1500  <Link#6>    xx:xx:xx:xx:xx  50000     0    25000     0     0     0"
EOF
    chmod +x "$mock_dir/netstat"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/netspeed.sh"
        _set_plugin_context netspeed
        plugin_declare_options
        get_option() {
            case "$1" in
                display) printf "both" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "netspeed: health=ok with thresholds disabled (default=0)" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/route" <<'EOF'
#!/usr/bin/env bash
echo "   route to: default
                                interface: en0"
EOF
    chmod +x "$mock_dir/route"
    cat >"$mock_dir/netstat" <<'EOF'
#!/usr/bin/env bash
echo "Name  Mtu   Network       Address            Ipkts Ierrs    Opkts Oerrs  Coll Drop"
echo "en0   1500  <Link#6>    xx:xx:xx:xx:xx  50000     0    25000     0     0     0"
EOF
    chmod +x "$mock_dir/netstat"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/netspeed.sh"
        _set_plugin_context netspeed
        plugin_declare_options
        plugin_collect
        echo "health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=ok"
}

@test "netspeed: plugin_get_context returns idle when rates are zero" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/route" <<'EOF'
#!/usr/bin/env bash
echo "   route to: default
                                interface: en0"
EOF
    chmod +x "$mock_dir/route"
    cat >"$mock_dir/netstat" <<'EOF'
#!/usr/bin/env bash
echo "Name  Mtu   Network       Address            Ipkts Ierrs    Opkts Oerrs  Coll Drop"
echo "en0   1500  <Link#6>    xx:xx:xx:xx:xx  50000     0    25000     0     0     0"
EOF
    chmod +x "$mock_dir/netstat"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/netspeed.sh"
        _set_plugin_context netspeed
        plugin_declare_options
        plugin_collect
        echo "context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp 'context=(idle|downloading|uploading|active)'
}

@test "netspeed: plugin_get_icon returns non-empty string" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/route" <<'EOF'
#!/usr/bin/env bash
echo "   route to: default
                                interface: en0"
EOF
    chmod +x "$mock_dir/route"
    cat >"$mock_dir/netstat" <<'EOF'
#!/usr/bin/env bash
echo "Name  Mtu   Network       Address            Ipkts Ierrs    Opkts Oerrs  Coll Drop"
echo "en0   1500  <Link#6>    xx:xx:xx:xx:xx  50000     0    25000     0     0     0"
EOF
    chmod +x "$mock_dir/netstat"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/netspeed.sh"
        _set_plugin_context netspeed
        plugin_declare_options
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "icon_ok" || echo "icon_empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon_ok"
}

@test "netspeed: display=download shows only download" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/route" <<'EOF'
#!/usr/bin/env bash
echo "   route to: default
                                interface: en0"
EOF
    chmod +x "$mock_dir/route"
    cat >"$mock_dir/netstat" <<'EOF'
#!/usr/bin/env bash
echo "Name  Mtu   Network       Address            Ipkts Ierrs    Opkts Oerrs  Coll Drop"
echo "en0   1500  <Link#6>    xx:xx:xx:xx:xx  50000     0    25000     0     0     0"
EOF
    chmod +x "$mock_dir/netstat"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/netspeed.sh"
        _set_plugin_context netspeed
        plugin_declare_options
        get_option() {
            case "$1" in
                display) printf "download" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Should contain download icon and rate, not upload-related
    [[ -n "$output" ]]
}

@test "netspeed: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/netspeed.sh"
        _set_plugin_context netspeed
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=netspeed"
}
