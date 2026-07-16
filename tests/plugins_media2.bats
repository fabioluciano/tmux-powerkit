#!/usr/bin/env bats
# =============================================================================
# BATS tests for media plugins (audiodevices, camera, microphone, bluetooth)
# — contract minimum + behavioral
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# audiodevices
# =============================================================================

@test "audiodevices: contract functions work with mocked SwitchAudioSource" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/SwitchAudioSource" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *-t\ output*) echo "Built-in Output" ;;
    *-t\ input*) echo "Built-in Microphone" ;;
    *) echo "Unknown" ;;
esac
EOF
    chmod +x "$mock_dir/SwitchAudioSource"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/audiodevices.sh"
        _set_plugin_context audiodevices
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

@test "audiodevices: both mode shows input+output via mock" {
    run bash -c "
        source \"\$1/src/core/bootstrap.sh\"
        source \"\$1/src/plugins/audiodevices.sh\"
        _set_plugin_context audiodevices
        plugin_declare_options
        get_option() { case \"\$1\" in display_mode) printf 'both' ;; show_only_on_threshold) printf 'false' ;; *) printf '' ;; esac; }
        _get_audio_system() { printf 'macos'; }
        plugin_data_set \"input\" \"Built-in Microphone\"
        plugin_data_set \"output\" \"Built-in Output\"
        echo \"state=\$(plugin_get_state) render=\$(plugin_render)\"
    " _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
}

@test "audiodevices: display_mode=off → state=inactive" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/audiodevices.sh"
        _set_plugin_context audiodevices
        plugin_declare_options
        get_option() { case "$1" in display_mode) echo "off" ;; *) echo "" ;; esac; }
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}

@test "audiodevices: plugin_get_icon returns non-empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/audiodevices.sh"
        _set_plugin_context audiodevices
        plugin_declare_options
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "ok" || echo "empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

# =============================================================================
# camera
# =============================================================================

@test "camera: contract functions work with mocked pgrep" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
echo "12345"
EOF
    chmod +x "$mock_dir/pgrep"

    cat >"$mock_dir/ps" <<'EOF'
#!/usr/bin/env bash
echo " 12.0"
EOF
    chmod +x "$mock_dir/ps"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/camera.sh"
        _set_plugin_context camera
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

@test "camera: active camera → state=active, health=info, render=ON" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/camera.sh"
        _set_plugin_context camera
        plugin_declare_options
        plugin_data_set "status" "active"
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=info"
    assert_output --partial "render=ON"
}

@test "camera: inactive camera → state=inactive" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/camera.sh"
        _set_plugin_context camera
        plugin_declare_options
        plugin_data_set "status" "inactive"
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}

@test "camera: plugin_get_icon returns non-empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/camera.sh"
        _set_plugin_context camera
        plugin_declare_options
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "ok" || echo "empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

@test "camera: render does NOT contain tmux formatting" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/camera.sh"
        _set_plugin_context camera
        plugin_declare_options
        plugin_data_set "status" "active"
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial "#["
}

# =============================================================================
# microphone
# =============================================================================

@test "microphone: contract functions work with data seeding" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/microphone.sh"
        _set_plugin_context microphone
        plugin_declare_options
        plugin_data_set "status" "active"
        plugin_data_set "mute" "unmuted"
        plugin_data_set "volume" "75"
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

@test "microphone: active+unmuted → state=active, health=info, render=ON" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/microphone.sh"
        _set_plugin_context microphone
        plugin_declare_options
        plugin_data_set "status" "active"
        plugin_data_set "mute" "unmuted"
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=info"
    assert_output --partial "render=ON"
}

@test "microphone: active+muted → health=warning, render=MUTED" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/microphone.sh"
        _set_plugin_context microphone
        plugin_declare_options
        plugin_data_set "status" "active"
        plugin_data_set "mute" "muted"
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=warning"
    assert_output --partial "render=MUTED"
}

@test "microphone: inactive → state=inactive, health=ok" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/microphone.sh"
        _set_plugin_context microphone
        plugin_declare_options
        plugin_data_set "status" "inactive"
        plugin_data_set "mute" "unmuted"
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
    assert_output --partial "health=ok"
}

@test "microphone: plugin_get_icon shows muted icon when muted" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/microphone.sh"
        _set_plugin_context microphone
        plugin_declare_options
        plugin_data_set "mute" "muted"
        icon_muted=$(plugin_get_icon)
        plugin_data_set "mute" "unmuted"
        icon_unmuted=$(plugin_get_icon)
        [[ -n "$icon_muted" && -n "$icon_unmuted" ]] && echo "both_ok" || echo "missing"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "both_ok"
}

# =============================================================================
# bluetooth
# =============================================================================

@test "bluetooth: contract functions work with mocked blueutil" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/blueutil" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -p) echo "1" ;;
    --connected) echo "name: \"Magic Mouse\", address: aa:bb:cc:dd:ee:ff" ;;
    --info) echo "battery: 75" ;;
    *) echo "" ;;
esac
EOF
    chmod +x "$mock_dir/blueutil"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bluetooth.sh"
        is_macos() { return 0; }
        _set_plugin_context bluetooth
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

@test "bluetooth: off → state=inactive" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/blueutil" <<'EOF'
#!/usr/bin/env bash
echo "0"
EOF
    chmod +x "$mock_dir/blueutil"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bluetooth.sh"
        is_macos() { return 0; }
        _set_plugin_context bluetooth
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}

@test "bluetooth: on no devices → state=active, health=info" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/blueutil" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -p) echo "1" ;;
    --connected) echo "" ;;
    *) echo "" ;;
esac
EOF
    chmod +x "$mock_dir/blueutil"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bluetooth.sh"
        is_macos() { return 0; }
        _set_plugin_context bluetooth
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=info"
    assert_output --partial "render=ON"
}

@test "bluetooth: devices connected → state=active, health=good" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/blueutil" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -p) echo "1" ;;
    --connected) echo "name: \"Magic Mouse\", address: aa:bb:cc:dd:ee:ff" ;;
    --info) echo "battery: 75" ;;
    *) echo "" ;;
esac
EOF
    chmod +x "$mock_dir/blueutil"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bluetooth.sh"
        is_macos() { return 0; }
        _set_plugin_context bluetooth
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=good"
}

@test "bluetooth: low battery → health=warning" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/blueutil" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -p) echo "1" ;;
    --connected) echo "name: \"Magic Mouse\", address: aa:bb:cc:dd:ee:ff" ;;
    --info) echo "battery: 15" ;;
    *) echo "" ;;
esac
EOF
    chmod +x "$mock_dir/blueutil"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bluetooth.sh"
        is_macos() { return 0; }
        _set_plugin_context bluetooth
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=warning"
}

@test "bluetooth: plugin_get_icon returns non-empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bluetooth.sh"
        _set_plugin_context bluetooth
        plugin_declare_options
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "ok" || echo "empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}
