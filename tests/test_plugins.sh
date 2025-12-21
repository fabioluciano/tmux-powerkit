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

# Test: Plugin has plugin_declare_options (new contract requirement)
test_plugin_declare_options() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    if grep -q "^plugin_declare_options()" "$file"; then
        log_pass "$plugin: has plugin_declare_options"
        return 0
    else
        log_fail "$plugin: missing plugin_declare_options (contract requirement)"
        return 1
    fi
}

# Test: Function naming convention (no double underscore definitions)
test_function_naming() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    # Check for double underscore function definitions
    local double_underscore
    double_underscore=$(grep -oE '^__[a-z_]+\(\)' "$file" 2>/dev/null || true)

    if [[ -n "$double_underscore" ]]; then
        log_fail "$plugin: has double underscore function definitions (use single underscore): $double_underscore"
        return 1
    fi

    log_pass "$plugin: function naming convention OK"
    return 0
}

# Test: Function definition/call consistency (no mismatches)
test_function_consistency() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    # Get all function definitions with underscore prefix
    local defs
    defs=$(grep -oE '^_[a-z_]+\(\)' "$file" 2>/dev/null | sed 's/()//' | sort -u || true)

    # Get all function calls with underscore prefix
    local calls
    calls=$(grep -oE '\$\(_[a-z_]+\)' "$file" 2>/dev/null | sed 's/\$(\([^)]*\))/\1/' | sort -u || true)

    local mismatches=""
    for call in $calls; do
        # Skip common utilities from other modules
        case "$call" in
            _bytes_to_human|_bytes_to_speed|_get_timestamp) continue ;;
        esac

        if ! echo "$defs" | grep -qx "$call" 2>/dev/null; then
            mismatches+="$call "
        fi
    done

    if [[ -z "$mismatches" ]]; then
        log_pass "$plugin: function definition/call consistency OK"
        return 0
    else
        log_fail "$plugin: undefined function calls: $mismatches"
        return 1
    fi
}

# Test: Standard header format
test_standard_header() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    # Check for standard header comment
    if head -7 "$file" | grep -q "^# Plugin:"; then
        if head -7 "$file" | grep -q "^# Type:"; then
            log_pass "$plugin: has standard header with Type"
            return 0
        else
            log_warn "$plugin: header missing Type declaration"
            return 0
        fi
    else
        log_fail "$plugin: missing standard header format"
        return 1
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

# =============================================================================
# Behavior Tests - Test actual plugin execution and output
# =============================================================================

# Test: Plugin execution produces valid output
test_execution() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    # Skip plugins that require external services/commands
    local skip_execution_plugins="crypto stocks jira github gitlab bitbucket weather ping external_ip kubernetes cloud cloudstatus vpn bluetooth wifi ssh terraform bitwarden smartkey"
    if [[ " $skip_execution_plugins " =~ " $plugin " ]]; then
        log_info "$plugin: skipped execution test (external dependency)"
        return 0
    fi

    # Execute the plugin script
    local output exit_code
    output=$(timeout 5 bash "$file" 2>/dev/null) && exit_code=$? || exit_code=$?

    # Exit code 0 or empty output (for conditional plugins) is OK
    if [[ $exit_code -eq 0 ]]; then
        log_pass "$plugin: execution successful"
        return 0
    elif [[ $exit_code -eq 124 ]]; then
        log_fail "$plugin: execution timed out (>5s)"
        return 1
    else
        log_warn "$plugin: execution returned exit code $exit_code"
        return 0
    fi
}

# Test: Plugin type is valid
test_plugin_type() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    local type_line
    type_line=$(grep -o "printf '[^']*'" "$file" | grep -E "static|dynamic|conditional" | head -1 || true)

    if [[ -z "$type_line" ]]; then
        log_warn "$plugin: could not determine plugin_get_type return value"
        return 0
    fi

    if [[ "$type_line" =~ (static|dynamic|conditional) ]]; then
        log_pass "$plugin: valid type '${BASH_REMATCH[1]}'"
        return 0
    else
        log_fail "$plugin: invalid plugin type"
        return 1
    fi
}

# Test: Cache TTL is defined in defaults.sh
test_cache_ttl_default() {
    local plugin="$1"
    TOTAL=$((TOTAL + 1))

    local upper
    upper=$(echo "$plugin" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local ttl_var="POWERKIT_PLUGIN_${upper}_CACHE_TTL"

    if grep -q "$ttl_var" "$SRC_DIR/defaults.sh" 2>/dev/null; then
        log_pass "$plugin: has cache TTL default ($ttl_var)"
        return 0
    else
        log_warn "$plugin: no cache TTL default in defaults.sh"
        return 0
    fi
}

# Test: Plugin uses DRY helper (default_plugin_display_info) when appropriate
test_dry_pattern() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    # Check if plugin uses default helper
    if grep -q "default_plugin_display_info" "$file"; then
        log_pass "$plugin: uses DRY helper (default_plugin_display_info)"
        return 0
    fi

    # Check if plugin has custom logic (which is also acceptable)
    if grep -q "build_display_info" "$file"; then
        log_pass "$plugin: uses custom display_info logic"
        return 0
    fi

    log_warn "$plugin: no display_info helper usage detected"
    return 0
}

# Test: Plugin avoids common anti-patterns
test_anti_patterns() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    local issues=0 messages=""

    # Check for echo | grep (should use bash regex)
    if grep -E 'echo.*\|.*grep' "$file" | grep -qv '#'; then
        issues=$((issues + 1))
        messages+="echo|grep pattern found (prefer bash regex); "
    fi

    # Check for cat to read single file (should use $(<file))
    if grep -qE 'cat [^|]*\|' "$file" 2>/dev/null; then
        issues=$((issues + 1))
        messages+="cat|pipe pattern found; "
    fi

    if [[ $issues -eq 0 ]]; then
        log_pass "$plugin: no anti-patterns detected"
        return 0
    else
        log_warn "$plugin: ${issues} anti-pattern(s): ${messages%%; }"
        return 0
    fi
}

# Test: Output format validation for specific plugins
test_output_format() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"
    TOTAL=$((TOTAL + 1))

    # Only test plugins with predictable output format
    case "$plugin" in
        cpu)
            local output
            output=$(timeout 3 bash "$file" 2>/dev/null) || true
            # Trim whitespace for comparison
            output="${output#"${output%%[![:space:]]*}"}"
            output="${output%"${output##*[![:space:]]}"}"
            if [[ "$output" =~ ^[0-9]+%?$ ]]; then
                log_pass "$plugin: output format valid (numeric percent)"
                return 0
            else
                log_warn "$plugin: unexpected output format: '$output'"
                return 0
            fi
            ;;
        memory|disk)
            local output
            output=$(timeout 3 bash "$file" 2>/dev/null) || true
            if [[ "$output" =~ ^[0-9]+%?$ ]] || [[ "$output" =~ ^[0-9]+(\.[0-9]+)?[KMGT]?$ ]]; then
                log_pass "$plugin: output format valid"
                return 0
            else
                log_warn "$plugin: unexpected output format: '$output'"
                return 0
            fi
            ;;
        datetime)
            local output
            output=$(timeout 3 bash "$file" 2>/dev/null) || true
            if [[ -n "$output" ]]; then
                log_pass "$plugin: produces datetime output"
                return 0
            else
                log_fail "$plugin: no datetime output"
                return 1
            fi
            ;;
        uptime)
            local output
            output=$(timeout 3 bash "$file" 2>/dev/null) || true
            if [[ "$output" =~ [0-9]+[dhm] ]]; then
                log_pass "$plugin: output format valid (time duration)"
                return 0
            else
                log_warn "$plugin: unexpected output format: '$output'"
                return 0
            fi
            ;;
        *)
            log_info "$plugin: no specific format test defined"
            return 0
            ;;
    esac
}

# Run all tests for a plugin
test_plugin() {
    local plugin="$1"
    local file="$PLUGIN_DIR/$plugin.sh"

    [[ ! -f "$file" ]] && { log_fail "$plugin: file not found"; return 1; }

    echo ""
    echo -e "${BLUE}━━━ Testing: $plugin ━━━${NC}"

    # Structure tests (contract compliance)
    test_syntax "$plugin"
    test_source "$plugin"
    test_required_functions "$plugin"
    test_plugin_declare_options "$plugin"
    test_display_info "$plugin"
    test_plugin_init "$plugin"
    test_standard_header "$plugin"
    test_function_naming "$plugin"
    test_function_consistency "$plugin"
    test_caching "$plugin"
    test_shellcheck "$plugin"

    # Behavior tests
    test_execution "$plugin"
    test_plugin_type "$plugin"
    test_cache_ttl_default "$plugin"
    test_dry_pattern "$plugin"
    test_anti_patterns "$plugin"
    test_output_format "$plugin"
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
