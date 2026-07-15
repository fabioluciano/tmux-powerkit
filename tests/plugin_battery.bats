#!/usr/bin/env bats
# =============================================================================
# BATS tests for battery plugin
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Contract Minimum: all required functions exist and return valid enums
# =============================================================================

@test "contract: all required functions exist and return valid enums" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pmset" <<'EOF'
#!/usr/bin/env bash
echo "Now drawing from 'Battery Power'
 -InternalBattery-0 (id=1234567)	80%; charging; 0:15 remaining"
EOF
    chmod +x "$mock_dir/pmset"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
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

@test "battery 50% discharging → state=active, health=ok" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pmset" <<'EOF'
#!/usr/bin/env bash
echo "Now drawing from 'Battery Power'
 -InternalBattery-0 (id=1234567)	50%; discharging; 4:15 remaining present: true"
EOF
    chmod +x "$mock_dir/pmset"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
    assert_output --partial "render=50%"
}

@test "battery 80% charging → health=info" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pmset" <<'EOF'
#!/usr/bin/env bash
echo "Now drawing from 'AC Power'
 -InternalBattery-0 (id=1234567)	80%; charging; 0:15 remaining present: true"
EOF
    chmod +x "$mock_dir/pmset"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=info"
}

@test "battery: no InternalBattery → state=inactive" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pmset" <<'EOF'
#!/usr/bin/env bash
echo "Now drawing from 'AC Power'
 -AC Charger-0    AC attached; not charging present: true"
EOF
    chmod +x "$mock_dir/pmset"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "state=inactive"
}

@test "battery 10% discharging → health=error" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pmset" <<'EOF'
#!/usr/bin/env bash
echo "Now drawing from 'Battery Power'
 -InternalBattery-0 (id=1234567)	10%; discharging; 0:15 remaining present: true"
EOF
    chmod +x "$mock_dir/pmset"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=error"
}

@test "battery 25% discharging → health=warning" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pmset" <<'EOF'
#!/usr/bin/env bash
echo "Now drawing from 'Battery Power'
 -InternalBattery-0 (id=1234567)	25%; discharging; 2:15 remaining present: true"
EOF
    chmod +x "$mock_dir/pmset"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=warning"
}

@test "battery 100% charged → health=ok" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pmset" <<'EOF'
#!/usr/bin/env bash
echo "Now drawing from 'AC Power'
 -InternalBattery-0 (id=1234567)	100%; charged; 0:00 remaining present: true"
EOF
    chmod +x "$mock_dir/pmset"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
    assert_output --partial "render=100%"
}

@test "battery: plugin_get_icon returns a non-empty string" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pmset" <<'EOF'
#!/usr/bin/env bash
echo "Now drawing from 'Battery Power'
 -InternalBattery-0 (id=1234567)	50%; discharging; 4:15 remaining present: true"
EOF
    chmod +x "$mock_dir/pmset"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
        plugin_declare_options
        plugin_collect
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "icon_ok" || echo "icon_empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon_ok"
}

@test "battery: plugin_get_context returns charging context" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pmset" <<'EOF'
#!/usr/bin/env bash
echo "Now drawing from 'AC Power'
 -InternalBattery-0 (id=1234567)	80%; charging; 0:15 remaining present: true"
EOF
    chmod +x "$mock_dir/pmset"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
        plugin_declare_options
        plugin_collect
        echo "context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "context=charging"
}

@test "battery: plugin_render does NOT contain tmux formatting" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pmset" <<'EOF'
#!/usr/bin/env bash
echo "Now drawing from 'Battery Power'
 -InternalBattery-0 (id=1234567)	50%; discharging; 4:15 remaining present: true"
EOF
    chmod +x "$mock_dir/pmset"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "battery: plugin_get_metadata exists and returns non-empty id" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/battery.sh"
        _set_plugin_context battery
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=battery"
}
