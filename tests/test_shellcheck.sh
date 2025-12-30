#!/usr/bin/env bash
# =============================================================================
# PowerKit Test: ShellCheck Validation
# Description: Validates shell scripts using shellcheck (parallel xargs mode)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Temp files for results
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "=== ShellCheck Validation ==="
echo ""

# Check if shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
    echo -e "${YELLOW}WARNING: shellcheck not installed, skipping validation${NC}"
    echo "Install with: brew install shellcheck (macOS) or apt-get install shellcheck (Linux)"
    exit 0
fi

echo "ShellCheck version: $(shellcheck --version | head -2 | tail -1)"

# Determine number of parallel jobs
if command -v nproc &>/dev/null; then
    JOBS=$(nproc)
elif command -v sysctl &>/dev/null; then
    JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
else
    JOBS=4
fi
echo "Parallel jobs: $JOBS"
echo ""

# Directories to check (standard rules)
DIRS=(
    "$POWERKIT_ROOT/src/core"
    "$POWERKIT_ROOT/src/utils"
    "$POWERKIT_ROOT/src/contract"
    "$POWERKIT_ROOT/src/renderer"
    "$POWERKIT_ROOT/src/plugins"
    "$POWERKIT_ROOT/src/helpers"
    "$POWERKIT_ROOT/src/native"
    "$POWERKIT_ROOT/bin"
    "$POWERKIT_ROOT/scripts"
)

# =============================================================================
# Collect all files
# =============================================================================
FILE_LIST="$TEMP_DIR/files.txt"
THEME_FILE_LIST="$TEMP_DIR/theme_files.txt"
RESULTS_FILE="$TEMP_DIR/results.txt"

for dir in "${DIRS[@]}"; do
    [[ ! -d "$dir" ]] && continue
    find "$dir" -name "*.sh" -type f 2>/dev/null >> "$FILE_LIST" || true
done

if [[ -d "$POWERKIT_ROOT/src/themes" ]]; then
    find "$POWERKIT_ROOT/src/themes" -name "*.sh" -type f 2>/dev/null >> "$THEME_FILE_LIST" || true
fi

TOTAL=$(wc -l < "$FILE_LIST" 2>/dev/null | tr -d ' ' || echo 0)
THEME_TOTAL=$(wc -l < "$THEME_FILE_LIST" 2>/dev/null | tr -d ' ' || echo 0)

echo "Files to check: $TOTAL standard + $THEME_TOTAL themes"
echo ""

# =============================================================================
# Check function (called by xargs)
# =============================================================================
_check_file() {
    local file="$1"
    local severity="$2"
    local results_file="$3"

    if shellcheck -S "$severity" "$file" >/dev/null 2>&1; then
        echo "PASS:$(basename "$file")" >> "$results_file"
    else
        echo "FAIL:$file" >> "$results_file"
    fi
}
export -f _check_file

# =============================================================================
# Run shellcheck in parallel for standard files
# =============================================================================
echo "--- Standard files ---"

if [[ -s "$FILE_LIST" ]]; then
    cat "$FILE_LIST" | xargs -P "$JOBS" -I {} bash -c '_check_file "$@"' _ {} "warning" "$RESULTS_FILE"
fi

# =============================================================================
# Run shellcheck in parallel for theme files (syntax errors only)
# =============================================================================
if [[ -s "$THEME_FILE_LIST" ]]; then
    echo ""
    echo "--- Themes (syntax only) ---"
    cat "$THEME_FILE_LIST" | xargs -P "$JOBS" -I {} bash -c '_check_file "$@"' _ {} "error" "$RESULTS_FILE"
fi

# =============================================================================
# Process and display results
# =============================================================================
PASSED=0
FAILED=0

if [[ -f "$RESULTS_FILE" ]]; then
    # Sort results for consistent output (FAIL before PASS for visibility)
    sort -r "$RESULTS_FILE" -o "$RESULTS_FILE"

    while IFS=: read -r status file; do
        case "$status" in
            PASS)
                printf "${GREEN}✓${NC} %s\n" "$file"
                ((PASSED++)) || true
                ;;
            FAIL)
                printf "${RED}✗ FAIL:${NC} %s\n" "$file"
                # Show errors for this specific file (|| true to prevent set -e exit)
                shellcheck -S warning "$file" 2>&1 | head -10 | sed 's/^/  /' || true
                ((FAILED++)) || true
                ;;
        esac
    done < "$RESULTS_FILE"
else
    echo "WARNING: No results file found"
fi

TOTAL_CHECKED=$((PASSED + FAILED))

echo ""
echo "=== Results ==="
echo -e "Total:  ${TOTAL_CHECKED}"
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
