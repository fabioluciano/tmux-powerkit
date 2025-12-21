#!/usr/bin/env bash
# =============================================================================
# Plugin: timezones
# Description: Display time in multiple time zones
# Type: conditional (hidden when no zones configured)
# Dependencies: None (uses TZ environment variable)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "zones" "string" "" "Comma-separated list of timezones (e.g., America/New_York,Europe/London)"
    declare_option "format" "string" "%H:%M" "Time format string (strftime format)"
    declare_option "show_label" "bool" "false" "Show timezone label (3-letter abbreviation)"
    declare_option "separator" "string" " | " "Separator between timezones"

    # Icons
    declare_option "icon" "icon" $'\U000F00AC' "Plugin icon"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "30" "Cache duration in seconds"
}

plugin_init "timezones"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -n "$content" ]] && printf '1:::' || printf '0:::'
}

# =============================================================================
# Helper Functions
# =============================================================================

_format_tz_time() {
    local tz="$1"
    local format
    format=$(get_option "format")

    local show_label time_str label=""
    show_label=$(get_option "show_label")
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
# Main Logic
# =============================================================================

load_plugin() {
    local zones separator
    zones=$(get_option "zones")
    separator=$(get_option "separator")

    [[ -z "$zones" ]] && return 0

    IFS=',' read -ra tz_array <<< "$zones"
    local parts=()

    for tz in "${tz_array[@]}"; do
        tz="${tz#"${tz%%[![:space:]]*}"}"  # trim leading
        tz="${tz%"${tz##*[![:space:]]}"}"  # trim trailing
        [[ -z "$tz" ]] && continue
        parts+=("$(_format_tz_time "$tz")")
    done

    [[ ${#parts[@]} -eq 0 ]] && return 0

    join_with_separator "$separator" "${parts[@]}"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
