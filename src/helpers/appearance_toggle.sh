#!/usr/bin/env bash
# =============================================================================
# Helper: appearance_toggle
# Description: Cycles macOS appearance mode: auto → dark → light → auto
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/utils/platform.sh"

# Apply @powerkit_theme/@powerkit_theme_variant to match dark_val ("1"|"0").
# Priority:
#   1. Explicit @powerkit_plugin_appearance_{dark,light}_theme tmux options
#   2. Auto-detect: current theme has both dark.sh and light.sh variants
#   3. No-op
_apply_theme() {
  local dark_val="$1"
  local dark_opt light_opt pair current_theme variant

  dark_opt=$(tmux show-option -gqv @powerkit_plugin_appearance_dark_theme  2>/dev/null)
  light_opt=$(tmux show-option -gqv @powerkit_plugin_appearance_light_theme 2>/dev/null)

  if [[ -n "$dark_opt" && -n "$light_opt" ]]; then
    [[ "$dark_val" == "1" ]] && pair="$dark_opt" || pair="$light_opt"
    tmux set-option -gq @powerkit_theme         "${pair%/*}" 2>/dev/null || true
    tmux set-option -gq @powerkit_theme_variant "${pair#*/}" 2>/dev/null || true
  else
    current_theme=$(tmux show-option -gqv @powerkit_theme 2>/dev/null)
    if [[ -n "$current_theme" && \
          -f "${POWERKIT_ROOT}/src/themes/${current_theme}/dark.sh" && \
          -f "${POWERKIT_ROOT}/src/themes/${current_theme}/light.sh" ]]; then
      [[ "$dark_val" == "1" ]] && variant="dark" || variant="light"
      tmux set-option -gq @powerkit_theme_variant "$variant" 2>/dev/null || true
    fi
  fi
}

macos_cycle_appearance
_apply_theme "$(tmux show-option -gqv @dark_appearance 2>/dev/null)"
cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/tmux-powerkit/data"
rm -f "${cache_dir}"/rendered_right__* 2>/dev/null || true
bash "${POWERKIT_ROOT}/tmux-powerkit.tmux" 2>/dev/null || true
