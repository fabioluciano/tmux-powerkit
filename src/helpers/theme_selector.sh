#!/usr/bin/env bash
# Helper: theme_selector - Interactive PowerKit theme selector

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$CURRENT_DIR/.."
THEMES_DIR="$ROOT_DIR/themes"
POWERKIT_ENTRY="$ROOT_DIR/../tmux-powerkit.tmux"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit"
SCRIPT_PATH="$CURRENT_DIR/theme_selector.sh"
THEME_CACHE_FILE="$CACHE_DIR/current_theme"

# Source dependencies (defaults first, then utils for toast function)
. "$ROOT_DIR/defaults.sh" 2>/dev/null || true
. "$ROOT_DIR/utils.sh" 2>/dev/null || true

# Fallback toast if utils.sh didn't load
if ! command -v toast &>/dev/null; then
    toast() { tmux display-message "$1" 2>/dev/null || echo "$1"; }
fi

# Get current theme (from cache file if exists, otherwise from tmux options)
get_current_theme() {
    local theme variant

    # First try to read from persistent cache
    if [[ -f "$THEME_CACHE_FILE" ]]; then
        cat "$THEME_CACHE_FILE"
        return
    fi

    # Fallback to tmux options
    theme=$(tmux show-option -gqv "@powerkit_theme" 2>/dev/null)
    variant=$(tmux show-option -gqv "@powerkit_theme_variant" 2>/dev/null)
    echo "${theme:-tokyo-night}/${variant:-night}"
}

# Apply theme (called directly, not via run-shell)
apply_theme() {
    local theme="$1"
    local variant="$2"

    # Update tmux options
    tmux set-option -g "@powerkit_theme" "$theme"
    tmux set-option -g "@powerkit_theme_variant" "$variant"

    # Ensure cache directory exists
    [[ ! -d "$CACHE_DIR" ]] && mkdir -p "$CACHE_DIR"

    # Save current theme to persistent cache (survives kill-server)
    echo "$theme/$variant" > "$THEME_CACHE_FILE"

    # Clear plugin caches (but not theme cache)
    find "$CACHE_DIR" -maxdepth 1 -type f -name "*.cache" -delete 2>/dev/null || true

    # Re-run PowerKit initialization
    [[ -x "$POWERKIT_ENTRY" ]] && bash "$POWERKIT_ENTRY" 2>/dev/null

    # Refresh
    tmux refresh-client -S
    toast "󰏘 Theme: $theme/$variant" "simple"
}

# Select theme (shows themes menu)
select_theme() {
    local current_theme
    current_theme=$(get_current_theme)

    local -a menu_args=()

    # Iterate through theme directories
    for theme_dir in "$THEMES_DIR"/*/; do
        [[ ! -d "$theme_dir" ]] && continue
        local theme_name
        theme_name=$(basename "$theme_dir")

        # Count variants
        local variant_count=0
        for _ in "$theme_dir"/*.sh; do
            ((variant_count++)) || true
        done

        # If single variant, add direct entry; otherwise, submenu
        if [[ $variant_count -eq 1 ]]; then
            local variant_file variant marker=" "
            variant_file=$(ls "$theme_dir"/*.sh | head -1)
            variant=$(basename "$variant_file" .sh)
            [[ "$theme_name/$variant" == "$current_theme" ]] && marker="●"
            menu_args+=("$marker $theme_name" "" "run-shell \"bash '$SCRIPT_PATH' apply '$theme_name' '$variant'\"")
        else
            # Has multiple variants - show with arrow
            local marker=" "
            [[ "$current_theme" == "$theme_name/"* ]] && marker="●"
            menu_args+=("$marker $theme_name  →" "" "run-shell \"bash '$SCRIPT_PATH' variants '$theme_name'\"")
        fi
    done

    tmux display-menu -T "󰏘  Select Theme" -x C -y C "${menu_args[@]}"
}

# Select variant for a specific theme
select_variant() {
    local theme="$1"
    local theme_dir="$THEMES_DIR/$theme"
    local current_theme
    current_theme=$(get_current_theme)

    [[ ! -d "$theme_dir" ]] && { toast "❌ Theme not found: $theme" "simple"; return 1; }

    local -a menu_args=()

    # Add back option
    menu_args+=("← Back" "" "run-shell \"bash '$SCRIPT_PATH' select\"")
    menu_args+=("" "" "")

    # List variants
    for variant_file in "$theme_dir"/*.sh; do
        [[ ! -f "$variant_file" ]] && continue
        local variant marker=" "
        variant=$(basename "$variant_file" .sh)
        [[ "$theme/$variant" == "$current_theme" ]] && marker="●"
        menu_args+=("$marker $variant" "" "run-shell \"bash '$SCRIPT_PATH' apply '$theme' '$variant'\"")
    done

    tmux display-menu -T "󰏘  $theme" -x C -y C "${menu_args[@]}"
}

# Main
case "${1:-select}" in
    select)
        select_theme
        ;;
    variants)
        select_variant "${2:-}"
        ;;
    apply)
        apply_theme "${2:-tokyo-night}" "${3:-night}"
        ;;
    current)
        get_current_theme
        ;;
    *)
        echo "Usage: $0 {select|variants <theme>|apply <theme> <variant>|current}"
        exit 1
        ;;
esac
