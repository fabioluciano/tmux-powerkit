#!/usr/bin/env bash
# =============================================================================
# Plugin: cloudstatus
# Description: Monitor cloud provider status (StatusPage.io compatible APIs)
# Dependencies: curl, jq (optional)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "cloudstatus"

# =============================================================================
# Provider Configuration (StatusPage.io API compatible)
# =============================================================================

# Format: name|api_url|icon
declare -A CLOUD_PROVIDERS=(
    # Major Cloud Providers
    ["aws"]="AWS|https://status.aws.amazon.com/data.json|󰸏"
    ["gcp"]="GCP|https://status.cloud.google.com/incidents.json|󱇶"

    # CDN & Infrastructure
    ["cloudflare"]="CF|https://www.cloudflarestatus.com/api/v2/status.json|󰸝"

    # Platform as a Service
    ["vercel"]="Vercel|https://www.vercel-status.com/api/v2/status.json|▲"
    ["netlify"]="Netlify|https://www.netlifystatus.com/api/v2/status.json|󰻃"
    ["digitalocean"]="DO|https://status.digitalocean.com/api/v2/status.json|🌊"

    # Development Tools
    ["github"]="GitHub|https://www.githubstatus.com/api/v2/status.json|󰊤"

    # Communication
    ["discord"]="Discord|https://discordstatus.com/api/v2/status.json|󰙯"
)

# =============================================================================
# Status Functions
# =============================================================================

fetch_status() {
    local url="$1"
    local timeout
    timeout=$(get_cached_option "@powerkit_plugin_cloudstatus_timeout" "$POWERKIT_PLUGIN_CLOUDSTATUS_TIMEOUT")
    timeout=$(validate_range "$timeout" 1 30 5)

    safe_curl "$url" "$timeout"
}

parse_statuspage() {
    local data="$1"

    # Try jq first (most reliable)
    if require_cmd jq 1; then
        printf '%s' "$data" | jq -r '.status.indicator // "operational"' 2>/dev/null
        return
    fi

    # Fallback: grep
    local indicator
    indicator=$(printf '%s' "$data" | grep -o '"indicator":"[^"]*"' | head -1 | cut -d'"' -f4)
    printf '%s' "${indicator:-operational}"
}

parse_gcp() {
    local data="$1"

    if require_cmd jq 1; then
        local active
        active=$(printf '%s' "$data" | jq '[.[] | select(.end == null)] | length' 2>/dev/null)
        [[ "${active:-0}" -gt 0 ]] && printf 'major' || printf 'operational'
        return
    fi

    # Fallback
    [[ "$data" == *'"end":null'* ]] && printf 'major' || printf 'operational'
}

get_provider_status() {
    local provider_key="$1"
    local provider_config="${CLOUD_PROVIDERS[$provider_key]}"
    [[ -z "$provider_config" ]] && return 1

    IFS='|' read -r name api_url icon <<< "$provider_config"

    local data
    data=$(fetch_status "$api_url")
    if [[ -z "$data" ]]; then
        log_warn "cloudstatus" "Failed to fetch status for provider: $provider_key"
        printf 'unknown'
        return
    fi

    log_debug "cloudstatus" "Successfully fetched status for: $provider_key"

    # GCP has different format
    [[ "$provider_key" == "gcp" ]] && { parse_gcp "$data"; return; }

    # StatusPage.io format (most providers)
    parse_statuspage "$data"
}

normalize_status() {
    case "$1" in
        none|operational|green|ok) printf 'ok' ;;
        minor|degraded*|yellow)    printf 'warning' ;;
        major|partial*|critical*)  printf 'error' ;;
        *)                         printf 'unknown' ;;
    esac
}

get_status_symbol() {
    case "$1" in
        ok)      printf '✓' ;;
        warning) printf '⚠' ;;
        error)   printf '✗' ;;
        *)       printf '?' ;;
    esac
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    [[ -z "$content" ]] && { build_display_info "0" "" "" ""; return; }

    local accent="" accent_icon=""

    # Check for warning/error in content
    if [[ "$content" == *"✗"* ]]; then
        accent=$(get_cached_option "@powerkit_plugin_cloudstatus_critical_accent_color" "$POWERKIT_PLUGIN_CLOUDSTATUS_CRITICAL_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_cloudstatus_critical_accent_color_icon" "$POWERKIT_PLUGIN_CLOUDSTATUS_CRITICAL_ACCENT_COLOR_ICON")
    elif [[ "$content" == *"⚠"* ]]; then
        accent=$(get_cached_option "@powerkit_plugin_cloudstatus_warning_accent_color" "$POWERKIT_PLUGIN_CLOUDSTATUS_WARNING_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_cloudstatus_warning_accent_color_icon" "$POWERKIT_PLUGIN_CLOUDSTATUS_WARNING_ACCENT_COLOR_ICON")
    fi

    build_display_info "1" "$accent" "$accent_icon" ""
}

# =============================================================================
# Main
# =============================================================================

_compute_cloudstatus() {
    local providers separator issues_only
    providers=$(get_cached_option "@powerkit_plugin_cloudstatus_providers" "$POWERKIT_PLUGIN_CLOUDSTATUS_PROVIDERS")
    separator=$(get_cached_option "@powerkit_plugin_cloudstatus_separator" "$POWERKIT_PLUGIN_CLOUDSTATUS_SEPARATOR")
    issues_only=$(get_cached_option "@powerkit_plugin_cloudstatus_issues_only" "$POWERKIT_PLUGIN_CLOUDSTATUS_ISSUES_ONLY")
    issues_only=$(validate_bool "$issues_only" "false")

    [[ -z "$providers" ]] && return 0

    IFS=',' read -ra provider_list <<< "$providers"
    local output_parts=()

    for provider in "${provider_list[@]}"; do
        provider="${provider#"${provider%%[![:space:]]*}"}"  # trim
        provider="${provider%"${provider##*[![:space:]]}"}"
        [[ -z "$provider" || -z "${CLOUD_PROVIDERS[$provider]}" ]] && continue

        IFS='|' read -r _ _ icon <<< "${CLOUD_PROVIDERS[$provider]}"
        local raw_status normalized symbol
        raw_status=$(get_provider_status "$provider")
        normalized=$(normalize_status "$raw_status")

        # Skip OK if issues_only
        [[ "$issues_only" == "true" && "$normalized" == "ok" ]] && continue

        symbol=$(get_status_symbol "$normalized")
        output_parts+=("${icon}${symbol}")
    done

    [[ ${#output_parts[@]} -eq 0 ]] && return 0

    join_with_separator "$separator" "${output_parts[@]}"
}

load_plugin() {
    # Check dependencies
    require_cmd curl || return 0

    # Use defer_plugin_load for network operations with lazy loading
    defer_plugin_load "$CACHE_KEY" cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_cloudstatus
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
