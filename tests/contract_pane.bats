#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/contract/pane_contract.sh
# Covers: flash effect, border styling, format placeholders, sync icon,
#         scrollbars style, appearance sync
#
# Runs outside tmux (TMUX unset). Functions that read tmux options will
# return defaults from core/defaults.sh. The color resolver is loaded
# so theme-dependent functions (border_color, etc.) resolve correctly.
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# pane_flash_is_enabled
# =============================================================================

@test "pane_flash_is_enabled returns 1 (disabled) when TMUX is unset" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_flash_is_enabled
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# pane_border_color — active
# =============================================================================

@test "pane_border_color active returns non-empty color" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_border_color "active"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    # Should be a hex color or named color
    [[ "$output" =~ ^# || "$output" =~ ^[a-z] ]]
}

# =============================================================================
# pane_border_color — inactive
# =============================================================================

@test "pane_border_color inactive returns non-empty color" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_border_color "inactive"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    [[ "$output" =~ ^# || "$output" =~ ^[a-z] ]]
}

# =============================================================================
# pane_border_style — active
# =============================================================================

@test "pane_border_style active returns fg=COLOR" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_border_style "active"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp '^fg='
    refute_output "fg="
}

# =============================================================================
# pane_border_style — inactive (synchronized conditional)
# =============================================================================

@test "pane_border_style inactive returns conditional with sync format" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_border_style "inactive"
    ' _ "$POWERKIT_ROOT"
    assert_success
    # Should contain pane_synchronized conditional
    assert_output --partial '#{?pane_synchronized'
    assert_output --partial 'fg='
}

# =============================================================================
# pane_resolve_format_placeholders — {index}
# =============================================================================

@test "pane_resolve_format_placeholders {index} resolves to #{pane_index}" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_resolve_format_placeholders "{index}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{pane_index}'
}

# =============================================================================
# pane_resolve_format_placeholders — {command}
# =============================================================================

@test "pane_resolve_format_placeholders {command} resolves to #{pane_current_command}" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_resolve_format_placeholders "{command}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{pane_current_command}'
}

# =============================================================================
# pane_resolve_format_placeholders — {active}
# =============================================================================

@test "pane_resolve_format_placeholders {active} resolves to conditional with ▶" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_resolve_format_placeholders "{active}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output '#{?pane_active,▶,}'
}

# =============================================================================
# pane_resolve_format_placeholders — plain text passthrough
# =============================================================================

@test "pane_resolve_format_placeholders passes plain text through unchanged" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_resolve_format_placeholders "plain text"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "plain text"
}

# =============================================================================
# pane_build_border_format
# =============================================================================

@test "pane_build_border_format returns non-empty format string" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_build_border_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    # Should contain tmux format references
    assert_output --partial '#{'
}

# =============================================================================
# pane_get_sync_icon
# =============================================================================

@test "pane_get_sync_icon returns non-empty icon" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_get_sync_icon
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

# =============================================================================
# pane_sync_format
# =============================================================================

@test "pane_sync_format returns conditional with pane_synchronized" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_sync_format
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial '#{?pane_synchronized'
}

# =============================================================================
# pane_scrollbars_style
# =============================================================================

@test "pane_scrollbars_style returns style string with fg and bg" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/renderer/color_resolver.sh"
        source "$1/src/contract/pane_contract.sh"
        pane_scrollbars_style
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --regexp '^fg='
    assert_output --partial 'bg='
    assert_output --partial 'width='
    assert_output --partial 'pad='
}

# =============================================================================
# sync_pane_flash_appearance — runs without error outside tmux
# =============================================================================

@test "sync_pane_flash_appearance runs without error" {
    run bash -c '
        unset TMUX
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/pane_contract.sh"
        sync_pane_flash_appearance
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# is_valid_pane_state
# =============================================================================

@test "is_valid_pane_state active returns 0" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/pane_contract.sh"
        is_valid_pane_state "active"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_valid_pane_state bogus returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/contract/pane_contract.sh"
        is_valid_pane_state "bogus"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}
