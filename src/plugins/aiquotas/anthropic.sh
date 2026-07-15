#!/usr/bin/env bash
# =============================================================================
# aiquotas adapter — anthropic
# Plan: .omo/plans/aiquotas-refactor.md
# =============================================================================
# Companion adapter for the aiquotas plugin. Provides _aiquotas_collect_anthropic
# which emits a canonical metrics document for the Anthropic official endpoint.
#
# Loaded lazily by _aiquotas_load_provider in the entry point. NEVER source this
# file directly — go through the loader.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_anthropic" && return 0

# -----------------------------------------------------------------------------
# Anthropic adapter
# -----------------------------------------------------------------------------
#
# Collects token usage (paginated) and cost (cents -> monetary) from the
# official Anthropic Admin API. Sources:
#   * Usage:  GET {anthropic_usage_url}?starting_at=...&ending_at=...&bucket_width=...
#             Authorization headers: x-api-key + anthropic-version
#   * Cost:   GET {anthropic_cost_url}?starting_at=...&ending_at=...&bucket_width=...
#
# Returns the canonical JSON document on stdout. Exits 0 even on partial
# failure (document carries a provider_outcomes entry with the error);
# exits non-zero only when jq cannot assemble a valid envelope.

_aiquotas_collect_anthropic() {
    local key="${ANTHROPIC_ADMIN_KEY:-${ANTHROPIC_API_KEY:-}}"

    if [[ -z "$key" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"anthropic",source:"official",
                                  status:"unconfigured",
                                  error:"ANTHROPIC_ADMIN_KEY not set"}]}
        '
        return 0
    fi

    local usage_base cost_base timeout window bucket max_pages
    usage_base=$(get_option "anthropic_usage_url")
    cost_base=$(get_option "anthropic_cost_url")
    timeout=$(get_option "timeout")
    window=$(get_option "report_window_days")
    bucket=$(get_option "usage_bucket_width")
    max_pages=$(get_option "max_pages")

    if [[ -z "$usage_base" || -z "$cost_base" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"anthropic",source:"official",
                                  status:"unconfigured",
                                  error:"anthropic usage/cost URL not configured"}]}
        '
        return 0
    fi

    timeout="${timeout:-5}"
    window="${window:-1}"
    window="${window//[^0-9]/}"
    [[ -z "$window" || "$window" -lt 1 ]] && window=1
    bucket="${bucket:-1d}"
    max_pages="${max_pages:-100}"
    max_pages="${max_pages//[^0-9]/}"
    [[ -z "$max_pages" || "$max_pages" -lt 1 ]] && max_pages=1

    # Filter CSVs (sent only when non-empty).
    local group_by models workspaces api_keys
    group_by=$(get_option "anthropic_group_by")
    models=$(get_option "anthropic_models")
    workspaces=$(get_option "anthropic_workspace_ids")
    api_keys=$(get_option "anthropic_api_key_ids")

    local iso_start iso_end
    iso_start=$(_aiquotas_iso_start "$window")
    iso_end=$(_aiquotas_iso_end)

    # Build the usage URL with stable param ordering; cursor appended later.
    local usage_url="${usage_base}?starting_at=${iso_start}&ending_at=${iso_end}&bucket_width=${bucket}"
    if [[ -n "$models" ]]; then usage_url+="&models%5B%5D=${models//,/+}"; fi
    if [[ -n "$workspaces" ]]; then usage_url+="&workspace_ids%5B%5D=${workspaces//,/+}"; fi
    if [[ -n "$api_keys" ]]; then usage_url+="&api_key_ids%5B%5D=${api_keys//,/+}"; fi
    if [[ -n "$group_by" ]]; then usage_url+="&group_by%5B%5D=${group_by//,/+}"; fi

    local cost_url="${cost_base}?starting_at=${iso_start}&ending_at=${iso_end}&bucket_width=${bucket}"

    # ---- USAGE endpoint (paginated via has_more / next_page) ----
    local usage_status="ok"
    local usage_error=""
    local usage_records_json='[]'
    local cursor=""
    local page_count=0
    while ((page_count < max_pages)); do
        local page_url="$usage_url"
        [[ -n "$cursor" ]] && page_url="${page_url}&page=${cursor}"

        local body status
        body=$(_aiquotas_http_get_meta \
            "$page_url" "$timeout" \
            -H "x-api-key: $key" \
            -H "anthropic-version: 2023-06-01" \
            -H "Accept: application/json") || {
            usage_status="unavailable"
            usage_error="usage fetch transport failure"
            break
        }
        status=$(_aiquotas_last_status)
        if [[ "$status" != 2* ]]; then
            usage_status=$(_aiquotas_http_status_to_canonical "$status")
            usage_error=$(_aiquotas_http_status_error_message "$body" "usage")
            break
        fi

        # Parse the page into token_usage records; concat across pages.
        local page_records
        page_records=$(jq -c --arg ws "$iso_start" --arg we "$iso_end" '
            [
                (.data // [])[]
                | (.results // []) as $results |
                $results[] |
                {
                    metric_kind: "token_usage",
                    value: (if (.input_tokens // null) != null
                            then ((.input_tokens // 0)
                                + (.output_tokens // 0)
                                + (.cache_creation_input_tokens // 0)
                                + (.cache_read_input_tokens // 0))
                            else null end),
                    limit: null,
                    remaining: null,
                    unit: "token",
                    currency: null,
                    window_start: ($ws // null),
                    window_end: ($we // null),
                    reset_at: null,
                    source: "official",
                    status: "ok",
                    error: null,
                    dimensions: {model: (.model // null),
                         input_tokens: (.input_tokens // null),
                         cached_input_tokens: (.cache_read_input_tokens // null),
                         cache_creation_tokens: (.cache_creation_input_tokens // null),
                         output_tokens: (.output_tokens // null),
                         requests: (.requests // null),
                         project: null,
                         line_item: null,
                         resource: null}
                }
            ]
        ' <<<"$body" 2>/dev/null) || page_records="[]"

        usage_records_json=$(jq -c --argjson base "$usage_records_json" --argjson page "$page_records" \
            '$base + $page' <<<"null")

        local has_more next_page
        has_more=$(jq -r '.has_more // false' <<<"$body" 2>/dev/null)
        next_page=$(jq -r '.next_page // ""' <<<"$body" 2>/dev/null)
        if [[ "$has_more" != "true" || -z "$next_page" ]]; then
            break
        fi
        cursor="$next_page"
        page_count=$((page_count + 1))
    done

    # ---- COST endpoint ----
    local cost_status="ok"
    local cost_error=""
    local cost_records_json='[]'
    local cost_body
    cost_body=$(_aiquotas_http_get_meta \
        "$cost_url" "$timeout" \
        -H "x-api-key: $key" \
        -H "anthropic-version: 2023-06-01" \
        -H "Accept: application/json") || {
        cost_status="unavailable"
        cost_error="cost fetch transport failure"
        cost_body=""
    }
    if [[ -n "$cost_body" ]]; then
        local cstatus
        cstatus=$(_aiquotas_last_status)
        if [[ "$cstatus" != 2* ]]; then
            cost_status=$(_aiquotas_http_status_to_canonical "$cstatus")
            cost_error=$(_aiquotas_http_status_error_message "$cost_body" "cost")
        else
            cost_records_json=$(jq -c --arg ws "$iso_start" --arg we "$iso_end" '
                [
                    (.data // [])[]
                    | (.results // []) as $results |
                    $results[] |
                    # Anthropic cost `amount` is in cents (string). Convert
                    # deterministically to the monetary unit preserving currency.
                    (try ( (.amount | tonumber) / 100 )
                      catch null) as $amount_decimal |
                    {
                        metric_kind: "monetary_spend",
                        value: ($amount_decimal // null),
                        limit: null,
                        remaining: null,
                        unit: "currency",
                        currency: (.currency // null),
                        window_start: $ws,
                        window_end: $we,
                        reset_at: null,
                        source: "official",
                        status: "ok",
                        error: null,
                        dimensions: {model: (.model // null),
                             input_tokens: null, cached_input_tokens: null,
                             cache_creation_tokens: null, output_tokens: null,
                             requests: null, project: null, line_item: null,
                             resource: null}
                    }
                ]
            ' <<<"$cost_body" 2>/dev/null) || cost_records_json="[]"
        fi
    fi

    # Aggregate outcome. USAGE is the primary signal: when it surfaces a
    # specific failure (unauthorized, rate_limited, malformed) the provider
    # status MUST reflect that, even if COST also failed with a less
    # specific status (e.g. transport unavailable). Errors are concatenated
    # so callers see the full picture.
    local final_status="$usage_status"
    local final_error="$usage_error"
    if [[ "$cost_status" != "ok" ]]; then
        if [[ "$final_status" == "ok" ]]; then
            final_status="$cost_status"
            final_error="$cost_error"
        else
            final_error="${final_error:+$final_error; }$cost_error"
        fi
    fi

    jq -nc \
        --arg src "official" \
        --arg st "$final_status" \
        --arg er "${final_error:-}" \
        --argjson recs "$(jq -nc --argjson a "$usage_records_json" --argjson b "$cost_records_json" '$a + $b')" \
        '
        {
            schema_version: 1,
            records: $recs,
            provider_outcomes: [
                {
                    provider: "anthropic",
                    source:   $src,
                    status:   $st,
                    error:    (if $er == "" then null else $er end)
                }
            ]
        }
        '
}
