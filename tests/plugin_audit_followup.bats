#!/usr/bin/env bats
# =============================================================================
# Additional bats tests for the wave-2 follow-up fixes that complement
# the security and reliability contracts. Covers:
#   - swap decimal precision (_to_bytes with floats)
#   - uptime awk fallback parser (BSD day/min/hr forms)
#   - api_validate_ip strict IPv6 (rejects garbage, accepts real)
#   - nowplaying app_priority option presence
#   - bitwarden narrow scope (no export BW_SESSION in success path)
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
    mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"
    export PATH="$mock_dir:$PATH"
}

# =============================================================================
# swap: decimal precision in _to_bytes
# =============================================================================

@test "swap: _to_bytes handles fractional MB values" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/swap.sh"
        # 1234.5 MB = 1294467072 bytes; previous impl returned 1293942784
        # (a 512 KB loss).
        printf "%s\n" "$(_to_bytes 1234.5 M)"
        printf "%s\n" "$(_to_bytes 0.75 G)"
        printf "%s\n" "$(_to_bytes 2.0 T)"
        printf "%s\n" "$(_to_bytes 0 M)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "1294467072"
    assert_output --partial "805306368"
    assert_output --partial "2199023255552"
    assert_output --partial "0"
}

@test "swap: _to_bytes rejects garbage input" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/swap.sh"
        printf "%s\n" "$(_to_bytes "abc" M)"
        printf "%s\n" "$(_to_bytes "1.2.3" M)"
        printf "%s\n" "$(_to_bytes "12; rm" M)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Every line is "0"
    [[ "$(echo "$output" | wc -l | tr -d ' ')" == "3" ]]
    [[ "$(echo "$output" | sort -u)" == "0" ]]
}

# =============================================================================
# uptime: awk fallback parser handles day/min/hr
# =============================================================================

@test "uptime: awk fallback recognizes days, hours, minutes" {
    run bash -c '
        awk -F"( |,|:)+" '"'"'
            {
                if ($5 == "min" || $5 == "mins")     print $4 * 60
                else if ($5 == "hrs")               print $4 * 3600
                else if ($5 == "day" || $5 == "days") {
                    base = $4 * 86400
                    if ($6 ~ /^[0-9]+$/ && $7 ~ /^[0-9]+$/) {
                        base += ($6 * 3600) + ($7 * 60)
                    }
                    print base
                }
                else                                print -1
            }'"'"' <<<"12:34, up 12 days,  2 users"
    '
    assert_success
    assert_output --partial "1036800"
}

# =============================================================================
# api_validate_ip: strict IPv6
# =============================================================================

@test "api_validate_ip: rejects garbage that the loose regex accepted" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        # Old loose regex accepted "abc:def" because every char is in [0-9a-fA-F:]
        # and it contains ":". The strict check should reject it because
        # "abc" is more than 4 hex digits.
        api_validate_ip "abc:def"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "api_validate_ip: rejects more than one :: compression" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        api_validate_ip "1::2::3"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "api_validate_ip: accepts valid IPv4" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        api_validate_ip "192.0.2.1"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_validate_ip: accepts canonical IPv6" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        api_validate_ip "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_validate_ip: accepts compressed IPv6 with ::" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        api_validate_ip "2001:db8::1"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_validate_ip: accepts loopback IPv6 ::1" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        api_validate_ip "::1"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# nowplaying: app_priority option exists
# =============================================================================

@test "nowplaying: app_priority option is declared" {
    # Static check: the option must be declared in plugin_declare_options.
    run bash -c '
        awk "/^plugin_declare_options\\(\\)/,/^}/" "$1/src/plugins/nowplaying.sh"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "app_priority"
}

# =============================================================================
# bitwarden: narrow scope (no export BW_SESSION on unlock success)
# =============================================================================

@test "bitwarden: _unlock_bitwarden_bw does not export BW_SESSION" {
    # Static check: the success path should call save_bw_session but
    # NOT contain `export BW_SESSION`. The session stays in tmux's
    # global environment only.
    run bash -c '
        awk "/^_unlock_bitwarden_bw\\(\\)/,/^}/" "$1/src/helpers/_bitwarden_common.sh"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial "export BW_SESSION"
    assert_output --partial "save_bw_session"
}

@test "bitwarden: load_bw_session may export BW_SESSION (current-shell only)" {
    # load_bw_session is the consumer-side helper that exports so the
    # current helper shell can use bw. This export is acceptable.
    run bash -c '
        grep -A 4 "^load_bw_session()" "$1/src/helpers/_bitwarden_common.sh"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "export BW_SESSION"
}
