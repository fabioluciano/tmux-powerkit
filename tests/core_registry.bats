#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/core/registry.sh
# Covers: health functions, validation functions, window icon lookups
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# get_health_level
# =============================================================================

@test "get_health_level ok returns 0" {
    run bash -c 'source "$1/src/core/registry.sh" && get_health_level "ok"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "0"
}

@test "get_health_level error returns 4" {
    run bash -c 'source "$1/src/core/registry.sh" && get_health_level "error"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "4"
}

@test "get_health_level warning returns 3" {
    run bash -c 'source "$1/src/core/registry.sh" && get_health_level "warning"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "3"
}

@test "get_health_level unknown returns 0" {
    run bash -c 'source "$1/src/core/registry.sh" && get_health_level "bogus"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "0"
}

# =============================================================================
# health_is_worse
# =============================================================================

@test "health_is_worse error vs warning returns 0 (error is worse)" {
    run bash -c 'source "$1/src/core/registry.sh" && health_is_worse "error" "warning"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "health_is_worse ok vs warning returns 1 (ok is not worse)" {
    run bash -c 'source "$1/src/core/registry.sh" && health_is_worse "ok" "warning"' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "health_is_worse equal levels returns 1" {
    run bash -c 'source "$1/src/core/registry.sh" && health_is_worse "warning" "warning"' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# health_max
# =============================================================================

@test "health_max ok and error returns error" {
    run bash -c 'source "$1/src/core/registry.sh" && health_max "ok" "error"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "error"
}

@test "health_max info and warning returns warning" {
    run bash -c 'source "$1/src/core/registry.sh" && health_max "info" "warning"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "warning"
}

# =============================================================================
# is_valid_state
# =============================================================================

@test "is_valid_state active returns 0" {
    run bash -c 'source "$1/src/core/registry.sh" && is_valid_state "active"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_state bogus returns 1" {
    run bash -c 'source "$1/src/core/registry.sh" && is_valid_state "bogus"' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# is_valid_health
# =============================================================================

@test "is_valid_health warning returns 0" {
    run bash -c 'source "$1/src/core/registry.sh" && is_valid_health "warning"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_health bogus returns 1" {
    run bash -c 'source "$1/src/core/registry.sh" && is_valid_health "bogus"' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# is_valid_content_type
# =============================================================================

@test "is_valid_content_type dynamic returns 0" {
    run bash -c 'source "$1/src/core/registry.sh" && is_valid_content_type "dynamic"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_content_type invalid returns 1" {
    run bash -c 'source "$1/src/core/registry.sh" && is_valid_content_type "hybrid"' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# is_valid_presence
# =============================================================================

@test "is_valid_presence conditional returns 0" {
    run bash -c 'source "$1/src/core/registry.sh" && is_valid_presence "conditional"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_presence always returns 0" {
    run bash -c 'source "$1/src/core/registry.sh" && is_valid_presence "always"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_presence invalid returns 1" {
    run bash -c 'source "$1/src/core/registry.sh" && is_valid_presence "never"' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# get_window_icon
# =============================================================================

@test "get_window_icon vim returns non-empty icon" {
    run bash -c 'source "$1/src/core/registry.sh" && get_window_icon "vim"' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "get_window_icon unknown command returns default icon" {
    run bash -c 'source "$1/src/core/registry.sh" && get_window_icon "thiscommanddoesnotexist"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "$(bash -c 'source "$1/src/core/registry.sh" && printf "%s" "$WINDOW_DEFAULT_ICON"' _ "$POWERKIT_ROOT")"
}

# =============================================================================
# has_window_icon
# =============================================================================

@test "has_window_icon vim returns 0" {
    run bash -c 'source "$1/src/core/registry.sh" && has_window_icon "vim"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "has_window_icon unknown command returns 1" {
    run bash -c 'source "$1/src/core/registry.sh" && has_window_icon "thiscommanddoesnotexist"' _ "$POWERKIT_ROOT"
    assert_failure
}
