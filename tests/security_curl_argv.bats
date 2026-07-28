#!/usr/bin/env bash
# =============================================================================
# Security regression: curl argv must never contain credential material.
# Plan: .beads/issues/tmux-powerkit-7x8
#
# Each test sources a powerkit helper that performs an authenticated
# request, then verifies via the deterministic curl shim that argv
# contains NO credential substring. Credentials must travel through
# --config - (stdin) or be absent entirely from non-auth helpers.
# =============================================================================

load 'helpers/test_helper'

setup() {
    setup_test_root
    unset TMUX
}

# Install a curl shim that records argv and returns a stub body.
# Usage: _install_curl_argv_recorder <state_dir>
_install_curl_argv_recorder() {
    local state_dir="$1"
    mkdir -p "$state_dir/bin"
    cat >"$state_dir/bin/curl" <<'SHIM'
#!/usr/bin/env bash
# argv recorder: dumps each arg as a separate line, exits 0
printf '%s\n' "$@" >"$AIQUOTAS_ARGV_LOG"
printf '{}'
SHIM
    chmod +x "$state_dir/bin/curl"
}

# Assert that argv contained no credential substring.
# Usage: assert_argv_clean "<logfile>" "<substring>"
assert_argv_clean() {
    local logfile="$1"
    local needle="$2"
    if grep -F -q -- "$needle" "$logfile" 2>/dev/null; then
        echo "FAIL: credential substring '$needle' leaked into curl argv:"
        cat "$logfile"
        return 1
    fi
}

# =============================================================================
# api.sh: api_fetch_with_auth (uses --config stdin)
# =============================================================================

@test "security: api_fetch_with_auth does not leak Authorization to argv" {
    local state_dir="$(mktemp -d -t aqt.argv.XXXXXX)"
    _install_curl_argv_recorder "$state_dir"
    export AIQUOTAS_ARGV_LOG="$state_dir/argv.log"

    run env PATH="$state_dir/bin:$PATH" \
        bash -c '
            source "$1/src/core/bootstrap.sh"
            source "$1/src/utils/api.sh"
            api_fetch_with_auth "https://api.example.com/x" "Bearer SECRET_TOKEN_AAA"
        ' _ "$POWERKIT_ROOT"

    assert_success
    assert_argv_clean "$state_dir/argv.log" "SECRET_TOKEN_AAA"
    rm -rf "$state_dir"
}

@test "security: api_fetch_with_auth basic auth does not leak credential" {
    local state_dir="$(mktemp -d -t aqt.argv.XXXXXX)"
    _install_curl_argv_recorder "$state_dir"
    export AIQUOTAS_ARGV_LOG="$state_dir/argv.log"

    run env PATH="$state_dir/bin:$PATH" \
        bash -c '
            source "$1/src/core/bootstrap.sh"
            source "$1/src/utils/api.sh"
            api_fetch_with_auth "https://api.example.com/x" "Basic dXNlcjpwYXNz"
        ' _ "$POWERKIT_ROOT"

    assert_success
    assert_argv_clean "$state_dir/argv.log" "dXNlcjpwYXNz"
    rm -rf "$state_dir"
}

# =============================================================================
# network.sh: safe_curl_with_auth (Basic via stdin)
# =============================================================================

@test "security: safe_curl_with_auth does not leak Basic user:pass to argv" {
    local state_dir="$(mktemp -d -t aqt.argv.XXXXXX)"
    _install_curl_argv_recorder "$state_dir"
    export AIQUOTAS_ARGV_LOG="$state_dir/argv.log"

    run env PATH="$state_dir/bin:$PATH" \
        bash -c '
            source "$1/src/core/bootstrap.sh"
            source "$1/src/utils/network.sh"
            safe_curl_with_auth "alice:SECRET_PWD_BBB" "https://api.example.com/x"
        ' _ "$POWERKIT_ROOT"

    assert_success
    assert_argv_clean "$state_dir/argv.log" "SECRET_PWD_BBB"
    rm -rf "$state_dir"
}

# =============================================================================
# jira_issue_selector.sh: jira_api_call (Basic via stdin)
# =============================================================================

@test "security: jira-style helper does not leak email or token to argv" {
    local state_dir="$(mktemp -d -t aqt.argv.XXXXXX)"
    _install_curl_argv_recorder "$state_dir"
    export AIQUOTAS_ARGV_LOG="$state_dir/argv.log"

    run env PATH="$state_dir/bin:$PATH" \
        bash -c '
            source "$1/src/core/bootstrap.sh"
            source "$1/src/utils/api.sh"
            source "$1/src/utils/network.sh"
            # The jira helper ultimately calls safe_curl_with_auth.
            # Verify the seam directly with a dummy Jira-style credential.
            safe_curl_with_auth "SECRET_EMAIL_CCC:SECRET_TOKEN_CCC" \
                "https://example.atlassian.net/rest/api/3/search"
        ' _ "$POWERKIT_ROOT"

    assert_success
    assert_argv_clean "$state_dir/argv.log" "SECRET_EMAIL_CCC"
    assert_argv_clean "$state_dir/argv.log" "SECRET_TOKEN_CCC"
    rm -rf "$state_dir"
}

# =============================================================================
# Whole-src audit (regex over src/)
# =============================================================================

@test "security: no -H Authorization in $() subshells in src/" {
    local matches
    matches=$(grep -rln -F '$(' "$POWERKIT_ROOT/src" 2>/dev/null \
        | xargs grep -l '\-H[[:space:]]*.*Authorization' 2>/dev/null || true)
    [ -z "$matches" ] || { echo "Matches: $matches"; return 1; }
}

@test "security: no -u with credential value (':' or '@') in src/" {
    local matches
    # Permits -u "" (legitimate opt-out) and -u followed by flag.
    matches=$(grep -rn --include='*.sh' \
        -E 'curl[^|;]*[[:space:]]-u[[:space:]]+[^[:space:]-][^[:space:]]*[:@]' \
        "$POWERKIT_ROOT/src" 2>/dev/null || true)
    [ -z "$matches" ] || { echo "Matches: $matches"; return 1; }
}

@test "security: no --user <cred> literal in src/" {
    local matches
    matches=$(grep -rn --include='*.sh' \
        -- "--user[[:space:]]\+[^\"'-]" \
        "$POWERKIT_ROOT/src" 2>/dev/null || true)
    [ -z "$matches" ] || { echo "Matches: $matches"; return 1; }
}
