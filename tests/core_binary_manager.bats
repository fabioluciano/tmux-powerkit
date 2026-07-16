#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/core/binary_manager.sh (pure logic only)
# Covers: binary_get_arch_suffix, binary_has_missing, binary_get_missing,
#         binary_clear_decision, binary_exists
#
# NOTE: Functions that download binaries or prompt users are NOT tested here.
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# binary_get_arch_suffix
# =============================================================================

@test "binary_get_arch_suffix returns non-empty architecture string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        suffix=$(binary_get_arch_suffix)
        printf "%s" "$suffix"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "binary_get_arch_suffix returns darwin- prefix on macOS" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        suffix=$(binary_get_arch_suffix)
        printf "%s" "${suffix%%-*}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "darwin"
}

# =============================================================================
# binary_has_missing
# =============================================================================

@test "binary_has_missing returns 1 when no missing binaries tracked" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        binary_has_missing
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# binary_get_missing
# =============================================================================

@test "binary_get_missing returns empty when no missing binaries tracked" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        binary_get_missing
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

# =============================================================================
# binary_clear_decision
# =============================================================================

@test "binary_clear_decision does not crash" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        binary_clear_decision "test-binary"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "binary_clear_all_decisions does not crash" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        binary_clear_all_decisions
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# binary_exists
# =============================================================================

@test "binary_exists returns 0 for existing executable binary" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        mkdir -p "$2/bin"
        touch "$2/bin/test-binary"
        chmod +x "$2/bin/test-binary"
        _BINARY_DIR="$2/bin"
        binary_exists "test-binary"
    ' _ "$POWERKIT_ROOT" "$BATS_TEST_TMPDIR"
    assert_success
}

@test "binary_exists returns 1 for non-existent binary" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        binary_exists "nonexistent-binary-xyzzy"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}
