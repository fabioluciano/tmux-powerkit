#!/usr/bin/env bash
# =============================================================================
# PowerKit Test: Bash Syntax Validation
# Description: Validates bash 4+ syntax for all .sh files
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

FAILED=0
PASSED=0
TOTAL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== Bash Syntax Validation ==="
echo ""

# Check bash version
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo -e "${RED}ERROR: Bash 4+ required, found ${BASH_VERSION}${NC}"
    exit 1
fi

echo "Bash version: ${BASH_VERSION}"
echo ""

# Directories to check
DIRS=(
    "$POWERKIT_ROOT/src/core"
    "$POWERKIT_ROOT/src/utils"
    "$POWERKIT_ROOT/src/contract"
    "$POWERKIT_ROOT/src/renderer"
    "$POWERKIT_ROOT/src/plugins"
    "$POWERKIT_ROOT/src/helpers"
    "$POWERKIT_ROOT/src/themes"
    "$POWERKIT_ROOT/src/native"
    "$POWERKIT_ROOT/bin"
    "$POWERKIT_ROOT/scripts"
    "$POWERKIT_ROOT/tests"
)

for dir in "${DIRS[@]}"; do
    [[ ! -d "$dir" ]] && continue

    while IFS= read -r -d '' file; do
        ((TOTAL++)) || true

        if bash -n "$file" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $(basename "$file")"
            ((PASSED++)) || true
        else
            echo -e "${RED}✗ FAIL:${NC} $file"
            bash -n "$file" 2>&1 | head -5 | sed 's/^/  /'
            ((FAILED++)) || true
        fi
    done < <(find "$dir" -name "*.sh" -print0 2>/dev/null) || true
done

echo ""
echo "=== Results ==="
echo -e "Total:  ${TOTAL}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo -e "${RED}Bash syntax validation FAILED${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Bash syntax validation PASSED${NC}"
exit 0
