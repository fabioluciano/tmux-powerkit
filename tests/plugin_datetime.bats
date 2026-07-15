#!/usr/bin/env bats
# =============================================================================
# BATS tests for datetime plugin
# Uses ONLY bash printf '%(...)T' builtin — no external commands
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
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
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
    assert_output --regexp "cx=(morning|afternoon|evening|night)"
    assert_output --partial "rd="
    refute_output --partial "rd=#"
}

# =============================================================================
# Behavioral Tests
# =============================================================================

@test "datetime: default format returns non-empty date string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
}

@test "datetime: format=time shows HH:MM" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_declare_options
        get_option() {
            case "$1" in
                format) printf "time" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp '^[0-9]{2}:[0-9]{2}$'
}

@test "datetime: format=date-iso shows ISO date" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_declare_options
        get_option() {
            case "$1" in
                format) printf "date-iso" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
}

@test "datetime: format=full returns non-empty string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_declare_options
        get_option() {
            case "$1" in
                format) printf "full" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
}

@test "datetime: plugin_render does NOT contain tmux formatting" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "datetime: plugin_get_icon returns non-empty string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_declare_options
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "icon_ok" || echo "icon_empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon_ok"
}

@test "datetime: plugin_get_context returns time-of-day category" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_declare_options
        echo "context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp 'context=(morning|afternoon|evening|night)'
}

@test "datetime: plugin_get_state always returns active" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_declare_options
        plugin_get_state
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "active"
}

@test "datetime: plugin_get_health always returns ok" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_declare_options
        plugin_get_health
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

@test "datetime: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=datetime"
}

@test "datetime: custom strftime format works" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/datetime.sh"
        _set_plugin_context datetime
        plugin_declare_options
        get_option() {
            case "$1" in
                format) printf '%%Y/%%m/%%d' ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
}
