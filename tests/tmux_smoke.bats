#!/usr/bin/env bats

load './helpers/test_helper.bash'

setup() {
    setup_test_root
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
}

@test "tmux entrypoint loads without a running tmux server" {
    run env POWERKIT_ROOT="$POWERKIT_ROOT" bash "$POWERKIT_ROOT/tmux-powerkit.tmux"
    assert_success
}

@test "datetime plugin entrypoint produces plain text" {
    run env POWERKIT_ROOT="$POWERKIT_ROOT" "$POWERKIT_ROOT/bin/powerkit-plugin" datetime
    assert_success
    [[ -n "$output" ]]
    [[ "$output" != *'#['* ]]
}
