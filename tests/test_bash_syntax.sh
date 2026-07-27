#!/usr/bin/env bash
# =============================================================================
# PowerKit Test: Bash Syntax Validation
# Description: Validates bash 5.3+ syntax for all .sh files
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
NC='\033[0m' # No Color

echo "=== Bash Syntax Validation ==="
echo ""

# Check bash version (5.3+ required for ${arr[@]@K} and modern features)
if ((BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3))); then
    echo -e "${RED}ERROR: Bash 5.3+ required, found ${BASH_VERSION}${NC}"
    echo -e "${RED}Install: brew install bash (macOS) or use distro bash 5.3+ (Linux)${NC}"
    exit 1
fi

echo "Bash version: ${BASH_VERSION}"
echo ""

while IFS= read -r -d '' relative_file; do
    file="${POWERKIT_ROOT}/${relative_file}"
    ((TOTAL++)) || true

    if bash -n "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $(basename "$file")"
        ((PASSED++)) || true
    else
        echo -e "${RED}✗ FAIL:${NC} $relative_file"
        bash -n "$file" 2>&1 | head -5 | sed 's/^/  /'
        ((FAILED++)) || true
    fi
done < <(git -C "$POWERKIT_ROOT" ls-files -z -- '*.sh' '*.bash' '*.tmux' 'bin/*' 'scripts/*')

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
