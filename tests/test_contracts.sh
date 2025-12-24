#!/usr/bin/env bash
# =============================================================================
# PowerKit Test: Contract Compliance Validation
# Description: Validates plugins and themes against their contracts
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export POWERKIT_ROOT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== Contract Compliance Validation ==="
echo ""

# Source bootstrap (loads all core modules)
# shellcheck disable=SC1091
. "$POWERKIT_ROOT/src/core/bootstrap.sh"

PLUGIN_FAILED=0
PLUGIN_PASSED=0
THEME_FAILED=0
THEME_PASSED=0

# =============================================================================
# Plugin Contract Validation
# =============================================================================

echo "--- Plugin Contracts ---"
echo ""

PLUGINS_DIR="$POWERKIT_ROOT/src/plugins"

if [[ -d "$PLUGINS_DIR" ]]; then
    for plugin_file in "$PLUGINS_DIR"/*.sh; do
        [[ ! -f "$plugin_file" ]] && continue

        plugin_name=$(basename "$plugin_file" .sh)

        # Reset plugin functions before sourcing
        unset -f plugin_get_metadata plugin_check_dependencies plugin_declare_options \
            plugin_get_content_type plugin_get_presence plugin_get_state plugin_get_health \
            plugin_get_context plugin_get_icon plugin_collect plugin_render plugin_setup_keybindings \
            2>/dev/null || true

        # Source plugin
        # shellcheck disable=SC1090
        if ! . "$plugin_file" 2>/dev/null; then
            echo -e "${RED}✗${NC} $plugin_name - failed to source"
            ((PLUGIN_FAILED++))
            continue
        fi

        # Validate required functions
        MISSING_FUNCS=()

        # Mandatory functions
        declare -F plugin_collect &>/dev/null || MISSING_FUNCS+=("plugin_collect")
        declare -F plugin_get_content_type &>/dev/null || MISSING_FUNCS+=("plugin_get_content_type")
        declare -F plugin_get_presence &>/dev/null || MISSING_FUNCS+=("plugin_get_presence")
        declare -F plugin_get_state &>/dev/null || MISSING_FUNCS+=("plugin_get_state")
        declare -F plugin_get_health &>/dev/null || MISSING_FUNCS+=("plugin_get_health")
        declare -F plugin_render &>/dev/null || MISSING_FUNCS+=("plugin_render")
        declare -F plugin_get_icon &>/dev/null || MISSING_FUNCS+=("plugin_get_icon")

        if [[ ${#MISSING_FUNCS[@]} -gt 0 ]]; then
            echo -e "${RED}✗${NC} $plugin_name - missing: ${MISSING_FUNCS[*]}"
            ((PLUGIN_FAILED++))
        else
            # Validate return values
            ERRORS=()

            # Check content_type
            if declare -F plugin_get_content_type &>/dev/null; then
                content_type=$(plugin_get_content_type 2>/dev/null || echo "")
                if [[ "$content_type" != "static" && "$content_type" != "dynamic" ]]; then
                    ERRORS+=("content_type='$content_type' (expected: static|dynamic)")
                fi
            fi

            # Check presence
            if declare -F plugin_get_presence &>/dev/null; then
                presence=$(plugin_get_presence 2>/dev/null || echo "")
                if [[ "$presence" != "always" && "$presence" != "conditional" ]]; then
                    ERRORS+=("presence='$presence' (expected: always|conditional)")
                fi
            fi

            if [[ ${#ERRORS[@]} -gt 0 ]]; then
                echo -e "${YELLOW}⚠${NC} $plugin_name - warnings: ${ERRORS[*]}"
                ((PLUGIN_PASSED++))  # Still pass but with warnings
            else
                echo -e "${GREEN}✓${NC} $plugin_name"
                ((PLUGIN_PASSED++))
            fi
        fi
    done
else
    echo -e "${YELLOW}No plugins directory found${NC}"
fi

echo ""

# =============================================================================
# Theme Contract Validation
# =============================================================================

echo "--- Theme Contracts ---"
echo ""

THEMES_DIR="$POWERKIT_ROOT/src/themes"

# Required theme colors
REQUIRED_COLORS=(
    "statusbar-bg" "statusbar-fg"
    "session-bg" "session-fg" "session-prefix-bg" "session-copy-bg"
    "window-active-base" "window-inactive-base"
    "pane-border-active" "pane-border-inactive"
    "ok-base" "good-base" "info-base" "warning-base" "error-base" "disabled-base"
    "message-bg" "message-fg"
    "accent" "border"
)

if [[ -d "$THEMES_DIR" ]]; then
    while IFS= read -r -d '' theme_file; do
        [[ ! -f "$theme_file" ]] && continue

        theme_path="${theme_file#$THEMES_DIR/}"
        theme_name="${theme_path%.sh}"

        # Reset THEME_COLORS
        unset THEME_COLORS
        declare -A THEME_COLORS

        # Source theme
        # shellcheck disable=SC1090
        if ! . "$theme_file" 2>/dev/null; then
            echo -e "${RED}✗${NC} $theme_name - failed to source"
            ((THEME_FAILED++))
            continue
        fi

        # Check for THEME_COLORS array
        if [[ ${#THEME_COLORS[@]} -eq 0 ]]; then
            echo -e "${RED}✗${NC} $theme_name - THEME_COLORS not defined or empty"
            ((THEME_FAILED++))
            continue
        fi

        # Check required colors
        MISSING_COLORS=()
        for color in "${REQUIRED_COLORS[@]}"; do
            if [[ -z "${THEME_COLORS[$color]:-}" ]]; then
                MISSING_COLORS+=("$color")
            fi
        done

        if [[ ${#MISSING_COLORS[@]} -gt 0 ]]; then
            echo -e "${RED}✗${NC} $theme_name - missing colors: ${MISSING_COLORS[*]}"
            ((THEME_FAILED++))
        else
            echo -e "${GREEN}✓${NC} $theme_name (${#THEME_COLORS[@]} colors)"
            ((THEME_PASSED++))
        fi
    done < <(find "$THEMES_DIR" -name "*.sh" -print0 2>/dev/null)
else
    echo -e "${YELLOW}No themes directory found${NC}"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================

echo "=== Summary ==="
echo ""

TOTAL_FAILED=$((PLUGIN_FAILED + THEME_FAILED))
TOTAL_PASSED=$((PLUGIN_PASSED + THEME_PASSED))

echo -e "Plugins: ${GREEN}${PLUGIN_PASSED} passed${NC}, ${RED}${PLUGIN_FAILED} failed${NC}"
echo -e "Themes:  ${GREEN}${THEME_PASSED} passed${NC}, ${RED}${THEME_FAILED} failed${NC}"
echo ""

if [[ $TOTAL_FAILED -gt 0 ]]; then
    echo -e "${RED}Contract validation FAILED${NC}"
    exit 1
fi

echo -e "${GREEN}Contract validation PASSED${NC}"
exit 0
