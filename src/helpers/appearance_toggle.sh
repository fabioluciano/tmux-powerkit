#!/usr/bin/env bash
# =============================================================================
# Helper: appearance_toggle
# Description: Cycles macOS appearance mode: auto → dark → light → auto
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/utils/platform.sh"
. "${POWERKIT_ROOT}/src/core/cache.sh"

# Apply @powerkit_theme/@powerkit_theme_variant to match dark_val ("1"|"0").
# Priority:
#   1. Explicit @powerkit_plugin_appearance_{dark,light}_theme tmux options
#   2. Auto-detect: current theme has both dark.sh and light.sh variants
#   3. No-op
#
# Note: this duplicates _appearance_switch_theme() from appearance.sh intentionally.
# This helper sources only platform.sh + cache.sh (no bootstrap) to stay lean for
# keybinding/mouse invocations. Pulling in plugin_contract.sh would load the full
# framework and defeat that purpose.
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
cache_clear_prefix "rendered_right__"
bash "${POWERKIT_ROOT}/tmux-powerkit.tmux" 2>/dev/null || true
