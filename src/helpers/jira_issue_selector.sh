#!/usr/bin/env bash
# =============================================================================
# Helper: jira_issue_selector
# Description: Interactive Jira issue browser with fzf/gum
# Type: popup
# =============================================================================

# Source helper base (handles all initialization)
# Using minimal bootstrap for faster startup - jira helper only needs:
# cache, platform, ui_backend (all available in minimal)
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init
# Note: ui_backend.sh is loaded by helper_contract.sh

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "jira_issue_selector"
    helper_metadata_set "name" "Jira Issue Selector"
    helper_metadata_set "description" "Browse and open Jira issues"
    helper_metadata_set "type" "popup"
}

helper_get_actions() {
    echo "browse - Browse issues (default)"
}

# =============================================================================
# Configuration
# =============================================================================

# Get config from plugin options (matching jira.sh plugin_declare_options)
_domain=$(get_tmux_option "@powerkit_plugin_jira_domain" "")
_email=$(get_tmux_option "@powerkit_plugin_jira_email" "")
_token=$(get_tmux_option "@powerkit_plugin_jira_token" "")
_project=$(get_tmux_option "@powerkit_plugin_jira_project" "")
_jql=$(get_tmux_option "@powerkit_plugin_jira_jql" "")
_selector_cache_ttl=$(get_tmux_option "@powerkit_plugin_jira_selector_cache_ttl" "7200")

# Build full URL from domain
_url="https://${_domain}"

# Cache key for selector issues
SELECTOR_CACHE_KEY="jira_selector_issues"

# Colors for status
COLOR_IN_PROGRESS="${POWERKIT_ANSI_BLUE}"
COLOR_TODO="${POWERKIT_ANSI_YELLOW}"
COLOR_FLAGGED="${POWERKIT_ANSI_RED}"
COLOR_DONE="${POWERKIT_ANSI_GREEN}"
COLOR_RESET="${POWERKIT_ANSI_RESET}"
COLOR_DIM="${POWERKIT_ANSI_DIM}"
COLOR_BOLD="${POWERKIT_ANSI_BOLD}"

# =============================================================================
# API Functions
# =============================================================================

# Make authenticated Jira API call
jira_api_call() {
    local endpoint="$1"
    local url="${_url}/rest/api/3/${endpoint}"

    # Base64 encode credentials
    local auth
    auth=$(printf '%s:%s' "$_email" "$_token" | base64 | tr -d '\n')

    safe_curl "$url" 10 \
        -H "Authorization: Basic ${auth}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json"
}

# Build JQL query for fetching issues
build_jql() {
    if [[ -n "$_jql" ]]; then
        printf '%s' "$_jql"
        return
    fi

    # Default: assigned to me, not done
    local jql="assignee = currentUser() AND resolution = Unresolved"

    # Add project filter if specified
    [[ -n "$_project" ]] && jql+=" AND project = ${_project}"

    # Order by status category, then priority
    jql+=" ORDER BY status ASC, priority DESC, updated DESC"

    printf '%s' "$jql"
}

# URL encode string
url_encode() {
    local string="$1"
    printf '%s' "$string" | sed "s/ /%20/g; s/=/%3D/g; s/\"/%22/g; s/'/%27/g; s/(/%28/g; s/)/%29/g; s/,/%2C/g"
}

# Get status color based on status category
get_status_color() {
    local status_category="$1"
    case "$status_category" in
        "In Progress") echo "$COLOR_IN_PROGRESS" ;;
        "To Do")       echo "$COLOR_TODO" ;;
        "Done")        echo "$COLOR_DONE" ;;
        *)             echo "$COLOR_DIM" ;;
    esac
}

# Determine if status name indicates flagged/blocked
is_flagged_by_status() {
    local status_name="$1"
    local lower_status="${status_name,,}"  # Bash 4.0+ lowercase

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

# Fetch all issues with details
fetch_issues() {
    local jql
    jql=$(build_jql)
    local encoded_jql
    encoded_jql=$(url_encode "$jql")

    local all_issues=""
    local next_token=""

    while true; do
        local url="search/jql?jql=${encoded_jql}&maxResults=50&fields=key,summary,status,priority,flagged"
        [[ -n "$next_token" ]] && url+="&nextPageToken=${next_token}"

        local response
        response=$(jira_api_call "$url")
        [[ -z "$response" ]] && break

        # Check for errors - jq -e returns non-zero if expression is false/null
        # We check if errorMessages key exists and has content
        local error_check
        error_check=$(echo "$response" | jq -r '.errorMessages[0] // empty' 2>/dev/null) || error_check=""
        if [[ -n "$error_check" ]]; then
            echo "Error: $error_check" >&2
            return 1
        fi

        # Accumulate issues - use subshell to isolate jq errors
        local batch
        batch=$(echo "$response" | jq -r '.issues[]? | @json' 2>/dev/null) || batch=""
        [[ -n "$batch" ]] && all_issues+="$batch"$'\n'

        # Check if this is the last page
        local is_last
        is_last=$(echo "$response" | jq -r '.isLast // true' 2>/dev/null) || is_last="true"
        [[ "$is_last" == "true" ]] && break

        # Get next page token
        next_token=$(echo "$response" | jq -r '.nextPageToken // empty' 2>/dev/null) || next_token=""
        [[ -z "$next_token" ]] && break
    done

    printf '%s' "$all_issues"
}

# Column widths for alignment
COL_STATUS=14
COL_KEY=12
COL_SUMMARY=55
COL_PRIORITY=10

# Get sort priority for status category (lower = first)
get_sort_priority() {
    local status="$1"
    local status_category="$2"

    # Flagged issues first (priority 1)
    if is_flagged_by_status "$status"; then
        echo "1"
    # In Progress second (priority 2)
    elif [[ "$status_category" == "In Progress" ]]; then
        echo "2"
    # To Do/Backlog last (priority 3)
    else
        echo "3"
    fi
}

# Pad string to fixed width (handles text without ANSI codes)
pad_string() {
    local str="$1"
    local width="$2"
    local len=${#str}

    if [[ $len -ge $width ]]; then
        printf '%s' "${str:0:$width}"
    else
        printf '%s%*s' "$str" $((width - len)) ""
    fi
}

# Check if issue is flagged (either by Jira flag field or status name)
is_issue_flagged() {
    local issue_json="$1"
    local status="$2"

    # Check Jira's flagged field (can be in different formats)
    local flagged_value
    flagged_value=$(echo "$issue_json" | jq -r '.fields.flagged // empty' 2>/dev/null)

    # Flagged can be: true, "Impediment", array with "Impediment", etc.
    if [[ -n "$flagged_value" && "$flagged_value" != "null" && "$flagged_value" != "false" && "$flagged_value" != "[]" ]]; then
        return 0
    fi

    # Also check customfield for flagged (some Jira instances use customfield_10021)
    flagged_value=$(echo "$issue_json" | jq -r '(.fields | to_entries | map(select(.key | test("flagged|impediment"; "i"))) | .[0].value) // empty' 2>/dev/null)
    if [[ -n "$flagged_value" && "$flagged_value" != "null" && "$flagged_value" != "false" && "$flagged_value" != "[]" ]]; then
        return 0
    fi

    # Fallback: check status name for flagged keywords
    is_flagged_by_status "$status"
}

# Format issue for display with fixed-width columns
format_issue() {
    local issue_json="$1"

    local key summary status status_category priority
    key=$(echo "$issue_json" | jq -r '.key')
    summary=$(echo "$issue_json" | jq -r '.fields.summary // "No summary"')
    status=$(echo "$issue_json" | jq -r '.fields.status.name // "Unknown"')
    status_category=$(echo "$issue_json" | jq -r '.fields.status.statusCategory.name // "Unknown"')
    priority=$(echo "$issue_json" | jq -r '.fields.priority.name // "None"')

    # Truncate summary if too long
    if [[ ${#summary} -gt $COL_SUMMARY ]]; then
        summary="${summary:0:$((COL_SUMMARY-3))}..."
    fi

    # Pad strings to fixed width BEFORE adding colors
    local padded_status padded_key padded_summary padded_priority
    padded_status=$(pad_string "$status" "$COL_STATUS")
    padded_key=$(pad_string "$key" "$COL_KEY")
    padded_summary=$(pad_string "$summary" "$COL_SUMMARY")
    padded_priority=$(pad_string "$priority" "$COL_PRIORITY")

    # Get color based on flagged status
    local color is_flagged=0
    if is_issue_flagged "$issue_json" "$status"; then
        color="$COLOR_FLAGGED"
        is_flagged=1
    else
        color=$(get_status_color "$status_category")
    fi

    # Get sort priority for grouping
    local sort_priority
    if [[ $is_flagged -eq 1 ]]; then
        sort_priority="1"
    elif [[ "$status_category" == "In Progress" ]]; then
        sort_priority="2"
    else
        sort_priority="3"
    fi

    # Output with sort key prefix (will be removed before display)
    # Format: SORT_KEY|colored_line
    printf '%s|%b%s%b │ %b%s%b │ %s │ %s\n' \
        "$sort_priority" \
        "$color" "$padded_status" "$COLOR_RESET" \
        "$COLOR_BOLD" "$padded_key" "$COLOR_RESET" \
        "$padded_summary" \
        "$padded_priority"
}

# Create section separator line
create_separator() {
    local label="$1"
    local color="$2"
    local width=$((COL_STATUS + COL_KEY + COL_SUMMARY + COL_PRIORITY + 12))  # 12 for separators
    local line=""
    local i

    # Create dashed line
    for ((i=0; i<width; i++)); do
        line+="─"
    done

    printf '%b── %s %b%s\n' "$color" "$label" "$COLOR_RESET" "${line:0:$((width - ${#label} - 4))}"
}

# Open issue in browser
open_issue() {
    local key="$1"
    local url="${_url}/browse/${key}"

    if has_cmd "open"; then
        open "$url"
    elif has_cmd "xdg-open"; then
        xdg-open "$url"
    elif has_cmd "wslview"; then
        wslview "$url"
    else
        echo "Cannot open browser. URL: $url"
    fi
}

# =============================================================================
# Main
# =============================================================================

show_error_and_wait() {
    echo "$1"
    echo ""
    echo "Press any key to close..."
    read -r -n 1
    exit 1
}

main() {
    # Validate configuration
    if [[ -z "$_domain" || -z "$_email" || -z "$_token" ]]; then
        show_error_and_wait "Error: Jira plugin not configured.
Required: @powerkit_plugin_jira_domain, @powerkit_plugin_jira_email, @powerkit_plugin_jira_token"
    fi

    # Check dependencies
    local backend
    backend=$(ui_get_backend)
    if [[ "$backend" == "basic" ]]; then
        show_error_and_wait "Error: fzf or gum is required for interactive issue selection"
    fi

    if ! has_cmd "jq"; then
        show_error_and_wait "Error: jq is required for JSON parsing"
    fi

    # Fetch issues (with cache)
    local issues=""
    local cached_issues=""

    # cache_get returns non-zero when cache miss/expired - this is expected behavior
    if cached_issues=$(cache_get "$SELECTOR_CACHE_KEY" "$_selector_cache_ttl"); then
        issues="$cached_issues"
    else
        # fetch_issues returns non-zero on API errors - capture and handle
        if issues=$(fetch_issues); then
            # Save to cache only on successful fetch
            if [[ -n "$issues" ]]; then
                cache_set "$SELECTOR_CACHE_KEY" "$issues"
            fi
        fi
    fi

    if [[ -z "$issues" ]]; then
        show_error_and_wait "No issues found."
    fi

    # Format issues for display with sort key prefix
    local raw_formatted=""
    while IFS= read -r issue_json; do
        [[ -z "$issue_json" ]] && continue
        raw_formatted+="$(format_issue "$issue_json")"$'\n'
    done <<< "$issues"

    if [[ -z "$raw_formatted" ]]; then
        show_error_and_wait "Error: Could not format issues."
    fi

    # Sort by priority and add section headers
    local sorted_lines=""
    sorted_lines=$(printf '%s' "$raw_formatted" | sort -t'|' -k1,1n) || sorted_lines="$raw_formatted"

    local formatted=""
    local current_section=""
    local prev_section=""

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Extract sort key and content
        current_section="${line%%|*}"
        local content="${line#*|}"

        # Add section separator when section changes
        if [[ "$current_section" != "$prev_section" ]]; then
            case "$current_section" in
                1) formatted+="$(create_separator "FLAGGED" "$COLOR_FLAGGED")"$'\n' ;;
                2) formatted+="$(create_separator "IN PROGRESS" "$COLOR_IN_PROGRESS")"$'\n' ;;
                3) formatted+="$(create_separator "BACKLOG" "$COLOR_TODO")"$'\n' ;;
            esac
            prev_section="$current_section"
        fi

        formatted+="$content"$'\n'
    done <<< "$sorted_lines"

    # Use ui_filter for selection with header
    local selected
    local header
    local h_status h_key h_summary h_priority
    h_status=$(pad_string "STATUS" "$COL_STATUS")
    h_key=$(pad_string "KEY" "$COL_KEY")
    h_summary=$(pad_string "SUMMARY" "$COL_SUMMARY")
    h_priority=$(pad_string "PRIORITY" "$COL_PRIORITY")
    header=$(printf '%b%s%b │ %b%s%b │ %s │ %s' \
        "$COLOR_DIM" "$h_status" "$COLOR_RESET" \
        "$COLOR_DIM" "$h_key" "$COLOR_RESET" \
        "$h_summary" \
        "$h_priority")

    # ui_filter handles both fzf and gum backends
    selected=$(printf '%s' "$formatted" | ui_filter \
        -h "$header" \
        -p "Select issue >" \
        -a \
        --height "100%") || true

    # Exit gracefully if user cancelled or no selection
    if [[ -z "$selected" ]]; then
        exit 0
    fi

    if [[ -n "$selected" ]]; then
        # Extract issue key from selection using bash regex (avoids grep pipe issues)
        local key=""
        if [[ "$selected" =~ [A-Z]+-[0-9]+ ]]; then
            key="${BASH_REMATCH[0]}"
        fi

        if [[ -n "$key" ]]; then
            open_issue "$key"
            toast "Opened $key in browser" "success"
        fi
    fi
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-browse}"

    case "$action" in
        browse|"") main ;;
        *)
            echo "Unknown action: $action" >&2
            return 1
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
