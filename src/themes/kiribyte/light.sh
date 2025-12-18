#!/usr/bin/env bash

# Kiribyte Light Theme - PowerKit Semantic Color Mapping
# Light variant of Kiribyte pastel theme
# Soft, paper-like background with pastel accents

declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"

  # Background Colors (Light theme - inverted from dark)
  [background]="#f5f4f0"           # Warm off-white - main background
  [background-alt]="#ebeae5"       # Slightly darker alternative
  [surface]="#e0dfd9"              # Surface/status bar
  [overlay]="#d4d3cc"              # Overlay/modal

  # Text Colors (Dark for light theme)
  [text]="#3b3d4a"                 # Dark gray-blue - primary text
  [text-muted]="#6d7187"           # Muted text (from dark theme)
  [text-disabled]="#8a8fb5"        # Disabled text (from dark theme)

  # Border Colors
  [border]="#d4d3cc"               # Default border
  [border-subtle]="#b8b7b0"        # Subtle border - visible on surface
  [border-strong]="#6d7187"        # Strong border

  # Semantic Colors (PowerKit Standard) - Pastel adapted for light
  [accent]="#9b7fc9"               # Darker lavender pastel - main accent
  [primary]="#7e6db8"              # Darker purple pastel - primary
  [secondary]="#6d7187"            # Blue-gray - secondary (dark for white text)
  [secondary-strong]="#3b3d4a"     # Strong secondary

  # Status Colors (Darker pastels for light theme visibility)
  [success]="#6a8c4f"              # Darker mint green
  [warning]="#9a7d4d"              # Darker warm gold
  [error]="#c94d66"                # Darker rose
  [info]="#4a8fa8"                 # Darker baby blue

  # Interactive States
  [hover]="#ebeae5"                # background-alt
  [active]="#9a9cb0"               # Active state (lighter for icon bg)
  [focus]="#6a9dc9"                # Darker sky blue
  [disabled]="#8a8fb5"             # Disabled state

  # Additional Variants (Darker for light theme)
  [success-subtle]="#80a865"       # Lighter success
  [success-strong]="#4d6638"       # Darker success
  [warning-strong]="#6e5a38"       # Darker warning
  [error-strong]="#9e3a4e"         # Darker error
  [info-subtle]="#62a8c2"          # Lighter info
  [info-strong]="#356578"          # Darker info
  [error-subtle]="#d97088"         # Lighter error
  [warning-subtle]="#b89a65"       # Lighter warning

  # System Colors
  [white]="#f5f4f0"                # Background
  [black]="#3b3d4a"                # Text
)

export THEME_COLORS
