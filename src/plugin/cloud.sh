#!/usr/bin/env bash
# =============================================================================
# Plugin: cloud
# Description: Display active cloud provider context (AWS/GCP/Azure)
# Type: conditional (hidden when not logged in or no active context)
# Dependencies: aws/gcloud/az CLIs for session verification
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "aws" "gcloud" "az" || return 1
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "providers" "string" "all" "Cloud providers to monitor (all|aws,gcp,azure)"
    declare_option "show_region" "bool" "false" "Show AWS region in display"
    declare_option "verify_session" "bool" "true" "Verify active session (not just config)"

    # Icons (Material Design Icons)
    declare_option "icon" "icon" $'\U000F0163' "Plugin icon (cloud-outline)"
    declare_option "icon_aws" "icon" $'\U000F0E0F' "AWS icon (aws)"
    declare_option "icon_gcp" "icon" $'\U000F0B20' "GCP icon (google-cloud)"
    declare_option "icon_azure" "icon" $'\U000F0805' "Azure icon (microsoft-azure)"
    declare_option "icon_multi" "icon" $'\U000F0164' "Multi-provider icon (cloud)"

    # Colors - Default (not logged in)
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Colors - Logged in (active session)
    declare_option "logged_accent_color" "color" "success" "Background when logged in"
    declare_option "logged_accent_color_icon" "color" "success-strong" "Icon background when logged in"

    # Cache
    declare_option "cache_ttl" "number" "60" "Cache duration in seconds"
}

plugin_init "cloud"

# =============================================================================
# AWS Detection
# =============================================================================

# Check if AWS SSO session is active (not expired)
is_aws_session_active() {
    local profile="${1:-default}"
    local verify_session
    verify_session=$(get_option "verify_session")

    # If verification disabled, assume active if profile exists
    [[ "$verify_session" != "true" ]] && return 0

    # Method 1: Check SSO cache for valid access token
    # Important: Only check files that contain accessToken (actual session tokens)
    # Files without accessToken are client registrations (not session tokens)
    local sso_cache_dir="$HOME/.aws/sso/cache"
    if [[ -d "$sso_cache_dir" ]]; then
        local now
        now=$(date +%s)
        for cache_file in "$sso_cache_dir"/*.json; do
            [[ -f "$cache_file" ]] || continue
            # Only process files that have accessToken (real session tokens)
            local has_token expires_at
            has_token=$(jq -r '.accessToken // empty' "$cache_file" 2>/dev/null)
            [[ -z "$has_token" ]] && continue
            expires_at=$(jq -r '.expiresAt // empty' "$cache_file" 2>/dev/null)
            [[ -z "$expires_at" ]] && continue
            # Convert ISO8601 to epoch
            local expires_epoch
            expires_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null || \
                           date -d "$expires_at" +%s 2>/dev/null)
            [[ -n "$expires_epoch" && "$expires_epoch" -gt "$now" ]] && return 0
        done
    fi

    # Method 2: Check credentials cache
    local cred_cache="$HOME/.aws/cli/cache"
    if [[ -d "$cred_cache" ]]; then
        local now
        now=$(date +%s)
        for cache_file in "$cred_cache"/*.json; do
            [[ -f "$cache_file" ]] || continue
            local expiration
            expiration=$(jq -r '.Credentials.Expiration // empty' "$cache_file" 2>/dev/null)
            [[ -z "$expiration" ]] && continue
            local expires_epoch
            expires_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expiration" +%s 2>/dev/null || \
                           date -d "$expiration" +%s 2>/dev/null)
            [[ -n "$expires_epoch" && "$expires_epoch" -gt "$now" ]] && return 0
        done
    fi

    # Method 3: Quick STS check (fallback, more expensive)
    # Only if we have aws cli and no cache hit
    if has_cmd aws; then
        timeout 2 aws sts get-caller-identity --profile "$profile" &>/dev/null && return 0
    fi

    return 1
}

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

    # Check if session is active
    local logged_in="true"
    is_aws_session_active "$profile" || logged_in="false"

    local show_region
    show_region=$(get_option "show_region")

    local context
    [[ -n "$region" && "$show_region" == "true" ]] && context="${profile}@${region}" || context="$profile"

    # Return format: context:logged_in
    echo "${context}:${logged_in}"
}

# =============================================================================
# GCP Detection
# =============================================================================

# Check if GCP session is active
is_gcp_session_active() {
    local verify_session
    verify_session=$(get_option "verify_session")

    # If verification disabled, assume active if config exists
    [[ "$verify_session" != "true" ]] && return 0

    # Check for active credentials in application default credentials
    local adc="$HOME/.config/gcloud/application_default_credentials.json"
    if [[ -f "$adc" ]]; then
        # Check if it has valid access token or refresh token
        local has_creds
        has_creds=$(jq -r '.client_id // .type // empty' "$adc" 2>/dev/null)
        [[ -n "$has_creds" ]] && return 0
    fi

    # Check for active account in gcloud
    local active_cfg="$HOME/.config/gcloud/properties"
    if [[ -f "$active_cfg" ]]; then
        grep -q "^account" "$active_cfg" 2>/dev/null && return 0
    fi

    # Fallback: check active config
    local cfg="$HOME/.config/gcloud/configurations/config_default"
    if [[ -f "$cfg" ]]; then
        grep -q "^account" "$cfg" 2>/dev/null && return 0
    fi

    # Method 2: Quick gcloud check (expensive)
    if has_cmd gcloud; then
        timeout 2 gcloud auth print-access-token &>/dev/null && return 0
    fi

    return 1
}

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

    # Check if session is active
    local logged_in="true"
    is_gcp_session_active || logged_in="false"

    # Return format: context:logged_in
    echo "${project}:${logged_in}"
}

# =============================================================================
# Azure Detection
# =============================================================================

# Check if Azure session is active
is_azure_session_active() {
    local verify_session
    verify_session=$(get_option "verify_session")

    # If verification disabled, assume active if config exists
    [[ "$verify_session" != "true" ]] && return 0

    # Check for active token in accessTokens.json
    local tokens="$HOME/.azure/accessTokens.json"
    if [[ -f "$tokens" ]]; then
        local now
        now=$(date +%s)
        # Check if any token is not expired
        local expires
        expires=$(jq -r '.[0].expiresOn // empty' "$tokens" 2>/dev/null)
        if [[ -n "$expires" ]]; then
            local expires_epoch
            expires_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$expires" +%s 2>/dev/null || \
                           date -d "$expires" +%s 2>/dev/null)
            [[ -n "$expires_epoch" && "$expires_epoch" -gt "$now" ]] && return 0
        fi
    fi

    # Check msal token cache (newer az cli)
    local msal_cache="$HOME/.azure/msal_token_cache.json"
    if [[ -f "$msal_cache" ]]; then
        # If file exists and has AccessToken entries, consider logged in
        jq -e '.AccessToken | length > 0' "$msal_cache" &>/dev/null && return 0
    fi

    # Fallback: Quick az check (expensive)
    if has_cmd az; then
        timeout 2 az account show &>/dev/null && return 0
    fi

    return 1
}

get_azure_subscription() {
    [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]] && { echo "$AZURE_SUBSCRIPTION_ID"; return 0; }

    local cfg="$HOME/.azure/azureProfile.json"
    [[ -f "$cfg" ]] && has_cmd jq && {
        local sub
        sub=$(jq -r '.subscriptions[] | select(.isDefault==true) | .name' "$cfg" 2>/dev/null | head -1)
        [[ -n "$sub" ]] && { echo "$sub"; return 0; }
    }
    return 1
}

get_azure_context() {
    local sub
    sub=$(get_azure_subscription) || return 1

    # Check if session is active
    local logged_in="true"
    is_azure_session_active || logged_in="false"

    # Return format: context:logged_in
    echo "${sub}:${logged_in}"
}

# =============================================================================
# Main Detection
# =============================================================================

# Returns: provider:context:logged_in (e.g., "aws:myprofile@us-east-1:true")
get_cloud_context() {
    local providers
    providers=$(get_option "providers")
    [[ "$providers" == "all" ]] && providers="aws,gcp,azure"

    local ctx=""
    local results=() provider_list=() login_states=()

    for provider in ${providers//,/ }; do
        case "${provider,,}" in
            aws)
                ctx=$(get_aws_context) && {
                    local context="${ctx%:*}"
                    local logged="${ctx##*:}"
                    results+=("$context")
                    provider_list+=("aws")
                    login_states+=("$logged")
                }
                ;;
            gcp)
                ctx=$(get_gcp_context) && {
                    local context="${ctx%:*}"
                    local logged="${ctx##*:}"
                    results+=("$context")
                    provider_list+=("gcp")
                    login_states+=("$logged")
                }
                ;;
            azure)
                ctx=$(get_azure_context) && {
                    local context="${ctx%:*}"
                    local logged="${ctx##*:}"
                    results+=("$context")
                    provider_list+=("azure")
                    login_states+=("$logged")
                }
                ;;
        esac
    done

    [[ ${#results[@]} -eq 0 ]] && return 1

    # Determine overall login state (all must be logged in)
    local all_logged="true"
    for state in "${login_states[@]}"; do
        [[ "$state" != "true" ]] && { all_logged="false"; break; }
    done

    # Single provider: return "provider:context:logged_in"
    # Multiple providers: return "multi:context1 | context2:logged_in"
    if [[ ${#results[@]} -eq 1 ]]; then
        echo "${provider_list[0]}:${results[0]}:${all_logged}"
    else
        local combined
        combined=$(IFS=" | "; echo "${results[*]}")
        echo "multi:$combined:$all_logged"
    fi
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -z "$content" ]] && { echo "0:::"; return; }

    # Read full "provider:context:logged_in" from cache
    local cached provider logged_in icon accent accent_icon
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null) || cached=""
    provider="${cached%%:*}"

    # Extract logged_in status (last field)
    logged_in="${cached##*:}"

    # Get provider-specific icon
    case "$provider" in
        aws)   icon=$(get_option "icon_aws") ;;
        gcp)   icon=$(get_option "icon_gcp") ;;
        azure) icon=$(get_option "icon_azure") ;;
        multi) icon=$(get_option "icon_multi") ;;
        *)     icon=$(get_option "icon") ;;
    esac

    # Set colors based on login state
    if [[ "$logged_in" == "true" ]]; then
        accent=$(get_option "logged_accent_color")
        accent_icon=$(get_option "logged_accent_color_icon")
    else
        accent=$(get_option "accent_color")
        accent_icon=$(get_option "accent_color_icon")
    fi

    # Return: show:accent:accent_icon:icon
    build_display_info "1" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main
# =============================================================================

# Extract context from "provider:context:logged_in" format
_extract_context() {
    local full="$1"
    # Remove provider prefix and logged_in suffix
    local without_provider="${full#*:}"
    local context="${without_provider%:*}"
    echo "$context"
}

load_plugin() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        # Cache has "provider:context:logged_in", output only context for display
        _extract_context "$cached"
        return 0
    fi

    local result
    result=$(get_cloud_context) || return 0

    # Store full "provider:context:logged_in" in cache
    cache_set "$CACHE_KEY" "$result"

    # Output only context for display
    _extract_context "$result"
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
