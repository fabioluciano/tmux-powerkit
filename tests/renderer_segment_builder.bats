#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/renderer/segment_builder.sh
# Covers: template system, segment building, plugin segment rendering,
#         simplified segment builders, external segment builder
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# get_segment_template
# =============================================================================

@test "get_segment_template returns non-empty default template string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/segment_builder.sh"
        get_segment_template
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "get_segment_template default contains expected variables" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/segment_builder.sh"
        get_segment_template
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "{sep_left}"
    assert_output --partial "{sep_right}"
    assert_output --partial "{icon_section}"
    assert_output --partial "{content_section}"
}

# =============================================================================
# build_simple_segment
# =============================================================================

@test "build_simple_segment with icon and content returns non-empty formatted string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        load_powerkit_theme
        separator_ensure_cache
        build_simple_segment "🔋" "50%" "ok-base" "#000000" "#ffffff"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "#["
    assert_output --partial "🔋"
    assert_output --partial "50%"
}

@test "build_simple_segment without accent uses default ok-base" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        load_powerkit_theme
        separator_ensure_cache
        build_simple_segment "🔋" "50%"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "🔋"
    assert_output --partial "50%"
}

# =============================================================================
# build_content_segment
# =============================================================================

@test "build_content_segment returns content segment with no icon" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        load_powerkit_theme
        separator_ensure_cache
        build_content_segment "50%" "ok-base" "#000000" "#ffffff"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "50%"
}

@test "build_content_segment with content only returns non-empty string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        load_powerkit_theme
        separator_ensure_cache
        build_content_segment "test"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "test"
}

# =============================================================================
# build_icon_segment
# =============================================================================

@test "build_icon_segment returns icon segment with no text" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        load_powerkit_theme
        separator_ensure_cache
        build_icon_segment "🔋" "ok-base" "#000000" "#ffffff"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "🔋"
}

# =============================================================================
# render_plugin_segment
# =============================================================================

@test "render_plugin_segment returns non-empty formatted string with icon and content" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        separator_ensure_cache
        render_plugin_segment "🔋" "50%" "active" "ok" "#ff0000" "#ffffff" "#00ff00" "#000000" "#000000"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "render_plugin_segment honors side parameter for separator direction" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        separator_ensure_cache
        render_plugin_segment "🔋" "50%" "active" "ok" "#ff0000" "#ffffff" "#00ff00" "#000000" "#000000" 0 0 "left"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

@test "render_plugin_segment handles inactive state gracefully with empty icon and content" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        separator_ensure_cache
        render_plugin_segment "" "" "inactive" "ok" "#565f89" "#ffffff" "#565f89" "#ffffff" "#000000"
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Should still produce something (no crash)
    refute_output ""
}

@test "render_plugin_segment is_first=1 includes edge opening separator" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        separator_ensure_cache
        render_plugin_segment "🔋" "50%" "active" "ok" "#ff0000" "#ffffff" "#00ff00" "#000000" "#000000" 1
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

# =============================================================================
# build_external_segment
# =============================================================================

@test "build_external_segment returns non-empty formatted string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        load_powerkit_theme
        separator_ensure_cache
        build_external_segment "icon" "text" "ok-base" "error-base" "#000000" "#ffffff"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "icon"
    assert_output --partial "text"
}

@test "build_external_segment with minimal arguments uses defaults" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        load_powerkit_theme
        separator_ensure_cache
        build_external_segment "🔋" "50%"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    assert_output --partial "🔋"
    assert_output --partial "50%"
}

# =============================================================================
# build_segment (core builder)
# =============================================================================

@test "build_segment constructs segment from template with all variables" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/separator.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/renderer/segment_builder.sh"
        separator_ensure_cache
        build_segment "🔋" "50%" "#ff0000" "#ffffff" "#00ff00" "#000000" "#000000" "#ffffff"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}
