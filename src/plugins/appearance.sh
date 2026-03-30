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
#   The toggle (appearance_toggle.sh) owns all theme changes for forced modes.
#
# Polling (plugin_collect):
#   - Runs every cache_ttl seconds
#   - ONLY syncs theme when mode is "auto" and macOS appearance has changed
#   - Forced dark/light modes: plugin_collect is completely hands-off;
#     the toggle is solely responsible for setting the theme in those modes
#   - Tracks last-applied value in @_powerkit_appearance_handled (not @dark_appearance,
#     which external tools like zac may also write) to detect real changes
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

  declare_option "dark_theme"  "string" "" "Theme/variant for dark mode (e.g. catppuccin/mocha)"
  declare_option "light_theme" "string" "" "Theme/variant for light mode (e.g. catppuccin/latte)"

  declare_option "keybinding_toggle" "key"  ""      "Keybinding to cycle appearance mode"
  declare_option "mouse_toggle"      "bool" "false" "Enable mouse click on the plugin segment to toggle"

  declare_option "cache_ttl" "number" "3" "Cache duration in seconds"
}

# =============================================================================
# Internal: Switch theme to match appearance
# =============================================================================

# Resolve and apply the correct theme/variant for the given dark_val ("1"|"0").
# Priority:
#   1. Explicit dark_theme / light_theme options (e.g. "catppuccin/mocha")
#   2. Auto-detect: if current theme has dark.sh + light.sh, switch variant
#   3. No-op
_appearance_switch_theme() {
  local dark_val="$1"
  local dark_opt light_opt pair theme variant

  dark_opt=$(get_option "dark_theme")
  light_opt=$(get_option "light_theme")

  if [[ -n "$dark_opt" && -n "$light_opt" ]]; then
    # Explicit config — supports any theme/variant pair (e.g. catppuccin)
    [[ "$dark_val" == "1" ]] && pair="$dark_opt" || pair="$light_opt"
    theme="${pair%/*}"
    variant="${pair#*/}"
  else
    # Auto-detect: check if current theme has standard dark.sh + light.sh
    local current_theme themes_dir
    current_theme=$(get_tmux_option "@powerkit_theme" "")
    themes_dir="${POWERKIT_ROOT}/src/themes"

    if [[ -n "$current_theme" && \
          -f "${themes_dir}/${current_theme}/dark.sh" && \
          -f "${themes_dir}/${current_theme}/light.sh" ]]; then
      theme="$current_theme"
      [[ "$dark_val" == "1" ]] && variant="dark" || variant="light"
    else
      return 0  # No-op: theme doesn't support auto light/dark switching
    fi
  fi

  tmux set-option -gq @powerkit_theme         "$theme"   2>/dev/null || true
  tmux set-option -gq @powerkit_theme_variant "$variant" 2>/dev/null || true
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
  local mode dark_val
  mode=$(get_macos_appearance_mode)    # auto | dark | light
  dark_val=$(get_macos_appearance)     # 1 | 0  (actual current display state)

  # Only sync theme in auto mode. In forced dark/light the toggle owns the theme;
  # polling should not interfere with what the user explicitly chose.
  if [[ "$mode" == "auto" ]]; then
    # Use a plugin-owned key (not @dark_appearance, which zac/other tools may write)
    # so we only react to actual macOS appearance changes, not external writes.
    local last_handled
    last_handled=$(get_tmux_option "@_powerkit_appearance_handled" "")
    if [[ "$dark_val" != "$last_handled" ]]; then
      tmux set-option -gq @_powerkit_appearance_handled "$dark_val" 2>/dev/null || true
      macos_dispatch_appearance "$dark_val"
      _appearance_switch_theme "$dark_val"
      tmux run-shell -b "sleep 0.1 && POWERKIT_ROOT='${POWERKIT_ROOT}' '${POWERKIT_ROOT}/tmux-powerkit.tmux' && tmux refresh-client -S" 2>/dev/null || true
    fi
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
