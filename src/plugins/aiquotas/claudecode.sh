#!/usr/bin/env bash
# =============================================================================
# aiquotas adapter — claudecode (Claude subscription: Pro / Max / Team)
# =============================================================================
# Companion adapter for the aiquotas plugin. Provides
# _aiquotas_collect_claudecode, which emits a canonical metrics document for
# the Claude subscription usage windows.
#
# Loaded lazily by _aiquotas_load_provider in the entry point. NEVER source this
# file directly — go through the loader.
#
# Endpoint: GET https://api.anthropic.com/api/oauth/usage
# Auth:     Authorization: Bearer <OAuth access token>
# Shape:    {limits:[{kind,group,percent,severity,resets_at,scope,is_active}],
#            five_hour:{utilization,resets_at,...},
#            seven_day:{utilization,resets_at,...}, extra_usage:{...}, ...}
#           kind = session | weekly_all | weekly_scoped
#           percent = % CONSUMED; remaining% = 100 - percent.
#
# This is the same undocumented endpoint the `claude /usage` command calls; it
# is not in the public API reference. Normalization lives in emit_claudecode in
# _metrics.sh, which classifies rows on `.kind` (never on a display label, per
# the schema Claude Code itself ships) and tolerates missing keys, because the
# response carries a number of null-valued codenames for window types that have
# not shipped yet.
#
# DISTINCT FROM the `anthropic` adapter, which reads the Admin API usage and
# cost reports with an ANTHROPIC_ADMIN_KEY. That is org-wide API token spend and
# contains no subscription window at all. The two are complementary, not
# alternatives.
#
# --- Recommended setup: a long-lived token via `claude setup-token` ----------
#
# Run `claude setup-token` once and export the printed token as
# CLAUDE_CODE_OAUTH_TOKEN in your shell profile (so tmux inherits it). Claude
# Code documents this as a one-year OAuth token for non-interactive use, and it
# is the only path that works on every platform: on macOS the interactive
# login stores credentials in the Keychain, and ~/.claude/.credentials.json
# only exists there as a fallback (locked Keychain, SSH sessions). On Linux and
# Windows the credentials file is the primary store, so the fallback below
# works out of the box, subject to caveat 1.
#
# --- Two operational caveats, both confirmed against the live endpoint --------
#
# 1. The interactive-login access token in the credentials file is short-lived
#    (roughly hourly) and ONLY Claude Code refreshes it. The file is therefore
#    re-read on every collect and the token is never cached here. Expect
#    intermittent `unauthorized` when Claude Code has not run for a while; the
#    lifecycle keeps the previous value and marks it stale, which is the right
#    outcome. A setup-token in CLAUDE_CODE_OAUTH_TOKEN sidesteps this entirely.
#
# 2. The endpoint rate-limits aggressively: roughly eight requests in quick
#    succession returned 429 for about five minutes. Users should keep
#    @powerkit_plugin_aiquotas_cache_ttl at the default (300) or higher rather
#    than polling this provider hard. A 429 maps to `rate_limited` through the
#    shared status mapper, so it degrades rather than blanking the segment.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "aiquotas_claudecode" && return 0

# -----------------------------------------------------------------------------
# Token resolution
# -----------------------------------------------------------------------------
# CLAUDE_CODE_OAUTH_TOKEN wins when set. It is the variable Claude Code itself
# accepts for headless auth and the one `claude setup-token` is meant for, so it
# is the recommended configuration (see header). Otherwise read
# claudeAiOauth.accessToken out of the credentials file, the same way the
# openai adapter reads the Codex OAuth file.
#
# Prints the token on stdout, or nothing when none can be resolved.
_aiquotas_claudecode_token() {
    if [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
        printf '%s' "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi

    local creds
    creds=$(get_option "claudecode_credentials_file")
    # tmux option values are not shell-expanded, so a leading ~/ is literal.
    # Only the bare-home form is expanded; ~user/... is left untouched rather
    # than being silently rewritten under the current $HOME.
    if [[ "$creds" == "~" ]]; then
        creds="$HOME"
    elif [[ "$creds" == \~/* ]]; then
        creds="${HOME}/${creds#\~/}"
    fi
    [[ -n "$creds" && -r "$creds" ]] || return 0

    jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Claude Code adapter
# -----------------------------------------------------------------------------
#
# Reads the subscription usage endpoint and emits one quota record for the
# 5-hour window, with the weekly window as a dimension. Treats the data as
# `official` only when a token could be resolved.
#
# Returns the canonical JSON document on stdout. Exits 0 even on partial
# failure (the provider_outcomes entry carries the error); exits non-zero only
# when jq cannot assemble the envelope at all.
#
_aiquotas_collect_claudecode() {
    local token
    token=$(_aiquotas_claudecode_token)

    if [[ -z "$token" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"claudecode",source:"official",
                                 status:"unconfigured",
                                 error:"no Claude OAuth token: set CLAUDE_CODE_OAUTH_TOKEN or log in with Claude Code"}]}
        '
        return 0
    fi

    local url timeout body status
    url=$(get_option "claudecode_usage_url")
    timeout=$(get_option "timeout")
    timeout="${timeout:-5}"

    if [[ -z "$url" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"claudecode",source:"official",
                                 status:"unconfigured",
                                 error:"claudecode usage URL not configured"}]}
        '
        return 0
    fi

    # The credential travels via stdin so it never appears in argv.
    body=$(_aiquotas_http_get_meta_authed \
        "$url" "$timeout" \
        "Authorization" "Bearer $token" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json") || body=""
    status=$(_aiquotas_last_status)

    if [[ -z "$body" ]]; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"claudecode",source:"official",
                                 status:"unavailable",
                                 error:"usage fetch transport failure"}]}
        '
        return 0
    fi

    # 401 here is the expected shape of an expired token rather than a
    # misconfiguration, and 429 is the rate limit described in the header.
    # Both map through the shared status mapper.
    if [[ "$status" != 2* ]]; then
        local canonical_status canonical_error
        canonical_status=$(_aiquotas_http_status_to_canonical "$status")
        canonical_error=$(_aiquotas_http_status_error_message "$body" "usage")
        jq -nc \
            --arg st "$canonical_status" \
            --arg er "$canonical_error" \
            '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"claudecode",source:"official",
                                 status:$st, error:$er}]}
            '
        return 0
    fi

    if ! _aiquotas_metrics_document "claudecode" "$body" 2>/dev/null; then
        jq -nc '
            {schema_version:1, records:[],
             provider_outcomes:[{provider:"claudecode",source:"official",
                                 status:"malformed",
                                 error:"usage payload normalization failed"}]}
        '
        return 0
    fi
}
