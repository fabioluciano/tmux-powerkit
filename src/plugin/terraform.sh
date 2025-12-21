#!/usr/bin/env bash
# =============================================================================
# Plugin: terraform
# Description: Display Terraform/OpenTofu workspace and status
# Dependencies: terraform or tofu (optional - reads state directly)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "terraform" "tofu" || return 1
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "tool" "string" "terraform" "Preferred tool (terraform or tofu)"
    declare_option "show_only_in_dir" "bool" "false" "Only show in Terraform directories"
    declare_option "show_pending" "bool" "true" "Show indicator for pending changes"
    declare_option "warn_on_prod" "bool" "true" "Warn when in production workspace"
    declare_option "prod_keywords" "string" "prod,production,prd" "Comma-separated production keywords"

    # Icons
    declare_option "icon" "icon" $'\ue69a' "Plugin icon"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Colors - Production workspace
    declare_option "prod_accent_color" "color" "error" "Background color for production workspace"
    declare_option "prod_accent_color_icon" "color" "error-strong" "Icon background color for production workspace"

    # Colors - Pending changes
    declare_option "pending_accent_color" "color" "warning" "Background color for pending changes"
    declare_option "pending_accent_color_icon" "color" "warning-strong" "Icon background color for pending changes"

    # Keybindings
    declare_option "workspace_key" "key" "" "Key binding for workspace selector"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "terraform"

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
    preferred=$(get_option "tool")

    case "$preferred" in
        tofu|opentofu)
            has_cmd tofu && { echo "tofu"; return 0; }
            has_cmd terraform && { echo "terraform"; return 0; }
            ;;
        terraform|*)
            has_cmd terraform && { echo "terraform"; return 0; }
            has_cmd tofu && { echo "tofu"; return 0; }
            ;;
    esac
    return 1
}

# Check if workspace is production-like
is_prod_workspace() {
    local ws="$1"
    local prod_keywords
    prod_keywords=$(get_option "prod_keywords")

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
    warn_prod=$(get_option "warn_on_prod")

    if [[ "$warn_prod" == "true" ]] && is_prod_workspace "$ws"; then
        accent=$(get_option "prod_accent_color")
        accent_icon=$(get_option "prod_accent_color_icon")
    elif [[ "$has_changes" -eq 1 ]]; then
        accent=$(get_option "pending_accent_color")
        accent_icon=$(get_option "pending_accent_color_icon")
    fi

    build_display_info "$show" "$accent" "$accent_icon" ""
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local show_only_in_tf_dir
    show_only_in_tf_dir=$(get_option "show_only_in_dir")

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
    show_pending=$(get_option "show_pending")
    [[ "$show_pending" == "true" ]] && has_pending_changes && result+="*"

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

# =============================================================================
# Keybindings
# =============================================================================

setup_keybindings() {
    # Check prerequisites before setting up keybindings
    # Don't set up keybindings if:
    # 1. Neither terraform nor tofu are installed
    # 2. No terraform directories exist in current workspace
    local tool
    tool=$(detect_tool) || return 0

    # Check if we're in or near a terraform directory
    # (This check is lenient - keybinding will be available if tool exists)
    # The selector script will handle the case where no workspaces are found

    local workspace_key
    workspace_key=$(get_option "workspace_key")

    local base_dir="${ROOT_DIR%/plugin}"
    local script="${base_dir}/helpers/terraform_workspace_selector.sh"
    [[ -n "$workspace_key" ]] && tmux bind-key "$workspace_key" run-shell "bash '$script' select"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
