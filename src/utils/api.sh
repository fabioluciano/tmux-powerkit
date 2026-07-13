#!/usr/bin/env bash
# =============================================================================
# PowerKit Utility: API Fetch Helpers
# Description: Reusable API fetch utilities to eliminate duplication across plugins
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "api" && return 0

# =============================================================================
# Simple API Fetch
# =============================================================================

# Simple API fetch with timeout and error handling
# Usage: api_fetch_url "https://api.example.com/endpoint" [timeout]
# Returns: Response body or empty string on failure
api_fetch_url() {
    local url="$1"
    local timeout="${2:-5}"

    curl -s --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null
}

# =============================================================================
# API Fetch with Retry
# =============================================================================

# API fetch with retry logic (3 attempts with 1s delay)
# Usage: api_fetch_with_retry "https://api.example.com/endpoint" [timeout]
# Returns: Response body or empty string on failure
api_fetch_with_retry() {
    local url="$1"
    local timeout="${2:-5}"
    local max_attempts=3
    local result

    local attempt
    for attempt in $(seq 1 $max_attempts); do
        result=$(api_fetch_url "$url" "$timeout")
        [[ -n "$result" ]] && {
            echo "$result"
            return 0
        }
        [[ $attempt -lt $max_attempts ]] && sleep 1
    done

    return 1
}

# =============================================================================
# API Fetch with Authorization
# =============================================================================

# API fetch with authorization header
# Usage: api_fetch_with_auth "https://api.example.com/endpoint" "Bearer token" [timeout]
# Returns: Response body or empty string on failure
api_fetch_with_auth() {
    local url="$1"
    local auth="$2"
    local timeout="${3:-5}"

    curl -s --connect-timeout "$timeout" --max-time "$timeout" \
        -H "Authorization: $auth" \
        "$url" 2>/dev/null
}

# =============================================================================
# Specialized API Fetch (GitHub, GitLab, etc.)
# =============================================================================

# Make API call with supported authentication types.
# Usage: make_api_call "url" "auth_type" "credential" [timeout]
# auth_type: bearer, github, private-token, basic, or a legacy provider name.
make_api_call() {
    local url="$1"
    local auth_type="$2"
    local credential="$3"
    local timeout="${4:-5}"

    local -a auth_args=()
    local accept_header="Accept: application/json"

    case "$auth_type" in
    github)
        auth_args=(-H "Authorization: token ${credential}")
        accept_header="Accept: application/vnd.github+json"
        ;;
    gitlab | private-token)
        auth_args=(-H "PRIVATE-TOKEN: ${credential}")
        ;;
    bitbucket | bearer)
        auth_args=(-H "Authorization: Bearer ${credential}")
        ;;
    basic)
        auth_args=(-u "$credential")
        ;;
    *)
        [[ -n "$credential" ]] && auth_args=(-H "Authorization: Bearer ${credential}")
        ;;
    esac

    curl -sf --connect-timeout "$timeout" --max-time "$((timeout * 2))" \
        "${auth_args[@]}" \
        -H "$accept_header" \
        "$url" 2>/dev/null
}

# =============================================================================
# Response Validation
# =============================================================================

# Validate API response (check if empty or contains error)
# Usage: api_validate_response "$result" || return 1
# Returns: 0 if valid, 1 if invalid
api_validate_response() {
    local response="$1"

    # Empty response
    [[ -z "$response" ]] && return 1

    # Whitespace only
    [[ "$response" =~ ^[[:space:]]*$ ]] && return 1

    # Contains error field (common in JSON APIs)
    [[ "$response" =~ \"error\" ]] && return 1

    return 0
}

# Check if response contains specific error patterns
# Usage: api_has_error "$response" || handle_error
# Returns: 0 if error found, 1 if no error
api_has_error() {
    local response="$1"

    # Common error patterns in JSON APIs
    [[ "$response" =~ \"error\": ]] && return 0
    [[ "$response" =~ \"message\":.*\"(error|failed|invalid)\" ]] && return 0
    [[ "$response" =~ ^HTTP/[0-9.].*\ (4[0-9]{2}|5[0-9]{2}) ]] && return 0

    return 1
}

# =============================================================================
# HTTP Status Code Handling
# =============================================================================

# Fetch URL with HTTP status code
# Usage: api_fetch_with_status "url" [timeout]
# Returns: "status_code body" (e.g., "200 {...}")
api_fetch_with_status() {
    local url="$1"
    local timeout="${2:-5}"

    local response
    response=$(curl -s -w "\n%{http_code}" --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null)

    # Split into body and status code
    local body="${response%$'\n'*}"
    local status="${response##*$'\n'}"

    echo "$status $body"
}

# Check if HTTP status code indicates success (2xx)
# Usage: api_is_success "200"
api_is_success() {
    local status_code="$1"
    [[ "$status_code" =~ ^2[0-9]{2}$ ]]
}

# =============================================================================
# Debug Logging
# =============================================================================

log_debug "api" "API utilities loaded"
