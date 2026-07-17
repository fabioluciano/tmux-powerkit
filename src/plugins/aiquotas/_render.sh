#!/usr/bin/env bash
# =============================================================================
# src/plugins/aiquotas/_render.sh — Render helpers (TEXT ONLY)
# Plan: .omo/plans/aiquotas-refactor.md (Todo 6, post-refactor extraction)
# =============================================================================
# Companion to aiquotas.sh. Provides record->text render helpers used by
# plugin_render. NEVER emit tmux formatting, colours, or the stale indicator
# here — those are the renderer's responsibility, not the plugin's.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_render" && return 0

# Compact a numeric value for display (e.g., 1250000 -> 1.2M).
# Returns the input unchanged when not a non-negative integer.
_aiquotas_compact_value() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]] || {
        printf '%s' "$value"
        return
    }
    if ((value >= 1000000)); then
        awk -v v="$value" 'BEGIN { printf "%.1fM", v / 1000000 }'
    elif ((value >= 1000)); then
        awk -v v="$value" 'BEGIN { printf "%.1fK", v / 1000 }'
    else
        printf '%s' "$value"
    fi
}

# Calculate rounded usage/available percentages for quota-shaped records.
# A zero-sized, unused quota is treated as fully available so the renderer can
# still explain API responses such as value=0, limit=0, remaining=0.
_aiquotas_quota_percentages() {
    local value="$1"
    local limit="$2"
    local remaining="${3:-}"

    [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
    [[ "$limit" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1

    if ! [[ "$remaining" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        remaining=$(awk -v v="$value" -v l="$limit" 'BEGIN { print l - v }')
    fi

    awk -v v="$value" -v l="$limit" -v r="$remaining" '
        BEGIN {
            if (l == 0) {
                if (v == 0) {
                    print "0 100"
                } else {
                    print "100 0"
                }
                exit
            }
            printf "%.0f %.0f\n", (v / l) * 100, (r / l) * 100
        }
    '
}

_aiquotas_render_label() {
    local provider="$1"
    local compact_content="${2:-false}"

    if [[ "$compact_content" == "true" ]]; then
        case "$provider" in
        anthropic) printf 'C' ;;
        openai) printf 'OAI' ;;
        deepseek) printf 'DS' ;;
        minimax) printf 'MM' ;;
        zai) printf 'zai' ;;
        *) printf '%s' "$provider" ;;
        esac
        return
    fi

    printf '%s' "${AIQUOTAS_LABELS[$provider]:-$provider}"
}

# Render a single record (or aggregated record list) as COMPACT text.
# Compact format shows the human label + the most relevant value(s):
#   * monetary_balance / monetary_spend -> "<Label> <value> <currency>"
#   * quota / token_quota / rate_limit  -> "<Label> <used>/<limit> (<pct>)"
#         pct is controlled by show_percent: both|left (default left)
#         X/Y prefix controlled by show_x_of_y: true|false (default false)
#   * token_usage                       -> "<Label> <value> tok"
#   * other                             -> "<Label> <value> <unit>"
#
# MiniMax compact special-case (Todo 17): when the caller (plugin_render)
# detects provider=minimax AND format=compact it forwards the FULL filtered
# records array as <record>; we aggregate by dimensions.model and emit
# "<Label> <p1>/<p2>% [/ <vp1>/<vp2>%] left". show_video=false (default)
# hides the "video" model so output is "MiniMax 67/84% left".
_aiquotas_render_record_compact() {
    local provider="$1"
    local metric_kind="$2"
    local value="$3"
    local limit="$4"
    local remaining="$5"
    local unit="$6"
    local currency="$7"
    local record="$8"
    local show_x_of_y="${9:-false}"
    local show_video="${10:-false}"
    local compact_content="${11:-false}"

    local label
    label=$(_aiquotas_render_label "$provider" "$compact_content")

    # MiniMax compact aggregation: when <record> is a JSON array we treat
    # it as the full set of filtered records for this provider and emit a
    # single combined line. Each record's value/limit is reduced to an
    # available/left percentage; models are grouped by dimensions.model
    # (defaults to the empty string when the dimension is absent). The
    # "video" group is suppressed unless show_video=true.
    if [[ "$provider" == "minimax" ]] && [[ "${record:0:1}" == "[" ]]; then
        _aiquotas_render_minimax_compact "$label" "$record" "$show_x_of_y" "$show_video" "$compact_content"
        return
    fi

    case "$metric_kind" in
    monetary_balance | monetary_spend)
        if [[ -n "$value" ]]; then
            if [[ "$compact_content" == "true" && "$currency" == "USD" ]]; then
                printf '%s $%s' "$label" "$value"
            else
                printf '%s %s' "$label" "$value"
                [[ -n "$currency" ]] && printf ' %s' "$currency"
            fi
        fi
        ;;
    quota | token_quota | rate_limit)
        # Dual-window quota providers (e.g. zai Coding Plan, OpenAI Codex
        # ChatGPT Plus/Pro) expose both an interval window (5h) and a weekly
        # window via the interval_remaining_percent / weekly_remaining_percent
        # dimensions. When the weekly dimension is present, emit
        # "<interval>/<weekly>% left" so both budgets are visible — mirroring
        # the MiniMax compact aggregator. Records without these dimensions
        # (anthropic/openai-api/deepseek) fall through to the value/limit
        # path below. MiniMax itself is handled by its dedicated aggregator.
        local dim_interval dim_weekly
        dim_interval=$(jq -r '.dimensions.interval_remaining_percent // empty' <<<"$record" 2>/dev/null)
        dim_weekly=$(jq -r '.dimensions.weekly_remaining_percent // empty' <<<"$record" 2>/dev/null)
        [[ "$dim_interval" =~ ^[0-9]+([.][0-9]+)?$ ]] || dim_interval=""
        [[ "$dim_weekly" =~ ^[0-9]+([.][0-9]+)?$ ]] || dim_weekly=""
        if [[ -n "$dim_weekly" ]] && [[ "$provider" != "minimax" ]]; then
            local int_pct="${dim_interval%.*}"
            local wk_pct="${dim_weekly%.*}"
            [[ -n "$int_pct" ]] || int_pct="$wk_pct"
            if [[ "$compact_content" == "true" ]]; then
                printf '%s %s/%s%%' "$label" "$int_pct" "$wk_pct"
            else
                printf '%s %s/%s%% left' "$label" "$int_pct" "$wk_pct"
            fi
            return 0
        fi

        local percentages usage_pct available_pct compact_value compact_limit
        if [[ -n "$value" && -n "$limit" ]] &&
            percentages=$(_aiquotas_quota_percentages "$value" "$limit" "$remaining"); then
            read -r usage_pct available_pct <<<"$percentages"
            compact_value=$(_aiquotas_compact_value "$value")
            compact_limit=$(_aiquotas_compact_value "$limit")
            # Build output based on show_x_of_y. When true, prepend the X/Y
            # prefix inside parentheses around the percentage; when false,
            # drop the prefix entirely and emit a clean "<label> <pct> <word>"
            # without parens so the display stays compact.
            if [[ "$show_x_of_y" == "true" ]]; then
                local xy_prefix="${compact_value}/${compact_limit} "
                case "$show_percent" in
                both)
                    printf '%s %s(%s%% used, %s%% left)' \
                        "$label" "$xy_prefix" \
                        "$usage_pct" "$available_pct"
                    ;;
                left | *)
                    if [[ "$compact_content" == "true" ]]; then
                        printf '%s %s%s%%' "$label" "$xy_prefix" "$available_pct"
                    else
                        printf '%s %s(%s%% left)' \
                            "$label" "$xy_prefix" "$available_pct"
                    fi
                    ;;
                esac
            else
                case "$show_percent" in
                both)
                    printf '%s %s%% used, %s%% left' \
                        "$label" "$usage_pct" "$available_pct"
                    ;;
                left | *)
                    if [[ "$compact_content" == "true" ]]; then
                        printf '%s %s%%' "$label" "$available_pct"
                    else
                        printf '%s %s%% left' "$label" "$available_pct"
                    fi
                    ;;
                esac
            fi
        elif [[ -n "$value" ]]; then
            printf '%s %s' "$label" "$(_aiquotas_compact_value "$value")"
        elif [[ -n "$remaining" ]]; then
            printf '%s %s' "$label" "$(_aiquotas_compact_value "$remaining")"
            [[ "$compact_content" != "true" ]] && printf ' left'
        fi
        ;;
    token_usage)
        if [[ -n "$value" ]]; then
            printf '%s %s tok' "$label" "$(_aiquotas_compact_value "$value")"
        fi
        ;;
    *)
        if [[ -n "$value" ]]; then
            printf '%s %s' "$label" "$value"
            if [[ "$unit" == "percent" ]]; then
                printf '%%'
            elif [[ -n "$unit" ]]; then
                printf ' %s' "$unit"
            fi
        fi
        ;;
    esac
}

# MiniMax compact aggregator (Todo 17). Sibling records for the same
# dimensions.model are reduced to "left" percentages, joined with "/" per
# group, and groups are joined with " / " in the order they appear in
# the records array. The "video" group is suppressed by default. When
# show_x_of_y=true the FIRST visible group's value/limit is prepended so
# users still see raw counts (e.g. "0/0 67/84% left").
_aiquotas_render_minimax_compact() {
    local label="$1"
    local records="$2"
    local show_x_of_y="$3"
    local show_video="$4"
    local compact_content="${5:-false}"

    local general_pcts="" video_pcts=""
    local xy_value="" xy_limit=""
    local rec_count
    rec_count=$(jq -r 'length' <<<"$records" 2>/dev/null || printf 0)
    rec_count="${rec_count:-0}"

    local i=0
    while ((i < rec_count)); do
        local rec model v l r pcts usage_pct available_pct int_pct weekly_pct record_pct
        rec=$(jq -c ".[$i]" <<<"$records" 2>/dev/null) || {
            i=$((i + 1))
            continue
        }
        i=$((i + 1))

        model=$(jq -r '.dimensions.model // ""' <<<"$rec" 2>/dev/null)
        v=$(jq -r '.value // empty' <<<"$rec" 2>/dev/null)
        l=$(jq -r '.limit // empty' <<<"$rec" 2>/dev/null)
        r=$(jq -r '.remaining // empty' <<<"$rec" 2>/dev/null)
        int_pct=$(jq -r '.dimensions.interval_remaining_percent // empty' <<<"$rec" 2>/dev/null)
        weekly_pct=$(jq -r '.dimensions.weekly_remaining_percent // empty' <<<"$rec" 2>/dev/null)

        # Empty value/limit (e.g. records where the API emitted only a
        # window_total=0 / usage=0 shape) — fall back to 0% used / 100% left.
        if ! [[ "$v" =~ ^[0-9]+([.][0-9]+)?$ ]]; then v=0; fi
        if ! [[ "$l" =~ ^[0-9]+([.][0-9]+)?$ ]] || [[ -z "$l" ]]; then l=0; fi
        if ! [[ "$r" =~ ^[0-9]+([.][0-9]+)?$ ]] || [[ -z "$r" ]]; then r=0; fi

        # Prefer API-supplied remaining percent when present (Todo 19).
        # The MiniMax API exposes current_interval_remaining_percent and
        # current_weekly_remaining_percent per record; when those fields
        # are present we use them directly instead of recomputing from
        # value/limit/remaining (which is unreliable when total_count=0
        # for the "5h limit" and "Weekly limit" cards).
        # When BOTH fields are set on the same record we emit
        # "<interval>/<weekly>" so a single record represents both quota
        # windows; when only one is set we emit that one.
        record_pct=""
        local has_int=0 has_weekly=0 int_clean="" weekly_clean=""
        if [[ -n "$int_pct" && "$int_pct" != "null" ]] &&
            [[ "$int_pct" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            has_int=1
            int_clean="${int_pct%.*}"
        fi
        if [[ -n "$weekly_pct" && "$weekly_pct" != "null" ]] &&
            [[ "$weekly_pct" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            has_weekly=1
            weekly_clean="${weekly_pct%.*}"
        fi
        if ((has_int)) && ((has_weekly)); then
            record_pct="${int_clean}/${weekly_clean}"
        elif ((has_int)); then
            record_pct="$int_clean"
        elif ((has_weekly)); then
            record_pct="$weekly_clean"
        fi

        if [[ -n "$record_pct" ]]; then
            available_pct="$record_pct"
            usage_pct="0"
        elif ! pcts=$(_aiquotas_quota_percentages "$v" "$l" "$r"); then
            continue
        else
            read -r usage_pct available_pct <<<"$pcts"
        fi

        case "$model" in
        "" | general)
            # Empty/blank and "general" both feed the primary group. A
            # missing dimensions.model is common in fixture data and the
            # canonical contract allows it (model is a free-form key).
            if [[ -z "$general_pcts" ]]; then
                general_pcts="$available_pct"
            else
                general_pcts+="/$available_pct"
            fi
            [[ -z "$xy_value" && "$show_x_of_y" == "true" ]] && xy_value="$v" && xy_limit="$l"
            ;;
        video)
            # Suppress unless the user opted in. We still remember the
            # X/Y from the FIRST general record so show_x_of_y works
            # even when the dominant group is "video".
            if [[ "$show_video" == "true" ]]; then
                if [[ -z "$video_pcts" ]]; then
                    video_pcts="$available_pct"
                else
                    video_pcts+="/$available_pct"
                fi
                [[ -z "$xy_value" && "$show_x_of_y" == "true" ]] && xy_value="$v" && xy_limit="$l"
            fi
            ;;
        *)
            # Unknown non-empty model — for now fold into general rather
            # than emit a separate group (canonical contract keeps the
            # schema flexible; mini-only branch is not exercised).
            if [[ -z "$general_pcts" ]]; then
                general_pcts="$available_pct"
            else
                general_pcts+="/$available_pct"
            fi
            [[ -z "$xy_value" && "$show_x_of_y" == "true" ]] && xy_value="$v" && xy_limit="$l"
            ;;
        esac
    done

    # Build the final line. The "general" group always leads; "video" only
    # appears when show_video=true. Each group is rendered with a trailing
    # "%" so multi-group output reads "<a>% / <b>%".
    local groups=()
    [[ -n "$general_pcts" ]] && groups+=("$general_pcts")
    [[ -n "$video_pcts" && "$show_video" == "true" ]] && groups+=("$video_pcts")

    ((${#groups[@]} > 0)) || return 0

    local joined=""
    local first=1
    for g in "${groups[@]}"; do
        if ((first)); then
            joined="${g}%"
            first=0
        else
            joined+=" / ${g}%"
        fi
    done

    local xy_prefix=""
    if [[ "$show_x_of_y" == "true" ]] && [[ -n "$xy_value" ]] && [[ -n "$xy_limit" ]]; then
        xy_prefix="${xy_value}/${xy_limit} "
    fi

    printf '%s %s%s' "$label" "$xy_prefix" "$joined"
    [[ "$compact_content" != "true" ]] && printf ' left'
}

# Render a single record as DETAILED text (used by plugin_render).
# Detailed output names the metric and adds model/reset context when available.
_aiquotas_render_record_detailed() {
    local provider="$1"
    local label="${AIQUOTAS_LABELS[$provider]:-$provider}"
    local record="$2"

    local kind value limit remaining unit currency model reset
    kind=$(jq -r '.metric_kind // ""' <<<"$record" 2>/dev/null)
    value=$(jq -r '.value // empty' <<<"$record" 2>/dev/null)
    limit=$(jq -r '.limit // empty' <<<"$record" 2>/dev/null)
    remaining=$(jq -r '.remaining // empty' <<<"$record" 2>/dev/null)
    unit=$(jq -r '.unit // ""' <<<"$record" 2>/dev/null)
    currency=$(jq -r '.currency // ""' <<<"$record" 2>/dev/null)
    model=$(jq -r '.dimensions.model // ""' <<<"$record" 2>/dev/null)
    reset=$(jq -r '.reset_at // ""' <<<"$record" 2>/dev/null)

    case "$kind" in
    monetary_balance)
        if [[ -n "$value" ]]; then
            printf '%s available %s' "$label" "$value"
            [[ -n "$currency" ]] && printf ' %s' "$currency"
        fi
        ;;
    monetary_spend)
        if [[ -n "$value" ]]; then
            printf '%s spent %s' "$label" "$value"
            [[ -n "$currency" ]] && printf ' %s' "$currency"
        fi
        ;;
    quota | token_quota | rate_limit)
        local percentages usage_pct available_pct details dim_weekly
        if [[ -n "$value" && -n "$limit" ]] &&
            percentages=$(_aiquotas_quota_percentages "$value" "$limit" "$remaining"); then
            read -r usage_pct available_pct <<<"$percentages"
            dim_weekly=$(jq -r '.dimensions.weekly_remaining_percent // empty' <<<"$record" 2>/dev/null)
            [[ "$dim_weekly" =~ ^[0-9]+([.][0-9]+)?$ ]] || dim_weekly=""
            details="${usage_pct}% used, ${available_pct}% left"
            [[ -n "$dim_weekly" ]] && details+=", weekly ${dim_weekly%.*}% left"
            [[ -n "$model" ]] && details+=", model=$model"
            [[ -n "$reset" ]] && details+=", reset=$reset"
            printf '%s usage %s/%s (%s)' \
                "$label" \
                "$(_aiquotas_compact_value "$value")" \
                "$(_aiquotas_compact_value "$limit")" \
                "$details"
        elif [[ -n "$value" ]]; then
            printf '%s usage %s' "$label" "$(_aiquotas_compact_value "$value")"
        fi
        ;;
    token_usage)
        if [[ -n "$value" ]]; then
            printf '%s usage %s tok' "$label" "$(_aiquotas_compact_value "$value")"
            [[ -n "$model" ]] && printf ' (model=%s)' "$model"
        fi
        ;;
    *)
        if [[ -n "$value" ]]; then
            printf '%s %s %s' "$label" "${kind:-usage}" "$value"
            if [[ "$unit" == "percent" ]]; then
                printf '%%'
            elif [[ -n "$unit" ]]; then
                printf ' %s' "$unit"
            fi
        fi
        ;;
    esac
}

# Dispatch a record to compact or detailed render based on a format flag.
# For MiniMax compact, <record> may be a JSON array (the filtered records
# for that provider) instead of a single object; the compact renderer
# aggregates them by dimensions.model.
_aiquotas_render_record() {
    local provider="$1"
    local record="$2"
    local format="${3:-compact}"
    local show_percent="${4:-left}"
    local show_x_of_y="${5:-false}"
    local show_video="${6:-false}"
    local compact_content="${7:-false}"

    if [[ "$format" == "detailed" ]]; then
        # Detailed output is per-record; if we received the array form
        # walk it and dispatch each element (preserves prior semantics).
        if [[ "${record:0:1}" == "[" ]]; then
            local rec_count i rec
            rec_count=$(jq -r 'length' <<<"$record" 2>/dev/null || printf 0)
            rec_count="${rec_count:-0}"
            i=0
            local sep=" | " first=1 result=""
            while ((i < rec_count)); do
                rec=$(jq -c ".[$i]" <<<"$record" 2>/dev/null) || {
                    i=$((i + 1))
                    continue
                }
                i=$((i + 1))
                local part
                part=$(_aiquotas_render_record_detailed "$provider" "$rec")
                if [[ -n "$part" ]]; then
                    if ((first)); then
                        result="$part"
                        first=0
                    else
                        result+="$sep$part"
                    fi
                fi
            done
            [[ -n "$result" ]] && printf '%s' "$result"
            return
        fi
        _aiquotas_render_record_detailed "$provider" "$record"
        return
    fi

    # Compact path: pre-extract per-record fields so the renderer can use
    # them directly without re-parsing the JSON. When <record> is the
    # array form (MiniMax aggregation) field extraction is skipped.
    local metric_kind value limit remaining unit currency
    if [[ "${record:0:1}" == "[" ]]; then
        metric_kind=""
        value=""
        limit=""
        remaining=""
        unit=""
        currency=""
    else
        metric_kind=$(jq -r '.metric_kind // ""' <<<"$record" 2>/dev/null)
        value=$(jq -r '.value // empty' <<<"$record" 2>/dev/null)
        limit=$(jq -r '.limit // empty' <<<"$record" 2>/dev/null)
        remaining=$(jq -r '.remaining // empty' <<<"$record" 2>/dev/null)
        unit=$(jq -r '.unit // ""' <<<"$record" 2>/dev/null)
        currency=$(jq -r '.currency // ""' <<<"$record" 2>/dev/null)
    fi

    _aiquotas_render_record_compact \
        "$provider" "$metric_kind" "$value" "$limit" "$remaining" \
        "$unit" "$currency" "$record" "$show_x_of_y" "$show_video" "$compact_content"
}
