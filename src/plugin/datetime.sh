#!/usr/bin/env bash
# Plugin: datetime - Display current date/time with advanced formatting

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# Predefined formats
declare -A FORMATS=(
    ["time"]="%H:%M"
    ["time-seconds"]="%H:%M:%S"
    ["time-12h"]="%I:%M %p"
    ["time-12h-seconds"]="%I:%M:%S %p"
    ["date"]="%d/%m"
    ["date-us"]="%m/%d"
    ["date-full"]="%d/%m/%Y"
    ["date-full-us"]="%m/%d/%Y"
    ["date-iso"]="%Y-%m-%d"
    ["datetime"]="%d/%m %H:%M"
    ["datetime-us"]="%m/%d %I:%M %p"
    ["weekday"]="%a %H:%M"
    ["weekday-full"]="%A %H:%M"
    ["full"]="%a, %d %b %H:%M"
    ["full-date"]="%a, %d %b %Y"
    ["iso"]="%Y-%m-%dT%H:%M:%S"
)

# Configuration
_format=$(get_tmux_option "@powerkit_plugin_datetime_format" "$POWERKIT_PLUGIN_DATETIME_FORMAT")
_timezone=$(get_tmux_option "@powerkit_plugin_datetime_timezone" "$POWERKIT_PLUGIN_DATETIME_TIMEZONE")
_show_week=$(get_tmux_option "@powerkit_plugin_datetime_show_week" "$POWERKIT_PLUGIN_DATETIME_SHOW_WEEK")
_separator=$(get_tmux_option "@powerkit_plugin_datetime_separator" "$POWERKIT_PLUGIN_DATETIME_SEPARATOR")

plugin_get_type() { printf 'static'; }

plugin_get_display_info() {
    build_display_info "1" "" "" ""
}

# Resolve predefined or custom format
resolve_format() {
    local f="${1:-}"
    printf '%s' "${FORMATS[$f]:-$f}"
}

load_plugin() {
    local out="" sep="${_separator:- }"
    local fmt=$(resolve_format "$_format")

    # Week number
    [[ "$_show_week" == "true" ]] && out="$(date +W%V 2>/dev/null || date +W%W)${sep}"

    # Main datetime
    out+=$(date +"$fmt" 2>/dev/null)

    # Secondary timezone
    [[ -n "$_timezone" ]] && out+="${sep}$(TZ="$_timezone" date +%H:%M 2>/dev/null)"

    printf '%s' "$out"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
