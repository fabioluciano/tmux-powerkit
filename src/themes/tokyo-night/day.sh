#!/usr/bin/env bash

# Tokyo Night Day Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/folke/tokyonight.nvim
# Day variant - Light theme with vibrant Tokyo Night colors

# Populate the global THEME_COLORS array for PowerKit compatibility
declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"

  # Background Colors (Light theme)
  [background]="#e1e2e7"           # Main background
  [background-alt]="#d5d6db"       # Alternative background (slightly darker)
  [surface]="#c4c8da"              # Surface/status bar background
  [overlay]="#b7c1e3"              # Overlay/selection background

  # Text Colors (Dark for light theme)
  [text]="#3760bf"                 # Primary text (blue - official day fg)
  [text-muted]="#6172b0"           # Muted text (color7)
  [text-disabled]="#a1a6c5"        # Disabled text (color8)

  # Border Colors
  [border]="#b7c1e3"               # Default border (inactive window content bg)
  [border-subtle]="#a1a6c5"        # Subtle border (inactive window index - visible on surface)
  [border-strong]="#6172b0"        # Strong border

  # Semantic Colors (PowerKit Standard) - Using vibrant day colors
  [accent]="#9854f1"               # Main accent (magenta/purple - color5)
  [primary]="#2e7de9"              # Primary brand (blue - color4)
  [secondary]="#6172b0"            # Secondary (muted blue for text contrast)
  [secondary-strong]="#3760bf"     # Strong secondary (fg color)

  # Status Colors (PowerKit Standard) - Vibrant official colors
  [success]="#587539"              # Success (green - color2)
  [warning]="#8c6c3e"              # Warning (yellow/brown - color3)
  [error]="#f52a65"                # Error (red - color1)
  [info]="#007197"                 # Info (cyan - color6)

  # Interactive States
  [hover]="#d5d6db"                # Hover state
  [active]="#8690b8"               # Active state (icon bg - mid contrast)
  [focus]="#2e7de9"                # Focus state (blue)
  [disabled]="#a1a6c5"             # Disabled state

  # Additional Variants - Brighter versions for visibility
  [success-subtle]="#5c8524"       # Subtle success (bright green - color10)
  [success-strong]="#3d5127"       # Strong success (darker)
  [warning-strong]="#6e5330"       # Strong warning (darker)
  [error-strong]="#c42152"         # Strong error (darker)
  [info-subtle]="#007ea8"          # Subtle info (bright cyan - color14)
  [info-strong]="#00566b"          # Strong info (darker)
  [error-subtle]="#ff4774"         # Subtle error (bright red - color9)
  [warning-subtle]="#a27629"       # Subtle warning (bright yellow - color11)

  # System Colors
  [white]="#e1e2e7"                # Background (lightest)
  [black]="#3760bf"                # Text (darkest)
)

# Export for PowerKit compatibility
export THEME_COLORS
