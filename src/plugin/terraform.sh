#!/usr/bin/env bash
# =============================================================================
# Plugin: terraform
# Description: Display Terraform/OpenTofu workspace and status
# Dependencies: terraform or tofu (optional - reads state directly)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "terraform"

# Configuration
_workspace_key=$(get_tmux_option "@powerkit_plugin_terraform_workspace_key" "$POWERKIT_PLUGIN_TERRAFORM_WORKSPACE_KEY")

# =============================================================================
# Terraform/OpenTofu Functions
# =============================================================================

# Detect if we're in a Terraform directory
is_tf_directory() {
    local pane_path
    pane_path=$(tmux display-message -p -F "#{pane_current_path}" 2>/dev/null)
    [[ -z "$pane_path" ]] && pane_path="$PWD"
    
    [[ -d "${pane_path}/.terraform" ]] && return 0
    ls "${pane_path}"/*.tf &>/dev/null && return 0
    
    return 1
}

# Get current workspace
get_workspace() {
    local pane_path
    pane_path=$(tmux display-message -p -F "#{pane_current_path}" 2>/dev/null)
    [[ -z "$pane_path" ]] && pane_path="$PWD"
    
    # Method 1: Read from environment file
    local env_file="${pane_path}/.terraform/environment"
    if [[ -f "$env_file" ]]; then
        cat "$env_file" 2>/dev/null
        return 0
    fi
    
    # Method 2: Try terraform/tofu command
    local tool
    tool=$(detect_tool)
    if [[ -n "$tool" ]]; then
        local ws
        ws=$(cd "$pane_path" && "$tool" workspace show 2>/dev/null)
        [[ -n "$ws" ]] && { echo "$ws"; return 0; }
    fi
    
    echo "default"
}

# Detect terraform or tofu
detect_tool() {
    local preferred
    preferred=$(get_cached_option "@powerkit_plugin_terraform_tool" "$POWERKIT_PLUGIN_TERRAFORM_TOOL")

    case "$preferred" in
        tofu|opentofu)
            require_cmd tofu 1 && { echo "tofu"; return 0; }
            require_cmd terraform 1 && { echo "terraform"; return 0; }
            ;;
        terraform|*)
            require_cmd terraform 1 && { echo "terraform"; return 0; }
            require_cmd tofu 1 && { echo "tofu"; return 0; }
            ;;
    esac
    return 1
}

# Check if workspace is production-like
is_prod_workspace() {
    local ws="$1"
    local prod_keywords
    prod_keywords=$(get_cached_option "@powerkit_plugin_terraform_prod_keywords" "$POWERKIT_PLUGIN_TERRAFORM_PROD_KEYWORDS")
    
    IFS=',' read -ra keywords <<< "$prod_keywords"
    for kw in "${keywords[@]}"; do
        kw="${kw#"${kw%%[![:space:]]*}"}"
        kw="${kw%"${kw##*[![:space:]]}"}"
        [[ "${ws,,}" == *"${kw,,}"* ]] && return 0
    done
    return 1
}

# Check for pending changes
has_pending_changes() {
    local pane_path
    pane_path=$(tmux display-message -p -F "#{pane_current_path}" 2>/dev/null)
    [[ -z "$pane_path" ]] && pane_path="$PWD"
    
    [[ -f "${pane_path}/tfplan" ]] && return 0
    [[ -f "${pane_path}/.terraform/tfplan" ]] && return 0
    
    return 1
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    local show="1" accent="" accent_icon=""
    
    [[ -z "$content" ]] && { build_display_info "0" "" "" ""; return; }
    
    local ws="${content%\*}"
    local has_changes=0
    [[ "$content" == *"*" ]] && has_changes=1
    
    local warn_prod
    warn_prod=$(get_cached_option "@powerkit_plugin_terraform_warn_on_prod" "$POWERKIT_PLUGIN_TERRAFORM_WARN_ON_PROD")
    
    if [[ "$warn_prod" == "true" ]] && is_prod_workspace "$ws"; then
        accent=$(get_cached_option "@powerkit_plugin_terraform_prod_accent_color" "$POWERKIT_PLUGIN_TERRAFORM_PROD_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_terraform_prod_accent_color_icon" "$POWERKIT_PLUGIN_TERRAFORM_PROD_ACCENT_COLOR_ICON")
    elif [[ "$has_changes" -eq 1 ]]; then
        accent=$(get_cached_option "@powerkit_plugin_terraform_pending_accent_color" "$POWERKIT_PLUGIN_TERRAFORM_PENDING_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_terraform_pending_accent_color_icon" "$POWERKIT_PLUGIN_TERRAFORM_PENDING_ACCENT_COLOR_ICON")
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" ""
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local show_only_in_tf_dir
    show_only_in_tf_dir=$(get_cached_option "@powerkit_plugin_terraform_show_only_in_dir" "$POWERKIT_PLUGIN_TERRAFORM_SHOW_ONLY_IN_DIR")
    
    if [[ "$show_only_in_tf_dir" == "true" ]]; then
        is_tf_directory || return 0
    fi
    
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi
    
    is_tf_directory || return 0
    
    local workspace
    workspace=$(get_workspace) || return 0
    [[ -z "$workspace" ]] && return 0
    
    local result="$workspace"
    
    local show_pending
    show_pending=$(get_cached_option "@powerkit_plugin_terraform_show_pending" "$POWERKIT_PLUGIN_TERRAFORM_SHOW_PENDING")
    [[ "$show_pending" == "true" ]] && has_pending_changes && result+="*"
    
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

# =============================================================================
# Keybindings
# =============================================================================

setup_keybindings() {
    local base_dir="${ROOT_DIR%/plugin}"
    local script="${base_dir}/helpers/terraform_workspace_selector.sh"
    [[ -n "$_workspace_key" ]] && tmux bind-key "$_workspace_key" run-shell "bash '$script' select"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
