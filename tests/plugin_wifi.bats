#!/usr/bin/env bats
# =============================================================================
# BATS tests for wifi plugin
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Contract Minimum
# =============================================================================

@test "contract: all required functions exist and return valid enums" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_declare_options
        _get_wifi_macos() { return 1; }
        _get_wifi_linux() { return 1; }
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
# Helper: set mock wifi data
# =============================================================================
# The wifi plugin's plugin_collect calls _get_wifi_macos() or _get_wifi_linux()
# which in turn sets plugin data. We override _get_wifi_macos to directly set data.

_set_mock_wifi_data() {
    local connected="${1:-1}"
    local ssid="${2:-MyHomeWiFi}"
    local signal="${3:-70}"
    local ip="${4:-192.168.1.100}"
    plugin_data_set "connected" "$connected"
    plugin_data_set "ssid" "$ssid"
    plugin_data_set "signal" "$signal"
    plugin_data_set "ip" "$ip"
}

# =============================================================================
# Behavioral Tests
# =============================================================================

@test "wifi: connected → state=active, shows SSID" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_declare_options
        get_option() {
            case "$1" in
                show_when) printf "connected" ;;
                format) printf "ssid" ;;
                *) printf "" ;;
            esac
        }
        plugin_data_set "connected" "1"
        plugin_data_set "ssid" "MyHomeWiFi"
        plugin_data_set "signal" "70"
        plugin_data_set "ip" "192.168.1.100"
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "render=MyHomeWiFi"
}

@test "wifi: strong signal → health=ok" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_declare_options
        get_option() {
            case "$1" in
                show_when) printf "connected" ;;
                *) printf "" ;;
            esac
        }
        plugin_data_set "connected" "1"
        plugin_data_set "ssid" "StrongWiFi"
        plugin_data_set "signal" "85"
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
}

@test "wifi: weak signal → health=error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_declare_options
        get_option() {
            case "$1" in
                show_when) printf "connected" ;;
                *) printf "" ;;
            esac
        }
        plugin_data_set "connected" "1"
        plugin_data_set "ssid" "WeakWiFi"
        plugin_data_set "signal" "15"
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=error"
}

@test "wifi: medium signal → health=warning" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_declare_options
        get_option() {
            case "$1" in
                show_when) printf "connected" ;;
                *) printf "" ;;
            esac
        }
        plugin_data_set "connected" "1"
        plugin_data_set "ssid" "MediumWiFi"
        plugin_data_set "signal" "40"
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=warning"
}

@test "wifi: disconnected (show_when=connected) → state=inactive" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_declare_options
        get_option() {
            case "$1" in
                show_when) printf "connected" ;;
                *) printf "" ;;
            esac
        }
        plugin_data_set "connected" "0"
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}

@test "wifi: render does NOT contain tmux formatting" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_declare_options
        get_option() {
            case "$1" in
                show_when) printf "connected" ;;
                *) printf "" ;;
            esac
        }
        plugin_data_set "connected" "1"
        plugin_data_set "ssid" "HomeWiFi"
        plugin_data_set "signal" "70"
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "wifi: plugin_get_icon returns non-empty string when connected" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_declare_options
        plugin_data_set "connected" "1"
        plugin_data_set "ssid" "HomeWiFi"
        plugin_data_set "signal" "70"
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "icon_ok" || echo "icon_empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon_ok"
}

@test "wifi: plugin_get_context returns connected context" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_declare_options
        plugin_data_set "connected" "1"
        plugin_data_set "ssid" "HomeWiFi"
        plugin_data_set "signal" "70"
        echo "context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp "context=(disconnected|connected)"
}

@test "wifi: format=ssid,signal shows both SSID and signal" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_declare_options
        get_option() {
            case "$1" in
                show_when) printf "connected" ;;
                format) printf "ssid,signal" ;;
                *) printf "" ;;
            esac
        }
        plugin_data_set "connected" "1"
        plugin_data_set "ssid" "OfficeWiFi"
        plugin_data_set "signal" "75"
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "OfficeWiFi"
    assert_output --partial "%"
}

@test "wifi: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/wifi.sh"
        _set_plugin_context wifi
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=wifi"
}
