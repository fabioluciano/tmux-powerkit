#!/usr/bin/env bash
# =============================================================================
# Plugin: github - Monitor GitHub repositories for issues, PRs and comments
# Description: Display open issues and PRs from repositories with optional user filtering
# Dependencies: curl, jq (for JSON parsing)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "github"

GITHUB_API="https://api.github.com"

# =============================================================================
# Configuration
# =============================================================================

# Repository format: "owner/repo,owner2/repo2"
GITHUB_REPOS=$(get_tmux_option "@powerkit_plugin_github_repos" "$POWERKIT_PLUGIN_GITHUB_REPOS")
GITHUB_FILTER_USER=$(get_tmux_option "@powerkit_plugin_github_filter_user" "$POWERKIT_PLUGIN_GITHUB_FILTER_USER")
GITHUB_SHOW_ISSUES=$(get_tmux_option "@powerkit_plugin_github_show_issues" "$POWERKIT_PLUGIN_GITHUB_SHOW_ISSUES")
GITHUB_SHOW_PRS=$(get_tmux_option "@powerkit_plugin_github_show_prs" "$POWERKIT_PLUGIN_GITHUB_SHOW_PRS")
GITHUB_SHOW_COMMENTS=$(get_tmux_option "@powerkit_plugin_github_show_comments" "$POWERKIT_PLUGIN_GITHUB_SHOW_COMMENTS")
GITHUB_ICON_ISSUE=$(get_tmux_option "@powerkit_plugin_github_icon_issue" "$POWERKIT_PLUGIN_GITHUB_ICON_ISSUE")
GITHUB_ICON_PR=$(get_tmux_option "@powerkit_plugin_github_icon_pr" "$POWERKIT_PLUGIN_GITHUB_ICON_PR")
GITHUB_TOKEN=$(get_tmux_option "@powerkit_plugin_github_token" "$POWERKIT_PLUGIN_GITHUB_TOKEN")
GITHUB_FORMAT=$(get_tmux_option "@powerkit_plugin_github_format" "$POWERKIT_PLUGIN_GITHUB_FORMAT")
GITHUB_WARNING_THRESHOLD=$(get_tmux_option "@powerkit_plugin_github_warning_threshold" "$POWERKIT_PLUGIN_GITHUB_WARNING_THRESHOLD")
GITHUB_SEPARATOR=$(get_tmux_option "@powerkit_plugin_github_separator" "$POWERKIT_PLUGIN_GITHUB_SEPARATOR")

# =============================================================================
# GitHub API Helper Functions
# =============================================================================

# Make authenticated API call
make_github_api_call() {
    local url="$1"
    make_api_call "$url" "bearer" "$GITHUB_TOKEN" 5
}


# Extract error message from API response
get_api_error_message() {
    local response="$1"
    echo "$response" | jq -r '.message // empty' 2>/dev/null
}

# Show API error using toast (only once per cache cycle)
show_github_api_error() {
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
        toast "⚠️ GitHub: $short_msg" "warning"

        # Cache the error message to avoid spam
        printf '%s' "$error_msg" > "$error_cache"
    fi
}

# Validate API response (check for error messages)
is_valid_api_response() {
    local response="$1"
    
    # Empty response is invalid
    [[ -z "$response" ]] && return 1
    
    # Check if response is an error object (has "message" key indicating error)
    local error_msg
    error_msg=$(get_api_error_message "$response")
    if [[ -n "$error_msg" ]]; then
        show_github_api_error "$error_msg"
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
check_rate_limit() {
    local response
    response=$(make_github_api_call "$GITHUB_API/rate_limit")
    echo "$response" | jq -r '.rate.remaining // 0' 2>/dev/null || echo "0"
}

# =============================================================================
# Data Retrieval Functions
# =============================================================================

# Count open issues for a repository (excluding PRs)
count_issues() {
    local user="$1"
    local repo="$2"
    local filter_user="$3"
    local url="$GITHUB_API/repos/$user/$repo/issues?state=open&per_page=100"

    local response
    response=$(make_github_api_call "$url")
    
    # Validate response before processing
    if ! is_valid_api_response "$response"; then
        echo "0"
        return 1
    fi

    if [[ -z "$filter_user" ]]; then
        # Count all issues (excluding PRs)
        echo "$response" | jq '[.[] | select(.pull_request == null)] | length' 2>/dev/null || echo "0"
    else
        # Count issues by specific user (creator or assignee)
        echo "$response" | jq --arg user "$filter_user" \
            '[.[] | select(.pull_request == null) | select(.user.login == $user or (.assignees[]?.login == $user))] | length' \
            2>/dev/null || echo "0"
    fi
}

# Count open PRs for a repository
count_prs() {
    local user="$1"
    local repo="$2"
    local filter_user="$3"
    local url="$GITHUB_API/repos/$user/$repo/pulls?state=open&per_page=100"

    local response
    response=$(make_github_api_call "$url")
    
    # Validate response before processing
    if ! is_valid_api_response "$response"; then
        echo "0"
        return 1
    fi

    if [[ -z "$filter_user" ]]; then
        # Count all PRs
        echo "$response" | jq 'length' 2>/dev/null || echo "0"
    else
        # Count PRs by specific user
        echo "$response" | jq --arg user "$filter_user" \
            '[.[] | select(.user.login == $user)] | length' \
            2>/dev/null || echo "0"
    fi
}

# Count PR comments for a repository
count_pr_comments() {
    local user="$1"
    local repo="$2"
    local filter_user="$3"
    local url="$GITHUB_API/repos/$user/$repo/pulls?state=open&per_page=100"

    local response
    response=$(make_github_api_call "$url")
    
    # Validate response before processing
    if ! is_valid_api_response "$response"; then
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
        comments_response=$(make_github_api_call "$comments_url")
        
        # Validate comments response
        if ! is_valid_api_response "$comments_response"; then
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
count_issues_and_prs() {
    local owner="$1"
    local repo="$2"
    local filter_user="$3"
    local show_comments="$4"

    local issues
    issues=$(count_issues "$owner" "$repo" "$filter_user")

    local prs
    prs=$(count_prs "$owner" "$repo" "$filter_user")

    local comments=0
    if [[ "$show_comments" == "on" ]]; then
        comments=$(count_pr_comments "$owner" "$repo" "$filter_user")
    fi

    echo "$issues $prs $comments"
}
# =============================================================================
# Display Functions
# =============================================================================

# Format repository status
format_repo_status() {
    local issues="$1"
    local prs="$2"
    local comments="$3"
    local show_comments="$4"

    local parts=()

    # Issues
    if [[ "$GITHUB_SHOW_ISSUES" == "on" ]]; then
        if [[ "$GITHUB_FORMAT" == "detailed" ]]; then
            parts+=("${GITHUB_ICON_ISSUE} $(format_number "$issues")i")
        else
            parts+=("${GITHUB_ICON_ISSUE} $(format_number "$issues")")
        fi
    fi

    # PRs
    if [[ "$GITHUB_SHOW_PRS" == "on" ]]; then
        if [[ "$GITHUB_FORMAT" == "detailed" ]]; then
            parts+=("${GITHUB_ICON_PR} $(format_number "$prs")p")
        else
            parts+=("${GITHUB_ICON_PR} $(format_number "$prs")")
        fi
    fi

    # Comments
    if [[ "$show_comments" == "on" ]]; then
        if [[ "$GITHUB_FORMAT" == "detailed" ]]; then
            parts+=("$(format_number "$comments")c")
        else
            parts+=("$(format_number "$comments")")
        fi
    fi

    # Join parts with configurable separator
    local output=""
    local sep=""
    for part in "${parts[@]}"; do
        output+="${sep}${part}"
        sep="$GITHUB_SEPARATOR"
    done

    echo "$output"
}

# Get GitHub info for all configured repos
get_github_info() {
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
        read -r issues prs comments <<<"$(count_issues_and_prs "$owner" "$repo" "$filter_user" "$show_comments")"

        # Add to totals
        total_issues=$((total_issues + issues))
        total_prs=$((total_prs + prs))
        total_comments=$((total_comments + comments))
    done

    # Check activity
    if [[ "$total_issues" -gt 0 ]] || [[ "$total_prs" -gt 0 ]]; then
        active=true
    fi
    # Also check comments if enabled? Usually issues/PRs driving visibility is enough.

    # Return "no activity" if nothing found (plugin logic handles hiding)
    if [[ "$active" == "false" ]]; then
        echo "no activity"
        return
    fi

    # Output aggregated status
    format_repo_status "$total_issues" "$total_prs" "$total_comments" "$show_comments"
}

# =============================================================================
# Plugin Interface
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

    # Use warning color if count exceeds threshold
    if [[ $total_count -ge $GITHUB_WARNING_THRESHOLD ]]; then
        local warning_color
        local warning_icon
        warning_color=$(get_tmux_option "@powerkit_plugin_github_warning_accent_color" "$POWERKIT_PLUGIN_GITHUB_WARNING_ACCENT_COLOR")
        warning_icon=$(get_tmux_option "@powerkit_plugin_github_warning_accent_color_icon" "$POWERKIT_PLUGIN_GITHUB_WARNING_ACCENT_COLOR_ICON")
        printf '1:%s:%s:' "$warning_color" "$warning_icon"
    else
        local accent_color
        local accent_icon
        accent_color=$(get_tmux_option "@powerkit_plugin_github_accent_color" "$POWERKIT_PLUGIN_GITHUB_ACCENT_COLOR")
        accent_icon=$(get_tmux_option "@powerkit_plugin_github_accent_color_icon" "$POWERKIT_PLUGIN_GITHUB_ACCENT_COLOR_ICON")
        printf '1:%s:%s:' "$accent_color" "$accent_icon"
    fi
}

_compute_github() {
    get_github_info "$GITHUB_REPOS" "$GITHUB_FILTER_USER" "$GITHUB_SHOW_COMMENTS"
}

load_plugin() {
    # Use defer_plugin_load for network operations with lazy loading
    defer_plugin_load "$CACHE_KEY" cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_github
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
