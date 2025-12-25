#!/usr/bin/env bash
# =============================================================================
# Plugin: datetime
# Description: Display current date/time with advanced formatting
# Type: static (always visible, no threshold colors)
# Dependencies: None
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "datetime"
    metadata_set "name" "DateTime"
    metadata_set "description" "Display current date/time with advanced formatting"
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "format" "string" "datetime" "Date/time format (time|date|datetime|full|iso or custom strftime)"
    declare_option "timezone" "string" "" "Secondary timezone to display"
    declare_option "show_week" "bool" "false" "Show ISO week number"
    declare_option "separator" "string" " " "Separator between elements"

    # Icons
    declare_option "icon" "icon" $'\U000F0954' "Plugin icon (nf-mdi-calendar_clock)"

    # Cache - time changes constantly, keep TTL short for accuracy
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local hour=$(date +%H)
    if (( hour >= 6 && hour < 12 )); then
        printf 'morning'
    elif (( hour >= 12 && hour < 18 )); then
        printf 'afternoon'
    elif (( hour >= 18 && hour < 22 )); then
        printf 'evening'
    else
        printf 'night'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

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

_resolve_format() {
    local f="${1:-}"
    printf '%s' "${FORMATS[$f]:-$f}"
}

plugin_collect() {
    local format timezone show_week separator
    format=$(get_option "format")
    timezone=$(get_option "timezone")
    show_week=$(get_option "show_week")
    separator=$(get_option "separator")

    plugin_data_set "format" "$format"
    plugin_data_set "timezone" "$timezone"
    plugin_data_set "show_week" "$show_week"
    plugin_data_set "separator" "$separator"
}

plugin_render() {
    local format timezone show_week separator
    format=$(plugin_data_get "format")
    timezone=$(plugin_data_get "timezone")
    show_week=$(plugin_data_get "show_week")
    separator=$(plugin_data_get "separator")

    local out="" sep="${separator:- }"
    local fmt=$(_resolve_format "$format")

    # Week number
    [[ "$show_week" == "true" ]] && out="$(date +W%V 2>/dev/null || date +W%W)${sep}"

    # Main datetime
    out+=$(date +"$fmt" 2>/dev/null)

    # Secondary timezone
    [[ -n "$timezone" ]] && out+="${sep}$(TZ="$timezone" date +%H:%M 2>/dev/null)"

    printf '%s' "$out"
}

