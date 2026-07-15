#!/usr/bin/env bash
# =============================================================================
# aiquotas adapter — xiaomi_mimo
# Plan: .omo/plans/aiquotas-refactor.md
# =============================================================================
# Companion adapter for the aiquotas plugin. Provides _aiquotas_collect_xiaomi_mimo
# which emits a canonical metrics document for the Xiaomi MiMo endpoint.
#
# Loaded lazily by _aiquotas_load_provider in the entry point. NEVER source this
# file directly — go through the loader.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_xiaomi_mimo" && return 0

# -----------------------------------------------------------------------------
# Xiaomi MiMo adapter
# -----------------------------------------------------------------------------
#
# MiMo platform.xiaomimimo.com has a usage API at
# /api/v1/tokenPlan/usage that requires browser session cookies
# (api-platform_serviceToken, userId, api-platform_ph, api-platform_slh).
#
# Authentication methods:
#   1. Session cookies via MIMO_SESSION_COOKIES env var (recommended)
#   2. API key via MIMO_API_KEY env var (for private adapters/proxies)
#
# Default endpoint: https://platform.xiaomimimo.com/api/v1/tokenPlan/usage
#
# Response format:
#   {code:0, data:{monthUsage:{items:[{name,used,limit,percent}]},
#                  usage:{items:[{name,used,limit,percent}]}}}
#
# Path matrix:
#   * no credentials + no URL       -> status=unsupported, exit 0, NO HTTP
#   * URL set + valid body          -> status=ok, source=configured
#   * HTTP 401/403/429              -> respective status, exit 0
#   * HTTP transport failure        -> status=unavailable, exit 0
#
_aiquotas_collect_xiaomi_mimo() {
    local cookies="${MIMO_SESSION_COOKIES:-}"
    local key="${MIMO_API_KEY:-${XIAOMI_MIMO_API_KEY:-}}"
    local url timeout body status

    # Default URL for the platform API
    url=$(get_option "xiaomi_mimo_usage_url")
    [[ -z "$url" ]] && url="https://platform.xiaomimimo.com/api/v1/tokenPlan/usage"

    # Try to load cookies from config file if not set via env
    if [[ -z "$cookies" && -z "$key" ]]; then
        local config_file="${POWERKIT_ROOT}/config/mimo_cookies.env"
        if [[ -f "$config_file" ]]; then
            source "$config_file"
            cookies="${MIMO_SESSION_COOKIES:-}"
            # Export for child processes
            [[ -n "$cookies" ]] && export MIMO_SESSION_COOKIES="$cookies"
        fi
    fi

    # No credentials at all => unsupported, NO HTTP call
    if [[ -z "$cookies" && -z "$key" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"xiaomi_mimo",source:"configured",
                                 status:"unsupported",
                                 error:"no credentials configured (set MIMO_SESSION_COOKIES or MIMO_API_KEY)"}]}
        '
        return 0
    fi

    timeout=$(get_option "timeout")
    timeout="${timeout:-5}"

    # Build curl args based on auth method
    local -a curl_args=()
    if [[ -n "$cookies" ]]; then
        # Session cookie authentication
        curl_args+=(-H "Cookie: $cookies")
    elif [[ -n "$key" ]]; then
        # Bearer token authentication (for private adapters)
        curl_args+=(-H "Authorization: Bearer $key")
    fi

    body=$(_aiquotas_http_get_meta \
        "$url" "$timeout" \
        "${curl_args[@]}" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "x-timeZone: $(date +%Z 2>/dev/null || echo "UTC")") || {
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"xiaomi_mimo",source:"configured",
                                 status:"unavailable",
                                 error:"usage fetch transport failure"}]}
        '
        return 0
    }

    status=$(_aiquotas_last_status)
    if [[ "$status" != 2* ]]; then
        local canonical_status canonical_error
        canonical_status=$(_aiquotas_http_status_to_canonical "$status")
        canonical_error=$(_aiquotas_http_status_error_message "$body" "usage")
        jq -nc \
            --arg st "$canonical_status" \
            --arg er "$canonical_error" \
            --arg src "configured" \
            '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"xiaomi_mimo",source:$src,
                                 status:$st, error:$er}]}
            '
        return 0
    fi

    # Use configured schema if provided, else use official MiMo parser
    local schema rc doc
    schema=$(get_option "xiaomi_mimo_schema")
    if [[ -n "$schema" ]]; then
        if doc=$(_aiquotas_metrics_document "xiaomi_mimo" "$body" "$schema" 2>/dev/null); then
            echo "$doc"
            return 0
        fi
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"xiaomi_mimo",source:"configured",
                                  status:"malformed",
                                  error:"invalid configured schema"}]}
        '
        return 1
    else
        _aiquotas_normalize_mimo_response "$body"
        rc=$?
        return $rc
    fi
}

# Normalize MiMo platform API response to canonical metrics document
_aiquotas_normalize_mimo_response() {
    local body="$1"

    # Extract plan_total_token from usage.items using jq directly
    # The response has: data.usage.items[] where name="plan_total_token"
    local plan_item
    plan_item=$(jq -c '
        .data.usage.items // [] |
        map(select(.name == "plan_total_token")) |
        .[0] // empty
    ' <<<"$body" 2>/dev/null)

    if [[ -z "$plan_item" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"xiaomi_mimo",source:"configured",
                                 status:"malformed",
                                 error:"response missing plan_total_token"}]}
        '
        return 1
    fi

    # Extract values
    local used limit percent
    used=$(jq -r '.used // 0' <<<"$plan_item" 2>/dev/null)
    limit=$(jq -r '.limit // 0' <<<"$plan_item" 2>/dev/null)
    percent=$(jq -r '.percent // 0' <<<"$plan_item" 2>/dev/null)

    # Build canonical document
    jq -nc \
        --argjson used "${used:-0}" \
        --argjson limit "${limit:-0}" \
        --argjson percent "${percent:-0}" \
        '
        {
            schema_version: 1,
            records: [{
                provider: "xiaomi_mimo",
                metric_kind: "token_quota",
                value: $used,
                limit: $limit,
                remaining: ($limit - $used),
                unit: "token",
                currency: null,
                window_start: null,
                window_end: null,
                reset_at: null,
                source: "configured",
                status: "ok",
                error: null,
                dimensions: {
                    input_tokens: null,
                    cached_input_tokens: null,
                    cache_creation_tokens: null,
                    output_tokens: null,
                    requests: null,
                    model: null,
                    project: null,
                    line_item: null,
                    resource: "token_plan"
                }
            }],
            provider_outcomes: [{
                provider: "xiaomi_mimo",
                source: "configured",
                status: "ok",
                error: null
            }]
        }
    '
}
