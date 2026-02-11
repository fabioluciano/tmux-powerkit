#!/usr/bin/env bash
# =============================================================================
# Helper: theme_selector (FZF version)
# Description: Interactive PowerKit theme selector using fzf
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Source bootstrap
. "${POWERKIT_ROOT}/src/core/bootstrap.sh"
powerkit_bootstrap_minimal

THEMES_DIR="${POWERKIT_ROOT}/src/themes"

# Get current theme
current_theme=$(get_tmux_option "@powerkit_theme" "catppuccin")
current_variant=$(get_tmux_option "@powerkit_theme_variant" "mocha")

# Build theme list
themes=()
while IFS= read -r -d '' theme_dir; do
    theme_name=$(basename "$theme_dir")

    # Get variants
    while IFS= read -r -d '' variant_file; do
        variant=$(basename "$variant_file" .sh)

        # Mark current theme
        marker=" "
        [[ "$theme_name" == "$current_theme" && "$variant" == "$current_variant" ]] && marker="▶"

        themes+=("$marker $theme_name/$variant")
    done < <(find "$theme_dir" -maxdepth 1 -name "*.sh" -print0 | sort -z)
done < <(find "$THEMES_DIR" -maxdepth 1 -type d ! -name "themes" -print0 | sort -z)

# Show selection
if command -v fzf &>/dev/null; then
    selection=$(printf '%s\n' "${themes[@]}" | fzf \
        --prompt="Select Theme > " \
        --height=100% \
        --border=rounded \
        --header="Current: $current_theme/$current_variant" \
        --reverse \
        --no-info)
else
    # Fallback to simple select
    PS3="Select theme: "
    select selection in "${themes[@]}"; do
        [[ -n "$selection" ]] && break
    done
fi

# Apply selection
if [[ -n "$selection" ]]; then
    # Parse selection and trim whitespace
    theme_variant="${selection#* }"  # Remove marker
    theme_variant="${theme_variant## }"  # Trim leading spaces
    theme_variant="${theme_variant%% }"  # Trim trailing spaces
    theme="${theme_variant%/*}"
    variant="${theme_variant#*/}"

    # Apply theme options (trimmed)
    tmux set-option -g @powerkit_theme "$theme"
    tmux set-option -g @powerkit_theme_variant "$variant"

    # Call dedicated reload script via tmux run-shell
    tmux run-shell "bash '${POWERKIT_ROOT}/src/helpers/reload_theme.sh'"
fi
