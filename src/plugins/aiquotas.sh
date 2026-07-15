#!/usr/bin/env bash
# =============================================================================
# Plugin: aiquotas
# Description: Canonical metrics document for AI provider usage.
#   Adheres to the v4 contract in .omo/plans/aiquotas-completo.md (Todo 1).
#
# Contract highlights (see plan v4):
#   * Document: {"schema_version":1, "records":[...], "provider_outcomes":[...]}
#   * metric_kind  : token_usage|token_quota|quota|monetary_balance|monetary_spend|rate_limit
#   * unit         : token|request|count|percent|currency  (singular "token", never "tokens")
#   * source       : official|configured
#   * status       : ok|unconfigured|unsupported|unauthorized|rate_limited|unavailable|malformed|stale
#   * dimensions   : MUST contain all 9 keys
#                    (input_tokens, cached_input_tokens, cache_creation_tokens,
#                     output_tokens, requests, model, project, line_item, resource)
#                    even when the value is null.
#   * monetary_*   : requires unit=currency, ISO-4217 currency, limit/remaining=null.
#   * quota        : limit>0, 0<=value<=limit, remaining=limit-value.
#   * MiniMax      : metric_kind=quota, unit=count,
#                    remaining=total_count-usage_count (subtraction, not direct).
#   * MiMo         : empty URL by default; requires configured schema CSV (json_path=field)
#                    validated against the canonical field names. With neither, returns
#                    a document with status=unsupported.
#
# Layout (Todo 6):
#   * this file  — entry point (contract + loader + collect/render dispatcher)
#   * _http.sh    — HTTP compatibility seams + status/error helpers
#   * _metrics.sh — _aiquotas_metrics_document (canonical jq document builder)
#   * _render.sh  — record→text render helpers (compact / detailed)
#   * _health.sh  — _aiquotas_worst_health / _aiquotas_threshold_health
#   * <provider>.sh — per-adapter files (anthropic, openai, deepseek, minimax, xiaomi_mimo)
#
# HTTP collection uses _aiquotas_http_get, a single seam that can be intercepted
# by an HTTP shim in tests/helpers/shims/curl (Todo 2) without modifying this file.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Provider metadata
# =============================================================================

# Display labels per provider (used by plugin_render when summarising records)
declare -gA AIQUOTAS_LABELS=(
    [anthropic]="Claude"
    [openai]="OpenAI"
    [deepseek]="DeepSeek"
    [minimax]="MiniMax"
    [zai]="zai"
)

# Default URLs per provider endpoint. URL can be overridden via plugin options.
# Keeping these centralised simplifies the URL-override tests and avoids
# coupling endpoint knowledge into multiple helpers.
#
declare -gA AIQUOTAS_DEFAULT_URLS=(
    [anthropic_usage]="https://api.anthropic.com/v1/organizations/usage_report/messages"
    [anthropic_cost]="https://api.anthropic.com/v1/organizations/cost_report"
    [openai_usage]="https://api.openai.com/v1/organization/usage/completions"
    [openai_cost]="https://api.openai.com/v1/organization/costs"
    [deepseek_balance]="https://api.deepseek.com/user/balance"
    [minimax_usage]="https://api.minimax.io/v1/token_plan/remains"
    [zai_quota]="https://api.z.ai/api/monitor/usage/quota/limit"
)

# =============================================================================
# Shared modules (eager source)
# =============================================================================
# Each module owns a focused concern and is loaded eagerly because the BATS
# suite invokes _aiquotas_metrics_document / _aiquotas_http_get directly after
# sourcing the entry point (no provider is loaded yet). source_guard inside
# each module makes repeated sourcing a no-op.

# Generic utilities provide reusable HTTP fetch and time-window helpers.
# shellcheck source=src/utils/api.sh
. "${POWERKIT_ROOT}/src/utils/api.sh"
# shellcheck source=src/utils/time.sh
. "${POWERKIT_ROOT}/src/utils/time.sh"
# shellcheck source=src/plugins/aiquotas/_http.sh
. "${POWERKIT_ROOT}/src/plugins/aiquotas/_http.sh"

# Backward-compat aliases re-exported for plugin internal use.
_aiquotas_iso_start() { time_iso_start "$@"; }
_aiquotas_iso_end() { time_iso_now; }
_aiquotas_epoch_start() { time_epoch_start "$@"; }
_aiquotas_epoch_end() { time_epoch_now; }

# shellcheck source=src/plugins/aiquotas/_metrics.sh
. "${POWERKIT_ROOT}/src/plugins/aiquotas/_metrics.sh"
# shellcheck source=src/plugins/aiquotas/_render.sh
. "${POWERKIT_ROOT}/src/plugins/aiquotas/_render.sh"
# shellcheck source=src/plugins/aiquotas/_health.sh
. "${POWERKIT_ROOT}/src/plugins/aiquotas/_health.sh"

# =============================================================================
# Provider loader (lazy source)
# =============================================================================
# Each provider lives in src/plugins/aiquotas/<name>.sh and defines
# _aiquotas_collect_<name> plus its own local helpers. Sourcing is deferred
# until the dispatcher actually needs a provider so that the entry point
# stays small and the per-provider code only loads when used.

_AIQUOTAS_PROVIDERS_LOADED=""

_aiquotas_load_provider() {
    # Source the provider adapter file on demand. Idempotent within a shell:
    # repeated calls for the same provider are a no-op.
    local provider="$1"
    local file="${POWERKIT_ROOT}/src/plugins/aiquotas/${provider}.sh"

    # Idempotency guard: skip if already loaded in this shell.
    [[ ",${_AIQUOTAS_PROVIDERS_LOADED}," == *",${provider},"* ]] && return 0

    [[ -f "$file" ]] || {
        printf 'ERROR: aiquotas provider file missing: %s\n' "$file" >&2
        return 1
    }

    # shellcheck source=/dev/null
    . "$file"
    _AIQUOTAS_PROVIDERS_LOADED="${_AIQUOTAS_PROVIDERS_LOADED:+${_AIQUOTAS_PROVIDERS_LOADED},}${provider}"
}

_aiquotas_load_all_providers() {
    # Convenience helper that pre-loads every known provider. Currently unused
    # by the dispatcher (which loads lazily), but exposed for tools/tests that
    # want all adapters available without dispatching first.
    _aiquotas_load_provider anthropic
    _aiquotas_load_provider openai
    _aiquotas_load_provider deepseek
    _aiquotas_load_provider minimax
    _aiquotas_load_provider zai
}

# =============================================================================
# Plugin metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "aiquotas"
    metadata_set "name" "AI Quotas"
    metadata_set "description" "Display AI provider token and billing usage"
}

# =============================================================================
# Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "jq" || return 1
    return 0
}

# =============================================================================
# Options
# =============================================================================

plugin_declare_options() {
    # Plugin-wide
    declare_option "providers" "string" "anthropic,openai,deepseek,minimax" "Comma-separated providers"
    declare_option "separator" "string" " | " "Separator between providers"
    declare_option "timeout" "number" "5" "HTTP timeout in seconds"
    declare_option "format" "enum" "compact" "Output format: compact or detailed"
    declare_option "show_percent" "enum" "left" "Show percentage in render: both|left"
    declare_option "show_x_of_y" "bool" "false" "Show raw X/Y values alongside percentages (true|false)"
    declare_option "show_video" "bool" "false" "Show MiniMax video bonus in render (MiniMax only)"
    declare_option "min_limit" "number" "1" "Skip quota records with limit < N (0 disables filter)"
    declare_option "warning_threshold" "number" "80" "Warning threshold for quota percentage"
    declare_option "critical_threshold" "number" "95" "Critical threshold for quota percentage"

    # Anthropic
    declare_option "anthropic_usage_url" "string" "${AIQUOTAS_DEFAULT_URLS[anthropic_usage]}" "Anthropic usage endpoint"
    declare_option "anthropic_cost_url" "string" "${AIQUOTAS_DEFAULT_URLS[anthropic_cost]}" "Anthropic cost endpoint"
    declare_option "anthropic_group_by" "string" "" "Anthropic group_by CSV (only sent when non-empty)"
    declare_option "anthropic_models" "string" "" "Anthropic models filter CSV (only sent when non-empty)"
    declare_option "anthropic_workspace_ids" "string" "" "Anthropic workspace IDs filter CSV (only sent when non-empty)"
    declare_option "anthropic_api_key_ids" "string" "" "Anthropic API key IDs filter CSV (only sent when non-empty)"

    # OpenAI
    declare_option "openai_usage_url" "string" "${AIQUOTAS_DEFAULT_URLS[openai_usage]}" "OpenAI usage endpoint"
    declare_option "openai_cost_url" "string" "${AIQUOTAS_DEFAULT_URLS[openai_cost]}" "OpenAI cost endpoint"
    declare_option "openai_group_by" "string" "" "OpenAI group_by CSV (only sent when non-empty)"
    declare_option "openai_models" "string" "" "OpenAI models filter CSV (only sent when non-empty)"
    declare_option "openai_project_ids" "string" "" "OpenAI project IDs filter CSV (only sent when non-empty)"
    declare_option "openai_api_key_ids" "string" "" "OpenAI API key IDs filter CSV (only sent when non-empty)"
    declare_option "openai_user_ids" "string" "" "OpenAI user IDs filter CSV (only sent when non-empty)"

    # Shared pagination / window
    declare_option "report_window_days" "number" "1" "Reporting window in days"
    declare_option "usage_bucket_width" "string" "1d" "Bucket width (e.g. 1d, 1h)"
    declare_option "max_pages" "number" "100" "Max pages for pagination"

    # DeepSeek
    declare_option "deepseek_balance_url" "string" "${AIQUOTAS_DEFAULT_URLS[deepseek_balance]}" "DeepSeek balance endpoint"

    # MiniMax
    declare_option "minimax_usage_url" "string" "${AIQUOTAS_DEFAULT_URLS[minimax_usage]}" "MiniMax Token Plan usage endpoint (remaining quota)"
    declare_option "minimax_schema" "string" "" "Configured JSON path to canonical field mappings (CSV)"

    # Z.ai (Zhipu GLM Coding Plan)
    declare_option "zai_quota_url" "string" "${AIQUOTAS_DEFAULT_URLS[zai_quota]}" "Z.ai quota/limit endpoint (Coding Plan 5h quota)"

    declare_option "icon" "icon" $'\uEE9C' "Plugin icon"
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}

# =============================================================================
# Content type / presence
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

# =============================================================================
# Collection (provider dispatch + plugin_collect)
# =============================================================================
# Iterates the configured providers, fetches each via the HTTP shim seam,
# stores canonical documents per provider. Returns non-zero only when ALL
# configured providers fail to produce a usable document; partial failures
# are preserved so the lifecycle can mark stale=1.

_aiquotas_collect_provider() {
    # Dispatches one provider's collection through its dedicated adapter
    # (anthropic / openai / deepseek / minimax / xiaomi_mimo). Each adapter
    # returns the canonical metrics document on stdout (or an empty string
    # on hard transport failure). Does NOT touch plugin_data.
    local provider="$1"
    local timeout
    timeout=$(get_option "timeout")
    timeout="${timeout:-5}"

    # Lazy load: source the provider adapter only when actually needed.
    # Idempotent — calling twice with the same provider is a no-op.
    _aiquotas_load_provider "$provider" || return 64

    case "$provider" in
    anthropic) _aiquotas_collect_anthropic 2>/dev/null ;;
    openai) _aiquotas_collect_openai 2>/dev/null ;;
    deepseek) _aiquotas_collect_deepseek 2>/dev/null ;;
    minimax) _aiquotas_collect_minimax 2>/dev/null ;;
    zai) _aiquotas_collect_zai 2>/dev/null ;;
    *) return 64 ;;
    esac
}

plugin_collect() {
    local providers provider document outcome
    local available=0 failed=0

    # Re-register options lazily: bin/powerkit-plugin calls
    # plugin_declare_options BEFORE _set_plugin_context, so _PLUGIN_OPTIONS
    # is empty when get_option first runs. Re-declare now (idempotent —
    # declare_option guards against duplicates via _inject_default_plugin_options).
    if [[ -n "$_CURRENT_PLUGIN" ]] && [[ -z "${_PLUGIN_OPTIONS[$_CURRENT_PLUGIN]:-}" ]]; then
        plugin_declare_options
    fi

    providers=$(get_option "providers")

    plugin_data_set "providers_count" "0"
    plugin_data_set "providers_failed" "0"

    IFS=',' read -ra provider_list <<<"$providers"
    for provider in "${provider_list[@]}"; do
        provider=$(trim "$provider")
        [[ -n "$provider" ]] || continue

        case "$provider" in
        anthropic | openai | deepseek | minimax | zai)
            # Unified dispatch: every adapter owns its own HTTP+normalization
            # and returns a canonical metrics document on stdout (or empty
            # on hard transport failure). See _aiquotas_collect_provider.
            document=$(_aiquotas_collect_provider "$provider" 2>/dev/null) || document=""
            ;;
        *)
            # Unknown provider — skip silently (handled by upstream validation
            # in plugin_declare_options, but the case here is a defensive
            # guard in case the comma list is hand-edited).
            continue
            ;;
        esac

        if [[ -z "$document" ]]; then
            outcome=$(jq -nc \
                --arg provider "$provider" \
                '{provider:$provider,source:"official",status:"unavailable",error:"adapter produced no document"}')
            plugin_data_set "outcome_${provider}" "$outcome"
            plugin_data_set "document_${provider}" ""
            ((failed++)) || true
            continue
        fi

        plugin_data_set "document_${provider}" "$document"
        outcome=$(jq -c '.provider_outcomes[0] // empty' <<<"$document" 2>/dev/null)
        if [[ -z "$outcome" ]]; then
            outcome=$(jq -nc \
                --arg provider "$provider" \
                '{provider:$provider,source:"official",status:"malformed",error:"document missing outcome"}')
            plugin_data_set "outcome_${provider}" "$outcome"
            plugin_data_set "document_${provider}" ""
            ((failed++)) || true
            continue
        fi
        plugin_data_set "outcome_${provider}" "$outcome"
        # Plan v4: partial success means at least one provider returned
        # VALID records. The "available" counter reflects records actually
        # present in the document; outcome-only envelopes (e.g. unconfigured
        # with empty records) do NOT count as available.
        local rec_count=0
        rec_count=$(jq -r '.records | length' <<<"$document" 2>/dev/null || true)
        rec_count="${rec_count:-0}"
        if [[ "$rec_count" -gt 0 ]]; then
            ((available++)) || true
        else
            # No records (unconfigured/unsupported/etc) — counted as failed
            # for the partial-success threshold; outcome already captures
            # the precise status (unconfigured/unsupported/etc).
            ((failed++)) || true
        fi
    done

    plugin_data_set "providers_count" "$available"
    plugin_data_set "providers_failed" "$failed"

    # Plan v4 (Todo 4): return non-zero ONLY when ALL configured providers
    # failed to produce a usable document (no records). Partial success →
    # exit 0 so lifecycle preserves the partial data.
    if ((available == 0 && failed > 0)); then
        return 1
    fi
    return 0
}

# =============================================================================
# Plugin state / health / icon / render / context
# =============================================================================

plugin_get_state() {
    local available failed
    available=$(plugin_data_get "providers_count")
    failed=$(plugin_data_get "providers_failed")
    available="${available:-0}"
    failed="${failed:-0}"

    if ((available == 0 && failed == 0)); then
        printf 'inactive' # nothing configured
        return
    fi
    if ((available == 0)); then
        printf 'failed' # all configured providers failed
        return
    fi
    if ((failed > 0)); then
        printf 'degraded' # partial failure
        return
    fi
    printf 'active'
}

plugin_get_health() {
    local warn_th crit_th worst threshold_health
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")
    warn_th="${warn_th:-80}"
    crit_th="${crit_th:-95}"

    # Threshold-driven health (from quota records with limit+window+unit).
    threshold_health=$(_aiquotas_threshold_health "$warn_th" "$crit_th")

    # Outcome-driven health (provider_outcomes status values).
    worst=$(_aiquotas_worst_health)

    # Threshold-driven health takes precedence ONLY when at least one
    # record produced a verdict (warning/error). An "info" outcome (e.g.
    # unconfigured) does NOT override "ok" threshold.
    local final="$worst"
    case "$threshold_health" in
    error) final="error" ;;
    warning)
        [[ "$final" != "error" ]] && final="warning"
        ;;
    esac
    printf '%s' "$final"
}

plugin_get_context() {
    local available failed
    available=$(plugin_data_get "providers_count")
    failed=$(plugin_data_get "providers_failed")
    available="${available:-0}"
    failed="${failed:-0}"
    if ((failed > 0 && available > 0)); then
        printf 'partial'
    fi
}

plugin_get_icon() {
    get_option "icon"
}

plugin_render() {
    # Build the lifecycle "content" field — plain text, no tmux formatting.
    # Stale flag is the lifecycle's responsibility, not ours (5th field of
    # the icon<US>content<US>state<US>health<US>stale output). This function
    # NEVER emits "stale", colour codes, or any tmux attribute sequence.
    #
    # Iterates ALL records across the configured providers (not just
    # records[0]). Joins with the configured separator (default " | ").
    # Format is decided by the @powerkit_plugin_aiquotas_format option
    # (compact | detailed). Default is compact.
    local separator format show_percent show_x_of_y show_video min_limit parts=() provider document recs rec_count i record part result
    separator=$(get_option "separator")
    [[ -z "$separator" ]] && separator=" | "
    format=$(get_option "format")
    [[ -z "$format" ]] && format="compact"
    show_percent=$(get_option "show_percent")
    [[ -z "$show_percent" ]] && show_percent="left"
    show_x_of_y=$(get_option "show_x_of_y")
    [[ -z "$show_x_of_y" ]] && show_x_of_y="false"
    show_video=$(get_option "show_video")
    [[ -z "$show_video" ]] && show_video="false"
    min_limit=$(get_option "min_limit")
    [[ -z "$min_limit" ]] && min_limit=1

    IFS=',' read -ra provider_list <<<"$(get_option 'providers')"
    for provider in "${provider_list[@]}"; do
        provider=$(trim "$provider")
        [[ -n "$provider" ]] || continue
        document=$(plugin_data_get "document_${provider}")
        [[ -n "$document" ]] || continue
        recs=$(jq -c '.records // []' <<<"$document" 2>/dev/null) || continue
        rec_count=$(jq -r 'length' <<<"$recs" 2>/dev/null)
        [[ "$rec_count" -gt 0 ]] || continue

        # Skip quota records where limit < min_limit (e.g. limit=0 quota
        # cards that would render as "0/0"). Set min_limit=0 to disable.
        # Only applies to quota/token_quota/rate_limit — monetary records
        # have limit=null by design and must not be filtered.
        #
        # Exception: MiniMax records are kept even with limit=0 because
        # the API provides current_interval_remaining_percent directly,
        # so the percentage is meaningful regardless of the raw limit.
        local filtered_recs=()
        i=0
        while ((i < rec_count)); do
            record=$(jq -c ".[$i]" <<<"$recs" 2>/dev/null)
            i=$((i + 1))
            [[ -n "$record" ]] || continue

            if [[ "$min_limit" -gt 0 ]]; then
                local record_kind record_limit effective_min_limit
                record_kind=$(printf '%s' "$record" | jq -r '.metric_kind // ""' 2>/dev/null)
                case "$record_kind" in
                quota | token_quota | rate_limit)
                    record_limit=$(printf '%s' "$record" | jq -r '.limit // 0' 2>/dev/null)
                    effective_min_limit="$min_limit"
                    # MiniMax ignores min_limit: API yields
                    # current_interval_remaining_percent, so 0/0 is valid
                    # representation, not meaningless.
                    [[ "$provider" == "minimax" ]] && effective_min_limit=0
                    if [[ "$record_limit" -lt "$effective_min_limit" ]]; then
                        continue
                    fi
                    ;;
                esac
            fi
            filtered_recs+=("$record")
        done

        ((${#filtered_recs[@]} > 0)) || continue

        # MiniMax compact: emit ONE aggregated entry per provider. The
        # dispatcher aggregates siblings by dimensions.model so users see
        # a combined "interval%/weekly% left" instead of one card per
        # record. Other providers / formats keep the per-record loop.
        if [[ "$provider" == "minimax" ]] && [[ "$format" == "compact" ]]; then
            local filtered_json="[]"
            for r in "${filtered_recs[@]}"; do
                filtered_json=$(jq -c --argjson x "$r" '. + [$x]' <<<"$filtered_json")
            done
            part=$(_aiquotas_render_record "$provider" "$filtered_json" "$format" "$show_percent" "$show_x_of_y" "$show_video")
            [[ -n "$part" ]] && parts+=("$part")
            continue
        fi

        for record in "${filtered_recs[@]}"; do
            part=$(_aiquotas_render_record "$provider" "$record" "$format" "$show_percent" "$show_x_of_y" "$show_video")
            [[ -n "$part" ]] && parts+=("$part")
        done
    done

    if ((${#parts[@]} == 0)); then
        printf ''
        return
    fi

    local first=1
    for part in "${parts[@]}"; do
        if ((first)); then
            result="$part"
            first=0
        else
            result+="$separator$part"
        fi
    done

    printf '%s' "$result"
}
