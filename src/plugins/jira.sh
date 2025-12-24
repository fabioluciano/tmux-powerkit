#!/usr/bin/env bash
# =============================================================================
# Plugin: jira
# Description: Display Jira issue status (requires jira CLI or API token)
# Dependencies: curl
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "jira"
    metadata_set "name" "Jira"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display Jira assigned issues count"
    metadata_set "priority" "100"
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
    # API options
    declare_option "domain" "string" "" "Jira domain (e.g., company.atlassian.net)"
    declare_option "email" "string" "" "Jira email"
    declare_option "api_token" "string" "" "Jira API token"
    declare_option "jql" "string" "assignee=currentuser() AND status!=Done" "JQL query"

    # Display options
    declare_option "show_count" "bool" "true" "Show issue count"

    # Icons
    declare_option "icon" "icon" $'\U000F0BE7' "Plugin icon"

    # Keybindings
    declare_option "keybinding_issues" "string" "" "Keybinding for issue selector"
    declare_option "popup_width" "string" "80%" "Popup width"
    declare_option "popup_height" "string" "80%" "Popup height"

    # Cache
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds (5 min)"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

_is_configured() {
    local domain email api_token
    domain=$(get_option "domain")
    email=$(get_option "email")
    api_token=$(get_option "api_token")
    
    [[ -n "$domain" && -n "$email" && -n "$api_token" ]] && return 0
    return 1
}

plugin_get_state() {
    if ! _is_configured; then
        printf 'failed'
        return
    fi
    local count=$(plugin_data_get "count")
    [[ "${count:-0}" -gt 0 ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    if ! _is_configured; then
        printf 'error'
        return
    fi
    local count=$(plugin_data_get "count")
    [[ "${count:-0}" -gt 10 ]] && printf 'warning' || printf 'ok'
}

plugin_get_context() {
    if ! _is_configured; then
        printf 'unconfigured'
        return
    fi
    
    local count=$(plugin_data_get "count")
    count="${count:-0}"
    
    if (( count == 0 )); then
        printf 'clear'
    elif (( count <= 3 )); then
        printf 'light'
    elif (( count <= 7 )); then
        printf 'moderate'
    else
        printf 'busy'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

_fetch_jira_issues() {
    local domain email api_token jql
    domain=$(get_option "domain")
    email=$(get_option "email")
    api_token=$(get_option "api_token")
    jql=$(get_option "jql")

    [[ -z "$domain" || -z "$email" || -z "$api_token" ]] && return 1

    local url="https://${domain}/rest/api/3/search"
    local encoded_jql=$(printf '%s' "$jql" | sed 's/ /%20/g; s/"/%22/g')
    url+="?jql=${encoded_jql}&maxResults=0"

    local response
    response=$(make_api_call "$url" "basic" "${email}:${api_token}" 5)

    [[ -z "$response" ]] && return 1

    # Extract total count from JSON
    json_get_value "$response" "total"
}

plugin_collect() {
    local count
    count=$(_fetch_jira_issues)

    plugin_data_set "count" "${count:-0}"
}

plugin_render() {
    local count show_count
    count=$(plugin_data_get "count")
    show_count=$(get_option "show_count")

    [[ "${count:-0}" -eq 0 ]] && return 0

    if [[ "$show_count" == "true" ]]; then
        printf '%s issues' "$count"
    else
        printf 'Jira'
    fi
}

# =============================================================================
# Keybindings
# =============================================================================

plugin_setup_keybindings() {
    local issues_key width height helper_script
    issues_key=$(get_option "keybinding_issues")
    width=$(get_option "popup_width")
    height=$(get_option "popup_height")
    helper_script="${POWERKIT_ROOT}/src/helpers/jira_issue_selector.sh"

    pk_bind_popup "$issues_key" "bash '$helper_script'" "$width" "$height" "jira:issues"
}

