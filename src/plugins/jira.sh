#!/usr/bin/env bash
# =============================================================================
# Plugin: jira
# Description: Display Jira issues breakdown (in progress, backlog, blocked)
# Dependencies: curl, jq
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "jira"
    metadata_set "name" "Jira"
    metadata_set "description" "Display Jira issues breakdown by status"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    require_cmd "jq" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # API options
    declare_option "domain" "string" "" "Jira domain (e.g., company.atlassian.net)"
    declare_option "email" "string" "" "Jira email"
    declare_option "token" "string" "" "Jira API token"
    declare_option "project" "string" "" "Filter by project key"
    declare_option "jql" "string" "" "Custom JQL query (overrides default)"

    # Display options
    declare_option "format" "string" "breakdown" "Display format: count, breakdown"
    declare_option "separator" "string" " | " "Separator between metrics"

    # Icons
    declare_option "icon" "icon" $'\U000F0303' "Plugin icon"
    declare_option "icon_progress" "icon" $'\U000F0E4E' "Icon for in-progress issues"
    declare_option "icon_todo" "icon" $'\U000F0E4F' "Icon for backlog issues"
    declare_option "icon_flagged" "icon" $'\U000F0229' "Icon for blocked issues"

    # Thresholds
    declare_option "warning_threshold_progress" "number" "3" "Warning when in-progress issues exceed threshold"
    declare_option "warning_threshold_backlog" "number" "10" "Warning when backlog issues exceed threshold"

    # Keybindings
    declare_option "keybinding_issues" "string" "" "Keybinding for issue selector"
    declare_option "popup_width" "string" "60%" "Popup width"
    declare_option "popup_height" "string" "80%" "Popup height"

    # Cache
    declare_option "cache_ttl" "number" "120" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

_is_configured() {
    local domain email token
    domain=$(get_option "domain")
    email=$(get_option "email")
    token=$(get_option "token")
    
    [[ -n "$domain" && -n "$email" && -n "$token" ]] && return 0
    return 1
}

plugin_get_state() {
    if ! _is_configured; then
        printf 'failed'
        return
    fi
    local in_progress todo flagged
    in_progress=$(plugin_data_get "in_progress")
    todo=$(plugin_data_get "todo")
    flagged=$(plugin_data_get "flagged")
    local total=$((${in_progress:-0} + ${todo:-0} + ${flagged:-0}))
    [[ "$total" -gt 0 ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    if ! _is_configured; then
        printf 'error'
        return
    fi
    
    local flagged in_progress todo
    flagged=$(plugin_data_get "flagged")
    in_progress=$(plugin_data_get "in_progress")
    todo=$(plugin_data_get "todo")
    
    # Blocked issues are always error
    [[ "${flagged:-0}" -gt 0 ]] && { printf 'error'; return; }
    
    local threshold_progress threshold_backlog
    threshold_progress=$(get_option "warning_threshold_progress")
    threshold_backlog=$(get_option "warning_threshold_backlog")
    
    # Check thresholds
    [[ "${in_progress:-0}" -ge "$threshold_progress" ]] && { printf 'warning'; return; }
    [[ "${todo:-0}" -ge "$threshold_backlog" ]] && { printf 'warning'; return; }
    
    printf 'ok'
}

plugin_get_context() {
    if ! _is_configured; then
        printf 'unconfigured'
        return
    fi
    
    local flagged in_progress
    flagged=$(plugin_data_get "flagged")
    in_progress=$(plugin_data_get "in_progress")
    
    [[ "${flagged:-0}" -gt 0 ]] && { printf 'blocked'; return; }
    [[ "${in_progress:-0}" -gt 0 ]] && { printf 'working'; return; }
    printf 'idle'
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

# Build JQL query
_build_jql() {
    local jql project
    jql=$(get_option "jql")
    project=$(get_option "project")

    if [[ -n "$jql" ]]; then
        printf '%s' "$jql"
        return
    fi

    # Default: assigned to me, not done
    local query="assignee = currentUser() AND resolution = Unresolved"
    [[ -n "$project" ]] && query+=" AND project = ${project}"
    query+=" ORDER BY priority DESC, updated DESC"

    printf '%s' "$query"
}

# Check if issue is blocked by status name
_is_blocked_by_status() {
    local status_name="$1"
    local lower_status="${status_name,,}"

    [[ "$lower_status" == *blocked* ]] && return 0
    [[ "$lower_status" == *impediment* ]] && return 0
    [[ "$lower_status" == *waiting* ]] && return 0
    [[ "$lower_status" == *"on hold"* ]] && return 0
    [[ "$lower_status" == *paused* ]] && return 0
    return 1
}

# Fetch and categorize issues
_fetch_jira_breakdown() {
    local domain email token jql
    domain=$(get_option "domain")
    email=$(get_option "email")
    token=$(get_option "token")
    jql=$(_build_jql)

    [[ -z "$domain" || -z "$email" || -z "$token" ]] && return 1

    # URL encode JQL query
    local encoded_jql
    encoded_jql=$(printf '%s' "$jql" | sed 's/ /%20/g; s/=/%3D/g; s/"/%22/g; s/(/%28/g; s/)/%29/g; s/!/%21/g; s/'\''/%27/g')

    local in_progress=0
    local todo=0
    local flagged=0
    local next_token=""

    # Paginate through results
    while true; do
        # Request status and impediment custom fields
        local url="https://${domain}/rest/api/3/search/jql?jql=${encoded_jql}&maxResults=100&fields=status,customfield_10177,customfield_10178"
        [[ -n "$next_token" ]] && url+="&nextPageToken=${next_token}"

        local response
        response=$(curl -sf --connect-timeout 10 --max-time 20 \
            -u "${email}:${token}" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            "$url" 2>/dev/null)
        
        [[ -z "$response" ]] && break

        # Check for errors
        if echo "$response" | jq -e '.errorMessages' &>/dev/null; then
            return 1
        fi

        # Count issues by status category
        # customfield_10177 = Início Impedimento (not null = has impediment start)
        # customfield_10178 = Fim Impedimento (null = impediment not ended)
        while IFS='|' read -r status_name status_category is_flagged; do
            [[ -z "$status_name" ]] && continue

            # Check if flagged (by impediment fields OR by status name)
            if [[ "$is_flagged" == "true" ]] || _is_blocked_by_status "$status_name"; then
                ((flagged++))
            elif [[ "$status_category" == "In Progress" ]]; then
                ((in_progress++))
            elif [[ "$status_category" == "To Do" ]]; then
                ((todo++))
            fi
        done < <(echo "$response" | jq -r '.issues[]? | "\(.fields.status.name // "Unknown")|\(.fields.status.statusCategory.name // "Unknown")|\(if (.fields.customfield_10177 != null and .fields.customfield_10178 == null) then "true" else "false" end)"' 2>/dev/null)

        # Check if last page
        local is_last
        is_last=$(echo "$response" | jq -r '.isLast // true' 2>/dev/null)
        [[ "$is_last" == "true" ]] && break

        # Get next page token
        next_token=$(echo "$response" | jq -r '.nextPageToken // empty' 2>/dev/null)
        [[ -z "$next_token" ]] && break
    done

    # Return as pipe-separated values
    printf '%d|%d|%d' "$in_progress" "$todo" "$flagged"
}

plugin_collect() {
    local result
    result=$(_fetch_jira_breakdown)

    if [[ -n "$result" ]]; then
        local in_progress todo flagged
        IFS='|' read -r in_progress todo flagged <<< "$result"
        plugin_data_set "in_progress" "${in_progress:-0}"
        plugin_data_set "todo" "${todo:-0}"
        plugin_data_set "flagged" "${flagged:-0}"
    else
        plugin_data_set "in_progress" "0"
        plugin_data_set "todo" "0"
        plugin_data_set "flagged" "0"
    fi
}

plugin_render() {
    if ! _is_configured; then
        return 0
    fi
    
    local format separator
    format=$(get_option "format")
    separator=$(get_option "separator")

    local in_progress todo flagged
    in_progress=$(plugin_data_get "in_progress")
    todo=$(plugin_data_get "todo")
    flagged=$(plugin_data_get "flagged")

    in_progress="${in_progress:-0}"
    todo="${todo:-0}"
    flagged="${flagged:-0}"

    local total=$((in_progress + todo + flagged))
    [[ "$total" -eq 0 ]] && return 0

    if [[ "$format" == "count" ]]; then
        printf '%s' "$total"
        return
    fi

    # Breakdown format with icons
    local icon_progress icon_todo icon_flagged
    icon_progress=$(get_option "icon_progress")
    icon_todo=$(get_option "icon_todo")
    icon_flagged=$(get_option "icon_flagged")

    local output=""
    [[ "$in_progress" -gt 0 ]] && output+="${icon_progress}${in_progress}"
    [[ "$todo" -gt 0 ]] && output+="${output:+${separator}}${icon_todo}${todo}"
    [[ "$flagged" -gt 0 ]] && output+="${output:+${separator}}${icon_flagged}${flagged}"

    printf '%s' "$output"
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

    [[ -n "$issues_key" ]] && pk_bind_popup "$issues_key" "bash '$helper_script'" "$width" "$height" "jira:issues"
}

