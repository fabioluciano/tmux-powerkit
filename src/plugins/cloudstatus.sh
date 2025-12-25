#!/usr/bin/env bash
# =============================================================================
# Plugin: cloudstatus
# Description: Monitor cloud provider status (StatusPage.io compatible APIs)
# Dependencies: curl (required), jq (optional)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Has issues to display
#   - inactive: All services operational (no issues)
#
# Health:
#   - ok: All monitored services operational
#   - warning: Minor or degraded issues
#   - error: Major or critical issues
#
# Context:
#   - operational: All services OK
#   - degraded: Minor issues
#   - incident: Major incident
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "cloudstatus"
    metadata_set "name" "Cloud Status"
    metadata_set "description" "Monitor cloud provider status"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    require_cmd "jq" 1  # Optional - improves JSON parsing
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display
    declare_option "providers" "string" "aws,gcp,azure,cloudflare,github" "Comma-separated list of providers"
    declare_option "separator" "string" " " "Separator between provider icons"
    declare_option "issues_only" "bool" "true" "Only show providers with issues"
    declare_option "timeout" "number" "5" "HTTP request timeout in seconds"

    # Icons (Material Design Icons)
    declare_option "icon" "icon" $'\U000F0163' "Default plugin icon (cloud-outline)"
    declare_option "icon_warning" "icon" $'\U000F0026' "Warning icon"
    declare_option "icon_error" "icon" $'\U000F0159' "Error icon"

    # Cache
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds (5 min)"
}

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
# Status Parsing Functions
# =============================================================================

_parse_statuspage() {
    local data="$1"

    if has_cmd jq; then
        printf '%s' "$data" | jq -r '.status.indicator // "operational"' 2>/dev/null
        return
    fi

    # Fallback: grep
    local indicator
    indicator=$(printf '%s' "$data" | grep -o '"indicator":"[^"]*"' | head -1 | cut -d'"' -f4)
    printf '%s' "${indicator:-operational}"
}

_parse_gcp() {
    local data="$1"

    if has_cmd jq; then
        local active
        active=$(printf '%s' "$data" | jq '[.[] | select(.end == null)] | length' 2>/dev/null)
        [[ "${active:-0}" -gt 0 ]] && printf 'major' || printf 'operational'
        return
    fi

    [[ "$data" == *'"end":null'* ]] && printf 'major' || printf 'operational'
}

_parse_aws() {
    local data="$1"
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

_parse_azure() {
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

    [[ "$data" == *'"health":"good"'* ]] && printf 'operational' || printf 'minor'
}

_parse_slack() {
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

_parse_heroku() {
    local data="$1"

    if has_cmd jq; then
        local issues
        issues=$(printf '%s' "$data" | jq '[.status[] | select(.status != "green")] | length' 2>/dev/null)
        [[ "${issues:-0}" -gt 0 ]] && printf 'minor' || printf 'operational'
        return
    fi

    [[ "$data" == *'"status":"green"'* ]] && printf 'operational' || printf 'minor'
}

_get_provider_status() {
    local provider_key="$1"
    local provider_config="${CLOUD_PROVIDERS[$provider_key]}"
    [[ -z "$provider_config" ]] && return 1

    local name api_url icon timeout
    IFS='|' read -r name api_url icon <<< "$provider_config"
    timeout=$(get_option "timeout")
    timeout="${timeout:-5}"

    local data
    data=$(safe_curl "$api_url" "$timeout" 2>/dev/null)
    [[ -z "$data" ]] && { printf 'unknown'; return; }

    # Provider-specific parsers
    case "$provider_key" in
        aws)    _parse_aws "$data" ;;
        gcp)    _parse_gcp "$data" ;;
        azure)  _parse_azure "$data" ;;
        slack)  _parse_slack "$data" ;;
        heroku) _parse_heroku "$data" ;;
        *)      _parse_statuspage "$data" ;;
    esac
}

_normalize_status() {
    case "$1" in
        none|operational|green|ok) printf 'ok' ;;
        minor|degraded*|yellow)    printf 'warning' ;;
        major|partial*|critical*)  printf 'error' ;;
        *)                         printf 'unknown' ;;
    esac
}

_get_status_indicator() {
    local status="$1"
    case "$status" in
        warning) printf '!' ;;
        error)   printf '!!' ;;
        *)       printf '' ;;
    esac
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local has_issues
    has_issues=$(plugin_data_get "has_issues")
    [[ "$has_issues" == "1" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local severity
    severity=$(plugin_data_get "severity")
    case "$severity" in
        error) printf 'error' ;;
        warning) printf 'warning' ;;
        *) printf 'ok' ;;
    esac
}

plugin_get_context() {
    local severity
    severity=$(plugin_data_get "severity")
    case "$severity" in
        error) printf 'incident' ;;
        warning) printf 'degraded' ;;
        *) printf 'operational' ;;
    esac
}

plugin_get_icon() {
    local health
    health=$(plugin_get_health)
    case "$health" in
        error) get_option "icon_error" ;;
        warning) get_option "icon_warning" ;;
        *) get_option "icon" ;;
    esac
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    has_cmd curl || return 0

    local providers issues_only timeout
    providers=$(get_option "providers")
    issues_only=$(get_option "issues_only")
    timeout=$(get_option "timeout")

    [[ -z "$providers" ]] && return 0

    local output_parts=()
    local has_error=false has_warning=false has_issues=false
    local provider raw_status normalized indicator icon

    IFS=',' read -ra provider_list <<< "$providers"

    for provider in "${provider_list[@]}"; do
        provider=$(trim "$provider")
        [[ -z "$provider" || -z "${CLOUD_PROVIDERS[$provider]}" ]] && continue

        IFS='|' read -r _ _ icon <<< "${CLOUD_PROVIDERS[$provider]}"
        raw_status=$(_get_provider_status "$provider")
        normalized=$(_normalize_status "$raw_status")

        # Skip OK if issues_only
        [[ "$issues_only" == "true" && "$normalized" == "ok" ]] && continue

        # Track severity
        [[ "$normalized" == "error" ]] && { has_error=true; has_issues=true; }
        [[ "$normalized" == "warning" ]] && { has_warning=true; has_issues=true; }

        # Add indicator for individual severity
        indicator=$(_get_status_indicator "$normalized")
        output_parts+=("${icon}${indicator}")
    done

    # Determine overall severity
    local severity="ok"
    [[ "$has_warning" == "true" ]] && severity="warning"
    [[ "$has_error" == "true" ]] && severity="error"

    plugin_data_set "severity" "$severity"
    plugin_data_set "has_issues" "$([[ "$has_issues" == "true" ]] && echo "1" || echo "0")"
    plugin_data_set "output" "$(join_with_separator ' ' "${output_parts[@]}")"
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local output separator
    output=$(plugin_data_get "output")
    separator=$(get_option "separator")

    [[ -z "$output" ]] && return 0

    # Replace default separator if needed
    if [[ "$separator" != " " ]]; then
        output="${output// /$separator}"
    fi

    printf '%s' "$output"
}
