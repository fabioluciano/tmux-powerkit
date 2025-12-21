#!/usr/bin/env bash
# =============================================================================
# Plugin: jira - Display Jira issues assigned to you
# Description: Show count of issues or current sprint task
# Dependencies: curl, jq (required), fzf (optional for selector)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    require_cmd "jq" || return 1
    require_cmd "fzf" 1  # Optional: for interactive issue selector
    return 0
}

# =============================================================================
# Options Declaration (Plugin Contract)
# =============================================================================

plugin_declare_options() {
    # Jira configuration
    declare_option "url" "string" "" "Jira instance URL"
    declare_option "email" "string" "" "Jira account email"
    declare_option "api_token" "string" "" "Jira API token"
    declare_option "project" "string" "" "Filter by project key"
    declare_option "jql" "string" "" "Custom JQL query"

    # Display options
    declare_option "format" "string" "breakdown" "Display format: count, current, or breakdown"
    declare_option "separator" "string" " | " "Separator between metrics"

    # Icons
    declare_option "icon" "icon" $'\U000F0303' "Plugin icon"
    declare_option "icon_progress" "icon" $'\U000F0E4E' "Icon for in-progress issues"
    declare_option "icon_todo" "icon" $'\U000F0E4F' "Icon for todo issues"
    declare_option "icon_flagged" "icon" $'\U000F0229' "Icon for flagged issues"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Colors - Warning state
    declare_option "warning_accent_color" "color" "warning" "Warning background color"
    declare_option "warning_accent_color_icon" "color" "warning-subtle" "Warning icon background"

    # Thresholds
    declare_option "warning_threshold" "number" "5" "Warning when count exceeds threshold"

    # Keybindings - Issue selector
    declare_option "selector_key" "key" "C-e" "Keybinding for issue selector"
    declare_option "selector_width" "string" "80%" "Popup width"
    declare_option "selector_height" "string" "60%" "Popup height"

    # Cache
    declare_option "cache_ttl" "number" "120" "Cache duration in seconds"
}

# Initialize plugin (auto-calls plugin_declare_options if defined)
plugin_init "jira"


# =============================================================================
# Main Logic
# =============================================================================

# Make authenticated Jira API call
_jira_api_call() {
    local endpoint="$1"
    local url email token
    url=$(get_option "url")
    email=$(get_option "email")
    token=$(get_option "api_token")

    local api_url="${url}/rest/api/3/${endpoint}"

    # Base64 encode credentials
    local auth
    auth=$(printf '%s:%s' "$email" "$token" | base64 | tr -d '\n')

    safe_curl "$api_url" 10 \
        -H "Authorization: Basic ${auth}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json"
}

# Build JQL query
_build_jql() {
    local jql project
    jql=$(get_option "jql")
    project=$(get_option "project")

    if [[ -n "$jql" ]]; then
        # Use custom JQL
        printf '%s' "$jql"
        return
    fi

    # Default: assigned to me, not done
    local query="assignee = currentUser() AND resolution = Unresolved"

    # Add project filter if specified
    [[ -n "$project" ]] && query+=" AND project = ${project}"

    # Order by priority and updated
    query+=" ORDER BY priority DESC, updated DESC"

    printf '%s' "$query"
}

# Get issue count
_get_issue_count() {
    local jql
    jql=$(_build_jql)

    # URL encode JQL query
    local encoded_jql
    encoded_jql=$(printf '%s' "$jql" | sed 's/ /%20/g; s/=/%3D/g; s/"/%22/g; s/(/%28/g; s/)/%29/g')

    local response total=0
    local next_token=""

    # Paginate through results to count all issues
    # New /search/jql API doesn't return total, uses cursor pagination
    while true; do
        local url="search/jql?jql=${encoded_jql}&maxResults=100"
        [[ -n "$next_token" ]] && url+="&nextPageToken=${next_token}"

        response=$(_jira_api_call "$url")
        [[ -z "$response" ]] && break

        # Check for errors
        if echo "$response" | jq -e '.errorMessages' &>/dev/null; then
            log_error "jira" "API error: $(echo "$response" | jq -r '.errorMessages[0]' 2>/dev/null)"
            return 1
        fi

        # Count issues in this batch
        local batch_count
        batch_count=$(echo "$response" | jq -r '.issues | length' 2>/dev/null)
        total=$((total + batch_count))

        # Check if this is the last page
        local is_last
        is_last=$(echo "$response" | jq -r '.isLast // true' 2>/dev/null)
        [[ "$is_last" == "true" ]] && break

        # Get next page token
        next_token=$(echo "$response" | jq -r '.nextPageToken // empty' 2>/dev/null)
        [[ -z "$next_token" ]] && break
    done

    printf '%s' "${total:-0}"
}

# Get current in-progress issue
_get_current_issue() {
    local project
    project=$(get_option "project")

    local jql="assignee = currentUser() AND status = 'In Progress'"
    [[ -n "$project" ]] && jql+=" AND project = ${project}"
    jql+=" ORDER BY updated DESC"

    # URL encode JQL query
    local encoded_jql
    encoded_jql=$(printf '%s' "$jql" | sed 's/ /%20/g; s/=/%3D/g; s/"/%22/g; s/'\''/%27/g; s/(/%28/g; s/)/%29/g')

    local response
    # Use new /search/jql endpoint (old /search was deprecated)
    response=$(_jira_api_call "search/jql?jql=${encoded_jql}&maxResults=1&fields=key,summary")
    [[ -z "$response" ]] && return 1

    local key summary
    key=$(echo "$response" | jq -r '.issues[0].key // empty' 2>/dev/null)
    [[ -z "$key" || "$key" == "null" ]] && return 1

    summary=$(echo "$response" | jq -r '.issues[0].fields.summary // empty' 2>/dev/null)

    # Truncate summary to 20 chars
    [[ ${#summary} -gt 20 ]] && summary="${summary:0:17}..."

    printf '%s' "$key"
}

# Check if issue is flagged by status name keywords
_is_flagged_by_status() {
    local status_name="$1"
    local lower_status
    lower_status=$(echo "$status_name" | tr '[:upper:]' '[:lower:]')

    # Check for flagged-related keywords in status name
    if [[ "$lower_status" == *blocked* ]] || \
       [[ "$lower_status" == *impediment* ]] || \
       [[ "$lower_status" == *waiting* ]] || \
       [[ "$lower_status" == *"on hold"* ]] || \
       [[ "$lower_status" == *paused* ]]; then
        return 0
    fi
    return 1
}

# Get issue breakdown by status category
_get_issue_breakdown() {
    local jql separator
    jql=$(_build_jql)
    separator=$(get_option "separator")

    # URL encode JQL query
    local encoded_jql
    encoded_jql=$(printf '%s' "$jql" | sed 's/ /%20/g; s/=/%3D/g; s/"/%22/g; s/(/%28/g; s/)/%29/g')

    local in_progress=0
    local todo=0
    local flagged=0
    local next_token=""

    # Paginate through results to count by status
    # Impediment detection: customfield_10177 (Início Impedimento) not null AND customfield_10178 (Fim Impedimento) null
    while true; do
        # Request status and impediment fields
        local url="search/jql?jql=${encoded_jql}&maxResults=100&fields=status,customfield_10177,customfield_10178"
        [[ -n "$next_token" ]] && url+="&nextPageToken=${next_token}"

        local response
        response=$(_jira_api_call "$url")
        [[ -z "$response" ]] && break

        # Check for errors
        if echo "$response" | jq -e '.errorMessages' &>/dev/null; then
            log_error "jira" "API error: $(echo "$response" | jq -r '.errorMessages[0]' 2>/dev/null)"
            return 1
        fi

        # Count issues by status category and flag
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local status_name status_category is_flagged
            status_name=$(echo "$line" | cut -d'|' -f1)
            status_category=$(echo "$line" | cut -d'|' -f2)
            is_flagged=$(echo "$line" | cut -d'|' -f3)

            # Check if flagged (by impediment fields OR by status name keywords)
            if [[ "$is_flagged" == "true" ]] || _is_flagged_by_status "$status_name"; then
                ((flagged++))
            elif [[ "$status_category" == "In Progress" ]]; then
                ((in_progress++))
            elif [[ "$status_category" == "To Do" ]]; then
                ((todo++))
            fi
        # Impediment detection: customfield_10177 (start) not null AND customfield_10178 (end) null = active impediment
        done < <(echo "$response" | jq -r '.issues[]? | "\(.fields.status.name // "Unknown")|\(.fields.status.statusCategory.name // "Unknown")|\(if (.fields.customfield_10177 != null and .fields.customfield_10178 == null) then "true" else "false" end)"' 2>/dev/null)

        # Check if this is the last page
        local is_last
        is_last=$(echo "$response" | jq -r '.isLast // true' 2>/dev/null)
        [[ "$is_last" == "true" ]] && break

        # Get next page token
        next_token=$(echo "$response" | jq -r '.nextPageToken // empty' 2>/dev/null)
        [[ -z "$next_token" ]] && break
    done

    # Format output with icons
    # Blue circle for in progress, yellow for todo/backlog, red for flagged
    local output=""
    local icon_progress icon_todo icon_flagged

    icon_progress=$(get_option "icon_progress")
    icon_todo=$(get_option "icon_todo")
    icon_flagged=$(get_option "icon_flagged")

    [[ "$in_progress" -gt 0 ]] && output+="${icon_progress}${in_progress}"
    [[ "$todo" -gt 0 ]] && output+="${output:+${separator}}${icon_todo}${todo}"
    [[ "$flagged" -gt 0 ]] && output+="${output:+${separator}}${icon_flagged}${flagged}"

    # If all zeros, show total of 0
    [[ -z "$output" ]] && output="0"

    printf '%s' "$output"
}

# =============================================================================
# Keybinding Setup
# =============================================================================

setup_keybindings() {
    local helper_path="${ROOT_DIR}/../helpers/jira_issue_selector.sh"
    local selector_key selector_width selector_height

    selector_key=$(get_option "selector_key")
    selector_width=$(get_option "selector_width")
    selector_height=$(get_option "selector_height")

    # Issue selector popup
    [[ -n "$selector_key" ]] && tmux bind-key "$selector_key" display-popup \
        -w "$selector_width" -h "$selector_height" -E \
        "bash '$helper_path'"
}

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -z "$content" || "$content" == "0" ]] && { build_display_info "0" "" "" ""; return; }

    # Extract number from content for threshold check
    local count
    if [[ "$content" =~ ^[0-9]+$ ]]; then
        count="$content"
    else
        count=$(extract_numeric "$content")
    fi

    local warning_threshold
    warning_threshold=$(get_option "warning_threshold")

    # Apply warning color if count exceeds threshold
    if [[ -n "$count" && "$count" -ge "$warning_threshold" ]]; then
        local warn_accent warn_icon
        warn_accent=$(get_option "warning_accent_color")
        warn_icon=$(get_option "warning_accent_color_icon")
        build_display_info "1" "$warn_accent" "$warn_icon" ""
    else
        build_display_info "1" "" "" ""
    fi
}

_compute_jira() {
    # Check dependencies
    check_dependencies curl jq || return 1

    # Validate configuration
    local url email token format
    url=$(get_option "url")
    email=$(get_option "email")
    token=$(get_option "api_token")
    format=$(get_option "format")

    [[ -z "$url" || -z "$email" || -z "$token" ]] && return 1

    case "$format" in
        current)
            _get_current_issue
            ;;
        breakdown)
            _get_issue_breakdown
            ;;
        count|*)
            _get_issue_count
            ;;
    esac
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_jira
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
