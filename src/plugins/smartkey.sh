#!/usr/bin/env bash
# =============================================================================
# Plugin: smartkey
# Description: Display custom key-value data from environment or file
# Dependencies: none
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "smartkey"
    metadata_set "name" "SmartKey"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display custom key-value data"
    metadata_set "priority" "175"
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "key" "string" "" "Environment variable or key to display"
    declare_option "file" "string" "" "File to read value from"
    declare_option "default" "string" "" "Default value if key not found"
    declare_option "format" "string" "%s" "Format string (%s for value)"

    # Icons
    declare_option "icon" "icon" $'\U000F0383' "Key icon"

    # Cache
    declare_option "cache_ttl" "number" "30" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'static'; }
plugin_get_presence() { printf 'conditional'; }
plugin_get_state() {
    local value=$(plugin_data_get "value")
    [[ -n "$value" ]] && printf 'active' || printf 'inactive'
}
plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local key file value
    key=$(get_option "key")
    file=$(get_option "file")
    value=$(plugin_data_get "value")
    
    if [[ -z "$value" ]]; then
        printf 'empty'
    elif [[ -n "$file" && -f "$file" ]]; then
        printf 'from_file'
    elif [[ -n "$key" ]]; then
        printf 'from_env'
    else
        printf 'default'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

_get_smartkey_value() {
    local key file default_val
    key=$(get_option "key")
    file=$(get_option "file")
    default_val=$(get_option "default")

    # Try file first
    if [[ -n "$file" && -f "$file" ]]; then
        cat "$file" 2>/dev/null && return 0
    fi

    # Try environment variable
    if [[ -n "$key" ]]; then
        local value="${!key}"
        [[ -n "$value" ]] && printf '%s' "$value" && return 0
    fi

    # Return default
    [[ -n "$default_val" ]] && printf '%s' "$default_val"
}

plugin_collect() {
    local value
    value=$(_get_smartkey_value)

    [[ -n "$value" ]] && plugin_data_set "value" "$value"
}

plugin_render() {
    local value format
    value=$(plugin_data_get "value")
    format=$(get_option "format")

    [[ -z "$value" ]] && return 0

    # shellcheck disable=SC2059
    printf "$format" "$value"
}

