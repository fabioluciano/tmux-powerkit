#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/renderer/entities/session.sh
# Covers: icon resolution, background colors, configure
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# resolve_session_icon
# =============================================================================

@test "resolve_session_icon returns non-empty icon (auto → get_os_icon)" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        resolve_session_icon
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "resolve_session_icon with custom icon set in cache returns custom icon" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        _TMUX_OPTIONS_CACHE["@powerkit_session_icon"]="▶"
        resolve_session_icon
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "▶"
}

# =============================================================================
# session_get_bg
# =============================================================================

@test "session_get_bg returns non-empty background format string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        load_powerkit_theme
        session_get_bg
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "session_get_bg returns tmux conditional format" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        load_powerkit_theme
        session_get_bg
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "#{?client_prefix"
}

# =============================================================================
# session_get_first_bg / session_get_last_bg
# =============================================================================

@test "session_get_first_bg returns same as session_get_bg" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        load_powerkit_theme
        bg=$(session_get_bg)
        first=$(session_get_first_bg)
        [[ "$bg" == "$first" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "session_get_last_bg returns same as session_get_bg" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        load_powerkit_theme
        bg=$(session_get_bg)
        last=$(session_get_last_bg)
        [[ "$bg" == "$last" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# session_configure
# =============================================================================

@test "session_configure runs without error (no-op)" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        session_configure
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# session_render
# =============================================================================

@test "session_render returns non-empty tmux format string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/entities/session.sh"
        load_powerkit_theme
        session_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "#["
    assert_output --partial "#S"
}
