#!/usr/bin/env bats

load './helpers/test_helper.bash'

setup() {
    setup_test_root
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
}

@test "cache set, get, and clear invalidate memory" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_set sample value
        cache_get sample 60
        cache_clear sample
        cache_get sample 60
    ' _ "$POWERKIT_ROOT"
    assert_failure
    assert_output "value"
}

# =============================================================================
# cache_valid
# =============================================================================

@test "cache_valid returns 0 after cache_set" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_set "valid_key" "valid_value"
        cache_valid "valid_key" 60
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "cache_valid returns 1 for non-existent key" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_valid "nonexistent_key" 60
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# cache_age
# =============================================================================

@test "cache_age returns non-negative number for existing entry" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_set "age_key" "age_value"
        age=$(cache_age "age_key")
        printf "%s" "$age"
        [[ "$age" =~ ^[0-9]+$ ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output "-1"
}

@test "cache_age returns -1 for non-existent entry" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_age "nonexistent_age_key"
    ' _ "$POWERKIT_ROOT"
    assert_failure
    assert_output "-1"
}

# =============================================================================
# cache_clear_prefix
# =============================================================================

@test "cache_clear_prefix clears matching entries but not others" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_set "prefix_foo" "foo_val"
        cache_set "prefix_bar" "bar_val"
        cache_set "other" "other_val"
        cache_clear_prefix "prefix_"
        # prefix_foo should be gone
        cache_valid "prefix_foo" 60 && printf "FOO_EXISTS" || printf "FOO_GONE"
        printf ":"
        # prefix_bar should be gone
        cache_valid "prefix_bar" 60 && printf "BAR_EXISTS" || printf "BAR_GONE"
        printf ":"
        # other should still exist
        cache_valid "other" 60 && printf "OTHER_EXISTS" || printf "OTHER_GONE"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "FOO_GONE:BAR_GONE:OTHER_EXISTS"
}

@test "cache_clear_prefix with non-matching prefix does not clear anything" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_set "keep_me" "keep_value"
        cache_clear_prefix "zzzz_"
        cache_valid "keep_me" 60
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# cache_list
# =============================================================================

@test "cache_list runs without error and lists entries" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_set "list_key_1" "value1"
        cache_set "list_key_2" "value2"
        cache_list
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "list_key_1"
    assert_output --partial "list_key_2"
}

@test "cache_list shows age for entries" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_set "age_list_key" "val"
        cache_list
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "age:"
}

# =============================================================================
# cache_reset_cycle
# =============================================================================

@test "cache_reset_cycle resets cycle timestamp to 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _CYCLE_TIMESTAMP=9999
        cache_reset_cycle
        printf "%s" "$_CYCLE_TIMESTAMP"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "0"
}

@test "cache_reset_cycle clears memory cache array" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _MEMORY_CACHE[test_key]=test_val
        [[ ${#_MEMORY_CACHE[@]} -gt 0 ]] || exit 1
        cache_reset_cycle
        printf "%s" "${#_MEMORY_CACHE[@]}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "0"
}

@test "cache_reset_cycle forces _get_now to return fresh timestamp" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _CYCLE_TIMESTAMP=1234
        now1=$(_get_now)
        cache_reset_cycle
        now2=$(_get_now)
        [[ "$now1" != "$now2" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# reset_all_cycle_caches
# =============================================================================

@test "reset_all_cycle_caches resets cycle without error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _CYCLE_TIMESTAMP=999
        reset_all_cycle_caches
        printf "%s" "$_CYCLE_TIMESTAMP"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "0"
}

# =============================================================================
# cache_get_or_compute
# =============================================================================

@test "cache_get_or_compute computes and returns value on cache miss" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_get_or_compute "compute_test" 60 printf "computed_result"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "computed_result"
}

@test "cache_get_or_compute returns cached value on subsequent calls" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_get_or_compute "cached_test" 60 printf "original"
        cache_get_or_compute "cached_test" 60 printf "should_not_appear"
    ' _ "$POWERKIT_ROOT"
    assert_success
    # First call stores "original", second call returns cached "original"
    assert_output "originaloriginal"
}

@test "cache_get_or_compute caches value so cache_get also retrieves it" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_get_or_compute "shared_key" 60 printf "shared_val"
        cache_get "shared_key" 60
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "shared_valshared_val"
}

# =============================================================================
# cache_clear
# =============================================================================

@test "cache_clear removes specific entry" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_set "clear_me" "to_be_cleared"
        cache_clear "clear_me"
        cache_valid "clear_me" 60
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "cache_clear does not affect other entries" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_set "keep_1" "keep_val"
        cache_set "remove_1" "remove_val"
        cache_clear "remove_1"
        cache_valid "keep_1" 60
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# Multiple entries
# =============================================================================

@test "multiple cache entries coexist independently" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        cache_set "first" "alpha"
        cache_set "second" "beta"
        val1=$(cache_get "first" 60)
        val2=$(cache_get "second" 60)
        printf "%s|%s" "$val1" "$val2"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "alpha|beta"
}
