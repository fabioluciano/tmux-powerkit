#!/usr/bin/env bash
# =============================================================================
# src/plugins/aiquotas/_health.sh — Health / threshold helpers
# Plan: .omo/plans/aiquotas-refactor.md (Todo 6, post-refactor extraction)
# =============================================================================
# Companion to aiquotas.sh. Provides health-aggregation helpers used by
# plugin_get_health:
#   * _aiquotas_worst_health      — worst status across stored outcomes
#   * _aiquotas_threshold_health  — quota-driven threshold violation worst
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_health" && return 0

# Determine the worst health across all stored provider outcomes.
# Threshold semantics (plan v4): warning/critical thresholds apply ONLY
# to metric_kind=quota records with:
#   * unit in [count|percent|token]
#   * limit > 0
#   * window_start AND window_end defined
# Monetary records (monetary_balance, monetary_spend) and token_usage
# records NEVER use thresholds. Threshold violations dominate outcome-
# based health (an "ok" outcome with a critical quota MUST be reported
# as "error").
_aiquotas_worst_health() {
    local worst="ok"
    local key outcome_json status
    for key in "${!_DATASTORE[@]}"; do
        [[ "$key" == "aiquotas:outcome_"* ]] || continue
        outcome_json="${_DATASTORE[$key]}"
        status=$(jq -r '.status // "ok"' <<<"$outcome_json" 2>/dev/null)
        case "$status" in
        error) worst="error" ;;
        warning | rate_limited | malformed | unauthorized)
            [[ "$worst" != "error" ]] && worst="warning"
            ;;
        unavailable | unconfigured)
            [[ "$worst" != "error" && "$worst" != "warning" ]] && worst="info"
            ;;
        esac
    done
    printf '%s' "$worst"
}

# Evaluate per-record thresholds (quota-only) and return the worst
# health implied by quota records in stored documents.
# Argument: warning_threshold, critical_threshold — both numeric
# percentages of quota CONSUMED (0-100). Returns one of:
#   "" (no qualifying quota records) | "ok" | "warning" | "error"
# Plans: see ".omo/plans/aiquotas-completo.md" v4 Todo 4.
_aiquotas_threshold_health() {
    local warn_th="$1"
    local crit_th="$2"

    local result=""
    local key document recs rec_count i record kind unit limit value ws we pct
    for key in "${!_DATASTORE[@]}"; do
        [[ "$key" == "aiquotas:document_"* ]] || continue
        document="${_DATASTORE[$key]}"
        [[ -n "$document" ]] || continue
        recs=$(jq -c '.records // []' <<<"$document" 2>/dev/null) || continue
        rec_count=$(jq -r 'length' <<<"$recs" 2>/dev/null)
        [[ "$rec_count" -gt 0 ]] || continue

        i=0
        while ((i < rec_count)); do
            record=$(jq -c ".[$i]" <<<"$recs" 2>/dev/null)
            i=$((i + 1))
            [[ -n "$record" ]] || continue
            kind=$(jq -r '.metric_kind // ""' <<<"$record" 2>/dev/null)
            [[ "$kind" == "quota" ]] || continue

            unit=$(jq -r '.unit // ""' <<<"$record" 2>/dev/null)
            case "$unit" in
            count | percent | token) ;;
            *) continue ;;
            esac

            limit=$(jq -r '.limit // 0' <<<"$record" 2>/dev/null)
            value=$(jq -r '.value // 0' <<<"$record" 2>/dev/null)
            ws=$(jq -r '.window_start // ""' <<<"$record" 2>/dev/null)
            we=$(jq -r '.window_end // ""' <<<"$record" 2>/dev/null)
            [[ -n "$ws" && -n "$we" ]] || continue

            # Skip records without numeric limit/limit<=0: thresholds
            # only make sense against a positive budget.
            if ! [[ "$limit" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then continue; fi
            (($(awk -v v="$limit" 'BEGIN { print (v > 0) ? 1 : 0 }'))) || continue
            if ! [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then continue; fi

            pct=$(awk -v v="$value" -v l="$limit" 'BEGIN { printf "%.0f", (v / l) * 100 }')

            if ((crit_th > 0)) && ((pct >= crit_th)); then
                result="error"
            elif ((warn_th > 0)) && ((pct >= warn_th)); then
                [[ "$result" != "error" ]] && result="warning"
            fi
        done
    done

    printf '%s' "$result"
}
