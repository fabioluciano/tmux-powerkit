#!/usr/bin/env bash
# =============================================================================
# PowerKit Test Suite Runner
# Description: Runs all tests in sequence and reports results
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

TOTAL_FAILED=0
TESTS_RUN=0

# Print header
print_header() {
    echo ""
    echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║     PowerKit v2 Test Suite                ║${NC}"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════╝${NC}"
    echo ""
}

# Print test section header
print_section() {
    local title="$1"
    echo -e "${BOLD}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│ $title${NC}"
    echo -e "${BOLD}└─────────────────────────────────────────┘${NC}"
}

# Run a test and track result
run_test() {
    local test_name="$1"
    local test_file="$2"

    ((TESTS_RUN++))

    print_section "Test $TESTS_RUN: $test_name"
    echo ""

    if [[ ! -f "$test_file" ]]; then
        echo -e "${YELLOW}SKIP: Test file not found: $test_file${NC}"
        return 0
    fi

    if [[ ! -x "$test_file" ]]; then
        chmod +x "$test_file"
    fi

    if bash "$test_file"; then
        echo ""
        echo -e "Result: ${GREEN}✓ PASS${NC}"
    else
        echo ""
        echo -e "Result: ${RED}✗ FAIL${NC}"
        ((TOTAL_FAILED++))
    fi
    echo ""
}

# Print summary
print_summary() {
    echo -e "${BOLD}╔═══════════════════════════════════════════╗${NC}"
    if [[ $TOTAL_FAILED -eq 0 ]]; then
        echo -e "${BOLD}║  ${GREEN}ALL TESTS PASSED ✓${NC}${BOLD}                       ║${NC}"
    else
        printf "${BOLD}║  ${RED}%d TEST(S) FAILED ✗${NC}${BOLD}                      ║\n" "$TOTAL_FAILED"
    fi
    echo -e "${BOLD}╚═══════════════════════════════════════════╝${NC}"
}

# =============================================================================
# Main
# =============================================================================

print_header

# Test 1: Bash Syntax
run_test "Bash Syntax Validation" "$SCRIPT_DIR/test_bash_syntax.sh"

# Test 2: ShellCheck
run_test "ShellCheck Validation" "$SCRIPT_DIR/test_shellcheck.sh"

# Test 3: Contract Compliance
run_test "Contract Compliance" "$SCRIPT_DIR/test_contracts.sh"

# Summary
print_summary

exit $TOTAL_FAILED
