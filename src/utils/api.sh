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

    curl -s --connect-timeout "$timeout" "$url" 2>/dev/null
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
        [[ -n "$result" ]] && { echo "$result"; return 0; }
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

    curl -s --connect-timeout "$timeout" \
        -H "Authorization: $auth" \
        "$url" 2>/dev/null
}

# =============================================================================
# Specialized API Fetch (GitHub, GitLab, etc.)
# =============================================================================

# Make API call with platform-specific headers
# Usage: make_api_call "url" "platform" "token" [timeout]
# Platform: github, gitlab, bitbucket
# Returns: Response body or empty string on failure
make_api_call() {
    local url="$1"
    local platform="$2"
    local token="$3"
    local timeout="${4:-5}"

    local auth_header accept_header

    case "$platform" in
        github)
            auth_header="Authorization: Bearer ${token}"
            accept_header="Accept: application/vnd.github+json"
            ;;
        gitlab)
            auth_header="PRIVATE-TOKEN: ${token}"
            accept_header="Accept: application/json"
            ;;
        bitbucket)
            auth_header="Authorization: Bearer ${token}"
            accept_header="Accept: application/json"
            ;;
        *)
            # Generic API - just use Bearer token
            auth_header="Authorization: Bearer ${token}"
            accept_header="Accept: application/json"
            ;;
    esac

    curl -s --connect-timeout "$timeout" \
        -H "$auth_header" \
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
    response=$(curl -s -w "\n%{http_code}" --connect-timeout "$timeout" "$url" 2>/dev/null)

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
