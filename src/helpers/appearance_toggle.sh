#!/usr/bin/env bash
# =============================================================================
# Helper: appearance_toggle
# Description: Manages macOS appearance for tmux-powerkit
#
# Usage:
#   appearance_toggle.sh [toggle]   - Cycle appearance: auto → dark → light → auto
#   appearance_toggle.sh watch      - Called by launchd on GlobalPreferences change
#   appearance_toggle.sh install    - Install launchd WatchPaths agent
#   appearance_toggle.sh uninstall  - Remove launchd agent
#
# Instant OS-driven switching (launchd):
#   The launchd agent watches ~/Library/Preferences/.GlobalPreferences.plist
#   and calls this script with the 'watch' argument when it changes. This
#   eliminates polling lag — the status bar updates as fast as Ghostty and
#   macOS itself.
#
#   Enable via tmux.conf (auto-installed on next tmux reload):
#     set -g @powerkit_plugin_appearance_watch_plist "true"
#
#   Or install/remove manually:
#     bash appearance_toggle.sh install
#     bash appearance_toggle.sh uninstall
#
#   Note: macOS Ventura (13)+ shows a "Background Item Added" notification
#   when the agent is installed. This is informational — it does not block
#   installation or require approval.
#
#   The agent is automatically removed if watch_plist is set back to "false"
#   and tmux is reloaded.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/utils/platform.sh"

_PLIST_LABEL="com.tmux-powerkit.appearance"
_PLIST_PATH="${HOME}/Library/LaunchAgents/${_PLIST_LABEL}.plist"

# -----------------------------------------------------------------------------
# Internal: apply @powerkit_theme/@powerkit_theme_variant to match dark_val.
# Priority:
#   1. Explicit @powerkit_plugin_appearance_{dark,light}_theme tmux options
#   2. Auto-detect: current theme has both dark.sh and light.sh variants
#   3. No-op
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# toggle: cycle auto → dark → light → auto, apply theme, full re-bootstrap
# -----------------------------------------------------------------------------
_cmd_toggle() {
  macos_cycle_appearance
  _apply_theme "$(tmux show-option -gqv @dark_appearance 2>/dev/null)"
  local cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/tmux-powerkit/data"
  rm -f "${cache_dir}"/rendered_right__* 2>/dev/null || true
  bash "${POWERKIT_ROOT}/tmux-powerkit.tmux" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# watch: called by launchd when GlobalPreferences.plist changes.
# Fast path — no bootstrap. Guards against non-appearance plist changes and
# against running when tmux is not active.
# -----------------------------------------------------------------------------
_cmd_watch() {
  command -v tmux >/dev/null 2>&1 || return 0
  tmux info >/dev/null 2>&1      || return 0

  local dark_val last_dark
  dark_val=$(get_macos_appearance)
  last_dark=$(tmux show-option -gqv @dark_appearance 2>/dev/null)
  [[ "$dark_val" == "$last_dark" ]] && return 0

  macos_dispatch_appearance "$dark_val"
  _apply_theme "$dark_val"
  local cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/tmux-powerkit/data"
  rm -f "${cache_dir}"/rendered_right__* 2>/dev/null || true
  tmux refresh-client -S 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# install: write launchd plist and load the agent (idempotent)
# -----------------------------------------------------------------------------
_cmd_install() {
  cat > "$_PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${_PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${POWERKIT_ROOT}/src/helpers/appearance_toggle.sh</string>
        <string>watch</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>${HOME}/Library/Preferences/.GlobalPreferences.plist</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string>
    </dict>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)/${_PLIST_LABEL}" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$_PLIST_PATH"
}

# -----------------------------------------------------------------------------
# uninstall: unload agent and remove plist
# -----------------------------------------------------------------------------
_cmd_uninstall() {
  launchctl bootout "gui/$(id -u)/${_PLIST_LABEL}" 2>/dev/null || true
  rm -f "$_PLIST_PATH"
}

# -----------------------------------------------------------------------------
# Dispatch
# -----------------------------------------------------------------------------
case "${1:-toggle}" in
  toggle)    _cmd_toggle    ;;
  watch)     _cmd_watch     ;;
  install)   _cmd_install   ;;
  uninstall) _cmd_uninstall ;;
  *)
    echo "usage: $(basename "$0") [toggle|watch|install|uninstall]" >&2
    exit 1
    ;;
esac
