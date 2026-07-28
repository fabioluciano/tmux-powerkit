#!/usr/bin/env bats
# =============================================================================
# BATS tests for the security and reliability contracts introduced by
# the recent fixes:
#   - credentials never appear in curl argv
#   - argv-based dispatch for helpers (no shell interpolation)
#   - all-failed returns nonzero so the lifecycle can keep stale cache
#   - validate_ip / validate_json guard API plugins
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
    mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"
    export PATH="$mock_dir:$PATH"
}

# Helper: stub safe_curl/curl with a recording script
_capture_curl_argv() {
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
# Record every argv element to a file so tests can grep for tokens.
{
    printf 'ARGVS:'
    for a in "$@"; do printf '|%s' "$a"; done
    printf '\n'
} >>"$CURL_LOG_FILE"
# Return success with an empty body unless the test overrides behaviour.
[[ -f "$CURL_BODY_FILE" ]] && cat "$CURL_BODY_FILE" || true
EOF
    chmod +x "$mock_dir/curl"
    export CURL_LOG_FILE="$BATS_TEST_TMPDIR/curl.log"
    export CURL_BODY_FILE="$BATS_TEST_TMPDIR/curl.body"
    : >"$CURL_LOG_FILE"
    : >"$CURL_BODY_FILE"
}

# Helper: assert argv captured by _capture_curl_argv does NOT contain a token
assert_argv_does_not_contain() {
    local token="$1"
    run grep -F -- "$token" "$CURL_LOG_FILE"
    assert_failure
}

# Helper: assert argv captured by _capture_curl_argv DOES contain a token
assert_argv_contains() {
    local token="$1"
    run grep -F -- "$token" "$CURL_LOG_FILE"
    assert_success
}

# =============================================================================
# jira.sh — basic auth via curl --config
# =============================================================================

@test "jira: email+token are NOT in curl argv" {
    _capture_curl_argv
    cat >"$CURL_BODY_FILE" <<'JSON'
{"issues":[],"isLast":true}
JSON

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/jira.sh"
        get_option() {
            case "$1" in
                domain) printf "example.atlassian.net" ;;
                email) printf "user@example.com" ;;
                token) printf "PK_TOKEN_SECRET_abc123" ;;
                jql)   printf "assignee = currentUser()" ;;
                project) printf "" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context jira
        plugin_collect || true
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_argv_does_not_contain "PK_TOKEN_SECRET_abc123"
    assert_argv_does_not_contain "user@example.com"
}

# =============================================================================
# gitlab.sh — PRIVATE-TOKEN via stdin
# =============================================================================

@test "gitlab: PRIVATE-TOKEN is NOT in curl argv" {
    _capture_curl_argv
    cat >"$CURL_BODY_FILE" <<'JSON'
{"statistics":{"counts":{"opened":7}}}
JSON

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/gitlab.sh"
        get_option() {
            case "$1" in
                url)   printf "https://gitlab.example.com" ;;
                token) printf "glpat-PK_GITLAB_SECRET_xyz" ;;
                repos) printf "group/project" ;;
                show_issues) printf "true" ;;
                show_mrs)    printf "false" ;;
                separator)   printf " " ;;
                icon_issue)  printf "I" ;;
                icon_mr)     printf "M" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context gitlab
        plugin_collect || true
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_argv_does_not_contain "glpat-PK_GITLAB_SECRET_xyz"
}

# =============================================================================
# github.sh — Authorization via stdin
# =============================================================================

@test "github: token is NOT in curl argv" {
    _capture_curl_argv
    cat >"$CURL_BODY_FILE" <<'JSON'
{"total_count":3}
JSON

    # github uses safe_curl directly, with token in header via stdin.
    # Stub the gh CLI and curl. The test verifies that the token does not
    # appear in any captured argv element.
    cat >"$mock_dir/gh" <<'GH'
#!/usr/bin/env bash
exit 0
GH
    chmod +x "$mock_dir/gh"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        get_option() {
            case "$1" in
                token) printf "ghp_PK_GITHUB_SECRET_qwerty" ;;
                repos) printf "" ;;
                filter_user) printf "" ;;
                show_issues) printf "true" ;;
                show_prs)    printf "true" ;;
                warning_threshold_issues) printf "10" ;;
                warning_threshold_prs)    printf "10" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context github
        plugin_collect || true
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_argv_does_not_contain "ghp_PK_GITHUB_SECRET_qwerty"
}

@test "github _verify_token: token is NOT in curl argv when gh is absent" {
    # Force the _verify_token path by NOT providing gh (so gh auth
    # status short-circuits fails). Falls through to the API path
    # which used to leak the token via make_api_call.
    _capture_curl_argv
    cat >"$CURL_BODY_FILE" <<'JSON'
{"login":"octocat"}
JSON

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        PATH="/usr/bin:/bin"   # remove the mock gh from PATH
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        get_option() {
            case "$1" in
                token) printf "ghp_PK_GITHUB_VERIFY_SECRET_zzzz" ;;
                repos) printf "" ;;
                filter_user) printf "" ;;
                show_issues) printf "true" ;;
                show_prs)    printf "true" ;;
                warning_threshold_issues) printf "10" ;;
                warning_threshold_prs)    printf "10" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context github
        # Stub only curl (not gh). The plugin should call _verify_token
        # which now uses api_fetch_with_token_header (stdin).
        plugin_collect || true
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_argv_does_not_contain "ghp_PK_GITHUB_VERIFY_SECRET_zzzz"
    # And no "Authorization: token" should appear in argv either
    assert_argv_does_not_contain "Authorization: token"
}

# =============================================================================
# externalip.sh — validate IP
# =============================================================================

@test "externalip: rejects non-IP text and returns nonzero" {
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo "<html>captive portal login</html>"
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/externalip.sh"
        get_option() { printf "PK_ICON"; }
        _set_plugin_context externalip
        plugin_collect
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "externalip: accepts a valid IPv4" {
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo "203.0.113.42"
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/externalip.sh"
        get_option() { printf "PK_ICON"; }
        _set_plugin_context externalip
        plugin_collect
        printf "ip=%s" "$(plugin_data_get ip)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ip=203.0.113.42"
}

# =============================================================================
# cloudstatus — unknown provider does not report operational
# =============================================================================

@test "cloudstatus: surfaces unknown provider as '?'" {
    # Stub curl to return a payload that jq can parse but does not
    # contain a recognised status indicator (unknown).
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo '{"status":{"indicator":"unknown"}}'
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cloudstatus.sh"
        get_option() {
            case "$1" in
                providers) printf "cloudflare" ;;
                separator) printf " " ;;
                issues_only) printf "false" ;;
                timeout) printf "5" ;;
                icon) printf "I" ;;
                icon_warning) printf "W" ;;
                icon_error) printf "E" ;;
                cache_ttl) printf "300" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context cloudstatus
        plugin_collect || true
        printf "output=%s" "$(plugin_data_get output)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "?"
}

# =============================================================================
# crypto.sh — all-failed returns nonzero
# =============================================================================

@test "crypto: all-failed returns nonzero" {
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo "not json at all"
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/crypto.sh"
        get_option() {
            case "$1" in
                coins) printf "bitcoin,ethereum" ;;
                currency) printf "usd" ;;
                show_change) printf "false" ;;
                format) printf "compact" ;;
                separator) printf " " ;;
                icon) printf "C" ;;
                cache_ttl) printf "60" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context crypto
        plugin_collect
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# stocks.sh — all-failed returns nonzero
# =============================================================================

@test "stocks: all-failed returns nonzero" {
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo "<html>not the yahoo API</html>"
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/stocks.sh"
        get_option() {
            case "$1" in
                tickers) printf "AAPL,GOOG" ;;
                show_ticker) printf "true" ;;
                show_change) printf "true" ;;
                format) printf "short" ;;
                separator) printf " " ;;
                icon) printf "S" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context stocks
        plugin_collect
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# bitbucket.sh — all-failed returns nonzero
# =============================================================================

@test "bitbucket: all-failed returns nonzero" {
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo "rate limit exceeded"
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bitbucket.sh"
        get_option() {
            case "$1" in
                repos) printf "owner/repo" ;;
                show_issues) printf "true" ;;
                show_prs)    printf "true" ;;
                type)        printf "cloud" ;;
                email)       printf "u@e.com" ;;
                token)       printf "t" ;;
                url)         printf "" ;;
                workspace)   printf "" ;;
                separator)   printf " " ;;
                icon_issue)  printf "I" ;;
                icon_pr)     printf "P" ;;
                icon)        printf "B" ;;
                format)      printf "compact" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context bitbucket
        plugin_collect
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "bitbucket cloud: email+token are NOT in curl argv" {
    _capture_curl_argv
    cat >"$CURL_BODY_FILE" <<'JSON'
{"size":3,"values":[]}
JSON

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bitbucket.sh"
        get_option() {
            case "$1" in
                repos) printf "owner/repo" ;;
                show_issues) printf "true" ;;
                show_prs)    printf "true" ;;
                type)        printf "cloud" ;;
                email)       printf "u@PK_BITBUCKET_SECRET.com" ;;
                token)       printf "PK_BITBUCKET_SECRET" ;;
                url)         printf "" ;;
                workspace)   printf "" ;;
                separator)   printf " " ;;
                icon_issue)  printf "I" ;;
                icon_pr)     printf "P" ;;
                icon)        printf "B" ;;
                format)      printf "compact" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context bitbucket
        plugin_collect || true
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_argv_does_not_contain "PK_BITBUCKET_SECRET"
    assert_argv_does_not_contain "u@PK_BITBUCKET_SECRET.com"
}

@test "bitbucket datacenter: token is NOT in curl argv" {
    _capture_curl_argv
    cat >"$CURL_BODY_FILE" <<'JSON'
{"size":3,"values":[]}
JSON

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bitbucket.sh"
        get_option() {
            case "$1" in
                repos) printf "owner/repo" ;;
                show_issues) printf "true" ;;
                show_prs)    printf "true" ;;
                type)        printf "datacenter" ;;
                token)       printf "PK_BITBUCKET_DC_SECRET" ;;
                url)         printf "https://bitbucket.example.com" ;;
                workspace)   printf "" ;;
                separator)   printf " " ;;
                icon_issue)  printf "I" ;;
                icon_pr)     printf "P" ;;
                icon)        printf "B" ;;
                format)      printf "compact" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context bitbucket
        plugin_collect || true
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_argv_does_not_contain "PK_BITBUCKET_DC_SECRET"
}

# =============================================================================
# jira — malformed JSON returns nonzero
# =============================================================================

@test "jira: malformed body returns nonzero" {
    _capture_curl_argv
    cat >"$CURL_BODY_FILE" <<'EOF'
not json
EOF

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/jira.sh"
        get_option() {
            case "$1" in
                domain) printf "example.atlassian.net" ;;
                email) printf "u@e.com" ;;
                token) printf "t" ;;
                jql)   printf "project = X" ;;
                project) printf "" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context jira
        plugin_collect
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# weather — _release_rate_limit decrements counter on failure
# =============================================================================

@test "weather: _release_rate_limit rolls back the counter" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        export XDG_CACHE_HOME="$2/cache"
        mkdir -p "$XDG_CACHE_HOME"
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/weather.sh"
        get_option() { printf "5"; }
        # Reserve a slot
        _check_rate_limit
        before=$(cache_get "weather_rate_limit:$(date +%Y%m%d%H)" 3600)
        # Release it
        _release_rate_limit
        after=$(cache_get "weather_rate_limit:$(date +%Y%m%d%H)" 3600)
        printf "before=%s after=%s" "$before" "$after"
    ' _ "$POWERKIT_ROOT" "$BATS_TEST_TMPDIR"
    assert_success
    # before is "1" (one slot reserved), after is "0" (released)
    [[ "$output" == "before=1 after=0" ]]
}

# =============================================================================
# helpers — argv-based dispatch (smoke)
# =============================================================================

@test "audiodevices: _pk_set_input exists and validates name" {
    # Static check: the helper defines _pk_set_input and uses an
    # allowlist regex that rejects shell metacharacters.
    run bash -c '
        grep -A 18 "^_pk_set_input()" "$1/src/helpers/audiodevices_selector.sh"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "valid name"
    # Allowlist regex is present
    grep -q 'A-Za-z0-9._:/@+=,-' "$POWERKIT_ROOT/src/helpers/audiodevices_selector.sh"
}

@test "terraform: _pk_tf_switch exists and validates path" {
    # Static check: the helper defines _pk_tf_switch and validates
    # the pane_path against a safe regex.
    run bash -c '
        grep -A 6 "^_pk_tf_switch()" "$1/src/helpers/terraform_workspace_selector.sh" | head -12
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "pane_path"
    # Allowlist regex is present
    grep -q 'A-Za-z0-9._+' "$POWERKIT_ROOT/src/helpers/terraform_workspace_selector.sh"
}

# =============================================================================
# src/utils/api.sh — new helpers
# =============================================================================

@test "api_validate_ip accepts a valid IPv4" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_validate_ip "203.0.113.42"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_validate_ip rejects arbitrary text" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_validate_ip "<html>portal</html>"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "api_validate_ip rejects IPv4 with out-of-range octet" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_validate_ip "999.0.0.1"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "api_validate_json accepts parseable JSON" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_validate_json "{\"a\":1}"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_validate_json rejects malformed JSON" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_validate_json "not json"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "api_classify_outcome maps HTTP status codes" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for s in 200 401 403 404 429 500 0; do
            api_classify_outcome "$s"
        done
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "success"
    assert_output --partial "unauthorized"
    assert_output --partial "forbidden"
    assert_output --partial "not_found"
    assert_output --partial "rate_limited"
    assert_output --partial "server_error"
    assert_output --partial "transport_error"
}

# =============================================================================
# binary_manager — trap + atomic install
# =============================================================================

@test "binary_manager: binary_download trap removes temp on failure (no -I flag)" {
    # We don't run the full installer (it would contact GitHub). We
    # only verify that the function's body contains the trap that
    # guarantees cleanup, and that the structure has a staged install
    # before the final mv -f.
    run bash -c '
        grep -E "trap .* RETURN" "$1/src/core/binary_manager.sh" | head -2
        grep -E "staged_file" "$1/src/core/binary_manager.sh" | head -3
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "RETURN"
    assert_output --partial "staged_file"
}

# =============================================================================
# bw_session cleanup on failure
# =============================================================================

@test "bitwarden: _unlock_bitwarden_bw calls clear_bw_session on the auth-failure path" {
    # Static check: the function must contain a clear_bw_session call
    # in the else branch where the password is rejected.
    run bash -c '
        awk "/_unlock_bitwarden_bw\\(\\)/,/^}/" "$1/src/helpers/_bitwarden_common.sh"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "clear_bw_session"
}

@test "bitwarden: _unlock_bitwarden_bw returns 130 on Ctrl-C instead of recursing" {
    # Static check for the Ctrl-C exit branch
    run bash -c '
        grep -A 2 "130" "$1/src/helpers/_bitwarden_common.sh" | head -8
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "clear_bw_session"
}

# =============================================================================
# TOTP code never appears in toast text
# =============================================================================

@test "bitwarden: totp_selector does not interpolate TOTP into toast" {
    run bash -c '
        # The toast calls should not contain $totp_code.
        grep -n "toast.*totp_code" "$1/src/helpers/bitwarden_totp_selector.sh" || true
    ' _ "$POWERKIT_ROOT"
    assert_success
    # No matches: the interpolation was removed
    [ -z "$output" ]
}
