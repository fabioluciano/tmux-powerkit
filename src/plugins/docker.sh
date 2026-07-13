#!/usr/bin/env bash
# =============================================================================
# Plugin: docker
# Description: Display Docker or Podman container status
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

plugin_get_metadata() {
    metadata_set "id" "docker"
    metadata_set "name" "Containers"
    metadata_set "description" "Display Docker or Podman container status"
}

plugin_declare_options() {
    declare_option "runtime" "enum" "auto" "Container runtime: auto, docker, or podman"
    declare_option "show_stopped" "bool" "false" "Include stopped containers"
    declare_option "show_when_empty" "bool" "false" "Show when no containers are running"
    declare_option "icon" "icon" $'\U000F0868' "Docker or Podman icon"
    declare_option "icon_warning" "icon" $'\U000F002A' "Icon when containers need attention"
    declare_option "cache_ttl" "number" "10" "Cache duration in seconds"
}

_container_runtime() {
    local configured
    configured=$(get_option "runtime")

    case "$configured" in
    docker | podman)
        has_cmd "$configured" && printf '%s' "$configured"
        ;;
    auto)
        if has_cmd docker; then
            printf 'docker'
        elif has_cmd podman; then
            printf 'podman'
        fi
        ;;
    esac
}

_container_timeout() {
    if has_cmd timeout; then
        timeout 3 "$@"
    elif has_cmd gtimeout; then
        gtimeout 3 "$@"
    else
        "$@"
    fi
}

plugin_check_dependencies() {
    [[ -n "$(_container_runtime)" ]]
}

plugin_should_be_active() {
    [[ -n "$(_container_runtime)" ]]
}

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local available running show_when_empty
    available=$(plugin_data_get "available")
    running=$(plugin_data_get "running")
    show_when_empty=$(get_option "show_when_empty")

    [[ "$available" == "1" ]] || {
        printf 'inactive'
        return
    }
    [[ "$running" != "0" || "$show_when_empty" == "true" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local unhealthy stopped show_stopped
    unhealthy=$(plugin_data_get "unhealthy")
    stopped=$(plugin_data_get "stopped")
    show_stopped=$(get_option "show_stopped")

    ((unhealthy > 0)) && {
        printf 'error'
        return
    }
    [[ "$show_stopped" == "true" ]] && ((stopped > 0)) && {
        printf 'warning'
        return
    }
    printf 'good'
}

plugin_get_context() {
    local runtime
    runtime=$(plugin_data_get "runtime")
    printf '%s' "$runtime"
}

plugin_get_icon() {
    local unhealthy stopped show_stopped
    unhealthy=$(plugin_data_get "unhealthy")
    stopped=$(plugin_data_get "stopped")
    show_stopped=$(get_option "show_stopped")

    ((unhealthy > 0)) || { [[ "$show_stopped" == "true" ]] && ((stopped > 0)); } && {
        get_option "icon_warning"
        return
    }
    get_option "icon"
}

plugin_collect() {
    local runtime running total unhealthy stopped
    runtime=$(_container_runtime)
    [[ -n "$runtime" ]] || {
        plugin_data_set "available" "0"
        return 0
    }

    if ! _container_timeout "$runtime" info >/dev/null 2>&1; then
        plugin_data_set "available" "0"
        return 1
    fi

    running=$(_container_timeout "$runtime" ps -q 2>/dev/null | wc -l | tr -d ' ')
    total=$(_container_timeout "$runtime" ps -aq 2>/dev/null | wc -l | tr -d ' ')
    unhealthy=$(_container_timeout "$runtime" ps --filter 'health=unhealthy' -q 2>/dev/null | wc -l | tr -d ' ')
    [[ "$running" =~ ^[0-9]+$ && "$total" =~ ^[0-9]+$ && "$unhealthy" =~ ^[0-9]+$ ]] || return 1
    stopped=$((total - running))

    plugin_data_set "available" "1"
    plugin_data_set "runtime" "$runtime"
    plugin_data_set "running" "${running:-0}"
    plugin_data_set "stopped" "${stopped:-0}"
    plugin_data_set "unhealthy" "${unhealthy:-0}"
}

plugin_render() {
    local running stopped show_stopped
    running=$(plugin_data_get "running")
    stopped=$(plugin_data_get "stopped")
    show_stopped=$(get_option "show_stopped")

    if [[ "$show_stopped" == "true" ]] && ((stopped > 0)); then
        printf '%s running, %s stopped' "${running:-0}" "$stopped"
    else
        printf '%s running' "${running:-0}"
    fi
}
