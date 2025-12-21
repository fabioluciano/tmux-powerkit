#!/usr/bin/env bash
# =============================================================================
# Plugin: weather
# Description: Display weather information from wttr.in API
# Type: conditional (hidden when weather unavailable)
# Dependencies: curl, jq (optional)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    require_cmd "jq" 1  # Optional
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "location" "string" "" "Weather location (auto-detected if empty)"
    declare_option "format" "string" "compact" "Format (compact, full, minimal, detailed, or custom wttr.in format)"
    declare_option "unit" "string" "m" "Unit system (m for metric, u for imperial)"
    declare_option "icon_mode" "string" "static" "Icon mode (static or dynamic)"

    # Icons
    declare_option "icon" "icon" $'\U000F00C2' "Plugin icon (when icon_mode is static)"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "1800" "Cache duration in seconds"
}

plugin_init "weather"

WEATHER_LOCATION_CACHE_KEY="weather_location"
WEATHER_LOCATION_CACHE_TTL="3600"
WEATHER_SYMBOL_CACHE_KEY="weather_symbol"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    local show="0" icon="" accent="" accent_icon=""
    [[ -n "$content" && "$content" != "N/A" ]] && show="1"

    # Defaults
    accent=$(get_option "accent_color")
    accent_icon=$(get_option "accent_color_icon")
    icon=$(get_option "icon")

    # Optional: dynamic icon based on wttr condition symbol (%c)
    local icon_mode
    icon_mode=$(get_option "icon_mode")
    if [[ "$show" == "1" && "$icon_mode" == "dynamic" ]]; then
        # Read symbol from cache (set by load_plugin)
        local symbol
        symbol=$(cache_get "$WEATHER_SYMBOL_CACHE_KEY" "$CACHE_TTL" 2>/dev/null) || symbol=""

        if [[ -n "$symbol" && "$symbol" != "N/A" ]]; then
            icon="$symbol"
        fi
    fi

    echo "${show}:${accent}:${accent_icon}:${icon}"
}

# =============================================================================
# Helper Functions
# =============================================================================

_resolve_format() {
    case "$1" in
    compact) printf '%s' '%t %c' ;;
    full) printf '%s' '%t %c H:%h' ;;
    minimal) printf '%s' '%t' ;;
    detailed) printf '%s' '%l: %t %c' ;;
    *) printf '%s' "$1" ;;
    esac
}

_weather_detect_location() {
    local cached_location
    if cached_location=$(cache_get "$WEATHER_LOCATION_CACHE_KEY" "$WEATHER_LOCATION_CACHE_TTL"); then
        printf '%s' "$cached_location"
        return 0
    fi

    has_cmd jq || return 1

    local location
    location=$(safe_curl "http://ip-api.com/json" 5 | jq -r '"\(.city), \(.country)"' 2>/dev/null)

    if [[ -n "$location" && "$location" != "null, null" && "$location" != ", " ]]; then
        cache_set "$WEATHER_LOCATION_CACHE_KEY" "$location"
        printf '%s' "$location"
        return 0
    fi
    return 1
}

_weather_fetch() {
    local location="$1"
    local format unit
    format=$(get_option "format")
    unit=$(get_option "unit")

    # _resolve_format handles both presets and custom formats
    local resolved_format
    resolved_format=$(_resolve_format "$format")

    local url="wttr.in/"
    [[ -n "$location" ]] && url+="$(printf '%s' "$location" | sed 's/ /%20/g; s/,/%2C/g')"
    url+="?"
    [[ -n "$unit" ]] && url+="${unit}&"
    url+="format=$(printf '%s' "$resolved_format" | sed 's/%/%25/g; s/ /%20/g; s/:/%3A/g; s/+/%2B/g')"

    local weather
    weather=$(safe_curl "$url" 5 -L)
    weather=$(printf '%s' "$weather" | sed 's/%$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
    command -v perl &>/dev/null && weather=$(printf '%s' "$weather" | perl -CS -pe 's/\x{FE0E}|\x{FE0F}//g')

    if [[ -z "$weather" || "$weather" == *"Unknown"* || "$weather" == *"ERROR"* || ${#weather} -gt 100 ]]; then
        log_warn "weather" "Failed to fetch weather data for location: ${location:-auto}"
        printf 'N/A'
        return 1
    fi
    log_debug "weather" "Successfully fetched weather: $weather"
    printf '%s' "$weather"
}

# Fetch only condition symbol (%c) for dynamic icon mapping
_weather_fetch_symbol() {
    local location="$1"
    local unit
    unit=$(get_option "unit")
    local url="wttr.in/"
    [[ -n "$location" ]] && url+="$(printf '%s' "$location" | sed 's/ /%20/g; s/,/%2C/g')"
    url+="?"
    [[ -n "$unit" ]] && url+="${unit}&"
    url+="format=%25c"
    local symbol
    symbol=$(safe_curl "$url" 5 -L)
    symbol=$(printf '%s' "$symbol" | sed 's/%$//; s/[[:space:]]*$//')
    command -v perl &>/dev/null && symbol=$(printf '%s' "$symbol" | perl -CS -pe 's/\x{FE0E}|\x{FE0F}//g')
    printf '%s' "$symbol "
}

# =============================================================================
# Main Logic
# =============================================================================

_compute_weather() {
    local location
    location=$(get_option "location")

    local result
    result=$(_weather_fetch "$location")

    # Fetch and cache symbol for dynamic icon mode (independent of format)
    local icon_mode
    icon_mode=$(get_option "icon_mode")
    if [[ "$icon_mode" == "dynamic" ]]; then
        local symbol
        symbol=$(_weather_fetch_symbol "$location")
        [[ -n "$symbol" ]] && cache_set "$WEATHER_SYMBOL_CACHE_KEY" "$symbol"
    fi

    printf '%s' "$result"
}

load_plugin() {
    # Runtime check - dependency contract handles notification
    has_cmd curl || return 0

    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_weather
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
