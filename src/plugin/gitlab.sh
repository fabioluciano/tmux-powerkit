#!/usr/bin/env bash
# =============================================================================
# Plugin: gitlab - Monitor GitLab repositories for issues and MRs
# Description: Display open issues and MRs from repositories (aggregated)
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
# Options Declaration (Plugin Contract)
# =============================================================================

plugin_declare_options() {
    # GitLab configuration
    declare_option "url" "string" "https://gitlab.com" "GitLab instance URL"
    declare_option "repos" "string" "" "Comma-separated list of owner/repo"
    declare_option "token" "string" "" "GitLab personal access token"

    # Display options
    declare_option "show_issues" "bool" "on" "Show open issues count"
    declare_option "show_mrs" "bool" "on" "Show open MRs count"
    declare_option "separator" "string" " / " "Separator between metrics"

    # Icons
    declare_option "icon" "icon" $'\U000F0296' "Plugin icon"
    declare_option "icon_issue" "icon" "" "Icon for issues"
    declare_option "icon_mr" "icon" "" "Icon for merge requests"

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

# Initialize plugin (auto-calls plugin_declare_options if defined)
plugin_init "gitlab"


# =============================================================================
# Main Logic
# =============================================================================

# URL encode string (for Project ID: owner/repo -> owner%2Frepo)
_url_encode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

_make_gitlab_api_call() {
    local url="$1"
    local token
    token=$(get_option "token")
    make_api_call "$url" "private-token" "$token" 5
}

_count_issues() {
    local project_encoded="$1"
    local gitlab_url token
    gitlab_url=$(get_option "url")
    token=$(get_option "token")

    # Use issues_statistics endpoint - more reliable than X-Total header
    local url="${gitlab_url}/api/v4/projects/${project_encoded}/issues_statistics?scope=all"

    local response
    if [[ -n "$token" ]]; then
        response=$(curl -s -H "PRIVATE-TOKEN: $token" "$url" 2>/dev/null)
    else
        response=$(curl -s "$url" 2>/dev/null)
    fi

    # Extract opened count from statistics
    local count
    if has_cmd jq; then
        count=$(echo "$response" | jq -r '.statistics.counts.opened // 0' 2>/dev/null)
    else
        # Fallback: extract with grep/sed
        count=$(echo "$response" | grep -o '"opened":[0-9]*' | grep -o '[0-9]*' | head -1)
    fi

    [[ -z "$count" || "$count" == "null" ]] && count=0
    echo "$count"
}

_count_mrs() {
    local project_encoded="$1"
    local gitlab_url token
    gitlab_url=$(get_option "url")
    token=$(get_option "token")

    local url="${gitlab_url}/api/v4/projects/${project_encoded}/merge_requests?state=opened&per_page=1"

    if [[ -n "$token" ]]; then
        curl -s -I -H "PRIVATE-TOKEN: $token" "$url" 2>/dev/null | grep -i '^x-total:' | awk '{print $2}' | tr -d '\r' || echo "0"
    else
        curl -s -I "$url" 2>/dev/null | grep -i '^x-total:' | awk '{print $2}' | tr -d '\r' || echo "0"
    fi
}

# Format repository status (uses shared helper from plugin_helpers.sh)
_format_status() {
    local issues="$1"
    local mrs="$2"

    local separator show_issues show_mrs icon_issue icon_mr
    separator=$(get_option "separator")
    show_issues=$(get_option "show_issues")
    show_mrs=$(get_option "show_mrs")
    icon_issue=$(get_option "icon_issue")
    icon_mr=$(get_option "icon_mr")

    format_repo_metrics \
        "$separator" \
        "simple" \
        "$show_issues" \
        "$issues" \
        "$icon_issue" \
        "i" \
        "$show_mrs" \
        "$mrs" \
        "$icon_mr" \
        "mr"
}

_get_gitlab_info() {
    local repos_csv="$1"
    local show_issues show_mrs
    show_issues=$(get_option "show_issues")
    show_mrs=$(get_option "show_mrs")

    # Split repos
    IFS=',' read -ra repos <<< "$repos_csv"

    local total_issues=0
    local total_mrs=0
    local active=false

    log_debug "gitlab" "Fetching info for repos: $repos_csv"

    for repo_spec in "${repos[@]}"; do
        repo_spec="$(echo "$repo_spec" | xargs)"
        [[ -z "$repo_spec" ]] && continue

        # Ensure owner/repo format for encoding
        if [[ "$repo_spec" != *"/"* ]]; then
            log_warn "gitlab" "Invalid repo format (missing /): $repo_spec"
            continue
        fi

        local project_encoded
        project_encoded=$(_url_encode "$repo_spec")

        local issues=0
        local mrs=0

        if [[ "$show_issues" == "on" || "$show_issues" == "true" ]]; then
            issues=$(_count_issues "$project_encoded")
            # If curl fails or returns empty, treat as 0
            [[ -z "$issues" ]] && issues=0
        fi

        if [[ "$show_mrs" == "on" || "$show_mrs" == "true" ]]; then
            mrs=$(_count_mrs "$project_encoded")
            [[ -z "$mrs" ]] && mrs=0
        fi

        total_issues=$((total_issues + issues))
        total_mrs=$((total_mrs + mrs))
    done

    if [[ "$total_issues" -gt 0 ]] || [[ "$total_mrs" -gt 0 ]]; then
        active=true
    fi

    log_debug "gitlab" "Total issues: $total_issues, MRs: $total_mrs"

    if [[ "$active" == "false" ]]; then
        echo "no activity"
        return
    fi

    _format_status "$total_issues" "$total_mrs"
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
    # Simple regex to sum numbers found in output "ICON 10 / ICON 5"
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

_compute_gitlab() {
    local repos
    repos=$(get_option "repos")
    _get_gitlab_info "$repos"
}

load_plugin() {
    # Runtime check - dependency contract handles notification
    has_cmd curl || return 0

    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_gitlab
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
