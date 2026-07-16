#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/core/defaults.sh
# Covers: default constants, get_plugin_default
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Theme Constants
# =============================================================================

@test "POWERKIT_DEFAULT_THEME equals catppuccin" {
    run bash -c 'source "$1/src/core/defaults.sh" && printf "%s" "$POWERKIT_DEFAULT_THEME"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "catppuccin"
}

@test "POWERKIT_DEFAULT_THEME_VARIANT equals mocha" {
    run bash -c 'source "$1/src/core/defaults.sh" && printf "%s" "$POWERKIT_DEFAULT_THEME_VARIANT"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "mocha"
}

# =============================================================================
# Byte Size Constants
# =============================================================================

@test "POWERKIT_BYTE_KB equals 1024" {
    run bash -c 'source "$1/src/core/defaults.sh" && printf "%s" "$POWERKIT_BYTE_KB"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "1024"
}

@test "POWERKIT_BYTE_MB equals 1048576" {
    run bash -c 'source "$1/src/core/defaults.sh" && printf "%s" "$POWERKIT_BYTE_MB"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "1048576"
}

@test "POWERKIT_BYTE_GB equals 1073741824" {
    run bash -c 'source "$1/src/core/defaults.sh" && printf "%s" "$POWERKIT_BYTE_GB"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "1073741824"
}

# =============================================================================
# Plugin Defaults
# =============================================================================

@test "POWERKIT_DEFAULT_PLUGINS is non-empty" {
    run bash -c 'source "$1/src/core/defaults.sh"; [[ -n "$POWERKIT_DEFAULT_PLUGINS" ]]' _ "$POWERKIT_ROOT"
    assert_success
}

@test "get_plugin_default returns empty for undefined plugin option" {
    run bash -c 'source "$1/src/core/defaults.sh" && get_plugin_default "battery" "nonexistent"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

# =============================================================================
# Separator Constants
# =============================================================================

@test "POWERKIT_DEFAULT_SEPARATOR_STYLE equals normal" {
    run bash -c 'source "$1/src/core/defaults.sh" && printf "%s" "$POWERKIT_DEFAULT_SEPARATOR_STYLE"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "normal"
}

# =============================================================================
# Lazy Loading Constants
# =============================================================================

@test "POWERKIT_DEFAULT_LAZY_LOADING is true" {
    run bash -c 'source "$1/src/core/defaults.sh" && printf "%s" "$POWERKIT_DEFAULT_LAZY_LOADING"' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "true"
}
