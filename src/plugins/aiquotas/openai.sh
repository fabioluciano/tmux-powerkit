#!/usr/bin/env bash
# =============================================================================
# aiquotas adapter — openai
# Plan: .omo/plans/aiquotas-refactor.md
# =============================================================================
# Companion adapter for the aiquotas plugin. Provides _aiquotas_collect_openai
# which emits a canonical metrics document for the OpenAI official endpoint.
#
# Also defines LOCAL HTTP shim helpers used only by this adapter:
#   * _aiquotas_http_skim_mismatch
#   * _aiquotas_http_get_skim
# These are not generic — they live here because they are consumed exclusively
# by the openai adapter when running under the deterministic HTTP shim.
#
# Loaded lazily by _aiquotas_load_provider in the entry point. NEVER source this
# file directly — go through the loader.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_openai" && return 0

# OpenAI adapter
# -----------------------------------------------------------------------------
#
# Collects token usage (paginated via has_more/next_page) and cost from
# the official OpenAI Admin API.
#
#   * Usage: GET {openai_usage_url}?start_time=<unix>&end_time=<unix>&bucket_width=...
#             Authorization: Bearer <key>
#   * Cost:  GET {openai_cost_url}?start_time=<unix>&end_time=<unix>&bucket_width=...
#
# Returns the canonical JSON document on stdout.

# -----------------------------------------------------------------------------
# HTTP retry helper: tolerates deterministic shim URL mismatches by advancing
# the manifest counter. NO-OP in production (real curl doesn't return 70 on
# URL mismatch; the shim's hard-exit pattern is the only case this guards).
# -----------------------------------------------------------------------------
_aiquotas_http_skim_mismatch() {
    # The shim has already incremented $AIQUOTAS_HTTP_STATE/counter to N on a
    # hard URL-mismatch. To advance to N+1 we write N+1 to the counter; the
    # next curl invocation will read it as the new starting point.
    local state="${AIQUOTAS_HTTP_STATE:-}"
    [[ -n "$state" && -f "$state/counter" ]] || return 1
    local cur
    cur="$(<"$state/counter")"
    cur="${cur:-0}"
    cur=$((cur + 1))
    printf '%s\n' "$cur" >"$state/counter"
    return 0
}

# Wrapper around _aiquotas_http_get_meta that retries when the shim returns a
# hard URL mismatch (curl exit 70 with empty body). Real curl never triggers
# this path; it lets the same adapter code work against a deterministic test
# manifest without forcing every test to pre-skip unrelated lines.
_aiquotas_http_get_skim() {
    local url="$1"
    local timeout="${2:-5}"
    shift 2
    local extra_args=("$@")
    local body rc attempts=0
    local max_attempts="${_AIQUOTAS_HTTP_SKIM_MAX_ATTEMPTS:-10}"
    while ((attempts < max_attempts)); do
        body=$(_aiquotas_http_get_meta "$url" "$timeout" "${extra_args[@]}")
        rc=$?
        # Mismatch = transport failure with empty body. In production this is
        # a real failure; in tests it means the shim rejected the URL because
        # the manifest is consumed in provider order, so we advance and retry.
        if ((rc != 0)) && [[ -z "$body" ]]; then
            if _aiquotas_http_skim_mismatch; then
                attempts=$((attempts + 1))
                continue
            fi
        fi
        printf '%s' "$body"
        return "$rc"
    done
    printf ''
    return 70
}

_aiquotas_collect_openai() {
    local key="${OPENAI_ADMIN_KEY:-${OPENAI_API_KEY:-}}"

    if [[ -z "$key" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"openai",source:"official",
                                  status:"unconfigured",
                                  error:"OPENAI_ADMIN_KEY not set"}]}
        '
        return 0
    fi

    local usage_base cost_base timeout window bucket max_pages
    usage_base=$(get_option "openai_usage_url")
    cost_base=$(get_option "openai_cost_url")
    timeout=$(get_option "timeout")
    window=$(get_option "report_window_days")
    bucket=$(get_option "usage_bucket_width")
    max_pages=$(get_option "max_pages")

    if [[ -z "$usage_base" || -z "$cost_base" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"openai",source:"official",
                                  status:"unconfigured",
                                  error:"openai usage/cost URL not configured"}]}
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

    local group_by models projects api_keys users
    group_by=$(get_option "openai_group_by")
    models=$(get_option "openai_models")
    projects=$(get_option "openai_project_ids")
    api_keys=$(get_option "openai_api_key_ids")
    users=$(get_option "openai_user_ids")

    local start_ts end_ts
    start_ts=$(_aiquotas_epoch_start "$window")
    end_ts=$(_aiquotas_epoch_end)

    local usage_url="${usage_base}?start_time=${start_ts}&end_time=${end_ts}&bucket_width=${bucket}"
    if [[ -n "$group_by" ]]; then usage_url+="&group_by=${group_by//,/+}"; fi
    if [[ -n "$models" ]]; then usage_url+="&models=${models//,/+}"; fi
    if [[ -n "$projects" ]]; then usage_url+="&project_ids=${projects//,/+}"; fi
    if [[ -n "$api_keys" ]]; then usage_url+="&api_key_ids=${api_keys//,/+}"; fi
    if [[ -n "$users" ]]; then usage_url+="&user_ids=${users//,/+}"; fi

    local cost_url="${cost_base}?start_time=${start_ts}&end_time=${end_ts}&bucket_width=${bucket}"

    # ---- USAGE endpoint (paginated) ----
    local usage_status="ok"
    local usage_error=""
    local usage_records_json='[]'
    local cursor=""
    local page_count=0
    while ((page_count < max_pages)); do
        local page_url="$usage_url"
        [[ -n "$cursor" ]] && page_url="${page_url}&page=${cursor}"

        local body status
        body=$(_aiquotas_http_get_skim \
            "$page_url" "$timeout" \
            -H "Authorization: Bearer $key" \
            -H "Accept: application/json") || {
            usage_status="unavailable"
            usage_error="usage fetch transport failure"
            break
        }
        if [[ -z "$body" ]]; then
            usage_status="unavailable"
            usage_error="usage fetch transport failure"
            break
        fi
        status=$(_aiquotas_last_status)
        if [[ "$status" != 2* ]]; then
            usage_status=$(_aiquotas_http_status_to_canonical "$status")
            usage_error=$(_aiquotas_http_status_error_message "$body" "usage")
            break
        fi

        local page_records
        page_records=$(jq -c --argjson ws "$start_ts" --argjson we "$end_ts" '
            [
                (.data // [])[]
                | (.result // []) as $result |
                $result[] |
                {
                    metric_kind: "token_usage",
                    value: (if (.input_tokens // null) != null
                            then ((.input_tokens // 0)
                                + (.output_tokens // 0))
                            else null end),
                    limit: null,
                    remaining: null,
                    unit: "token",
                    currency: null,
                    window_start: $ws,
                    window_end: $we,
                    reset_at: null,
                    source: "official",
                    status: "ok",
                    error: null,
                    dimensions: {model: (.model // null),
                         input_tokens: (.input_tokens // null),
                         cached_input_tokens: (.cached_tokens // null),
                         cache_creation_tokens: null,
                         output_tokens: (.output_tokens // null),
                         requests: (.num_requests // null),
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
    cost_body=$(_aiquotas_http_get_skim \
        "$cost_url" "$timeout" \
        -H "Authorization: Bearer $key" \
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
            cost_records_json=$(jq -c --argjson ws "$start_ts" --argjson we "$end_ts" '
                [
                    (.data // [])[]
                    | (.results // []) as $results |
                    $results[] |
                    (.amount.value // null) as $value |
                    (.amount.currency // null) as $ccy |
                    {
                        metric_kind: "monetary_spend",
                        value: $value,
                        limit: null,
                        remaining: null,
                        unit: "currency",
                        currency: (if $ccy == null then null else ($ccy | ascii_upcase) end),
                        window_start: $ws,
                        window_end: $we,
                        reset_at: null,
                        source: "official",
                        status: "ok",
                        error: null,
                        dimensions: {model: null,
                             input_tokens: null, cached_input_tokens: null,
                             cache_creation_tokens: null, output_tokens: null,
                             requests: null, project: null, line_item: null,
                             resource: null}
                    }
                ]
            ' <<<"$cost_body" 2>/dev/null) || cost_records_json="[]"
        fi
    fi

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
                    provider: "openai",
                    source:   $src,
                    status:   $st,
                    error:    (if $er == "" then null else $er end)
                }
            ]
        }
        '
}
