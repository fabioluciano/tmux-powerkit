#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Theme Loader
# Description: Loads theme files and initializes color system
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "theme_loader" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/core/cache.sh"
. "${POWERKIT_ROOT}/src/core/color_generator.sh"

# =============================================================================
# Configuration (using defaults from defaults.sh)
# =============================================================================

_THEMES_DIR="${POWERKIT_ROOT}/src/themes"
_THEME_CACHE_KEY="current_theme"

# Current loaded theme
declare -g _CURRENT_THEME=""
declare -g _CURRENT_VARIANT=""

# Theme colors (populated by theme file)
declare -gA THEME_COLORS=()

# =============================================================================
# Internal Functions
# =============================================================================

# Expand tilde in path
_expand_path() {
    local path="$1"
    # Handle escaped tilde
    path="${path//\\~/~}"
    # Expand tilde to home directory
    if [[ "$path" == "~"* ]]; then
        path="${HOME}${path:1}"
    fi
    printf '%s' "$path"
}

# Load theme from cache (uses cache API)
_load_cached_theme() {
    local cached
    # TTL=31536000 (1 year) - effectively permanent
    cached=$(cache_get "$_THEME_CACHE_KEY" 31536000) || return 1
    [[ -z "$cached" ]] && return 1

    # Parse theme/variant format
    if [[ "$cached" == *"/"* ]]; then
        _CURRENT_THEME="${cached%/*}"
        _CURRENT_VARIANT="${cached#*/}"
        return 0
    fi

    return 1
}

# Save current theme to cache (uses cache API)
_save_theme_cache() {
    cache_set "$_THEME_CACHE_KEY" "${_CURRENT_THEME}/${_CURRENT_VARIANT}"
}

# Get theme file path
_get_theme_path() {
    local theme="$1"
    local variant="$2"

    if [[ "$theme" == "custom" ]]; then
        local custom_path
        custom_path=$(get_tmux_option "@powerkit_custom_theme_path" "${POWERKIT_DEFAULT_CUSTOM_THEME_PATH}")
        custom_path=$(_expand_path "$custom_path")
        printf '%s' "$custom_path"
    else
        printf '%s/%s/%s.sh' "$_THEMES_DIR" "$theme" "$variant"
    fi
}

# Validate theme file exists
_validate_theme() {
    local theme_path="$1"
    [[ -f "$theme_path" && -r "$theme_path" ]]
}

# =============================================================================
# Public API
# =============================================================================

# Load a theme
# Usage: load_theme "tokyo-night" "night"
load_theme() {
    local theme="${1:-${POWERKIT_DEFAULT_THEME}}"
    local variant="${2:-${POWERKIT_DEFAULT_THEME_VARIANT}}"

    # Fast path: if same theme/variant is already in memory with colors+variants, reuse
    if [[ "$_CURRENT_THEME" == "$theme" && "$_CURRENT_VARIANT" == "$variant" && ${#THEME_COLORS[@]} -gt 0 && ${#_COLOR_VARIANTS[@]} -gt 0 ]]; then
        log_debug "theme_loader" "Using in-memory theme: $theme/$variant"
        return 0
    fi

    # Try to load from color cache first
    local cache_key="theme_colors__${theme}__${variant}"
    local cached_colors
    cached_colors=$(cache_get "$cache_key" 86400 2>/dev/null)  # 24h TTL
    
    if [[ -n "$cached_colors" ]]; then
        log_debug "theme_loader" "Loading theme from cache: $theme/$variant"
        deserialize_theme_colors "$cached_colors"
        # Validate cache contents; if empty or corrupted, fall back to file load
        if [[ ${#THEME_COLORS[@]} -gt 0 && ${#_COLOR_VARIANTS[@]} -gt 0 ]]; then
            _CURRENT_THEME="$theme"
            _CURRENT_VARIANT="$variant"
            _save_theme_cache
            log_debug "theme_loader" "Cache valid for: $theme/$variant"
            return 0
        else
            log_warn "theme_loader" "Theme cache invalid/empty, reloading from file: $theme/$variant"
            THEME_COLORS=()
            clear_color_variants
        fi
    fi

    # Get theme file path
    local theme_path
    theme_path=$(_get_theme_path "$theme" "$variant")

    # Validate theme exists
    if ! _validate_theme "$theme_path"; then
        log_warn "theme_loader" "Theme not found: $theme/$variant, falling back to default"
        theme="${POWERKIT_DEFAULT_THEME}"
        variant="${POWERKIT_DEFAULT_THEME_VARIANT}"
        theme_path=$(_get_theme_path "$theme" "$variant")

        if ! _validate_theme "$theme_path"; then
            log_error "theme_loader" "Default theme not found: $theme_path"
            return 1
        fi
    fi

    # Clear existing colors
    THEME_COLORS=()
    clear_color_variants

    # Source theme file
    log_debug "theme_loader" "Loading theme from file: $theme_path"
    # shellcheck disable=SC1090
    . "$theme_path"

    # Validate THEME_COLORS was populated
    if [[ ${#THEME_COLORS[@]} -eq 0 ]]; then
        log_error "theme_loader" "Theme file did not define THEME_COLORS: $theme_path"
        return 1
    fi

    # Generate color variants
    generate_color_variants

    # Cache all colors (base + variants) in a single file
    local serialized
    serialized=$(serialize_theme_colors)
    cache_set "$cache_key" "$serialized"

    # Verify cache persisted; if not, log and continue with in-memory colors
    if ! cache_get "$cache_key" 86400 >/dev/null 2>&1; then
        log_warn "theme_loader" "Failed to persist theme cache (will reuse in-memory colors): $cache_key"
    else
        log_debug "theme_loader" "Persisted theme cache: $cache_key"
    fi

    # Update current theme
    _CURRENT_THEME="$theme"
    _CURRENT_VARIANT="$variant"

    # Save to cache
    _save_theme_cache

    log_info "theme_loader" "Loaded theme: $theme/$variant with ${#THEME_COLORS[@]} base colors + variants (cached)"
    return 0
}

# Load theme from tmux options or cache
# Usage: load_powerkit_theme
load_powerkit_theme() {
    local theme variant

    # Try cache first
    if _load_cached_theme; then
        theme="$_CURRENT_THEME"
        variant="$_CURRENT_VARIANT"
    fi

    # Tmux options override cache
    local opt_theme opt_variant
    opt_theme=$(get_tmux_option "@powerkit_theme" "")
    opt_variant=$(get_tmux_option "@powerkit_theme_variant" "")

    if [[ -n "$opt_theme" ]]; then theme="$opt_theme"; fi
    if [[ -n "$opt_variant" ]]; then variant="$opt_variant"; fi

    # Fall back to defaults if not set
    theme="${theme:-${POWERKIT_DEFAULT_THEME}}"
    variant="${variant:-${POWERKIT_DEFAULT_THEME_VARIANT}}"

    load_theme "$theme" "$variant"
}

# Get currently loaded theme info
# Usage: get_current_theme
get_current_theme() {
    printf '%s/%s' "$_CURRENT_THEME" "$_CURRENT_VARIANT"
}

# Get theme name
get_theme_name() {
    printf '%s' "$_CURRENT_THEME"
}

# Get theme variant
get_theme_variant() {
    printf '%s' "$_CURRENT_VARIANT"
}

# =============================================================================
# Theme Discovery
# =============================================================================

# List available themes
# Usage: list_themes
list_themes() {
    local theme_dir
    for theme_dir in "$_THEMES_DIR"/*/; do
        [[ -d "$theme_dir" ]] || continue
        local theme_name
        theme_name=$(basename "$theme_dir")
        printf '%s\n' "$theme_name"
    done
}

# List variants for a theme
# Usage: list_variants "tokyo-night"
list_variants() {
    local theme="$1"
    local variant_file
    for variant_file in "$_THEMES_DIR/$theme"/*.sh; do
        [[ -f "$variant_file" ]] || continue
        local variant_name
        variant_name=$(basename "$variant_file" .sh)
        printf '%s\n' "$variant_name"
    done
}

# List all theme/variant combinations
list_all_themes() {
    local theme variant
    for theme in $(list_themes); do
        for variant in $(list_variants "$theme"); do
            printf '%s/%s\n' "$theme" "$variant"
        done
    done
}

# =============================================================================
# Color Access Helpers
# =============================================================================

# Get a theme color by semantic name
# Usage: get_powerkit_color "secondary"
get_powerkit_color() {
    local name="$1"
    get_color "$name"
}

# Check if theme is loaded
is_theme_loaded() {
    [[ -n "$_CURRENT_THEME" && ${#THEME_COLORS[@]} -gt 0 ]]
}

# Reload current theme (useful after theme file changes)
reload_theme() {
    if [[ -n "$_CURRENT_THEME" ]]; then
        load_theme "$_CURRENT_THEME" "$_CURRENT_VARIANT"
    else
        load_powerkit_theme
    fi
}
