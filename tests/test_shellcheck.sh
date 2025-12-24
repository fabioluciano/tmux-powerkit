#!/usr/bin/env bash
# =============================================================================
# PowerKit Test: ShellCheck Validation
# Description: Validates shell scripts using shellcheck
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

FAILED=0
PASSED=0
SKIPPED=0
TOTAL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== ShellCheck Validation ==="
echo ""

# Check if shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
    echo -e "${YELLOW}WARNING: shellcheck not installed, skipping validation${NC}"
    echo "Install with: brew install shellcheck (macOS) or apt-get install shellcheck (Linux)"
    exit 0
fi

echo "ShellCheck version: $(shellcheck --version | head -2 | tail -1)"
echo ""

# Directories to check
DIRS=(
    "$POWERKIT_ROOT/src/core"
    "$POWERKIT_ROOT/src/utils"
    "$POWERKIT_ROOT/src/contract"
    "$POWERKIT_ROOT/src/renderer"
    "$POWERKIT_ROOT/src/plugins"
    "$POWERKIT_ROOT/src/helpers"
    "$POWERKIT_ROOT/bin"
)

# ShellCheck options
# -x: Follow external sources
# -S warning: Severity level (error, warning, info, style)
SHELLCHECK_OPTS="-x -S warning"

for dir in "${DIRS[@]}"; do
    [[ ! -d "$dir" ]] && continue

    while IFS= read -r -d '' file; do
        ((TOTAL++)) || true

        # shellcheck disable=SC2086
        if shellcheck $SHELLCHECK_OPTS "$file" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $(basename "$file")"
            ((PASSED++)) || true
        else
            echo -e "${RED}✗ FAIL:${NC} $file"
            # Show first few errors
            # shellcheck disable=SC2086
            shellcheck $SHELLCHECK_OPTS "$file" 2>&1 | head -10 | sed 's/^/  /'
            ((FAILED++)) || true
        fi
    done < <(find "$dir" -name "*.sh" -print0 2>/dev/null) || true
done

# Check themes separately with less strict rules (they're just variable declarations)
if [[ -d "$POWERKIT_ROOT/src/themes" ]]; then
    echo ""
    echo "--- Themes (syntax only) ---"
    while IFS= read -r -d '' file; do
        ((TOTAL++)) || true

        if shellcheck -x -S error "$file" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $(basename "$file")"
            ((PASSED++)) || true
        else
            echo -e "${RED}✗ FAIL:${NC} $file"
            shellcheck -x -S error "$file" 2>&1 | head -5 | sed 's/^/  /'
            ((FAILED++)) || true
        fi
    done < <(find "$POWERKIT_ROOT/src/themes" -name "*.sh" -print0 2>/dev/null) || true
fi

echo ""
echo "=== Results ==="
echo -e "Total:  ${TOTAL}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo -e "${RED}ShellCheck validation FAILED${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}ShellCheck validation PASSED${NC}"
exit 0
