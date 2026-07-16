#!/usr/bin/env bash
# =============================================================================
# aiquotas adapter — deepseek
# Plan: .omo/plans/aiquotas-refactor.md
# =============================================================================
# Companion adapter for the aiquotas plugin. Provides _aiquotas_collect_deepseek
# which emits a canonical metrics document for the DeepSeek official endpoint.
#
# Loaded lazily by _aiquotas_load_provider in the entry point. NEVER source this
# file directly — go through the loader.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_deepseek" && return 0

# -----------------------------------------------------------------------------
# DeepSeek adapter (Todo 3)
# -----------------------------------------------------------------------------
#
# Reads the DeepSeek user balance endpoint and emits one monetary_balance
# record per currency in balance_infos[]. The plan forbids aggregation across
# currencies; this adapter preserves each entry verbatim. Treats the data
# as `official` ONLY when DEEPSEEK_API_KEY is set.
#
#   * URL:    GET {deepseek_balance_url} (default: https://api.deepseek.com/user/balance)
#   * Header: Authorization: Bearer <DEEPSEEK_API_KEY>
#   * Errors: unconfigured|unauthorized|rate_limited|unavailable|malformed
#
# Returns the canonical JSON document on stdout. Exits 0 even on partial
# failure (the document's provider_outcomes entry carries the error);
# exits non-zero only when jq cannot assemble the envelope at all.
#
_aiquotas_collect_deepseek() {
    local key="${DEEPSEEK_API_KEY:-}"

    if [[ -z "$key" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"deepseek",source:"official",
                                 status:"unconfigured",
                                 error:"DEEPSEEK_API_KEY not set"}]}
        '
        return 0
    fi

    local url timeout body status
    url=$(get_option "deepseek_balance_url")
    timeout=$(get_option "timeout")
    timeout="${timeout:-5}"

    if [[ -z "$url" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"deepseek",source:"official",
                                 status:"unconfigured",
                                 error:"deepseek balance URL not configured"}]}
        '
        return 0
    fi

    body=$(_aiquotas_http_get_meta \
        "$url" "$timeout" \
        -H "Authorization: Bearer $key" \
        -H "Accept: application/json") || {
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"deepseek",source:"official",
                                 status:"unavailable",
                                 error:"balance fetch transport failure"}]}
        '
        return 0
    }

    status=$(_aiquotas_last_status)
    if [[ "$status" != 2* ]]; then
        local canonical_status canonical_error
        canonical_status=$(_aiquotas_http_status_to_canonical "$status")
        canonical_error=$(_aiquotas_http_status_error_message "$body" "balance")
        jq -nc \
            --arg st "$canonical_status" \
            --arg er "$canonical_error" \
            --arg src "official" \
            '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"deepseek",source:$src,
                                 status:$st, error:$er}]}
            '
        return 0
    fi

    if ! _aiquotas_metrics_document "deepseek" "$body" 2>/dev/null; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"deepseek",source:"official",
                                 status:"malformed",
                                 error:"balance payload normalization failed"}]}
        '
        return 0
    fi
}
