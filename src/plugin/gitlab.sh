#!/usr/bin/env bash
# =============================================================================
# Plugin: gitlab - Monitor GitLab repositories for issues and MRs
# Description: Display open issues and MRs from repositories (aggregated)
# Dependencies: curl, jq
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "gitlab"

# =============================================================================
# Configuration
# =============================================================================

GITLAB_URL=$(get_tmux_option "@powerkit_plugin_gitlab_url" "$POWERKIT_PLUGIN_GITLAB_URL")
GITLAB_REPOS=$(get_tmux_option "@powerkit_plugin_gitlab_repos" "$POWERKIT_PLUGIN_GITLAB_REPOS")
GITLAB_SHOW_ISSUES=$(get_tmux_option "@powerkit_plugin_gitlab_show_issues" "$POWERKIT_PLUGIN_GITLAB_SHOW_ISSUES")
GITLAB_SHOW_MRS=$(get_tmux_option "@powerkit_plugin_gitlab_show_mrs" "$POWERKIT_PLUGIN_GITLAB_SHOW_MRS")
GITLAB_ICON_ISSUE=$(get_tmux_option "@powerkit_plugin_gitlab_icon_issue" "$POWERKIT_PLUGIN_GITLAB_ICON_ISSUE")
GITLAB_ICON_MR=$(get_tmux_option "@powerkit_plugin_gitlab_icon_mr" "$POWERKIT_PLUGIN_GITLAB_ICON_MR")
GITLAB_TOKEN=$(get_tmux_option "@powerkit_plugin_gitlab_token" "$POWERKIT_PLUGIN_GITLAB_TOKEN")
GITLAB_WARNING_THRESHOLD=$(get_tmux_option "@powerkit_plugin_gitlab_warning_threshold" "$POWERKIT_PLUGIN_GITLAB_WARNING_THRESHOLD")
GITLAB_SEPARATOR=$(get_tmux_option "@powerkit_plugin_gitlab_separator" "$POWERKIT_PLUGIN_GITLAB_SEPARATOR")

# =============================================================================
# Helper Functions
# =============================================================================

# URL encode string (for Project ID: owner/repo -> owner%2Frepo)
url_encode() {
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

make_gitlab_api_call() {
    local url="$1"
    make_api_call "$url" "private-token" "$GITLAB_TOKEN" 5
}

# =============================================================================
# Data Retrieval
# =============================================================================

count_issues() {
    local project_encoded="$1"
    # Use issues_statistics endpoint - more reliable than X-Total header
    local url="$GITLAB_URL/api/v4/projects/$project_encoded/issues_statistics?scope=all"

    local response
    if [[ -n "$GITLAB_TOKEN" ]]; then
        response=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$url" 2>/dev/null)
    else
        response=$(curl -s "$url" 2>/dev/null)
    fi

    # Extract opened count from statistics
    local count
    if command -v jq &>/dev/null; then
        count=$(echo "$response" | jq -r '.statistics.counts.opened // 0' 2>/dev/null)
    else
        # Fallback: extract with grep/sed
        count=$(echo "$response" | grep -o '"opened":[0-9]*' | grep -o '[0-9]*' | head -1)
    fi

    [[ -z "$count" || "$count" == "null" ]] && count=0
    echo "$count"
}

count_mrs() {
    local project_encoded="$1"
    local url="$GITLAB_URL/api/v4/projects/$project_encoded/merge_requests?state=opened&per_page=1"
    
    if [[ -n "$GITLAB_TOKEN" ]]; then
        curl -s -I -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$url" 2>/dev/null | grep -i '^x-total:' | awk '{print $2}' | tr -d '\r' || echo "0"
    else
        curl -s -I "$url" 2>/dev/null | grep -i '^x-total:' | awk '{print $2}' | tr -d '\r' || echo "0"
    fi
}

# =============================================================================
# Display Logic
# =============================================================================

format_status() {
    local issues="$1"
    local mrs="$2"

    local parts=()

    if [[ "$GITLAB_SHOW_ISSUES" == "on" ]]; then
        parts+=("${GITLAB_ICON_ISSUE} $(format_number "$issues")")
    fi

    if [[ "$GITLAB_SHOW_MRS" == "on" ]]; then
        parts+=("${GITLAB_ICON_MR} $(format_number "$mrs")")
    fi

    local output=""
    local sep=""
    for part in "${parts[@]}"; do
        output+="${sep}${part}"
        sep="$GITLAB_SEPARATOR"
    done
    echo "$output"
}

get_gitlab_info() {
    local repos_csv="$1"

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
        project_encoded=$(url_encode "$repo_spec")

        local issues=0
        local mrs=0

        if [[ "$GITLAB_SHOW_ISSUES" == "on" ]]; then
            issues=$(count_issues "$project_encoded")
            # If curl fails or returns empty, treat as 0
            [[ -z "$issues" ]] && issues=0
        fi

        if [[ "$GITLAB_SHOW_MRS" == "on" ]]; then
            mrs=$(count_mrs "$project_encoded")
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

    format_status "$total_issues" "$total_mrs"
}

# =============================================================================
# Plugin Interface
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
    # Not strictly parsing per icon, just sum of all numbers
    local temp_content="$content"
    while [[ "$temp_content" =~ ([0-9]+) ]]; do
        total_count=$((total_count + BASH_REMATCH[1]))
        temp_content="${temp_content#*"${BASH_REMATCH[1]}"}"
    done

    if [[ $total_count -ge $GITLAB_WARNING_THRESHOLD ]]; then
        local warning_color
        local warning_icon
        warning_color=$(get_tmux_option "@powerkit_plugin_gitlab_warning_accent_color" "$POWERKIT_PLUGIN_GITLAB_WARNING_ACCENT_COLOR")
        warning_icon=$(get_tmux_option "@powerkit_plugin_gitlab_warning_accent_color_icon" "$POWERKIT_PLUGIN_GITLAB_WARNING_ACCENT_COLOR_ICON")
        printf '1:%s:%s:' "$warning_color" "$warning_icon"
    else
        local accent_color
        local accent_icon
        accent_color=$(get_tmux_option "@powerkit_plugin_gitlab_accent_color" "$POWERKIT_PLUGIN_GITLAB_ACCENT_COLOR")
        accent_icon=$(get_tmux_option "@powerkit_plugin_gitlab_accent_color_icon" "$POWERKIT_PLUGIN_GITLAB_ACCENT_COLOR_ICON")
        printf '1:%s:%s:' "$accent_color" "$accent_icon"
    fi
}

_compute_gitlab() {
    get_gitlab_info "$GITLAB_REPOS"
}

load_plugin() {
    # Check dependencies
    require_cmd curl || return 0

    # Use defer_plugin_load for network operations with lazy loading
    defer_plugin_load "$CACHE_KEY" cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_gitlab
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
