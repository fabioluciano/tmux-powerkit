#!/usr/bin/env bash
# =============================================================================
# PowerKit Test: Contract Compliance Validation
# Description: Validates plugins, themes, contracts, and utilities
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

# Source bootstrap (loads core and utils modules)
# shellcheck disable=SC1091
. "$POWERKIT_ROOT/src/core/bootstrap.sh"

# Load contract modules (not auto-loaded by bootstrap)
_load_contract_modules

PLUGIN_FAILED=0
PLUGIN_PASSED=0
THEME_FAILED=0
THEME_PASSED=0
CONTRACT_FAILED=0
CONTRACT_PASSED=0
UTILITY_FAILED=0
UTILITY_PASSED=0

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
            ((PLUGIN_FAILED++)) || true
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
            ((PLUGIN_FAILED++)) || true
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
                ((PLUGIN_PASSED++)) || true  # Still pass but with warnings
            else
                echo -e "${GREEN}✓${NC} $plugin_name"
                ((PLUGIN_PASSED++)) || true
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
            ((THEME_FAILED++)) || true
            continue
        fi

        # Check for THEME_COLORS array
        if [[ ${#THEME_COLORS[@]} -eq 0 ]]; then
            echo -e "${RED}✗${NC} $theme_name - THEME_COLORS not defined or empty"
            ((THEME_FAILED++)) || true
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
            ((THEME_FAILED++)) || true
        else
            echo -e "${GREEN}✓${NC} $theme_name (${#THEME_COLORS[@]} colors)"
            ((THEME_PASSED++)) || true
        fi
    done < <(find "$THEMES_DIR" -name "*.sh" -print0 2>/dev/null) || true
else
    echo -e "${YELLOW}No themes directory found${NC}"
fi

echo ""

# =============================================================================
# Contract Module Validation
# =============================================================================

echo "--- Contract Modules ---"
echo ""

CONTRACTS_DIR="$POWERKIT_ROOT/src/contract"

# Session Contract
if [[ -f "$CONTRACTS_DIR/session_contract.sh" ]]; then
    MISSING_FUNCS=()

    # Check required functions
    declare -F session_get_state &>/dev/null || MISSING_FUNCS+=("session_get_state")
    declare -F session_get_mode &>/dev/null || MISSING_FUNCS+=("session_get_mode")
    declare -F session_get_name &>/dev/null || MISSING_FUNCS+=("session_get_name")
    declare -F session_get_icon &>/dev/null || MISSING_FUNCS+=("session_get_icon")
    declare -F session_render &>/dev/null || MISSING_FUNCS+=("session_render")
    declare -F session_get_all &>/dev/null || MISSING_FUNCS+=("session_get_all")

    if [[ ${#MISSING_FUNCS[@]} -gt 0 ]]; then
        echo -e "${RED}✗${NC} session_contract - missing: ${MISSING_FUNCS[*]}"
        ((CONTRACT_FAILED++)) || true
    else
        echo -e "${GREEN}✓${NC} session_contract"
        ((CONTRACT_PASSED++)) || true
    fi
else
    echo -e "${YELLOW}⚠${NC} session_contract - file not found"
fi

# Window Contract
if [[ -f "$CONTRACTS_DIR/window_contract.sh" ]]; then
    MISSING_FUNCS=()

    # Check required functions
    declare -F window_index_format &>/dev/null || MISSING_FUNCS+=("window_index_format")
    declare -F window_name_format &>/dev/null || MISSING_FUNCS+=("window_name_format")
    declare -F window_basic_format &>/dev/null || MISSING_FUNCS+=("window_basic_format")
    declare -F window_zoom_format &>/dev/null || MISSING_FUNCS+=("window_zoom_format")
    declare -F window_get_icon_format &>/dev/null || MISSING_FUNCS+=("window_get_icon_format")
    declare -F window_get_active_format &>/dev/null || MISSING_FUNCS+=("window_get_active_format")
    declare -F window_get_inactive_format &>/dev/null || MISSING_FUNCS+=("window_get_inactive_format")

    if [[ ${#MISSING_FUNCS[@]} -gt 0 ]]; then
        echo -e "${RED}✗${NC} window_contract - missing: ${MISSING_FUNCS[*]}"
        ((CONTRACT_FAILED++)) || true
    else
        echo -e "${GREEN}✓${NC} window_contract"
        ((CONTRACT_PASSED++)) || true
    fi
else
    echo -e "${YELLOW}⚠${NC} window_contract - file not found"
fi

# Pane Contract
if [[ -f "$CONTRACTS_DIR/pane_contract.sh" ]]; then
    MISSING_FUNCS=()

    # Check required functions
    declare -F pane_get_state &>/dev/null || MISSING_FUNCS+=("pane_get_state")
    declare -F pane_is_active &>/dev/null || MISSING_FUNCS+=("pane_is_active")
    declare -F pane_is_zoomed &>/dev/null || MISSING_FUNCS+=("pane_is_zoomed")
    declare -F pane_get_id &>/dev/null || MISSING_FUNCS+=("pane_get_id")
    declare -F pane_get_index &>/dev/null || MISSING_FUNCS+=("pane_get_index")
    declare -F pane_get_all &>/dev/null || MISSING_FUNCS+=("pane_get_all")
    declare -F pane_flash_trigger &>/dev/null || MISSING_FUNCS+=("pane_flash_trigger")
    declare -F pane_flash_is_enabled &>/dev/null || MISSING_FUNCS+=("pane_flash_is_enabled")
    declare -F pane_flash_enable &>/dev/null || MISSING_FUNCS+=("pane_flash_enable")
    declare -F pane_flash_disable &>/dev/null || MISSING_FUNCS+=("pane_flash_disable")
    declare -F pane_border_color &>/dev/null || MISSING_FUNCS+=("pane_border_color")
    declare -F pane_border_style &>/dev/null || MISSING_FUNCS+=("pane_border_style")
    declare -F pane_configure &>/dev/null || MISSING_FUNCS+=("pane_configure")

    if [[ ${#MISSING_FUNCS[@]} -gt 0 ]]; then
        echo -e "${RED}✗${NC} pane_contract - missing: ${MISSING_FUNCS[*]}"
        ((CONTRACT_FAILED++)) || true
    else
        echo -e "${GREEN}✓${NC} pane_contract"
        ((CONTRACT_PASSED++)) || true
    fi
else
    echo -e "${YELLOW}⚠${NC} pane_contract - file not found"
fi

echo ""

# =============================================================================
# Utility Module Validation
# =============================================================================

echo "--- Utility Modules ---"
echo ""

UTILS_DIR="$POWERKIT_ROOT/src/utils"

# Hooks Utility
if [[ -f "$UTILS_DIR/hooks.sh" ]]; then
    MISSING_FUNCS=()

    # Check required functions
    declare -F register_hook &>/dev/null || MISSING_FUNCS+=("register_hook")
    declare -F register_hook_local &>/dev/null || MISSING_FUNCS+=("register_hook_local")
    declare -F unregister_hook &>/dev/null || MISSING_FUNCS+=("unregister_hook")
    declare -F unregister_hook_local &>/dev/null || MISSING_FUNCS+=("unregister_hook_local")
    declare -F list_hooks &>/dev/null || MISSING_FUNCS+=("list_hooks")
    declare -F has_hook &>/dev/null || MISSING_FUNCS+=("has_hook")
    declare -F clear_all_hooks &>/dev/null || MISSING_FUNCS+=("clear_all_hooks")
    declare -F run_delayed &>/dev/null || MISSING_FUNCS+=("run_delayed")
    declare -F run_delayed_ms &>/dev/null || MISSING_FUNCS+=("run_delayed_ms")

    if [[ ${#MISSING_FUNCS[@]} -gt 0 ]]; then
        echo -e "${RED}✗${NC} hooks - missing: ${MISSING_FUNCS[*]}"
        ((UTILITY_FAILED++)) || true
    else
        echo -e "${GREEN}✓${NC} hooks"
        ((UTILITY_PASSED++)) || true
    fi
else
    echo -e "${YELLOW}⚠${NC} hooks - file not found"
fi

# Platform Utility
if [[ -f "$UTILS_DIR/platform.sh" ]]; then
    MISSING_FUNCS=()

    # Check required functions
    declare -F get_os &>/dev/null || MISSING_FUNCS+=("get_os")
    declare -F is_macos &>/dev/null || MISSING_FUNCS+=("is_macos")
    declare -F is_linux &>/dev/null || MISSING_FUNCS+=("is_linux")
    declare -F has_cmd &>/dev/null || MISSING_FUNCS+=("has_cmd")

    if [[ ${#MISSING_FUNCS[@]} -gt 0 ]]; then
        echo -e "${RED}✗${NC} platform - missing: ${MISSING_FUNCS[*]}"
        ((UTILITY_FAILED++)) || true
    else
        echo -e "${GREEN}✓${NC} platform"
        ((UTILITY_PASSED++)) || true
    fi
else
    echo -e "${YELLOW}⚠${NC} platform - file not found"
fi

# Strings Utility
if [[ -f "$UTILS_DIR/strings.sh" ]]; then
    MISSING_FUNCS=()

    # Check required functions
    declare -F trim &>/dev/null || MISSING_FUNCS+=("trim")
    declare -F truncate_text &>/dev/null || MISSING_FUNCS+=("truncate_text")
    declare -F join_with_separator &>/dev/null || MISSING_FUNCS+=("join_with_separator")

    if [[ ${#MISSING_FUNCS[@]} -gt 0 ]]; then
        echo -e "${RED}✗${NC} strings - missing: ${MISSING_FUNCS[*]}"
        ((UTILITY_FAILED++)) || true
    else
        echo -e "${GREEN}✓${NC} strings"
        ((UTILITY_PASSED++)) || true
    fi
else
    echo -e "${YELLOW}⚠${NC} strings - file not found"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================

echo "=== Summary ==="
echo ""

TOTAL_FAILED=$((PLUGIN_FAILED + THEME_FAILED + CONTRACT_FAILED + UTILITY_FAILED))
TOTAL_PASSED=$((PLUGIN_PASSED + THEME_PASSED + CONTRACT_PASSED + UTILITY_PASSED))

echo -e "Plugins:   ${GREEN}${PLUGIN_PASSED} passed${NC}, ${RED}${PLUGIN_FAILED} failed${NC}"
echo -e "Themes:    ${GREEN}${THEME_PASSED} passed${NC}, ${RED}${THEME_FAILED} failed${NC}"
echo -e "Contracts: ${GREEN}${CONTRACT_PASSED} passed${NC}, ${RED}${CONTRACT_FAILED} failed${NC}"
echo -e "Utilities: ${GREEN}${UTILITY_PASSED} passed${NC}, ${RED}${UTILITY_FAILED} failed${NC}"
echo ""

if [[ $TOTAL_FAILED -gt 0 ]]; then
    echo -e "${RED}Contract validation FAILED${NC}"
    exit 1
fi

echo -e "${GREEN}Contract validation PASSED${NC}"
exit 0
