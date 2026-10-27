#!/usr/bin/env bash
# Helper script to reload theme after selection

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Bootstrap minimal to get functions
. "${POWERKIT_ROOT}/src/core/bootstrap.sh"
powerkit_bootstrap_minimal

# Delete all theme caches (files)
_cache_dir="$(get_cache_dir)"
rm -f "${_cache_dir}/theme_colors__"* 2>/dev/null || true
rm -f "${_cache_dir}/current_theme" 2>/dev/null || true

# CRITICAL: Clear in-memory global variables that cause fast-path to skip reload
unset _CURRENT_THEME
unset _CURRENT_VARIANT
# shellcheck disable=SC2034  # Variables used by bootstrap/theme system
declare -gA THEME_COLORS=()
# shellcheck disable=SC2034
declare -gA _COLOR_VARIANTS=()

# NOW do full bootstrap (will load theme fresh from file)
powerkit_bootstrap

# Render everything
. "${POWERKIT_ROOT}/src/renderer/renderer.sh"
render_all

# Force tmux to refresh
tmux refresh-client -S
