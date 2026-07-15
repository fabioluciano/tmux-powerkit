#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/contract/window_contract.sh
# Covers: format builders, state indicators, icon resolution, validation
#
# All tests run via bootstrap so core modules (options, registry, utils)
# are available. Window functions are format string generators for tmux
# and do not require a running tmux session.
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# window_index_format
# =============================================================================

@test "window_index_format returns #{window_index}" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_index_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{window_index}'
}

# =============================================================================
# window_name_format
# =============================================================================

@test "window_name_format returns #{window_name}" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_name_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{window_name}'
}

# =============================================================================
# window_flags_format
# =============================================================================

@test "window_flags_format returns #{window_flags}" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_flags_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{window_flags}'
}

# =============================================================================
# window_basic_format
# =============================================================================

@test "window_basic_format returns #{window_index}:#{window_name}" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_basic_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{window_index}:#{window_name}'
}

# =============================================================================
# window_zoom_format — default args
# =============================================================================

@test "window_zoom_format default returns zoom conditional with Z" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_zoom_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{?window_zoomed_flag,[Z],}'
}

# =============================================================================
# window_zoom_format — custom args
# =============================================================================

@test "window_zoom_format with custom icon returns zoom conditional with custom" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_zoom_format "🔍" ""
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{?window_zoomed_flag,🔍,}'
}

# =============================================================================
# window_activity_format
# =============================================================================

@test "window_activity_format returns activity conditional with exclamation" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_activity_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{?window_activity_flag,!,}'
}

# =============================================================================
# window_bell_format
# =============================================================================

@test "window_bell_format returns bell conditional with B" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_bell_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{?window_bell_flag,B,}'
}

# =============================================================================
# window_last_format
# =============================================================================

@test "window_last_format returns last conditional with dash" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_last_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{?window_last_flag,-,}'
}

# =============================================================================
# window_state_indicators
# =============================================================================

@test "window_state_indicators returns combined zoom+activity+bell conditionals" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_state_indicators
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial '#{?window_zoomed_flag'
    assert_output --partial '#{?window_activity_flag'
    assert_output --partial '#{?window_bell_flag'
}

# =============================================================================
# window_get_simple_icon — active
# =============================================================================

@test "window_get_simple_icon 1 returns active window icon when set" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        # Mock tmux options via internal cache
        _TMUX_OPTIONS_CACHE["@powerkit_active_window_icon"]="▶"
        _TMUX_OPTIONS_CACHE["@powerkit_inactive_window_icon"]="○"
        window_get_simple_icon "1"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "▶"
}

# =============================================================================
# window_get_simple_icon — inactive
# =============================================================================

@test "window_get_simple_icon 0 returns inactive window icon when set" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        # Mock tmux options via internal cache
        _TMUX_OPTIONS_CACHE["@powerkit_active_window_icon"]="▶"
        _TMUX_OPTIONS_CACHE["@powerkit_inactive_window_icon"]="○"
        window_get_simple_icon "0"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "○"
}

# =============================================================================
# window_get_simple_icon — no icons set
# =============================================================================

@test "window_get_simple_icon returns empty when no custom icons configured" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_get_simple_icon "1"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

@test "window_get_simple_icon 0 returns empty when no custom icons configured" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_get_simple_icon "0"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

# =============================================================================
# is_valid_window_state
# =============================================================================

@test "is_valid_window_state active returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        is_valid_window_state "active"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_window_state inactive returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        is_valid_window_state "inactive"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_window_state bogus returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        is_valid_window_state "bogus"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# window_get_index_display
# =============================================================================

@test "window_get_index_display returns format string with tmux conditionals" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_get_index_display
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    # When TMUX is unset, default style is "text" which returns #{window_index}
    assert_output '#{window_index}'
}

# =============================================================================
# window_get_icon_format
# =============================================================================

@test "window_get_icon_format returns non-empty conditional format" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_get_icon_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    # Should contain pane_current_command conditionals
    assert_output --partial '#{?#{=='
    assert_output --partial '#{pane_current_command}'
}

# =============================================================================
# window_get_active_format
# =============================================================================

@test "window_get_active_format returns non-empty format string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_get_active_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    # Should contain tmux format references
    assert_output --partial '#{'
}

# =============================================================================
# window_get_inactive_format
# =============================================================================

@test "window_get_inactive_format returns non-empty format string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        window_get_inactive_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial '#{'
}
