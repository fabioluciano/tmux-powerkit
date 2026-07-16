#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/core/color_generator.sh
# Covers: hex/RGB conversion, clamp, color_lighter, color_darker,
#         get_color, has_color, generate_color_variants,
#         serialize_theme_colors, clear_color_variants
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# _hex_to_rgb
# =============================================================================

@test "_hex_to_rgb parses #ff0000 to 255 0 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _hex_to_rgb "#ff0000"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "255 0 0"
}

@test "_hex_to_rgb parses #abcdef to correct decimal values" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _hex_to_rgb "#abcdef"
    ' _ "$POWERKIT_ROOT"
    assert_success
    # 0xab=171, 0xcd=205, 0xef=239
    assert_output "171 205 239"
}

@test "_hex_to_rgb returns 0 0 0 and exit 1 for invalid hex" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _hex_to_rgb "notacolor" 2>/dev/null
    ' _ "$POWERKIT_ROOT"
    assert_failure
    assert_output "0 0 0"
}

# =============================================================================
# _rgb_to_hex
# =============================================================================

@test "_rgb_to_hex converts 255 85 0 to #ff5500" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _rgb_to_hex 255 85 0
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#ff5500"
}

# =============================================================================
# _clamp
# =============================================================================

@test "_clamp 150 returns 150 (within bounds)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _clamp 150
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "150"
}

@test "_clamp 300 returns 255 (upper bound)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _clamp 300
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "255"
}

@test "_clamp -50 returns 0 (lower bound)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _clamp -50
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "0"
}

# =============================================================================
# color_lighter
# =============================================================================

@test "color_lighter #ff0000 20 makes red lighter (#ff3333)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        color_lighter "#ff0000" 20
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#ff3333"
}

@test "color_lighter #000000 20 becomes #333333 (moves toward white)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        color_lighter "#000000" 20
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#333333"
}

# =============================================================================
# color_darker
# =============================================================================

@test "color_darker #ff0000 20 makes red darker (#cb0000)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        color_darker "#ff0000" 20
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#cb0000"
}

@test "color_darker #ffffff 20 becomes #cbcbcb" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        color_darker "#ffffff" 20
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#cbcbcb"
}

# =============================================================================
# get_color (universal colors)
# =============================================================================

@test "get_color transparent returns NONE" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_color "transparent"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "NONE"
}

@test "get_color white returns #ffffff" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_color "white"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#ffffff"
}

@test "get_color black returns #000000" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_color "black"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#000000"
}

@test "get_color nonexistent returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_color "nonexistent_color" 2>/dev/null
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# has_color
# =============================================================================

@test "has_color white returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        has_color "white"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "has_color nonexistent returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        has_color "nonexistent_color"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# generate_color_variants / serialize_theme_colors / clear_color_variants
# =============================================================================

@test "generate_color_variants runs without error with populated THEME_COLORS" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        THEME_COLORS=(
            [ok-base]="#45475a"
            [warning-base]="#f9e2af"
            [error-base]="#f38ba8"
            [info-base]="#89b4fa"
            [good-base]="#a6e3a1"
            [disabled-base]="#6c7086"
            [window-active-base]="#f5c2e7"
            [window-inactive-base]="#45475a"
        )
        generate_color_variants
        printf "%s" "${_COLOR_VARIANTS[ok-base-lighter]}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_regex "$output" '^#[0-9a-f]{6}$'
}

@test "serialize_theme_colors produces non-empty output" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        THEME_COLORS=(
            [ok-base]="#45475a"
            [warning-base]="#f9e2af"
        )
        generate_color_variants
        result=$(serialize_theme_colors)
        [[ -n "$result" ]] && echo "nonempty" || echo "empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "nonempty"
}

@test "serialize_theme_colors output contains ok-base=..." {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        THEME_COLORS=(
            [ok-base]="#45475a"
            [warning-base]="#f9e2af"
        )
        generate_color_variants
        serialize_theme_colors
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == *"ok-base=#45475a"* ]]
}

@test "clear_color_variants empties _COLOR_VARIANTS" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        THEME_COLORS=(
            [ok-base]="#45475a"
        )
        generate_color_variants
        variants_before="${#_COLOR_VARIANTS[@]}"
        clear_color_variants
        variants_after="${#_COLOR_VARIANTS[@]}"
        echo "before=$variants_before after=$variants_after"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "before=6 after=0"
}

@test "deserialize_theme_colors restores colors from serialized string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        THEME_COLORS=(
            [ok-base]="#45475a"
            [warning-base]="#f9e2af"
        )
        generate_color_variants
        serialized=$(serialize_theme_colors)
        THEME_COLORS=()
        clear_color_variants
        deserialize_theme_colors "$serialized"
        echo "${THEME_COLORS[ok-base]}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#45475a"
}
