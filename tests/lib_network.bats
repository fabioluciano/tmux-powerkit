#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/utils/network.sh
# Covers: safe_curl, is_endpoint_reachable, is_host_reachable,
#         json_get_value, json_get_size, _network_make_api_call,
#         make_api_call wrapper
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Helper: create mock curl script
# =============================================================================

_mock_curl() {
    local script="$1"
    local dir="$BATS_TEST_TMPDIR/mockbin"
    mkdir -p "$dir"
    printf '%s' "$script" >"$dir/curl"
    chmod +x "$dir/curl"
    printf '%s' "$dir"
}

# =============================================================================
# safe_curl
# =============================================================================

@test "safe_curl returns body from mock curl" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
echo "safe response body"')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        safe_curl "http://test" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "safe response body"
}

@test "safe_curl returns empty and status 1 when curl fails" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
exit 1')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        safe_curl "http://test" 5
    ' _ "$POWERKIT_ROOT"
    assert_failure
    assert_output ""
}

@test "safe_curl passes extra arguments to curl" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) shift; echo "output_target=$1";;
    esac
    shift
done')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        safe_curl "http://test" 5 -o "/dev/null"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "output_target=/dev/null"
}

# =============================================================================
# is_endpoint_reachable
# =============================================================================

@test "is_endpoint_reachable returns 0 when endpoint responds" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
# -o /dev/null expects no output to stdout
exit 0')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        is_endpoint_reachable "http://localhost" 2
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_endpoint_reachable returns 1 when endpoint fails" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
exit 1')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        is_endpoint_reachable "http://localhost" 2
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# json_get_value (fallback without jq)
# =============================================================================

@test "json_get_value extracts value for simple key using fallback" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        json_get_value "{\"key\":\"value\"}" "key"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "value"
}

@test "json_get_value returns empty for non-existent key" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        json_get_value "{\"key\":\"value\"}" "nonexistent"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

@test "json_get_value uses jq when available" {
    if ! has_cmd "jq"; then
        skip "jq not available on this system"
    fi

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        json_get_value "{\"key\":\"value\"}" "key"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "value"
}

# =============================================================================
# json_get_size (fallback without jq)
# =============================================================================

@test "json_get_size returns size value using fallback" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        json_get_size "{\"size\":5}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "5"
}

@test "json_get_size returns 0 when no size field" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        json_get_size "{\"count\":10}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "0"
}

# =============================================================================
# is_host_reachable
# =============================================================================

@test "is_host_reachable returns 0 when port is reachable via nc" {
    if ! has_cmd "nc"; then
        skip "nc not available on this system"
    fi

    local port
    port=$(shuf -i 20000-30000 -n 1)
    nc -l "$port" &
    local nc_pid=$!
    disown

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        is_host_reachable "127.0.0.1" "'"$port"'" 2
    ' _ "$POWERKIT_ROOT"
    assert_success

    kill "$nc_pid" 2>/dev/null || true
}

@test "is_host_reachable returns 1 when port is not reachable" {
    if ! has_cmd "nc"; then
        skip "nc not available on this system"
    fi

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        is_host_reachable "127.0.0.1" "19999" 1
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# _network_make_api_call
# =============================================================================

@test "_network_make_api_call with bearer auth" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -H) shift; echo "H: $1";;
        -*) ;;
        *) echo "url: $1";;
    esac
    shift
done')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        _network_make_api_call "http://test" "bearer" "mytoken" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "H: Authorization: Bearer mytoken"
}

@test "_network_make_api_call with github auth" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -H) shift; echo "H: $1";;
        -*) ;;
        *) echo "url: $1";;
    esac
    shift
done')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        _network_make_api_call "http://test" "github" "ghp_xxx" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "H: Authorization: token ghp_xxx"
}

@test "_network_make_api_call with private-token auth" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -H) shift; echo "H: $1";;
        -*) ;;
        *) echo "url: $1";;
    esac
    shift
done')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        _network_make_api_call "http://test" "private-token" "glpat_xxx" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "H: PRIVATE-TOKEN: glpat_xxx"
}

@test "_network_make_api_call with basic auth" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u) shift; echo "user: $1";;
        -*) ;;
        *) echo "url: $1";;
    esac
    shift
done')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        _network_make_api_call "http://test" "basic" "user:pass" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "user: user:pass"
}

# =============================================================================
# make_api_call wrapper (fallback in network.sh)
# =============================================================================

@test "make_api_call wrapper delegates to _network_make_api_call" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
echo "wrapper works"')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        make_api_call "http://test" "bearer" "tok" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "wrapper works"
}
