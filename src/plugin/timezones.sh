#!/usr/bin/env bash
# =============================================================================
# Plugin: timezones
# Description: Display time in multiple time zones
# Dependencies: None (uses TZ environment variable)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "timezones"

# =============================================================================
# Timezone Functions
# =============================================================================

format_tz_time() {
    local tz="$1"
    local format
    format=$(get_cached_option "@powerkit_plugin_timezones_format" "$POWERKIT_PLUGIN_TIMEZONES_FORMAT")

    local show_label time_str label=""
    show_label=$(get_cached_option "@powerkit_plugin_timezones_show_label" "$POWERKIT_PLUGIN_TIMEZONES_SHOW_LABEL")
    time_str=$(TZ="$tz" date +"$format" 2>/dev/null)

    if [[ "$show_label" == "true" ]]; then
        # Extract city name from timezone (e.g., America/New_York -> New_York)
        label="${tz##*/}"
        label="${label:0:3}"
        label="${label^^} "
    fi

    printf '%s%s' "$label" "$time_str"
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -n "$content" ]] && printf '1:::' || printf '0:::'
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local zones separator
    zones=$(get_cached_option "@powerkit_plugin_timezones_zones" "$POWERKIT_PLUGIN_TIMEZONES_ZONES")
    separator=$(get_cached_option "@powerkit_plugin_timezones_separator" "$POWERKIT_PLUGIN_TIMEZONES_SEPARATOR")

    [[ -z "$zones" ]] && return 0

    IFS=',' read -ra tz_array <<< "$zones"
    local parts=()

    for tz in "${tz_array[@]}"; do
        tz="${tz#"${tz%%[![:space:]]*}"}"  # trim leading
        tz="${tz%"${tz##*[![:space:]]}"}"  # trim trailing
        [[ -z "$tz" ]] && continue
        parts+=("$(format_tz_time "$tz")")
    done

    [[ ${#parts[@]} -eq 0 ]] && return 0

    join_with_separator "$separator" "${parts[@]}"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
