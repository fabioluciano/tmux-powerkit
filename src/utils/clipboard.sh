#!/usr/bin/env bash
# =============================================================================
# PowerKit Utils: Clipboard
# Description: Cross-platform clipboard utilities
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_clipboard" && return 0

. "${POWERKIT_ROOT}/src/utils/platform.sh"

# =============================================================================
# Clipboard Detection
# =============================================================================

# Detect available clipboard command
# Returns: pbcopy, xclip, xsel, wl-copy, or empty
_detect_clipboard_cmd() {
    if is_macos; then
        printf 'pbcopy'
    elif has_cmd wl-copy && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        printf 'wl-copy'
    elif has_cmd xclip && [[ -n "${DISPLAY:-}" ]]; then
        printf 'xclip'
    elif has_cmd xsel && [[ -n "${DISPLAY:-}" ]]; then
        printf 'xsel'
    fi
}

# Detect paste command
_detect_paste_cmd() {
    if is_macos; then
        printf 'pbpaste'
    elif has_cmd wl-paste && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        printf 'wl-paste'
    elif has_cmd xclip && [[ -n "${DISPLAY:-}" ]]; then
        printf 'xclip_paste'
    elif has_cmd xsel && [[ -n "${DISPLAY:-}" ]]; then
        printf 'xsel_paste'
    fi
}

# =============================================================================
# Clipboard Operations
# =============================================================================

# Copy text to clipboard
# Usage: copy_to_clipboard "text to copy"
# Usage: echo "text" | copy_to_clipboard
copy_to_clipboard() {
    local text="${1:-}"

    local clipboard_cmd
    clipboard_cmd=$(_detect_clipboard_cmd)

    if [[ -z "$clipboard_cmd" ]]; then
        # Fallback to tmux buffer if inside tmux
        if is_in_tmux; then
            if [[ -n "$text" ]]; then
                tmux set-buffer "$text"
            else
                tmux set-buffer "$(cat)"
            fi
            return 0
        fi
        return 1
    fi

    case "$clipboard_cmd" in
        pbcopy)
            if [[ -n "$text" ]]; then
                printf '%s' "$text" | pbcopy
            else
                pbcopy
            fi
            ;;
        wl-copy)
            if [[ -n "$text" ]]; then
                printf '%s' "$text" | wl-copy
            else
                wl-copy
            fi
            ;;
        xclip)
            if [[ -n "$text" ]]; then
                printf '%s' "$text" | xclip -selection clipboard
            else
                xclip -selection clipboard
            fi
            ;;
        xsel)
            if [[ -n "$text" ]]; then
                printf '%s' "$text" | xsel --clipboard --input
            else
                xsel --clipboard --input
            fi
            ;;
    esac
}

# Paste from clipboard
# Usage: text=$(paste_from_clipboard)
paste_from_clipboard() {
    local paste_cmd
    paste_cmd=$(_detect_paste_cmd)

    if [[ -z "$paste_cmd" ]]; then
        # Fallback to tmux buffer if inside tmux
        if is_in_tmux; then
            tmux show-buffer 2>/dev/null
            return
        fi
        return 1
    fi

    case "$paste_cmd" in
        pbpaste)
            pbpaste
            ;;
        wl-paste)
            wl-paste 2>/dev/null
            ;;
        xclip_paste)
            xclip -selection clipboard -o 2>/dev/null
            ;;
        xsel_paste)
            xsel --clipboard --output 2>/dev/null
            ;;
    esac
}

# Check if clipboard is available
# Usage: clipboard_available && echo "available"
clipboard_available() {
    [[ -n "$(_detect_clipboard_cmd)" ]] || is_in_tmux
}

# =============================================================================
# Tmux Clipboard Integration
# =============================================================================

# Copy to both system clipboard and tmux buffer
# Usage: copy_to_all "text"
copy_to_all() {
    local text="$1"

    # Copy to system clipboard
    copy_to_clipboard "$text"

    # Also copy to tmux buffer if in tmux
    if is_in_tmux; then
        tmux set-buffer "$text"
    fi
}

# Get from clipboard, preferring tmux buffer
# Usage: text=$(get_clipboard_or_buffer)
get_clipboard_or_buffer() {
    # Try tmux buffer first if in tmux
    if is_in_tmux; then
        local buffer
        buffer=$(tmux show-buffer 2>/dev/null)
        if [[ -n "$buffer" ]]; then
            printf '%s' "$buffer"
            return
        fi
    fi

    # Fall back to system clipboard
    paste_from_clipboard
}

# =============================================================================
# Clipboard History (tmux buffers)
# =============================================================================

# List tmux buffers
# Usage: list_buffers
list_buffers() {
    is_in_tmux || return 1
    tmux list-buffers 2>/dev/null
}

# Get specific tmux buffer
# Usage: get_buffer 0
get_buffer() {
    local index="${1:-0}"
    is_in_tmux || return 1
    tmux show-buffer -b "buffer$index" 2>/dev/null
}

# Delete tmux buffer
# Usage: delete_buffer 0
delete_buffer() {
    local index="${1:-0}"
    is_in_tmux || return 1
    tmux delete-buffer -b "buffer$index" 2>/dev/null
}

# Clear all tmux buffers
# Usage: clear_buffers
clear_buffers() {
    is_in_tmux || return 1

    while tmux delete-buffer 2>/dev/null; do
        :
    done
}
