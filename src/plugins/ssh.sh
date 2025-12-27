#!/usr/bin/env bash
# =============================================================================
# Plugin: ssh
# Description: Display SSH connection indicator for incoming and outgoing sessions
# Dependencies: none
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: In SSH session (incoming or outgoing)
#   - inactive: Not in SSH session
#
# Health:
#   - ok: Normal operation
#
# Context:
#   - incoming: SSH session from remote to this host
#   - outgoing: SSH connection from this host to remote (pane)
#   - local: Not in SSH session
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "ssh"
    metadata_set "name" "SSH"
    metadata_set "description" "Display SSH connection indicator (incoming and outgoing)"
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display format options
    declare_option "format" "string" "auto" "Display format: auto, host, user, indicator"
    declare_option "text" "string" "SSH" "Text for indicator format"

    # Detection options
    declare_option "detection_mode" "string" "current" "Detection mode: session, pane, current"
    declare_option "show_when_local" "bool" "false" "Show plugin when not in SSH"

    # Legacy compatibility options (mapped to format)
    declare_option "show_user" "bool" "true" "Show username (when format=auto)"
    declare_option "show_host" "bool" "true" "Show hostname (when format=auto)"

    # Icons
    declare_option "icon" "icon" $'\U000F08C0' "Plugin icon"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# SSH Detection Methods
# =============================================================================

# Check for incoming SSH session (we are the remote host)
_is_ssh_session() {
    # Check environment variables (fastest method)
    [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" || -n "${SSH_CONNECTION:-}" ]] && return 0

    # Check parent process
    local parent_cmd
    parent_cmd=$(ps -o comm= -p $PPID 2>/dev/null)
    [[ "$parent_cmd" == *"sshd"* ]] && return 0

    return 1
}

# Check for outgoing SSH connection in current pane
_is_ssh_in_pane() {
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
_get_ssh_destination() {
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

# Get formatted SSH info based on format option
_get_ssh_info() {
    local format is_incoming dest
    format=$(get_option "format")
    is_incoming=$(plugin_data_get "is_incoming")
    dest=$(plugin_data_get "destination")

    case "$format" in
        host)
            if [[ "$is_incoming" == "1" ]]; then
                # Remote host from SSH_CONNECTION (incoming)
                [[ -n "${SSH_CONNECTION:-}" ]] && printf '%s' "${SSH_CONNECTION%% *}"
            else
                # Outgoing SSH: get host from destination
                [[ -n "$dest" ]] && printf '%s' "${dest#*@}"
            fi
            ;;
        user)
            if [[ "$is_incoming" == "1" ]]; then
                get_current_user 2>/dev/null
            else
                # Outgoing SSH: get user from destination if present
                if [[ "$dest" == *@* ]]; then
                    printf '%s' "${dest%%@*}"
                else
                    get_current_user 2>/dev/null
                fi
            fi
            ;;
        indicator)
            local text
            text=$(get_option "text")
            printf '%s' "$text"
            ;;
        *)
            # auto: user@hostname or destination
            if [[ "$is_incoming" == "1" ]]; then
                local show_user show_host result=""
                show_user=$(get_option "show_user")
                show_host=$(get_option "show_host")

                [[ "$show_user" == "true" ]] && result="$(get_current_user)"
                if [[ "$show_host" == "true" ]]; then
                    [[ -n "$result" ]] && result+="@"
                    result+="$(get_hostname)"
                fi
                printf '%s' "${result:-SSH}"
            else
                # Outgoing SSH: show destination
                [[ -n "$dest" ]] && printf '%s' "$dest" || printf 'SSH'
            fi
            ;;
    esac
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local detection_mode in_ssh=0 is_incoming=0 is_outgoing=0 destination=""
    detection_mode=$(get_option "detection_mode")

    case "$detection_mode" in
        session)
            # Only check incoming SSH session
            if _is_ssh_session; then
                in_ssh=1
                is_incoming=1
            fi
            ;;
        pane)
            # Only check outgoing SSH in pane
            if _is_ssh_in_pane; then
                in_ssh=1
                is_outgoing=1
                destination=$(_get_ssh_destination)
            fi
            ;;
        *)
            # current: check both, incoming first
            if _is_ssh_session; then
                in_ssh=1
                is_incoming=1
            elif _is_ssh_in_pane; then
                in_ssh=1
                is_outgoing=1
                destination=$(_get_ssh_destination)
            fi
            ;;
    esac

    plugin_data_set "in_ssh" "$in_ssh"
    plugin_data_set "is_incoming" "$is_incoming"
    plugin_data_set "is_outgoing" "$is_outgoing"
    plugin_data_set "destination" "$destination"
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }

plugin_get_presence() {
    local show_when_local
    show_when_local=$(get_option "show_when_local")
    [[ "$show_when_local" == "true" ]] && printf 'always' || printf 'conditional'
}

# =============================================================================
# Plugin Contract: State
# =============================================================================

plugin_get_state() {
    local in_ssh show_when_local
    in_ssh=$(plugin_data_get "in_ssh")
    show_when_local=$(get_option "show_when_local")

    if [[ "$in_ssh" == "1" ]]; then
        printf 'active'
    elif [[ "$show_when_local" == "true" ]]; then
        printf 'active'
    else
        printf 'inactive'
    fi
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================

plugin_get_health() { printf 'ok'; }

# =============================================================================
# Plugin Contract: Context
# =============================================================================

plugin_get_context() {
    local is_incoming is_outgoing
    is_incoming=$(plugin_data_get "is_incoming")
    is_outgoing=$(plugin_data_get "is_outgoing")

    if [[ "$is_incoming" == "1" ]]; then
        printf 'incoming'
    elif [[ "$is_outgoing" == "1" ]]; then
        printf 'outgoing'
    else
        printf 'local'
    fi
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local in_ssh show_when_local
    in_ssh=$(plugin_data_get "in_ssh")
    show_when_local=$(get_option "show_when_local")

    # If not in SSH and show_when_local is false, return nothing
    if [[ "$in_ssh" != "1" ]]; then
        if [[ "$show_when_local" == "true" ]]; then
            printf 'local'
        fi
        return
    fi

    _get_ssh_info
}

