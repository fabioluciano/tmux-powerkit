#!/usr/bin/env bash
# =============================================================================
# Plugin: hostname
# Description: Display current hostname
# Contract-based plugin (PowerKit)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

plugin_get_metadata() {
    metadata_set "id" "hostname"
    metadata_set "name" "Hostname"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display current hostname"
    metadata_set "priority" "10"
}

plugin_declare_options() {
    declare_option "format" "string" "short" "Hostname format (short|full)"
    declare_option "icon" "icon" $'\U0000f015' "Plugin icon"
}


plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    # Detect if in SSH session
    if [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]; then
        printf 'remote'
    else
        printf 'local'
    fi
}

plugin_collect() {
    local format value
    format=$(get_option "format")
    case "$format" in
        full) value=$(get_hostname_full) ;;
        short|*) value=$(get_hostname) ;;
    esac
    plugin_data_set "hostname" "$value"
}

plugin_render() {
    plugin_data_get "hostname"
}

plugin_get_icon() {
    get_option "icon"
}
