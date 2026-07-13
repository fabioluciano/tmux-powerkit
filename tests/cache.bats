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
