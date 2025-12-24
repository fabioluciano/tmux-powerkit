#!/usr/bin/env bash
# =============================================================================
# Plugin: ssh
# Description: Display SSH connection indicator when in an SSH session
# Dependencies: none
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "ssh"
    metadata_set "name" "SSH"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display SSH connection indicator"
    metadata_set "priority" "20"
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show_user" "bool" "true" "Show username"
    declare_option "show_host" "bool" "true" "Show hostname"

    # Icons
    declare_option "icon" "icon" $'\U000F08C0' "Plugin icon"

    # Cache
    declare_option "cache_ttl" "number" "600" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'static'; }
plugin_get_presence() { printf 'conditional'; }
plugin_get_state() {
    local in_ssh=$(plugin_data_get "in_ssh")
    [[ "$in_ssh" == "1" ]] && printf 'active' || printf 'inactive'
}
plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local in_ssh=$(plugin_data_get "in_ssh")
    [[ "$in_ssh" == "1" ]] && printf 'remote' || printf 'local'
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

_check_ssh_session() {
    [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]] && return 0
    
    # Check parent process
    local parent_cmd
    parent_cmd=$(ps -o comm= -p $PPID 2>/dev/null)
    [[ "$parent_cmd" == *"sshd"* ]] && return 0
    
    return 1
}

plugin_collect() {
    local in_ssh=0
    _check_ssh_session && in_ssh=1

    plugin_data_set "in_ssh" "$in_ssh"
    
    if [[ "$in_ssh" == "1" ]]; then
        plugin_data_set "user" "$(get_current_user)"
        plugin_data_set "host" "$(get_hostname)"
    fi
}

plugin_render() {
    local in_ssh show_user show_host user host
    in_ssh=$(plugin_data_get "in_ssh")
    [[ "$in_ssh" != "1" ]] && return 0

    show_user=$(get_option "show_user")
    show_host=$(get_option "show_host")
    user=$(plugin_data_get "user")
    host=$(plugin_data_get "host")

    local result=""
    [[ "$show_user" == "true" ]] && result="$user"
    
    if [[ "$show_host" == "true" ]]; then
        [[ -n "$result" ]] && result+="@"
        result+="$host"
    fi

    [[ -n "$result" ]] && printf '%s' "$result" || printf 'SSH'
}

