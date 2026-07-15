#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/contract/helper_contract.sh
# Covers: metadata, dispatch, dependency checks, display, formatting, cache
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# helper_metadata_set / helper_metadata_get
# =============================================================================

@test "helper_metadata_set and helper_metadata_get store and retrieve values" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_metadata_set "key" "value"
        helper_metadata_get "key"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "value"
}

@test "helper_metadata_get returns empty for nonexistent key" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_metadata_get "nonexistent"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

# =============================================================================
# helper_dispatch --help
# =============================================================================

@test "helper_dispatch --help prints help and exits 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_dispatch --help 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "Usage"
    assert_output --partial "help"
}

# =============================================================================
# helper_require
# =============================================================================

@test "helper_require bash returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_require "bash" 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "helper_require nonexistent_cmd returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_require "nonexistent_cmd_xyz" 2>&1 < /dev/null
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# helper_require_selector
# =============================================================================

@test "helper_require_selector returns 0 (basic always available)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_require_selector 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# helper_show_error / warning / success
# =============================================================================

@test "helper_show_error prints error formatted" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_show_error "test msg" 2>&1 < /dev/null || true
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "test msg"
}

@test "helper_show_warning prints warning formatted" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_show_warning "test msg" 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "test msg"
}

@test "helper_show_success prints success formatted" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_show_success "test msg" 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "test msg"
}

# =============================================================================
# helper_print_header / helper_print_separator
# =============================================================================

@test "helper_print_header prints formatted header" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_print_header "title" 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "title"
}

@test "helper_print_separator prints separator line" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        helper_print_separator 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "─"
}

# =============================================================================
# helper_get_cache_dir / helper_get_cache_file
# =============================================================================

@test "helper_get_cache_dir returns non-empty path" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        HELPER_SCRIPT_NAME="testhelper"
        helper_get_cache_dir 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "testhelper"
}

@test "helper_get_cache_file returns file path" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/helper_contract.sh"
        HELPER_SCRIPT_NAME="testhelper"
        helper_get_cache_file "test.txt" 2>&1
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "testhelper"
    assert_output --partial "test.txt"
}
