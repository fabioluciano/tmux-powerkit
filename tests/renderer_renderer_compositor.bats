#!/usr/bin/env bats
# =============================================================================
# BATS tests for renderer.sh + compositor.sh + entities/plugins.sh
# Covers: entity order, plugins entity functions, compositor helpers
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# plugins entity functions (from entities/plugins.sh)
# =============================================================================

@test "plugins_get_bg returns non-empty background" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/entities/plugins.sh"
        load_powerkit_theme
        plugins_get_bg
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "plugins_get_bg returns resolved statusbar-bg" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/entities/plugins.sh"
        load_powerkit_theme
        expected=$(resolve_color "statusbar-bg")
        actual=$(plugins_get_bg)
        [[ "$expected" == "$actual" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "plugins_get_first_bg returns non-empty background" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/entities/plugins.sh"
        load_powerkit_theme
        plugins_get_first_bg
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "plugins_get_last_bg returns non-empty background" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/entities/plugins.sh"
        load_powerkit_theme
        plugins_get_last_bg
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "plugins_get_first_bg equals plugins_get_bg" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/entities/plugins.sh"
        load_powerkit_theme
        bg=$(plugins_get_bg)
        first=$(plugins_get_first_bg)
        last=$(plugins_get_last_bg)
        [[ "$bg" == "$first" ]] && [[ "$bg" == "$last" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# get_entity_order (from compositor.sh)
# =============================================================================

@test "get_entity_order returns default expanded order when no custom option set" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        source "$1/src/renderer/entities/windows.sh"
        source "$1/src/renderer/entities/plugins.sh"
        source "$1/src/renderer/compositor.sh"
        get_entity_order
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    # Default order "session,plugins" expands to "session,windows,plugins"
    assert_output --partial "session"
    assert_output --partial "windows"
    assert_output --partial "plugins"
}

@test "get_entity_order with custom order in cache returns expanded custom order" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        source "$1/src/renderer/entities/windows.sh"
        source "$1/src/renderer/entities/plugins.sh"
        source "$1/src/renderer/compositor.sh"
        _TMUX_OPTIONS_CACHE["@powerkit_status_order"]="plugins,session"
        get_entity_order
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "plugins"
    assert_output --partial "windows"
    assert_output --partial "session"
}

# =============================================================================
# is_custom_order
# =============================================================================

@test "is_custom_order returns 1 when default order is used" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        source "$1/src/renderer/entities/windows.sh"
        source "$1/src/renderer/entities/plugins.sh"
        source "$1/src/renderer/compositor.sh"
        is_custom_order
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "is_custom_order returns 0 when custom order is set" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        source "$1/src/renderer/entities/windows.sh"
        source "$1/src/renderer/entities/plugins.sh"
        source "$1/src/renderer/compositor.sh"
        _TMUX_OPTIONS_CACHE["@powerkit_status_order"]="plugins,session"
        is_custom_order
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# renderer.sh functions (via renderer.sh)
# =============================================================================

@test "renderer.sh sources without error" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/renderer.sh"
        printf "ok"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

@test "build_status_style returns non-empty style string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/styles.sh"
        load_powerkit_theme
        build_status_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "fg="
    assert_output --partial "bg="
}

@test "build_message_style returns non-empty style string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/styles.sh"
        load_powerkit_theme
        build_message_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "fg="
    assert_output --partial "bg="
    assert_output --partial "fill="
}

# =============================================================================
# compositor helpers via renderer.sh (full chain)
# =============================================================================

@test "compositor _expand_order adds windows to 2-element order" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        source "$1/src/renderer/entities/windows.sh"
        source "$1/src/renderer/entities/plugins.sh"
        source "$1/src/renderer/compositor.sh"
        result=$(_expand_order "session,plugins")
        printf "%s" "$result"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "session,windows,plugins"
}

@test "compositor _expand_order leaves 3-element order unchanged" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        source "$1/src/renderer/entities/windows.sh"
        source "$1/src/renderer/entities/plugins.sh"
        source "$1/src/renderer/compositor.sh"
        result=$(_expand_order "plugins,windows,session")
        printf "%s" "$result"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "plugins,windows,session"
}

@test "compositor _is_explicit_three_element_order detects 3-element order" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        source "$1/src/renderer/entities/windows.sh"
        source "$1/src/renderer/entities/plugins.sh"
        source "$1/src/renderer/compositor.sh"
        _is_explicit_three_element_order "session,windows,plugins"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "compositor _is_explicit_three_element_order rejects 2-element order" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        source "$1/src/renderer/entities/windows.sh"
        source "$1/src/renderer/entities/plugins.sh"
        source "$1/src/renderer/compositor.sh"
        _is_explicit_three_element_order "session,plugins"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "plugins_render returns #() call to powerkit-render" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/entities/plugins.sh"
        plugins_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "powerkit-render"
}
