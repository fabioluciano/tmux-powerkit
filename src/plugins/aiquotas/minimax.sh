#!/usr/bin/env bash
# =============================================================================
# aiquotas adapter — minimax
# Plan: .omo/plans/aiquotas-refactor.md
# =============================================================================
# Companion adapter for the aiquotas plugin. Provides _aiquotas_collect_minimax
# which emits a canonical metrics document for the MiniMax official endpoint.
#
# Loaded lazily by _aiquotas_load_provider in the entry point. NEVER source this
# file directly — go through the loader.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_minimax" && return 0

# -----------------------------------------------------------------------------
# MiniMax adapter (Todo 3)
# -----------------------------------------------------------------------------
#
# Reads the official MiniMax Token Plan endpoint and emits one `quota` record
# per model in model_remains[]. Each record:
#   * unit = "count" (NEVER "token" - MiniMax counts requests, not tokens)
#   * value = current_interval_usage_count
#   * limit = current_interval_total_count
#   * remaining = (current_interval_remaining_percent / 100 * current_interval_total_count)
#                when API provides remaining_percent; falls back to (limit - value) otherwise.
#   * source = "official"
#
#   * URL:    GET {minimax_usage_url} (default: https://api.minimax.io/v1/token_plan/remains)
#   * Header: Authorization: Bearer <MINIMAX_API_KEY>
#
_aiquotas_collect_minimax() {
    local key="${MINIMAX_API_KEY:-}"

    if [[ -z "$key" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"minimax",source:"official",
                                 status:"unconfigured",
                                 error:"MINIMAX_API_KEY not set"}]}
        '
        return 0
    fi

    local url timeout body status
    url=$(get_option "minimax_usage_url")
    timeout=$(get_option "timeout")
    timeout="${timeout:-5}"

    if [[ -z "$url" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"minimax",source:"official",
                                 status:"unconfigured",
                                 error:"minimax usage URL not configured"}]}
        '
        return 0
    fi

    body=$(_aiquotas_http_get_meta \
        "$url" "$timeout" \
        -H "Authorization: Bearer $key" \
        -H "Accept: application/json") || {
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"minimax",source:"official",
                                 status:"unavailable",
                                 error:"token plan fetch transport failure"}]}
        '
        return 0
    }

    status=$(_aiquotas_last_status)
    if [[ "$status" != 2* ]]; then
        local canonical_status canonical_error
        canonical_status=$(_aiquotas_http_status_to_canonical "$status")
        canonical_error=$(_aiquotas_http_status_error_message "$body" "token_plan")
        jq -nc \
            --arg st "$canonical_status" \
            --arg er "$canonical_error" \
            --arg src "official" \
            '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"minimax",source:$src,
                                 status:$st, error:$er}]}
            '
        return 0
    fi

    if ! _aiquotas_metrics_document "minimax" "$body" 2>/dev/null; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"minimax",source:"official",
                                 status:"malformed",
                                 error:"token plan payload normalization failed"}]}
        '
        return 0
    fi
}
