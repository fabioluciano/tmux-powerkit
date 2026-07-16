#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/core/color_palette.sh
# Covers: get_state_color, get_health_color, get_health_icon_color,
#         get_health_text_color, get_contrast_variant, get_plugin_colors,
#         get_session_mode_color, get_window_colors, get_message_color
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# get_state_color
# =============================================================================

@test "get_state_color active returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_state_color "active"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_state_color inactive returns non-empty hex (differs from active)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        active=$(get_state_color "active")
        inactive=$(get_state_color "inactive")
        echo "active=$active inactive=$active"
        [[ "$active" != "$inactive" ]] && echo "different" || echo "same"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "different"
}

@test "get_state_color degraded returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_state_color "degraded"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_state_color failed returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_state_color "failed"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

# =============================================================================
# get_health_color
# =============================================================================

@test "get_health_color ok returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_health_color "ok"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_health_color error returns non-empty hex (differs from ok)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        ok=$(get_health_color "ok")
        err=$(get_health_color "error")
        [[ "$ok" != "$err" ]] && echo "different" || echo "same"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "different"
}

@test "get_health_color good returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_health_color "good"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_health_color info returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_health_color "info"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_health_color warning returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_health_color "warning"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

# =============================================================================
# get_health_icon_color
# =============================================================================

@test "get_health_icon_color warning returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_health_icon_color "warning"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_health_icon_color returns lighter variant (differs from base)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        base=$(get_health_color "warning")
        icon=$(get_health_icon_color "warning")
        [[ "$base" != "$icon" ]] && echo "different" || echo "same"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "different"
}

# =============================================================================
# get_health_text_color
# =============================================================================

@test "get_health_text_color returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_health_text_color "info"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

# =============================================================================
# get_contrast_variant
# =============================================================================

@test "get_contrast_variant #ffffff returns darkest (white bg needs dark text)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_contrast_variant "#ffffff"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "darkest"
}

@test "get_contrast_variant #000000 returns lightest (black bg needs light text)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_contrast_variant "#000000"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "lightest"
}

@test "get_contrast_variant for dark-gray #555555 returns lightest" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_contrast_variant "#555555"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "lightest"
}

# =============================================================================
# get_plugin_colors
# =============================================================================

@test "get_plugin_colors active ok returns 4 space-separated values" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        cols=$(get_plugin_colors "active" "ok")
        wc=$(echo "$cols" | wc -w | tr -d " ")
        echo "$wc"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "4"
}

@test "get_plugin_colors failed error uses error-base colors" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_plugin_colors "failed" "error"
    ' _ "$POWERKIT_ROOT"
    assert_success
    colors=($output)
    [[ ${#colors[@]} -eq 4 ]]
}

# =============================================================================
# get_session_mode_color
# =============================================================================

@test "get_session_mode_color prefix returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_session_mode_color "prefix"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_session_mode_color normal returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_session_mode_color "normal"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_session_mode_color copy returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_session_mode_color "copy"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

# =============================================================================
# get_window_colors
# =============================================================================

@test "get_window_colors active returns 3 space-separated values" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        cols=$(get_window_colors "active")
        wc=$(echo "$cols" | wc -w | tr -d " ")
        echo "$wc"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "3"
}

@test "get_window_colors inactive returns 3 space-separated values" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        cols=$(get_window_colors "inactive")
        wc=$(echo "$cols" | wc -w | tr -d " ")
        echo "$wc"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "3"
}

@test "get_window_colors active and inactive differ" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        active=$(get_window_colors "active")
        inactive=$(get_window_colors "inactive")
        [[ "$active" != "$inactive" ]] && echo "different" || echo "same"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "different"
}

# =============================================================================
# get_message_color
# =============================================================================

@test "get_message_color error returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_message_color "error"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_message_color info returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_message_color "info"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_message_color success returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_message_color "success"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "get_message_color warning returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_message_color "warning"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

# =============================================================================
# get_window_color (backward compatible)
# =============================================================================

@test "get_window_color active returns non-empty hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        load_theme "catppuccin" "mocha" 2>/dev/null
        get_window_color "active"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}
