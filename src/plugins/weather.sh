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
# Weather Icon Mapping (Emoji to Nerd Fonts)
# =============================================================================
# Maps wttr.in weather condition emojis to Nerd Fonts (nf-md-weather_*)

declare -gA _WEATHER_ICON_MAP=(
    # Sunny/Clear
    ["☀️"]=$'\U000F0599'      # nf-md-weather_sunny
    ["☀"]=$'\U000F0599'       # nf-md-weather_sunny (no variation selector)
    ["🌣"]=$'\U000F0599'      # nf-md-weather_sunny

    # Partly cloudy
    ["⛅"]=$'\U000F0595'       # nf-md-weather_partly_cloudy
    ["⛅️"]=$'\U000F0595'      # nf-md-weather_partly_cloudy
    ["🌤️"]=$'\U000F0595'      # nf-md-weather_partly_cloudy
    ["🌤"]=$'\U000F0595'       # nf-md-weather_partly_cloudy

    # Cloudy
    ["☁️"]=$'\U000F0590'      # nf-md-weather_cloudy
    ["☁"]=$'\U000F0590'       # nf-md-weather_cloudy
    ["🌥️"]=$'\U000F0595'      # nf-md-weather_partly_cloudy
    ["🌥"]=$'\U000F0595'       # nf-md-weather_partly_cloudy

    # Rainy
    ["🌧️"]=$'\U000F0597'      # nf-md-weather_rainy
    ["🌧"]=$'\U000F0597'       # nf-md-weather_rainy
    ["🌦️"]=$'\U000F0597'      # nf-md-weather_rainy (sun + rain)
    ["🌦"]=$'\U000F0597'       # nf-md-weather_rainy
    ["💧"]=$'\U000F0597'       # nf-md-weather_rainy

    # Thunderstorm
    ["⛈️"]=$'\U000F0596'      # nf-md-weather_lightning_rainy
    ["⛈"]=$'\U000F0596'       # nf-md-weather_lightning_rainy
    ["🌩️"]=$'\U000F0593'      # nf-md-weather_lightning
    ["🌩"]=$'\U000F0593'       # nf-md-weather_lightning

    # Snow
    ["❄️"]=$'\U000F0598'      # nf-md-weather_snowy
    ["❄"]=$'\U000F0598'       # nf-md-weather_snowy
    ["🌨️"]=$'\U000F0598'      # nf-md-weather_snowy
    ["🌨"]=$'\U000F0598'       # nf-md-weather_snowy
    ["⛄"]=$'\U000F0598'       # nf-md-weather_snowy

    # Fog/Mist
    ["🌫️"]=$'\U000F0591'      # nf-md-weather_fog
    ["🌫"]=$'\U000F0591'       # nf-md-weather_fog

    # Wind
    ["💨"]=$'\U000F059D'       # nf-md-weather_windy

    # Night/Moon
    ["🌙"]=$'\U000F0594'       # nf-md-weather_night
    ["🌑"]=$'\U000F0594'       # nf-md-weather_night
    ["🌒"]=$'\U000F0594'       # nf-md-weather_night
    ["🌓"]=$'\U000F0594'       # nf-md-weather_night
    ["🌔"]=$'\U000F0594'       # nf-md-weather_night
    ["🌕"]=$'\U000F0594'       # nf-md-weather_night
    ["🌖"]=$'\U000F0594'       # nf-md-weather_night
    ["🌗"]=$'\U000F0594'       # nf-md-weather_night
    ["🌘"]=$'\U000F0594'       # nf-md-weather_night
)

# Map emoji to Nerd Font icon
_map_weather_icon() {
    local emoji="$1"
    # Remove variation selectors for lookup
    local clean_emoji
    clean_emoji=$(printf '%s' "$emoji" | perl -CS -pe 's/\x{FE0E}|\x{FE0F}//g' 2>/dev/null || printf '%s' "$emoji")

    # Try with cleaned emoji first, then original
    if [[ -n "${_WEATHER_ICON_MAP[$clean_emoji]:-}" ]]; then
        printf '%s' "${_WEATHER_ICON_MAP[$clean_emoji]}"
    elif [[ -n "${_WEATHER_ICON_MAP[$emoji]:-}" ]]; then
        printf '%s' "${_WEATHER_ICON_MAP[$emoji]}"
    else
        # Fallback to original emoji if no mapping
        printf '%s' "$emoji"
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

    # For dynamic icon mode, extract symbol separately and remove %c from display format
    local fetch_format="$format"
    local needs_symbol=0
    local sep="|||"
    if [[ "$icon_mode" == "dynamic" ]]; then
        # Remove %c from format (we'll get it separately)
        local clean_format="${format//%c/}"
        # Clean up extra spaces from removal
        clean_format=$(printf '%s' "$clean_format" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]]\{2,\}/ /g')
        fetch_format="%c${sep}${clean_format}"
        needs_symbol=1
    fi

    # URL encode the format string (% -> %25, space -> %20, | -> %7C)
    local encoded_format
    encoded_format=$(printf '%s' "$fetch_format" | sed 's/%/%25/g; s/ /%20/g; s/|/%7C/g')

    local url="http://wttr.in"
    [[ -n "$encoded_location" ]] && url+="/$encoded_location"
    url+="?format=${encoded_format}&${units}"
    [[ -n "$language" ]] && url+="&lang=$language"

    # Fetch with timeout (5s connect, 10s max - wttr.in can be slow)
    local result
    result=$(safe_curl "$url" 5 -L) || return 1

    # Return only if we got valid data (not error messages)
    if [[ -n "$result" && ! "$result" =~ ^(Unknown|Error|Sorry) ]]; then
        if [[ "$needs_symbol" -eq 1 && "$result" == *"|||"* ]]; then
            # Extract symbol and weather separately
            local symbol="${result%%|||*}"
            local weather="${result#*|||}"
            # Output: symbol\nweather (newline separated for easy parsing)
            printf '%s\n%s' "$symbol" "$weather"
        else
            printf '%s' "$result"
        fi
    fi
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local result
    result=$(_fetch_weather)

    # API failed - return error to let lifecycle handle stale-while-revalidate
    # The lifecycle will preserve the previous cache if within stale window
    [[ -z "$result" ]] && return 1

    local weather symbol

    # Check if result contains symbol (newline separated from _fetch_weather)
    if [[ "$result" == *$'\n'* ]]; then
        symbol="${result%%$'\n'*}"
        weather="${result#*$'\n'}"
    else
        weather="$result"
    fi

    # Clean up and map symbol to Nerd Font icon
    if [[ -n "$symbol" ]]; then
        symbol=$(printf '%s' "$symbol" | sed 's/[[:space:]]*$//')
        # Map emoji to Nerd Font icon
        symbol=$(_map_weather_icon "$symbol")
    fi

    # Clean up the weather output:
    # 1. Remove ANSI escape codes
    # 2. Remove newlines
    # 3. Trim whitespace
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

