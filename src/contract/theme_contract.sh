#!/usr/bin/env bash
# =============================================================================
#  THEME CONTRACT
#  Contract definition and validation for PowerKit themes
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. Theme Structure
#   3. Required Colors
#   4. Optional Colors
#   5. Color Variant System
#   6. Validation API
#   7. Examples
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# The Theme Contract defines the structure and requirements for PowerKit themes.
# Themes provide the color palette that determines the visual appearance of all
# tmux elements rendered by PowerKit.
#
# Key Concepts:
#   - Themes must define a THEME_COLORS associative array
#   - All required colors must be present for the theme to be valid
#   - Colors use semantic names that indicate WHERE/HOW they are used
#   - Base colors (like ok-base) get auto-generated variants (-lighter, -darker)
#
# Theme Location:
#   - Built-in themes: src/themes/{theme-name}/{variant}.sh
#   - Custom themes: Set @powerkit_custom_theme_path in tmux.conf
#
# =============================================================================
#
# 2. THEME STRUCTURE
# ==================
#
# A theme file must:
#   1. Define a THEME_COLORS associative array
#   2. Include all required colors (see section 3)
#   3. Use valid color formats (#RRGGBB, NONE, or default)
#   4. Optionally export THEME_COLORS
#
# Basic structure:
#
#   #!/usr/bin/env bash
#   declare -gA THEME_COLORS=(
#       [statusbar-bg]="#1a1b26"
#       [statusbar-fg]="#c0caf5"
#       # ... more colors ...
#   )
#   export THEME_COLORS
#
# =============================================================================
#
# 3. REQUIRED COLORS
# ==================
#
# Themes must define a THEME_COLORS associative array with at least:
#
# Status Bar:
#   - statusbar-bg     : Status bar background color
#   - statusbar-fg     : Status bar foreground/text color
#
# Session:
#   - session-bg       : Session segment background
#   - session-fg       : Session segment foreground
#   - session-prefix-bg: Session background when prefix pressed
#   - session-copy-bg  : Session background in copy mode
#
# Windows (base colors - variants auto-generated):
#   - window-active-base   : Active window base color
#   - window-inactive-base : Inactive window base color
#
# Pane Borders:
#   - pane-border-active   : Active pane border color
#   - pane-border-inactive : Inactive pane border color
#
# Health States (base colors - variants auto-generated):
#   - ok-base       : Normal/good state
#   - good-base     : Better than ok state
#   - info-base     : Informational state
#   - warning-base  : Warning state
#   - error-base    : Error/critical state
#   - disabled-base : Disabled/inactive state
#
# Messages:
#   - message-bg : Message popup background
#   - message-fg : Message popup foreground
#
# Color Format:
#   - Must be hex format: #RRGGBB (e.g., #ff5500)
#   - Special values allowed: "NONE", "default"
#
# =============================================================================
#
# 3. API REFERENCE
# ================
#
#   validate_theme FILE
#       Validate a single theme file.
#       Returns: 0 if valid, 1 if invalid
#
#   validate_all_themes DIRECTORY
#       Validate all themes in a directory (including subdirectories).
#       Returns: 0 if all valid, 1 if any invalid
#
#   list_required_theme_colors
#       List all required color names.
#       Output: One color name per line
#
# =============================================================================
#
# 4. USAGE EXAMPLES
# =================
#
#   # Validate a single theme
#   validate_theme "src/themes/tokyo-night/night.sh"
#
#   # Validate all themes
#   validate_all_themes "src/themes"
#
#   # Check required colors
#   list_required_theme_colors
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "contract_theme" && return 0

# Note: All core and utils modules are loaded by bootstrap.sh

# =============================================================================
# Required Theme Colors
# =============================================================================

# Required colors that every theme must define
declare -gra THEME_REQUIRED_COLORS=(
    # Status bar
    "statusbar-bg"
    "statusbar-fg"

    # Session
    "session-bg"
    "session-fg"
    "session-prefix-bg"
    "session-copy-bg"

    # Windows (base colors)
    "window-active-base"
    "window-inactive-base"

    # Pane borders
    "pane-border-active"
    "pane-border-inactive"

    # Health states (base colors)
    "ok-base"
    "good-base"
    "info-base"
    "warning-base"
    "error-base"
    "disabled-base"

    # Messages
    "message-bg"
    "message-fg"
)

# Optional colors that enhance the theme
declare -gra THEME_OPTIONAL_COLORS=(
    # Extended session modes
    "session-command-bg"
    "session-search-bg"

    # Extended health
    "neutral-base"

    # Selection
    "selection-bg"
    "selection-fg"

    # Search
    "search-match-bg"
    "search-match-fg"

    # Popup
    "popup-bg"
    "popup-fg"
    "popup-border"

    # Menu
    "menu-bg"
    "menu-fg"
    "menu-selected-bg"
    "menu-selected-fg"
    "menu-border"
)

# =============================================================================
# Color Format Validation
# =============================================================================

# Validate hex color format (#RRGGBB)
# Usage: _is_valid_hex_color "#ff5500"
# Returns: 0 if valid, 1 if invalid
_is_valid_hex_color() {
    local color="$1"

    # Allow special values
    [[ "$color" == "NONE" || "$color" == "default" ]] && return 0

    # Check hex format
    [[ "$color" =~ ^#[0-9a-fA-F]{6}$ ]]
}

# =============================================================================
# Single Theme Validation
# =============================================================================

# Validate a theme file
# Usage: validate_theme "/path/to/theme.sh"
# Returns: 0 if valid, 1 if invalid
validate_theme() {
    local theme_file="$1"
    local -a errors=()
    local -a warnings=()

    # Check file exists
    if [[ ! -f "$theme_file" ]]; then
        echo "ERROR: Theme file not found: $theme_file"
        return 1
    fi

    # Check syntax
    local syntax_errors
    if ! syntax_errors=$(bash -n "$theme_file" 2>&1); then
        echo "ERROR: Theme has syntax errors: $theme_file"
        echo "$syntax_errors"
        return 1
    fi

    # Source theme and check THEME_COLORS
    local missing_colors
    missing_colors=$(
        (
            # shellcheck disable=SC1090
            . "$theme_file" 2>/dev/null

            if ! declare -p THEME_COLORS &>/dev/null; then
                echo "_MISSING_ARRAY_"
            else
                for color in "${THEME_REQUIRED_COLORS[@]}"; do
                    if [[ -z "${THEME_COLORS[$color]:-}" ]]; then
                        echo "$color"
                    fi
                done
            fi
        )
    )

    if [[ "$missing_colors" == *"_MISSING_ARRAY_"* ]]; then
        errors+=("Theme does not define THEME_COLORS associative array")
    elif [[ -n "$missing_colors" ]]; then
        while IFS= read -r color; do
            [[ -n "$color" ]] && errors+=("Missing required color: $color")
        done <<< "$missing_colors"
    fi

    # Validate color formats
    local invalid_colors
    invalid_colors=$(
        (
            # shellcheck disable=SC1090
            . "$theme_file" 2>/dev/null

            if declare -p THEME_COLORS &>/dev/null; then
                for name in "${!THEME_COLORS[@]}"; do
                    local color="${THEME_COLORS[$name]}"
                    # Check hex format or special values
                    if [[ "$color" != "NONE" && "$color" != "default" && ! "$color" =~ ^#[0-9a-fA-F]{6}$ ]]; then
                        echo "$name: $color"
                    fi
                done
            fi
        )
    )

    if [[ -n "$invalid_colors" ]]; then
        while IFS= read -r entry; do
            [[ -n "$entry" ]] && errors+=("Invalid color format: $entry (expected #RRGGBB, NONE, or default)")
        done <<< "$invalid_colors"
    fi

    # Count defined colors for info
    local color_count
    color_count=$(
        (
            # shellcheck disable=SC1090
            . "$theme_file" 2>/dev/null
            declare -p THEME_COLORS &>/dev/null && echo "${#THEME_COLORS[@]}" || echo "0"
        )
    )

    # Output results
    local theme_name
    theme_name=$(basename "$theme_file" .sh)
    local theme_dir
    theme_dir=$(basename "$(dirname "$theme_file")")

    if [[ ${#errors[@]} -eq 0 ]]; then
        echo "Theme '$theme_dir/$theme_name': VALID ($color_count colors defined)"

        if [[ ${#warnings[@]} -gt 0 ]]; then
            for warn in "${warnings[@]}"; do
                echo "  WARNING: $warn"
            done
        fi

        return 0
    else
        echo "Theme '$theme_dir/$theme_name': INVALID"

        for err in "${errors[@]}"; do
            echo "  ERROR: $err"
        done

        for warn in "${warnings[@]}"; do
            echo "  WARNING: $warn"
        done

        return 1
    fi
}

# =============================================================================
# Batch Validation
# =============================================================================

# Validate all themes in a directory
# Usage: validate_all_themes "/path/to/themes"
validate_all_themes() {
    local themes_dir="$1"
    local total=0
    local valid=0
    local invalid=0

    echo "Validating themes in: $themes_dir"
    echo "---"

    local theme_dir theme_file
    for theme_dir in "$themes_dir"/*/; do
        [[ -d "$theme_dir" ]] || continue

        for theme_file in "$theme_dir"*.sh; do
            [[ -f "$theme_file" ]] || continue
            ((total++))

            if validate_theme "$theme_file"; then
                ((valid++))
            else
                ((invalid++))
            fi
            echo ""
        done
    done

    echo "---"
    echo "Total: $total, Valid: $valid, Invalid: $invalid"

    [[ $invalid -eq 0 ]]
}

# =============================================================================
# Utility Functions
# =============================================================================

# Get list of required theme colors
list_required_theme_colors() {
    printf '%s\n' "${THEME_REQUIRED_COLORS[@]}"
}

# Get list of optional theme colors
list_optional_theme_colors() {
    printf '%s\n' "${THEME_OPTIONAL_COLORS[@]}"
}

# Check if a color is required
is_required_theme_color() {
    local color="$1"
    local required
    for required in "${THEME_REQUIRED_COLORS[@]}"; do
        [[ "$color" == "$required" ]] && return 0
    done
    return 1
}

# Check if a color is optional
is_optional_theme_color() {
    local color="$1"
    local optional
    for optional in "${THEME_OPTIONAL_COLORS[@]}"; do
        [[ "$color" == "$optional" ]] && return 0
    done
    return 1
}
