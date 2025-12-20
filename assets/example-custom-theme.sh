#!/usr/bin/env bash
# =============================================================================
# Example Custom Theme for PowerKit
# =============================================================================
#
# This is an example custom theme showing all required semantic colors.
# Copy this file and modify colors to create your own theme.
#
# Usage:
#   1. Copy this file to your desired location
#   2. Modify the colors below
#   3. In your ~/.tmux.conf, add:
#      set -g @powerkit_theme "custom"
#      set -g @powerkit_custom_theme_path "/path/to/your-theme.sh"
#   4. Reload tmux: tmux source ~/.tmux.conf
#
# =============================================================================

declare -A THEME_COLORS=(
    # =============================================================================
    # Core System Colors (Required)
    # =============================================================================
    [transparent]="NONE"
    [none]="NONE"

    # =============================================================================
    # Background Colors (Required)
    # =============================================================================
    [background]="#1e1e2e"       # Main background color
    [background-alt]="#181825"   # Alternative/darker background
    [surface]="#313244"          # Surface/card background
    [overlay]="#3e3f4a"          # Overlay/modal background

    # =============================================================================
    # Text Colors (Required)
    # =============================================================================
    [text]="#cdd6f4"             # Primary text color
    [text-muted]="#6c7086"       # Muted/comment text
    [text-disabled]="#585b70"    # Disabled text

    # =============================================================================
    # Border Colors (Required)
    # =============================================================================
    [border]="#585b70"           # Default border color
    [border-subtle]="#45475a"    # Subtle border
    [border-strong]="#7f849c"    # Strong border

    # =============================================================================
    # Semantic Colors (Required)
    # =============================================================================
    [primary]="#89b4fa"          # Primary accent (blue)
    [secondary]="#45475a"        # Secondary/muted background
    [secondary-strong]="#313244" # Strong secondary
    [accent]="#cba6f7"           # Main accent color (purple)

    # =============================================================================
    # Status Colors (Required)
    # =============================================================================
    [success]="#a6e3a1"          # Success state (green)
    [warning]="#f9e2af"          # Warning state (yellow)
    [error]="#f38ba8"            # Error state (red)
    [info]="#89dceb"             # Information state (cyan)

    # =============================================================================
    # Interactive Colors (Required)
    # =============================================================================
    [active]="#6c7086"           # Active/selected elements
    [disabled]="#313244"         # Disabled elements
    [hover]="#7f849c"            # Hover state
    [focus]="#89b4fa"            # Focus state

    # =============================================================================
    # Subtle Variants (Required)
    # =============================================================================
    [primary-subtle]="#313244"
    [success-subtle]="#b9e9af"
    [warning-subtle]="#fbedc0"
    [error-subtle]="#f6a4b3"
    [info-subtle]="#a5e5f5"
    [accent-subtle]="#dfc0f5"

    # =============================================================================
    # Strong Variants (Required)
    # =============================================================================
    [primary-strong]="#b4befe"
    [success-strong]="#5e8f57"
    [warning-strong]="#b08654"
    [error-strong]="#a84f63"
    [info-strong]="#4b9dba"
    [accent-strong]="#9366ba"

    # =============================================================================
    # Additional Colors (Optional but recommended)
    # =============================================================================
    [white]="#ffffff"            # Pure white (for high contrast text)
    [black]="#000000"            # Pure black
    [muted]="#6c7086"            # Muted/secondary text
)

# Export the theme colors (Required!)
export THEME_COLORS
