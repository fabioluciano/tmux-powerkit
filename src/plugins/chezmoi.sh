
#!/usr/bin/env bash
# =============================================================================
# Plugin: chezmoi
# Description: Display pending differences detected by chezmoi in safe mode
# Type: conditional (hidden when no differences are detected)
# Dependencies: chezmoi
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active:   There are pending differences detected by chezmoi
#   - inactive: No differences detected, or chezmoi is not initialized
#
# Health:
#   - ok:      count is 0 (fallback, normally plugin is inactive/hidden)
#   - info:    count is below warning threshold
#   - warning: count is at or above warning threshold
#   - error:   count is at or above critical threshold
#
# Context:
#   - chezmoi_ok, chezmoi_info, chezmoi_warning, chezmoi_error
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "chezmoi"
    metadata_set "name" "Chezmoi"
    metadata_set "description" "Display pending differences detected by chezmoi in safe mode"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "chezmoi" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U000F0494' "Plugin icon"

    # Thresholds
    declare_option "warning_threshold"  "number" "5"  "Warning threshold (number of pending differences)"
    declare_option "critical_threshold" "number" "20" "Critical threshold (number of pending differences)"

    # Safe status mode excludes types that can trigger scripts, template evaluation,
    # secret manager calls, or external refreshes.
    declare_option "exclude_types" "string" "scripts,always,templates,encrypted,externals" "Comma-separated chezmoi entry types to exclude from status"

    # Cache
    declare_option "cache_ttl" "number" "60" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence()     { printf 'conditional'; }

# =============================================================================
# Plugin Contract: State
# =============================================================================

plugin_get_state() {
    local available count
    available=$(plugin_data_get "available")
    count=$(plugin_data_get "count")

    [[ "$available" != "1" ]] && { printf 'inactive'; return; }
    [[ "${count:-0}" -gt 0 ]] && printf 'active' || printf 'inactive'
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================

plugin_get_health() {
    local count warn_th crit_th
    count=$(plugin_data_get "count")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    count="${count:-0}"
    warn_th="${warn_th:-5}"
    crit_th="${crit_th:-20}"

    if (( count >= crit_th )); then
        printf 'error'
    elif (( count >= warn_th )); then
        printf 'warning'
    elif (( count > 0 )); then
        printf 'info'
    else
        printf 'ok'
    fi
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================

plugin_get_context() {
    plugin_context_from_health "$(plugin_get_health)" "chezmoi"
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() {
    get_option "icon"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    plugin_data_set "available" "0"
    plugin_data_set "count" "0"

    # Verify chezmoi is initialized (source dir must exist)
    local source_path exclude_types status_output count
    source_path=$(chezmoi source-path 2>/dev/null) || return 0
    [[ -n "$source_path" && -d "$source_path" ]] || return 0

    plugin_data_set "available" "1"

    exclude_types=$(get_option "exclude_types")

    # Use chezmoi status in a non-interactive safe mode.
    # Excluding templates/encrypted/scripts avoids template rendering and secret
    # manager prompts, while still detecting real source/target differences for
    # the remaining entry types.
    status_output=$(chezmoi status --no-pager --no-tty --exclude "$exclude_types" 2>/dev/null) || return 1

    if [[ -z "$status_output" ]]; then
        count=0
    else
        count=$(printf '%s\n' "$status_output" | grep -c '.')
    fi

    plugin_data_set "count" "${count:-0}"
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local count
    count=$(plugin_data_get "count")
    printf '%d' "${count:-0}"
}
