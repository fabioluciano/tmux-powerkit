#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/contract/theme_contract.sh
# Covers: required/optional colors, validation, is_* helpers
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# list_required_theme_colors
# =============================================================================

@test "list_required_theme_colors returns multiple color names" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        list_required_theme_colors
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "statusbar-bg"
    assert_output --partial "statusbar-fg"
    assert_output --partial "session-bg"
    assert_output --partial "error-base"
}

@test "list_required_theme_colors includes specific required color" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        list_required_theme_colors
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "window-active-base"
    assert_output --partial "message-bg"
}

# =============================================================================
# list_optional_theme_colors
# =============================================================================

@test "list_optional_theme_colors returns multiple color names" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        list_optional_theme_colors
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "popup-bg"
    assert_output --partial "selection-fg"
    assert_output --partial "menu-border"
}

@test "list_optional_theme_colors does not include required colors" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        list_optional_theme_colors
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial "statusbar-bg"
}

# =============================================================================
# is_required_theme_color
# =============================================================================

@test "is_required_theme_color statusbar-bg returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        is_required_theme_color "statusbar-bg" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "yes"
}

@test "is_required_theme_color nonexistent returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        is_required_theme_color "nonexistent" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "no"
}

@test "is_required_theme_color session-fg returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        is_required_theme_color "session-fg" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "yes"
}

# =============================================================================
# is_optional_theme_color
# =============================================================================

@test "is_optional_theme_color popup-bg returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        is_optional_theme_color "popup-bg" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "yes"
}

@test "is_optional_theme_color nonexistent returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        is_optional_theme_color "nonexistent" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "no"
}

@test "is_optional_theme_color menu-selected-bg returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        is_optional_theme_color "menu-selected-bg" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "yes"
}

# =============================================================================
# validate_theme
# =============================================================================

@test "validate_theme with real theme file returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        validate_theme "$1/src/themes/tokyo-night/storm.sh" 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "VALID"
}

@test "validate_theme with nonexistent file returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        validate_theme "/nonexistent/path/theme.sh" 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_failure
    assert_output --partial "ERROR"
}

# =============================================================================
# validate_all_themes
# =============================================================================

@test "validate_all_themes with themes dir runs and produces summary" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/theme_contract.sh"
        validate_all_themes "$1/src/themes" 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_output --partial "Total:"
    assert_output --partial "Valid:"
    assert_output --partial "Invalid:"
}
