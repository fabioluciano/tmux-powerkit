#!/usr/bin/env bash

# GitHub Light Theme - PowerKit Semantic Color Mapping
# Based on GitHub's Primer design system
# Light Default variant

declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"

  # Background Colors (Light theme)
  [background]="#ffffff"           # canvas.default - main background
  [background-alt]="#f6f8fa"       # canvas.subtle - alternative background
  [surface]="#eaeef2"              # canvas.inset - surface/status bar
  [overlay]="#d0d7de"              # border.default - overlay/modal

  # Text Colors (Dark for light theme)
  [text]="#24292f"                 # fg.default - primary text
  [text-muted]="#57606a"           # fg.muted - muted text
  [text-disabled]="#8c959f"        # fg.subtle - disabled text

  # Border Colors
  [border]="#d0d7de"               # border.default
  [border-subtle]="#afb8c1"        # border.muted - visible on surface
  [border-strong]="#57606a"        # fg.muted

  # Semantic Colors (PowerKit Standard)
  [accent]="#8250df"               # purple - main accent
  [primary]="#0969da"              # blue - primary
  [secondary]="#57606a"            # fg.muted - secondary (dark for white text)
  [secondary-strong]="#24292f"     # fg.default - strong secondary

  # Status Colors (GitHub's semantic colors - vibrant for light)
  [success]="#1a7f37"              # success.fg
  [warning]="#9a6700"              # attention.fg
  [error]="#cf222e"                # danger.fg
  [info]="#0969da"                 # accent.fg

  # Interactive States
  [hover]="#f6f8fa"                # canvas.subtle
  [active]="#8c959f"               # active (lighter for icon bg)
  [focus]="#0969da"                # accent
  [disabled]="#8c959f"             # fg.subtle

  # Additional Variants
  [success-subtle]="#2da44e"       # success.emphasis
  [success-strong]="#116329"       # success.muted
  [warning-strong]="#6d4d00"       # attention.muted
  [error-strong]="#a40e26"         # danger.muted
  [info-subtle]="#218bff"          # accent.emphasis
  [info-strong]="#0550ae"          # accent.muted
  [error-subtle]="#ff8182"         # danger.emphasis
  [warning-subtle]="#bf8700"       # attention.emphasis

  # System Colors
  [white]="#ffffff"                # canvas.default
  [black]="#24292f"                # fg.default
)

export THEME_COLORS
