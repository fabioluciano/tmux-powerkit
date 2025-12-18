#!/usr/bin/env bash

# Kanagawa Dragon Theme - PowerKit Semantic Color Mapping
# Based on https://github.com/rebelot/kanagawa.nvim
# Dragon variant - Darker, more muted variant

declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"

  # Background Colors (Dragon is darker/inkier)
  [background]="#181616"           # dragonBlack3 - main background
  [background-alt]="#0d0c0c"       # dragonBlack0 - darker background
  [surface]="#282727"              # dragonBlack4 - surface/status bar
  [overlay]="#393836"              # dragonBlack5 - overlay/modal

  # Text Colors
  [text]="#c5c9c5"                 # dragonWhite - primary text
  [text-muted]="#a6a69c"           # dragonGray2 - muted text
  [text-disabled]="#625e5a"        # dragonGray - disabled text

  # Border Colors
  [border]="#393836"               # dragonBlack5
  [border-subtle]="#625e5a"        # dragonGray
  [border-strong]="#a6a69c"        # dragonGray2

  # Semantic Colors (PowerKit Standard)
  [accent]="#8992a7"               # dragonViolet - main accent
  [primary]="#8ba4b0"              # dragonBlue2 - primary
  [secondary]="#223249"            # waveBlue1 - secondary
  [secondary-strong]="#2D4F67"     # waveBlue2 - strong secondary

  # Status Colors
  [success]="#87a987"              # dragonGreen2
  [warning]="#c4b28a"              # dragonYellow
  [error]="#c4746e"                # dragonRed
  [info]="#8ba4b0"                 # dragonBlue2

  # Interactive States
  [hover]="#282727"                # dragonBlack4
  [active]="#2D4F67"               # waveBlue2 - active
  [focus]="#8ba4b0"                # dragonBlue2
  [disabled]="#625e5a"             # dragonGray

  # Additional Variants
  [success-subtle]="#8a9a7b"       # dragonGreen
  [success-strong]="#2B3328"       # winterGreen
  [warning-strong]="#49443C"       # winterYellow
  [error-strong]="#43242B"         # winterRed
  [info-subtle]="#a6a69c"          # dragonGray2
  [info-strong]="#252535"          # winterBlue
  [error-subtle]="#b6927b"         # dragonOrange2
  [warning-subtle]="#e6c384"       # carpYellow

  # System Colors
  [white]="#c5c9c5"                # dragonWhite
  [black]="#0d0c0c"                # dragonBlack0
)

export THEME_COLORS
