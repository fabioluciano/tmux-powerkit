#!/usr/bin/env bash
# =============================================================================
# Plugin: cloud
# Description: Display active cloud provider context (AWS/GCP/Azure)
# Type: conditional (hidden when not logged in or no active context)
# Dependencies: aws/gcloud/az CLIs
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Cloud provider detected and session active
#   - inactive: No cloud provider detected
#   - degraded: Provider detected but session expired/invalid
#
# Health:
#   - ok: Session is active and valid
#   - warning: Session expired or not authenticated
#
# Context:
#   - aws: AWS provider active
#   - gcp: GCP provider active
#   - azure: Azure provider active
#   - multi: Multiple providers active
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "cloud"
    metadata_set "name" "Cloud"
    metadata_set "description" "Display active cloud provider context"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "aws" "gcloud" "az" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "providers" "string" "all" "Cloud providers to monitor (all|aws,gcp,azure)"
    declare_option "show_region" "bool" "false" "Show AWS region in display"
    declare_option "verify_session" "bool" "true" "Verify active session (not just config)"

    # Icons (Material Design Icons)
    declare_option "icon" "icon" $'\U000F0163' "Default icon (cloud-outline)"
    declare_option "icon_aws" "icon" $'\U000F0E0F' "AWS icon"
    declare_option "icon_gcp" "icon" $'\U000F0B20' "GCP icon"
    declare_option "icon_azure" "icon" $'\U000F0805' "Azure icon"
    declare_option "icon_multi" "icon" $'\U000F0164' "Multi-provider icon"

    # Cache - cloud sessions are relatively stable (minutes to hours)
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local provider logged_in
    provider=$(plugin_data_get "provider")
    logged_in=$(plugin_data_get "logged_in")

    [[ -z "$provider" ]] && { printf 'inactive'; return; }
    [[ "$logged_in" != "true" ]] && { printf 'degraded'; return; }
    printf 'active'
}

plugin_get_health() {
    local logged_in
    logged_in=$(plugin_data_get "logged_in")
    [[ "$logged_in" == "true" ]] && printf 'good' || printf 'warning'
}

plugin_get_context() {
    local provider
    provider=$(plugin_data_get "provider")
    printf '%s' "${provider:-none}"
}

plugin_get_icon() {
    local provider
    provider=$(plugin_data_get "provider")

    case "$provider" in
        aws)   get_option "icon_aws" ;;
        gcp)   get_option "icon_gcp" ;;
        azure) get_option "icon_azure" ;;
        multi) get_option "icon_multi" ;;
        *)     get_option "icon" ;;
    esac
}

# =============================================================================
# AWS Detection
# =============================================================================

_is_aws_session_active() {
    local profile="${1:-default}"
    local verify_session
    verify_session=$(get_option "verify_session")

    [[ "$verify_session" != "true" ]] && return 0

    # Method 1: Check SSO cache for valid access token
    local sso_cache_dir="$HOME/.aws/sso/cache"
    if [[ -d "$sso_cache_dir" ]]; then
        local now=$EPOCHSECONDS
        local cache_file has_token expires_at expires_epoch
        for cache_file in "$sso_cache_dir"/*.json; do
            [[ -f "$cache_file" ]] || continue
            has_token=$(jq -r '.accessToken // empty' "$cache_file" 2>/dev/null)
            [[ -z "$has_token" ]] && continue
            expires_at=$(jq -r '.expiresAt // empty' "$cache_file" 2>/dev/null)
            [[ -z "$expires_at" ]] && continue
            expires_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null || \
                           date -d "$expires_at" +%s 2>/dev/null)
            [[ -n "$expires_epoch" && "$expires_epoch" -gt "$now" ]] && return 0
        done
    fi

    # Method 2: Check credentials cache
    local cred_cache="$HOME/.aws/cli/cache"
    if [[ -d "$cred_cache" ]]; then
        local now=$EPOCHSECONDS
        local cache_file expiration expires_epoch
        for cache_file in "$cred_cache"/*.json; do
            [[ -f "$cache_file" ]] || continue
            expiration=$(jq -r '.Credentials.Expiration // empty' "$cache_file" 2>/dev/null)
            [[ -z "$expiration" ]] && continue
            expires_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expiration" +%s 2>/dev/null || \
                           date -d "$expiration" +%s 2>/dev/null)
            [[ -n "$expires_epoch" && "$expires_epoch" -gt "$now" ]] && return 0
        done
    fi

    # Method 3: Quick STS check (fallback)
    has_cmd aws && timeout 2 aws sts get-caller-identity --profile "$profile" &>/dev/null && return 0

    return 1
}

_get_aws_profile() {
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

_get_aws_region() {
    local profile="${1:-default}"
    [[ -n "${AWS_REGION:-}" ]] && { echo "$AWS_REGION"; return 0; }
    [[ -n "${AWS_DEFAULT_REGION:-}" ]] && { echo "$AWS_DEFAULT_REGION"; return 0; }

    local cfg="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    [[ ! -f "$cfg" ]] && return 1

    local region
    region=$(awk -v p="$profile" '
        /^\[profile / || /^\[default\]/ || /^\[sso-session/ { in_profile=0 }
        $0 ~ "\\[profile "p"\\]" || (p=="default" && /^\[default\]/) { in_profile=1 }
        in_profile && /^region[[:space:]]*=/ { sub(/^region[[:space:]]*=[[:space:]]*/, ""); print; exit }
    ' "$cfg")
    [[ -n "$region" ]] && echo "$region"
}

_get_aws_context() {
    local profile region logged_in show_region context
    profile=$(_get_aws_profile) || return 1

    logged_in="true"
    _is_aws_session_active "$profile" || logged_in="false"

    show_region=$(get_option "show_region")
    region=$(_get_aws_region "$profile")

    [[ -n "$region" && "$show_region" == "true" ]] && context="${profile}@${region}" || context="$profile"

    echo "${context}:${logged_in}"
}

# =============================================================================
# GCP Detection
# =============================================================================

_is_gcp_session_active() {
    local verify_session
    verify_session=$(get_option "verify_session")

    [[ "$verify_session" != "true" ]] && return 0

    # Check application default credentials
    local adc="$HOME/.config/gcloud/application_default_credentials.json"
    if [[ -f "$adc" ]]; then
        local has_creds
        has_creds=$(jq -r '.client_id // .type // empty' "$adc" 2>/dev/null)
        [[ -n "$has_creds" ]] && return 0
    fi

    # Check active account in gcloud
    local active_cfg="$HOME/.config/gcloud/properties"
    [[ -f "$active_cfg" ]] && grep -q "^account" "$active_cfg" 2>/dev/null && return 0

    # Check default config
    local cfg="$HOME/.config/gcloud/configurations/config_default"
    [[ -f "$cfg" ]] && grep -q "^account" "$cfg" 2>/dev/null && return 0

    # Fallback: Quick gcloud check
    has_cmd gcloud && timeout 2 gcloud auth print-access-token &>/dev/null && return 0

    return 1
}

_get_gcp_project() {
    [[ -n "${CLOUDSDK_CORE_PROJECT:-}" ]] && { echo "$CLOUDSDK_CORE_PROJECT"; return 0; }
    [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]] && { echo "$GOOGLE_CLOUD_PROJECT"; return 0; }

    local cfg="$HOME/.config/gcloud/configurations/config_default"
    if [[ -f "$cfg" ]]; then
        local project
        project=$(awk -F '= ' '/^project = / {print $2}' "$cfg" 2>/dev/null)
        [[ -n "$project" ]] && { echo "$project"; return 0; }
    fi
    return 1
}

_get_gcp_context() {
    local project logged_in
    project=$(_get_gcp_project) || return 1

    logged_in="true"
    _is_gcp_session_active || logged_in="false"

    echo "${project}:${logged_in}"
}

# =============================================================================
# Azure Detection
# =============================================================================

_is_azure_session_active() {
    local verify_session
    verify_session=$(get_option "verify_session")

    [[ "$verify_session" != "true" ]] && return 0

    # Check accessTokens.json
    local tokens="$HOME/.azure/accessTokens.json"
    if [[ -f "$tokens" ]]; then
        local now=$EPOCHSECONDS expires expires_epoch
        expires=$(jq -r '.[0].expiresOn // empty' "$tokens" 2>/dev/null)
        if [[ -n "$expires" ]]; then
            expires_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$expires" +%s 2>/dev/null || \
                           date -d "$expires" +%s 2>/dev/null)
            [[ -n "$expires_epoch" && "$expires_epoch" -gt "$now" ]] && return 0
        fi
    fi

    # Check msal token cache
    local msal_cache="$HOME/.azure/msal_token_cache.json"
    [[ -f "$msal_cache" ]] && jq -e '.AccessToken | length > 0' "$msal_cache" &>/dev/null && return 0

    # Fallback: Quick az check
    has_cmd az && timeout 2 az account show &>/dev/null && return 0

    return 1
}

_get_azure_subscription() {
    [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]] && { echo "$AZURE_SUBSCRIPTION_ID"; return 0; }

    local cfg="$HOME/.azure/azureProfile.json"
    if [[ -f "$cfg" ]] && has_cmd jq; then
        local sub
        sub=$(jq -r '.subscriptions[] | select(.isDefault==true) | .name' "$cfg" 2>/dev/null | head -1)
        [[ -n "$sub" ]] && { echo "$sub"; return 0; }
    fi
    return 1
}

_get_azure_context() {
    local sub logged_in
    sub=$(_get_azure_subscription) || return 1

    logged_in="true"
    _is_azure_session_active || logged_in="false"

    echo "${sub}:${logged_in}"
}

# =============================================================================
# Main Detection
# =============================================================================

_get_cloud_context() {
    local providers
    providers=$(get_option "providers")
    [[ "$providers" == "all" ]] && providers="aws,gcp,azure"

    local results=() provider_list=() login_states=()
    local ctx provider

    for provider in ${providers//,/ }; do
        case "${provider,,}" in
            aws)
                ctx=$(_get_aws_context) && {
                    results+=("${ctx%:*}")
                    provider_list+=("aws")
                    login_states+=("${ctx##*:}")
                }
                ;;
            gcp)
                ctx=$(_get_gcp_context) && {
                    results+=("${ctx%:*}")
                    provider_list+=("gcp")
                    login_states+=("${ctx##*:}")
                }
                ;;
            azure)
                ctx=$(_get_azure_context) && {
                    results+=("${ctx%:*}")
                    provider_list+=("azure")
                    login_states+=("${ctx##*:}")
                }
                ;;
        esac
    done

    [[ ${#results[@]} -eq 0 ]] && return 1

    # Determine overall login state
    local all_logged="true"
    local state
    for state in "${login_states[@]}"; do
        [[ "$state" != "true" ]] && { all_logged="false"; break; }
    done

    # Single or multiple providers
    if [[ ${#results[@]} -eq 1 ]]; then
        echo "${provider_list[0]}:${results[0]}:${all_logged}"
    else
        local combined
        combined=$(join_with_separator " | " "${results[@]}")
        echo "multi:$combined:$all_logged"
    fi
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local result provider context logged_in
    result=$(_get_cloud_context) || return 0

    # Parse "provider:context:logged_in"
    provider="${result%%:*}"
    local rest="${result#*:}"
    context="${rest%:*}"
    logged_in="${rest##*:}"

    plugin_data_set "provider" "$provider"
    plugin_data_set "context" "$context"
    plugin_data_set "logged_in" "$logged_in"
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local context
    context=$(plugin_data_get "context")
    printf '%s' "$context"
}
