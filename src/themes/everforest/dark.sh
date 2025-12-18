#!/usr/bin/env bash

# Everforest Dark Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/sainnhe/everforest
# Dark variant - Comfortable green-based theme

declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"

  # Background Colors
  [background]="#2d353b"           # bg0 - main background
  [background-alt]="#232a2e"       # bg_dim - darker background
  [surface]="#343f44"              # bg1 - surface/status bar
  [overlay]="#3d484d"              # bg2 - overlay/modal

  # Text Colors
  [text]="#d3c6aa"                 # fg - primary text
  [text-muted]="#859289"           # grey1 - muted text
  [text-disabled]="#7a8478"        # grey0 - disabled text

  # Border Colors
  [border]="#3d484d"               # bg2
  [border-subtle]="#475258"        # bg3
  [border-strong]="#859289"        # grey1

  # Semantic Colors (PowerKit Standard)
  [accent]="#d699b6"               # purple - main accent
  [primary]="#7fbbb3"              # blue/aqua - primary
  [secondary]="#475258"            # bg3 - secondary
  [secondary-strong]="#3d484d"     # bg2 - strong secondary

  # Status Colors
  [success]="#a7c080"              # green
  [warning]="#dbbc7f"              # yellow
  [error]="#e67e80"                # red
  [info]="#83c092"                 # aqua

  # Interactive States
  [hover]="#343f44"                # bg1
  [active]="#4f585e"               # bg4 - active (lighter than secondary)
  [focus]="#7fbbb3"                # blue
  [disabled]="#7a8478"             # grey0

  # Additional Variants
  [success-subtle]="#b5cfa0"       # lighter green
  [success-strong]="#6e8b59"       # darker green
  [warning-strong]="#9a8555"       # darker yellow
  [error-strong]="#a35a5c"         # darker red
  [info-subtle]="#9dd0a8"          # lighter aqua
  [info-strong]="#5a8a7d"          # darker aqua
  [error-subtle]="#eba0a2"         # lighter red
  [warning-subtle]="#e6d0a0"       # lighter yellow

  # System Colors
  [white]="#d3c6aa"                # fg
  [black]="#232a2e"                # bg_dim
)

export THEME_COLORS
