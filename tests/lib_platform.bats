#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/utils/platform.sh
# Covers: get_os, is_macos, is_linux, has_cmd, get_arch,
#         is_in_tmux, get_terminal
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# get_os / is_macos / is_linux
# =============================================================================

@test "get_os returns a non-empty lowercase string" {
    run bash -c 'source "$1" && get_os' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
    refute_output ""
    # uname -s returns e.g. "Darwin" / "Linux"; get_os lowercases it.
    assert_output "$(uname -s | tr '[:upper:]' '[:lower:]')"
}

@test "is_macos and is_linux are mutually exclusive on the current host" {
    # On any host, at most one of is_macos/is_linux should be true.
    # A buggy platform detector returning both would be caught here.
    run bash -c '
        source "$1"
        if is_macos && is_linux; then exit 1; fi
        if ! is_macos && ! is_linux && [[ "$(get_os)" != "freebsd" ]]; then exit 2; fi
        exit 0
    ' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
}

@test "is_macos is consistent with get_os" {
    run bash -c '
        source "$1"
        os=$(get_os)
        if [[ "$os" == "darwin" ]]; then
            is_macos || exit 1
        else
            is_macos && exit 1
        fi
        exit 0
    ' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
}

@test "is_linux is consistent with get_os" {
    run bash -c '
        source "$1"
        os=$(get_os)
        if [[ "$os" == "linux" ]]; then
            is_linux || exit 1
        else
            is_linux && exit 1
        fi
        exit 0
    ' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
}

# =============================================================================
# has_cmd / get_cmd_path
# =============================================================================

@test "has_cmd returns success for commands in PATH" {
    run bash -c 'source "$1" && has_cmd "bash"' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
}

@test "has_cmd returns failure for missing commands" {
    run bash -c 'source "$1" && has_cmd "definitely_not_a_real_command_xyz123"' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_failure
}

@test "get_cmd_path returns full path for existing commands" {
    run bash -c 'source "$1" && get_cmd_path "bash"' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
    assert_output "$(command -v bash)"
}

@test "get_cmd_path returns empty for missing commands" {
    run bash -c 'source "$1" && get_cmd_path "definitely_not_a_real_command_xyz123"' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
    assert_output ""
}

# =============================================================================
# get_arch / is_64bit / is_arm
# =============================================================================

@test "get_arch matches uname -m" {
    run bash -c 'source "$1" && get_arch' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
    assert_output "$(uname -m)"
}

@test "is_64bit is consistent with get_arch" {
    run bash -c '
        source "$1"
        arch=$(get_arch)
        case "$arch" in
            x86_64|amd64|arm64|aarch64) is_64bit ;;
            *) is_64bit && exit 1 ;;
        esac
    ' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
}

# =============================================================================
# Environment detection
# =============================================================================

@test "is_in_tmux reflects TMUX env var" {
    run bash -c '
        source "$1"
        if [[ -n "${TMUX:-}" ]]; then
            is_in_tmux || exit 1
        else
            is_in_tmux && exit 1
        fi
    ' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
}

@test "get_current_user returns USER" {
    run bash -c 'source "$1" && get_current_user' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
    assert_output "${USER:-${USERNAME:-unknown}}"
}

@test "get_shell returns basename of SHELL" {
    run bash -c 'source "$1" && get_shell' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
    assert_output "$(basename "${SHELL:-/bin/sh}")"
}

# =============================================================================
# get_terminal
# =============================================================================

@test "get_terminal returns a non-empty string" {
    run bash -c 'source "$1" && get_terminal' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
    refute_output ""
}

@test "get_terminal prefers TERM_PROGRAM when set" {
    run bash -c 'source "$1" && TERM_PROGRAM="TestApp" get_terminal' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
    assert_output "TestApp"
}

# =============================================================================
# Caching: get_os is idempotent across calls
# =============================================================================

@test "get_os returns the same value across calls (caching works)" {
    run bash -c '
        source "$1"
        first=$(get_os)
        second=$(get_os)
        third=$(get_os)
        [[ "$first" == "$second" && "$second" == "$third" ]]
    ' _ "$POWERKIT_ROOT/src/utils/platform.sh"
    assert_success
}