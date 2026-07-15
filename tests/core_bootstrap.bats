#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/core/bootstrap.sh
# Covers: _extract_plugin_names, powerkit_bootstrap_minimal, PATH safety block
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# _extract_plugin_names
# =============================================================================

@test "_extract_plugin_names 'a,b,c' returns 'a b c'" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _extract_plugin_names "a,b,c"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "a b c"
}

@test "_extract_plugin_names with group syntax expands groups" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _extract_plugin_names "a,group(b,c),d"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "a b c d"
}

@test "_extract_plugin_names empty string returns empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _extract_plugin_names ""
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

@test "_extract_plugin_names single group returns group contents" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _extract_plugin_names "group(a)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "a"
}

@test "_extract_plugin_names multiple groups expands all" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _extract_plugin_names "group(a,b),group(c,d),e"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "a b c d e"
}

@test "_extract_plugin_names single element returns itself" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _extract_plugin_names "single"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "single"
}

@test "_extract_plugin_names with underscores and hyphens preserves them" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _extract_plugin_names "my-plugin,group(another_plugin,third)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "my-plugin another_plugin third"
}

# =============================================================================
# powerkit_bootstrap_minimal
# =============================================================================

@test "powerkit_bootstrap_minimal loads without error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        powerkit_bootstrap_minimal
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# PATH Safety Block
# =============================================================================

@test "PATH includes /usr/sbin after sourcing bootstrap" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        case ":${PATH}:" in
            *:/usr/sbin:*) exit 0 ;;
            *) exit 1 ;;
        esac
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "PATH includes /sbin after sourcing bootstrap" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        case ":${PATH}:" in
            *:/sbin:*) exit 0 ;;
            *) exit 1 ;;
        esac
    ' _ "$POWERKIT_ROOT"
    assert_success
}
