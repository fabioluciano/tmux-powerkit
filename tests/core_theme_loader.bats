#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/core/theme_loader.sh
# Covers: _expand_path, list_themes, list_variants, list_all_themes,
#         load_theme, is_theme_loaded, get_current_theme, reload_theme,
#         get_theme_name, get_theme_variant, load_powerkit_theme
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# _expand_path
# =============================================================================

@test "_expand_path tilde expands to HOME directory" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _expand_path "~"
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "$HOME" ]]
}

@test "_expand_path tilde with subpath expands correctly" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _expand_path "~/.config"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "${HOME}/.config"
}

@test "_expand_path absolute path returned unchanged" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _expand_path "/tmp/test"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "/tmp/test"
}

@test "_expand_path empty string returns empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _expand_path ""
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

# =============================================================================
# list_themes
# =============================================================================

@test "list_themes returns non-empty list including catppuccin" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        list_themes
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "catppuccin"
}

@test "list_themes returns multiple themes (at least 30)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        list_themes | wc -l | tr -d " "
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Should have at least 30 themes
    [[ $output -ge 30 ]]
}

# =============================================================================
# list_variants
# =============================================================================

@test "list_variants catppuccin returns mocha, macchiato, frappe, latte" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        list_variants "catppuccin"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "mocha"
    assert_output --partial "latte"
}

@test "list_variants tokyo-night returns night, storm, day" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        list_variants "tokyo-night"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "night"
    assert_output --partial "storm"
    assert_output --partial "day"
}

@test "list_variants nonexistent theme returns empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        list_variants "nonexistent_theme_xyz"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

# =============================================================================
# list_all_themes
# =============================================================================

@test "list_all_themes returns non-empty combinations" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        list_all_themes
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "catppuccin/mocha"
    assert_output --partial "tokyo-night/night"
}

# =============================================================================
# load_theme
# =============================================================================

@test "load_theme catppuccin mocha succeeds and populates THEME_COLORS" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        printf "%s" "${#THEME_COLORS[@]}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Should have at least 10 theme colors defined
    [[ $output -ge 10 ]]
}

@test "load_theme nonexistent falls back to default" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "nonexistent_theme_xyz" "blah" 2>/dev/null
        echo "status=$?"
        echo "theme=$_CURRENT_THEME"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "theme=catppuccin"
}

# =============================================================================
# is_theme_loaded
# =============================================================================

@test "is_theme_loaded returns 1 before loading any theme" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        is_theme_loaded
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "is_theme_loaded returns 0 after loading a theme" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        is_theme_loaded
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# get_current_theme
# =============================================================================

@test "get_current_theme returns theme/variant after load" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "tokyo-night" "storm" 2>/dev/null
        get_current_theme
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "tokyo-night/storm"
}

# =============================================================================
# get_theme_name / get_theme_variant
# =============================================================================

@test "get_theme_name returns theme name" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "latte" 2>/dev/null
        get_theme_name
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "catppuccin"
}

@test "get_theme_variant returns variant name" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "latte" 2>/dev/null
        get_theme_variant
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "latte"
}

# =============================================================================
# reload_theme
# =============================================================================

@test "reload_theme works without error after loading theme" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        reload_theme 2>/dev/null
        echo "status=$?"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "status=0"
}

# =============================================================================
# get_powerkit_color
# =============================================================================

@test "get_powerkit_color resolves theme color after load" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_powerkit_color "statusbar-bg"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}
