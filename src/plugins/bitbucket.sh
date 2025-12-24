#!/usr/bin/env bash
# =============================================================================
# Plugin: bitbucket
# Description: Display Bitbucket pull requests
# Dependencies: curl
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "bitbucket"
    metadata_set "name" "Bitbucket"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display Bitbucket pull requests"
    metadata_set "priority" "115"
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
    # Bitbucket configuration
    declare_option "type" "string" "cloud" "Bitbucket type: cloud or datacenter"
    declare_option "url" "string" "" "Bitbucket API URL (required for datacenter, auto for cloud)"
    declare_option "repos" "string" "" "Comma-separated list of workspace/repo (cloud) or project/repo (datacenter)"
    declare_option "email" "string" "" "Atlassian account email (required for cloud API tokens)"
    declare_option "token" "string" "" "API token (cloud) or Personal Access Token (datacenter)"

    # Display options
    declare_option "show_issues" "bool" "on" "Show open issues count"
    declare_option "show_prs" "bool" "on" "Show open PRs count"
    declare_option "separator" "string" " | " "Separator between metrics"

    # Icons
    declare_option "icon" "icon" $'\U000F0171' "Plugin icon"
    declare_option "icon_issue" "icon" $'\U0000F41B' "Icon for issues"
    declare_option "icon_pr" "icon" $'\U0000F407' "Icon for pull requests"

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

_is_configured() {
    local bb_type repos email token url
    bb_type=$(get_option "type")
    repos=$(get_option "repos")
    email=$(get_option "email")
    token=$(get_option "token")
    url=$(get_option "url")
    
    # repos is always required
    [[ -z "$repos" ]] && return 1
    
    if [[ "$bb_type" == "datacenter" ]]; then
        # Datacenter requires url and token
        [[ -z "$url" || -z "$token" ]] && return 1
    else
        # Cloud requires email and token
        [[ -z "$email" || -z "$token" ]] && return 1
    fi
    
    return 0
}

plugin_get_state() {
    if ! _is_configured; then
        printf 'failed'
        return
    fi
    
    local issues prs
    issues=$(plugin_data_get "issues")
    prs=$(plugin_data_get "prs")
    
    [[ "${issues:-0}" -gt 0 || "${prs:-0}" -gt 0 ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    if ! _is_configured; then
        printf 'error'
        return
    fi
    
    local issues prs total warning_threshold
    issues=$(plugin_data_get "issues")
    prs=$(plugin_data_get "prs")
    total=$((${issues:-0} + ${prs:-0}))
    warning_threshold=$(get_option "warning_threshold")
    
    [[ "$total" -ge "$warning_threshold" ]] && printf 'warning' || printf 'ok'
}

plugin_get_context() {
    if ! _is_configured; then
        printf 'unconfigured'
        return
    fi
    
    local issues prs
    issues=$(plugin_data_get "issues")
    prs=$(plugin_data_get "prs")
    issues="${issues:-0}"
    prs="${prs:-0}"
    
    if (( issues == 0 && prs == 0 )); then
        printf 'clear'
    elif (( prs > issues )); then
        printf 'pr_heavy'
    elif (( issues > prs )); then
        printf 'issue_heavy'
    else
        printf 'balanced'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Constants
# =============================================================================

BITBUCKET_CLOUD_API="https://api.bitbucket.org/2.0"

# =============================================================================
# API Functions
# =============================================================================

_get_api_url() {
    local bb_type bb_url
    bb_type=$(get_option "type")
    bb_url=$(get_option "url")

    if [[ "$bb_type" == "datacenter" ]]; then
        [[ -z "$bb_url" ]] && return 1
        printf '%s' "${bb_url%/}"
    else
        if [[ -n "$bb_url" ]]; then
            printf '%s' "${bb_url%/}"
        else
            printf '%s' "$BITBUCKET_CLOUD_API"
        fi
    fi
}

_bb_api_call() {
    local url="$1"
    local bb_type email token
    bb_type=$(get_option "type")
    email=$(get_option "email")
    token=$(get_option "token")

    if [[ "$bb_type" == "datacenter" ]]; then
        make_api_call "$url" "bearer" "$token" 5
    else
        make_api_call "$url" "basic" "${email}:${token}" 5
    fi
}

_count_issues() {
    local workspace="$1" repo_slug="$2"
    local bb_type bitbucket_url url response
    bb_type=$(get_option "type")
    bitbucket_url=$(_get_api_url) || return 1

    if [[ "$bb_type" == "datacenter" ]]; then
        # Data Center doesn't have native issues (uses Jira)
        printf '0'
        return 0
    fi

    # Cloud API
    url="${bitbucket_url}/repositories/$workspace/$repo_slug/issues?q=state=%22new%22+OR+state=%22open%22&pagelen=0"
    response=$(_bb_api_call "$url")
    json_get_size "$response"
}

_count_prs() {
    local workspace="$1" repo_slug="$2"
    local bb_type bitbucket_url url response
    bb_type=$(get_option "type")
    bitbucket_url=$(_get_api_url) || return 1

    if [[ "$bb_type" == "datacenter" ]]; then
        url="${bitbucket_url}/rest/api/1.0/projects/$workspace/repos/$repo_slug/pull-requests?state=OPEN&limit=0"
    else
        url="${bitbucket_url}/repositories/$workspace/$repo_slug/pullrequests?state=OPEN&pagelen=0"
    fi

    response=$(_bb_api_call "$url")
    json_get_size "$response"
}

plugin_collect() {
    _is_configured || return 0
    
    local repos_csv show_issues show_prs
    repos_csv=$(get_option "repos")
    show_issues=$(get_option "show_issues")
    show_prs=$(get_option "show_prs")

    IFS=',' read -ra repos <<< "$repos_csv"

    local total_issues=0 total_prs=0

    for repo_spec in "${repos[@]}"; do
        repo_spec=$(trim "$repo_spec")
        [[ -z "$repo_spec" || "$repo_spec" != *"/"* ]] && continue

        local workspace="${repo_spec%%/*}"
        local repo_slug="${repo_spec#*/}"

        if [[ "$show_issues" == "on" || "$show_issues" == "true" ]]; then
            local issues=$(_count_issues "$workspace" "$repo_slug")
            total_issues=$((total_issues + ${issues:-0}))
        fi

        if [[ "$show_prs" == "on" || "$show_prs" == "true" ]]; then
            local prs=$(_count_prs "$workspace" "$repo_slug")
            total_prs=$((total_prs + ${prs:-0}))
        fi
    done

    plugin_data_set "issues" "$total_issues"
    plugin_data_set "prs" "$total_prs"
}

plugin_render() {
    if ! _is_configured; then
        printf 'Not configured'
        return
    fi
    
    local issues prs show_issues show_prs separator icon_issue icon_pr
    issues=$(plugin_data_get "issues")
    prs=$(plugin_data_get "prs")
    show_issues=$(get_option "show_issues")
    show_prs=$(get_option "show_prs")
    separator=$(get_option "separator")
    icon_issue=$(get_option "icon_issue")
    icon_pr=$(get_option "icon_pr")

    [[ "${issues:-0}" -eq 0 && "${prs:-0}" -eq 0 ]] && return 0

    local output=""
    
    if [[ "$show_issues" == "on" || "$show_issues" == "true" ]] && [[ "${issues:-0}" -gt 0 ]]; then
        output="${icon_issue} ${issues}"
    fi
    
    if [[ "$show_prs" == "on" || "$show_prs" == "true" ]] && [[ "${prs:-0}" -gt 0 ]]; then
        [[ -n "$output" ]] && output+="$separator"
        output+="${icon_pr} ${prs}"
    fi

    printf '%s' "$output"
}

