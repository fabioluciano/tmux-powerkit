#!/usr/bin/env bash
# =============================================================================
# Helper: kubernetes_selector
# Description: Interactive selector for Kubernetes contexts and namespaces
# Type: popup
# =============================================================================

# Source helper base (handles all initialization)
# Using minimal bootstrap for faster startup
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "kubernetes_selector"
    helper_metadata_set "name" "Kubernetes Selector"
    helper_metadata_set "description" "Select Kubernetes contexts and namespaces"
    helper_metadata_set "type" "popup"
}

helper_get_actions() {
    echo "context - Select Kubernetes context (default)"
    echo "namespace - Select namespace in current context"
}

# =============================================================================
# Configuration
# =============================================================================

_conn_timeout=$(get_tmux_option "@powerkit_plugin_kubernetes_connectivity_timeout" "2")

# =============================================================================
# Connectivity Check
# =============================================================================

_check_cluster_connectivity() {
    # Use kubectl cluster-info which handles auth and self-signed certs properly
    kubectl cluster-info --request-timeout="${_conn_timeout}s" >/dev/null 2>&1
}

# =============================================================================
# Functions
# =============================================================================

_select_context() {
    local selected current_context
    current_context=$(kubectl config current-context 2>/dev/null)

    # Put current context first with marker, then others
    selected=$(kubectl config get-contexts -o name | \
        awk -v current="$current_context" '
            BEGIN { found="" }
            $0 == current { found = "* " $0; next }
            { others = others "  " $0 "\n" }
            END { if (found) print found; printf "%s", others }
        ' | \
        ui_filter --height 100% -h "Select Kubernetes Context (current: ${current_context})" | \
        sed 's/^[* ] //')

    if [[ -n "$selected" ]]; then
        kubectl config use-context "$selected"
        # Clear both internal kubernetes cache and plugin output cache
        cache_clear_prefix "kubernetes"
        cache_clear_prefix "plugin_kubernetes"
        tmux refresh-client -S
        toast "Switched to context: $selected" "info"
    fi
}

_select_namespace() {
    # Note: Connectivity is checked at plugin keybinding level before popup opens
    # This is a safety net in case helper is invoked directly
    if ! _check_cluster_connectivity; then
        toast "Cluster not reachable" "error"
        return 1
    fi

    local selected current_namespace namespaces
    current_namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
    if [[ -z "$current_namespace" ]]; then
        current_namespace="default"
    fi

    # Fetch namespaces with timeout
    namespaces=$(timeout "${_conn_timeout}s" kubectl get namespaces -o name 2>/dev/null | sed 's/namespace\///')
    if [[ -z "$namespaces" ]]; then
        toast "Failed to get namespaces" "error"
        return 1
    fi

    # Put current namespace first with marker, then others
    selected=$(printf '%s' "$namespaces" | \
        awk -v current="$current_namespace" '
            BEGIN { found="" }
            $0 == current { found = "* " $0; next }
            { others = others "  " $0 "\n" }
            END { if (found) print found; printf "%s", others }
        ' | \
        ui_filter --height 100% -h "Select Namespace (current: ${current_namespace})" | \
        sed 's/^[* ] //')

    if [[ -n "$selected" ]]; then
        kubectl config set-context --current --namespace="$selected"
        # Clear both internal kubernetes cache and plugin output cache
        cache_clear_prefix "kubernetes"
        cache_clear_prefix "plugin_kubernetes"
        tmux refresh-client -S
        toast "Switched to namespace: $selected" "info"
    fi
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-context}"

    case "$action" in
        context|"") _select_context ;;
        namespace)  _select_namespace ;;
        *)
            echo "Unknown action: $action" >&2
            return 1
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
