#!/usr/bin/env bash
# Plugin: livetennis
# Description: Live tennis snapshots with a shared request limit.
# Dependencies: python3, jq

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

plugin_get_metadata() {
    metadata_set "id" "livetennis"
    metadata_set "name" "Live tennis"
    metadata_set "description" "Live tennis snapshots with their capture time"
}

plugin_check_dependencies() {
    require_cmd "python3" || return 1
    require_cmd "jq" || return 1
    return 0
}

plugin_declare_options() {
    declare_option "player" "string" "" "Local player name filter"
    declare_option "icon" "icon" "T" "Plugin icon"
    declare_option "cache_ttl" "number" "60" "Display cache duration in seconds"
}

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }

plugin_collect() {
    local response text state health context player
    player=$(get_option "player")
    response=$(python3 "${POWERKIT_ROOT}/src/plugins/livetennis/cache.py" "--player=$player") || return 1

    printf '%s' "$response" | jq -e '
        (.text | type == "string") and
        (.state == "active" or .state == "degraded" or .state == "failed") and
        (.health == "ok" or .health == "warning" or .health == "error") and
        (.context | type == "string")
    ' >/dev/null 2>&1 || return 1
    text=$(printf '%s' "$response" | jq -r '.text') || return 1
    state=$(printf '%s' "$response" | jq -r '.state') || return 1
    health=$(printf '%s' "$response" | jq -r '.health') || return 1
    context=$(printf '%s' "$response" | jq -r '.context') || return 1

    plugin_data_set "text" "$text"
    plugin_data_set "state" "$state"
    plugin_data_set "health" "$health"
    plugin_data_set "context" "$context"
}

plugin_render() { plugin_data_get "text"; }
_livetennis_status() {
    local value
    value=$(plugin_data_get "$1")
    printf '%s' "${value:-$2}"
}

plugin_get_state() { _livetennis_status "state" "failed"; }
plugin_get_health() { _livetennis_status "health" "error"; }
plugin_get_context() { _livetennis_status "context" "unavailable"; }
plugin_get_icon() { get_option "icon"; }
