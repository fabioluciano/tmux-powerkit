#!/usr/bin/env bats

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

@test "lifecycle payload preserves tmux-looking plugin text literally" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        _build_plugin_output i "#[fg=red] #{session_name} #(uname)" active ok
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == *'#[fg=red] #{session_name} #(uname)'* ]]
}
