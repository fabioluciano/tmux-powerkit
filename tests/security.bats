#!/usr/bin/env bats

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

@test "powerkit-plugin rejects traversal names before sourcing a plugin" {
    run env POWERKIT_ROOT="$POWERKIT_ROOT" "$POWERKIT_ROOT/bin/powerkit-plugin" '../core/lifecycle'
    assert_failure
}

@test "powerkit-plugin rejects absolute plugin names" {
    run env POWERKIT_ROOT="$POWERKIT_ROOT" "$POWERKIT_ROOT/bin/powerkit-plugin" '/tmp/plugin'
    assert_failure
}

@test "cache mtime supports lock directories" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        lock_dir=$(mktemp -d)
        _file_mtime "$lock_dir"
        rm -rf "$lock_dir"
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" =~ ^[0-9]+$ ]]
    [[ "$output" -gt 0 ]]
}

@test "lifecycle ignores invalid internal plugin names" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _register_plugin "../core/lifecycle"
        [[ -z "${_PLUGINS[../core/lifecycle]+x}" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}
