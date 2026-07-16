#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/core/keybindings.sh (pure logic only)
# Covers: register_core_keybinding, get_core_keybindings, get_core_keybinding_info
#
# NOTE: Functions that call tmux are intentionally NOT tested here.
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# register_core_keybinding
# =============================================================================

@test "register_core_keybinding registers a shell-type keybinding" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        register_core_keybinding "test_binding" "shell" "@test_key" "C-t"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "register_core_keybinding registers a popup-type keybinding" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        register_core_keybinding "popup_test" "popup" "@popup_key" "C-p" "@popup_w" "80%" "@popup_h" "60%" "test_helper.sh"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# get_core_keybindings
# =============================================================================

@test "get_core_keybindings includes newly registered keybinding" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        register_core_keybinding "custom_binding" "shell" "@ck" "C-k"
        get_core_keybindings
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "custom_binding"
}

# =============================================================================
# get_core_keybinding_info
# =============================================================================

@test "get_core_keybinding_info returns config for registered keybinding" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        register_core_keybinding "info_test" "shell" "@info_key" "C-i"
        get_core_keybinding_info "info_test"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "shell"
    assert_output --partial "@info_key"
    assert_output --partial "C-i"
}

@test "get_core_keybinding_info returns empty for unregistered keybinding" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_core_keybinding_info "nonexistent_binding"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

@test "get_core_keybindings lists all pre-configured core keybindings" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        get_core_keybindings
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "cache_clear"
    assert_output --partial "options_viewer"
    assert_output --partial "keybindings_viewer"
    assert_output --partial "theme_selector"
    assert_output --partial "log_viewer"
}
