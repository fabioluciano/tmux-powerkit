#!/usr/bin/env bash
# =============================================================================
# Helper: theme_selector
# Description: Interactive PowerKit theme selector using tmux display-menu
# Type: menu
# =============================================================================

# Source helper base (handles all initialization)
# Using minimal bootstrap for faster startup
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "theme_selector"
    helper_metadata_set "name" "Theme Selector"
    helper_metadata_set "description" "Select PowerKit theme and variant"
    helper_metadata_set "type" "menu"
}

helper_get_actions() {
    echo "select           - Show theme selection menu (default)"
    echo "variants <theme> - Show variant selection for a theme"
    echo "apply <t> <v>    - Apply theme and variant"
    echo "current          - Show current theme"
}

# =============================================================================
# Configuration
# =============================================================================

THEMES_DIR="${POWERKIT_ROOT}/src/themes"
POWERKIT_ENTRY="${POWERKIT_ROOT}/tmux-powerkit.tmux"
THEME_CACHE_KEY="current_theme"
SCRIPT_PATH="${BASH_SOURCE[0]}"

# =============================================================================
# Theme Management
# =============================================================================

# Get current theme (from cache file if exists, otherwise from tmux options)
_get_current_theme() {
    local theme variant cached

    # First try to read from persistent cache (TTL=31536000 = 1 year, effectively permanent)
    cached=$(cache_get "$THEME_CACHE_KEY" 31536000) || true
    if [[ -n "$cached" ]]; then
        echo "$cached"
        return
    fi

    # Fallback to tmux options
    theme=$(get_tmux_option "@powerkit_theme" "tokyo-night")
    variant=$(get_tmux_option "@powerkit_theme_variant" "night")
    echo "${theme}/${variant}"
}

# Apply theme (called directly, not via run-shell)
_apply_theme() {
    local theme="$1"
    local variant="$2"

    # Show immediate feedback FIRST (before any heavy processing)
    if [[ "$theme" == "custom" ]]; then
        toast " Applying theme: custom..."
    else
        toast " Applying theme: $theme/$variant..."
    fi

    # Update tmux options
    tmux set-option -g "@powerkit_theme" "$theme"

    # For custom theme, variant is just a placeholder
    if [[ "$theme" == "custom" ]]; then
        # Verify custom theme path is set
        local custom_path
        custom_path=$(get_tmux_option "@powerkit_custom_theme_path" "")
        if [[ -z "$custom_path" ]]; then
            toast " Custom theme path not set (@powerkit_custom_theme_path)" "error"
            return 1
        fi
        # Don't set variant for custom theme (it's ignored anyway)
    else
        tmux set-option -g "@powerkit_theme_variant" "$variant"
    fi

    # Save current theme to persistent cache (survives kill-server)
    cache_set "$THEME_CACHE_KEY" "$theme/$variant"

    # Clear plugin caches (but not theme cache)
    cache_clear_prefix "plugin_"

    # Immediate refresh to clear old content
    tmux refresh-client -S

    # Re-run PowerKit initialization in background (non-blocking)
    if [[ -x "$POWERKIT_ENTRY" ]]; then
        (bash "$POWERKIT_ENTRY" 2>/dev/null && tmux refresh-client -S) &
    fi
}

# =============================================================================
# Theme Structure Cache
# =============================================================================

# Get themes structure from cache or filesystem
# Returns: Multi-line string with format "theme:variant1,variant2,..."
_get_themes_structure() {
    local cache_key="themes_structure"
    local ttl=86400  # 24 hours
    local cached

    # Try to get from cache
    if cached=$(cache_get "$cache_key" "$ttl"); then
        printf '%s' "$cached"
        return 0
    fi

    # Scan filesystem
    local structure=""
    for theme_dir in "$THEMES_DIR"/*/; do
        [[ ! -d "$theme_dir" ]] && continue
        local theme_name
        theme_name=$(basename "$theme_dir")

        # Collect variants
        local variants=()
        for variant_file in "$theme_dir"/*.sh; do
            [[ ! -f "$variant_file" ]] && continue
            variants+=("$(basename "$variant_file" .sh)")
        done

        # Add to structure (format: theme:var1,var2,var3)
        if [[ ${#variants[@]} -gt 0 ]]; then
            # Convert array to comma-separated string
            local variants_str
            variants_str=$(IFS=','; echo "${variants[*]}")
            structure+="${theme_name}:${variants_str}"$'\n'
        fi
    done

    # Remove trailing newline
    structure=${structure%$'\n'}

    # Save to cache
    cache_set "$cache_key" "$structure"

    printf '%s' "$structure"
}

# Get variants for a specific theme from cache
# Usage: _parse_theme_variants "catppuccin" "$structure"
# Returns: Comma-separated variants (e.g., "frappe,latte,macchiato,mocha")
_parse_theme_variants() {
    local target_theme="$1"
    local structure="$2"

    while IFS=: read -r theme variants; do
        if [[ "$theme" == "$target_theme" ]]; then
            printf '%s' "$variants"
            return 0
        fi
    done <<< "$structure"

    return 1
}

# =============================================================================
# Theme Selection UI
# =============================================================================

# Select theme (shows themes menu)
_select_theme() {
    local current_theme
    current_theme=$(_get_current_theme)

    local -a menu_args=()

    # Check if custom theme is configured
    local custom_theme_path
    custom_theme_path=$(get_tmux_option "@powerkit_custom_theme_path" "")

    # Add custom theme option if path is configured
    if [[ -n "$custom_theme_path" ]]; then
        local marker=" "
        [[ "$current_theme" == "custom/"* ]] && marker="*"
        menu_args+=("$marker custom (user-defined)" "" "run-shell \"bash '$SCRIPT_PATH' apply 'custom' 'custom'\"")
        # Add separator
        menu_args+=("" "" "")
    fi

    # Get cached themes structure
    local themes_structure
    themes_structure=$(_get_themes_structure)

    # Parse cache and build menu
    while IFS=: read -r theme variants_str; do
        [[ -z "$theme" ]] && continue

        # Parse variants into array
        IFS=',' read -ra variants <<< "$variants_str"
        local variant_count=${#variants[@]}

        # If single variant, add direct entry; otherwise, submenu
        if [[ $variant_count -eq 1 ]]; then
            local marker=" "
            [[ "$theme/${variants[0]}" == "$current_theme" ]] && marker="*"
            menu_args+=("$marker $theme" "" "run-shell \"bash '$SCRIPT_PATH' apply '$theme' '${variants[0]}'\"")
        else
            # Has multiple variants - show with arrow
            local marker=" "
            [[ "$current_theme" == "$theme/"* ]] && marker="*"
            menu_args+=("$marker $theme  >" "" "run-shell \"bash '$SCRIPT_PATH' variants '$theme'\"")
        fi
    done <<< "$themes_structure"

    tmux display-menu -T " Select Theme" -x C -y C "${menu_args[@]}"
}

# Select variant for a specific theme
_select_variant() {
    local theme="$1"
    local current_theme
    current_theme=$(_get_current_theme)

    local -a menu_args=()

    # Add back option
    menu_args+=("< Back" "" "run-shell \"bash '$SCRIPT_PATH' select\"")
    menu_args+=("" "" "")

    # Get variants from cache
    local themes_structure variants_str
    themes_structure=$(_get_themes_structure)
    variants_str=$(_parse_theme_variants "$theme" "$themes_structure")

    if [[ -z "$variants_str" ]]; then
        toast " Theme not found: $theme" "error"
        return 1
    fi

    # Parse and build menu
    IFS=',' read -ra variants <<< "$variants_str"
    for variant in "${variants[@]}"; do
        [[ -z "$variant" ]] && continue
        local marker=" "
        [[ "$theme/$variant" == "$current_theme" ]] && marker="*"
        menu_args+=("$marker $variant" "" "run-shell \"bash '$SCRIPT_PATH' apply '$theme' '$variant'\"")
    done

    tmux display-menu -T " $theme" -x C -y C "${menu_args[@]}"
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-select}"
    shift 2>/dev/null || true

    case "$action" in
        select|"")
            _select_theme
            ;;
        variants)
            _select_variant "${1:-}"
            ;;
        apply)
            _apply_theme "${1:-tokyo-night}" "${2:-night}"
            ;;
        current)
            _get_current_theme
            ;;
        *)
            echo "Unknown action: $action" >&2
            echo "Use --help for usage information" >&2
            return 1
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
