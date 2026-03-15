#!/usr/bin/env bash
# =============================================================================
# Helper: appearance_toggle
# Description: Cycles macOS appearance mode: auto → dark → light → auto
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/utils/platform.sh"

macos_cycle_appearance

# Switch @powerkit_theme / @powerkit_theme_variant to match the new appearance.
# Must run before the re-bootstrap so load_powerkit_theme() picks up the change.
dark_val=$(tmux show-option -gqv @dark_appearance 2>/dev/null)
dark_opt=$(tmux show-option -gqv @powerkit_plugin_appearance_dark_theme  2>/dev/null)
light_opt=$(tmux show-option -gqv @powerkit_plugin_appearance_light_theme 2>/dev/null)

if [[ -n "$dark_opt" && -n "$light_opt" ]]; then
  [[ "$dark_val" == "1" ]] && pair="$dark_opt" || pair="$light_opt"
  tmux set-option -gq @powerkit_theme         "${pair%/*}" 2>/dev/null || true
  tmux set-option -gq @powerkit_theme_variant "${pair#*/}" 2>/dev/null || true
else
  current_theme=$(tmux show-option -gqv @powerkit_theme 2>/dev/null)
  themes_dir="${POWERKIT_ROOT}/src/themes"
  if [[ -n "$current_theme" && \
        -f "${themes_dir}/${current_theme}/dark.sh" && \
        -f "${themes_dir}/${current_theme}/light.sh" ]]; then
    [[ "$dark_val" == "1" ]] && variant="dark" || variant="light"
    tmux set-option -gq @powerkit_theme_variant "$variant" 2>/dev/null || true
  fi
fi

cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/tmux-powerkit/data"
rm -f "${cache_dir}"/rendered_right__* 2>/dev/null || true
bash "${POWERKIT_ROOT}/tmux-powerkit.tmux" 2>/dev/null || true
