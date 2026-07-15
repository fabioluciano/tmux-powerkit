#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/renderer/entities/windows.sh
# Covers: icon resolution, background colors, state validation
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# resolve_window_icon
# =============================================================================

@test "resolve_window_icon active returns non-empty icon" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        source "$1/src/contract/pane_contract.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/windows.sh"
        load_powerkit_theme
        resolve_window_icon "active" "false"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "resolve_window_icon inactive returns non-empty icon" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        source "$1/src/contract/pane_contract.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/windows.sh"
        load_powerkit_theme
        resolve_window_icon "inactive" "false"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "resolve_window_icon returns zoomed icon when zoomed flag is set" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        source "$1/src/contract/pane_contract.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/windows.sh"
        load_powerkit_theme
        _TMUX_OPTIONS_CACHE["@powerkit_zoomed_window_icon"]="Z"
        resolve_window_icon "active" "true"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "Z"
}

@test "resolve_window_icon zoomed overrides state-specific icon" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        source "$1/src/contract/pane_contract.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/windows.sh"
        load_powerkit_theme
        _TMUX_OPTIONS_CACHE["@powerkit_zoomed_window_icon"]="Z"
        _TMUX_OPTIONS_CACHE["@powerkit_active_window_icon"]="A"
        _TMUX_OPTIONS_CACHE["@powerkit_inactive_window_icon"]="I"
        active_zoom=$(resolve_window_icon "active" "true")
        inactive_zoom=$(resolve_window_icon "inactive" "true")
        [[ "$active_zoom" == "Z" ]] && [[ "$inactive_zoom" == "Z" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "resolve_window_icon custom icons via cache are used when set" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        source "$1/src/contract/pane_contract.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/windows.sh"
        load_powerkit_theme
        _TMUX_OPTIONS_CACHE["@powerkit_active_window_icon"]="▶"
        _TMUX_OPTIONS_CACHE["@powerkit_inactive_window_icon"]="○"
        active_icon=$(resolve_window_icon "active" "false")
        inactive_icon=$(resolve_window_icon "inactive" "false")
        [[ "$active_icon" == "▶" ]] && [[ "$inactive_icon" == "○" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# windows_get_bg
# =============================================================================

@test "windows_get_bg returns non-empty background color" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        source "$1/src/contract/pane_contract.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/windows.sh"
        load_powerkit_theme
        windows_get_bg
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "windows_get_bg returns resolved statusbar-bg" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        source "$1/src/contract/pane_contract.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/windows.sh"
        load_powerkit_theme
        expected=$(resolve_color "statusbar-bg")
        actual=$(windows_get_bg)
        [[ "$expected" == "$actual" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# windows_get_first_bg / windows_get_last_bg
# =============================================================================

@test "windows_get_first_bg returns tmux conditional format string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        source "$1/src/contract/pane_contract.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/windows.sh"
        load_powerkit_theme
        windows_get_first_bg
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "#{?"
}

@test "windows_get_last_bg returns tmux conditional format string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        source "$1/src/contract/pane_contract.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/windows.sh"
        load_powerkit_theme
        windows_get_last_bg
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "#{?"
}

# =============================================================================
# is_valid_window_state (from window_contract.sh)
# =============================================================================

@test "is_valid_window_state active returns 0" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        is_valid_window_state "active"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_window_state inactive returns 0" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        is_valid_window_state "inactive"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_window_state bogus returns 1" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/window_contract.sh"
        is_valid_window_state "bogus"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}
