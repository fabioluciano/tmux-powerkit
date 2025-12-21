#!/usr/bin/env bash
# =============================================================================
# Plugin: github - Monitor GitHub repositories for issues, PRs and comments
# Description: Display open issues and PRs from repositories with optional user filtering
# Dependencies: curl, jq (optional, for JSON parsing)
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
    # Repository configuration
    declare_option "repos" "string" "" "Comma-separated list of owner/repo"
    declare_option "token" "string" "" "GitHub personal access token"
    declare_option "filter_user" "string" "" "Filter issues/PRs by username"

    # Display options
    declare_option "show_issues" "bool" "on" "Show open issues count"
    declare_option "show_prs" "bool" "on" "Show open PRs count"
    declare_option "show_comments" "bool" "off" "Show PR comments count"
    declare_option "format" "string" "simple" "Format style: simple or detailed"
    declare_option "separator" "string" " | " "Separator between metrics"

    # Icons
    declare_option "icon" "icon" $'\U000F02A4' "Plugin icon"
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

# Initialize plugin (auto-calls plugin_declare_options if defined)
plugin_init "github"


# =============================================================================
# Constants
# =============================================================================

GITHUB_API="https://api.github.com"

# =============================================================================
# Main Logic
# =============================================================================

# Make authenticated API call
_make_github_api_call() {
    local url="$1"
    local token
    token=$(get_option "token")
    make_api_call "$url" "github" "$token" 5
}


# Extract error message from API response
_get_api_error_message() {
    local response="$1"
    echo "$response" | jq -r '.message // empty' 2>/dev/null
}

# Show API error using toast (only once per cache cycle)
_show_github_api_error() {
    local error_msg="$1"
    local error_cache="${CACHE_DIR}/github_error.cache"

    # Log error
    log_error "github" "API error: $error_msg"

    # Check if we already showed this error recently (within TTL)
    if [[ -f "$error_cache" ]]; then
        local cached_error=$(<"$error_cache")
        [[ "$cached_error" == "$error_msg" ]] && return 0
    fi

    # Determine if error is important enough to show without debug mode
    local is_critical=false
    case "$error_msg" in
        *"rate limit"*|*"Rate limit"*) is_critical=true ;;
        *"Bad credentials"*|*"Unauthorized"*) is_critical=true ;;
        *"Not Found"*) is_critical=true ;;  # Repo doesn't exist or no access
    esac

    # Show toast if critical error or debug mode
    if [[ "$is_critical" == "true" ]] || is_debug_mode; then
        local short_msg="${error_msg:0:50}"
        [[ ${#error_msg} -gt 50 ]] && short_msg="${short_msg}..."
        toast "GitHub: $short_msg" "warning"

        # Cache the error message to avoid spam
        printf '%s' "$error_msg" > "$error_cache"
    fi
}

# Validate API response (check for error messages)
_is_valid_api_response() {
    local response="$1"

    # Empty response is invalid
    [[ -z "$response" ]] && return 1

    # Check if response is an error object (has "message" key indicating error)
    local error_msg
    error_msg=$(_get_api_error_message "$response")
    if [[ -n "$error_msg" ]]; then
        _show_github_api_error "$error_msg"
        return 1
    fi

    # Check if response is an array (expected for lists)
    if echo "$response" | jq -e 'type == "array"' &>/dev/null; then
        # Clear error cache on successful response
        rm -f "${CACHE_DIR}/github_error.cache" 2>/dev/null
        return 0
    fi

    return 1
}

# Check API rate limit
_check_rate_limit() {
    local response
    response=$(_make_github_api_call "$GITHUB_API/rate_limit")
    echo "$response" | jq -r '.rate.remaining // 0' 2>/dev/null || echo "0"
}

# Count open issues for a repository (excluding PRs) using Search API
_count_issues() {
    local owner="$1"
    local repo="$2"
    local filter_user="$3"

    local query="repo:${owner}/${repo}+type:issue+state:open"
    [[ -n "$filter_user" ]] && query="${query}+author:${filter_user}"

    local url="$GITHUB_API/search/issues?q=${query}&per_page=1"
    local response
    response=$(_make_github_api_call "$url")

    # Check for errors
    if [[ -z "$response" ]]; then
        echo "0"
        return 1
    fi

    local error_msg
    error_msg=$(echo "$response" | jq -r '.message // empty' 2>/dev/null)
    if [[ -n "$error_msg" ]]; then
        _show_github_api_error "$error_msg"
        echo "0"
        return 1
    fi

    echo "$response" | jq -r '.total_count // 0' 2>/dev/null || echo "0"
}

# Count open PRs for a repository using Search API
_count_prs() {
    local owner="$1"
    local repo="$2"
    local filter_user="$3"

    local query="repo:${owner}/${repo}+type:pr+state:open"
    [[ -n "$filter_user" ]] && query="${query}+author:${filter_user}"

    local url="$GITHUB_API/search/issues?q=${query}&per_page=1"
    local response
    response=$(_make_github_api_call "$url")

    # Check for errors
    if [[ -z "$response" ]]; then
        echo "0"
        return 1
    fi

    local error_msg
    error_msg=$(echo "$response" | jq -r '.message // empty' 2>/dev/null)
    if [[ -n "$error_msg" ]]; then
        _show_github_api_error "$error_msg"
        echo "0"
        return 1
    fi

    echo "$response" | jq -r '.total_count // 0' 2>/dev/null || echo "0"
}

# Count PR comments for a repository
_count_pr_comments() {
    local user="$1"
    local repo="$2"
    local filter_user="$3"
    local url="$GITHUB_API/repos/$user/$repo/pulls?state=open&per_page=100"

    local response
    response=$(_make_github_api_call "$url")

    # Validate response before processing
    if ! _is_valid_api_response "$response"; then
        echo "0"
        return 1
    fi

    # Get all open PR numbers
    local pr_numbers
    pr_numbers=$(echo "$response" | jq -r '.[].number' 2>/dev/null)

    [[ -z "$pr_numbers" ]] && echo "0" && return

    local total_comments=0

    # For each PR, count comments
    while IFS= read -r pr_number; do
        [[ -z "$pr_number" ]] && continue

        local comments_url="$GITHUB_API/repos/$user/$repo/issues/$pr_number/comments?per_page=100"
        local comments_response
        comments_response=$(_make_github_api_call "$comments_url")

        # Validate comments response
        if ! _is_valid_api_response "$comments_response"; then
            continue
        fi

        if [[ -z "$filter_user" ]]; then
            local count
            count=$(echo "$comments_response" | jq 'length' 2>/dev/null || echo "0")
            total_comments=$((total_comments + count))
        else
            local count
            count=$(echo "$comments_response" | jq --arg user "$filter_user" \
                '[.[] | select(.user.login == $user)] | length' 2>/dev/null || echo "0")
            total_comments=$((total_comments + count))
        fi
    done <<<"$pr_numbers"

    echo "$total_comments"
}

# Wrapper to count all items (issues, prs, comments)
_count_issues_and_prs() {
    local owner="$1"
    local repo="$2"
    local filter_user="$3"
    local show_comments="$4"

    local issues
    issues=$(_count_issues "$owner" "$repo" "$filter_user")

    local prs
    prs=$(_count_prs "$owner" "$repo" "$filter_user")

    local comments=0
    if [[ "$show_comments" == "on" || "$show_comments" == "true" ]]; then
        comments=$(_count_pr_comments "$owner" "$repo" "$filter_user")
    fi

    echo "$issues $prs $comments"
}

# Format repository status (uses shared helper from plugin_helpers.sh)
_format_repo_status() {
    local issues="$1"
    local prs="$2"
    local comments="$3"
    local show_comments="$4"

    local format separator show_issues show_prs icon_issue icon_pr
    format=$(get_option "format")
    separator=$(get_option "separator")
    show_issues=$(get_option "show_issues")
    show_prs=$(get_option "show_prs")
    icon_issue=$(get_option "icon_issue")
    icon_pr=$(get_option "icon_pr")

    format_repo_metrics \
        "$separator" \
        "$format" \
        "$show_issues" \
        "$issues" \
        "$icon_issue" \
        "i" \
        "$show_prs" \
        "$prs" \
        "$icon_pr" \
        "p" \
        "$show_comments" \
        "$comments" \
        "c"
}

# Get GitHub info for all configured repos
_get_github_info() {
    local repos_csv="$1"
    local filter_user="$2"
    local show_comments="$3"

    # Check dependencies
    if ! check_dependencies curl jq; then
        return 1
    fi

    # Split repos by comma
    IFS=',' read -ra repos <<<"$repos_csv"

    local total_issues=0
    local total_prs=0
    local total_comments=0
    local active=false

    for repo_spec in "${repos[@]}"; do
        # Trim whitespace
        repo_spec="$(echo "$repo_spec" | xargs)"
        [[ -z "$repo_spec" ]] && continue

        # Parse owner/repo format
        local owner repo
        if [[ "$repo_spec" == *"/"* ]]; then
            # Format: owner/repo
            owner="${repo_spec%%/*}"
            repo="${repo_spec#*/}"
        else
            # Invalid format, skip
            continue
        fi

        local issues prs comments
        read -r issues prs comments <<<"$(_count_issues_and_prs "$owner" "$repo" "$filter_user" "$show_comments")"

        # Add to totals
        total_issues=$((total_issues + issues))
        total_prs=$((total_prs + prs))
        total_comments=$((total_comments + comments))
    done

    # Check activity
    if [[ "$total_issues" -gt 0 ]] || [[ "$total_prs" -gt 0 ]]; then
        active=true
    fi

    # Return "no activity" if nothing found (plugin logic handles hiding)
    if [[ "$active" == "false" ]]; then
        echo "no activity"
        return
    fi

    # Output aggregated status
    _format_repo_status "$total_issues" "$total_prs" "$total_comments" "$show_comments"
}

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() {
    printf 'conditional'
}

plugin_get_display_info() {
    local content="$1"

    # Don't show plugin if no activity
    if [[ -z "$content" || "$content" == "no activity" ]]; then
        printf '0:::'
        return 0
    fi

    # Parse total issue count from content to determine color
    local total_count=0

    # Extract numbers from format like "repo:5/3" or "repo: 5i/3p"
    if [[ "$content" =~ ([0-9]+) ]]; then
        total_count="${BASH_REMATCH[1]}"
    fi

    local warning_threshold
    warning_threshold=$(get_option "warning_threshold")

    # Use warning color if count exceeds threshold
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

_compute_github() {
    local repos filter_user show_comments
    repos=$(get_option "repos")
    filter_user=$(get_option "filter_user")
    show_comments=$(get_option "show_comments")

    _get_github_info "$repos" "$filter_user" "$show_comments"
}

load_plugin() {
    # Runtime check - dependency contract handles notification
    has_cmd curl || return 0

    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_github
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
