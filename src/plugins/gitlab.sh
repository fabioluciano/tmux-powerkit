#!/usr/bin/env bash
# =============================================================================
# Plugin: gitlab
# Description: Monitor GitLab repositories for issues and merge requests
# Dependencies: curl, jq (optional), glab CLI (optional)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "gitlab"
    metadata_set "name" "GitLab"
    metadata_set "description" "Monitor GitLab repos for issues and MRs"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    require_cmd "jq" 1  # Optional but recommended
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # GitLab configuration
    declare_option "url" "string" "https://gitlab.com" "GitLab instance URL (self-hosted support)"
    declare_option "repos" "string" "" "Comma-separated list of owner/repo or group/project"
    declare_option "token" "string" "" "GitLab personal access token"
    
    # Display options
    declare_option "show_issues" "bool" "true" "Show open issues count"
    declare_option "show_mrs" "bool" "true" "Show open MRs count"
    declare_option "separator" "string" " / " "Separator between metrics"
    
    # Icons
    declare_option "icon" "icon" $'\U000F0296' "Plugin icon"
    declare_option "icon_issue" "icon" "" "Issues icon"
    declare_option "icon_mr" "icon" "" "MR icon"
    
    # Thresholds
    declare_option "warning_threshold" "number" "10" "Warning when total exceeds threshold"
    
    # Cache
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

_is_authenticated() {
    # Check glab CLI authentication
    if has_cmd "glab"; then
        glab auth status &>/dev/null && return 0
    fi
    # Check for token option or env vars
    local token=$(get_option "token")
    [[ -n "$token" ]] && return 0
    [[ -n "${GITLAB_TOKEN:-}" || -n "${GITLAB_PRIVATE_TOKEN:-}" ]] && return 0
    return 1
}

_get_token() {
    local token=$(get_option "token")
    [[ -n "$token" ]] && { printf '%s' "$token"; return 0; }
    [[ -n "${GITLAB_TOKEN:-}" ]] && { printf '%s' "$GITLAB_TOKEN"; return 0; }
    [[ -n "${GITLAB_PRIVATE_TOKEN:-}" ]] && { printf '%s' "$GITLAB_PRIVATE_TOKEN"; return 0; }
    return 1
}

plugin_get_state() {
    if ! _is_authenticated; then
        printf 'failed'
        return
    fi
    local total=$(plugin_data_get "total")
    local api_error=$(plugin_data_get "api_error")
    
    if [[ "$api_error" == "1" ]]; then
        printf 'degraded'
    elif [[ "${total:-0}" -gt 0 ]]; then
        printf 'active'
    else
        printf 'inactive'
    fi
}

plugin_get_health() {
    if ! _is_authenticated; then
        printf 'error'
        return
    fi
    
    local api_error=$(plugin_data_get "api_error")
    [[ "$api_error" == "1" ]] && { printf 'error'; return; }
    
    local total=$(plugin_data_get "total")
    local warning_threshold=$(get_option "warning_threshold")
    
    [[ "${total:-0}" -ge "$warning_threshold" ]] && printf 'warning' || printf 'ok'
}

plugin_get_context() {
    if ! _is_authenticated; then
        printf 'unauthenticated'
        return
    fi
    
    local api_error=$(plugin_data_get "api_error")
    [[ "$api_error" == "1" ]] && { printf 'api_error'; return; }
    
    local total=$(plugin_data_get "total")
    local issues=$(plugin_data_get "issues")
    local mrs=$(plugin_data_get "mrs")
    
    total="${total:-0}"
    issues="${issues:-0}"
    mrs="${mrs:-0}"
    
    if (( total == 0 )); then
        printf 'clear'
    elif (( issues > 0 && mrs > 0 )); then
        printf 'issues_and_mrs'
    elif (( issues > 0 )); then
        printf 'issues_only'
    elif (( mrs > 0 )); then
        printf 'mrs_only'
    else
        printf 'activity'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# URL Encoding (for project paths like group/subgroup/project)
# =============================================================================

_url_encode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o
    
    for (( pos=0; pos<strlen; pos++ )); do
        c="${string:$pos:1}"
        case "$c" in
            [-_.~a-zA-Z0-9]) o="$c" ;;
            *) printf -v o '%%%02x' "'$c" ;;
        esac
        encoded+="$o"
    done
    printf '%s' "$encoded"
}

# =============================================================================
# API Functions
# =============================================================================

_make_gitlab_api_call() {
    local url="$1"
    local token=$(_get_token)
    
    local curl_opts=(-s -f --connect-timeout 5 --max-time 10)
    [[ -n "$token" ]] && curl_opts+=(-H "PRIVATE-TOKEN: $token")
    
    curl "${curl_opts[@]}" "$url" 2>/dev/null
}

_make_gitlab_head_call() {
    local url="$1"
    local token=$(_get_token)
    
    local curl_opts=(-s -I --connect-timeout 5 --max-time 10)
    [[ -n "$token" ]] && curl_opts+=(-H "PRIVATE-TOKEN: $token")
    
    curl "${curl_opts[@]}" "$url" 2>/dev/null
}

_count_issues() {
    local project_encoded="$1"
    local gitlab_url=$(get_option "url")
    
    # Use issues_statistics endpoint - more efficient than listing
    local url="${gitlab_url}/api/v4/projects/${project_encoded}/issues_statistics?scope=all"
    local response=$(_make_gitlab_api_call "$url")
    
    [[ -z "$response" ]] && { echo "0"; return 1; }
    
    local count
    if has_cmd jq; then
        count=$(echo "$response" | jq -r '.statistics.counts.opened // 0' 2>/dev/null)
    else
        count=$(echo "$response" | grep -o '"opened":[0-9]*' | grep -o '[0-9]*' | head -1)
    fi
    
    [[ -z "$count" || "$count" == "null" ]] && count=0
    echo "$count"
}

_count_mrs() {
    local project_encoded="$1"
    local gitlab_url=$(get_option "url")
    
    # Use X-Total header for efficient counting
    local url="${gitlab_url}/api/v4/projects/${project_encoded}/merge_requests?state=opened&per_page=1"
    local response=$(_make_gitlab_head_call "$url")
    
    local count=$(echo "$response" | grep -i '^x-total:' | awk '{print $2}' | tr -d '\r\n')
    
    [[ -z "$count" ]] && count=0
    echo "$count"
}

# Use glab CLI if available and no repos configured
_fetch_via_glab_cli() {
    local show_issues=$(get_option "show_issues")
    local show_mrs=$(get_option "show_mrs")
    
    local issues=0 mrs=0
    
    if [[ "$show_mrs" == "true" ]]; then
        mrs=$(glab mr list --assignee @me --state opened 2>/dev/null | wc -l | tr -d ' ')
    fi
    
    if [[ "$show_issues" == "true" ]]; then
        issues=$(glab issue list --assignee @me --state opened 2>/dev/null | wc -l | tr -d ' ')
    fi
    
    echo "$issues $mrs"
}

# =============================================================================
# Main Logic
# =============================================================================

_format_status() {
    local issues="$1"
    local mrs="$2"
    
    local show_issues=$(get_option "show_issues")
    local show_mrs=$(get_option "show_mrs")
    local separator=$(get_option "separator")
    local icon_issue=$(get_option "icon_issue")
    local icon_mr=$(get_option "icon_mr")
    
    local parts=()
    
    if [[ "$show_issues" == "true" && "$issues" -gt 0 ]]; then
        if [[ -n "$icon_issue" ]]; then
            parts+=("${icon_issue} ${issues}")
        else
            parts+=("${issues}i")
        fi
    fi
    
    if [[ "$show_mrs" == "true" && "$mrs" -gt 0 ]]; then
        if [[ -n "$icon_mr" ]]; then
            parts+=("${icon_mr} ${mrs}")
        else
            parts+=("${mrs}mr")
        fi
    fi
    
    local IFS="$separator"
    echo "${parts[*]}"
}

_get_gitlab_info() {
    local repos_csv=$(get_option "repos")
    local show_issues=$(get_option "show_issues")
    local show_mrs=$(get_option "show_mrs")
    
    # If no repos configured, try glab CLI
    if [[ -z "$repos_csv" ]] && has_cmd glab; then
        local result=$(_fetch_via_glab_cli)
        echo "$result 0"  # issues mrs api_error
        return 0
    fi
    
    [[ -z "$repos_csv" ]] && { echo "0 0 1"; return 1; }
    
    IFS=',' read -ra repos <<<"$repos_csv"
    
    local total_issues=0 total_mrs=0
    local api_error=0
    
    for repo_spec in "${repos[@]}"; do
        # Trim whitespace
        repo_spec="${repo_spec#"${repo_spec%%[![:space:]]*}"}"
        repo_spec="${repo_spec%"${repo_spec##*[![:space:]]}"}"
        [[ -z "$repo_spec" || "$repo_spec" != *"/"* ]] && continue
        
        local project_encoded=$(_url_encode "$repo_spec")
        local issues=0 mrs=0
        
        if [[ "$show_issues" == "true" ]]; then
            issues=$(_count_issues "$project_encoded")
            [[ -z "$issues" ]] && api_error=1
            issues="${issues:-0}"
        fi
        
        if [[ "$show_mrs" == "true" ]]; then
            mrs=$(_count_mrs "$project_encoded")
            [[ -z "$mrs" ]] && api_error=1
            mrs="${mrs:-0}"
        fi
        
        total_issues=$((total_issues + issues))
        total_mrs=$((total_mrs + mrs))
    done
    
    echo "$total_issues $total_mrs $api_error"
}

plugin_collect() {
    if ! _is_authenticated; then
        plugin_data_set "issues" "0"
        plugin_data_set "mrs" "0"
        plugin_data_set "total" "0"
        plugin_data_set "api_error" "0"
        return 0
    fi
    
    local result=$(_get_gitlab_info)
    local issues mrs api_error
    read -r issues mrs api_error <<<"$result"
    
    issues="${issues:-0}"
    mrs="${mrs:-0}"
    api_error="${api_error:-0}"
    
    local total=$((issues + mrs))
    
    plugin_data_set "issues" "$issues"
    plugin_data_set "mrs" "$mrs"
    plugin_data_set "total" "$total"
    plugin_data_set "api_error" "$api_error"
}

plugin_render() {
    local issues=$(plugin_data_get "issues")
    local mrs=$(plugin_data_get "mrs")
    local total=$(plugin_data_get "total")
    
    issues="${issues:-0}"
    mrs="${mrs:-0}"
    total="${total:-0}"
    
    [[ "$total" -eq 0 ]] && return 0
    
    _format_status "$issues" "$mrs"
}

