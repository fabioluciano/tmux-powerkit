#!/usr/bin/env bash
# =============================================================================
# src/plugins/aiquotas/_http.sh — Aiquotas HTTP-specific helpers
# Plan: .omo/plans/aiquotas-refactor.md (post-refactor consolidation)
# =============================================================================
# HTTP compatibility seams, status mapping, and error message extraction.
# Generic HTTP helpers come from utils/api.sh.
# Time helpers come from utils/time.sh (time_iso_*, time_epoch_*).
#
# Loaded eagerly by aiquotas.sh.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_http" && return 0

# Strict HTTP GET compatibility seam. Tests intercept curl via PATH.
_aiquotas_http_get() {
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

# Lenient HTTP GET compatibility seam. Tests intercept curl via PATH.
_aiquotas_http_get_meta() {
    local url="$1"
    local timeout="${2:-5}"
    shift 2
    local extra_args=("$@")
    local body rc
    body=$(curl -s \
        --connect-timeout "$timeout" \
        --max-time "$((timeout * 2))" \
        "${extra_args[@]}" \
        "$url" 2>/dev/null)
    rc=$?
    if ((rc != 0)); then
        printf ''
        return "$rc"
    fi
    printf '%s' "$body"
}

# Credential-safe HTTP GET: header_name + header_value are routed to curl
# via stdin (so the secret never appears in process argv). All other args
# pass through argv as usual. Use this whenever an API key, cookie or
# bearer token would otherwise be appended via -H "..." in argv.
# Usage: _aiquotas_http_get_meta_authed "url" "timeout" "Header-Name" "Header-Value" [extra_argv...]
_aiquotas_http_get_meta_authed() {
    local url="$1"
    local timeout="${2:-5}"
    local header_name="$3"
    local header_value="$4"
    shift 4
    local extra_args=("$@")
    local body rc
    body=$(printf 'header = "%s: %s"\n' "$header_name" "$header_value" | curl -s \
        --config - \
        --connect-timeout "$timeout" \
        --max-time "$((timeout * 2))" \
        "${extra_args[@]}" \
        "$url" 2>/dev/null)
    rc=$?
    if ((rc != 0)); then
        printf ''
        return "$rc"
    fi
    printf '%s' "$body"
}

# Same as _aiquotas_http_get_meta_authed but for the strict (`-sf`) seam.
_aiquotas_http_get_authed() {
    local url="$1"
    local timeout="${2:-5}"
    local header_name="$3"
    local header_value="$4"
    shift 4
    local extra_args=("$@")
    curl -sf \
        --connect-timeout "$timeout" \
        --max-time "$((timeout * 2))" \
        --config <(printf 'header = "%s: %s"\n' "$header_name" "$header_value") \
        "${extra_args[@]}" \
        "$url" 2>/dev/null
}

# Read the HTTP status the shim served for the most recent call.
# Falls back to "200" when no shim is active (real curl has no concept of
# last_status; the adapter contract assumes 2xx on transport success).
_aiquotas_last_status() {
    local state="${AIQUOTAS_HTTP_STATE:-}"
    if [[ -z "$state" || ! -f "$state/last_status" ]]; then
        printf '200'
        return
    fi
    local s
    s="$(<"$state/last_status")"
    s="${s//[[:space:]]/}"
    [[ -n "$s" ]] && printf '%s' "$s" || printf '200'
}

# Map a numeric HTTP status to the canonical status enum used in
# provider_outcomes: 2xx->ok, 401/403->unauthorized, 429->rate_limited, else->unavailable.
_aiquotas_http_status_to_canonical() {
    local status="$1"
    case "$status" in
    2*) printf 'ok' ;;
    401 | 403) printf 'unauthorized' ;;
    429) printf 'rate_limited' ;;
    *) printf 'unavailable' ;;
    esac
}

# Compose a human-readable error string from a non-2xx HTTP body. Prefers
# the provider's error.message; falls back to a placeholder when empty.
_aiquotas_http_status_error_message() {
    local body="$1"
    local endpoint="$2"
    if [[ -z "$body" ]]; then
        printf '%s: HTTP response body empty' "$endpoint"
        return
    fi
    local msg
    msg=$(jq -r '
        if type == "object" and (.error.message // null) != null
        then .error.message
        elif type == "object" and (.message // null) != null
        then .message
        else "" end' <<<"$body" 2>/dev/null) || msg=""
    if [[ -z "$msg" ]]; then
        printf '%s: HTTP error response' "$endpoint"
    else
        printf '%s: %s' "$endpoint" "$msg"
    fi
}

log_debug "aiquotas_http" "Aiquotas HTTP-specific helpers loaded"
