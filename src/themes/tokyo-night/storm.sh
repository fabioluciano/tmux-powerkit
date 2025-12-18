#!/usr/bin/env bash

# Tokyo Night Storm Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/folke/tokyonight.nvim
# Storm variant - Slightly lighter background than Night

# Populate the global THEME_COLORS array for PowerKit compatibility
declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"

  # Background Colors (Storm is slightly lighter than Night)
  [background]="#24283b"           # Main background (storm bg)
  [background-alt]="#1f2335"       # Alternative/darker background
  [surface]="#292e42"              # Surface/card background (bg_highlight)
  [overlay]="#3b4261"              # Overlay/modal background

  # Text Colors
  [text]="#c0caf5"                 # Primary text
  [text-muted]="#565f89"           # Muted/comment text
  [text-disabled]="#414868"        # Disabled text

  # Border Colors
  [border]="#3b4261"               # Default border
  [border-subtle]="#545c7e"        # Subtle border
  [border-strong]="#737aa2"        # Strong border

  # Semantic Colors (PowerKit Standard)
  [accent]="#bb9af7"               # Main accent color (magenta)
  [primary]="#9d7cd8"              # Primary brand color (purple)
  [secondary]="#394b70"            # Secondary color (blue-gray)
  [secondary-strong]="#222d47"     # Strong secondary (40% darker)

  # Status Colors (PowerKit Standard)
  [success]="#9ece6a"              # Success state (green)
  [warning]="#e0af68"              # Warning state (yellow)
  [error]="#f7768e"                # Error state (red)
  [info]="#7dcfff"                 # Informational state (cyan)

  # Interactive States
  [hover]="#292e42"                # Hover state
  [active]="#46608a"               # Active state (lighter than secondary)
  [focus]="#7aa2f7"                # Focus state (blue)
  [disabled]="#565f89"             # Disabled state

  # Additional Variants
  [success-subtle]="#abd88c"       # Subtle success
  [success-strong]="#5a8431"       # Strong success
  [warning-strong]="#786344"       # Strong warning
  [error-strong]="#89414f"         # Strong error
  [info-subtle]="#95d8ff"          # Subtle info
  [info-strong]="#45738e"          # Strong info
  [error-subtle]="#f88fa3"         # Subtle error
  [warning-subtle]="#e0c193"       # Subtle warning

  # System Colors
  [white]="#c0caf5"                # Light text
  [black]="#1f2335"                # Darkest background
)

# Export for PowerKit compatibility
export THEME_COLORS
