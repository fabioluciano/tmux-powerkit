#!/usr/bin/env bash
# =============================================================================
# Plugin: cloud
# Description: Display active cloud provider context (AWS/GCP/Azure)
# Dependencies: None (reads from config files, CLIs optional)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "cloud"

# =============================================================================
# AWS Detection
# =============================================================================

get_aws_profile() {
    [[ -n "${AWS_PROFILE:-}" ]] && { echo "$AWS_PROFILE"; return 0; }
    [[ -n "${AWS_DEFAULT_PROFILE:-}" ]] && { echo "$AWS_DEFAULT_PROFILE"; return 0; }
    
    local cfg="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    [[ ! -f "$cfg" ]] && return 1
    
    grep -q '^\[default\]\|^\[profile default\]' "$cfg" 2>/dev/null && { echo "default"; return 0; }
    
    local profile
    profile=$(grep -oE '^\[profile [^]]+\]' "$cfg" 2>/dev/null | head -1 | sed 's/\[profile //;s/\]//')
    [[ -n "$profile" ]] && { echo "$profile"; return 0; }
    return 1
}

get_aws_region() {
    local profile="${1:-default}"
    [[ -n "${AWS_REGION:-}" ]] && { echo "$AWS_REGION"; return 0; }
    [[ -n "${AWS_DEFAULT_REGION:-}" ]] && { echo "$AWS_DEFAULT_REGION"; return 0; }
    
    local cfg="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    [[ ! -f "$cfg" ]] && return 1
    
    # Try region from profile, then sso_region from sso-session
    local region sso_session
    region=$(awk -v p="$profile" '
        /^\[profile / || /^\[default\]/ || /^\[sso-session/ { in_profile=0 }
        $0 ~ "\\[profile "p"\\]" || (p=="default" && /^\[default\]/) { in_profile=1 }
        in_profile && /^region[[:space:]]*=/ { sub(/^region[[:space:]]*=[[:space:]]*/, ""); print; exit }
    ' "$cfg")
    
    [[ -n "$region" ]] && { echo "$region"; return 0; }
    
    # Get sso_session name and lookup sso_region
    sso_session=$(awk -v p="$profile" '
        /^\[profile / || /^\[default\]/ { in_profile=0 }
        $0 ~ "\\[profile "p"\\]" { in_profile=1 }
        in_profile && /^sso_session[[:space:]]*=/ { sub(/^sso_session[[:space:]]*=[[:space:]]*/, ""); print; exit }
    ' "$cfg")
    
    [[ -n "$sso_session" ]] && region=$(awk -v s="$sso_session" '
        /^\[sso-session / { in_session=0 }
        $0 ~ "\\[sso-session "s"\\]" { in_session=1 }
        in_session && /^sso_region[[:space:]]*=/ { sub(/^sso_region[[:space:]]*=[[:space:]]*/, ""); print; exit }
    ' "$cfg")
    
    [[ -n "$region" ]] && echo "$region"
}

get_aws_context() {
    local profile region
    profile=$(get_aws_profile) || return 1
    region=$(get_aws_region "$profile")
    
    local show_region
    show_region=$(get_tmux_option "@powerkit_plugin_cloud_show_region" "$POWERKIT_PLUGIN_CLOUD_SHOW_REGION")
    
    [[ -n "$region" && "$show_region" == "true" ]] && echo "${profile}@${region}" || echo "$profile"
}

# =============================================================================
# GCP Detection
# =============================================================================

get_gcp_project() {
    [[ -n "${CLOUDSDK_CORE_PROJECT:-}" ]] && { echo "$CLOUDSDK_CORE_PROJECT"; return 0; }
    [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]] && { echo "$GOOGLE_CLOUD_PROJECT"; return 0; }
    
    local cfg="$HOME/.config/gcloud/configurations/config_default"
    [[ -f "$cfg" ]] && {
        local project
        project=$(awk -F '= ' '/^project = / {print $2}' "$cfg" 2>/dev/null)
        [[ -n "$project" ]] && { echo "$project"; return 0; }
    }
    return 1
}

get_gcp_context() {
    local project
    project=$(get_gcp_project) || return 1
    echo "$project"
}

# =============================================================================
# Azure Detection
# =============================================================================

get_azure_subscription() {
    [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]] && { echo "$AZURE_SUBSCRIPTION_ID"; return 0; }
    
    local cfg="$HOME/.azure/azureProfile.json"
    [[ -f "$cfg" ]] && require_cmd jq 1 && {
        local sub
        sub=$(jq -r '.subscriptions[] | select(.isDefault==true) | .name' "$cfg" 2>/dev/null | head -1)
        [[ -n "$sub" ]] && { echo "$sub"; return 0; }
    }
    return 1
}

get_azure_context() {
    local sub
    sub=$(get_azure_subscription) || return 1
    echo "$sub"
}

# =============================================================================
# Main Detection
# =============================================================================

# Returns: provider:context (e.g., "aws:myprofile@us-east-1")
get_cloud_context() {
    local providers
    providers=$(get_tmux_option "@powerkit_plugin_cloud_providers" "$POWERKIT_PLUGIN_CLOUD_PROVIDERS")
    [[ "$providers" == "all" ]] && providers="aws,gcp,azure"
    
    local ctx=""
    local results=() provider_list=()
    
    for provider in ${providers//,/ }; do
        case "${provider,,}" in
            aws)   ctx=$(get_aws_context)   && { results+=("$ctx"); provider_list+=("aws"); } ;;
            gcp)   ctx=$(get_gcp_context)   && { results+=("$ctx"); provider_list+=("gcp"); } ;;
            azure) ctx=$(get_azure_context) && { results+=("$ctx"); provider_list+=("azure"); } ;;
        esac
    done
    
    [[ ${#results[@]} -eq 0 ]] && return 1
    
    # Single provider: return "provider:context"
    # Multiple providers: return "multi:context1 | context2"
    if [[ ${#results[@]} -eq 1 ]]; then
        echo "${provider_list[0]}:${results[0]}"
    else
        local combined
        combined=$(IFS=" | "; echo "${results[*]}")
        echo "multi:$combined"
    fi
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -z "$content" ]] && { echo "0:::"; return; }
    
    # Read full "provider:context" from cache to get provider
    local cached provider icon
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null) || cached=""
    provider="${cached%%:*}"
    
    case "$provider" in
        aws)   icon="$POWERKIT_PLUGIN_CLOUD_ICON_AWS" ;;
        gcp)   icon="$POWERKIT_PLUGIN_CLOUD_ICON_GCP" ;;
        azure) icon="$POWERKIT_PLUGIN_CLOUD_ICON_AZURE" ;;
        multi) icon="$POWERKIT_PLUGIN_CLOUD_ICON_MULTI" ;;
        *)     icon="$POWERKIT_PLUGIN_CLOUD_ICON" ;;
    esac
    
    # Return: show:accent:accent_icon:icon
    printf '1:::%s' "$icon"
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        # Cache has "provider:context", output only context for display
        printf '%s' "${cached#*:}"
        return 0
    fi
    
    local result
    result=$(get_cloud_context) || return 0
    
    # Store full "provider:context" in cache
    cache_set "$CACHE_KEY" "$result"
    
    # Output only context for display
    printf '%s' "${result#*:}"
}

# Only run if executed directly (not sourced)
# The || true ensures sourcing doesn't fail with exit code 1
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
