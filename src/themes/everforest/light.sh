#!/usr/bin/env bash

# Everforest Light Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/sainnhe/everforest
# Light variant - Soft, paper-like light theme

declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"

  # Background Colors (Light theme)
  [background]="#fdf6e3"           # bg0 - main background
  [background-alt]="#f4f0d9"       # bg1 - alternative background
  [surface]="#efebd4"              # bg2 - surface/status bar
  [overlay]="#e6e2cc"              # bg3 - overlay/modal

  # Text Colors (Dark for light theme)
  [text]="#5c6a72"                 # fg - primary text
  [text-muted]="#829181"           # grey2 - muted text
  [text-disabled]="#939f91"        # grey1 - disabled text

  # Border Colors
  [border]="#e6e2cc"               # bg3
  [border-subtle]="#bdc3af"        # bg5 - visible on surface
  [border-strong]="#829181"        # grey2

  # Semantic Colors (PowerKit Standard)
  [accent]="#df69ba"               # purple - main accent
  [primary]="#3a94c5"              # blue - primary
  [secondary]="#829181"            # grey2 - secondary (dark for white text)
  [secondary-strong]="#5c6a72"     # fg - strong secondary

  # Status Colors (Vibrant for light theme)
  [success]="#8da101"              # green
  [warning]="#dfa000"              # yellow
  [error]="#f85552"                # red
  [info]="#35a77c"                 # aqua

  # Interactive States
  [hover]="#f4f0d9"                # bg1
  [active]="#a6b0a0"               # grey0 - active (lighter for icon bg)
  [focus]="#3a94c5"                # blue
  [disabled]="#939f91"             # grey1

  # Additional Variants
  [success-subtle]="#a4b800"       # brighter green
  [success-strong]="#5f6d01"       # darker green
  [warning-strong]="#9a7000"       # darker yellow
  [error-strong]="#c43b3d"         # darker red
  [info-subtle]="#4bbf92"          # brighter aqua
  [info-strong]="#267a59"          # darker aqua
  [error-subtle]="#fa7775"         # lighter red
  [warning-subtle]="#f0b826"       # lighter yellow

  # System Colors
  [white]="#fdf6e3"                # bg0
  [black]="#5c6a72"                # fg
)

export THEME_COLORS
