#!/usr/bin/env bash
# =============================================================================
# Plugin: packages
# Description: Display pending package updates
# Dependencies: package manager (brew/apt/yum/pacman)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "packages"
    metadata_set "name" "Packages"
    metadata_set "description" "Display pending package updates"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "brew" "apt" "yum" "pacman" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show_count" "bool" "true" "Show update count"

    # Icons
    declare_option "icon" "icon" $'\U000F0C62' "Plugin icon"

    # Thresholds
    declare_option "warning_threshold" "number" "10" "Warning threshold"
    declare_option "critical_threshold" "number" "50" "Critical threshold"

    # Cache (check for updates infrequently)
    declare_option "cache_ttl" "number" "3600" "Cache duration in seconds (1 hour)"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }
plugin_get_state() {
    local count=$(plugin_data_get "update_count")
    [[ "${count:-0}" -gt 0 ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local count warn_th crit_th
    count=$(plugin_data_get "update_count")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    count="${count:-0}"
    warn_th="${warn_th:-10}"
    crit_th="${crit_th:-50}"

    if (( count >= crit_th )); then
        printf 'error'
    elif (( count >= warn_th )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

plugin_get_context() {
    local count=$(plugin_data_get "update_count")
    count="${count:-0}"
    
    if (( count == 0 )); then
        printf 'up_to_date'
    elif (( count <= 5 )); then
        printf 'few_updates'
    elif (( count <= 20 )); then
        printf 'some_updates'
    else
        printf 'many_updates'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

_count_updates_brew() {
    local outdated
    outdated=$(brew outdated --quiet 2>/dev/null | wc -l)
    echo "$outdated" | tr -d ' '
}

_count_updates_apt() {
    # Requires apt-get update to be run first, but we skip that for performance
    apt list --upgradable 2>/dev/null | grep -c "upgradable"
}

_count_updates_yum() {
    yum list updates 2>/dev/null | grep -c "^[^[:space:]]"
}

_count_updates_pacman() {
    pacman -Qu 2>/dev/null | wc -l | tr -d ' '
}

_count_package_updates() {
    if has_cmd "brew"; then
        _count_updates_brew
    elif has_cmd "apt-get"; then
        _count_updates_apt
    elif has_cmd "yum"; then
        _count_updates_yum
    elif has_cmd "pacman"; then
        _count_updates_pacman
    else
        echo "0"
    fi
}

plugin_collect() {
    local count
    count=$(_count_package_updates)
    plugin_data_set "update_count" "${count:-0}"
}

plugin_render() {
    local count show_count
    count=$(plugin_data_get "update_count")
    show_count=$(get_option "show_count")

    [[ "${count:-0}" -eq 0 ]] && return 0

    if [[ "$show_count" == "true" ]]; then
        printf '%s updates' "$count"
    else
        printf 'Updates available'
    fi
}

