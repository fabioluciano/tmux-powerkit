#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/core/guard.sh
# Covers: source_guard, is_module_loaded, reset_guard, reset_all_guards
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# source_guard
# =============================================================================

@test "source_guard returns 1 on first call (first load)" {
    run bash -c 'source "$1/src/core/guard.sh"; source_guard "mymod"' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "source_guard returns 0 on second call (double-load prevention)" {
    run bash -c 'source "$1/src/core/guard.sh"; source_guard "mymod"; source_guard "mymod"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "source_guard with empty module name does not crash" {
    run bash -c 'source "$1/src/core/guard.sh"; source_guard ""' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# is_module_loaded
# =============================================================================

@test "is_module_loaded returns 0 when module is loaded" {
    run bash -c 'source "$1/src/core/guard.sh"; source_guard "mymod" >/dev/null 2>&1; is_module_loaded "mymod"' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_module_loaded returns 1 when module is not loaded" {
    run bash -c 'source "$1/src/core/guard.sh"; is_module_loaded "nonexistent"' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# reset_guard
# =============================================================================

@test "reset_guard removes guard for a specific module" {
    run bash -c 'source "$1/src/core/guard.sh"; source_guard "mymod" >/dev/null 2>&1; reset_guard "mymod"; is_module_loaded "mymod"' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "reset_guard does not affect other module guards" {
    run bash -c 'source "$1/src/core/guard.sh"; source_guard "mod_a" >/dev/null 2>&1; source_guard "mod_b" >/dev/null 2>&1; reset_guard "mod_a"; is_module_loaded "mod_b"' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# reset_all_guards
# =============================================================================

@test "reset_all_guards clears all guards" {
    run bash -c 'source "$1/src/core/guard.sh"; source_guard "mod_a" >/dev/null 2>&1; source_guard "mod_b" >/dev/null 2>&1; reset_all_guards; is_module_loaded "mod_a"' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "reset_all_guards clears all guards including second module" {
    run bash -c 'source "$1/src/core/guard.sh"; source_guard "mod_a" >/dev/null 2>&1; source_guard "mod_b" >/dev/null 2>&1; reset_all_guards; is_module_loaded "mod_b"' _ "$POWERKIT_ROOT"
    assert_failure
}
