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
#
# The auth string is routed via curl --config (stdin) so the token never
# appears in process argv.
api_fetch_with_auth() {
    local url="$1"
    local auth="$2"
    local timeout="${3:-5}"

    printf 'header = "Authorization: %s"\n' "$auth" | curl -s \
        --config - \
        --connect-timeout "$timeout" --max-time "$timeout" \
        "$url" 2>/dev/null
}

# =============================================================================
# Specialized API Fetch (GitHub, GitLab, etc.)
# =============================================================================

# Make API call with supported authentication types.
# Usage: make_api_call "url" "auth_type" "credential" [timeout]
# auth_type: bearer, github, private-token, basic, or a legacy provider name.
#
# DEPRECATED: the credential is passed as a curl argv element and is
# therefore visible in process listings. Prefer
# api_fetch_with_bearer / api_fetch_with_token_header /
# api_fetch_with_basic_config for any new caller so the secret stays
# out of argv.
make_api_call() {
    local url="$1"
    local auth_type="$2"
    local credential="$3"
    local timeout="${4:-5}"

    # Route every credential through curl --config (stdin) so the
    # token never appears in process argv. The config body is built
    # line by line depending on auth_type.
    local cfg_body="" accept_header="Accept: application/json"

    case "$auth_type" in
    github)
        cfg_body+="header = \"Authorization: token ${credential}\""$'\n'
        accept_header="Accept: application/vnd.github+json"
        ;;
    gitlab | private-token)
        cfg_body+="header = \"PRIVATE-TOKEN: ${credential}\""$'\n'
        ;;
    bitbucket | bearer)
        cfg_body+="header = \"Authorization: Bearer ${credential}\""$'\n'
        ;;
    basic)
        cfg_body+="user = \"${credential}\""$'\n'
        ;;
    *)
        if [[ -n "$credential" ]]; then
            cfg_body+="header = \"Authorization: Bearer ${credential}\""$'\n'
        fi
        ;;
    esac
    cfg_body+="header = \"${accept_header}\""$'\n'

    printf '%s' "$cfg_body" | curl -sf \
        --config - \
        --connect-timeout "$timeout" \
        --max-time "$((timeout * 2))" \
        "$url" 2>/dev/null
}

# =============================================================================
# Credential-Safe Transport
# =============================================================================
# These helpers avoid exposing secrets in process argv (visible via /proc,
# ps, process accounting, set -x traces). Prefer them over make_api_call when
# the credential would otherwise appear as a curl argv element.

# Fetch a URL with an HTTP header passed via curl --config (stdin).
# Usage: api_fetch_with_header_stdin "url" "Header-Name: value" [timeout]
# Returns: response body; empty string on transport failure
api_fetch_with_header_stdin() {
    local url="$1" header="$2" timeout="${3:-5}"
    printf 'header = "%s"\n' "$header" |
        curl -sf --config - --connect-timeout "$timeout" --max-time "$((timeout * 2))" \
            "$url" 2>/dev/null
}

# Fetch a URL with HTTP basic auth passed via a curl config file.
# Usage: api_fetch_with_basic_config "url" "user" "password" [timeout]
# Returns: response body; empty string on transport failure
# The temp file is created with mode 600 and removed via trap on return.
api_fetch_with_basic_config() {
    local url="$1" user="$2" password="$3" timeout="${4:-5}"
    local cfg
    cfg=$(mktemp "${TMPDIR:-/tmp}/powerkit-curl.XXXXXX") || return 1
    chmod 600 "$cfg"
    trap 'rm -f "$cfg"' RETURN
    printf -- '-u %s:%s\n' "$user" "$password" >"$cfg"
    curl -sf --config "$cfg" --connect-timeout "$timeout" --max-time "$((timeout * 2))" \
        "$url" 2>/dev/null
}

# Fetch a URL with bearer token in Authorization header, passed via stdin.
# Usage: api_fetch_with_bearer "url" "token" [timeout]
api_fetch_with_bearer() {
    local url="$1" token="$2" timeout="${3:-5}"
    api_fetch_with_header_stdin "$url" "Authorization: Bearer ${token}" "$timeout"
}

# Fetch a URL with a vendor-specific token header via stdin.
# Usage: api_fetch_with_token_header "url" "Header-Name" "token" [timeout]
# Example: api_fetch_with_token_header "$url" "PRIVATE-TOKEN" "$glpat" 5
api_fetch_with_token_header() {
    local url="$1" header_name="$2" token="$3" timeout="${4:-5}"
    api_fetch_with_header_stdin "$url" "${header_name}: ${token}" "$timeout"
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

# Validate that a string is parseable JSON (requires jq).
# Usage: api_validate_json "$body" || return 1
# Returns: 0 if valid JSON, 1 if not
api_validate_json() {
    local body="$1"
    has_cmd jq || return 1
    printf '%s' "$body" | jq -e . >/dev/null 2>&1
}

# Validate that a string is an IPv4 or IPv6 address.
# Usage: api_validate_ip "$value" || return 1
# Returns: 0 if valid IP, 1 if not
api_validate_ip() {
    local value="$1"
    if [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local o
        local IFS='.'
        # shellcheck disable=SC2206
        local -a octets=($value)
        for o in "${octets[@]}"; do
            ((o >= 0 && o <= 255)) || return 1
        done
        return 0
    fi
    # IPv6: every group is 1-4 hex digits separated by ":". A single
    # "::" is allowed to compress one or more zero groups. Reject
    # values that have no colon at all, more than one "::", or that
    # don't expose either the 8-group form or the compressed form.
    if [[ ! "$value" =~ ^[0-9a-fA-F:]+$ ]]; then
        return 1
    fi
    [[ "$value" == *:* ]] || return 1
    # More than one "::" is invalid. awk splits on the literal "::"
    # and reports the number of resulting fields; 1 means no "::",
    # 2 means exactly one, 3+ means too many.
    local dbl_colon_count
    dbl_colon_count=$(awk -v v="$value" 'BEGIN { n = split(v, parts, "::"); print (n - 1) }')
    [[ "$dbl_colon_count" -le 1 ]] || return 1
    # Each non-empty group must be 1-4 hex digits; the empty groups
    # around "::" are accepted as-is.
    local IFS=':'
    # shellcheck disable=SC2206
    local -a groups=($value)
    local g
    for g in "${groups[@]}"; do
        [[ -z "$g" || "$g" =~ ^[0-9a-fA-F]{1,4}$ ]] || return 1
    done
    # Require either 8 groups (full form) or at least one "::"
    # (compressed form). Without this check "abc:def" would pass
    # because both groups are valid 1-4 hex chunks.
    if [[ "$value" == *"::"* ]]; then
        return 0
    fi
    [[ "${#groups[@]}" -eq 8 ]]
}

# Classify an HTTP response into a canonical outcome string.
# Usage: outcome=$(api_classify_outcome "$http_status" "$body")
# Returns: success | unauthorized | forbidden | rate_limited | not_found |
#          server_error | transport_error | malformed
api_classify_outcome() {
    local status="$1" body="${2:-}"
    case "$status" in
    2*) printf 'success' ;;
    401) printf 'unauthorized' ;;
    403) printf 'forbidden' ;;
    404) printf 'not_found' ;;
    429) printf 'rate_limited' ;;
    5*) printf 'server_error' ;;
    0 | "") printf 'transport_error' ;;
    *)
        [[ -z "$body" ]] && printf 'transport_error' || printf 'malformed'
        ;;
    esac
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
