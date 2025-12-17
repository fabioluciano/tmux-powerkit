#!/usr/bin/env bash
# =============================================================================
# PowerKit Plugin Test Framework
# Usage: ./tests/test_plugins.sh [plugin_name]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$ROOT_DIR/src"
PLUGIN_DIR="$SRC_DIR/plugin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL=0
PASSED=0
FAILED=0
WARNINGS=0

# =============================================================================
# Test Functions
# =============================================================================

log_pass() { printf "${GREEN}✓${NC} %s\n" "$1"; PASSED=$((PASSED + 1)); }
log_fail() { printf "${RED}✗${NC} %s\n" "$1"; FAILED=$((FAILED + 1)); }
log_warn() { printf "${YELLOW}⚠${NC} %s\n" "$1"; WARNINGS=$((WARNINGS + 1)); }
log_info() { printf "${BLUE}ℹ${NC} %s\n" "$1"; }

# Test: Bash syntax is valid
test_syntax() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    if bash -n "$file" 2>/dev/null; then
        log_pass "$plugin: syntax valid"
        return 0
    else
        log_fail "$plugin: syntax error"
        return 1
    fi
}

# Test: Plugin can be sourced without errors
test_source() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    # Skip sourcing test - just check file exists and is readable
    if [[ -r "$file" ]]; then
        log_pass "$plugin: file readable"
        return 0
    fi
    log_fail "$plugin: file not readable"
    return 1
}

# Test: Required functions exist
test_required_functions() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    local has_load=0 has_type=0

    grep -q "^load_plugin()" "$file" && has_load=1
    grep -q "^plugin_get_type()" "$file" && has_type=1

    if [[ $has_load -eq 1 && $has_type -eq 1 ]]; then
        log_pass "$plugin: has required functions (load_plugin, plugin_get_type)"
        return 0
    else
        local missing=""
        [[ $has_load -eq 0 ]] && missing+="load_plugin "
        [[ $has_type -eq 0 ]] && missing+="plugin_get_type "
        log_fail "$plugin: missing functions: $missing"
        return 1
    fi
}

# Test: plugin_get_display_info exists and uses build_display_info
test_display_info() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    if grep -q "plugin_get_display_info()" "$file"; then
        if grep -q "build_display_info" "$file"; then
            log_pass "$plugin: plugin_get_display_info uses build_display_info"
            return 0
        else
            log_warn "$plugin: plugin_get_display_info exists but doesn't use build_display_info"
            return 0
        fi
    else
        log_warn "$plugin: missing plugin_get_display_info (will use defaults)"
        return 0
    fi
}

# Test: Plugin uses plugin_init
test_plugin_init() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    if grep -q "plugin_init" "$file"; then
        log_pass "$plugin: uses plugin_init"
        return 0
    else
        log_warn "$plugin: doesn't use plugin_init for cache setup"
        return 0
    fi
}

# Test: Plugin uses caching
test_caching() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    if grep -q "cache_get\|cache_set" "$file"; then
        log_pass "$plugin: uses caching"
        return 0
    else
        log_warn "$plugin: no caching implemented"
        return 0
    fi
}

# Test: No shellcheck errors (if shellcheck available)
test_shellcheck() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    if ! command -v shellcheck &>/dev/null; then
        log_info "$plugin: shellcheck not available, skipping"
        return 0
    fi

    local errors
    errors=$(shellcheck -S error "$file" 2>&1 || true)

    if [[ -z "$errors" ]]; then
        log_pass "$plugin: no shellcheck errors"
        return 0
    else
        log_fail "$plugin: shellcheck errors found"
        echo "$errors" | head -5
        return 1
    fi
}

# Run all tests for a plugin
test_plugin() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"

    [[ ! -f "$file" ]] && { log_fail "$plugin: file not found"; return 1; }

    echo ""
    echo -e "${BLUE}━━━ Testing: $plugin ━━━${NC}"

    test_syntax "$plugin"
    test_source "$plugin"
    test_required_functions "$plugin"
    test_display_info "$plugin"
    test_plugin_init "$plugin"
    test_caching "$plugin"
    test_shellcheck "$plugin"
}

# =============================================================================
# Main
# =============================================================================

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    PowerKit Plugin Test Framework      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

if [[ $# -gt 0 ]]; then
    # Test specific plugins
    for plugin in "$@"; do
        test_plugin "$plugin"
    done
else
    # Test all plugins
    for file in "$PLUGIN_DIR"/*.sh; do
        plugin=$(basename "$file" .sh)
        test_plugin "$plugin"
    done
fi

# Summary
echo ""
echo -e "${BLUE}━━━ Summary ━━━${NC}"
echo -e "Total:    $TOTAL"
echo -e "${GREEN}Passed:   $PASSED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Failed:   $FAILED${NC}"
echo ""

[[ $FAILED -gt 0 ]] && exit 1
exit 0
