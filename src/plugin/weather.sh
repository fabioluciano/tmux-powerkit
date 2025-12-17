#!/usr/bin/env bash
# Plugin: weather - Display weather information from wttr.in API

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "weather"

WEATHER_LOCATION_CACHE_KEY="weather_location"
WEATHER_LOCATION_CACHE_TTL="3600"
WEATHER_SYMBOL_CACHE_KEY="weather_symbol"

plugin_get_type() { printf 'conditional'; }

resolve_format() {
    case "$1" in
        compact)  printf '%s' '%t %c' ;;
        full)     printf '%s' '%t %c H:%h' ;;
        minimal)  printf '%s' '%t' ;;
        detailed) printf '%s' '%l: %t %c' ;;
        *)        printf '%s' "$1" ;;
    esac
}

weather_detect_location() {
    local cached_location
    if cached_location=$(cache_get "$WEATHER_LOCATION_CACHE_KEY" "$WEATHER_LOCATION_CACHE_TTL"); then
        printf '%s' "$cached_location"
        return 0
    fi

    require_cmd jq 1 || return 1

    local location
    location=$(safe_curl "http://ip-api.com/json" 5 | jq -r '"\(.city), \(.country)"' 2>/dev/null)

    if [[ -n "$location" && "$location" != "null, null" && "$location" != ", " ]]; then
        cache_set "$WEATHER_LOCATION_CACHE_KEY" "$location"
        printf '%s' "$location"
        return 0
    fi
    return 1
}

weather_fetch() {
    local location="$1"
    local format unit
    format=$(get_cached_option "@powerkit_plugin_weather_format" "$POWERKIT_PLUGIN_WEATHER_FORMAT")
    unit=$(get_cached_option "@powerkit_plugin_weather_unit" "$POWERKIT_PLUGIN_WEATHER_UNIT")

    # resolve_format handles both presets and custom formats
    local resolved_format
    resolved_format=$(resolve_format "$format")

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
weather_fetch_symbol() {
    local location="$1"
    local unit
    unit=$(get_cached_option "@powerkit_plugin_weather_unit" "$POWERKIT_PLUGIN_WEATHER_UNIT")
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

plugin_get_display_info() {
    local content="${1:-}"
    local show="0" icon="" accent="" accent_icon=""
    [[ -n "$content" && "$content" != "N/A" ]] && show="1"

    # Defaults
    accent=$(get_cached_option "@powerkit_plugin_weather_accent_color" "$POWERKIT_PLUGIN_WEATHER_ACCENT_COLOR")
    accent_icon=$(get_cached_option "@powerkit_plugin_weather_accent_color_icon" "$POWERKIT_PLUGIN_WEATHER_ACCENT_COLOR_ICON")
    icon=$(get_cached_option "@powerkit_plugin_weather_icon" "$POWERKIT_PLUGIN_WEATHER_ICON")

    # Optional: dynamic icon based on wttr condition symbol (%c)
    local icon_mode
    icon_mode=$(get_cached_option "@powerkit_plugin_weather_icon_mode" "$POWERKIT_PLUGIN_WEATHER_ICON_MODE")
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

_compute_weather() {
    local location
    location=$(get_cached_option "@powerkit_plugin_weather_location" "$POWERKIT_PLUGIN_WEATHER_LOCATION")

    local result
    result=$(weather_fetch "$location")

    # Fetch and cache symbol for dynamic icon mode (independent of format)
    local icon_mode
    icon_mode=$(get_cached_option "@powerkit_plugin_weather_icon_mode" "$POWERKIT_PLUGIN_WEATHER_ICON_MODE")
    if [[ "$icon_mode" == "dynamic" ]]; then
        local symbol
        symbol=$(weather_fetch_symbol "$location")
        [[ -n "$symbol" ]] && cache_set "$WEATHER_SYMBOL_CACHE_KEY" "$symbol"
    fi

    printf '%s' "$result"
}

load_plugin() {
    require_cmd curl || return 0

    # Use defer_plugin_load for network operations with lazy loading
    defer_plugin_load "$CACHE_KEY" cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_weather
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
