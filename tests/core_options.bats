#!/usr/bin/env bats
# =============================================================================
# Tests: core/options.sh
# Description: Tests for the PowerKit options declaration and validation API
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
}

# ---------------------------------------------------------------------------
# declare_option
# ---------------------------------------------------------------------------

@test "declare_option succeeds in plugin context" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplug"
        declare_option "my_opt" "string" "default_val" "A test option"
        echo "OK"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "OK"
}

@test "declare_option fails without plugin context" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        declare_option "x" "string" "d" "desc" 2>/dev/null && echo "ok" || echo "fail"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "fail"
}

# ---------------------------------------------------------------------------
# _validate_option_value — number type
# ---------------------------------------------------------------------------

@test "_validate_option_value returns valid number as-is" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "42" "number" "0"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "42"
}

@test "_validate_option_value returns default for invalid number" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "notanumber" "number" "5"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "5"
}

@test "_validate_option_value returns default for empty number" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "" "number" "10"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "10"
}

@test "_validate_option_value accepts negative numbers" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "-7" "number" "0"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "-7"
}

# ---------------------------------------------------------------------------
# _validate_option_value — bool type
# ---------------------------------------------------------------------------

@test "_validate_option_value normalizes 'true' to 'true'" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "true" "bool" "false"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "true"
}

@test "_validate_option_value normalizes 'yes' to 'true'" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "yes" "bool" "false"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "true"
}

@test "_validate_option_value normalizes 'on' to 'true'" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "on" "bool" "false"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "true"
}

@test "_validate_option_value normalizes '1' to 'true'" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "1" "bool" "false"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "true"
}

@test "_validate_option_value normalizes 'no' to 'false'" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "no" "bool" "true"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "false"
}

@test "_validate_option_value normalizes 'off' to 'false'" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "off" "bool" "true"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "false"
}

@test "_validate_option_value returns default for invalid bool" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "bogus" "bool" "false"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "false"
}

# ---------------------------------------------------------------------------
# _validate_option_value — string type (pass-through)
# ---------------------------------------------------------------------------

@test "_validate_option_value passes through string values unchanged" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _validate_option_value "hello world" "string" "default"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "hello world"
}

# ---------------------------------------------------------------------------
# get_plugin_declared_options
# ---------------------------------------------------------------------------

@test "get_plugin_declared_options returns all declared options" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplug"
        declare_option "opt_a" "string" "a" "Option A"
        declare_option "opt_b" "number" "0" "Option B"
        get_plugin_declared_options "testplug"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "opt_a"
    assert_output --partial "opt_b"
}

@test "get_plugin_declared_options returns empty for unknown plugin" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_plugin_declared_options "nonexistent"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

# ---------------------------------------------------------------------------
# get_option (context-dependent)
# ---------------------------------------------------------------------------

@test "get_option returns default when no tmux option is set" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplug"
        declare_option "myopt" "string" "mydefault" "desc"
        get_option "myopt"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "mydefault"
}

@test "get_option fails without plugin context" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_option "anything" 2>/dev/null && echo "ok" || echo "fail"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "fail"
}

# ---------------------------------------------------------------------------
# get_named_plugin_option (context-free)
# ---------------------------------------------------------------------------

@test "get_named_plugin_option reads option for any plugin" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "someplug"
        declare_option "greeting" "string" "hello" "A greeting"
        # Context-free read
        get_named_plugin_option "someplug" "greeting"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "hello"
}

@test "get_named_plugin_option fails without plugin argument" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_named_plugin_option "" "x" 2>/dev/null && echo "ok" || echo "fail"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "fail"
}

# ---------------------------------------------------------------------------
# has_declared_options
# ---------------------------------------------------------------------------

@test "has_declared_options returns 0 when plugin has options" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "hasopts"
        declare_option "x" "string" "d" "desc"
        has_declared_options "hasopts" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "yes"
}

@test "has_declared_options returns 1 when plugin has no options" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        has_declared_options "empty" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "no"
}

# ---------------------------------------------------------------------------
# get_plugin_keybinding_options
# ---------------------------------------------------------------------------

@test "get_plugin_keybinding_options returns only keybinding_ options" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "keyplug"
        declare_option "keybinding_select" "key" "C-s" "Select key"
        declare_option "keybinding_toggle" "key" "C-t" "Toggle key"
        declare_option "icon" "icon" "X" "Not a keybinding"
        get_plugin_keybinding_options "keyplug"
        true
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_line "keybinding_select"
    assert_line "keybinding_toggle"
    refute_line "icon"
}

# ---------------------------------------------------------------------------
# Global option helpers (outside tmux — returns defaults)
# ---------------------------------------------------------------------------

@test "is_transparent_mode returns default when TMUX is unset" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        is_transparent_mode && echo "true" || echo "false"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "false"
}

@test "is_debug_enabled returns false (1) outside tmux" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        is_debug_enabled && echo "true" || echo "false"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "false"
}

# ---------------------------------------------------------------------------
# clear_options_cache
# ---------------------------------------------------------------------------

@test "clear_options_cache invalidates cached option values" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "plug"
        declare_option "x" "string" "orig" "desc"
        # This populates the cache
        get_option "x" > /dev/null
        clear_options_cache
        # Cache cleared — calling again re-resolves
        get_option "x"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "orig"
}

# ---------------------------------------------------------------------------
# show_only_on_threshold default injection
# ---------------------------------------------------------------------------

@test "show_only_on_threshold is injected as default option" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "plug"
        declare_option "myopt" "string" "val" "desc"
        get_plugin_declared_options "plug"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "show_only_on_threshold"
}
