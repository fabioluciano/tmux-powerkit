#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/utils/time.sh
# Covers: time_epoch_now, time_epoch_start, time_iso_now, time_iso_start
#
# NOTE: Uses $EPOCHSECONDS (bash 5.0+ built-in) via direct source of time.sh.
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# time_epoch_now
# =============================================================================

@test "time_epoch_now returns a positive integer (epoch seconds)" {
    run bash -c '
        source "$1"
        now=$(time_epoch_now)
        [[ "$now" =~ ^[0-9]+$ ]] && (( now > 1700000000 ))
    ' _ "$POWERKIT_ROOT/src/utils/time.sh"
    assert_success
}

# =============================================================================
# time_epoch_start
# =============================================================================

@test "time_epoch_start 0 returns same as time_epoch_now (within tolerance)" {
    run bash -c '
        source "$1"
        now=$(time_epoch_now)
        start=$(time_epoch_start 0)
        diff=$(( now - start ))
        (( diff >= -1 && diff <= 1 ))
    ' _ "$POWERKIT_ROOT/src/utils/time.sh"
    assert_success
}

@test "time_epoch_start 1 returns epoch for ~24h ago (within tolerance)" {
    run bash -c '
        source "$1"
        start=$(time_epoch_start 1)
        now=$EPOCHSECONDS
        expected=$(( now - 86400 ))
        diff=$(( start - expected ))
        (( diff >= -1 && diff <= 1 ))
    ' _ "$POWERKIT_ROOT/src/utils/time.sh"
    assert_success
}

@test "time_epoch_start 7 returns epoch for ~7 days ago" {
    run bash -c '
        source "$1"
        start=$(time_epoch_start 7)
        now=$EPOCHSECONDS
        expected=$(( now - 604800 ))
        diff=$(( start - expected ))
        (( diff >= -1 && diff <= 1 ))
    ' _ "$POWERKIT_ROOT/src/utils/time.sh"
    assert_success
}

# =============================================================================
# time_iso_now
# =============================================================================

@test "time_iso_now returns a string matching ISO-8601 Zulu pattern" {
    run bash -c '
        source "$1"
        iso=$(time_iso_now)
        [[ "$iso" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
    ' _ "$POWERKIT_ROOT/src/utils/time.sh"
    assert_success
}

# =============================================================================
# time_iso_start
# =============================================================================

@test "time_iso_start 0 matches ISO-8601 Zulu pattern" {
    run bash -c '
        source "$1"
        iso=$(time_iso_start 0)
        [[ "$iso" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
    ' _ "$POWERKIT_ROOT/src/utils/time.sh"
    assert_success
}

@test "time_iso_start 1 returns a date different from time_iso_now" {
    run bash -c '
        source "$1"
        now=$(time_iso_now)
        yesterday=$(time_iso_start 1)
        [[ "$now" != "$yesterday" ]]
    ' _ "$POWERKIT_ROOT/src/utils/time.sh"
    assert_success
}

@test "time_iso_start 0 and time_iso_now are equal (within same second)" {
    run bash -c '
        source "$1"
        now=$(time_iso_now)
        start0=$(time_iso_start 0)
        [[ "$now" == "$start0" ]]
    ' _ "$POWERKIT_ROOT/src/utils/time.sh"
    assert_success
}
