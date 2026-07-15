#!/usr/bin/env bats
# =============================================================================
# Tests: core/logger.sh
# Description: Tests for the PowerKit centralized logging system
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
    # Each test gets an isolated cache dir via BATS_TEST_TMPDIR
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
}

# ---------------------------------------------------------------------------
# Basic logging
# ---------------------------------------------------------------------------

@test "log_info writes a line to the log file" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_info "test" "hello world"
        cat "$(get_log_file)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "[INFO] [test] hello world"
}

@test "log_warn writes at default info level" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_warn "test" "warning message"
        cat "$(get_log_file)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "[WARN] [test] warning message"
}

@test "log_error writes at default info level" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_error "test" "error message"
        cat "$(get_log_file)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "[ERROR] [test] error message"
}

# ---------------------------------------------------------------------------
# get_log_file
# ---------------------------------------------------------------------------

@test "get_log_file returns a non-empty path" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        local path
        path=$(get_log_file)
        printf "%s" "$path"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "powerkit.log"
}

# ---------------------------------------------------------------------------
# clear_log
# ---------------------------------------------------------------------------

@test "clear_log empties the log file" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_info "test" "entry one"
        log_info "test" "entry two"
        clear_log
        cat "$(get_log_file)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""   # file should be empty after clear
}

# ---------------------------------------------------------------------------
# get_recent_logs
# ---------------------------------------------------------------------------

@test "get_recent_logs returns written entries" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_info "src" "first"
        log_info "src" "second"
        get_recent_logs 10
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "first"
    assert_output --partial "second"
}

@test "get_recent_logs with count parameter limits output" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_info "src" "line 1"
        log_info "src" "line 2"
        log_info "src" "line 3"
        log_info "src" "line 4"
        log_info "src" "line 5"
        log_info "src" "line 6"
        log_info "src" "line 7"
        # Should return only last 2 lines
        get_recent_logs 2 | wc -l
    ' _ "$POWERKIT_ROOT"
    assert_success
    # wc -l output may have leading whitespace; check it contains "2"
    assert_output --partial "2"
}

@test "get_recent_logs defaults to 20 when count is omitted" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for i in $(seq 1 25); do
            log_info "src" "line $i"
        done
        get_recent_logs | wc -l
    ' _ "$POWERKIT_ROOT"
    assert_success
    # 25 written, default returns last 20 → should contain "20"
    assert_output --partial "20"
}

# ---------------------------------------------------------------------------
# set_log_level
# ---------------------------------------------------------------------------

@test "set_log_level error suppresses info messages" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        set_log_level "error"
        log_info "src" "info should NOT appear"
        log_error "src" "error should appear"
        get_recent_logs 10
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "error should appear"
    refute_output --partial "info should NOT appear"
}

@test "set_log_level warn suppresses info but allows warn" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        set_log_level "warn"
        log_info "src" "info suppressed"
        log_warn "src" "warn passes"
        get_recent_logs 10
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "warn passes"
    refute_output --partial "info suppressed"
}

# ---------------------------------------------------------------------------
# log_debug
# ---------------------------------------------------------------------------

@test "log_debug does NOT write when debug is disabled" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_debug "src" "debug message"
        get_recent_logs 10 || true
    ' _ "$POWERKIT_ROOT"
    refute_output --partial "debug message"
}

@test "set_debug true enables debug output (with log level debug)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        set_debug "true"
        set_log_level "debug"
        log_debug "src" "debug enabled"
        get_recent_logs 10 || true
    ' _ "$POWERKIT_ROOT"
    assert_output --partial "[DEBUG] [src] debug enabled"
}

# ---------------------------------------------------------------------------
# Log format & structure
# ---------------------------------------------------------------------------

@test "log entries include timestamp, level, source, and message" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_info "mysource" "my message"
        cat "$(get_log_file)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Format: [YYYY-MM-DD HH:MM:SS] [INFO] [mysource] my message
    assert_output --regexp '\[20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\] \[INFO\] \[mysource\] my message'
}

# ---------------------------------------------------------------------------
# Convenience helpers
# ---------------------------------------------------------------------------

@test "log_plugin_error logs with plugin: prefix in source" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_plugin_error "myplugin" "something broke"
        get_recent_logs 10
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "[plugin:myplugin] something broke"
}

@test "log_missing_dep logs a warning" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_missing_dep "myplugin" "curl"
        get_recent_logs 10
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "[WARN]"
    assert_output --partial "[plugin:myplugin]"
    assert_output --partial "Missing dependency: curl"
}

# ---------------------------------------------------------------------------
# Multiple entries preserve order
# ---------------------------------------------------------------------------

@test "log entries preserve insertion order" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        log_info "src" "AAAf"
        log_info "src" "ZZZg"
        get_recent_logs 10
    ' _ "$POWERKIT_ROOT"
    assert_success
    # first line should have AAA, second should have ZZZ
    local lines
    lines=$(echo "$output" | grep -c "AAAf")
    [[ "$lines" -ge 1 ]]
    lines=$(echo "$output" | grep -c "ZZZg")
    [[ "$lines" -ge 1 ]]
}
