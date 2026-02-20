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
    declare_option "geocoding_cache_ttl" "number" "86400" "Geocoding cache duration in seconds (24 hours)"
    declare_option "max_requests_per_hour" "number" "60" "Maximum API requests per hour (safety limit)"
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
# Language Support
# =============================================================================
# Open Meteo Geocoding API supports location names in multiple languages.
# Weather descriptions use WMO codes (language-agnostic standards).
# Text descriptions default to English and are transparent to users.
#
# Supported languages: Portuguese, Spanish, French, German, Italian, Russian,
# Chinese, Japanese, Korean, Arabic, Turkish, Polish, Dutch, Swedish, Norwegian,
# Danish, Finnish, Czech, Hungarian, Romanian, Greek, Hebrew, Hindi, Thai,
# Vietnamese, Indonesian, Malay.

declare -gA _LANGUAGE_MAP=(
    # Portuguese (Brazil → Portuguese)
    [pt_BR]="pt"
    [pt_PT]="pt"
    [pt]="pt"

    # Spanish
    [es_ES]="es"
    [es_MX]="es"
    [es]="es"

    # French
    [fr_FR]="fr"
    [fr_CA]="fr"
    [fr]="fr"

    # German
    [de_DE]="de"
    [de_AT]="de"
    [de_CH]="de"
    [de]="de"

    # Italian
    [it_IT]="it"
    [it]="it"

    # Russian
    [ru_RU]="ru"
    [ru]="ru"

    # Chinese
    [zh_CN]="zh"
    [zh_TW]="zh"
    [zh]="zh"

    # Japanese
    [ja_JP]="ja"
    [ja]="ja"

    # Korean
    [ko_KR]="ko"
    [ko]="ko"

    # Arabic
    [ar_SA]="ar"
    [ar]="ar"

    # Turkish
    [tr_TR]="tr"
    [tr]="tr"

    # Polish
    [pl_PL]="pl"
    [pl]="pl"

    # Dutch
    [nl_NL]="nl"
    [nl_BE]="nl"
    [nl]="nl"

    # Swedish
    [sv_SE]="sv"
    [sv]="sv"

    # Norwegian
    [no_NO]="no"
    [nb_NO]="no"
    [nn_NO]="no"
    [no]="no"

    # Danish
    [da_DK]="da"
    [da]="da"

    # Finnish
    [fi_FI]="fi"
    [fi]="fi"

    # Czech
    [cs_CZ]="cs"
    [cs]="cs"

    # Hungarian
    [hu_HU]="hu"
    [hu]="hu"

    # Romanian
    [ro_RO]="ro"
    [ro]="ro"

    # Greek
    [el_GR]="el"
    [el]="el"

    # Hebrew
    [he_IL]="he"
    [he]="he"

    # Hindi
    [hi_IN]="hi"
    [hi]="hi"

    # Thai
    [th_TH]="th"
    [th]="th"

    # Vietnamese
    [vi_VN]="vi"
    [vi]="vi"

    # Indonesian
    [id_ID]="id"
    [id]="id"

    # Malay
    [ms_MY]="ms"
    [ms]="ms"
)

# Map language code to Open Meteo supported language
# Handles region variants (e.g., pt_BR → pt) and falls back to English
# Input: language code (e.g., "pt_BR", "es", "fr_CA")
# Output: mapped language code or "en" (English fallback)
_map_language() {
    local lang="$1"
    [[ -z "$lang" ]] && { printf 'en'; return; }

    printf '%s' "${_LANGUAGE_MAP[$lang]:-en}"
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
# WMO Weather Code Mapping
# =============================================================================
# Maps WMO weather codes (0-99) to Nerd Fonts icons and descriptions
# Reference: https://open-meteo.com/en/docs (WMO Weather interpretation codes)

declare -gA _WMO_CODE_MAP=(
    # Clear/Sunny (0)
    [0]=$'\U000F0599'                # nf-md-weather_sunny

    # Mainly clear (1)
    [1]=$'\U000F0595'                # nf-md-weather_partly_cloudy

    # Partly cloudy (2)
    [2]=$'\U000F0595'                # nf-md-weather_partly_cloudy

    # Overcast (3)
    [3]=$'\U000F0590'                # nf-md-weather_cloudy

    # Fog (45, 48)
    [45]=$'\U000F0591'               # nf-md-weather_fog
    [48]=$'\U000F0591'               # nf-md-weather_fog

    # Drizzle (light precipitation)
    [51]=$'\U000F0597'               # nf-md-weather_rainy
    [53]=$'\U000F0597'               # nf-md-weather_rainy
    [55]=$'\U000F0597'               # nf-md-weather_rainy

    # Freezing drizzle
    [56]=$'\U000F0598'               # nf-md-weather_snowy
    [57]=$'\U000F0598'               # nf-md-weather_snowy

    # Rain (moderate)
    [61]=$'\U000F0597'               # nf-md-weather_rainy
    [63]=$'\U000F0597'               # nf-md-weather_rainy
    [65]=$'\U000F0597'               # nf-md-weather_rainy

    # Freezing rain
    [66]=$'\U000F0598'               # nf-md-weather_snowy
    [67]=$'\U000F0598'               # nf-md-weather_snowy

    # Snow
    [71]=$'\U000F0598'               # nf-md-weather_snowy
    [73]=$'\U000F0598'               # nf-md-weather_snowy
    [75]=$'\U000F0598'               # nf-md-weather_snowy
    [77]=$'\U000F0598'               # nf-md-weather_snowy

    # Rain showers
    [80]=$'\U000F0597'               # nf-md-weather_rainy
    [81]=$'\U000F0597'               # nf-md-weather_rainy
    [82]=$'\U000F0597'               # nf-md-weather_rainy

    # Snow showers
    [85]=$'\U000F0598'               # nf-md-weather_snowy
    [86]=$'\U000F0598'               # nf-md-weather_snowy

    # Thunderstorm
    [95]=$'\U000F0596'               # nf-md-weather_lightning_rainy
    [96]=$'\U000F0596'               # nf-md-weather_lightning_rainy
    [99]=$'\U000F0596'               # nf-md-weather_lightning_rainy
)

declare -gA _WMO_CODE_TEXT=(
    [0]="Clear sky"
    [1]="Mainly clear"
    [2]="Partly cloudy"
    [3]="Overcast"
    [45]="Fog"
    [48]="Fog with frost"
    [51]="Light drizzle"
    [53]="Moderate drizzle"
    [55]="Dense drizzle"
    [56]="Light freezing drizzle"
    [57]="Dense freezing drizzle"
    [61]="Slight rain"
    [63]="Moderate rain"
    [65]="Heavy rain"
    [66]="Slight freezing rain"
    [67]="Heavy freezing rain"
    [71]="Slight snow"
    [73]="Moderate snow"
    [75]="Heavy snow"
    [77]="Snow grains"
    [80]="Slight rain showers"
    [81]="Moderate rain showers"
    [82]="Violent rain showers"
    [85]="Slight snow showers"
    [86]="Heavy snow showers"
    [95]="Thunderstorm"
    [96]="Thunderstorm with hail"
    [99]="Thunderstorm with heavy hail"
)

# Map WMO weather code to Nerd Font icon
_map_weather_code() {
    local code="$1"
    local is_day="${2:-1}"  # 1 for day, 0 for night

    # Handle night variants for codes 0, 1, 2 (clear/cloudy conditions)
    if [[ "$is_day" -eq 0 ]]; then
        case "$code" in
            0) printf '%s' $'\U000F0594'; return 0;;         # nf-md-weather_night (clear sky → night)
            1) printf '%s' $'\U000F0594'; return 0;;         # nf-md-weather_night (mainly clear → night)
            2) printf '%s' $'\U000F0594'; return 0;;         # nf-md-weather_night (partly cloudy → night)
        esac
    fi

    # Return mapped icon or fallback to generic cloudy
    if [[ -n "${_WMO_CODE_MAP[$code]:-}" ]]; then
        printf '%s' "${_WMO_CODE_MAP[$code]}"
    else
        printf '%s' $'\U000F0590'  # Fallback: generic cloudy icon
    fi
}

# Get text description for WMO weather code
_get_weather_text() {
    local code="$1"
    if [[ -n "${_WMO_CODE_TEXT[$code]:-}" ]]; then
        printf '%s' "${_WMO_CODE_TEXT[$code]}"
    else
        printf 'Unknown'
    fi
}

# =============================================================================
# Geocoding Functions
# =============================================================================

# Parse geocoding API response
# Input: JSON response from Open Meteo Geocoding API
# Output: "latitude|longitude|display_name" or empty on error
_parse_geocode_response() {
    local json="$1"

    # Use jq if available for robust JSON parsing
    if has_cmd "jq"; then
        local result
        result=$(printf '%s' "$json" | jq -r '
            .results[0] |
            if . == null then empty
            else "\(.latitude)|\(.longitude)|\(.name), \(.country)"
            end
        ' 2>/dev/null)
        [[ -n "$result" ]] && printf '%s' "$result"
        return
    fi

    # Fallback: regex parsing (fragile but better than nothing)
    if [[ "$json" =~ \"latitude\":([0-9.-]+) ]]; then
        local lat="${BASH_REMATCH[1]}"
        if [[ "$json" =~ \"longitude\":([0-9.-]+) ]]; then
            local lon="${BASH_REMATCH[1]}"
            local name=""
            local country=""

            [[ "$json" =~ \"name\":\"([^\"]+)\" ]] && name="${BASH_REMATCH[1]}"
            [[ "$json" =~ \"country\":\"([^\"]+)\" ]] && country="${BASH_REMATCH[1]}"

            local display="$name"
            [[ -n "$country" ]] && display="$name, $country"

            printf '%s|%s|%s' "$lat" "$lon" "$display"
        fi
    fi
}

# Geocode city name using Open Meteo Geocoding API
# Input: city name (e.g., "Paris, France" or "Paris, Texas, USA")
# Output: "latitude|longitude|display_name" or empty on error
_geocode_city() {
    local city="$1"
    [[ -z "$city" ]] && return 1

    # URL encode city name (spaces -> %20, commas -> %2C)
    local encoded_city
    encoded_city=$(printf '%s' "$city" | sed 's/ /%20/g; s/,/%2C/g')

    local url="https://geocoding-api.open-meteo.com/v1/search?name=${encoded_city}&count=1&language=en&format=json"

    # Fetch with 5s timeout
    local response
    response=$(safe_curl "$url" 5) || return 1

    # Parse response
    _parse_geocode_response "$response"
}

# Auto-detect location via IP using Open Meteo Geocoding API
# Output: "latitude|longitude|display_name" or empty on error
_geocode_auto() {
    # Open Meteo supports IP-based location with empty query
    local url="https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json"

    local response
    response=$(safe_curl "$url" 5) || {
        # Fallback: try to use last known location from cache (30 day TTL)
        local last_known
        last_known=$(cache_get "weather_last_known_location" 2592000)
        [[ -n "$last_known" ]] && printf '%s' "$last_known" && return 0
        return 1
    }

    _parse_geocode_response "$response"
}

# Main geocoding function with caching
# Input: location string (empty for auto-detect)
# Output: "latitude|longitude|display_name" or empty on error
# Cache: 24 hour TTL for geocoding results
_geocode_location() {
    local location="$1"
    local language="${2:-en}"

    # Generate collision-safe cache key
    # Format: geocode:{normalized_location}:{language}
    # Normalize: lowercase, trim, replace spaces with underscores
    local normalized
    if [[ -z "$location" ]]; then
        normalized=""
    else
        normalized=$(printf '%s' "$location" | \
            tr '[:upper:]' '[:lower:]' | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]]/_/g')
    fi

    local cache_key="geocode:${normalized}:${language}"

    # Check cache first (24 hour TTL)
    local cached
    cached=$(cache_get "$cache_key" 86400)
    if [[ -n "$cached" ]]; then
        printf '%s' "$cached"
        return 0
    fi

    # Perform geocoding
    local result
    if [[ -z "$location" ]]; then
        result=$(_geocode_auto)
    else
        result=$(_geocode_city "$location")
    fi

    # Cache successful result
    if [[ -n "$result" ]]; then
        cache_set "$cache_key" "$result"
        # Save as last known location (30 day TTL for fallback)
        cache_set "weather_last_known_location" "$result"
        printf '%s' "$result"
        return 0
    fi

    return 1
}

# =============================================================================
# Rate Limiting Protection
# =============================================================================

# Check if rate limit has been exceeded for the current hour
# Returns: 0 if request allowed, 1 if rate limited
_check_rate_limit() {
    local max_per_hour
    max_per_hour=$(get_option "max_requests_per_hour")

    # Get current hour bucket (format: YYYYMMDDHH)
    local hour_bucket
    hour_bucket=$(date +"%Y%m%d%H")
    local cache_key="weather_rate_limit:${hour_bucket}"

    # Get current count for this hour (default to 0)
    local current_count
    current_count=$(cache_get "$cache_key" "3600") || current_count="0"

    # Check if over limit
    if (( current_count >= max_per_hour )); then
        log_debug "weather" "Rate limit exceeded: ${current_count}/${max_per_hour}"
        return 1
    fi

    # Increment counter and cache it
    cache_set "$cache_key" "$((current_count + 1))"
    return 0
}

# =============================================================================
# API Functions
# =============================================================================

# Legacy wttr.in implementation (kept for potential rollback)
# _fetch_weather_legacy() {
#     local location units format_option language icon_mode
#     location=$(get_option "location")
#     units=$(get_option "units")
#     format_option=$(get_option "format")
#     language=$(get_option "language")
#     icon_mode=$(get_option "icon_mode")
#
#     # Resolve format presets to actual format strings
#     local format
#     format=$(_resolve_format "$format_option")
#
#     # URL encode location if provided
#     local encoded_location=""
#     if [[ -n "$location" ]]; then
#         encoded_location=$(printf '%s' "$location" | sed 's/ /%20/g')
#     fi
#
#     # For dynamic icon mode, extract symbol separately and remove %c from display format
#     local fetch_format="$format"
#     local needs_symbol=0
#     local sep="|||"
#     if [[ "$icon_mode" == "dynamic" ]]; then
#         # Remove %c from format (we'll get it separately)
#         local clean_format="${format//%c/}"
#         # Clean up extra spaces from removal
#         clean_format=$(printf '%s' "$clean_format" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]]\{2,\}/ /g')
#         fetch_format="%c${sep}${clean_format}"
#         needs_symbol=1
#     fi
#
#     # URL encode the format string (% -> %25, space -> %20, | -> %7C)
#     local encoded_format
#     encoded_format=$(printf '%s' "$fetch_format" | sed 's/%/%25/g; s/ /%20/g; s/|/%7C/g')
#
#     local url="http://wttr.in"
#     [[ -n "$encoded_location" ]] && url+="/$encoded_location"
#     url+="?format=${encoded_format}&${units}"
#     [[ -n "$language" ]] && url+="&lang=$language"
#
#     # Fetch with timeout (5s connect, 10s max - wttr.in can be slow)
#     local result
#     result=$(safe_curl "$url" 5 -L) || return 1
#
#     # Return only if we got valid data (not error messages)
#     if [[ -n "$result" && ! "$result" =~ ^(Unknown|Error|Sorry) ]]; then
#         if [[ "$needs_symbol" -eq 1 && "$result" == *"|||"* ]]; then
#             # Extract symbol and weather separately
#             local symbol="${result%%|||*}"
#             local weather="${result#*|||}"
#             # Output: symbol\nweather (newline separated for easy parsing)
#             printf '%s\n%s' "$symbol" "$weather"
#         else
#             printf '%s' "$result"
#         fi
#     fi
# }

# Fetch weather from Open Meteo API
# Returns: "json_response|location_name" or empty on error
_fetch_weather_openmeteo() {
    local location units format language
    location=$(get_option "location")
    units=$(get_option "units")
    format=$(get_option "format")
    language=$(get_option "language")

    # Step 1: Geocode location to get coordinates
    local geocode_result
    geocode_result=$(_geocode_location "$location" "$language") || return 1

    # Step 2: Parse geocode result
    local lat lon location_name
    IFS='|' read -r lat lon location_name <<< "$geocode_result"

    [[ -z "$lat" || -z "$lon" ]] && return 1

    # Step 3: Map units to Open Meteo parameters
    local temp_unit="celsius"
    local wind_unit="kmh"

    case "$units" in
        u)
            temp_unit="fahrenheit"
            wind_unit="mph"
            ;;
        M)
            # SI units: Celsius and m/s (Note: Kelvin not supported by Open Meteo)
            temp_unit="celsius"
            wind_unit="ms"
            ;;
        *)
            # Default: metric (Celsius, km/h)
            temp_unit="celsius"
            wind_unit="kmh"
            ;;
    esac

    # Step 4: Build API URL with current weather variables
    local url="https://api.open-meteo.com/v1/forecast"
    url+="?latitude=${lat}"
    url+="&longitude=${lon}"
    url+="&current=temperature_2m,relative_humidity_2m,apparent_temperature"
    url+=",precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,is_day"
    url+="&temperature_unit=${temp_unit}"
    url+="&wind_speed_unit=${wind_unit}"
    url+="&timezone=auto"
    url+="&format=json"

    # Step 5: Fetch with timeout
    local response
    response=$(safe_curl "$url" 5) || return 1

    # Step 6: Validate response - check for error patterns
    if [[ -z "$response" ]]; then
        return 1
    fi

    # Check for JSON error field
    if printf '%s' "$response" | grep -q '"error"'; then
        return 1
    fi

    # Check for invalid parameter errors
    if printf '%s' "$response" | grep -q '"reason": "Invalid'; then
        return 1
    fi

    # Step 7: Return response with location name (pipe-separated for parsing)
    printf '%s|%s' "$response" "$location_name"
}

# Main weather fetch function (uses Open Meteo API)
_fetch_weather() {
    _fetch_weather_openmeteo
}

# =============================================================================
# Format Resolution Functions
# =============================================================================

# Convert wind direction degrees (0-360) to 16-point compass notation
# Input: degrees (0-360, where 0=N, 90=E, 180=S, 270=W)
# Output: compass point (N, NNE, NE, ENE, E, ESE, SE, SSE, S, SSW, SW, WSW, W, WNW, NW, NNW)
_degrees_to_compass() {
    local degrees="$1"

    # Validate input
    [[ ! "$degrees" =~ ^[0-9]+(\.[0-9]+)?$ ]] && { printf 'N'; return; }

    # 16-point compass: each direction covers 22.5 degrees
    # Formula: index = ((degrees + 11.25) / 22.5) % 16
    # Using integer math: index = ((degrees + 11) / 22) % 16
    local index=$(( (${degrees%.*} + 11) / 22 % 16 ))

    local compass_points=(
        "N" "NNE" "NE" "ENE" "E" "ESE" "SE" "SSE"
        "S" "SSW" "SW" "WSW" "W" "WNW" "NW" "NNW"
    )

    printf '%s' "${compass_points[$index]}"
}

# Parse single JSON value using jq or regex fallback
# Input: json_data, key_path (e.g., "current.temperature_2m")
# Output: extracted value or empty string
_parse_json_value() {
    local json="$1"
    local key_path="$2"

    # Use jq if available
    if has_cmd "jq"; then
        local value
        value=$(printf '%s' "$json" | jq -r "$key_path // empty" 2>/dev/null)
        [[ -n "$value" && "$value" != "null" ]] && printf '%s' "$value"
        return
    fi

    # Fallback: regex parsing (fragile but better than nothing)
    # Convert dot notation to regex pattern
    # Example: "current.temperature_2m" -> match after "temperature_2m":<whitespace>value
    local key="${key_path##*.}"  # Get last part after dot

    # Match: "key": value (number) or "key": "value" (string)
    if [[ "$json" =~ \"$key\":[[:space:]]*([0-9.-]+) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    elif [[ "$json" =~ \"$key\":[[:space:]]*\"([^\"]+)\" ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}

# Resolve format strings with Open Meteo data
# Input: format, json_data, location_name
# Output: formatted string with placeholders replaced
_resolve_format_openmeteo() {
    local format="$1"
    local json_data="$2"
    local location_name="$3"

    # Resolve preset formats first
    case "$format" in
        compact)
            format='%t %c'
            ;;
        full)
            format='%t %c H:%h'
            ;;
        minimal)
            format='%t'
            ;;
        detailed)
            format='%l: %t %c'
            ;;
    esac

    # Parse all needed values from JSON
    local temp=$(_parse_json_value "$json_data" ".current.temperature_2m")
    local weather_code=$(_parse_json_value "$json_data" ".current.weather_code")
    local is_day=$(_parse_json_value "$json_data" ".current.is_day")
    local humidity=$(_parse_json_value "$json_data" ".current.relative_humidity_2m")
    local wind_speed=$(_parse_json_value "$json_data" ".current.wind_speed_10m")
    local wind_direction=$(_parse_json_value "$json_data" ".current.wind_direction_10m")
    local precipitation=$(_parse_json_value "$json_data" ".current.precipitation")

    # Get temperature unit from API response (e.g., "°C" or "°F")
    local temp_unit=$(_parse_json_value "$json_data" ".current_units.temperature_2m")

    # Format temperature with unit
    local temp_formatted=""
    if [[ -n "$temp" ]]; then
        # Remove + sign if configured
        local hide_plus=$(get_option "hide_plus_sign")
        if [[ "$hide_plus" == "true" ]]; then
            temp="${temp#+}"
        fi
        temp_formatted="${temp}${temp_unit}"
    fi

    # Get weather icon and description
    local weather_icon=""
    local weather_text=""
    if [[ -n "$weather_code" ]]; then
        weather_icon=$(_map_weather_code "$weather_code" "${is_day:-1}")
        weather_text=$(_get_weather_text "$weather_code")
    fi

    # Format wind with compass direction
    local wind_formatted=""
    if [[ -n "$wind_speed" && -n "$wind_direction" ]]; then
        local compass=$(_degrees_to_compass "$wind_direction")
        # Get wind speed unit from API response
        local wind_unit=$(_parse_json_value "$json_data" ".current_units.wind_speed_10m")
        wind_formatted="${wind_speed}${wind_unit} ${compass}"
    fi

    # Build placeholder replacements
    # Placeholder mapping (Open Meteo):
    #   %t - Temperature with unit (e.g., "15.2°C")
    #   %c - Weather condition icon
    #   %C - Weather condition text description
    #   %w - Wind speed with compass direction
    #   %h - Humidity percentage
    #   %l - Location name
    #   %p - Precipitation in mm
    #   %P - (not available - pressure not in Open Meteo free tier)
    #   %m - (not available - moon phase not in Open Meteo)

    local result="$format"
    result="${result//%t/$temp_formatted}"
    result="${result//%c/$weather_icon}"
    result="${result//%C/$weather_text}"
    result="${result//%w/$wind_formatted}"
    result="${result//%h/${humidity}%}"
    result="${result//%l/$location_name}"
    result="${result//%p/${precipitation}mm}"
    result="${result//%P/}"  # Empty - not available
    result="${result//%m/}"  # Empty - not available

    # Clean up: remove empty placeholders and extra spaces
    result=$(printf '%s' "$result" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]]\{2,\}/ /g')

    printf '%s' "$result"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    # Step 1: Check rate limiting first
    _check_rate_limit || {
        # Rate limited - try to use cached data
        local cached_weather
        cached_weather=$(cache_get "weather_plugin_weather" 3600)
        if [[ -n "$cached_weather" ]]; then
            plugin_data_set "weather" "$cached_weather"
            local cached_symbol
            cached_symbol=$(cache_get "weather_plugin_symbol" 3600)
            [[ -n "$cached_symbol" ]] && plugin_data_set "symbol" "$cached_symbol"
            return 0
        fi
        # No cache available - fail collection
        return 1
    }

    # Step 2: Fetch weather from Open Meteo
    local result
    result=$(_fetch_weather_openmeteo) || return 1

    # Step 3: Parse pipe-separated result (json_data|location_name)
    local json_data="${result%|*}"
    local location_name="${result##*|}"

    [[ -z "$json_data" ]] && return 1

    # Step 4: Get icon mode and extract weather code for dynamic icons
    local icon_mode symbol
    icon_mode=$(get_option "icon_mode")

    if [[ "$icon_mode" == "dynamic" ]]; then
        local weather_code is_day
        weather_code=$(_parse_json_value "$json_data" ".current.weather_code")
        is_day=$(_parse_json_value "$json_data" ".current.is_day")

        # Map weather code to icon (with day/night support)
        if [[ -n "$weather_code" ]]; then
            symbol=$(_map_weather_code "$weather_code" "${is_day:-1}")
        fi
    fi

    # Step 5: Format weather text using Open Meteo data
    local format_option weather_text
    format_option=$(get_option "format")
    weather_text=$(_resolve_format_openmeteo "$format_option" "$json_data" "$location_name")

    [[ -z "$weather_text" ]] && return 1

    # Step 6: Apply transformations
    # Remove + sign from positive temperatures if configured
    local hide_plus
    hide_plus=$(get_option "hide_plus_sign")
    [[ "$hide_plus" == "true" ]] && weather_text="${weather_text//+/}"

    # Limit to reasonable length (50 chars max)
    weather_text=$(truncate_text "$weather_text" 50 "...")

    # Step 7: Store data
    plugin_data_set "weather" "$weather_text"
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

