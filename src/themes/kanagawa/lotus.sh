#!/usr/bin/env bash

# Kanagawa Lotus Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/rebelot/kanagawa.nvim
# Lotus variant - Light theme

declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"

  # Background Colors (Light theme)
  [background]="#f2ecbc"           # lotusWhite0 - main background
  [background-alt]="#e7dba0"       # lotusWhite1 - alternative background
  [surface]="#e4d794"              # lotusWhite2 - surface/status bar
  [overlay]="#d5cea3"              # lotusWhite3 - overlay/modal

  # Text Colors (Dark for light theme)
  [text]="#545464"                 # lotusInk1 - primary text
  [text-muted]="#716e61"           # lotusGray - muted text
  [text-disabled]="#8a8980"        # lotusGray2 - disabled text

  # Border Colors
  [border]="#c9cbd1"               # lotusWhite4
  [border-subtle]="#9e9b93"        # lotusGray3 - visible on surface
  [border-strong]="#716e61"        # lotusGray

  # Semantic Colors (PowerKit Standard)
  [accent]="#b35b79"               # lotusPink - main accent
  [primary]="#4d699b"              # lotusBlue - primary
  [secondary]="#716e61"            # lotusGray - secondary (dark for white text)
  [secondary-strong]="#545464"     # lotusInk1 - strong secondary

  # Status Colors
  [success]="#6f894e"              # lotusGreen
  [warning]="#77713f"              # lotusYellow (olive)
  [error]="#c84053"                # lotusRed
  [info]="#4e8ca2"                 # lotusTeal

  # Interactive States
  [hover]="#e7dba0"                # lotusWhite1
  [active]="#8a8980"               # lotusGray2 - active (lighter for icon bg)
  [focus]="#4d699b"                # lotusBlue
  [disabled]="#8a8980"             # lotusGray2

  # Additional Variants
  [success-subtle]="#6e915f"       # lotusGreen2
  [success-strong]="#4a5e36"       # darker green
  [warning-strong]="#4f4a2b"       # darker yellow
  [error-strong]="#a3354a"         # darker red
  [info-subtle]="#597b8d"          # lotusAqua2
  [info-strong]="#3a6174"          # darker teal
  [error-subtle]="#d9a594"         # lotusOrange2
  [warning-subtle]="#de9a00"       # lotusOrange (brighter)

  # System Colors
  [white]="#f2ecbc"                # lotusWhite0
  [black]="#545464"                # lotusInk1
)

export THEME_COLORS
