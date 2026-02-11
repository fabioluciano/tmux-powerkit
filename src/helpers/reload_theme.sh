#!/usr/bin/env bash
# Helper script to reload theme after selection

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Delete all theme caches (files)
rm -f ~/.cache/tmux-powerkit/data/theme_colors__* 2>/dev/null || true
rm -f ~/.cache/tmux-powerkit/data/current_theme 2>/dev/null || true

# Bootstrap minimal to get functions
. "${POWERKIT_ROOT}/src/core/bootstrap.sh"
powerkit_bootstrap_minimal

# CRITICAL: Clear in-memory global variables that cause fast-path to skip reload
unset _CURRENT_THEME
unset _CURRENT_VARIANT
THEME_COLORS=()
_COLOR_VARIANTS=()

# NOW do full bootstrap (will load theme fresh from file)
powerkit_bootstrap

# Render everything
. "${POWERKIT_ROOT}/src/renderer/renderer.sh"
render_all

# Force tmux to refresh
tmux refresh-client -S
