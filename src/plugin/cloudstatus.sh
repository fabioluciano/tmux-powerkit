#!/usr/bin/env bash
# =============================================================================
# Plugin: cloudstatus
# Description: Monitor cloud provider status (StatusPage.io compatible APIs)
# Type: conditional (hidden when no providers configured or all OK with issues_only)
# Dependencies: curl (required), jq (optional, for better JSON parsing)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    require_cmd "jq" 1  # Optional - improves JSON parsing
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display
    declare_option "providers" "string" "aws,gcp,azure,cloudflare,github" "Comma-separated list of providers (aws,gcp,azure,cloudflare,github,etc)"
    declare_option "separator" "string" " | " "Separator between provider status icons"
    declare_option "issues_only" "bool" "true" "Only show providers with issues (default: true)"
    declare_option "timeout" "number" "5" "HTTP request timeout in seconds"

    # Icons (Material Design Icons)
    declare_option "icon" "icon" $'\U000F0163' "Plugin icon (cloud-outline)"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Colors - Warning state
    declare_option "warning_accent_color" "color" "warning" "Background color for warning status"
    declare_option "warning_accent_color_icon" "color" "warning-strong" "Icon background color for warning status"

    # Colors - Critical state
    declare_option "critical_accent_color" "color" "error" "Background color for critical status"
    declare_option "critical_accent_color_icon" "color" "error-strong" "Icon background color for critical status"

    # Cache
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}

plugin_init "cloudstatus"

# =============================================================================
# Provider Configuration (StatusPage.io API compatible)
# =============================================================================

# Material Design Icons (pre-evaluated)
_ICON_AWS=$'\U000F0E0F'
_ICON_GCP=$'\U000F0B20'
_ICON_AZURE=$'\U000F0805'
_ICON_CLOUD=$'\U000F0163'
_ICON_WEB=$'\U000F0547'
_ICON_GITHUB=$'\U000F059F'
_ICON_GITLAB=$'\U000F0BA3'
_ICON_BITBUCKET=$'\U000F0171'
_ICON_NPM=$'\U000F06F7'
_ICON_DOCKER=$'\U000F0868'
_ICON_DISCORD=$'\U000F01A4'
_ICON_SLACK=$'\U000F0540'
_ICON_VIDEO=$'\U000F0F5E'
_ICON_DATABASE=$'\U000F0209'
_ICON_LEAF=$'\U000F0517'
_ICON_CARD=$'\U000F0176'
_ICON_SHIELD=$'\U000F0A12'
_ICON_BELL=$'\U000F0F23'

# Format: name|api_url|icon
declare -A CLOUD_PROVIDERS=(
    # Major Cloud Providers
    ["aws"]="AWS|https://health.aws.amazon.com/health/status|${_ICON_AWS}"
    ["gcp"]="GCP|https://status.cloud.google.com/incidents.json|${_ICON_GCP}"
    ["azure"]="Azure|https://status.azure.com/api/v1/status|${_ICON_AZURE}"

    # CDN & Infrastructure
    ["cloudflare"]="CF|https://www.cloudflarestatus.com/api/v2/status.json|${_ICON_CLOUD}"
    ["fastly"]="Fastly|https://status.fastly.com/api/v2/status.json|${_ICON_CLOUD}"
    ["akamai"]="Akamai|https://www.akamaistatus.com/api/v2/status.json|${_ICON_CLOUD}"

    # Platform as a Service
    ["vercel"]="Vercel|https://www.vercel-status.com/api/v2/status.json|${_ICON_WEB}"
    ["netlify"]="Netlify|https://www.netlifystatus.com/api/v2/status.json|${_ICON_WEB}"
    ["heroku"]="Heroku|https://status.heroku.com/api/v4/current-status|${_ICON_WEB}"
    ["digitalocean"]="DO|https://status.digitalocean.com/api/v2/status.json|${_ICON_CLOUD}"
    ["linode"]="Linode|https://status.linode.com/api/v2/status.json|${_ICON_CLOUD}"

    # Development Tools
    ["github"]="GitHub|https://www.githubstatus.com/api/v2/status.json|${_ICON_GITHUB}"
    ["gitlab"]="GitLab|https://status.gitlab.com/api/v2/status.json|${_ICON_GITLAB}"
    ["bitbucket"]="BB|https://bitbucket.status.atlassian.com/api/v2/status.json|${_ICON_BITBUCKET}"
    ["npm"]="npm|https://status.npmjs.org/api/v2/status.json|${_ICON_NPM}"
    ["docker"]="Docker|https://status.docker.com/api/v2/status.json|${_ICON_DOCKER}"

    # CI/CD
    ["circleci"]="CircleCI|https://status.circleci.com/api/v2/status.json|${_ICON_CLOUD}"
    ["travisci"]="Travis|https://www.traviscistatus.com/api/v2/status.json|${_ICON_CLOUD}"

    # Communication & Collaboration
    ["discord"]="Discord|https://discordstatus.com/api/v2/status.json|${_ICON_DISCORD}"
    ["slack"]="Slack|https://status.slack.com/api/v2.0.0/current|${_ICON_SLACK}"
    ["zoom"]="Zoom|https://status.zoom.us/api/v2/status.json|${_ICON_VIDEO}"

    # Databases & Services
    ["mongodb"]="MongoDB|https://status.mongodb.com/api/v2/status.json|${_ICON_LEAF}"
    ["redis"]="Redis|https://status.redis.com/api/v2/status.json|${_ICON_DATABASE}"
    ["datadog"]="Datadog|https://status.datadoghq.com/api/v2/status.json|${_ICON_DATABASE}"

    # Payment & Auth
    ["stripe"]="Stripe|https://status.stripe.com/api/v2/status.json|${_ICON_CARD}"
    ["auth0"]="Auth0|https://status.auth0.com/api/v2/status.json|${_ICON_SHIELD}"
    ["okta"]="Okta|https://status.okta.com/api/v2/status.json|${_ICON_SHIELD}"

    # Monitoring
    ["pagerduty"]="PD|https://status.pagerduty.com/api/v2/status.json|${_ICON_BELL}"
    ["newrelic"]="NR|https://status.newrelic.com/api/v2/status.json|${_ICON_BELL}"
)

# =============================================================================
# Status Functions
# =============================================================================

fetch_status() {
    local url="$1"
    local timeout
    timeout=$(get_option "timeout")
    timeout=$(validate_range "$timeout" 1 30 5)

    safe_curl "$url" "$timeout"
}

parse_statuspage() {
    local data="$1"

    # Try jq first (most reliable)
    if has_cmd jq; then
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

    if has_cmd jq; then
        local active
        active=$(printf '%s' "$data" | jq '[.[] | select(.end == null)] | length' 2>/dev/null)
        [[ "${active:-0}" -gt 0 ]] && printf 'major' || printf 'operational'
        return
    fi

    # Fallback
    [[ "$data" == *'"end":null'* ]] && printf 'major' || printf 'operational'
}

parse_aws() {
    local data="$1"
    # AWS Health Dashboard returns HTML, check for service health indicators
    # If page contains "Service is operating normally" = OK
    # Otherwise check for incident markers
    if [[ "$data" == *"Service is operating normally"* ]] || [[ "$data" == *"All services are operating normally"* ]]; then
        printf 'operational'
    elif [[ "$data" == *"Service disruption"* ]] || [[ "$data" == *"Informational message"* ]]; then
        printf 'major'
    elif [[ "$data" == *"Performance issues"* ]]; then
        printf 'minor'
    else
        printf 'operational'
    fi
}

parse_azure() {
    local data="$1"

    if has_cmd jq; then
        local status
        status=$(printf '%s' "$data" | jq -r '.status.health // "good"' 2>/dev/null)
        case "$status" in
            good|healthy) printf 'operational' ;;
            advisory|degraded) printf 'minor' ;;
            critical|unhealthy) printf 'major' ;;
            *) printf 'operational' ;;
        esac
        return
    fi

    # Fallback
    [[ "$data" == *'"health":"good"'* ]] && printf 'operational' || printf 'minor'
}

parse_slack() {
    local data="$1"

    if has_cmd jq; then
        local status
        status=$(printf '%s' "$data" | jq -r '.status // "ok"' 2>/dev/null)
        case "$status" in
            ok|active) printf 'operational' ;;
            notice) printf 'minor' ;;
            incident|outage) printf 'major' ;;
            *) printf 'operational' ;;
        esac
        return
    fi

    [[ "$data" == *'"status":"ok"'* ]] && printf 'operational' || printf 'minor'
}

parse_heroku() {
    local data="$1"

    if has_cmd jq; then
        local issues
        issues=$(printf '%s' "$data" | jq '[.status[] | select(.status != "green")] | length' 2>/dev/null)
        [[ "${issues:-0}" -gt 0 ]] && printf 'minor' || printf 'operational'
        return
    fi

    [[ "$data" == *'"status":"green"'* ]] && printf 'operational' || printf 'minor'
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

    # Provider-specific parsers
    case "$provider_key" in
        aws)    parse_aws "$data" ;;
        gcp)    parse_gcp "$data" ;;
        azure)  parse_azure "$data" ;;
        slack)  parse_slack "$data" ;;
        heroku) parse_heroku "$data" ;;
        *)      parse_statuspage "$data" ;;  # StatusPage.io format (most providers)
    esac
}

normalize_status() {
    case "$1" in
        none|operational|green|ok) printf 'ok' ;;
        minor|degraded*|yellow)    printf 'warning' ;;
        major|partial*|critical*)  printf 'error' ;;
        *)                         printf 'unknown' ;;
    esac
}

get_status_indicator() {
    local status="$1"
    case "$status" in
        warning) printf '!' ;;   # Warning indicator
        error)   printf '!!' ;;  # Critical indicator (double exclamation)
        *)       printf '' ;;    # No indicator for OK/unknown
    esac
}

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    [[ -z "$content" ]] && { build_display_info "0" "" "" ""; return; }

    local accent="" accent_icon="" icon=""
    icon=$(get_option "icon")

    # Read cached value to check severity prefix (content passed here has prefix stripped)
    local cached
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null) || cached=""

    # Check severity prefix (E: = error, W: = warning)
    if [[ "$cached" == E:* ]]; then
        accent=$(get_option "critical_accent_color")
        accent_icon=$(get_option "critical_accent_color_icon")
    elif [[ "$cached" == W:* ]]; then
        accent=$(get_option "warning_accent_color")
        accent_icon=$(get_option "warning_accent_color_icon")
    else
        # No issues - use default colors
        accent=$(get_option "accent_color")
        accent_icon=$(get_option "accent_color_icon")
    fi

    build_display_info "1" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Logic
# =============================================================================

_compute_cloudstatus() {
    local providers separator issues_only
    providers=$(get_option "providers")
    separator=$(get_option "separator")
    issues_only=$(get_option "issues_only")
    issues_only=$(validate_bool "$issues_only" "true")

    [[ -z "$providers" ]] && return 0

    IFS=',' read -ra provider_list <<< "$providers"
    local output_parts=()
    local has_error=false has_warning=false

    for provider in "${provider_list[@]}"; do
        provider="${provider#"${provider%%[![:space:]]*}"}"  # trim
        provider="${provider%"${provider##*[![:space:]]}"}"
        [[ -z "$provider" || -z "${CLOUD_PROVIDERS[$provider]}" ]] && continue

        IFS='|' read -r _ _ icon <<< "${CLOUD_PROVIDERS[$provider]}"
        local raw_status normalized indicator
        raw_status=$(get_provider_status "$provider")
        normalized=$(normalize_status "$raw_status")

        # Skip OK if issues_only
        [[ "$issues_only" == "true" && "$normalized" == "ok" ]] && continue

        # Track severity for colors
        [[ "$normalized" == "error" ]] && has_error=true
        [[ "$normalized" == "warning" ]] && has_warning=true

        # Add indicator to show individual severity
        indicator=$(get_status_indicator "$normalized")
        output_parts+=("${icon}${indicator}")
    done

    [[ ${#output_parts[@]} -eq 0 ]] && return 0

    # Prefix with severity marker for plugin_get_display_info
    local prefix=""
    [[ "$has_error" == "true" ]] && prefix="E:"
    [[ "$has_error" != "true" && "$has_warning" == "true" ]] && prefix="W:"

    printf '%s%s' "$prefix" "$(join_with_separator "$separator" "${output_parts[@]}")"
}

load_plugin() {
    # Runtime check - dependency contract handles notification
    has_cmd curl || return 0

    local result
    result=$(cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_cloudstatus)

    # Remove severity prefix (E: or W:) for display
    result="${result#E:}"
    result="${result#W:}"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
