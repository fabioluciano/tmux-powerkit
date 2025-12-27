#!/usr/bin/env bash
# =============================================================================
# Plugin: weather
# Description: Display current weather from wttr.in
# Dependencies: curl
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Weather data retrieved
#   - inactive: No weather data available
#
# Health:
#   - ok: Normal operation
#
# Context:
#   - available: Weather data available
#   - unavailable: No weather data
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "weather"
    metadata_set "name" "Weather"
    metadata_set "description" "Display current weather from wttr.in"
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
    declare_option "format" "string" "compact" "Format: compact, full, minimal, detailed, or custom format string (%c %t %w %h %C %l)"
    declare_option "language" "string" "" "Language code (e.g., pt, es, fr)"
    declare_option "hide_plus_sign" "bool" "true" "Hide + sign for positive temperatures"

    # Icons
    declare_option "icon" "icon" $'\U000F0599' "Plugin icon (used when icon_mode is static)"
    declare_option "icon_mode" "string" "dynamic" "Icon mode: static (use icon option) or dynamic (use weather condition symbol from API)"

    # Cache (weather doesn't change frequently)
    declare_option "cache_ttl" "number" "1800" "Cache duration in seconds (30 min)"
}

# =============================================================================
# Format Presets
# =============================================================================
# Format codes from wttr.in:
#   %c - Weather condition icon (emoji)
#   %C - Weather condition text
#   %t - Temperature
#   %w - Wind
#   %h - Humidity
#   %l - Location
#   %m - Moon phase
#   %p - Precipitation
#   %P - Pressure

_resolve_format() {
    local format="$1"

    case "$format" in
        compact)
            # Compact: temperature and condition icon
            printf '%s' '%t %c'
            ;;
        full)
            # Full: temperature, condition icon, and humidity
            printf '%s' '%t %c H:%h'
            ;;
        minimal)
            # Minimal: just temperature
            printf '%s' '%t'
            ;;
        detailed)
            # Detailed: location, temperature, and condition icon
            printf '%s' '%l: %t %c'
            ;;
        *)
            # Custom format string - pass through as-is
            printf '%s' "$format"
            ;;
    esac
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local weather
    weather=$(plugin_data_get "weather")
    [[ -n "$weather" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local weather
    weather=$(plugin_data_get "weather")
    [[ -n "$weather" ]] && printf 'available' || printf 'unavailable'
}

plugin_get_icon() {
    local icon_mode
    icon_mode=$(get_option "icon_mode")
    if [[ "$icon_mode" == "dynamic" ]]; then
        local symbol
        symbol=$(plugin_data_get "symbol")
        [[ -n "$symbol" ]] && printf '%s' "$symbol" || get_option "icon"
    else
        get_option "icon"
    fi
}

# =============================================================================
# API Functions
# =============================================================================

_fetch_weather() {
    local location units format_option language icon_mode
    location=$(get_option "location")
    units=$(get_option "units")
    format_option=$(get_option "format")
    language=$(get_option "language")
    icon_mode=$(get_option "icon_mode")

    # Resolve format presets to actual format strings
    local format
    format=$(_resolve_format "$format_option")

    # URL encode location if provided
    local encoded_location=""
    if [[ -n "$location" ]]; then
        encoded_location=$(printf '%s' "$location" | sed 's/ /%20/g')
    fi

    # For dynamic icon mode, prepend %c to format if not already present
    # We use a separator to easily extract the symbol later
    local fetch_format="$format"
    local needs_symbol=0
    if [[ "$icon_mode" == "dynamic" && ! "$format" =~ %c ]]; then
        fetch_format="%c|||${format}"
        needs_symbol=1
    fi

    local url="https://wttr.in"
    [[ -n "$encoded_location" ]] && url+="/$encoded_location"
    url+="?format=${fetch_format}&${units}"
    [[ -n "$language" ]] && url+="&lang=$language"

    # Fetch with timeout and error handling
    local result
    result=$(safe_curl "$url" 5 -L) || return 1

    # Return only if we got valid data (not error messages)
    if [[ -n "$result" && ! "$result" =~ ^(Unknown|Error|Sorry) ]]; then
        if [[ "$needs_symbol" -eq 1 && "$result" == *"|||"* ]]; then
            # Extract symbol and weather separately
            local symbol="${result%%|||*}"
            local weather="${result#*|||}"

            # Clean up symbol (remove variation selectors and whitespace)
            symbol=$(printf '%s' "$symbol" | sed 's/[[:space:]]*$//')
            command -v perl &>/dev/null && symbol=$(printf '%s' "$symbol" | perl -CS -pe 's/\x{FE0E}|\x{FE0F}//g')

            # Output: symbol\nweather (newline separated for easy parsing)
            printf '%s\n%s' "$symbol" "$weather"
        else
            # No symbol extraction needed or format already has %c
            printf '%s' "$result"
        fi
    fi
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local result icon_mode
    result=$(_fetch_weather)
    icon_mode=$(get_option "icon_mode")

    [[ -z "$result" ]] && return

    local weather symbol

    # Check if result contains symbol (newline separated)
    if [[ "$result" == *$'\n'* ]]; then
        symbol="${result%%$'\n'*}"
        weather="${result#*$'\n'}"
    else
        weather="$result"
        # If icon_mode is dynamic and format contains %c, try to extract first emoji
        if [[ "$icon_mode" == "dynamic" ]]; then
            # Extract first emoji-like character as symbol
            symbol=$(printf '%s' "$weather" | grep -o '^[^a-zA-Z0-9 +-]*' | head -c 4)
        fi
    fi

    # Clean up the weather output:
    # 1. Remove ANSI escape codes
    # 2. Remove newlines
    # 3. Trim whitespace
    # 4. Limit length to prevent bar overflow
    weather=$(printf '%s' "$weather" | \
        sed 's/\x1b\[[0-9;]*m//g' | \
        tr -d '\n\r' | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Remove + sign from positive temperatures if configured
    local hide_plus
    hide_plus=$(get_option "hide_plus_sign")
    [[ "$hide_plus" == "true" ]] && weather="${weather//+/}"

    # Limit to reasonable length (50 chars max)
    weather=$(truncate_text "$weather" 50 "...")

    plugin_data_set "weather" "$weather"
    [[ -n "$symbol" ]] && plugin_data_set "symbol" "$symbol"
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local weather
    weather=$(plugin_data_get "weather")
    [[ -n "$weather" ]] && printf '%s' "$weather"
}

