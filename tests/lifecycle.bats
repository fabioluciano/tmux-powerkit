#!/usr/bin/env bats

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

@test "lifecycle payload has exactly five unit-separator fields" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        value=$(_build_plugin_output "i" $'"'"'text\nmore\x1f'"'"' active good)
        IFS=$'"'"'\x1f'"'"' read -r icon content state health stale <<<"$value"
        printf "%s|%s|%s|%s|%s" "$icon" "$content" "$state" "$health" "$stale"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "i|text more |active|good|0"
}

@test "lifecycle rejects invalid output enums" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        _validate_plugin_output_values bogus good conditional
    ' _ "$POWERKIT_ROOT"
    assert_failure
}
