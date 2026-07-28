#!/usr/bin/env bash
# =============================================================================
# aiquotas adapter — kimicode (Kimi Code / Moonshot AI)
# =============================================================================
# Companion adapter for the aiquotas plugin. Provides _aiquotas_collect_kimicode
# which emits a canonical metrics document for the Kimi Code usage/quota.
#
# Loaded lazily by _aiquotas_load_provider in the entry point. NEVER source this
# file directly — go through the loader.
#
# Endpoint: GET https://api.kimi.com/coding/v1/usages
# Auth:     Authorization: Bearer <KIMI_CODE_API_KEY>
# Shape:    {usage:{limit, remaining, resetTime},
#            limits:[{window:{duration, timeUnit}, detail:{limit, remaining}}]}
#           Primary: usage.limit/remaining (weekly window).
#           Secondary: limits[].detail (5h rolling rate limit).
#
# The endpoint is the same one the Kimi Code CLI and web console query for
# usage tracking.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_kimicode" && return 0

# -----------------------------------------------------------------------------
# Kimi Code adapter
# -----------------------------------------------------------------------------
#
# Reads the Kimi Code usage endpoint and emits one quota record for the weekly
# window (5h rate limit as a dimension). Treats the data as `official` ONLY
# when KIMI_CODE_API_KEY is set.
#
# Returns the canonical JSON document on stdout. Exits 0 even on partial
# failure (the document's provider_outcomes entry carries the error); exits
# non-zero only when jq cannot assemble the envelope at all.
#
_aiquotas_collect_kimicode() {
    local key="${KIMI_CODE_API_KEY:-}"

    if [[ -z "$key" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"kimicode",source:"official",
                                 status:"unconfigured",
                                 error:"KIMI_CODE_API_KEY not set"}]}
        '
        return 0
    fi

    local url timeout body status
    url=$(get_option "kimicode_usage_url")
    timeout=$(get_option "timeout")
    timeout="${timeout:-5}"

    if [[ -z "$url" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"kimicode",source:"official",
                                 status:"unconfigured",
                                 error:"kimicode usage URL not configured"}]}
        '
        return 0
    fi

    # Standard GET request. The credential travels via stdin so it never
    # appears in argv.
    body=$(_aiquotas_http_get_meta_authed \
        "$url" "$timeout" \
        "Authorization" "Bearer $key" \
        -H "Accept: application/json") || body=""
    status=$(_aiquotas_last_status)

    if [[ -z "$body" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"kimicode",source:"official",
                                 status:"unavailable",
                                 error:"quota fetch transport failure"}]}
        '
        return 0
    fi

    if [[ "$status" != 2* ]]; then
        local canonical_status canonical_error
        canonical_status=$(_aiquotas_http_status_to_canonical "$status")
        canonical_error=$(_aiquotas_http_status_error_message "$body" "quota")
        jq -nc \
            --arg st "$canonical_status" \
            --arg er "$canonical_error" \
            --arg src "official" \
            '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"kimicode",source:$src,
                                 status:$st, error:$er}]}
            '
        return 0
    fi

    if ! _aiquotas_metrics_document "kimicode" "$body" 2>/dev/null; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"kimicode",source:"official",
                                 status:"malformed",
                                 error:"quota payload normalization failed"}]}
        '
        return 0
    fi
}
