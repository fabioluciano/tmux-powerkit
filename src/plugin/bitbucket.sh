#!/usr/bin/env bash
# =============================================================================
# Plugin: bitbucket - Monitor Bitbucket repositories for issues and PRs
# Description: Display open issues and PRs from repositories (aggregated)
# Dependencies: curl, jq
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "bitbucket"

# =============================================================================
# Configuration
# =============================================================================

BITBUCKET_URL=$(get_tmux_option "@powerkit_plugin_bitbucket_url" "$POWERKIT_PLUGIN_BITBUCKET_URL")
BITBUCKET_REPOS=$(get_tmux_option "@powerkit_plugin_bitbucket_repos" "$POWERKIT_PLUGIN_BITBUCKET_REPOS")
BITBUCKET_SHOW_ISSUES=$(get_tmux_option "@powerkit_plugin_bitbucket_show_issues" "$POWERKIT_PLUGIN_BITBUCKET_SHOW_ISSUES")
BITBUCKET_SHOW_PRS=$(get_tmux_option "@powerkit_plugin_bitbucket_show_prs" "$POWERKIT_PLUGIN_BITBUCKET_SHOW_PRS")
BITBUCKET_ICON_ISSUE=$(get_tmux_option "@powerkit_plugin_bitbucket_icon_issue" "$POWERKIT_PLUGIN_BITBUCKET_ICON_ISSUE")
BITBUCKET_ICON_PR=$(get_tmux_option "@powerkit_plugin_bitbucket_icon_pr" "$POWERKIT_PLUGIN_BITBUCKET_ICON_PR")
BITBUCKET_TOKEN=$(get_tmux_option "@powerkit_plugin_bitbucket_token" "$POWERKIT_PLUGIN_BITBUCKET_TOKEN")
BITBUCKET_WARNING_THRESHOLD=$(get_tmux_option "@powerkit_plugin_bitbucket_warning_threshold" "$POWERKIT_PLUGIN_BITBUCKET_WARNING_THRESHOLD")
BITBUCKET_SEPARATOR=$(get_tmux_option "@powerkit_plugin_bitbucket_separator" "$POWERKIT_PLUGIN_BITBUCKET_SEPARATOR")

# =============================================================================
# Helper Functions
# =============================================================================

make_bitbucket_api_call() {
    local url="$1"
    # Bitbucket uses Basic Auth for API with App Passwords
    make_api_call "$url" "basic" "$BITBUCKET_TOKEN" 5
}

# =============================================================================
# Data Retrieval
# =============================================================================

count_issues() {
    local workspace="$1"
    local repo_slug="$2"
    # Bitbucket API: /repositories/{workspace}/{repo_slug}/issues
    # state is "new" or "open" for issues
    local url="$BITBUCKET_URL/repositories/$workspace/$repo_slug/issues?q=state=%22new%22+OR+state=%22open%22&pagelen=0"
    
    local response
    response=$(make_bitbucket_api_call "$url")
    
    # Bitbucket returns "size" property in root object
    echo "$response" | jq -r '.size // 0' 2>/dev/null || echo "0"
}

count_prs() {
    local workspace="$1"
    local repo_slug="$2"
    # Bitbucket API: /repositories/{workspace}/{repo_slug}/pullrequests
    # state=OPEN is default usually, but let's be explicit
    local url="$BITBUCKET_URL/repositories/$workspace/$repo_slug/pullrequests?state=OPEN&pagelen=0"
    
    local response
    response=$(make_bitbucket_api_call "$url")
    
    echo "$response" | jq -r '.size // 0' 2>/dev/null || echo "0"
}

# =============================================================================
# Display Logic
# =============================================================================

format_status() {
    local issues="$1"
    local prs="$2"

    local parts=()

    if [[ "$BITBUCKET_SHOW_ISSUES" == "on" ]]; then
        parts+=("${BITBUCKET_ICON_ISSUE} $(format_number "$issues")")
    fi

    if [[ "$BITBUCKET_SHOW_PRS" == "on" ]]; then
        parts+=("${BITBUCKET_ICON_PR} $(format_number "$prs")")
    fi

    local output=""
    local sep=""
    for part in "${parts[@]}"; do
        output+="${sep}${part}"
        sep="$BITBUCKET_SEPARATOR"
    done
    echo "$output"
}

get_bitbucket_info() {
    local repos_csv="$1"

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

        if [[ "$BITBUCKET_SHOW_ISSUES" == "on" ]]; then
            issues=$(count_issues "$workspace" "$repo_slug")
            [[ -z "$issues" ]] && issues=0
        fi

        if [[ "$BITBUCKET_SHOW_PRS" == "on" ]]; then
            prs=$(count_prs "$workspace" "$repo_slug")
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

    format_status "$total_issues" "$total_prs"
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
    local temp_content="$content"
    while [[ "$temp_content" =~ ([0-9]+) ]]; do
        total_count=$((total_count + BASH_REMATCH[1]))
        temp_content="${temp_content#*"${BASH_REMATCH[1]}"}"
    done

    if [[ $total_count -ge $BITBUCKET_WARNING_THRESHOLD ]]; then
        local warning_color
        local warning_icon
        warning_color=$(get_tmux_option "@powerkit_plugin_bitbucket_warning_accent_color" "$POWERKIT_PLUGIN_BITBUCKET_WARNING_ACCENT_COLOR")
        warning_icon=$(get_tmux_option "@powerkit_plugin_bitbucket_warning_accent_color_icon" "$POWERKIT_PLUGIN_BITBUCKET_WARNING_ACCENT_COLOR_ICON")
        printf '1:%s:%s:' "$warning_color" "$warning_icon"
    else
        local accent_color
        local accent_icon
        accent_color=$(get_tmux_option "@powerkit_plugin_bitbucket_accent_color" "$POWERKIT_PLUGIN_BITBUCKET_ACCENT_COLOR")
        accent_icon=$(get_tmux_option "@powerkit_plugin_bitbucket_accent_color_icon" "$POWERKIT_PLUGIN_BITBUCKET_ACCENT_COLOR_ICON")
        printf '1:%s:%s:' "$accent_color" "$accent_icon"
    fi
}

_compute_bitbucket() {
    get_bitbucket_info "$BITBUCKET_REPOS"
}

load_plugin() {
    # Check dependencies
    check_dependencies curl jq || return 0

    # Use defer_plugin_load for network operations with lazy loading
    defer_plugin_load "$CACHE_KEY" cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_bitbucket
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
