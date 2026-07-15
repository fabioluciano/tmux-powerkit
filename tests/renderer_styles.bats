#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/renderer/styles.sh
# Covers: build_status_style, build_message_style, build_message_command_style,
#         build_clock_format, build_mode_style, build_popup_style,
#         build_popup_border_style, build_menu_style, build_menu_selected_style,
#         build_menu_border_style
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Status Bar Style
# =============================================================================

@test "build_status_style returns string starting with fg=" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        build_status_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == fg=* ]]
}

# =============================================================================
# Message Styles
# =============================================================================

@test "build_message_style returns string with fg= and bg=" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        build_message_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == *"fg="* ]]
    [[ "$output" == *"bg="* ]]
    [[ "$output" == *"fill="* ]]
}

@test "build_message_command_style returns string with fg= and bg=" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        build_message_command_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == *"fg="* ]]
    [[ "$output" == *"bg="* ]]
    [[ "$output" == *"fill="* ]]
}

# =============================================================================
# Clock Style
# =============================================================================

@test "build_clock_format returns non-empty hex value" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        build_clock_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
}

# =============================================================================
# Copy Mode Style
# =============================================================================

@test "build_mode_style returns string with fg= and bg=" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        build_mode_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == *"fg="* ]]
    [[ "$output" == *"bg="* ]]
}

# =============================================================================
# Popup Styles
# =============================================================================

@test "build_popup_style returns non-empty style string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        build_popup_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
    [[ "$output" == *"fg="* ]]
    [[ "$output" == *"bg="* ]]
}

@test "build_popup_border_style returns string with fg=" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        build_popup_border_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == *"fg="* ]]
}

# =============================================================================
# Menu Styles
# =============================================================================

@test "build_menu_style returns non-empty style string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        build_menu_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
    [[ "$output" == *"fg="* ]]
    [[ "$output" == *"bg="* ]]
}

@test "build_menu_selected_style returns non-empty style string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        build_menu_selected_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ -n "$output" ]]
    [[ "$output" == *"fg="* ]]
    [[ "$output" == *"bg="* ]]
}

@test "build_menu_border_style returns string with fg=" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        for f in "$1/src/renderer"/*.sh; do . "$f"; done
        load_theme "catppuccin" "mocha" 2>/dev/null
        build_menu_border_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" == *"fg="* ]]
}
