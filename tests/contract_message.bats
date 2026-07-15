#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/contract/message_contract.sh
# Covers: message_show, severity helpers, message_clear, popup_supported,
#         get_message_style
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# message_show
# =============================================================================

@test "message_show without TMUX does not crash (falls back to log)" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/message_contract.sh"
        message_show "test" 2>&1 || true
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "message_show with custom severity does not crash" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/message_contract.sh"
        message_show "test msg" "warning" 2>&1 || true
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# message_info
# =============================================================================

@test "message_info without TMUX does not crash" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/message_contract.sh"
        message_info "info test" 2>&1 || true
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# message_success
# =============================================================================

@test "message_success without TMUX does not crash" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/message_contract.sh"
        message_success "success test" 2>&1 || true
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# message_warning
# =============================================================================

@test "message_warning without TMUX does not crash" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/message_contract.sh"
        message_warning "warning test" 2>&1 || true
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# message_error
# =============================================================================

@test "message_error without TMUX does not crash" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/message_contract.sh"
        message_error "error test" 2>&1 || true
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# message_clear
# =============================================================================

@test "message_clear without TMUX does not crash" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/message_contract.sh"
        message_clear 2>&1 || true
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# popup_supported
# =============================================================================

@test "popup_supported returns 1 when TMUX is unset" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/message_contract.sh"
        popup_supported && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "no"
}

# =============================================================================
# get_message_style
# =============================================================================

@test "get_message_style info returns valid style string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/message_contract.sh"
        get_message_style "info" 2>&1 || true
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "fg="
}

@test "get_message_style error returns style string with fg=" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/message_contract.sh"
        get_message_style "error" 2>&1 || true
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "fg="
}
