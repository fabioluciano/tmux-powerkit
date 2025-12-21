#!/usr/bin/env bash
# =============================================================================
# Plugin: datetime
# Description: Display current date/time with advanced formatting
# Type: static (always visible, no threshold colors)
# Dependencies: None
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "format" "string" "datetime" "Date/time format (time|date|datetime|full|iso or custom strftime)"
    declare_option "timezone" "string" "" "Secondary timezone to display"
    declare_option "show_week" "bool" "false" "Show ISO week number"
    declare_option "separator" "string" " " "Separator between elements"

    # Icons
    declare_option "icon" "icon" $'\U000F0954' "Plugin icon (nf-mdi-calendar_clock)"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"
}

plugin_init "datetime"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'static'; }

plugin_get_display_info() { default_plugin_display_info "${1:-}"; }

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

load_plugin() {
    local format timezone show_week separator
    format=$(get_option "format")
    timezone=$(get_option "timezone")
    show_week=$(get_option "show_week")
    separator=$(get_option "separator")

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

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
