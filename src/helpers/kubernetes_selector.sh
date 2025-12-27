#!/usr/bin/env bash
# =============================================================================
# Helper: kubernetes_selector
# Description: Interactive selector for Kubernetes contexts and namespaces
# Usage: kubernetes_selector.sh [context|namespace]
# =============================================================================

set -uo pipefail

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export POWERKIT_ROOT

. "${POWERKIT_ROOT}/src/core/bootstrap.sh"
. "${POWERKIT_ROOT}/src/utils/ui_backend.sh"

# =============================================================================
# Configuration
# =============================================================================

_mode="${1:-context}"
_conn_timeout=$(get_tmux_option "@powerkit_plugin_kubernetes_connectivity_timeout" "2")

# =============================================================================
# Functions
# =============================================================================

_check_connectivity() {
    kubectl cluster-info --request-timeout="${_conn_timeout}s" &>/dev/null
}

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
        ui_filter -h "Select Kubernetes Context (current: ${current_context})" | \
        sed 's/^[* ] //')
    
    if [[ -n "$selected" ]]; then
        kubectl config use-context "$selected"
        # Clear both internal kubernetes cache and plugin output cache
        cache_clear_prefix "kubernetes"
        cache_clear_prefix "plugin_kubernetes"
        tmux refresh-client -S
        echo "✅ Switched to context: $selected"
    fi
}

_select_namespace() {
    if ! _check_connectivity; then
        echo "❌ Cluster not reachable"
        echo "Press any key to close..."
        read -n1
        exit 1
    fi
    
    local selected current_namespace
    current_namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
    [[ -z "$current_namespace" ]] && current_namespace="default"
    
    # Put current namespace first with marker, then others
    selected=$(kubectl get namespaces -o name | sed 's/namespace\///' | \
        awk -v current="$current_namespace" '
            BEGIN { found="" }
            $0 == current { found = "* " $0; next }
            { others = others "  " $0 "\n" }
            END { if (found) print found; printf "%s", others }
        ' | \
        ui_filter -h "Select Namespace (current: ${current_namespace})" | \
        sed 's/^[* ] //')
    
    if [[ -n "$selected" ]]; then
        kubectl config set-context --current --namespace="$selected"
        # Clear both internal kubernetes cache and plugin output cache
        cache_clear_prefix "kubernetes"
        cache_clear_prefix "plugin_kubernetes"
        tmux refresh-client -S
        echo "✅ Switched to namespace: $selected"
    fi
}

# =============================================================================
# Main
# =============================================================================

case "$_mode" in
    context)
        _select_context
        ;;
    namespace)
        _select_namespace
        ;;
    *)
        echo "Usage: $0 [context|namespace]"
        exit 1
        ;;
esac
