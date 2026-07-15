#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/utils/keybinding.sh (pure logic only)
# Covers: pk_bind_shell, pk_bind_popup, pk_bind_shell_root,
#         pk_bind_popup_root, pk_bind_message, pk_bind_smart
#
# These tests verify ONLY the parts that don't require tmux:
#   - Early returns on empty key
#   - Functions are properly declared
#   - Mock tmux verifies argument passing
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Function Declaration Checks
# =============================================================================

@test "keybinding functions are declared" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        for fn in pk_bind_shell pk_bind_shell_root pk_bind_popup pk_bind_popup_root pk_bind_message pk_bind_smart; do
            declare -F "$fn" >/dev/null || { echo "MISSING: $fn"; exit 1; }
        done
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# Early Return Tests (empty key → returns 0, no tmux call)
# =============================================================================

@test "pk_bind_shell empty key returns 0" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        pk_bind_shell "" "test command"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "pk_bind_popup empty key returns 0" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        pk_bind_popup "" "test command"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "pk_bind_shell_root empty key returns 0" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        pk_bind_shell_root "" "test command"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "pk_bind_popup_root empty key returns 0" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        pk_bind_popup_root "" "test command"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "pk_bind_message empty key returns 0" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        pk_bind_message "" "test message"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "pk_bind_smart empty key returns 0" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        pk_bind_smart "" "test command"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# Mock tmux — verify functions pass the correct key to tmux
# =============================================================================

@test "pk_bind_shell with key calls tmux bind-key" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        tmux() { echo "tmux:$*"; }
        pk_bind_shell "C-x" "echo hello"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "tmux:bind-key"
}

@test "pk_bind_popup with key calls tmux display-popup" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        tmux() { echo "tmux:$*"; }
        pk_bind_popup "C-e" "bash script.sh"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "display-popup"
}
