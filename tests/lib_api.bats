#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/utils/api.sh
# Covers: api_fetch_url, api_fetch_with_auth, api_fetch_with_retry,
#         make_api_call, api_validate_response, api_has_error,
#         api_is_success, api_fetch_with_status, api_fetch_with_status_meta
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
# api_fetch_url
# =============================================================================

@test "api_fetch_url returns response body from mock curl" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
echo "mocked response"')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        api_fetch_url "http://test"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "mocked response"
}

@test "api_fetch_url returns empty and status 1 when curl fails" {
    # api_fetch_url does not return on failure; curl's exit code propagates.
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
exit 1')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        api_fetch_url "http://test"
    ' _ "$POWERKIT_ROOT"
    assert_failure
    assert_output ""
}

# =============================================================================
# api_fetch_with_auth
# =============================================================================

@test "api_fetch_with_auth returns body from mock curl" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
echo "authenticated response"')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        api_fetch_with_auth "http://test" "Bearer mytoken" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "authenticated response"
}

# =============================================================================
# api_fetch_with_retry
# =============================================================================

@test "api_fetch_with_retry succeeds when first attempt fails and later succeeds" {
    # First call fails (no marker), second call succeeds (marker found)
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
marker="'"$BATS_TEST_TMPDIR"'/retry_flag"
if [[ -f "$marker" ]]; then
    echo "success"
else
    touch "$marker"
    exit 1
fi')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        api_fetch_with_retry "http://test" 1
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "success"
}

@test "api_fetch_with_retry returns failure when all attempts fail" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
exit 1')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        api_fetch_with_retry "http://test" 1
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# make_api_call
# =============================================================================

@test "make_api_call with github auth type" {
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
        make_api_call "http://test" "github" "ghp_token" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "H: Authorization: token ghp_token"
}

@test "make_api_call with bearer auth type" {
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
        make_api_call "http://test" "bearer" "my_token" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "H: Authorization: Bearer my_token"
}

@test "make_api_call with basic auth type" {
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
        make_api_call "http://test" "basic" "user:pass" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "user: user:pass"
}

@test "make_api_call with private-token auth type" {
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
        make_api_call "http://test" "private-token" "glpat_token" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "H: PRIVATE-TOKEN: glpat_token"
}

# =============================================================================
# api_validate_response
# =============================================================================

@test "api_validate_response returns 0 for non-empty valid response" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_validate_response "valid data"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_validate_response returns 1 for empty response" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_validate_response ""
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "api_validate_response returns 1 for whitespace-only response" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_validate_response "   "
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "api_validate_response returns 1 for response containing error field" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_validate_response "{\"error\":\"not found\"}"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# api_has_error
# =============================================================================

@test "api_has_error returns 0 for response with error field" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_has_error "{\"error\":\"some error\"}"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_has_error returns 0 for response with error message" {
    # The regex expects the error word as the complete JSON string value
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_has_error "{\"message\":\"error\"}"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_has_error returns 0 for response with failed message" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_has_error "{\"message\":\"failed\"}"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_has_error returns 1 for clean response" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_has_error "{\"status\":\"ok\"}"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "api_has_error detects HTTP 4xx/5xx status lines" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_has_error "HTTP/1.1 404 Not Found"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# api_is_success
# =============================================================================

@test "api_is_success returns 0 for status 200" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_is_success "200"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_is_success returns 0 for status 201" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_is_success "201"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "api_is_success returns 1 for status 404" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_is_success "404"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "api_is_success returns 1 for status 500" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_is_success "500"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "api_is_success returns 1 for status 302" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        api_is_success "302"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# api_fetch_with_status
# =============================================================================

@test "api_fetch_with_status returns status code and body" {
    mock_dir=$(_mock_curl '#!/usr/bin/env bash
printf "%s\n" "{\"data\":\"ok\"}"
printf "200\n"')

    run bash -c '
        PATH="'"$mock_dir"':$PATH"
        source "$1/src/core/bootstrap.sh"
        api_fetch_with_status "http://test" 5
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "200"
}

# api_fetch_with_status_meta test removed — the function does not exist in
# the original src/utils/api.sh. See git log for the reverted commit.
