#!/usr/bin/env bash
# =============================================================================
# Plugin: ssh
# Description: Indicate when running in an SSH session or pane
# Dependencies: None (uses environment variables)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "ssh"

# =============================================================================
# SSH Detection Functions
# =============================================================================

is_ssh_session() {
    # Check environment variables (fastest method)
    [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" || -n "${SSH_CONNECTION:-}" ]]
}

is_ssh_in_pane() {
    local pane_pid
    pane_pid=$(tmux display-message -p "#{pane_pid}" 2>/dev/null)
    [[ -z "$pane_pid" ]] && return 1

    # Check pane process and children for ssh
    local pid cmd
    for pid in $pane_pid $(pgrep -P "$pane_pid" 2>/dev/null); do
        cmd=$(ps -p "$pid" -o comm= 2>/dev/null)
        [[ "$cmd" == "ssh" ]] && return 0
    done

    return 1
}

# Get SSH destination from pane's ssh process
get_ssh_destination() {
    local pane_pid
    pane_pid=$(tmux display-message -p "#{pane_pid}" 2>/dev/null)
    [[ -z "$pane_pid" ]] && return 1

    local pid cmd args dest
    for pid in $pane_pid $(pgrep -P "$pane_pid" 2>/dev/null); do
        cmd=$(ps -p "$pid" -o comm= 2>/dev/null)
        if [[ "$cmd" == "ssh" ]]; then
            args=$(ps -p "$pid" -o args= 2>/dev/null)
            # Extract destination: skip flags (-X, -p 22, etc) and get user@host or host
            # Parse args to find the destination (first non-flag argument after 'ssh')
            dest=$(echo "$args" | awk '
            {
                for (i=2; i<=NF; i++) {
                    # Skip flags and their arguments
                    if ($i ~ /^-[bcDEeFIiJLlmOopQRSWw]$/) { i++; continue }
                    if ($i ~ /^-/) continue
                    # First non-flag is the destination
                    print $i
                    exit
                }
            }')
            [[ -n "$dest" ]] && { printf '%s' "$dest"; return 0; }
        fi
    done

    return 1
}

get_ssh_info() {
    local format
    format=$(get_cached_option "@powerkit_plugin_ssh_format" "$POWERKIT_PLUGIN_SSH_FORMAT")

    # Check if we're in an incoming SSH session or outgoing SSH connection
    local is_incoming=false
    is_ssh_session && is_incoming=true

    case "$format" in
        host)
            if [[ "$is_incoming" == "true" ]]; then
                # Remote host from SSH_CONNECTION (incoming)
                [[ -n "${SSH_CONNECTION:-}" ]] && printf '%s' "${SSH_CONNECTION%% *}"
            else
                # Outgoing SSH: get destination from process
                local dest
                dest=$(get_ssh_destination) && printf '%s' "${dest#*@}"
            fi
            ;;
        user)
            if [[ "$is_incoming" == "true" ]]; then
                whoami 2>/dev/null
            else
                local dest
                dest=$(get_ssh_destination)
                [[ "$dest" == *@* ]] && printf '%s' "${dest%%@*}" || whoami 2>/dev/null
            fi
            ;;
        indicator)
            local text
            text=$(get_cached_option "@powerkit_plugin_ssh_text" "$POWERKIT_PLUGIN_SSH_TEXT")
            printf '%s' "$text"
            ;;
        *)
            # Default: user@hostname
            if [[ "$is_incoming" == "true" ]]; then
                printf '%s@%s' "$(whoami)" "$(hostname -s 2>/dev/null || hostname)"
            else
                # Outgoing SSH: show destination
                local dest
                dest=$(get_ssh_destination) && printf '%s' "$dest"
            fi
            ;;
    esac
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    if [[ -n "$content" ]]; then
        local accent accent_icon
        accent=$(get_cached_option "@powerkit_plugin_ssh_active_accent_color" "$POWERKIT_PLUGIN_SSH_ACTIVE_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_ssh_active_accent_color_icon" "$POWERKIT_PLUGIN_SSH_ACTIVE_ACCENT_COLOR_ICON")
        build_display_info "1" "$accent" "$accent_icon" ""
    else
        build_display_info "0" "" "" ""
    fi
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local detection_mode in_ssh=false
    detection_mode=$(get_cached_option "@powerkit_plugin_ssh_detection_mode" "$POWERKIT_PLUGIN_SSH_DETECTION_MODE")

    case "$detection_mode" in
        session) is_ssh_session && in_ssh=true ;;
        pane)    is_ssh_in_pane && in_ssh=true ;;
        *)       { is_ssh_session || is_ssh_in_pane; } && in_ssh=true ;;
    esac

    [[ "$in_ssh" != "true" ]] && return 0

    get_ssh_info
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
