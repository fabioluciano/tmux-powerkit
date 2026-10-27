#!/usr/bin/env bash
# =============================================================================
# PowerKit Utils: Clipboard
# Description: Cross-platform clipboard access with a tmux buffer fallback
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_clipboard" && return 0

. "${POWERKIT_ROOT}/src/utils/platform.sh"

_detect_clipboard_cmd() {
    if is_macos && has_cmd pbcopy; then
        printf 'pbcopy'
    elif [[ -n "${WAYLAND_DISPLAY:-}" ]] && has_cmd wl-copy; then
        printf 'wl-copy'
    elif [[ -n "${DISPLAY:-}" ]] && has_cmd xclip; then
        printf 'xclip'
    elif [[ -n "${DISPLAY:-}" ]] && has_cmd xsel; then
        printf 'xsel'
    fi
}

# Read stdin directly so secrets never become external command arguments.
_copy_clipboard_stdin() {
    local clipboard_cmd
    clipboard_cmd=$(_detect_clipboard_cmd)
    case "$clipboard_cmd" in
        pbcopy) pbcopy ;;
        wl-copy) wl-copy ;;
        xclip) xclip -selection clipboard ;;
        xsel) xsel --clipboard --input ;;
        *)
            is_in_tmux || return 1
            tmux load-buffer -
            ;;
    esac
}

# Usage: copy_to_clipboard "text" OR printf '%s' "text" | copy_to_clipboard
copy_to_clipboard() {
    if (( $# > 0 )); then
        printf '%s' "$1" | _copy_clipboard_stdin
    else
        _copy_clipboard_stdin
    fi
}

paste_from_clipboard() {
    if is_macos && has_cmd pbpaste; then
        pbpaste
    elif [[ -n "${WAYLAND_DISPLAY:-}" ]] && has_cmd wl-paste; then
        wl-paste --no-newline
    elif [[ -n "${DISPLAY:-}" ]] && has_cmd xclip; then
        xclip -selection clipboard -o
    elif [[ -n "${DISPLAY:-}" ]] && has_cmd xsel; then
        xsel --clipboard --output
    else
        is_in_tmux || return 1
        tmux save-buffer -
    fi
}

clipboard_available() {
    [[ -n "$(_detect_clipboard_cmd)" ]] || is_in_tmux
}
