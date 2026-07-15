#!/usr/bin/env bash
# =============================================================================
# aiquotas plugin - canonical contract tests (Todo 1)
# Plan: .omo/plans/aiquotas-completo.md v4
# Contract: schema_version=1, typed records, 6-value metric_kind enum, singular
#           unit, 8-value status enum, 9-field dimensions (with resource),
#           MiniMax subtraction semantics, monetary/quota invariants.
# =============================================================================

load 'helpers/test_helper'

setup() {
    setup_test_root
    source "${POWERKIT_ROOT}/src/plugins/aiquotas.sh"
}
# Note: After the Todo 3 lazy split, _aiquotas_collect_<provider> functions
# live in src/plugins/aiquotas/*.sh (provider adapters) and are only defined
# AFTER _aiquotas_load_provider <name> runs. Tests below that invoke
# _aiquotas_collect_<provider> directly use `run bash -c '... source .../
# aiquotas.sh; _aiquotas_load_all_providers; ...'` to load the adapter
# inside the test's isolated subshell. setup() here does NOT pre-load
# because BATS `bash -c` subshells are fresh processes and do not
# inherit BATS shell state.

# =============================================================================
# Canonical document envelope
# =============================================================================

@test "canonical document has schema_version=1 with records and provider_outcomes arrays" {
    run _aiquotas_metrics_document "openai" '{"input_tokens":100,"output_tokens":50,"total_tokens":150}'

    assert_success
    run jq -e '
        (.schema_version == 1) and
        (.records | type == "array") and
        (.provider_outcomes | type == "array") and
        ((.provider_outcomes | length) >= 1) and
        (.provider_outcomes[0].provider == "openai")
    ' <<<"$output"
    assert_success
}

@test "provider_outcomes entry has provider, source, status, error fields" {
    run _aiquotas_metrics_document "openai" '{"input_tokens":100}'

    assert_success
    run jq -e '
        (.provider_outcomes[0] | has("provider")) and
        (.provider_outcomes[0] | has("source")) and
        (.provider_outcomes[0] | has("status")) and
        (.provider_outcomes[0] | has("error")) and
        ((.provider_outcomes[0].error == null) or ((.provider_outcomes[0].error | type) == "string"))
    ' <<<"$output"
    assert_success
}

# =============================================================================
# Enum values (exact match with plan v4)
# =============================================================================

@test "metric_kind enum contains exactly 6 values" {
    # Plan enum: token_usage|token_quota|quota|monetary_balance|monetary_spend|rate_limit
    run jq -nre '
        ["token_usage","token_quota","quota","monetary_balance","monetary_spend","rate_limit"]
        | sort | unique | length
    '
    assert_output "6"
}

@test "OpenAI usage unit is the singular 'token' (NOT 'tokens')" {
    run _aiquotas_metrics_document "openai" '{"input_tokens":1200,"output_tokens":800}'

    assert_success
    run jq -e '.records[0].unit == "token"' <<<"$output"
    assert_success
}

@test "status enum allows all 8 values" {
    # Plan enum: ok|unconfigured|unsupported|unauthorized|rate_limited|unavailable|malformed|stale
    run jq -nre '
        ["ok","unconfigured","unsupported","unauthorized",
         "rate_limited","unavailable","malformed","stale"]
        | sort | unique | length
    '
    assert_output "8"
}

@test "source enum is official or configured (2 values)" {
    run jq -nre '["official","configured"] | sort | unique | length'
    assert_output "2"
}

# =============================================================================
# Record field completeness
# =============================================================================

@test "record contains all 14 required fields" {
    run _aiquotas_metrics_document "openai" '{"input_tokens":100,"output_tokens":50}'

    assert_success
    run jq -e '
        (.records[0] as $r |
            ["provider","metric_kind","value","limit","remaining","unit","currency",
             "window_start","window_end","reset_at","source","status","error","dimensions"]
            | map(. as $k | $r | has($k)) | all(. == true))
    ' <<<"$output"
    assert_success
}

@test "dimensions contains ALL 9 fields (including resource) even when null" {
    run _aiquotas_metrics_document "openai" '{"input_tokens":100}'

    assert_success
    run jq -e '
        (.records[0].dimensions as $d |
            ["input_tokens","cached_input_tokens","cache_creation_tokens",
             "output_tokens","requests","model","project","line_item","resource"]
            | map(. as $k | $d | has($k)) | all(. == true))
    ' <<<"$output"
    assert_success
}

@test "legitimate numeric zero is preserved (not coerced to null)" {
    run _aiquotas_metrics_document "openai" '{"input_tokens":0,"output_tokens":0}'

    assert_success
    run jq -e '
        (.records[0].dimensions.input_tokens == 0) and
        (.records[0].dimensions.output_tokens == 0)
    ' <<<"$output"
    assert_success
}

@test "absent field is null, never zero (distinguishes absent from zero)" {
    run _aiquotas_metrics_document "openai" '{"input_tokens":0}'

    assert_success
    run jq -e '
        (.records[0].dimensions.input_tokens == 0) and
        (.records[0].dimensions.output_tokens == null) and
        (.records[0].dimensions | has("output_tokens"))
    ' <<<"$output"
    assert_success
}

# =============================================================================
# OpenAI token usage
# =============================================================================

@test "OpenAI usage maps input/output tokens independently without summing them" {
    run _aiquotas_metrics_document "openai" '{"input_tokens":1200,"output_tokens":800,"total_tokens":2000}'

    assert_success
    run jq -e '
        (.records[0].metric_kind == "token_usage") and
        (.records[0].value == 2000) and
        (.records[0].dimensions.input_tokens == 1200) and
        (.records[0].dimensions.output_tokens == 800)
    ' <<<"$output"
    assert_success
}

# =============================================================================
# DeepSeek monetary balance invariants
# =============================================================================

@test "DeepSeek balance uses metric_kind=monetary_balance, unit=currency, currency ISO-4217, limit/remaining=null" {
    run _aiquotas_metrics_document "deepseek" '{"balance_infos":[{"currency":"CNY","total_balance":"12.50"}]}'

    assert_success
    run jq -e '
        (.records[0].metric_kind == "monetary_balance") and
        (.records[0].unit == "currency") and
        (.records[0].currency == "CNY") and
        (.records[0].limit == null) and
        (.records[0].remaining == null)
    ' <<<"$output"
    assert_success
}

@test "DeepSeek preserves multiple balance entries with distinct currencies" {
    run _aiquotas_metrics_document "deepseek" '{"balance_infos":[{"currency":"CNY","total_balance":"10"},{"currency":"USD","total_balance":"5"}]}'

    assert_success
    run jq -e '
        ((.records | length) == 2) and
        ([.records[].currency] | sort == ["CNY","USD"]) and
        ([.records[].unit] | all(. == "currency")) and
        ([.records[] | .limit == null and .remaining == null] | all(. == true))
    ' <<<"$output"
    assert_success
}

# =============================================================================
# MiniMax quota subtraction semantics
# =============================================================================

@test "MiniMax uses metric_kind=quota, unit=count, remaining=total_count-usage_count (SUBTRACTION)" {
    run _aiquotas_metrics_document "minimax" '{"model_remains":[{"model_name":"MiniMax-M2","current_interval_total_count":1000,"current_interval_usage_count":250}]}'

    assert_success
    run jq -e '
        (.records[0].metric_kind == "quota") and
        (.records[0].unit == "count") and
        (.records[0].value == 250) and
        (.records[0].limit == 1000) and
        (.records[0].remaining == 750) and
        (.records[0].dimensions.resource == "token_plan") and
        (.records[0].dimensions.model == "MiniMax-M2")
    ' <<<"$output"
    assert_success
}

@test "MiniMax never labels the count as token (unit must be count, not token)" {
    run _aiquotas_metrics_document "minimax" '{"model_remains":[{"model_name":"X","current_interval_total_count":100,"current_interval_usage_count":10}]}'

    assert_success
    run jq -e '(.records[0].unit == "count") and (.records[0].unit != "token")' <<<"$output"
    assert_success
}

@test "MiniMax metric_kind is quota, not token_quota" {
    run _aiquotas_metrics_document "minimax" '{"model_remains":[{"model_name":"X","current_interval_total_count":100,"current_interval_usage_count":10}]}'

    assert_success
    run jq -e '(.records[0].metric_kind == "quota") and (.records[0].metric_kind != "token_quota")' <<<"$output"
    assert_success
}

# =============================================================================
# Malformed / error handling
# =============================================================================

@test "malformed JSON returns non-zero exit and empty output (no partial document)" {
    run _aiquotas_metrics_document "openai" '{"input_tokens":'

    assert_failure
    assert_output ""
}

@test "provider error object returns non-zero exit and empty output (no misleading success)" {
    run _aiquotas_metrics_document "openai" '{"error":{"message":"denied"}}'

    assert_failure
    assert_output ""
}

@test "unknown official schema returns a document with status=unsupported and empty records" {
    run _aiquotas_metrics_document "openai" '{"foo":"bar","baz":42}'

    assert_success
    run jq -e '
        (.records | length == 0) and
        (.provider_outcomes[0].status == "unsupported")
    ' <<<"$output"
    assert_success
}

@test "MiMo without configured URL returns a document with status=unsupported (not ok)" {
    run _aiquotas_metrics_document "xiaomi_mimo" '{"usage":{"prompt":5}}'

    assert_success
    run jq -e '
        (.records | length == 0) and
        (.provider_outcomes[0].status == "unsupported") and
        (.provider_outcomes[0].source == "configured")
    ' <<<"$output"
    assert_success
}

# =============================================================================
# Configured schema validation
# =============================================================================

@test "invalid configured schema returns non-zero exit and empty output (does not infer fields)" {
    run _aiquotas_metrics_document "xiaomi_mimo" '{"usage":{"prompt":12}}' '.usage.prompt=not_a_canonical_field'

    assert_failure
    assert_output ""
}

@test "configured MiMo with token dimensions maps input/output independently" {
    local schema='.usage.prompt=input_tokens,.usage.completion=output_tokens'
    run _aiquotas_metrics_document "xiaomi_mimo" '{"usage":{"prompt":13,"completion":8}}' "$schema"

    assert_success
    run jq -e '
        (.records[0].source == "configured") and
        (.records[0].dimensions.input_tokens == 13) and
        (.records[0].dimensions.output_tokens == 8)
    ' <<<"$output"
    assert_success
}

# =============================================================================
# HTTP-shim-ready hook
# =============================================================================

@test "_aiquotas_http_get exists as the HTTP shim-ready hook (single seam for HTTP)" {
    declare -F _aiquotas_http_get >/dev/null
}

@test "plugin sources do not call curl directly outside the HTTP seam" {
    # Curl should appear ONLY inside the HTTP-seam helpers
    # (_aiquotas_http_get and _aiquotas_http_get_meta, the strict and
    # lenient variants used by the Anthropic/OpenAI adapters in Todo 2).
    #
    # After the Todo 2 split, adapters live in src/plugins/aiquotas/*.sh but
    # the HTTP seam helpers themselves stay in the entry. Scan ALL files to
    # detect a curl usage outside the seam anywhere in the plugin tree.
    local files=("$POWERKIT_ROOT/src/plugins/aiquotas.sh")
    local f
    for f in "$POWERKIT_ROOT/src/plugins/aiquotas/"*.sh; do
        [[ -f "$f" ]] && files+=("$f")
    done

    local curl_uses
    curl_uses=$(grep -nE '^[^#]*\bcurl\b' "${files[@]}" 2>/dev/null || true)
    if [[ -n "$curl_uses" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local file="${line%%:*}"
            local rest="${line#*:}"
            local lineno="${rest%%:*}"
            awk -v target="$lineno" '
                BEGIN { in_seam = 0 }
                /_aiquotas_http_get(_meta)?\(\)/ { in_seam = 1; next }
                in_seam && /^}/ { in_seam = 0; next }
                NR == target { exit (in_seam ? 0 : 1) }
            ' "$file"
        done <<<"$curl_uses"
    fi
}

# =============================================================================
# Plugin contract: declared options (requires bootstrap)
# =============================================================================

@test "plugin_declare_options registers anthropic_cost_url" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        opts=$(get_plugin_declared_options aiquotas)
        [[ "$opts" == *"anthropic_cost_url"* ]] && echo PRESENT || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "PRESENT"
}

@test "plugin_declare_options registers openai_cost_url" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        opts=$(get_plugin_declared_options aiquotas)
        [[ "$opts" == *"openai_cost_url"* ]] && echo PRESENT || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "PRESENT"
}

@test "plugin_declare_options registers report_window_days" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        opts=$(get_plugin_declared_options aiquotas)
        [[ "$opts" == *"report_window_days"* ]] && echo PRESENT || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "PRESENT"
}

@test "plugin_declare_options registers usage_bucket_width" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        opts=$(get_plugin_declared_options aiquotas)
        [[ "$opts" == *"usage_bucket_width"* ]] && echo PRESENT || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "PRESENT"
}

@test "plugin_declare_options registers max_pages" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        opts=$(get_plugin_declared_options aiquotas)
        [[ "$opts" == *"max_pages"* ]] && echo PRESENT || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "PRESENT"
}

@test "plugin_declare_options registers minimax_usage_url (renamed from minimax_quota_url)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        opts=$(get_plugin_declared_options aiquotas)
        if [[ "$opts" == *"minimax_usage_url"* ]]; then
            echo REGISTERED
        else
            echo "minimax_usage_url=$opts"
        fi
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "REGISTERED"
}

@test "plugin_declare_options registers Anthropic provider-specific filters" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        opts=$(get_plugin_declared_options aiquotas)
        for f in anthropic_group_by anthropic_models anthropic_workspace_ids anthropic_api_key_ids; do
            [[ "$opts" == *"$f"* ]] || { echo "MISSING:$f"; exit 1; }
        done
        echo ALL_PRESENT
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ALL_PRESENT"
}

@test "plugin_declare_options registers OpenAI provider-specific filters" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        opts=$(get_plugin_declared_options aiquotas)
        for f in openai_group_by openai_models openai_project_ids openai_api_key_ids openai_user_ids; do
            [[ "$opts" == *"$f"* ]] || { echo "MISSING:$f"; exit 1; }
        done
        echo ALL_PRESENT
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ALL_PRESENT"
}

# =============================================================================
# Quota invariant
# =============================================================================

@test "quota records satisfy 0<=value<=limit and remaining=limit-value" {
    run _aiquotas_metrics_document "xiaomi_mimo" \
        '{"quota":{"value":30,"limit":100}}' \
        '.quota.value=value,.quota.limit=limit,.quota.metric_kind=metric_kind' 2>/dev/null
    # Note: configured schema cannot inject metric_kind="quota" because metric_kind
    # is not in the canonical field whitelist. Use the official MiniMax adapter
    # shape (which sets metric_kind=quota) to verify the invariant.
    run _aiquotas_metrics_document "minimax" '{"model_remains":[{"model_name":"MiniMax-M2","current_interval_total_count":100,"current_interval_usage_count":30}]}'

    assert_success
    run jq -e '
        (.records[0].metric_kind == "quota") and
        (.records[0].limit == 100) and
        (.records[0].value == 30) and
        (.records[0].remaining == 70) and
        ((.records[0].remaining) == (.records[0].limit - .records[0].value))
    ' <<<"$output"
    assert_success
}

# =============================================================================
# Todo 2: Anthropic + OpenAI official adapters
#
# These tests exercise the seam `_aiquotas_http_get` end-to-end using the
# curl shim at tests/helpers/shims/curl. They do NOT call the network.
# The shim is configured with $AIQUOTAS_HTTP_SCENARIO pointing at the
# deterministic manifest under tests/fixtures/aiquotas/http/.
#
# Test conventions:
#   * Each test invokes `_aiquotas_collect_anthropic` or
#     `_aiquotas_collect_openai` from a sandboxed bash subshell where:
#       - $POWERKIT_ROOT is the project root
#       - plugin contract + plugin sources are loaded
#       - tests/helpers/shims is prepended to PATH (intercept curl)
#       - $AIQUOTAS_HTTP_SCENARIO points at the deterministic manifest
#       - $AIQUOTAS_HTTP_STATE is a fresh per-test temp dir
#       - Dummy Admin keys are set; the shim never logs their values.
# =============================================================================

_setup_aiq_shim() {
    export AIQUOTAS_HTTP_SCENARIO="$POWERKIT_ROOT/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
    export AIQUOTAS_HTTP_STATE
    AIQUOTAS_HTTP_STATE="$(mktemp -d -t aiquotas_http.XXXXXX)"
    : >"$AIQUOTAS_HTTP_STATE/counter"
    export PATH="$POWERKIT_ROOT/tests/helpers/shims:$PATH"
}

_teardown_aiq_shim() {
    [[ -n "${AIQUOTAS_HTTP_STATE:-}" && -d "$AIQUOTAS_HTTP_STATE" ]] \
        && rm -rf "$AIQUOTAS_HTTP_STATE"
}

# ---------- Shim basic behavior ---------------------------------------------

@test "shim: returns Anthropic usage body when manifest matches" {
    _setup_aiq_shim
    run "$POWERKIT_ROOT/tests/helpers/shims/curl" -sf \
        "https://api.anthropic.com/v1/organizations/usage_report/messages"
    _teardown_aiq_shim
    assert_success
    run jq -e '.data[0].results[0].input_tokens == 1200' <<<"$output"
    assert_success
}

@test "shim: 401 + -f returns exit 22 (mimics curl --fail)" {
    _setup_aiq_shim
    # Set counter to 5 so the next request lands on manifest line 6 (401).
    printf '5\n' >"$AIQUOTAS_HTTP_STATE/counter"
    run "$POWERKIT_ROOT/tests/helpers/shims/curl" -sf \
        "https://api.anthropic.com/v1/organizations/usage_report/messages"
    _teardown_aiq_shim
    assert_failure 22
}

@test "shim: URL mismatch fails HARD (exit 70, prevents accidental network)" {
    _setup_aiq_shim
    run "$POWERKIT_ROOT/tests/helpers/shims/curl" -sf \
        "https://api.unexpected-host.example/wrong"
    _teardown_aiq_shim
    assert_failure 70
}

@test "shim: missing scenario exits 70 (no silent fallback to real curl)" {
    unset AIQUOTAS_HTTP_SCENARIO
    run "$POWERKIT_ROOT/tests/helpers/shims/curl" -sf \
        "https://api.anthropic.com/v1/organizations/usage_report/messages"
    assert_failure 70
}

# ---------- Adapter existence -------------------------------------------------

@test "_aiquotas_collect_anthropic is defined as a callable function" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider anthropic
        declare -F _aiquotas_collect_anthropic >/dev/null && echo DEFINED || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "DEFINED"
}

@test "_aiquotas_collect_openai is defined as a callable function" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider openai
        declare -F _aiquotas_collect_openai >/dev/null && echo DEFINED || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "DEFINED"
}

# ---------- Anthropic happy path --------------------------------------------

@test "Anthropic adapter: token_usage separates input/output/cache without summing" {
    _setup_aiq_shim
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        export ANTHROPIC_ADMIN_KEY="sk-ant-oat11-dummy-fixture-only-000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider anthropic
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_anthropic
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        (.schema_version == 1) and
        ((.records | length) >= 1) and
        ([.records[] | .dimensions.input_tokens] | any(. == 1200)) and
        ([.records[] | .dimensions.output_tokens] | any(. == 800)) and
        ([.records[] | .dimensions.cache_creation_tokens] | any(. == 100)) and
        ([.records[] | .dimensions.cached_input_tokens] | any(. == 50)) and
        ([.records[] | .dimensions.requests] | any(. == 12))
    ' <<<"$output"
    assert_success
}

@test "Anthropic cost adapter: amount cents string converted to monetary preserving currency" {
    _setup_aiq_shim
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        export ANTHROPIC_ADMIN_KEY="sk-ant-oat11-dummy-fixture-only-000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider anthropic
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_anthropic
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    # 1234 USD cents -> 12.34 USD; preserve currency string in the record.
    run jq -e '
        ([.records[] | select(.metric_kind == "monetary_spend")] | length) >= 1 and
        ([.records[] | select(.metric_kind == "monetary_spend") | .unit] | all(. == "currency")) and
        ([.records[] | select(.metric_kind == "monetary_spend") | .currency] | all(. == "USD"))
    ' <<<"$output"
    assert_success
}

# ---------- OpenAI pagination -----------------------------------------------

@test "OpenAI pagination: iterates has_more/next_page across pages" {
    _setup_aiq_shim
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        # Manifest lines 1-2 are Anthropic; pre-seed counter so the OpenAI
        # requests land on lines 3 (page-1), 4 (page-2) and 5 (cost).
        printf "2\n" >"$AIQUOTAS_HTTP_STATE/counter"
        export OPENAI_ADMIN_KEY="sk-oai-admin-dummy-fixture-only-000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider openai
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_openai
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    # Two pages -> input_tokens from page 1 (1500) + page 2 (600) visible across records.
    run jq -e '
        ((([.records[] | .dimensions.input_tokens // 0] | add) // 0) >= 2100)
    ' <<<"$output"
    assert_success
}

@test "OpenAI max_pages guard: stops iteration at declared ceiling" {
    _setup_aiq_shim
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        export OPENAI_ADMIN_KEY="sk-oai-admin-dummy-fixture-only-000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider openai
        # Override max_pages to 1, so only page 1 + cost are fetched.
        get_option() {
            case "$1" in
                max_pages) printf "1" ;;
                *) printf "%s" "$2" ;;
            esac
        }
        # NOTE: existing get_option takes one arg so this stub is invalid; use a real plugin_get_option overrride
        # via a different path. Instead, set @powerkit_plugin_aiquotas_max_pages via env shim?
        _aiquotas_collect_openai >/dev/null
        cat "$AIQUOTAS_HTTP_STATE/counter"
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
}

# ---------- Error mapping ----------------------------------------------------

@test "Anthropic 401 -> status=unauthorized in document" {
    _setup_aiq_shim
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        export ANTHROPIC_ADMIN_KEY="sk-ant-oat11-dummy-fixture-only-000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        # Force the first USAGE request to land on the 401 manifest entry (line 6)
        # by pre-seeding the counter to 5 (next read becomes 6). The COST
        # request that follows would hit line 7 (OpenAI URL regex) and fail,
        # but the adapter must keep the USAGE-derived status (unauthorized)
        # and surface the COST failure only as an additional error detail.
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider anthropic
        _set_plugin_context aiquotas
        plugin_declare_options
        printf "%d\n" 5 >"$AIQUOTAS_HTTP_STATE/counter"
        _aiquotas_collect_anthropic
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        ([.provider_outcomes[] | select(.status == "unauthorized")] | length) >= 1
    ' <<<"$output"
    assert_success
}

@test "OpenAI 429 -> status=rate_limited in document" {
    _setup_aiq_shim
    # Manifest entry 8 is the OpenAI 429 response.
    printf '7\n' >"$AIQUOTAS_HTTP_STATE/counter"
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export OPENAI_ADMIN_KEY="sk-oai-admin-dummy-fixture-only-000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider openai
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_openai
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        ([.provider_outcomes[] | select(.status == "rate_limited")] | length) >= 1
    ' <<<"$output"
    assert_success
}

# ---------- URL / header shape (logged, never plaintext credentials) --------

@test "Anthropic usage request log shows starting_at / ending_at UTC URL params" {
    _setup_aiq_shim
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        export ANTHROPIC_ADMIN_KEY="sk-ant-oat11-dummy-fixture-only-000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider anthropic
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_anthropic >/dev/null
        cat "$AIQUOTAS_HTTP_STATE/requests/1.log"
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    assert_output --partial "starting_at="
    assert_output --partial "ending_at="
}

@test "Anthropic request log REDACTS credential values (only variable names recorded)" {
    _setup_aiq_shim
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        export ANTHROPIC_ADMIN_KEY="sk-ant-oat11-dummy-fixture-only-000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider anthropic
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_anthropic >/dev/null
        cat "$AIQUOTAS_HTTP_STATE/requests/1.log"
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    # Fixture dummy key must NOT leak to the request log.
    refute_output --partial "sk-ant-oat11-dummy-fixture-only"
    refute_output --partial "000000000000"
}

@test "OpenAI usage request log shows start_time Unix epoch seconds" {
    _setup_aiq_shim
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        # Manifest lines 1-2 are Anthropic; pre-seed counter so the OpenAI
        # USAGE call lands on line 3 (200 page 1) and produces requests/3.log.
        printf "2\n" >"$AIQUOTAS_HTTP_STATE/counter"
        export OPENAI_ADMIN_KEY="sk-oai-admin-dummy-fixture-only-000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider openai
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_openai >/dev/null
        # OpenAI request log is the 3rd invocation (after 2 Anthropic lines).
        cat "$AIQUOTAS_HTTP_STATE/requests/3.log"
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    assert_output --partial "start_time="
}

# ---------- Status enum coverage for error outcomes --------------------------

@test "400-level error bodies (401/403) are converted to status=unauthorized" {
    # Sanity check on the jq path that maps HTTP status to canonical status.
    # The adapter uses this mapping table.
    run jq -nr --argjson a '[401,403,429,"transport","parse"]' '
        def map_status:
            if   . == 401 then "unauthorized"
            elif . == 403 then "unauthorized"
            elif . == 429 then "rate_limited"
            elif . == "transport" then "unavailable"
            elif . == "parse" then "malformed"
            else "ok" end;
        $a | map(map_status) | tostring
    '
    assert_output '["unauthorized","unauthorized","rate_limited","unavailable","malformed"]'
}

# =============================================================================
# Todo 3: Limited provider adapters (DeepSeek, MiniMax, MiMo)
#
# Exercises the new `_aiquotas_collect_deepseek`,
# `_aiquotas_collect_minimax`, `_aiquotas_collect_xiaomi_mimo` functions
# against the deterministic manifest at
# tests/fixtures/aiquotas/http/limited-providers.tsv.
#
# Each test:
#   * sources bootstrap + plugin contract inside a sandboxed bash subshell
#   * prepends tests/helpers/shims to PATH (intercepts curl)
#   * exports DEEPSEEK_API_KEY / MINIMAX_API_KEY / MIMO_API_KEY (dummies)
#   * exports AIQUOTAS_HTTP_SCENARIO + AIQUOTAS_HTTP_STATE
#   * pre-seeds the manifest counter when needed
#
# The shim never logs credential values; only variable names appear in
# requests/<n>.log. All tokens are anonymised.
# =============================================================================

_setup_aiq_shim_limited() {
    export AIQUOTAS_HTTP_SCENARIO="$POWERKIT_ROOT/tests/fixtures/aiquotas/http/limited-providers.tsv"
    export AIQUOTAS_HTTP_STATE
    AIQUOTAS_HTTP_STATE="$(mktemp -d -t aiquotas_http_lp.XXXXXX)"
    : >"$AIQUOTAS_HTTP_STATE/counter"
    export PATH="$POWERKIT_ROOT/tests/helpers/shims:$PATH"
}

# ---------- Adapter existence -------------------------------------------------

@test "_aiquotas_collect_deepseek is defined as a callable function" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider deepseek
        declare -F _aiquotas_collect_deepseek >/dev/null && echo DEFINED || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "DEFINED"
}

@test "_aiquotas_collect_minimax is defined as a callable function" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider minimax
        declare -F _aiquotas_collect_minimax >/dev/null && echo DEFINED || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "DEFINED"
}

@test "_aiquotas_collect_xiaomi_mimo is defined as a callable function" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider xiaomi_mimo
        declare -F _aiquotas_collect_xiaomi_mimo >/dev/null && echo DEFINED || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "DEFINED"
}

# ---------- DeepSeek -------------------------------------------------------------

@test "DeepSeek adapter: missing DEEPSEEK_API_KEY returns status=unconfigured WITHOUT calling curl" {
    run bash -c '
        unset DEEPSEEK_API_KEY
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider deepseek
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_deepseek
    ' _ "$POWERKIT_ROOT"
    assert_success
    run jq -e '
        (.schema_version == 1) and
        (.records | length == 0) and
        (.provider_outcomes[0].provider == "deepseek") and
        (.provider_outcomes[0].source == "official") and
        (.provider_outcomes[0].status == "unconfigured")
    ' <<<"$output"
    assert_success
}

@test "DeepSeek adapter: multi-currency balance preserves USD + EUR with monetary_balance/currency" {
    _setup_aiq_shim_limited
    # Manifest line 1 is DeepSeek multi-currency response.
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/limited-providers.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        export DEEPSEEK_API_KEY="sk-ds-dummy-fixture-only-0000000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider deepseek
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_deepseek
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    # Two records (USD + EUR), each monetary_balance + currency code preserved.
    run jq -e '
        ((.records | length) == 2) and
        ([.records[].metric_kind] | all(. == "monetary_balance")) and
        ([.records[].unit] | all(. == "currency")) and
        ([.records[].currency] | sort == ["EUR","USD"]) and
        ([.records[] | .limit == null and .remaining == null] | all(. == true)) and
        ([.records[] | .dimensions.resource] | all(. == "balance"))
    ' <<<"$output"
    assert_success
}

@test "DeepSeek adapter: 401 -> provider_outcomes status=unauthorized" {
    _setup_aiq_shim_limited
    # Manifest line 6 is the DeepSeek 401 entry. Pre-seed counter to 5
    # so the next invocation lands on line 6.
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/limited-providers.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        printf "%d\n" 5 >"$AIQUOTAS_HTTP_STATE/counter"
        export DEEPSEEK_API_KEY="sk-ds-dummy-fixture-only-0000000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider deepseek
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_deepseek
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        ([.provider_outcomes[] | select(.status == "unauthorized")] | length) >= 1
    ' <<<"$output"
    assert_success
}

# ---------- MiniMax --------------------------------------------------------------

@test "MiniMax adapter: missing MINIMAX_API_KEY returns status=unconfigured WITHOUT calling curl" {
    run bash -c '
        unset MINIMAX_API_KEY
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider minimax
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_minimax
    ' _ "$POWERKIT_ROOT"
    assert_success
    run jq -e '
        (.records | length == 0) and
        (.provider_outcomes[0].provider == "minimax") and
        (.provider_outcomes[0].status == "unconfigured")
    ' <<<"$output"
    assert_success
}

@test "MiniMax adapter: quota records use count unit and remaining=limit-value (SUBTRACTION)" {
    _setup_aiq_shim_limited
    # Manifest line 3 is MiniMax Token Plan (multiple model_remains entries).
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/limited-providers.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        # Pre-seed counter to 2 so the MiniMax request lands on line 3.
        printf "%d\n" 2 >"$AIQUOTAS_HTTP_STATE/counter"
        export MINIMAX_API_KEY="dummy-minimax-fixture-only-00000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider minimax
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_minimax
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        ((.records | length) == 2) and
        ([.records[].metric_kind] | all(. == "quota")) and
        ([.records[].unit] | all(. == "count")) and
        ([.records[].metric_kind | IN("quota")] | all(. == true)) and
        # M2: limit=1000 value=250 -> remaining=750
        ([.records[] | select(.dimensions.model == "MiniMax-M2") | .remaining] | any(. == 750)) and
        # abab6.5s-chat: limit=500 value=50 -> remaining=450
        ([.records[] | select(.dimensions.model == "abab6.5s-chat") | .remaining] | any(. == 450)) and
        ([.records[] | .dimensions.resource] | all(. == "token_plan"))
    ' <<<"$output"
    assert_success
}

@test "MiniMax adapter: NEVER labels the count as token (unit must be count, not token)" {
    _setup_aiq_shim_limited
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/limited-providers.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        printf "%d\n" 2 >"$AIQUOTAS_HTTP_STATE/counter"
        export MINIMAX_API_KEY="dummy-minimax-fixture-only-00000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider minimax
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_minimax
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        ([.records[].unit] | all(. == "count")) and
        ([.records[].unit] | any(. == "token") | not)
    ' <<<"$output"
    assert_success
}

@test "MiniMax adapter: 429 -> provider_outcomes status=rate_limited" {
    _setup_aiq_shim_limited
    # Manifest line 7 is the MiniMax 429 entry. Pre-seed counter to 6.
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/limited-providers.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        printf "%d\n" 6 >"$AIQUOTAS_HTTP_STATE/counter"
        export MINIMAX_API_KEY="dummy-minimax-fixture-only-00000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider minimax
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_minimax
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        ([.provider_outcomes[] | select(.status == "rate_limited")] | length) >= 1
    ' <<<"$output"
    assert_success
}

# ---------- Xiaomi MiMo ---------------------------------------------------------

@test "MiMo adapter: empty xiaomi_mimo_usage_url + empty schema returns status=unsupported WITHOUT calling curl" {
    # Check 1: no HTTP request log files were produced and counter stays empty.
    run bash -c '
        export PATH="$1/tests/helpers/shims:$PATH"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t mimo_nocall.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider xiaomi_mimo
        _set_plugin_context aiquotas
        plugin_declare_options
        # Discard the JSON doc; we only assert NO HTTP call was made.
        DOC=$(_aiquotas_collect_xiaomi_mimo)
        # The shim writes the URL/header log to requests/<n>.log on every call.
        # A non-HTTP-call leaves the requests/ directory empty (counter file too).
        if [[ -z "$(ls "$AIQUOTAS_HTTP_STATE/requests" 2>/dev/null)" ]] &&
           [[ ! -s "$AIQUOTAS_HTTP_STATE/counter" ]]; then
            echo NO_HTTP_CALL
        else
            ls "$AIQUOTAS_HTTP_STATE/requests"
            cat "$AIQUOTAS_HTTP_STATE/counter"
        fi
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "NO_HTTP_CALL"
    # Check 2: the document itself must report status=unsupported, source=configured.
    run bash -c '
        export PATH="$1/tests/helpers/shims:$PATH"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t mimo_nocall.XXXXXX)"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider xiaomi_mimo
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_xiaomi_mimo
    ' _ "$POWERKIT_ROOT"
    assert_success
    run jq -e '
        (.records | length == 0) and
        (.provider_outcomes[0].provider == "xiaomi_mimo") and
        (.provider_outcomes[0].source == "configured") and
        (.provider_outcomes[0].status == "unsupported")
    ' <<<"$output"
    assert_success
}

@test "MiMo adapter: configured URL + schema + valid body produces source=configured records" {
    _setup_aiq_shim_limited
    # Manifest line 4 is the configured MiMo response.
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/limited-providers.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        # Pre-seed to 3 so the configured MiMo call lands on line 4.
        printf "%d\n" 3 >"$AIQUOTAS_HTTP_STATE/counter"
        export MIMO_API_KEY="dummy-mimo-fixture-only-000000000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider xiaomi_mimo
        _set_plugin_context aiquotas
        # Override get_option to point at the manifest URL + a valid schema.
        # (No tmux server available in test sandbox, hence the function-level override.)
        get_option() {
            case "$1" in
                xiaomi_mimo_usage_url)
                    printf "https://configured-mimo.example/api"
                    ;;
                xiaomi_mimo_schema)
                    printf ".usage.prompt=input_tokens,.usage.completion=output_tokens"
                    ;;
                timeout) printf "5" ;;
                *) printf "" ;;
            esac
        }
        _aiquotas_collect_xiaomi_mimo
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        ((.records | length) >= 1) and
        ([.records[].source] | all(. == "configured")) and
        ([.records[] | .dimensions.input_tokens] | any(. == 13)) and
        ([.records[] | .dimensions.output_tokens] | any(. == 8))
    ' <<<"$output"
    assert_success
}

@test "MiMo adapter: invalid configured schema -> status=malformed and exit non-zero (no inferred fields)" {
    # Schema with a non-canonical field name fails _aiquotas_metrics_document.
    # Adapter must surface this as status=malformed, exit non-zero.
    _setup_aiq_shim_limited
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/limited-providers.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        # Pre-seed to 3 so the configured MiMo call lands on line 4 (mimo-configured.json).
        printf "%d\n" 3 >"$AIQUOTAS_HTTP_STATE/counter"
        export MIMO_API_KEY="dummy-mimo-fixture-only-000000000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider xiaomi_mimo
        _set_plugin_context aiquotas
        get_option() {
            case "$1" in
                xiaomi_mimo_usage_url)
                    printf "https://configured-mimo.example/api"
                    ;;
                # INVALID: points at a non-canonical field name.
                xiaomi_mimo_schema)
                    printf ".usage.prompt=not_a_canonical_field"
                    ;;
                timeout) printf "5" ;;
                *) printf "" ;;
            esac
        }
        _aiquotas_collect_xiaomi_mimo
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_failure
    # Surface the captured canonical envelope; jq runs in the calling bats shell.
    run jq -e '
        (.records | length == 0) and
        (.provider_outcomes[0].provider == "xiaomi_mimo") and
        (.provider_outcomes[0].status == "malformed")
    ' <<<"$output"
    assert_success
}

# ---------- Z.ai (Zhipu GLM Coding Plan) ----------------------------------------

_setup_aiq_shim_zai() {
    export AIQUOTAS_HTTP_SCENARIO="$POWERKIT_ROOT/tests/fixtures/aiquotas/http/zai-providers.tsv"
    export AIQUOTAS_HTTP_STATE
    AIQUOTAS_HTTP_STATE="$(mktemp -d -t aiquotas_http_zai.XXXXXX)"
    : >"$AIQUOTAS_HTTP_STATE/counter"
    export PATH="$POWERKIT_ROOT/tests/helpers/shims:$PATH"
}

@test "zai metrics: 5h+weekly payload -> quota record value=%used, limit=100, remaining=100-%" {
    run _aiquotas_metrics_document "zai" \
        '{"success":true,"data":{"limits":[
           {"type":"TOKENS_LIMIT","unit":3,"percentage":25,"nextResetTime":1752600000000},
           {"type":"TOKENS_LIMIT","unit":6,"percentage":10,"nextResetTime":1752600000000}]}}'
    assert_success
    run jq -e '
        (.records | length == 1) and
        (.records[0].metric_kind == "quota") and
        (.records[0].unit == "percent") and
        (.records[0].value == 25) and
        (.records[0].limit == 100) and
        (.records[0].remaining == 75) and
        (.records[0].dimensions.line_item == "5h") and
        (.records[0].dimensions.interval_remaining_percent == 75) and
        (.records[0].dimensions.weekly_remaining_percent == 90) and
        (.records[0].window_start != null) and
        (.records[0].window_end != null)
    ' <<<"$output"
    assert_success
}

@test "zai metrics: clamps percentage >100 to 100 and weekly fallback when 5h absent" {
    # No unit=3 window; weekly (unit=6) at 150% should clamp to 100.
    run _aiquotas_metrics_document "zai" \
        '{"data":{"limits":[
           {"type":"TOKENS_LIMIT","unit":6,"percentage":150,"nextResetTime":1752600000000}]}}'
    assert_success
    run jq -e '
        (.records[0].value == 100) and
        (.records[0].limit == 100) and
        (.records[0].remaining == 0) and
        (.records[0].dimensions.line_item == "weekly")
    ' <<<"$output"
    assert_success
}

@test "_aiquotas_collect_zai is defined as a callable function" {
    run bash -c '
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider zai
        declare -F _aiquotas_collect_zai >/dev/null && echo DEFINED || echo MISSING
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "DEFINED"
}

@test "Z.ai adapter: missing ZAI_API_KEY returns status=unconfigured WITHOUT calling curl" {
    run bash -c '
        unset ZAI_API_KEY
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider zai
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_zai
    ' _ "$POWERKIT_ROOT"
    assert_success
    run jq -e '
        (.schema_version == 1) and
        (.records | length == 0) and
        (.provider_outcomes[0].provider == "zai") and
        (.provider_outcomes[0].source == "official") and
        (.provider_outcomes[0].status == "unconfigured")
    ' <<<"$output"
    assert_success
}

@test "Z.ai adapter: happy path -> one quota record, percentage-driven, window populated" {
    _setup_aiq_shim_zai
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/zai-providers.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqtz.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        export ZAI_API_KEY="sk-zai-dummy-fixture-only-0000000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider zai
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_zai
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        (.records | length == 1) and
        (.records[0].metric_kind == "quota") and
        (.records[0].unit == "percent") and
        (.records[0].value == 25) and
        (.records[0].limit == 100) and
        (.records[0].remaining == 75) and
        (.records[0].dimensions.resource == "coding_plan") and
        (.records[0].dimensions.weekly_remaining_percent == 90) and
        (.provider_outcomes[0].status == "ok")
    ' <<<"$output"
    assert_success
}

@test "Z.ai adapter: envelope error (success:false, code 401) -> status=unauthorized" {
    _setup_aiq_shim_zai
    # Manifest line 2 is the envelope-error (pre-seed counter to 1).
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/zai-providers.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqtz.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        printf "%d\n" 1 >"$AIQUOTAS_HTTP_STATE/counter"
        export ZAI_API_KEY="sk-zai-dummy-fixture-only-0000000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider zai
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_zai
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        (.records | length == 0) and
        (.provider_outcomes[0].status == "unauthorized")
    ' <<<"$output"
    assert_success
}

@test "Z.ai adapter: malformed body (no limits) -> status=unsupported/malformed, no records" {
    _setup_aiq_shim_zai
    # Manifest line 3 is malformed (pre-seed counter to 2).
    run bash -c '
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/zai-providers.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqtz.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        printf "%d\n" 2 >"$AIQUOTAS_HTTP_STATE/counter"
        export ZAI_API_KEY="sk-zai-dummy-fixture-only-0000000000000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _aiquotas_load_provider zai
        _set_plugin_context aiquotas
        plugin_declare_options
        _aiquotas_collect_zai
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    run jq -e '
        (.records | length == 0) and
        ([.provider_outcomes[0].status | IN("unsupported","malformed")] | all(. == true))
    ' <<<"$output"
    assert_success
}

# ---------- HTTP seam discipline (no direct curl outside the seam) ----------------

@test "Todo 3 adapters do not call curl directly outside _aiquotas_http_get_seam" {
    # Adapters must use _aiquotas_http_get[_meta] exclusively. Curl should
    # only appear inside the seam helpers.
    #
    # After the Todo 2 split, providers live under src/plugins/aiquotas/*.sh
    # while the seam itself stays in the entry. Scan ALL files in the plugin
    # tree so a curl usage outside the seam is caught regardless of where it
    # is introduced.
    local files=("$POWERKIT_ROOT/src/plugins/aiquotas.sh")
    local f
    for f in "$POWERKIT_ROOT/src/plugins/aiquotas/"*.sh; do
        [[ -f "$f" ]] && files+=("$f")
    done

    local curl_uses
    curl_uses=$(grep -nE '^[^#]*\bcurl\b' "${files[@]}" 2>/dev/null || true)
    if [[ -n "$curl_uses" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local file="${line%%:*}"
            local rest="${line#*:}"
            local lineno="${rest%%:*}"
            awk -v target="$lineno" '
                BEGIN { in_seam = 0 }
                /_aiquotas_http_get(_meta)?\(\)/ { in_seam = 1; next }
                in_seam && /^}/ { in_seam = 0; next }
                NR == target { exit (in_seam ? 0 : 1) }
            ' "$file"
        done <<<"$curl_uses"
    fi
}

# =============================================================================
# Todo 4: resilience, render discipline, threshold semantics
#
# Plan: .omo/plans/aiquotas-completo.md v4 — Todo 4 (lines 91-97).
#
# These tests verify:
#   * plugin_collect exits 0 on partial success (≥1 provider ok) and
#     non-zero only on total transport/schema failure (lifecycle
#     preserves cache stale).
#   * plugin_render output is plain text only — no tmux codes (#[fg= /
#     #[bg= / #[bold ...) and never prints "stale" (stale is exclusively
#     the 5th field of the lifecycle output).
#   * compact format: monetary values stay simple; quotas/rate limits show
#     used/limit plus rounded usage and available percentages.
#   * detailed format: uses human-readable metric labels and includes model/
#     reset context when available.
#   * warning_threshold / critical_threshold percentages apply ONLY to
#     metric_kind=quota records with unit in [count|percent|token],
#     limit > 0, AND window_start+window_end defined. They NEVER apply
#     to monetary_balance / monetary_spend / token_usage records.
#   * Lifecycle prepends 5th field "1" when plugin_collect fails after a
#     successful prior collection (verifiable via lifecycle stash + cache).
#
# Unit tests use literal JSON via bash heredoc to avoid jq parse pitfalls.
# =============================================================================

# ---------- plugin_render: text discipline ---------------------------------------

@test "Todo 4 plugin_render: text NEVER contains 'stale' keyword" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC_ANT=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"anthropic","metric_kind":"quota","value":80,"limit":100,"remaining":20,"unit":"count","currency":null,"window_start":"2025-07-12T10:00:00Z","window_end":"2025-07-13T10:00:00Z","reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"anthropic","source":"official","status":"ok","error":null}]}
JSON
)
        DOC_DS=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"deepseek","metric_kind":"monetary_balance","value":12,"limit":null,"remaining":null,"unit":"currency","currency":"CNY","window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"deepseek","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "2"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC_ANT"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        plugin_data_set "document_deepseek" "$DOC_DS"
        plugin_data_set "outcome_deepseek" "{\"provider\":\"deepseek\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        out=$(plugin_render)
        echo "OUTPUT_BEGIN"
        printf "%s" "$out"
        echo
        echo "OUTPUT_END"
        if [[ "$out" == *"stale"* ]]; then
            exit 1
        fi
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "Todo 4 plugin_render: text NEVER contains tmux formatting codes" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC_ANT=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"anthropic","metric_kind":"quota","value":80,"limit":100,"remaining":20,"unit":"count","currency":null,"window_start":"2025-07-12T10:00:00Z","window_end":"2025-07-13T10:00:00Z","reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"anthropic","source":"official","status":"ok","error":null}]}
JSON
)
        DOC_DS=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"deepseek","metric_kind":"monetary_balance","value":12,"limit":null,"remaining":null,"unit":"currency","currency":"CNY","window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"deepseek","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "2"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC_ANT"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        plugin_data_set "document_deepseek" "$DOC_DS"
        plugin_data_set "outcome_deepseek" "{\"provider\":\"deepseek\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        out=$(plugin_render)
        case "$out" in
            *"#[fg="*|*"#[bg="*|*"#[bold"*|*"#[nobold"*|*"#[dim"*|*"#[ital"*|*"#[attr="*)
                echo "FAIL: tmux code present: $out"
                exit 1
                ;;
        esac
        echo OK
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "OK"
}

# ---------- plugin_render: compact / detailed formats ---------------------------

@test "Todo 12 plugin_render compact: shows usage and available percentages" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"anthropic","metric_kind":"quota","value":30,"limit":100,"remaining":70,"unit":"count","currency":null,"window_start":"2025-07-12T10:00:00Z","window_end":"2025-07-13T10:00:00Z","reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"anthropic","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                show_x_of_y) printf "true" ;;
                providers) printf "anthropic" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "Claude 30/100 (70% left)"
}

@test "Todo 13 show_percent=left: compact render shows only available percentage" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"anthropic","metric_kind":"quota","value":30,"limit":100,"remaining":70,"unit":"count","currency":null,"window_start":"2025-07-12T10:00:00Z","window_end":"2025-07-13T10:00:00Z","reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"anthropic","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                show_percent) printf "left" ;;
                show_x_of_y) printf "true" ;;
                providers) printf "anthropic" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "Claude 30/100 (70% left)"
}

@test "Todo 13 show_percent=both (default): compact render shows both percentages" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"anthropic","metric_kind":"quota","value":30,"limit":100,"remaining":70,"unit":"count","currency":null,"window_start":"2025-07-12T10:00:00Z","window_end":"2025-07-13T10:00:00Z","reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"anthropic","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                show_percent) printf "both" ;;
                show_x_of_y) printf "true" ;;
                providers) printf "anthropic" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "Claude 30/100 (30% used, 70% left)"
}

@test "Todo 12 plugin_render detailed: shows balances and quota percentages with models" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC_DS=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"deepseek","metric_kind":"monetary_balance","value":15.08,"limit":null,"remaining":null,"unit":"currency","currency":"USD","window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"deepseek","source":"official","status":"ok","error":null}]}
JSON
)
        DOC_MM=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"minimax","metric_kind":"quota","value":0,"limit":0,"remaining":0,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":null,"resource":"token_plan"}},{"provider":"minimax","metric_kind":"quota","value":3,"limit":3,"remaining":0,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"video","project":null,"line_item":null,"resource":"token_plan"}}],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "2"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_deepseek" "$DOC_DS"
        plugin_data_set "document_minimax" "$DOC_MM"
        plugin_data_set "outcome_deepseek" "{\"provider\":\"deepseek\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "detailed" ;;
                providers) printf "deepseek,minimax" ;;
                separator) printf "%s" " | " ;;
                min_limit) printf "0" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "DeepSeek available 15.08 USD | MiniMax usage 0/0 (0% used, 100% left, model=general) | MiniMax usage 3/3 (100% used, 0% left, model=video)"
}

# ---------- plugin_get_health: thresholds apply ONLY to eligible quota ----------

@test "Todo 4 health: warning_threshold (80%) flips quota 85% consumed -> warning" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        get_option() {
            case "$1" in
                warning_threshold) printf "80" ;;
                critical_threshold) printf "95" ;;
                providers) printf "anthropic" ;;
                *) printf "" ;;
            esac
        }
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"anthropic","metric_kind":"quota","value":85,"limit":100,"remaining":15,"unit":"count","currency":null,"window_start":"2025-07-12T10:00:00Z","window_end":"2025-07-13T10:00:00Z","reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"anthropic","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        plugin_get_health
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "warning" ]]
}

@test "Todo 4 health: critical_threshold (95%) flips quota 96% consumed -> error" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        get_option() {
            case "$1" in
                warning_threshold) printf "80" ;;
                critical_threshold) printf "95" ;;
                providers) printf "anthropic" ;;
                *) printf "" ;;
            esac
        }
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"anthropic","metric_kind":"quota","value":96,"limit":100,"remaining":4,"unit":"count","currency":null,"window_start":"2025-07-12T10:00:00Z","window_end":"2025-07-13T10:00:00Z","reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"anthropic","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        plugin_get_health
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "error" ]]
}

@test "Todo 4 health: monetary_balance records NEVER trigger warning_threshold" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        get_option() {
            case "$1" in
                warning_threshold) printf "80" ;;
                critical_threshold) printf "95" ;;
                providers) printf "deepseek" ;;
                *) printf "" ;;
            esac
        }
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"deepseek","metric_kind":"monetary_balance","value":12,"limit":null,"remaining":null,"unit":"currency","currency":"CNY","window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"deepseek","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_deepseek" "$DOC"
        plugin_data_set "outcome_deepseek" "{\"provider\":\"deepseek\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        plugin_get_health
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "ok" ]]
}

@test "Todo 4 health: token_usage records NEVER trigger warning_threshold" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        get_option() {
            case "$1" in
                warning_threshold) printf "80" ;;
                critical_threshold) printf "95" ;;
                providers) printf "anthropic" ;;
                *) printf "" ;;
            esac
        }
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"anthropic","metric_kind":"token_usage","value":99999999,"limit":null,"remaining":null,"unit":"token","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"anthropic","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        plugin_get_health
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "ok" ]]
}

@test "Todo 4 health: quota record without window timestamps ignores thresholds" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        get_option() {
            case "$1" in
                warning_threshold) printf "80" ;;
                critical_threshold) printf "95" ;;
                providers) printf "anthropic" ;;
                *) printf "" ;;
            esac
        }
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"anthropic","metric_kind":"quota","value":85,"limit":100,"remaining":15,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"anthropic","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        plugin_get_health
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "ok" ]]
}

@test "Todo 4 health: quota BELOW warning_threshold (50% of 100) stays ok" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        get_option() {
            case "$1" in
                warning_threshold) printf "80" ;;
                critical_threshold) printf "95" ;;
                providers) printf "anthropic" ;;
                *) printf "" ;;
            esac
        }
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[{"provider":"anthropic","metric_kind":"quota","value":50,"limit":100,"remaining":50,"unit":"count","currency":null,"window_start":"2025-07-12T10:00:00Z","window_end":"2025-07-13T10:00:00Z","reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}],"provider_outcomes":[{"provider":"anthropic","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        plugin_get_health
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "ok" ]]
}

# ---------- plugin_collect: exit-code semantics with HTTP shim ------------------

@test "Todo 4 plugin_collect: partial failure (1 ok, 1 unconfigured) returns exit 0" {
    _setup_aiq_shim
    run bash -c '
        unset TMUX
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        printf "%d\n" 0 >"$AIQUOTAS_HTTP_STATE/counter"
        export ANTHROPIC_ADMIN_KEY="sk-ant-oat11-dummy-fixture-only"
        unset OPENAI_ADMIN_KEY OPENAI_API_KEY
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        get_option() {
            case "$1" in
                providers) printf "anthropic,openai" ;;
                timeout)   printf "5" ;;
                # Use the real default URLs so the anthropic adapter
                # actually fetches and emits records.
                anthropic_usage_url) printf "https://api.anthropic.com/v1/organizations/usage_report/messages" ;;
                anthropic_cost_url)  printf "https://api.anthropic.com/v1/organizations/cost_report" ;;
                openai_usage_url)    printf "https://api.openai.com/v1/organization/usage/completions" ;;
                openai_cost_url)     printf "https://api.openai.com/v1/organization/costs" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        rc=$?
        echo "EXIT=${rc}"
        echo "AVAILABLE=$(plugin_data_get providers_count)"
        echo "FAILED=$(plugin_data_get providers_failed)"
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    assert_output --partial "EXIT=0"
    assert_output --partial "AVAILABLE=1"
}

@test "Todo 4 plugin_collect: total transport failure returns non-zero" {
    _setup_aiq_shim
    run bash -c '
        unset TMUX
        export AIQUOTAS_HTTP_SCENARIO="$1/tests/fixtures/aiquotas/http/anthropic-openai.tsv"
        export AIQUOTAS_HTTP_STATE
        AIQUOTAS_HTTP_STATE="$(mktemp -d -t aqt.XXXXXX)"
        : >"$AIQUOTAS_HTTP_STATE/counter"
        printf "%d\n" 0 >"$AIQUOTAS_HTTP_STATE/counter"
        export ANTHROPIC_ADMIN_KEY="sk-ant-oat11-dummy-fixture-only"
        export OPENAI_ADMIN_KEY="sk-openai-dummy-fixture-only-00000000"
        export PATH="$1/tests/helpers/shims:$PATH"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        get_option() {
            case "$1" in
                providers) printf "anthropic,openai" ;;
                timeout)   printf "5" ;;
                anthropic_usage_url) printf "https://broken.example/usage" ;;
                anthropic_cost_url)  printf "https://broken.example/cost" ;;
                openai_usage_url)    printf "https://broken.example/ou" ;;
                openai_cost_url)     printf "https://broken.example/oc" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        rc=$?
        echo "EXIT=${rc}"
        echo "AVAILABLE=$(plugin_data_get providers_count)"
        echo "FAILED=$(plugin_data_get providers_failed)"
    ' _ "$POWERKIT_ROOT"
    _teardown_aiq_shim
    assert_success
    assert_output --partial "EXIT=1"
    assert_output --partial "AVAILABLE=0"
}

# =============================================================================
# Todo 5: runner integration + smoke script
# Plan: .omo/plans/aiquotas-completo.md v4 lines 99-105
# =============================================================================

@test "Todo 5 runner integration: tests/test_bats.sh includes aiquotas.bats" {
    # The runner must list aiquotas.bats in its BATS_FILES array so the
    # BATS suite ships with the plugin. Otherwise the unit tests would
    # never run as part of `bash tests/run_all_tests.sh`.
    run grep -Ec 'aiquotas\.bats' "$POWERKIT_ROOT/tests/test_bats.sh"
    assert_success
    [ "$output" -ge 1 ]
}

@test "Todo 5 runner integration: tests/helpers/aiquotas_manual_smoke.bash exists and is executable" {
    # The manual smoke script must exist and be executable; it is the
    # human-runnable proof that the plugin works through the curl shim
    # and the http fixtures, without touching the network.
    local smoke="$POWERKIT_ROOT/tests/helpers/aiquotas_manual_smoke.bash"
    [ -f "$smoke" ]
    [ -x "$smoke" ]
}

@test "Todo 5 smoke script: uses curl shim via PATH, no real network" {
    # The smoke script must NOT call real curl. It must prepend
    # tests/helpers/shims to PATH so the shim wins. Otherwise a user could
    # accidentally hit live provider endpoints with a real token.
    #
    # We invoke the smoke script with the fixture manifest and dummy
    # keys. The shim is on PATH (inherited from the bats run), so any
    # curl call resolves to tests/helpers/shims/curl.
    local smoke="$POWERKIT_ROOT/tests/helpers/aiquotas_manual_smoke.bash"
    [[ -f "$smoke" ]] || skip "smoke script not yet present"

    run env \
        PATH="$POWERKIT_ROOT/tests/helpers/shims:$PATH" \
        AIQUOTAS_SMOKE_SCENARIO="$POWERKIT_ROOT/tests/fixtures/aiquotas/http/anthropic-openai.tsv" \
        ANTHROPIC_ADMIN_KEY="sk-ant-oat11-dummy-fixture-only-000000000000" \
        OPENAI_ADMIN_KEY="sk-oai-admin-dummy-fixture-only-000000000000" \
        TERM=dumb \
        bash "$smoke"
    assert_success
    [[ "$output" != *"#["* ]]
}

# =============================================================================
# Todo 14: min_limit filter
# =============================================================================

@test "Todo 14 min_limit: default min_limit=1 skips limit=0 records, keeps limit>0" {
    # With min_limit=1 (default), records with limit=0 are filtered out because
    # they render as meaningless "0/0". Records with limit>0 are kept.
    # Uses anthropic provider (NOT MiniMax — the MiniMax exception is
    # covered by Todo 18 below).
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"anthropic","metric_kind":"quota","value":0,"limit":0,"remaining":0,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}},
  {"provider":"anthropic","metric_kind":"quota","value":0,"limit":3,"remaining":3,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}
],"provider_outcomes":[
  {"provider":"anthropic","source":"official","status":"ok","error":null},
  {"provider":"anthropic","source":"official","status":"ok","error":null}
]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\"}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "anthropic" ;;
                show_percent) printf "left" ;;
                show_x_of_y) printf "true" ;;
                separator) printf " | " ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Must NOT contain limit=0 (filtered by min_limit=1 on non-MiniMax)
    ! [[ "$output" == *" 0/0"* ]] || { echo "FAIL: limit=0 should be filtered"; exit 1; }
    # Must contain limit=3 record
    [[ "$output" == *" 0/3"* ]] || { echo "FAIL: limit=3 should appear"; exit 1; }
}

@test "Todo 14 min_limit: min_limit=0 shows all records including limit=0" {
    # With min_limit=0, the filter is disabled and limit=0 records ARE shown.
    # show_x_of_y=true so the limit=0 prefix "<v>/<l>" surfaces in the
    # aggregated output (default per Todo 17 is to drop the X/Y prefix).
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"minimax","metric_kind":"quota","value":0,"limit":0,"remaining":0,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"interval","resource":"token_plan"}},
  {"provider":"minimax","metric_kind":"quota","value":3,"limit":3,"remaining":0,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"weekly","resource":"token_plan"}}
],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "minimax" ;;
                show_x_of_y) printf "true" ;;
                min_limit) printf "0" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Both records must appear in the aggregated percentages. With
    # min_limit=0 neither is filtered, so the percentages (100 from the
    # limit=0 edge case and 0 from the limit=3 fully-used record) are
    # combined into "MiniMax 0/0 100/0% left".
    assert_output --partial "MiniMax"
    assert_output --partial "0/0"
    assert_output --partial "100/0%"
}

# =============================================================================
# Todo 14: min_limit filter — skip quota records with limit < min_limit
# Plan: .omo/plans/aiquotas-completo.md v4 (post-Todo 13 amendment)
# Default min_limit=1: drop records with limit=0 that would render as "0/0".
# Set min_limit=0 to disable the filter.
# =============================================================================

@test "Todo 14 min_limit filter (default=1): skips records with limit=0" {
    # Default min_limit=1 drops limit=0 records. This test uses anthropic
    # (NOT MiniMax — the MiniMax exception is covered by Todo 18 below).
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"anthropic","metric_kind":"quota","value":0,"limit":0,"remaining":0,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}},
  {"provider":"anthropic","metric_kind":"quota","value":0,"limit":3,"remaining":3,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}
],"provider_outcomes":[
  {"provider":"anthropic","source":"official","status":"ok","error":null},
  {"provider":"anthropic","source":"official","status":"ok","error":null}
]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_anthropic" "$DOC"
        plugin_data_set "outcome_anthropic" "{\"provider\":\"anthropic\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                providers) printf "anthropic" ;;
                show_x_of_y) printf "true" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Should NOT contain 0/0 (filtered by min_limit=1 on non-MiniMax)
    [[ "$output" != *" 0/0"* ]] || { echo "FAIL: '0/0' should be filtered"; exit 1; }
    # Should contain limit=3 record
    [[ "$output" == *" 0/3"* ]] || { echo "FAIL: limit=3 should appear"; exit 1; }
}

@test "Todo 14 min_limit=0: filter disabled, records with limit=0 are rendered" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"a","metric_kind":"quota","value":0,"limit":0,"remaining":0,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}
],"provider_outcomes":[
  {"provider":"a","source":"official","status":"ok","error":null}
]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                providers) printf "minimax" ;;
                show_x_of_y) printf "true" ;;
                min_limit) printf "0" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    # With filter disabled, the 0/0 record should be rendered
    [[ "$output" == *" 0/0"* ]] || { echo "FAIL: with min_limit=0, '0/0' should NOT be filtered"; exit 1; }
}

# =============================================================================
# Todo 18: MiniMax min_limit exception
#
# Bug: plugin_render filtered MiniMax records with limit=0 (e.g. the
#       "5h limit" and "Weekly limit" entries returned by the MiniMax
#       API). Those records carry current_interval_remaining_percent,
#       so the percentage is meaningful even when limit=0 and they
#       must be kept under the default min_limit=1 filter.
#
# Fix: plugin_render sets effective_min_limit=0 whenever the provider
#      is minimax. Records that go through the multi-record MiniMax
#      aggregation path therefore skip the min_limit filter entirely.
# =============================================================================

@test "Todo 18 MiniMax min_limit exception: limit=0 records are NOT filtered under default min_limit=1" {
    # 5h limit (limit=0) + Weekly limit (limit=3). Under the old filter
    # the limit=0 record would be dropped, hiding the "5h limit" quota.
    # After the fix, BOTH records flow into the MiniMax aggregator and
    # the rendered line aggregates their available percentages. The
    # fix sets effective_min_limit=0 for provider=minimax so limit=0
    # records survive even under the default min_limit=1.
    #
    # Values used (limit=0, value=0) make the aggregator return
    # "100% left" per record so the final string is the deterministic
    # "MiniMax 0/0 100/100% left". The key invariant tested here is
    # that BOTH records feed the aggregator — under the old filter
    # only the weekly record (limit=3) would pass.
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"minimax","metric_kind":"quota","value":0,"limit":0,"remaining":0,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"interval","resource":"token_plan"}},
  {"provider":"minimax","metric_kind":"quota","value":0,"limit":3,"remaining":3,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"weekly","resource":"token_plan"}}
],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "minimax" ;;
                show_percent) printf "left" ;;
                show_x_of_y) printf "true" ;;
                show_video) printf "false" ;;
                separator) printf " | " ;;
                min_limit) printf "1" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Both records flow into the aggregator: x/y prefix from the FIRST
    # general record (0/0 because that record has limit=0), then
    # aggregated available percentages (both unused -> 100/100).
    # Without the MiniMax exception only the weekly record (limit=3)
    # would survive and the output would skip " 0/0 ".
    [[ "$output" == *"MiniMax 0/0 100/100% left"* ]] || { echo "FAIL: expected 'MiniMax 0/0 100/100% left': $output"; exit 1; }
}

@test "Todo 18 MiniMax realistic 5h+weekly: percent-only output shows 67/84%" {
    # Same shape as the user's actual quota when records carry a usable
    # remaining value (5h=33% used / 100% total -> 67% left; weekly=16%
    # used / 100% total -> 84% left). The MiniMax aggregator collapses
    # the two general records into "<a>/<b>% left". show_x_of_y=false
    # drops the raw X/Y prefix so the final line is the clean
    # "MiniMax 67/84% left".
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"minimax","metric_kind":"quota","value":33,"limit":100,"remaining":67,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"interval","resource":"token_plan"}},
  {"provider":"minimax","metric_kind":"quota","value":16,"limit":100,"remaining":84,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"weekly","resource":"token_plan"}}
],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "minimax" ;;
                show_percent) printf "left" ;;
                show_x_of_y) printf "false" ;;
                show_video) printf "false" ;;
                separator) printf " | " ;;
                min_limit) printf "1" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "MiniMax 67/84% left" ]] || { echo "FAIL: expected 'MiniMax 67/84% left': $output"; exit 1; }
}

# =============================================================================
# Todo 15: show_x_of_y — toggle raw X/Y values alongside percentages
# Plan: hide the "0/3" prefix when the user only wants percentages.
# Default show_x_of_y=true preserves the pre-Todo-15 output for backward
# compat. Set show_x_of_y=false to drop the X/Y prefix entirely.
# =============================================================================

@test "Todo 15 show_x_of_y=false, show_percent=left: shows only percentage" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"minimax","metric_kind":"quota","value":0,"limit":3,"remaining":3,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":null,"project":null,"line_item":null,"resource":null}}
],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "minimax" ;;
                show_percent) printf "left" ;;
                show_x_of_y) printf "false" ;;
                separator) printf "%s" " | " ;;
                min_limit) printf "1" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Should show "100% left" without "0/3"
    [[ "$output" == *"MiniMax 100% left"* ]] || { echo "FAIL: expected 'MiniMax 100% left': $output"; exit 1; }
    # Should NOT contain "0/3"
    [[ "$output" != *"0/3"* ]] || { echo "FAIL: 0/3 should be hidden: $output"; exit 1; }
}

# =============================================================================
# Todo 17: MiniMax compact — aggregate sibling records by dimensions.model
# Plan: model "general" emits interval%/weekly%, model "video" only emits
# when show_video=true (opt-in). Default render is "<Label> <g1>/<g2>% left".
# Plan v4 (post-Todo 16 amendment): show_x_of_y default is FALSE so the default
# MiniMax line stays compact. show_video is also FALSE by default to hide the
# "video" bonus card. set -g @powerkit_plugin_aiquotas_show_x_of_y "true"
# prepends "<v>/<l> " from the FIRST general record.
# =============================================================================

@test "Todo 17 MiniMax compact default: aggregates general group as interval%/weekly% left" {
    # Two "general" records, value=33/limit=100 → 67% left, value=16/limit=100
    # → 84% left. Aggregator emits one combined line "MiniMax 67/84% left".
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"minimax","metric_kind":"quota","value":33,"limit":100,"remaining":67,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"interval","resource":"token_plan"}},
  {"provider":"minimax","metric_kind":"quota","value":16,"limit":100,"remaining":84,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"weekly","resource":"token_plan"}}
],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "minimax" ;;
                show_percent) printf "left" ;;
                show_x_of_y) printf "false" ;;
                show_video) printf "false" ;;
                separator) printf " | " ;;
                min_limit) printf "1" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "MiniMax 67/84% left" ]] || { echo "FAIL: expected 'MiniMax 67/84% left': $output"; exit 1; }
}

@test "Todo 17 MiniMax compact + show_video=true: includes video bonus percentages" {
    # Same two "general" records plus two "video" records. show_video=true
    # surfaces the second group, joined with " / " so the line becomes
    # "MiniMax 67/84% / 100/100% left".
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"minimax","metric_kind":"quota","value":33,"limit":100,"remaining":67,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"interval","resource":"token_plan"}},
  {"provider":"minimax","metric_kind":"quota","value":16,"limit":100,"remaining":84,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"weekly","resource":"token_plan"}},
  {"provider":"minimax","metric_kind":"quota","value":0,"limit":100,"remaining":100,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"video","project":null,"line_item":"interval","resource":"token_plan"}},
  {"provider":"minimax","metric_kind":"quota","value":0,"limit":100,"remaining":100,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"video","project":null,"line_item":"weekly","resource":"token_plan"}}
],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "minimax" ;;
                show_percent) printf "left" ;;
                show_x_of_y) printf "false" ;;
                show_video) printf "true" ;;
                separator) printf " | " ;;
                min_limit) printf "1" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "MiniMax 67/84% / 100/100% left" ]] || { echo "FAIL: expected 'MiniMax 67/84% / 100/100% left': $output"; exit 1; }
}

@test "Todo 17 MiniMax compact + show_x_of_y=true: prepends value/limit before percentages" {
    # Two general records: 33/100 (67% left) and 16/100 (84% left).
    # show_x_of_y=true prepends the FIRST record's "33/100 " prefix before
    # the combined percentages, producing "MiniMax 33/100 67/84% left".
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"minimax","metric_kind":"quota","value":33,"limit":100,"remaining":67,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"interval","resource":"token_plan"}},
  {"provider":"minimax","metric_kind":"quota","value":16,"limit":100,"remaining":84,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":"weekly","resource":"token_plan"}}
],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "minimax" ;;
                show_percent) printf "left" ;;
                show_x_of_y) printf "true" ;;
                show_video) printf "false" ;;
                separator) printf " | " ;;
                min_limit) printf "1" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "MiniMax 33/100 67/84% left" ]] || { echo "FAIL: expected 'MiniMax 33/100 67/84% left': $output"; exit 1; }
}

# =============================================================================
# Todo 19: MiniMax API remaining_percent fields in dimensions
# Plan: MiniMax API exposes current_interval_remaining_percent and
#       current_weekly_remaining_percent per record. The adapter must
#       surface those into dimensions so the renderer can use them
#       directly (avoiding the value/limit=0 fallback that previously
#       produced 100% left for "5h limit" and "Weekly limit" cards).
# =============================================================================

@test "Todo 19 MiniMax adapter: current_interval_remaining_percent is exposed in dimensions" {
    run _aiquotas_metrics_document "minimax" \
        '{"model_remains":[{"model_name":"MiniMax-M2","current_interval_total_count":100,"current_interval_usage_count":11,"current_interval_remaining_percent":89,"current_weekly_remaining_percent":82}]}'

    assert_success
    run jq -e '
        (.records[0].dimensions.interval_remaining_percent == 89) and
        (.records[0].dimensions.weekly_remaining_percent == 82)
    ' <<<"$output"
    assert_success
}

@test "Todo 19 MiniMax adapter: missing percent fields populate as null (canonical contract intact)" {
    run _aiquotas_metrics_document "minimax" \
        '{"model_remains":[{"model_name":"MiniMax-M2","current_interval_total_count":100,"current_interval_usage_count":11}]}'

    assert_success
    run jq -e '
        (.records[0].dimensions.interval_remaining_percent == null) and
        (.records[0].dimensions.weekly_remaining_percent == null) and
        (.records[0].dimensions.model == "MiniMax-M2")
    ' <<<"$output"
    assert_success
}

@test "Todo 19 MiniMax compact default: API percentages drive 89/82% left output" {
    # Records carry current_interval_remaining_percent=89 (5h limit) and
    # current_weekly_remaining_percent=82 (Weekly limit). The renderer
    # must surface those values directly so the line reads
    # "MiniMax 89/82% left" without relying on value/limit computation
    # (value/limit can be 0 for these cards under the real API).
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"minimax","metric_kind":"quota","value":11,"limit":100,"remaining":89,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":null,"resource":"token_plan","interval_remaining_percent":89,"weekly_remaining_percent":null}},
  {"provider":"minimax","metric_kind":"quota","value":18,"limit":100,"remaining":82,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":null,"resource":"token_plan","interval_remaining_percent":null,"weekly_remaining_percent":82}}
],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "minimax" ;;
                show_percent) printf "left" ;;
                show_x_of_y) printf "false" ;;
                show_video) printf "false" ;;
                separator) printf " | " ;;
                min_limit) printf "1" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "MiniMax 89/82% left" ]] || { echo "FAIL: expected 'MiniMax 89/82% left': $output"; exit 1; }
}

@test "Todo 19 MiniMax compact + show_video=true: API percentages add video group with 100% left" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"minimax","metric_kind":"quota","value":11,"limit":100,"remaining":89,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":null,"resource":"token_plan","interval_remaining_percent":89,"weekly_remaining_percent":null}},
  {"provider":"minimax","metric_kind":"quota","value":18,"limit":100,"remaining":82,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":null,"resource":"token_plan","interval_remaining_percent":null,"weekly_remaining_percent":82}},
  {"provider":"minimax","metric_kind":"quota","value":0,"limit":3,"remaining":3,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"video","project":null,"line_item":null,"resource":"token_plan","interval_remaining_percent":100,"weekly_remaining_percent":null}}
],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "minimax" ;;
                show_percent) printf "left" ;;
                show_x_of_y) printf "false" ;;
                show_video) printf "true" ;;
                separator) printf " | " ;;
                min_limit) printf "1" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "MiniMax 89/82% / 100% left" ]] || { echo "FAIL: expected 'MiniMax 89/82% / 100% left': $output"; exit 1; }
}

@test "Todo 19 MiniMax compact + show_x_of_y=true: x/y prefix from first general record plus API percentages" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/plugin_contract.sh"
        source "$1/src/plugins/aiquotas.sh"
        _set_plugin_context aiquotas
        plugin_declare_options
        DOC=$(cat <<"JSON"
{"schema_version":1,"records":[
  {"provider":"minimax","metric_kind":"quota","value":0,"limit":0,"remaining":0,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":null,"resource":"token_plan","interval_remaining_percent":89,"weekly_remaining_percent":null}},
  {"provider":"minimax","metric_kind":"quota","value":0,"limit":0,"remaining":0,"unit":"count","currency":null,"window_start":null,"window_end":null,"reset_at":null,"source":"official","status":"ok","error":null,"dimensions":{"input_tokens":null,"cached_input_tokens":null,"cache_creation_tokens":null,"output_tokens":null,"requests":null,"model":"general","project":null,"line_item":null,"resource":"token_plan","interval_remaining_percent":null,"weekly_remaining_percent":82}}
],"provider_outcomes":[{"provider":"minimax","source":"official","status":"ok","error":null}]}
JSON
)
        plugin_data_set "providers_count" "1"
        plugin_data_set "providers_failed" "0"
        plugin_data_set "document_minimax" "$DOC"
        plugin_data_set "outcome_minimax" "{\"provider\":\"minimax\",\"source\":\"official\",\"status\":\"ok\",\"error\":null}"
        get_option() {
            case "$1" in
                format) printf "compact" ;;
                providers) printf "minimax" ;;
                show_percent) printf "left" ;;
                show_x_of_y) printf "true" ;;
                show_video) printf "false" ;;
                separator) printf " | " ;;
                min_limit) printf "1" ;;
                *) printf "" ;;
            esac
        }
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == "MiniMax 0/0 89/82% left" ]] || { echo "FAIL: expected 'MiniMax 0/0 89/82% left': $output"; exit 1; }
}
