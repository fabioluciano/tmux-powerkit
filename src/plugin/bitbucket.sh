#!/usr/bin/env bash
# =============================================================================
# Plugin: bitbucket
# Description: Monitor Bitbucket repositories for issues and PRs
# Type: conditional (hidden when no activity)
# Dependencies: curl, jq (optional)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    require_cmd "jq" 1  # Optional
    return 0
}

# =============================================================================
# Options Declaration
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

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"
    declare_option "warning_accent_color" "color" "warning" "Warning background color"
    declare_option "warning_accent_color_icon" "color" "warning-subtle" "Warning icon background"

    # Thresholds
    declare_option "warning_threshold" "number" "10" "Warning when total exceeds threshold"

    # Cache
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}

plugin_init "bitbucket"

# =============================================================================
# Constants
# =============================================================================

BITBUCKET_CLOUD_API="https://api.bitbucket.org/2.0"

# =============================================================================
# Helper Functions
# =============================================================================

# Get the API base URL based on type
_get_api_url() {
    local bb_type bb_url
    bb_type=$(get_option "type")
    bb_url=$(get_option "url")

    if [[ "$bb_type" == "datacenter" ]]; then
        # Data Center requires explicit URL
        if [[ -z "$bb_url" ]]; then
            log_error "bitbucket" "URL is required for Bitbucket Data Center"
            return 1
        fi
        # Remove trailing slash if present
        echo "${bb_url%/}"
    else
        # Cloud: use provided URL or default
        if [[ -n "$bb_url" ]]; then
            echo "${bb_url%/}"
        else
            echo "$BITBUCKET_CLOUD_API"
        fi
    fi
}

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() {
    printf 'conditional'
}

plugin_get_display_info() {
    local content="$1"

    if [[ -z "$content" || "$content" == "no activity" ]]; then
        printf '0:::'
        return 0
    fi

    # Extract numbers for threshold check
    local total_count=0
    local temp_content="$content"
    while [[ "$temp_content" =~ ([0-9]+) ]]; do
        total_count=$((total_count + BASH_REMATCH[1]))
        temp_content="${temp_content#*"${BASH_REMATCH[1]}"}"
    done

    local warning_threshold
    warning_threshold=$(get_option "warning_threshold")

    if [[ $total_count -ge $warning_threshold ]]; then
        local warning_color warning_icon
        warning_color=$(get_option "warning_accent_color")
        warning_icon=$(get_option "warning_accent_color_icon")
        printf '1:%s:%s:' "$warning_color" "$warning_icon"
    else
        local accent_color accent_icon
        accent_color=$(get_option "accent_color")
        accent_icon=$(get_option "accent_color_icon")
        printf '1:%s:%s:' "$accent_color" "$accent_icon"
    fi
}

# =============================================================================
# Main Logic
# =============================================================================

_make_bitbucket_api_call() {
    local url="$1"
    local bb_type email token
    bb_type=$(get_option "type")
    email=$(get_option "email")
    token=$(get_option "token")

    log_debug "bitbucket" "API call to: $url"

    local response

    if [[ "$bb_type" == "datacenter" ]]; then
        # Data Center uses Bearer token
        response=$(make_api_call "$url" "bearer" "$token" 5)
    else
        # Cloud uses Basic Auth with email:api_token
        if [[ -n "$email" && -n "$token" ]]; then
            response=$(make_api_call "$url" "basic" "${email}:${token}" 5)
        else
            log_error "bitbucket" "Email and token required for Bitbucket Cloud"
            return 1
        fi
    fi

    # Check for API errors
    local error_msg
    error_msg=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    if [[ -n "$error_msg" ]]; then
        log_error "bitbucket" "API error: $error_msg"
        echo ""
        return 1
    fi

    echo "$response"
}

_count_issues() {
    local workspace="$1"
    local repo_slug="$2"
    local bb_type
    bb_type=$(get_option "type")

    local bitbucket_url
    bitbucket_url=$(_get_api_url) || return 1

    local url response

    if [[ "$bb_type" == "datacenter" ]]; then
        # Data Center API: /rest/api/1.0/projects/{projectKey}/repos/{repositorySlug}
        # Note: Data Center doesn't have a native issues tracker (uses Jira integration)
        # We return 0 for issues on Data Center
        echo "0"
        return 0
    else
        # Cloud API: /repositories/{workspace}/{repo_slug}/issues
        # state is "new" or "open" for issues
        url="${bitbucket_url}/repositories/$workspace/$repo_slug/issues?q=state=%22new%22+OR+state=%22open%22&pagelen=0"
    fi

    response=$(_make_bitbucket_api_call "$url")

    # Bitbucket Cloud returns "size" property in root object
    echo "$response" | jq -r '.size // 0' 2>/dev/null || echo "0"
}

_count_prs() {
    local workspace="$1"
    local repo_slug="$2"
    local bb_type
    bb_type=$(get_option "type")

    local bitbucket_url
    bitbucket_url=$(_get_api_url) || return 1

    local url response

    if [[ "$bb_type" == "datacenter" ]]; then
        # Data Center API: /rest/api/1.0/projects/{projectKey}/repos/{repositorySlug}/pull-requests
        # Note: workspace = projectKey, repo_slug = repositorySlug in Data Center
        url="${bitbucket_url}/rest/api/1.0/projects/$workspace/repos/$repo_slug/pull-requests?state=OPEN&limit=0"
        response=$(_make_bitbucket_api_call "$url")
        # Data Center returns "size" in the response
        echo "$response" | jq -r '.size // 0' 2>/dev/null || echo "0"
    else
        # Cloud API: /repositories/{workspace}/{repo_slug}/pullrequests
        url="${bitbucket_url}/repositories/$workspace/$repo_slug/pullrequests?state=OPEN&pagelen=0"
        response=$(_make_bitbucket_api_call "$url")
        # Cloud returns "size" property in root object
        echo "$response" | jq -r '.size // 0' 2>/dev/null || echo "0"
    fi
}

_format_status() {
    local issues="$1"
    local prs="$2"

    local separator show_issues show_prs icon_issue icon_pr
    separator=$(get_option "separator")
    show_issues=$(get_option "show_issues")
    show_prs=$(get_option "show_prs")
    icon_issue=$(get_option "icon_issue")
    icon_pr=$(get_option "icon_pr")

    format_repo_metrics \
        "$separator" \
        "simple" \
        "$show_issues" \
        "$issues" \
        "$icon_issue" \
        "i" \
        "$show_prs" \
        "$prs" \
        "$icon_pr" \
        "p"
}

_get_bitbucket_info() {
    local repos_csv="$1"
    local bb_type show_issues show_prs
    bb_type=$(get_option "type")
    show_issues=$(get_option "show_issues")
    show_prs=$(get_option "show_prs")

    # Validate URL for datacenter
    if [[ "$bb_type" == "datacenter" ]]; then
        local bb_url
        bb_url=$(get_option "url")
        if [[ -z "$bb_url" ]]; then
            log_error "bitbucket" "URL is required when type is 'datacenter'"
            echo "no activity"
            return 1
        fi
    fi

    # Split repos
    IFS=',' read -ra repos <<< "$repos_csv"

    local total_issues=0
    local total_prs=0
    local active=false

    log_debug "bitbucket" "Fetching info for repos: $repos_csv"

    for repo_spec in "${repos[@]}"; do
        repo_spec="$(echo "$repo_spec" | xargs)"
        [[ -z "$repo_spec" ]] && continue

        # Ensure workspace/repo_slug format
        if [[ "$repo_spec" != *"/"* ]]; then
            log_warn "bitbucket" "Invalid repo format (missing /): $repo_spec"
            continue
        fi

        local workspace="${repo_spec%%/*}"
        local repo_slug="${repo_spec#*/}"

        local issues=0
        local prs=0

        if [[ "$show_issues" == "on" || "$show_issues" == "true" ]]; then
            issues=$(_count_issues "$workspace" "$repo_slug")
            [[ -z "$issues" ]] && issues=0
        fi

        if [[ "$show_prs" == "on" || "$show_prs" == "true" ]]; then
            prs=$(_count_prs "$workspace" "$repo_slug")
            [[ -z "$prs" ]] && prs=0
        fi

        total_issues=$((total_issues + issues))
        total_prs=$((total_prs + prs))
    done

    if [[ "$total_issues" -gt 0 ]] || [[ "$total_prs" -gt 0 ]]; then
        active=true
    fi

    log_debug "bitbucket" "Total issues: $total_issues, PRs: $total_prs"

    if [[ "$active" == "false" ]]; then
        echo "no activity"
        return
    fi

    _format_status "$total_issues" "$total_prs"
}

_compute_bitbucket() {
    local repos
    repos=$(get_option "repos")
    _get_bitbucket_info "$repos"
}

load_plugin() {
    # Runtime check - dependency contract handles notification
    has_cmd curl || return 0

    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_bitbucket
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
