#!/usr/bin/env bash
# =============================================================================
# Plugin: timezones
# Description: Display time in multiple time zones
# Dependencies: None (uses TZ environment variable)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Timezones configured and displaying
#   - degraded: No zones configured (plugin visible but needs setup)
#   - inactive: No timezone data available
#
# Health:
#   - error: No zones configured
#   - ok: Zones configured and working
#
# Context:
#   - not_configured: No zones defined
#   - configured: Zones are set up
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "timezones"
    metadata_set "name" "Timezones"
    metadata_set "description" "Display time in multiple time zones"
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "zones" "string" "" "Comma-separated list of timezones (e.g., America/New_York,Europe/London)"
    declare_option "format" "string" "%H:%M" "Time format string (strftime format)"
    declare_option "show_label" "bool" "true" "Show timezone label (3-letter abbreviation)"
    declare_option "separator" "string" " | " "Separator between timezones"

    # Icons
    declare_option "icon" "icon" $'\U0000F0AC' "Plugin icon"

    # Cache - time changes constantly, keep TTL short for accuracy
    declare_option "cache_ttl" "number" "60" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }

plugin_get_state() {
    local zones
    zones=$(get_option "zones")

    # No zones configured - degraded state (visible but needs setup)
    [[ -z "$zones" ]] && { printf 'degraded'; return; }

    local stored_zones
    stored_zones=$(plugin_data_get "zones")
    [[ -n "$stored_zones" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local zones
    zones=$(get_option "zones")

    # No zones configured - error health
    [[ -z "$zones" ]] && { printf 'error'; return; }

    printf 'ok'
}

plugin_get_context() {
    local zones
    zones=$(get_option "zones")
    [[ -z "$zones" ]] && { printf 'not_configured'; return; }
    printf 'configured'
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Helper Functions
# =============================================================================

_format_tz_time() {
    local tz="$1"
    local format="$2"
    local show_label="$3"

    local time_str label=""
    time_str=$(TZ="$tz" date +"$format" 2>/dev/null)

    if [[ "$show_label" == "true" ]]; then
        # Extract city name from timezone (e.g., America/New_York -> NYC)
        label="${tz##*/}"
        label="${label:0:3}"
        label="${label^^} "
    fi

    printf '%s%s' "$label" "$time_str"
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    local zones format show_label separator
    zones=$(get_option "zones")
    format=$(get_option "format")
    show_label=$(get_option "show_label")
    separator=$(get_option "separator")

    plugin_data_set "zones" "$zones"
    plugin_data_set "format" "$format"
    plugin_data_set "show_label" "$show_label"
    plugin_data_set "separator" "$separator"
}

plugin_render() {
    local zones format show_label separator
    zones=$(plugin_data_get "zones")

    # No zones configured - show message
    [[ -z "$zones" ]] && { printf 'not configured'; return; }

    format=$(plugin_data_get "format")
    show_label=$(plugin_data_get "show_label")
    separator=$(plugin_data_get "separator")

    IFS=',' read -ra tz_array <<< "$zones"
    local parts=()

    for tz in "${tz_array[@]}"; do
        tz=$(trim "$tz")
        [[ -z "$tz" ]] && continue
        parts+=("$(_format_tz_time "$tz" "$format" "$show_label")")
    done

    [[ ${#parts[@]} -eq 0 ]] && return 0

    join_with_separator "$separator" "${parts[@]}"
}

