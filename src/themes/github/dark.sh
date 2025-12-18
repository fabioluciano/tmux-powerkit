#!/usr/bin/env bash

# GitHub Dark Theme - PowerKit Semantic Color Mapping
# Based on GitHub's Primer design system
# Dark Default variant

declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"

  # Background Colors
  [background]="#0d1117"           # canvas.default - main background
  [background-alt]="#010409"       # canvas.inset - darker background
  [surface]="#161b22"              # canvas.subtle - surface/status bar
  [overlay]="#21262d"              # canvas.overlay - overlay/modal

  # Text Colors
  [text]="#e6edf3"                 # fg.default - primary text
  [text-muted]="#8b949e"           # fg.muted - muted text
  [text-disabled]="#6e7681"        # fg.subtle - disabled text

  # Border Colors
  [border]="#30363d"               # border.default
  [border-subtle]="#21262d"        # border.subtle
  [border-strong]="#8b949e"        # border.muted

  # Semantic Colors (PowerKit Standard)
  [accent]="#a371f7"               # purple - main accent
  [primary]="#58a6ff"              # blue - primary
  [secondary]="#30363d"            # secondary
  [secondary-strong]="#21262d"     # strong secondary

  # Status Colors (GitHub's semantic colors)
  [success]="#3fb950"              # success.fg
  [warning]="#d29922"              # attention.fg
  [error]="#f85149"                # danger.fg
  [info]="#58a6ff"                 # accent.fg

  # Interactive States
  [hover]="#161b22"                # canvas.subtle
  [active]="#484f58"               # active (lighter than secondary)
  [focus]="#58a6ff"                # accent
  [disabled]="#6e7681"             # fg.subtle

  # Additional Variants
  [success-subtle]="#56d364"       # success.emphasis
  [success-strong]="#238636"       # success.muted
  [warning-strong]="#9e6a03"       # attention.muted
  [error-strong]="#b62324"         # danger.muted
  [info-subtle]="#79c0ff"          # accent.emphasis
  [info-strong]="#1f6feb"          # accent.muted
  [error-subtle]="#ff7b72"         # danger.emphasis
  [warning-subtle]="#e3b341"       # attention.emphasis

  # System Colors
  [white]="#e6edf3"                # fg.default
  [black]="#010409"                # canvas.inset
)

export THEME_COLORS
