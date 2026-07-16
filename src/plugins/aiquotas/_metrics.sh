#!/usr/bin/env bash
# =============================================================================
# src/plugins/aiquotas/_metrics.sh — Canonical metrics document builder
# Plan: .omo/plans/aiquotas-refactor.md (Todo 6, post-refactor extraction)
# =============================================================================
# Companion to aiquotas.sh. Provides _aiquotas_metrics_document: a pure
# function over JSON payload that emits the canonical document envelope
# (schema_version=1, records, provider_outcomes).
#
# Loaded eagerly by aiquotas.sh because the BATS suite invokes
# _aiquotas_metrics_document directly after sourcing the entry.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_metrics" && return 0

# -----------------------------------------------------------------------------
# Canonical metrics document (pure function over JSON payload)
# -----------------------------------------------------------------------------
# Usage: _aiquotas_metrics_document <provider> <payload_json> [schema_csv]
#   provider   : anthropic|openai|deepseek|minimax|xiaomi_mimo
#   payload    : raw JSON string from the provider endpoint
#   schema_csv : optional configured schema ("json_path=field,...")
#
# On success prints a canonical JSON document with schema_version=1 and exit 0.
# On malformed JSON, error object, or invalid configured schema prints nothing
# and exits non-zero (caller can decide to mark the lifecycle as failed).
# Unknown official schemas still produce a document with status="unsupported".

_aiquotas_metrics_document() {
    local provider="$1"
    local payload="$2"
    local schema="${3:-}"

    jq -ce --arg provider "$provider" --arg schema "$schema" '
        # ---- canonical helpers ---------------------------------------------
        def dimension_keys:
            ["input_tokens","cached_input_tokens","cache_creation_tokens",
             "output_tokens","requests","model","project","line_item","resource",
             "interval_remaining_percent","weekly_remaining_percent"];

        def dimensions($v):
            reduce dimension_keys[] as $k
                ({}; . + {($k): ($v[$k] // null)});

        def valid_metric:  IN("token_usage","token_quota","quota","monetary_balance","monetary_spend","rate_limit");
        def valid_source:  IN("official","configured");
        def valid_status:  IN("ok","unconfigured","unsupported","unauthorized","rate_limited","unavailable","malformed","stale");
        def valid_unit:    IN("token","request","count","percent","currency", null);
        def valid_kind_status_source:
            (valid_metric) and (valid_source) and (valid_status);

        def outcome($source; $status; $error):
            { provider: $provider, source: $source, status: $status, error: $error };

        def doc($records; $source; $status; $error):
            {
                schema_version: 1,
                records: $records,
                provider_outcomes: [ outcome($source; $status; $error) ]
            };

        def record($kind; $value; $limit; $remaining; $unit; $currency;
                   $ws; $we; $reset; $source; $dims):
            {
                provider: $provider,
                metric_kind: $kind,
                value: $value,
                limit: $limit,
                remaining: $remaining,
                unit: $unit,
                currency: $currency,
                window_start: $ws,
                window_end: $we,
                reset_at: $reset,
                source: $source,
                status: "ok",
                error: null,
                dimensions: dimensions($dims)
            };

        def parse_schema_str($s):
            if $s == "" then []
            else $s | split(",")
            end;

        def valid_schema_pair:
            . as $p |
            ($p | test("^\\.[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)*=(" +
                (["metric_kind","value","limit","remaining","unit","currency",
                  "window_start","window_end","reset_at","input_tokens",
                  "cached_input_tokens","cache_creation_tokens","output_tokens",
                  "requests","model","project","line_item","resource",
                  "interval_remaining_percent","weekly_remaining_percent"] | join("|")) +
                ")$")) as $matches |
            $matches;

        def apply_schema($root; $schema_str):
            parse_schema_str($schema_str) |
            map(if valid_schema_pair then . else error("invalid configured schema entry: \(.)") end) |
            reduce .[] as $entry
                ({}; . + {
                    (($entry | split("=")[1])):
                        ($root | getpath(($entry | split("=")[0] | ltrimstr(".") | split("."))))
                });

        # ---- known schema validators --------------------------------------
        def monetary_ok($r):
            ($r.unit == "currency") and
            (($r.currency | type) == "string") and
            ($r.limit == null) and ($r.remaining == null);

        def quota_ok($r):
            (($r.limit  | type) == "number") and ($r.limit > 0) and
            (($r.value  | type) == "number") and
            ((0 <= $r.value) and ($r.value <= $r.limit)) and
            ($r.remaining == ($r.limit - $r.value));

        # ---- per-provider emission ----------------------------------------
        def root_has_any($keys):
            . as $root | reduce $keys[] as $k (false; . or ($root | has($k)));

        def record_has_all_dimensions:
            . as $r | reduce dimension_keys[] as $k (true; . and ($r.dimensions | has($k)));

        def emit_openai:
            # Recognise OpenAI usage when at least one usage-shaped key is present.
            if (root_has_any(["used","total_tokens","input_tokens","output_tokens",
                              "cached_input_tokens","cache_creation_tokens","requests"]) | not)
            then error("unknown schema")
            else
                record(
                    "token_usage";
                    (.used // .total_tokens // null);
                    (.limit // null);
                    (.remaining // null);
                    "token";
                    null;
                    (.window_start // null);
                    (.window_end // null);
                    (.reset_at // .reset_epoch // null);
                    "official";
                    .
                )
            end;

        def emit_deepseek:
            if (has("balance_infos") | not) or
               ((.balance_infos | type) != "array") or
               ((.balance_infos | length) == 0)
            then error("unknown schema")
            else .balance_infos
            end;

        def emit_deepseek_record($bi):
            record(
                "monetary_balance";
                ($bi.total_balance // null);
                null;
                null;
                "currency";
                ($bi.currency // null);
                null;
                null;
                null;
                "official";
                {resource: "balance"}
            );

        def emit_minimax_official:
            if (has("model_remains") | not) or
               ((.model_remains | type) != "array") or
               ((.model_remains | length) == 0)
            then error("unknown schema")
            else .model_remains
            end;

        def emit_minimax_official_record($m):
            if ($m | (has("current_interval_total_count") | not)) or
               ($m | (has("current_interval_usage_count") | not))
            then error("MiniMax quota record requires total_count and usage_count")
            else
                ($m.current_interval_total_count  | type) as $tt |
                ($m.current_interval_usage_count | type) as $uu |
                if ($tt != "number") or ($uu != "number")
                then error("MiniMax total/usage counts must be numeric")
                else
                    (
                        if ($m | has("current_interval_remaining_percent"))
                        then
                            (if ($m.current_interval_total_count > 0)
                             then (($m.current_interval_remaining_percent / 100) * $m.current_interval_total_count) | floor
                             else null end)
                        else
                            ($m.current_interval_total_count - $m.current_interval_usage_count)
                        end
                    ) as $remaining |
                    record(
                        "quota";
                        $m.current_interval_usage_count;
                        $m.current_interval_total_count;
                        $remaining;
                        "count";
                        null;
                        null;
                        null;
                        null;
                        "official";
                        (
                            (if ($m | has("model_name"))
                             then {model: $m.model_name}
                             else {} end) +
                            {resource: "token_plan"} +
                            (if ($m | has("current_interval_remaining_percent"))
                             then {interval_remaining_percent: $m.current_interval_remaining_percent}
                             else {} end) +
                            (if ($m | has("current_weekly_remaining_percent"))
                             then {weekly_remaining_percent: $m.current_weekly_remaining_percent}
                             else {} end)
                        )
                    )
                end
            end;

        def emit_zai:
            # Z.ai quota envelope. Unwrap data.data.limits ?? data.limits.
            (.data.limits // .limits // empty) as $limits |
            if ($limits | type) != "array" or ($limits | length) == 0
            then error("unknown schema")
            else
                ($limits | map(select(.type == "TOKENS_LIMIT" and .unit == 3)) | .[0] // null) as $w5 |
                ($limits | map(select(.type == "TOKENS_LIMIT" and .unit == 6)) | .[0] // null) as $ww |
                # Prefer the 5-hour window; fall back to the weekly window.
                ($w5 // $ww // null) as $w |
                if $w == null then error("no token window")
                else
                    # percentage = % CONSUMED; clamp to [0,100].
                    ($w.percentage // 0) as $raw |
                    (if $raw > 100 then 100 elif $raw < 0 then 0 else $raw end) as $pct |
                    ($w.nextResetTime // null) as $reset_ms |
                    # Derive window endpoints from nextResetTime (epoch ms) so
                    # the threshold evaluator can score this quota (5h or 7d).
                    (if ($reset_ms | type) == "number" and $reset_ms > 0
                     then ($reset_ms / 1000) | todate
                     else null end) as $we_iso |
                    (if $we_iso != null then
                         (if ($w.unit // 0) == 3 then (($reset_ms / 1000) - 18000) | todate
                          else (($reset_ms / 1000) - 604800) | todate end)
                     else null end) as $ws_iso |
                    record(
                        "quota";
                        $pct;
                        100;
                        (100 - $pct);
                        "percent";
                        null;
                        $ws_iso;
                        $we_iso;
                        $we_iso;
                        "official";
                        ({resource: "coding_plan"} +
                         (if ($w.unit // null) == 3 then {line_item: "5h"}
                          elif ($w.unit // null) == 6 then {line_item: "weekly"}
                          else {} end) +
                         {interval_remaining_percent: (100 - $pct)} +
                         (if $ww != null then
                              {weekly_remaining_percent: (100 - (($ww.percentage // 0) | if . > 100 then 100 elif . < 0 then 0 else . end))}
                          else {} end))
                    )
                end
            end;

        # ---- top-level dispatch -------------------------------------------
        . as $root |
        if (type != "object") or has("error")
        then error("invalid provider payload")
        elif ($provider == "openai") and ($schema == "")
        then
            (try emit_openai catch null) as $rec |
            if $rec == null
            then doc([]; "official"; "unsupported"; "unknown schema")
            else doc([ $rec ]; "official"; "ok"; null)
            end
        elif ($provider == "deepseek") and ($schema == "")
        then
            (try emit_deepseek catch null) as $rows |
            if ($rows == null)
            then doc([]; "official"; "unsupported"; "unknown schema")
            else doc([ $rows[] | emit_deepseek_record(.) ]; "official"; "ok"; null)
            end
        elif ($provider == "minimax") and ($schema == "")
        then
            (try emit_minimax_official catch null) as $rows |
            if ($rows == null)
            then doc([]; "official"; "unsupported"; "unknown schema")
            else
                (try (
                    doc([ $rows[] | emit_minimax_official_record(.) ]; "official"; "ok"; null)
                 ) catch
                    doc([]; "official"; "unsupported"; "unknown schema"))
            end
        elif ($provider == "zai") and ($schema == "")
        then
            (try emit_zai catch null) as $rec |
            if $rec == null
            then doc([]; "official"; "unsupported"; "unknown schema")
            else doc([ $rec ]; "official"; "ok"; null)
            end
        elif (($provider == "xiaomi_mimo") or ($provider == "minimax")) and ($schema != "")
        then
            (try apply_schema($root; $schema) catch null) as $mapped |
            if $mapped == null
            then error("invalid configured schema")
            else
                record(
                    ($mapped.metric_kind // "token_usage");
                    ($mapped.value       // null);
                    ($mapped.limit       // null);
                    ($mapped.remaining   // null);
                    ($mapped.unit        // "count");
                    ($mapped.currency    // null);
                    ($mapped.window_start // null);
                    ($mapped.window_end   // null);
                    ($mapped.reset_at     // null);
                    "configured";
                    ($mapped | with_entries(select(.key | IN(
                        "input_tokens","cached_input_tokens","cache_creation_tokens",
                        "output_tokens","requests","model","project","line_item","resource"))))
                ) as $rec |
                doc([ $rec ]; "configured"; "ok"; null)
            end
        elif ($provider == "xiaomi_mimo")
        then
            doc([]; "configured"; "unsupported"; "no URL or schema configured")
        else
            doc([]; "configured"; "unsupported"; "schema not configured")
        end |
        # ---- top-level validation ----------------------------------------
        # Validate the canonical contract. Use root-captured expressions
        # so `all(.records[]; ...)` iterates each record correctly.
        def schema_ok: .schema_version == 1;
        def records_ok: ((.records // []) | type) == "array";
        def outcomes_ok: ((.provider_outcomes // []) | type) == "array";
        def record_valid:
            (.metric_kind | valid_metric) and
            (.source     | valid_source) and
            (.status     | valid_status) and
            (.unit       | valid_unit) and
            ((.dimensions | type == "object"));
        def all_records_valid: ((.records // []) | (if length == 0 then true else all(.[]; record_valid) end));
        def all_records_have_dimensions: ((.records // []) | (if length == 0 then true else all(.[]; record_has_all_dimensions) end));
        def outcome_valid:
            (.source | valid_source) and
            (.status | valid_status);
        def all_outcomes_valid: ((.provider_outcomes // []) | (if length == 0 then true else all(.[]; outcome_valid) end));
        if schema_ok and
           records_ok and
           outcomes_ok and
           all_records_valid and
           all_records_have_dimensions and
           all_outcomes_valid
        then .
        else error("canonical contract violation")
        end
    ' <<<"$payload" 2>/dev/null
}
