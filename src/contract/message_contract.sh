#!/usr/bin/env bash
# =============================================================================
# MESSAGE CONTRACT
# Toast/message API for user notifications
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "contract_message" && return 0

# Note: All core and utils modules are loaded by bootstrap.sh

# =============================================================================
# Message Contract Definition
# =============================================================================

# Functions:
#
# message_show(content, severity, duration)
#   - severity: "info", "success", "warning", "error"
#   - duration: seconds (0 = until dismissed)
#
# message_popup(content, title, width, height)
#   - Uses display-popup for modal content

# =============================================================================
# Message Severity Levels
# =============================================================================

declare -gra MESSAGE_SEVERITIES=(
    "info"     # Informational
    "success"  # Success/confirmation
    "warning"  # Warning
    "error"    # Error/failure
)

# =============================================================================
# Toast Messages (display-message)
# =============================================================================

# Show a toast message
# Usage: message_show "message" "info" 3
message_show() {
    local content="$1"
    local severity="${2:-info}"
    local duration="${3:-3}"

    # Validate severity
    local valid=0
    local s
    for s in "${MESSAGE_SEVERITIES[@]}"; do
        [[ "$severity" == "$s" ]] && { valid=1; break; }
    done
    [[ "$valid" -eq 0 ]] && severity="info"

    # Get color for severity
    local color
    color=$(get_message_color "$severity")

    # Get icon based on severity
    local icon
    case "$severity" in
        info)    icon=$'\uf05a' ;;  #
        success) icon=$'\uf00c' ;;  #
        warning) icon=$'\uf071' ;;  #
        error)   icon=$'\uf057' ;;  #
    esac

    # Calculate duration in milliseconds
    local duration_ms=$((duration * 1000))

    # Format message
    local formatted_msg
    formatted_msg="#[fg=$color]$icon #[default]$content"

    # Show message
    if [[ -n "${TMUX:-}" ]]; then
        tmux display-message -d "$duration_ms" "$formatted_msg" 2>/dev/null || true
    fi

    # Also log it
    log_info "message" "[$severity] $content"
}

# Convenience functions for each severity
message_info() {
    message_show "$1" "info" "${2:-3}"
}

message_success() {
    message_show "$1" "success" "${2:-3}"
}

message_warning() {
    message_show "$1" "warning" "${2:-5}"
}

message_error() {
    message_show "$1" "error" "${2:-5}"
}

# =============================================================================
# Popup Messages (display-popup)
# =============================================================================

# Show a popup with content
# Usage: message_popup "Content here" "Title" 80 24
message_popup() {
    local content="$1"
    local title="${2:-PowerKit}"
    local width="${3:-80}"
    local height="${4:-24}"

    if [[ -z "${TMUX:-}" ]]; then
        # Not in tmux, just print
        printf '%s\n' "$content"
        return
    fi

    # Check if tmux supports display-popup (tmux 3.2+)
    local tmux_version
    tmux_version=$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)

    if awk -v ver="$tmux_version" 'BEGIN { exit !(ver >= 3.2) }' 2>/dev/null; then
        # Create temporary file for content
        local temp_file
        temp_file=$(mktemp)
        printf '%s' "$content" > "$temp_file"

        # Show popup using pk_popup
        pk_popup -T "$title" -w "$width" -H "$height" "cat '$temp_file'; rm -f '$temp_file'; read -n1"
    else
        # Fallback to display-message for older tmux
        tmux display-message "PowerKit: $title - Use tmux 3.2+ for popups"
    fi
}

# Show popup from a command output
# Usage: message_popup_cmd "ls -la" "Directory Listing"
message_popup_cmd() {
    local cmd="$1"
    local title="${2:-Command Output}"
    local width="${3:-80}"
    local height="${4:-24}"

    if [[ -z "${TMUX:-}" ]]; then
        eval "$cmd"
        return
    fi

    local tmux_version
    tmux_version=$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)

    if awk -v ver="$tmux_version" 'BEGIN { exit !(ver >= 3.2) }' 2>/dev/null; then
        pk_popup -T "$title" -w "$width" -H "$height" "$cmd; read -n1"
    else
        tmux display-message "PowerKit: $title - Use tmux 3.2+ for popups"
    fi
}

# =============================================================================
# Confirmation Dialogs
# =============================================================================

# Show confirmation and return result
# Usage: message_confirm "Are you sure?" && echo "confirmed"
message_confirm() {
    local prompt="$1"
    local _default="${2:-n}"  # Reserved for future use

    if [[ -z "${TMUX:-}" ]]; then
        read -rp "$prompt [y/n]: " answer
        [[ "${answer,,}" == "y" ]]
        return
    fi

    # For tmux, we need to use command-prompt
    # This is limited - can't easily capture result
    tmux command-prompt -p "$prompt (y/n):" "if -F '#{==:%1,y}' '' ''"

    # Note: This is a limitation - proper confirmation needs
    # a helper script or display-popup with input handling
    return 0
}

# =============================================================================
# Progress Indicators
# =============================================================================

# Show progress message (updates in place)
# Usage: message_progress "Loading..." 50
message_progress() {
    local message="$1"
    local percent="${2:-}"

    local display_msg="$message"
    if [[ -n "$percent" ]]; then
        display_msg="$message [$percent%]"
    fi

    if [[ -n "${TMUX:-}" ]]; then
        # Use short duration and refresh
        tmux display-message -d 500 "$display_msg" 2>/dev/null || true
    fi
}

# Clear any displayed message
# Usage: message_clear
message_clear() {
    if [[ -n "${TMUX:-}" ]]; then
        tmux display-message "" 2>/dev/null || true
    fi
}

# =============================================================================
# Notification Helpers
# =============================================================================

# Check if popups are supported
popup_supported() {
    [[ -n "${TMUX:-}" ]] || return 1

    local tmux_version
    tmux_version=$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)

    awk -v ver="$tmux_version" 'BEGIN { exit !(ver >= 3.2) }' 2>/dev/null
}

# Get message style based on severity
get_message_style() {
    local severity="$1"
    local color
    color=$(get_message_color "$severity")

    printf 'fg=%s' "$color"
}
