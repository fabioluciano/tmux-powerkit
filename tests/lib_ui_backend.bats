#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/utils/ui_backend.sh (backend detection only)
# Covers: ui_get_backend, ui_detect_backend, ui_has_backend,
#         ui_reset_backend_cache, toast, ui_toast
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Backend Detection
# =============================================================================

@test "ui_detect_backend returns a valid backend name" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        backend=$(ui_detect_backend)
        echo "$backend"
        case "$backend" in
            gum|fzf|basic) exit 0 ;;
            *) exit 1 ;;
        esac
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "ui_get_backend returns a non-empty string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        ui_get_backend
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "ui_has_backend basic returns 0" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        ui_has_backend "basic"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "ui_has_backend missing returns 1" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        ui_has_backend "nonexistent_backend_xyz"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# Cache Management
# =============================================================================

@test "ui_reset_backend_cache does not error" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        ui_get_backend >/dev/null       # populate cache
        ui_reset_backend_cache
        ui_get_backend >/dev/null       # re-detect after reset
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# Toast (no TMUX — graceful handling)
# =============================================================================

@test "toast message without TMUX does not crash" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        toast "test message" 2>/dev/null || true
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "ui_toast message without TMUX does not crash" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        ui_toast "test message" "info" 2>/dev/null || true
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "toast empty message returns early" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        toast "" 2>/dev/null
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "ui_toast empty message returns early" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh" 2>/dev/null
        ui_toast "" "info" 2>/dev/null
    ' _ "$POWERKIT_ROOT"
    assert_success
}
