#!/usr/bin/env bash
# =============================================================================
# PowerKit Test Helper
# Description: Shared setup/teardown helpers for bats tests
# Loads bats-support and bats-assert for assertions
# =============================================================================

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Resolve project root (one level up from tests/) regardless of PWD.
# Bats changes CWD to the test file's directory, so we walk up from BATS_TEST_FILENAME.
setup_test_root() {
    export POWERKIT_ROOT
    POWERKIT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME:-$(pwd)}")/.." && pwd)"
}

# Create an isolated temporary directory for the current test.
# Exported so sourced libraries can see it via $TEST_TMPDIR.
setup_test_tmp() {
    export TEST_TMPDIR
    TEST_TMPDIR="$(mktemp -d)"
}

# Recursively remove the temporary directory created by setup_test_tmp.
teardown_test_tmp() {
    [[ -n "${TEST_TMPDIR:-}" ]] || return 0
    [[ -d "$TEST_TMPDIR" ]] || {
        unset TEST_TMPDIR
        return 0
    }
    rm -rf "$TEST_TMPDIR"
    unset TEST_TMPDIR
}
