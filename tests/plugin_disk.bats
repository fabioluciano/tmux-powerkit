#!/usr/bin/env bats
# =============================================================================
# BATS tests for disk plugin
# Note: disk plugin uses /bin/df (absolute path), so we override private functions
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
        source "$1/src/plugins/disk.sh"
        _set_plugin_context disk
        plugin_declare_options
        _get_disk_percent() { echo "40"; }
        _get_disk_info() { echo "40%"; }
        _resolve_mount() { printf "%s" "$1"; }
        get_option() {
            case "$1" in
                mounts) printf "/" ;;
                *) printf "" ;;
            esac
        }
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

@test "disk: 40% usage → health=ok" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/disk.sh"
        _set_plugin_context disk
        plugin_declare_options
        _get_disk_percent() { echo "40"; }
        _get_disk_info() { echo "40%"; }
        _resolve_mount() { printf "%s" "$1"; }
        get_option() {
            case "$1" in
                mounts) printf "/" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
}

@test "disk: 85% usage → health=warning" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/disk.sh"
        _set_plugin_context disk
        plugin_declare_options
        _get_disk_percent() { echo "85"; }
        _get_disk_info() { echo "85%"; }
        _resolve_mount() { printf "%s" "$1"; }
        get_option() {
            case "$1" in
                mounts) printf "/" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=warning"
}

@test "disk: 95% usage → health=error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/disk.sh"
        _set_plugin_context disk
        plugin_declare_options
        _get_disk_percent() { echo "95"; }
        _get_disk_info() { echo "95%"; }
        _resolve_mount() { printf "%s" "$1"; }
        get_option() {
            case "$1" in
                mounts) printf "/" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=error"
}

@test "disk: format=percent renders with percent sign" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/disk.sh"
        _set_plugin_context disk
        plugin_declare_options
        _get_disk_percent() { echo "40"; }
        _get_disk_info() { echo "40%"; }
        _resolve_mount() { printf "%s" "$1"; }
        get_option() {
            case "$1" in
                format) printf "percent" ;;
                mounts) printf "/" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp '.*%'
}

@test "disk: format=usage renders with slash" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/disk.sh"
        _set_plugin_context disk
        plugin_declare_options
        _get_disk_percent() { echo "40"; }
        _get_disk_info() { echo "93.3G/233.7G"; }
        _resolve_mount() { printf "%s" "$1"; }
        get_option() {
            case "$1" in
                format) printf "usage" ;;
                mounts) printf "/" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp '[0-9.]+G/[0-9.]+G'
}

@test "disk: plugin_get_icon returns non-empty string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/disk.sh"
        _set_plugin_context disk
        plugin_declare_options
        _get_disk_percent() { echo "40"; }
        _get_disk_info() { echo "40%"; }
        _resolve_mount() { printf "%s" "$1"; }
        get_option() {
            case "$1" in
                mounts) printf "/" ;;
                icon) printf "ICON_PLACEHOLDER" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "icon_ok" || echo "icon_empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon_ok"
}

@test "disk: no render tmux formatting" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/disk.sh"
        _set_plugin_context disk
        plugin_declare_options
        _get_disk_percent() { echo "40"; }
        _get_disk_info() { echo "40%"; }
        _resolve_mount() { printf "%s" "$1"; }
        get_option() {
            case "$1" in
                mounts) printf "/" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "disk: multiple mounts with label" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/disk.sh"
        _set_plugin_context disk
        plugin_declare_options
        _get_disk_percent() {
            case "$1" in
                /) echo "40" ;;
                /home) echo "80" ;;
            esac
        }
        _get_disk_info() {
            case "$1" in
                /) echo "40%" ;;
                /home) echo "80%" ;;
            esac
        }
        _resolve_mount() { printf "%s" "$1"; }
        get_option() {
            case "$1" in
                mounts) printf "/,/home" ;;
                format) printf "percent" ;;
                show_label) printf "true" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        echo "mount_count=$(plugin_data_get mount_count)"
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "mount_count=2"
}

@test "disk: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/disk.sh"
        _set_plugin_context disk
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=disk"
}
