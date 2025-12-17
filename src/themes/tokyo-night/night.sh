#!/usr/bin/env bash

# Tokyo Night Theme - PowerKit Semantic Color Mapping
# This file maps Tokyo Night colors to universal PowerKit semantic names
# that can be used across different themes consistently.

# Populate the global THEME_COLORS array for PowerKit compatibility
declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"
  
  # Background Colors
  [background]="#1a1b26"           # Main background
  [background-alt]="#16161e"       # Alternative/darker background
  [surface]="#292e42"              # Surface/card background
  [overlay]="#3b4261"              # Overlay/modal background
  
  # Text Colors  
  [text]="#ffffff"                 # Primary text
  [text-muted]="#565f89"           # Muted/comment text
  [text-disabled]="#414868"        # Disabled text
  
  # Border Colors
  [border]="#3b4261"               # Default border
  [border-subtle]="#545c7e"        # Subtle border
  [border-strong]="#737aa2"        # Strong border
  
  # Semantic Colors (PowerKit Standard)
  [accent]="#bb9af7"               # Main accent color (magenta)
  [primary]="#9d7cd8"              # Primary brand color (blue)
  [secondary]="#394b70"            # Secondary color (blue-gray)
  [secondary-strong]="#222d47"     # Strong secondary (40% darker)
  
  # Status Colors (PowerKit Standard)
  [success]="#9ece6a"              # Success state (green)
  [warning]="#e0af68"              # Warning state (yellow)
  [error]="#f7768e"                # Error state (red)
  [info]="#7dcfff"                 # Informational state (cyan)
  
  # Interactive States
  [hover]="#292e42"                # Hover state
  [active]="#46608a"               # Active state (10% mais clara que secondary)
  [focus]="#7aa2f7"                # Focus state
  [disabled]="#565f89"             # Disabled state
  
  # Additional Variants
  [success-subtle]="#abd88c"       # Subtle success (5% darker que o tom claro anterior)
  [success-strong]="#6b9c3a"       # Strong success (40% darker)
  [warning-strong]="#a6833e"       # Strong warning (40% darker)
  [error-strong]="#c44a55"         # Strong error (40% darker)
  [info-subtle]="#99d6e6"          # Subtle info (5% mais escuro que o tom claro anterior)
  [info-strong]="#3990b3"          # Strong info (darker cyan)
  [error-subtle]="#f18fa0"          # Subtle error (5% mais clara)
  [warning-subtle]="#eac07a"        # Subtle warning (um pouco mais clara que warning)
  
  # System Colors
  [white]="#ffffff"                # Pure white
  [black]="#000000"                # Pure black
)

# Export for PowerKit compatibility
export THEME_COLORS