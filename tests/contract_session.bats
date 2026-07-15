#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/contract/session_contract.sh
# Covers: icon resolution, mode format, color format, mode validation,
#         batch operations (session_get_all without tmux)
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# session_get_icon_for_mode
# =============================================================================

@test "session_get_icon_for_mode normal returns a non-empty icon" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "normal"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "session_get_icon_for_mode prefix returns a non-empty icon" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "prefix"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "session_get_icon_for_mode copy returns a non-empty icon" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "copy"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "session_get_icon_for_mode command returns a non-empty icon" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "command"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "session_get_icon_for_mode search returns a non-empty icon" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "search"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "session_get_icon_for_mode returns different icons for prefix vs normal" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "normal"
    ' _ "$POWERKIT_ROOT"
    assert_success
    local normal_icon="$output"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "prefix"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output "$normal_icon"
}

@test "session_get_icon_for_mode returns different icons for normal vs copy" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "normal"
    ' _ "$POWERKIT_ROOT"
    assert_success
    local normal_icon="$output"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "copy"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output "$normal_icon"
}

@test "session_get_icon_for_mode unknown mode falls back to normal icon" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "normal"
    ' _ "$POWERKIT_ROOT"
    assert_success
    local normal_icon="$output"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_icon_for_mode "bogus"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "$normal_icon"
}

# =============================================================================
# session_get_mode_format
# =============================================================================

@test "session_get_mode_format returns tmux conditional format string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_mode_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "#{?client_prefix"
}

@test "session_get_mode_format contains mode placeholders" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_mode_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "PREFIX"
    assert_output --partial "SEARCH"
    assert_output --partial "COPY"
}

# =============================================================================
# session_get_color_format
# =============================================================================

@test "session_get_color_format returns tmux format with color placeholders" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_color_format "red" "blue" "green"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#{?client_prefix,blue,#{?pane_in_mode,green,red}}"
}

@test "session_get_color_format supports arbitrary color strings" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_color_format "#1a1b26" "#7aa2f7" "#bb9af7"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "#{?client_prefix,#7aa2f7,#{?pane_in_mode,#bb9af7,#1a1b26}}"
}

# =============================================================================
# is_valid_mode
# =============================================================================

@test "is_valid_mode normal returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        is_valid_mode "normal"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_mode prefix returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        is_valid_mode "prefix"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_mode copy returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        is_valid_mode "copy"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_mode command returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        is_valid_mode "command"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_mode search returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        is_valid_mode "search"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_mode bogus returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        is_valid_mode "bogus"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# session_get_state (without tmux)
# =============================================================================

@test "session_get_state without tmux returns detached" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_state
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "detached"
}

# =============================================================================
# session_get_mode (without tmux)
# =============================================================================

@test "session_get_mode without tmux returns normal" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_mode
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "normal"
}

# =============================================================================
# session_get_name (without tmux)
# =============================================================================

@test "session_get_name without tmux returns tmux" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_get_name
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "tmux"
}

# =============================================================================
# session_render (without tmux)
# =============================================================================

@test "session_render without tmux returns tmux" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        session_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "tmux"
}

# =============================================================================
# session_get_all (without tmux)
# =============================================================================

@test "session_get_all without tmux returns defaults without crashing" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        eval "$(session_get_all)"
        printf "STATE=%s MODE=%s NAME=%s" "$SESSION_STATE" "$SESSION_MODE" "$SESSION_NAME"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "STATE=detached MODE=normal NAME=tmux"
}

@test "session_get_all without tmux exports SESSION_ICON" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        eval "$(session_get_all)"
        [[ -n "$SESSION_ICON" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "session_get_all without tmux exports empty SESSION_CONTEXT" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/session_contract.sh"
        eval "$(session_get_all)"
        [[ -z "$SESSION_CONTEXT" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}
