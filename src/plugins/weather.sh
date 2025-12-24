#!/usr/bin/env bash
# =============================================================================
# Plugin: weather
# Description: Display current weather from wttr.in
# Dependencies: curl
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "weather"
    metadata_set "name" "Weather"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display current weather"
    metadata_set "priority" "70"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "location" "string" "" "Location (empty for auto-detect)"
    declare_option "units" "string" "m" "Units: m (metric), u (US), or M (SI)"
    declare_option "format" "string" "%t" "Format string: %c=condition icon %t=temp %w=wind %h=humidity %C=condition text"
    declare_option "language" "string" "" "Language code (e.g., pt, es, fr)"

    # Icons
    declare_option "icon" "icon" $'\U000F0599' "Plugin icon"

    # Cache (weather doesn't change frequently)
    declare_option "cache_ttl" "number" "1800" "Cache duration in seconds (30 min)"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }
plugin_get_state() {
    local weather=$(plugin_data_get "weather")
    [[ -n "$weather" ]] && printf 'active' || printf 'inactive'
}
plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local weather=$(plugin_data_get "weather")
    [[ -n "$weather" ]] && printf 'available' || printf 'unavailable'
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

_fetch_weather() {
    local location units format language
    location=$(get_option "location")
    units=$(get_option "units")
    format=$(get_option "format")
    language=$(get_option "language")

    # URL encode location if provided
    local encoded_location=""
    if [[ -n "$location" ]]; then
        encoded_location=$(printf '%s' "$location" | sed 's/ /%20/g')
    fi

    local url="https://wttr.in"
    [[ -n "$encoded_location" ]] && url+="/$encoded_location"
    url+="?format=${format}&${units}"
    [[ -n "$language" ]] && url+="&lang=$language"

    # Fetch with timeout and error handling
    local result
    result=$(curl -sf --connect-timeout 3 --max-time 6 "$url" 2>/dev/null) || return 1
    
    # Return only if we got valid data (not error messages)
    if [[ -n "$result" && ! "$result" =~ ^(Unknown|Error|Sorry) ]]; then
        printf '%s' "$result"
    fi
}

plugin_collect() {
    local weather
    weather=$(_fetch_weather)

    if [[ -n "$weather" ]]; then
        # Clean up the output:
        # 1. Remove ANSI escape codes
        # 2. Remove newlines
        # 3. Trim whitespace
        # 4. Limit length to prevent bar overflow
        weather=$(printf '%s' "$weather" | \
            sed 's/\x1b\[[0-9;]*m//g' | \
            tr -d '\n\r' | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Limit to reasonable length (50 chars max)
        if [[ ${#weather} -gt 50 ]]; then
            weather="${weather:0:47}..."
        fi
        
        plugin_data_set "weather" "$weather"
    fi
}

plugin_render() {
    local weather
    weather=$(plugin_data_get "weather")
    [[ -n "$weather" ]] && printf '%s' "$weather"
}

