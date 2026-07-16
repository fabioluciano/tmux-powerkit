#!/usr/bin/env bash
# =============================================================================
# aiquotas adapter — zai (Z.ai / Zhipu GLM Coding Plan)
# =============================================================================
# Companion adapter for the aiquotas plugin. Provides _aiquotas_collect_zai
# which emits a canonical metrics document for the Z.ai Coding Plan quota.
#
# Loaded lazily by _aiquotas_load_provider in the entry point. NEVER source this
# file directly — go through the loader.
#
# Endpoint: GET https://api.z.ai/api/monitor/usage/quota/limit
# Auth:     Authorization: <ZAI_API_KEY> (raw key; Bearer fallback on 401)
# Shape:    {success, code, msg, data:{limits:[{type, unit, percentage,
#            nextResetTime}]}}
#           TOKENS_LIMIT unit=3 -> 5-hour window (preferred)
#           TOKENS_LIMIT unit=6 -> weekly window (fallback)
#           percentage = % CONSUMED; remaining% = 100 - percentage.
#
# The endpoint is undocumented (not in the public OpenAPI spec) but is the same
# one the official Z.ai web console and community trackers query. It returns
# percentage-based quota only (no raw token counts), so the canonical record is
# modelled as a quota over a 0-100 scale with unit="percent".
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_zai" && return 0

# -----------------------------------------------------------------------------
# Z.ai adapter
# -----------------------------------------------------------------------------
#
# Reads the Z.ai Coding Plan quota/limit endpoint and emits one token-quota
# record for the 5-hour window (weekly as a dimension). Treats the data as
# `official` ONLY when ZAI_API_KEY is set.
#
# Returns the canonical JSON document on stdout. Exits 0 even on partial
# failure (the document's provider_outcomes entry carries the error); exits
# non-zero only when jq cannot assemble the envelope at all.
#
_aiquotas_collect_zai() {
    local key="${ZAI_API_KEY:-}"

    if [[ -z "$key" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"zai",source:"official",
                                 status:"unconfigured",
                                 error:"ZAI_API_KEY not set"}]}
        '
        return 0
    fi

    local url timeout body status
    url=$(get_option "zai_quota_url")
    timeout=$(get_option "timeout")
    timeout="${timeout:-5}"

    if [[ -z "$url" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"zai",source:"official",
                                 status:"unconfigured",
                                 error:"zai quota URL not configured"}]}
        '
        return 0
    fi

    # The Z.ai monitor endpoints accept the raw API key (matching the web
    # console). Some keys require the Bearer form, so retry on a 401.
    body=$(_aiquotas_http_get_meta \
        "$url" "$timeout" \
        -H "Authorization: $key" \
        -H "Content-Type: application/json" \
        -H "Accept-Language: en-US,en") || body=""
    status=$(_aiquotas_last_status)

    if [[ "$status" == "401" ]]; then
        body=$(_aiquotas_http_get_meta \
            "$url" "$timeout" \
            -H "Authorization: Bearer $key" \
            -H "Content-Type: application/json" \
            -H "Accept-Language: en-US,en") || body=""
        status=$(_aiquotas_last_status)
    fi

    if [[ -z "$body" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"zai",source:"official",
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
             provider_outcomes:[{provider:"zai",source:$src,
                                 status:$st, error:$er}]}
            '
        return 0
    fi

    # HTTP 200 but envelope-level failure (real curl has no status capture, so
    # the Z.ai envelope is the authoritative error signal in production).
    if [[ "$(jq -r 'if (.success == false) or ((.code // 0) >= 400) then "true" else "false" end' <<<"$body" 2>/dev/null)" == "true" ]]; then
        local env_code env_msg env_status
        env_code=$(jq -r '.code // 0' <<<"$body" 2>/dev/null)
        env_msg=$(jq -r '.msg // .error.message // "Z.ai API reported an error"' <<<"$body" 2>/dev/null)
        case "$env_code" in
        401 | 403) env_status="unauthorized" ;;
        429) env_status="rate_limited" ;;
        *) env_status="unavailable" ;;
        esac
        jq -nc \
            --arg st "$env_status" \
            --arg er "$env_msg" \
            --arg src "official" \
            '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"zai",source:$src,
                                 status:$st, error:$er}]}
            '
        return 0
    fi

    if ! _aiquotas_metrics_document "zai" "$body" 2>/dev/null; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"zai",source:"official",
                                 status:"malformed",
                                 error:"quota payload normalization failed"}]}
        '
        return 0
    fi
}
