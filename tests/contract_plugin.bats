#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/contract/plugin_contract.sh
# Covers: threshold evaluation helpers, dependency checking helpers,
#         platform helpers, icon selection helpers, context helpers
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# evaluate_threshold_health
# =============================================================================

@test "evaluate_threshold_health 50 70 90 0 returns ok (below warn)" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && evaluate_threshold_health 50 70 90 0' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

@test "evaluate_threshold_health 80 70 90 0 returns warning (above warn, below crit)" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && evaluate_threshold_health 80 70 90 0' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "warning"
}

@test "evaluate_threshold_health 95 70 90 0 returns error (above crit)" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && evaluate_threshold_health 95 70 90 0' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "error"
}

@test "evaluate_threshold_health 85 30 15 1 returns ok (invert: high value is good)" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && evaluate_threshold_health 85 30 15 1' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

@test "evaluate_threshold_health 10 30 15 1 returns error (invert: low value is critical)" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && evaluate_threshold_health 10 30 15 1' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "error"
}

@test "evaluate_threshold_health 15 30 15 1 returns error (invert: equal to crit)" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && evaluate_threshold_health 15 30 15 1' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "error"
}

# =============================================================================
# evaluate_threshold_health_float
# =============================================================================

@test "evaluate_threshold_health_float 50.5 70.0 90.0 0 returns ok" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && evaluate_threshold_health_float 50.5 70.0 90.0 0' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

@test "evaluate_threshold_health_float 85.0 70.0 90.0 0 returns warning" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && evaluate_threshold_health_float 85.0 70.0 90.0 0' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "warning"
}

# =============================================================================
# require_cmd
# =============================================================================

@test "require_cmd returns 0 for commands in PATH" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && require_cmd "bash"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "require_cmd returns 1 for missing commands" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && require_cmd "nonexistent_cmd_xyz"' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "require_cmd optional missing logs but returns 0" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && require_cmd "nonexistent_cmd_xyz" 1' _ "$POWERKIT_ROOT"
    assert_success
}

@test "require_cmd optional present returns 0" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && require_cmd "bash" 1' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# require_any_cmd
# =============================================================================

@test "require_any_cmd returns 0 when at least one command exists" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && require_any_cmd "bash" "zsh"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "require_any_cmd returns 1 when none of the commands exist" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && require_any_cmd "nonexistent_cmd_xyz" "also_fake"' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# check_dependencies
# =============================================================================

@test "check_dependencies returns 0 when all exist" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && check_dependencies "bash" "pwd"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "check_dependencies returns 1 when any command is missing" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && check_dependencies "bash" "nonexistent_cmd_xyz"' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# reset_dependency_check
# =============================================================================

@test "reset_dependency_check clears dependency tracking arrays" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        _MISSING_DEPS=("dep1" "dep2")
        _MISSING_OPTIONAL_DEPS=("opt1")
        reset_dependency_check
        [[ ${#_MISSING_DEPS[@]} -eq 0 && ${#_MISSING_OPTIONAL_DEPS[@]} -eq 0 ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "reset_dependency_check also resets required/optional tracking arrays" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        _REQUIRED_DEPS=("dep1")
        _OPTIONAL_DEPS=("opt1")
        reset_dependency_check
        [[ ${#_REQUIRED_DEPS[@]} -eq 0 && ${#_OPTIONAL_DEPS[@]} -eq 0 ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# get_missing_deps / get_missing_optional_deps
# =============================================================================

@test "get_missing_deps returns missing required deps after failed require_cmd" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        reset_dependency_check
        require_cmd "nonexistent_cmd_xyz" 2>/dev/null || true
        deps=$(get_missing_deps)
        [[ "$deps" == "nonexistent_cmd_xyz" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "get_missing_optional_deps returns missing optional deps" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        reset_dependency_check
        require_cmd "nonexistent_cmd_xyz" 1
        deps=$(get_missing_optional_deps)
        [[ "$deps" == "nonexistent_cmd_xyz" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# get_platform_value
# =============================================================================

@test "get_platform_value returns correct OS-specific value" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && get_platform_value "macos_val" "linux_val"' _ "$POWERKIT_ROOT"
    assert_success
    if [[ "$(uname -s)" == "Darwin" ]]; then
        assert_output "macos_val"
    else
        assert_output "linux_val"
    fi
}

@test "get_platform_value with freebsd value falls back to linux on macOS/Linux" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && get_platform_value "mac" "lin" "bsd"' _ "$POWERKIT_ROOT"
    assert_success
    if [[ "$(uname -s)" == "Darwin" ]]; then
        assert_output "mac"
    else
        assert_output "lin"
    fi
}

# =============================================================================
# require_platform
# =============================================================================

@test "require_platform returns 0 for current OS" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        current=$(get_os)
        require_platform "$current"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "require_platform returns 1 for non-matching OS" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        current=$(get_os)
        case "$current" in
            darwin) other="linux" ;;
            linux)  other="darwin" ;;
            *)      other="nonexistent" ;;
        esac
        require_platform "$other"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# run_platform_func
# =============================================================================

@test "run_platform_func calls the correct platform function" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        _macos_func() { printf "ran_macos"; }
        _linux_func() { printf "ran_linux"; }
        result=$(run_platform_func "_macos_func" "_linux_func")
        if is_macos; then
            [[ "$result" == "ran_macos" ]]
        else
            [[ "$result" == "ran_linux" ]]
        fi
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# plugin_get_icon_by_state
# =============================================================================

@test "plugin_get_icon_by_state with truthy string returns on icon" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        get_option() {
            case "$1" in
                icon_on) printf "ICON_ON" ;;
                icon_off) printf "ICON_OFF" ;;
                icon) printf "ICON_DEFAULT" ;;
                *) printf "" ;;
            esac
        }
        plugin_get_icon_by_state 1 "icon_on" "icon_off" "icon"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ICON_ON"
}

@test "plugin_get_icon_by_state with false string returns off icon" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        get_option() {
            case "$1" in
                icon_on) printf "ICON_ON" ;;
                icon_off) printf "ICON_OFF" ;;
                icon) printf "ICON_DEFAULT" ;;
                *) printf "" ;;
            esac
        }
        plugin_get_icon_by_state 0 "icon_on" "icon_off" "icon"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ICON_OFF"
}

@test "plugin_get_icon_by_state with true/yes also returns on icon" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        get_option() {
            case "$1" in
                icon_on) printf "ON" ;;
                icon_off) printf "OFF" ;;
                icon) printf "DEFAULT" ;;
                *) printf "" ;;
            esac
        }
        result_a=$(plugin_get_icon_by_state "true" "icon_on" "icon_off" "icon")
        result_b=$(plugin_get_icon_by_state "yes" "icon_on" "icon_off" "icon")
        [[ "$result_a" == "ON" && "$result_b" == "ON" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "plugin_get_icon_by_state with neutral value returns default icon" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        get_option() {
            case "$1" in
                icon_on) printf "ON" ;;
                icon_off) printf "OFF" ;;
                icon) printf "DEFAULT" ;;
                *) printf "" ;;
            esac
        }
        plugin_get_icon_by_state "unknown" "icon_on" "icon_off" "icon"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "DEFAULT"
}

# =============================================================================
# plugin_get_icon_by_range
# =============================================================================

@test "plugin_get_icon_by_range low value returns critical icon" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        get_option() {
            case "$1" in
                icon_critical) printf "CRIT" ;;
                icon_warning) printf "WARN" ;;
                icon) printf "DEFAULT" ;;
                *) printf "" ;;
            esac
        }
        plugin_get_icon_by_range 5 "15:icon_critical" "30:icon_warning" "icon"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "CRIT"
}

@test "plugin_get_icon_by_range mid value returns warning icon" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        get_option() {
            case "$1" in
                icon_critical) printf "CRIT" ;;
                icon_warning) printf "WARN" ;;
                icon) printf "DEFAULT" ;;
                *) printf "" ;;
            esac
        }
        plugin_get_icon_by_range 25 "15:icon_critical" "30:icon_warning" "icon"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "WARN"
}

@test "plugin_get_icon_by_range high value returns default icon" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        get_option() {
            case "$1" in
                icon_critical) printf "CRIT" ;;
                icon_warning) printf "WARN" ;;
                icon) printf "DEFAULT" ;;
                *) printf "" ;;
            esac
        }
        plugin_get_icon_by_range 50 "15:icon_critical" "30:icon_warning" "icon"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "DEFAULT"
}

@test "plugin_get_icon_by_range value equal to threshold returns that threshold icon" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        get_option() {
            case "$1" in
                icon_critical) printf "CRIT" ;;
                icon_warning) printf "WARN" ;;
                icon) printf "DEFAULT" ;;
                *) printf "" ;;
            esac
        }
        # value=15 exactly equals first threshold
        plugin_get_icon_by_range 15 "15:icon_critical" "30:icon_warning" "icon"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "CRIT"
}

# =============================================================================
# plugin_context_from_health
# =============================================================================

@test "plugin_context_from_health error returns prefix_error" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_health "error" "cpu"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "cpu_error"
}

@test "plugin_context_from_health warning returns prefix_warning" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_health "warning" "cpu"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "cpu_warning"
}

@test "plugin_context_from_health info returns prefix_info" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_health "info" "cpu"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "cpu_info"
}

@test "plugin_context_from_health good returns prefix_good" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_health "good" "cpu"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "cpu_good"
}

@test "plugin_context_from_health ok returns prefix_ok" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_health "ok" "cpu"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "cpu_ok"
}

@test "plugin_context_from_health uses default prefix when not provided" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_health "ok"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "state_ok"
}

# =============================================================================
# plugin_context_from_state
# =============================================================================

@test "plugin_context_from_state 1 returns connected" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_state 1 "connected" "disconnected"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "connected"
}

@test "plugin_context_from_state 0 returns disconnected" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_state 0 "connected" "disconnected"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "disconnected"
}

@test "plugin_context_from_state true returns connected" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_state "true" "connected" "disconnected"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "connected"
}

@test "plugin_context_from_state false returns disconnected" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_state "false" "connected" "disconnected"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "disconnected"
}

# =============================================================================
# plugin_context_from_value
# =============================================================================

@test "plugin_context_from_value charging returns charging" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_value "charging" "charging:charging" "discharging:on_battery" "unknown"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "charging"
}

@test "plugin_context_from_value discharging returns on_battery" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_value "discharging" "charging:charging" "discharging:on_battery" "unknown"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "on_battery"
}

@test "plugin_context_from_value unmatched value returns default" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_context_from_value "unknown_status" "charging:charging" "discharging:on_battery" "unknown"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "unknown"
}

# =============================================================================
# Default function implementations
# =============================================================================

@test "default plugin_get_content_type returns dynamic" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_get_content_type' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "dynamic"
}

@test "default plugin_get_presence returns conditional" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_get_presence' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "conditional"
}

@test "default plugin_check_dependencies returns 0" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_check_dependencies' _ "$POWERKIT_ROOT"
    assert_success
}

@test "default plugin_get_metadata returns nothing" {
    run bash -c 'source "$1/src/contract/plugin_contract.sh" && plugin_get_metadata' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}
