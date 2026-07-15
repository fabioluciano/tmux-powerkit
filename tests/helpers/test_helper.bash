#!/usr/bin/env bash
# =============================================================================
# Test Helper for tmux-powerkit BATS tests
#
# Shared setup functions used by ALL test files.
# Source via:  load './helpers/test_helper.bash'  OR  load 'helpers/test_helper'
# =============================================================================

# -----------------------------------------------------------------------------
# setup_test_root
#
# Sets POWERKIT_ROOT to the project root (parent of tests/),
# creates a dedicated XDG_CACHE_HOME under BATS_TEST_TMPDIR,
# and loads bats-support / bats-assert helper libraries.
#
# Must be called from a BATS setup() or @test body so that
# BATS_TEST_DIRNAME and BATS_TEST_TMPDIR are defined.
# -----------------------------------------------------------------------------
setup_test_root() {
    POWERKIT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export POWERKIT_ROOT
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
    mkdir -p "$XDG_CACHE_HOME"
    load "$BATS_TEST_DIRNAME/test_helper/bats-support/load"
    load "$BATS_TEST_DIRNAME/test_helper/bats-assert/load"
}

# -----------------------------------------------------------------------------
# create_mock_path
#
# Creates a temporary bin directory under BATS_TEST_TMPDIR,
# prepends it to PATH, and prints its path so callers can
# create stub/script executables inside it.
#
# Usage:
#   mock_dir=$(create_mock_path)
#   cat >"$mock_dir/mycommand" <<'EOF' ... ; chmod +x "$mock_dir/mycommand"
# -----------------------------------------------------------------------------
create_mock_path() {
    local bin_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$bin_dir"
    # Store globally so callers can use the path even when called via $(...)
    export _MOCK_BIN_DIR="$bin_dir"
    export PATH="$bin_dir:$PATH"
    printf '%s' "$bin_dir"
}

# Re-export mock PATH in the parent shell (compensate for $(create_mock_path) subshell)
# Usage: mock_dir=$(create_mock_path) && mock_path_export
mock_path_export() {
    export PATH="$_MOCK_BIN_DIR:$PATH"
}

# -----------------------------------------------------------------------------
# mock_plugin_options
#
# Creates a get_option() function stub that returns the specified
# key=value pairs.  Accepts one or more "key=value" arguments.
#
# Usage:
#   mock_plugin_options "warning_threshold=30" "icon=battery"
#   get_option "warning_threshold"   # => "30"
#   get_option "icon"                 # => "battery"
#   get_option "undefined_key"       # => "" (falls through to default)
# -----------------------------------------------------------------------------
mock_plugin_options() {
    local pair key val code
    code="get_option() {"
    code+=' case "$1" in'
    for pair in "$@"; do
        key="${pair%%=*}"
        val="${pair#*=}"
        code+=" ${key}) printf '%s' '${val}' ;;"
    done
    code+=' *) printf "" ;;'
    code+=' esac; }'
    eval "$code"
}
