#!/usr/bin/env bats
load './helpers/test_helper.bash'

setup() {
    setup_test_root
    mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"
    export PATH="$mock_dir:$PATH"
}

@test "uptime over 1 day shows days in context" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/uptime.sh"
        _set_plugin_context uptime
        plugin_data_set "uptime" "3d 5h"
        printf "context=%s" "$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "context=days"
}

@test "uptime under 1 day shows hours in context" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/uptime.sh"
        _set_plugin_context uptime
        plugin_data_set "uptime" "15h 30m"
        printf "context=%s" "$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "context=hours"
}

@test "uptime under 1 hour shows minutes in context" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/uptime.sh"
        _set_plugin_context uptime
        plugin_data_set "uptime" "45m"
        printf "context=%s" "$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "context=minutes"
}

@test "uptime render returns the uptime string" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/uptime.sh"
        _set_plugin_context uptime
        plugin_data_set "uptime" "2d 3h 45m"
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "2d 3h 45m"
}

@test "uptime very long shows days context" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/uptime.sh"
        _set_plugin_context uptime
        plugin_data_set "uptime" "365d"
        printf "context=%s" "$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "context=days"
}

@test "uptime just started shows minutes context" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/uptime.sh"
        _set_plugin_context uptime
        plugin_data_set "uptime" "2m"
        printf "context=%s" "$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "context=minutes"
}

@test "uptime plugin has contract functions" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/uptime.sh"
        printf "content_type=%s presence=%s state=%s health=%s" \
            "$(plugin_get_content_type)" \
            "$(plugin_get_presence)" \
            "$(plugin_get_state)" \
            "$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "content_type=dynamic"
    assert_output --partial "presence=always"
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
}

@test "uptime plugin declares options" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/uptime.sh"
        _set_plugin_context uptime
        plugin_declare_options
        get_option "icon"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}
