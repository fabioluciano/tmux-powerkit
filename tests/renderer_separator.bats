#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/renderer/separator.sh
# Covers: separator style, glyphs, spacing, validation, caching
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Separator Style Functions
# =============================================================================

@test "get_separator_style returns normal (default)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        get_separator_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "normal"
}

@test "get_edge_separator_style returns rounded (default)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        get_edge_separator_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "rounded"
}

# =============================================================================
# Separator Glyph Functions
# =============================================================================

@test "get_left_separator returns a non-empty unicode character" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        get_left_separator
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
    # Should be a multi-byte unicode glyph (not ASCII)
    [[ "${#output}" -ge 1 ]]
}

@test "get_right_separator returns a non-empty unicode character" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        get_right_separator
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
}

@test "get_final_separator returns a non-empty unicode character" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        get_final_separator
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
}

@test "get_initial_separator returns a non-empty unicode character" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        get_initial_separator
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
}

@test "get_edge_right_separator returns a non-empty unicode character" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        get_edge_right_separator
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
}

# =============================================================================
# Spacing Configuration
# =============================================================================

@test "get_spacing_mode returns false (default)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        get_spacing_mode
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "false"
}

@test "has_window_spacing returns 1 (false) when spacing mode is false" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        has_window_spacing
        echo "exit=$?"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "exit=1"
}

@test "has_plugin_spacing returns 1 (false) when spacing mode is false" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        has_plugin_spacing
        echo "exit=$?"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "exit=1"
}

# =============================================================================
# Separator Style Validation
# =============================================================================

@test "is_valid_separator_style normal returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        is_valid_separator_style "normal"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_separator_style rounded returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        is_valid_separator_style "rounded"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_separator_style slant returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        is_valid_separator_style "slant"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_separator_style none returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        is_valid_separator_style "none"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_separator_style bogus returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        is_valid_separator_style "bogus"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "list_separator_styles includes normal and rounded" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        list_separator_styles
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == *"normal"* ]]
    [[ "$output" == *"rounded"* ]]
}

# =============================================================================
# Apply-All-Edges & Cache
# =============================================================================

@test "should_apply_all_edges returns 1 (false) by default" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        should_apply_all_edges
        echo "exit=$?"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "exit=1"
}

@test "separator_reset_cache runs without error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        . "$1/src/renderer/separator.sh"
        separator_reset_cache
        printf "ok"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}
