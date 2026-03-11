#!/usr/bin/env bash
# =============================================================================
# Plugin: appearance
# Description: macOS appearance monitor with auto/dark/light three-way toggle
# Type: conditional (hidden on non-macOS)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active:   Running on macOS with appearance data collected
#   - inactive: Not on macOS
#
# Health:
#   - ok:   Auto mode (following system schedule)
#   - good: Forced dark or light mode
#
# Context:
#   - auto:  Following system appearance
#   - dark:  Forced dark mode
#   - light: Forced light mode
#
# Toggle cycle: auto → dark → light → auto
#   Triggered by keybinding_toggle or mouse click on the plugin segment.
#
# This plugin is the tmux-side appearance watcher:
#   - Polls system appearance each status interval via get_macos_appearance_mode()
#   - When @dark_appearance changes, calls macos_dispatch_appearance() which
#     sets the tmux option and sends SIGUSR1 to all zsh panes so zac
#     (zsh-appearance-control) can sync its internal state.
#
# This file doubles as a CLI tool when invoked directly:
#   bash appearance.sh toggle
# Used by keybindings and mouse clicks — no separate helper script needed.
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
  metadata_set "id"          "appearance"
  metadata_set "name"        "Appearance"
  metadata_set "description" "macOS appearance monitor with auto/dark/light toggle"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
  is_macos || return 1
  require_cmd "defaults"  || return 1
  require_cmd "osascript" || return 1
  return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
  declare_option "icon_auto"  "icon" $'\U000F101B' "Nerd Font icon: auto mode (theme-light-dark)"
  declare_option "icon_dark"  "icon" $'\U000F0594' "Nerd Font icon: dark mode (moon)"
  declare_option "icon_light" "icon" $'\U000F0599' "Nerd Font icon: light mode (sun)"

  declare_option "toggle_icon_auto"  "icon" "🌗" "Content icon: auto mode"
  declare_option "toggle_icon_dark"  "icon" "🌚" "Content icon: dark mode"
  declare_option "toggle_icon_light" "icon" "🌞" "Content icon: light mode"

  declare_option "keybinding_toggle" "key"  ""      "Keybinding to cycle appearance mode"
  declare_option "mouse_toggle"      "bool" "false" "Enable mouse click on the plugin segment to toggle"

  declare_option "cache_ttl" "number" "0" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
  local mode dark_val
  mode=$(get_macos_appearance_mode)    # auto | dark | light
  dark_val=$(get_macos_appearance)     # 1 | 0  (actual current display state)

  local last_dark
  last_dark=$(get_tmux_option "@dark_appearance" "")
  if [[ "$dark_val" != "$last_dark" ]]; then
    macos_dispatch_appearance "$dark_val"
    local cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/tmux-powerkit/data"
    rm -f "${cache_dir}"/rendered_right__* 2>/dev/null || true
    tmux run-shell -b "sleep 0.5 && tmux refresh-client -S" 2>/dev/null || true
  fi

  plugin_data_set "mode" "$mode"
  plugin_data_set "dark" "$dark_val"
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence()     { printf 'conditional'; }

# =============================================================================
# Plugin Contract: State
# =============================================================================

plugin_get_state() {
  is_macos || { printf 'inactive'; return; }
  local mode
  mode=$(plugin_data_get "mode")
  [[ -n "$mode" ]] && printf 'active' || printf 'inactive'
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================

plugin_get_health() {
  local mode
  mode=$(plugin_data_get "mode")
  case "$mode" in
    auto) printf 'ok'   ;;
    *)    printf 'good' ;;
  esac
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================

plugin_get_context() {
  local mode
  mode=$(plugin_data_get "mode")
  printf '%s' "${mode:-auto}"
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() {
  local mode
  mode=$(plugin_data_get "mode")
  case "$mode" in
    dark)  get_option "icon_dark"  ;;
    light) get_option "icon_light" ;;
    *)     get_option "icon_auto"  ;;
  esac
}

# =============================================================================
# Plugin Contract: Render (plain text only)
# =============================================================================

plugin_render() {
  local mode
  mode=$(plugin_data_get "mode")
  case "$mode" in
    dark)  get_option "toggle_icon_dark"  ;;
    light) get_option "toggle_icon_light" ;;
    *)     get_option "toggle_icon_auto"  ;;
  esac
}

# =============================================================================
# Plugin Contract: Keybindings
# =============================================================================

plugin_setup_keybindings() {
  local toggle_key mouse helper
  helper="${POWERKIT_ROOT}/src/helpers/appearance_toggle.sh"

  toggle_key=$(get_option "keybinding_toggle")
  if [[ -n "$toggle_key" ]]; then
    register_keybinding "$toggle_key" "run-shell 'bash \"${helper}\"'"
  fi

  mouse=$(get_option "mouse_toggle")
  if [[ "$mouse" == "true" ]]; then
    # MouseDown1Status fires for user-named ranges in status-right.
    # #{mouse_status_range} returns the bare name (not "user|name").
    # Fall through to switch-client so window selection still works.
    tmux bind-key -T root MouseDown1Status \
      if-shell -F "#{==:#{mouse_status_range},appearance}" \
      "run-shell 'bash ${helper}'" \
      "switch-client -t =" 2>/dev/null || true
  fi
}
