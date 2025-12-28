#!/usr/bin/env bash
# =============================================================================
# Network Utilities
# Description: HTTP/API call utilities with error handling
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_network" && return 0

. "${POWERKIT_ROOT}/src/utils/platform.sh"

# =============================================================================
# Safe HTTP Requests
# =============================================================================

# Safe curl with timeout and error handling
# Usage: safe_curl <url> [timeout] [extra_args...]
# Returns: curl output or empty on error
safe_curl() {
    local url="$1"
    local timeout="${2:-5}"
    shift 2 2>/dev/null || shift 1
    local extra_args=("$@")

    curl -sf \
        --connect-timeout "$timeout" \
        --max-time "$((timeout * 2))" \
        "${extra_args[@]}" \
        "$url" 2>/dev/null
}

# =============================================================================
# API Authentication
# =============================================================================

# Make authenticated API call
# Usage: make_api_call <url> <auth_type> <token> [timeout]
# auth_type: "bearer" (standard OAuth), "github" (GitHub), "private-token" (GitLab), "basic" (user:pass)
# Returns: API response or empty on error
make_api_call() {
    local url="$1"
    local auth_type="$2"
    local token="$3"
    local timeout="${4:-5}"

    local auth_args=()
    if [[ -n "$token" ]]; then
        case "$auth_type" in
            bearer)
                # Standard OAuth Bearer token (Bitbucket, etc.)
                auth_args=(-H "Authorization: Bearer $token")
                ;;
            github)
                # GitHub uses "token" instead of "Bearer"
                auth_args=(-H "Authorization: token $token")
                ;;
            private-token)
                # GitLab style
                auth_args=(-H "PRIVATE-TOKEN: $token")
                ;;
            basic)
                # Basic auth (user:password or user:token)
                auth_args=(-u "$token")
                ;;
            *)
                # No auth or unknown type
                ;;
        esac
    fi

    curl -sf \
        --connect-timeout "$timeout" \
        --max-time "$((timeout * 2))" \
        "${auth_args[@]}" \
        "$url" 2>/dev/null
}

# =============================================================================
# Endpoint Reachability
# =============================================================================

# Check if an endpoint is reachable
# Usage: is_endpoint_reachable <url> [timeout]
# Returns: 0 if reachable, 1 if not
is_endpoint_reachable() {
    local url="$1"
    local timeout="${2:-2}"

    # Use safe_curl with -o /dev/null to just check connectivity
    safe_curl "$url" "$timeout" -o /dev/null
}

# Check if a host:port is reachable (TCP connection test)
# Usage: is_host_reachable <host> <port> [timeout]
# Returns: 0 if reachable, 1 if not
is_host_reachable() {
    local host="$1"
    local port="$2"
    local timeout="${3:-2}"

    if has_cmd nc; then
        nc -z -w "$timeout" "$host" "$port" 2>/dev/null
    elif has_cmd timeout; then
        timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
    else
        # Fallback: use safe_curl
        safe_curl "http://${host}:${port}" "$timeout" -o /dev/null
    fi
}

# =============================================================================
# JSON Parsing (without jq dependency)
# =============================================================================

# Extract simple JSON value (works without jq for simple cases)
# Usage: json_get_value <json> <key>
# Returns: value or empty
json_get_value() {
    local json="$1"
    local key="$2"
    
    # Try jq first if available
    if has_cmd "jq"; then
        printf '%s' "$json" | jq -r ".$key // empty" 2>/dev/null
        return
    fi
    
    # Fallback: simple grep/sed extraction (works for simple flat JSON)
    printf '%s' "$json" | grep -o "\"$key\":[^,}]*" | head -1 | sed 's/.*://' | tr -d '"[:space:]'
}

# Extract JSON array size
# Usage: json_get_size <json>
# Returns: size number or 0
json_get_size() {
    local json="$1"
    
    if has_cmd "jq"; then
        printf '%s' "$json" | jq -r '.size // 0' 2>/dev/null
        return
    fi
    
    # Fallback
    printf '%s' "$json" | grep -o '"size":[0-9]*' | head -1 | grep -o '[0-9]*' || printf '0'
}
