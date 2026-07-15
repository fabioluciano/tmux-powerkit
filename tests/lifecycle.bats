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

# =============================================================================
# is_plugin_hidden_by_presence
# =============================================================================

@test "is_plugin_hidden_by_presence conditional+inactive returns 0 (hidden)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        is_plugin_hidden_by_presence "conditional" "inactive"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_plugin_hidden_by_presence always+inactive returns 1 (visible)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        is_plugin_hidden_by_presence "always" "inactive"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "is_plugin_hidden_by_presence conditional+active returns 1 (visible)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        is_plugin_hidden_by_presence "conditional" "active"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "is_plugin_hidden_by_presence always+active returns 1 (visible)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        is_plugin_hidden_by_presence "always" "active"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "is_plugin_hidden_by_presence conditional+degraded returns 1 (visible)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        is_plugin_hidden_by_presence "conditional" "degraded"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "is_plugin_hidden_by_presence conditional+failed returns 1 (visible)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        is_plugin_hidden_by_presence "conditional" "failed"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# lifecycle_reset_cycle
# =============================================================================

@test "lifecycle_reset_cycle runs without error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        lifecycle_reset_cycle
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "lifecycle_reset_cycle clears plugin output" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        _PLUGIN_OUTPUT[test:content]=value
        lifecycle_reset_cycle
        printf "%s" "${_PLUGIN_OUTPUT[*]:-}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

# =============================================================================
# _validate_plugin_output_values
# =============================================================================

@test "_validate_plugin_output_values accepts active+ok+always" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        _validate_plugin_output_values "active" "ok" "always"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "_validate_plugin_output_values accepts all valid states" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        _validate_plugin_output_values "active" "good" "conditional" && \
        _validate_plugin_output_values "inactive" "info" "conditional" && \
        _validate_plugin_output_values "degraded" "warning" "always" && \
        _validate_plugin_output_values "failed" "error" "always"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "_validate_plugin_output_values rejects invalid state" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        _validate_plugin_output_values "bogus" "ok" "always"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "_validate_plugin_output_values rejects invalid health" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        _validate_plugin_output_values "active" "bogus" "always"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "_validate_plugin_output_values rejects invalid presence" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        _validate_plugin_output_values "active" "ok" "bogus"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# _build_plugin_output
# =============================================================================

@test "_build_plugin_output with stale=1 outputs 5th field as 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        value=$(_build_plugin_output "icon" "text" "active" "warning" 1)
        IFS=$'"'"'\x1f'"'"' read -r icon content state health stale <<<"$value"
        printf "%s|%s|%s|%s|%s" "$icon" "$content" "$state" "$health" "$stale"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon|text|active|warning|1"
}

@test "_build_plugin_output with default stale outputs 5th field as 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        value=$(_build_plugin_output "icon" "text" "active" "ok")
        IFS=$'"'"'\x1f'"'"' read -r icon content state health stale <<<"$value"
        printf "%s|%s|%s|%s|%s" "$icon" "$content" "$state" "$health" "$stale"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon|text|active|ok|0"
}

@test "_build_plugin_output sanitizes newlines in content" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/core/lifecycle.sh"
        value=$(_build_plugin_output "i" $'"'"'line1\nline2'"'"' "active" "ok")
        IFS=$'"'"'\x1f'"'"' read -r icon content state health stale <<<"$value"
        printf "%s|%s|%s|%s|%s" "$icon" "$content" "$state" "$health" "$stale"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "i|line1 line2|active|ok|0"
}
