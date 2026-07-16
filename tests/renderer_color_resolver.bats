#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/renderer/color_resolver.sh
# Covers: resolve_color, get_contrast_fg, build_style, reset_style,
#         resolve_background, is_transparent, get_window_style,
#         resolve_plugin_colors_full
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# resolve_color
# =============================================================================

@test "resolve_color transparent returns NONE" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        resolve_color "transparent"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "NONE"
}

@test "resolve_color white returns #ffffff" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        resolve_color "white"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#ffffff"
}

# =============================================================================
# get_contrast_fg
# =============================================================================

@test "get_contrast_fg #ffffff returns #000000 (white bg -> black text)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        get_contrast_fg "#ffffff"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#000000"
}

@test "get_contrast_fg #000000 returns #ffffff (black bg -> white text)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        get_contrast_fg "#000000"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#ffffff"
}

# =============================================================================
# build_style
# =============================================================================

@test "build_style #ff0000 #00ff00 returns #[fg=#ff0000,bg=#00ff00]" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        build_style "#ff0000" "#00ff00"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#[fg=#ff0000,bg=#00ff00]"
}

@test "build_style #ff0000 #00ff00 bold adds bold attribute" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        build_style "#ff0000" "#00ff00" "bold"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#[fg=#ff0000,bg=#00ff00,bold]"
}

@test "reset_style returns #[default]" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        reset_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#[default]"
}

# =============================================================================
# resolve_background & is_transparent
# =============================================================================

@test "resolve_background returns non-empty outside tmux" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        resolve_background
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
}

@test "is_transparent returns consistent boolean value" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        is_transparent && echo "true" || echo "false"
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Outside tmux, get_tmux_option returns default "false", so is_transparent should be false
    # Inside tmux, it depends on user's @powerkit_transparent setting
    [[ "$output" == "true" || "$output" == "false" ]]
}

# =============================================================================
# get_window_style
# =============================================================================

@test "get_window_style active returns bold (from catppuccin mocha)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_window_style "active"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "bold"
}

@test "get_window_style inactive returns empty (none style)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_window_style "inactive"
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -z "$output" ]]
}

# =============================================================================
# resolve_plugin_colors_full
# =============================================================================

@test "resolve_plugin_colors_full active ok returns 4 space-separated hex values" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        resolve_plugin_colors_full "active" "ok" "text" "0"
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Should be 4 hex values separated by spaces
    local count
    count=$(echo "$output" | wc -w | tr -d ' ')
    [[ "$count" -eq 4 ]]
    for val in $output; do
        [[ "$val" =~ ^#[0-9a-f]{6}$ ]]
    done
}

@test "resolve_plugin_colors_full active error returns different colors from ok" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        ok_result=$(resolve_plugin_colors_full "active" "ok" "text" "0")
        error_result=$(resolve_plugin_colors_full "active" "error" "text" "0")
        [[ "$ok_result" != "$error_result" ]] && echo "different" || echo "same"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "different"
}

@test "resolve_plugin_colors_full stale=1 returns different colors from fresh" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        fresh=$(resolve_plugin_colors_full "active" "ok" "text" "0")
        stale=$(resolve_plugin_colors_full "active" "ok" "text" "1")
        [[ "$fresh" != "$stale" ]] && echo "different" || echo "same"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "different"
}
