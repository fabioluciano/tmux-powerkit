#!/usr/bin/env bash
# =============================================================================
# Plugin: terraform
# Description: Display Terraform/OpenTofu workspace and status
# Dependencies: terraform or tofu
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: In a Terraform directory with workspace
#   - degraded: Has pending changes (tfplan exists)
#   - inactive: Not in a Terraform directory
#
# Health:
#   - error: In production workspace (matches prod_keywords)
#   - warning: Has pending changes
#   - ok: Normal workspace
#
# Context:
#   - production: Production workspace
#   - staging: Staging workspace
#   - development: Development workspace
#   - default: Default workspace
#   - custom: Custom workspace
#   - *_pending: Any of the above with pending changes
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "terraform"
    metadata_set "name" "Terraform"
    metadata_set "description" "Display Terraform/OpenTofu workspace"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "terraform" "tofu" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Tool selection
    declare_option "tool" "enum" "auto" "Preferred tool: auto, terraform, tofu"

    # Display options
    declare_option "show_pending" "bool" "true" "Show indicator for pending changes"

    # Production warning
    declare_option "warn_on_prod" "bool" "true" "Warn when in production workspace"
    declare_option "prod_keywords" "string" "prod,production,prd" "Comma-separated production keywords"

    # Icons
    declare_option "icon" "icon" $'\U000F1062' "Plugin icon"
    declare_option "icon_pending" "icon" $'\U000F12A3' "Pending changes icon"

    # Keybindings
    declare_option "keybinding_workspace" "key" "" "Keybinding for workspace selector"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local workspace=$(plugin_data_get "workspace")
    local has_pending=$(plugin_data_get "has_pending")
    
    if [[ -z "$workspace" ]]; then
        printf 'inactive'
    elif [[ "$has_pending" == "1" ]]; then
        printf 'degraded'
    else
        printf 'active'
    fi
}

plugin_get_health() {
    local workspace=$(plugin_data_get "workspace")
    local has_pending=$(plugin_data_get "has_pending")
    local warn_on_prod=$(get_option "warn_on_prod")
    local prod_keywords=$(get_option "prod_keywords")
    
    if [[ -z "$workspace" ]]; then
        printf 'ok'
        return
    fi
    
    # Check if in production workspace
    if [[ "$warn_on_prod" == "true" ]]; then
        local IFS=','
        for keyword in $prod_keywords; do
            keyword=$(trim "$keyword")
            if [[ "${workspace,,}" == *"${keyword,,}"* ]]; then
                printf 'error'
                return
            fi
        done
    fi
    
    # Check for pending changes
    if [[ "$has_pending" == "1" ]]; then
        printf 'warning'
        return
    fi
    
    printf 'ok'
}

plugin_get_context() {
    local workspace=$(plugin_data_get "workspace")
    local has_pending=$(plugin_data_get "has_pending")
    local prod_keywords=$(get_option "prod_keywords")
    
    if [[ -z "$workspace" ]]; then
        printf 'none'
        return
    fi
    
    # Check for production
    local IFS=','
    for keyword in $prod_keywords; do
        keyword=$(trim "$keyword")
        if [[ "${workspace,,}" == *"${keyword,,}"* ]]; then
            [[ "$has_pending" == "1" ]] && printf 'production_pending' || printf 'production'
            return
        fi
    done
    
    if [[ "$workspace" == "default" ]]; then
        [[ "$has_pending" == "1" ]] && printf 'default_pending' || printf 'default'
    elif [[ "${workspace,,}" == *stag* || "${workspace,,}" == *staging* ]]; then
        [[ "$has_pending" == "1" ]] && printf 'staging_pending' || printf 'staging'
    elif [[ "${workspace,,}" == *dev* || "${workspace,,}" == *development* ]]; then
        [[ "$has_pending" == "1" ]] && printf 'development_pending' || printf 'development'
    else
        [[ "$has_pending" == "1" ]] && printf 'custom_pending' || printf 'custom'
    fi
}

plugin_get_icon() {
    local has_pending=$(plugin_data_get "has_pending")
    [[ "$has_pending" == "1" ]] && get_option "icon_pending" || get_option "icon"
}

# =============================================================================
# Tool Detection
# =============================================================================

_detect_tool() {
    local preferred=$(get_option "tool")

    case "$preferred" in
        tofu)
            has_cmd tofu && { printf 'tofu'; return 0; }
            ;;
        terraform)
            has_cmd terraform && { printf 'terraform'; return 0; }
            ;;
        auto|*)
            # Auto-detect: prefer terraform, fallback to tofu
            has_cmd terraform && { printf 'terraform'; return 0; }
            has_cmd tofu && { printf 'tofu'; return 0; }
            ;;
    esac
    return 1
}

# =============================================================================
# Directory Detection
# =============================================================================

# Check if directory is a Terraform/Terragrunt directory
# Detects: .terraform/, *.tf, terragrunt*.hcl
_is_tf_directory() {
    local path="$1"
    [[ -d "${path}/.terraform" ]] && return 0
    ls "${path}"/*.tf &>/dev/null 2>&1 && return 0
    ls "${path}"/terragrunt*.hcl &>/dev/null 2>&1 && return 0
    return 1
}

# Check if directory has pending Terraform changes
_has_pending_changes() {
    local path="$1"
    [[ -f "${path}/tfplan" ]] && return 0
    [[ -f "${path}/.terraform/tfplan" ]] && return 0
    return 1
}

# =============================================================================
# Main Logic
# =============================================================================

_get_terraform_workspace() {
    local path="$1"
    local tool="$2"
    
    # Method 1: Read from environment file (fastest, no command execution)
    local env_file="${path}/.terraform/environment"
    if [[ -f "$env_file" ]]; then
        cat "$env_file" 2>/dev/null
        return 0
    fi
    
    # Method 2: Use tool command
    if [[ -n "$tool" ]]; then
        local ws
        ws=$(cd "$path" && "$tool" workspace show 2>/dev/null)
        [[ -n "$ws" ]] && { printf '%s' "$ws"; return 0; }
    fi
    
    printf 'default'
}

plugin_collect() {
    local path=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
    [[ -z "$path" || ! -d "$path" ]] && return 0

    # Only show in Terraform directories
    _is_tf_directory "$path" || return 0

    local tool=$(_detect_tool)
    local workspace=$(_get_terraform_workspace "$path" "$tool")

    [[ -z "$workspace" ]] && return 0

    plugin_data_set "workspace" "$workspace"
    plugin_data_set "tool" "$tool"

    # Check for pending changes
    if [[ "$(get_option "show_pending")" == "true" ]] && _has_pending_changes "$path"; then
        plugin_data_set "has_pending" "1"
    else
        plugin_data_set "has_pending" "0"
    fi
}

plugin_render() {
    local workspace has_pending
    workspace=$(plugin_data_get "workspace")
    has_pending=$(plugin_data_get "has_pending")

    [[ -z "$workspace" ]] && return 0

    # Add pending indicator if enabled and has pending changes
    if [[ "$(get_option "show_pending")" == "true" && "$has_pending" == "1" ]]; then
        printf '%s*' "$workspace"
    else
        printf '%s' "$workspace"
    fi
}

# =============================================================================
# Keybindings
# =============================================================================

plugin_setup_keybindings() {
    local ws_key helper_script
    ws_key=$(get_option "keybinding_workspace")
    helper_script="${POWERKIT_ROOT}/src/helpers/terraform_workspace_selector.sh"

    # terraform_workspace_selector uses display-menu (not popup)
    pk_bind_shell "$ws_key" "bash '$helper_script' select" "terraform:workspace"
}

