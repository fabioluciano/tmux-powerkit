#!/usr/bin/env bash
# =============================================================================
# Plugin: kubernetes
# Description: Display current Kubernetes context and namespace
# Dependencies: kubectl (optional, reads from kubeconfig directly)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "kubernetes"

# =============================================================================
# Kubernetes Functions
# =============================================================================

# Check if kubeconfig changed since last cache and invalidate if needed
# This ensures namespace/context changes outside PowerKit are detected
check_kubeconfig_changed() {
    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    local mtime_cache="${CACHE_DIR}/kubernetes_mtime.cache"
    
    [[ ! -f "$kubeconfig" ]] && return 0
    
    local current_mtime
    if is_macos; then
        current_mtime=$(stat -f "%m" "$kubeconfig" 2>/dev/null) || return 0
    else
        current_mtime=$(stat -c "%Y" "$kubeconfig" 2>/dev/null) || return 0
    fi
    
    local cached_mtime=""
    [[ -f "$mtime_cache" ]] && cached_mtime=$(<"$mtime_cache")
    
    if [[ "$current_mtime" != "$cached_mtime" ]]; then
        # Kubeconfig changed - invalidate kubernetes cache
        cache_invalidate "$CACHE_KEY"
        cache_invalidate "${CACHE_KEY}_connectivity"
        printf '%s' "$current_mtime" > "$mtime_cache"
    fi
}

get_current_context() {
    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    [[ ! -f "$kubeconfig" ]] && return 1
    awk '/^current-context:/ {print $2; exit}' "$kubeconfig" 2>/dev/null
}

get_namespace_for_context() {
    local context="$1"
    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    
    # Parse YAML to find namespace for the given context
    # Format:
    # contexts:
    # - context:
    #     namespace: xxx
    #   name: context-name
    awk -v ctx="$context" '
        /^contexts:/ { in_contexts=1; next }
        in_contexts && /^[^ -]/ { in_contexts=0 }
        in_contexts && /^- context:/ { in_context_block=1; ns=""; next }
        in_context_block && /^    namespace:/ { ns=$2; next }
        in_context_block && /^  name:/ && $2 == ctx { print ns; exit }
        in_context_block && /^- / { in_context_block=0; ns="" }
    ' "$kubeconfig" 2>/dev/null
}

# Check if kubernetes cluster is reachable
check_k8s_connectivity() {
    local timeout
    timeout=$(get_tmux_option "@powerkit_plugin_kubernetes_connectivity_timeout" "$POWERKIT_PLUGIN_KUBERNETES_CONNECTIVITY_TIMEOUT")
    
    # Try to connect to the cluster with timeout
    if command -v kubectl >/dev/null 2>&1; then
        kubectl cluster-info --request-timeout="${timeout}s" &>/dev/null
        return $?
    fi
    return 1
}

# Get cached connectivity status
get_cached_connectivity() {
    local conn_cache_key="${CACHE_KEY}_connectivity"
    local conn_ttl
    conn_ttl=$(get_tmux_option "@powerkit_plugin_kubernetes_connectivity_cache_ttl" "$POWERKIT_PLUGIN_KUBERNETES_CONNECTIVITY_CACHE_TTL")
    
    local cached
    if cached=$(cache_get "$conn_cache_key" "$conn_ttl"); then
        [[ "$cached" == "1" ]] && return 0 || return 1
    fi
    
    if check_k8s_connectivity; then
        cache_set "$conn_cache_key" "1"
        return 0
    else
        cache_set "$conn_cache_key" "0"
        return 1
    fi
}

get_k8s_info() {
    local context
    context=$(get_current_context) || return 1
    [[ -z "$context" ]] && return 1
    
    # Check display mode
    local display_mode
    display_mode=$(get_tmux_option "@powerkit_plugin_kubernetes_display_mode" "$POWERKIT_PLUGIN_KUBERNETES_DISPLAY_MODE")
    
    # If display_mode is "connected", check connectivity
    if [[ "$display_mode" == "connected" ]]; then
        get_cached_connectivity || return 1
    fi
    
    # Shorten context name (remove user@ and cluster: prefixes)
    local display="${context##*@}"
    display="${display##*:}"
    
    # Add namespace if configured
    local show_ns
    show_ns=$(get_tmux_option "@powerkit_plugin_kubernetes_show_namespace" "$POWERKIT_PLUGIN_KUBERNETES_SHOW_NAMESPACE")
    
    if [[ "$show_ns" == "true" ]]; then
        local ns
        ns=$(get_namespace_for_context "$context")
        display+="/${ns:-default}"
    fi
    
    echo "$display"
}

# =============================================================================
# Keybinding Setup
# =============================================================================

setup_keybindings() {
    local ctx_key ns_key ctx_w ctx_h ns_w ns_h cache_dir conn_timeout
    
    ctx_key=$(get_tmux_option "@powerkit_plugin_kubernetes_context_selector_key" "$POWERKIT_PLUGIN_KUBERNETES_CONTEXT_SELECTOR_KEY")
    ctx_w=$(get_tmux_option "@powerkit_plugin_kubernetes_context_selector_width" "$POWERKIT_PLUGIN_KUBERNETES_CONTEXT_SELECTOR_WIDTH")
    ctx_h=$(get_tmux_option "@powerkit_plugin_kubernetes_context_selector_height" "$POWERKIT_PLUGIN_KUBERNETES_CONTEXT_SELECTOR_HEIGHT")
    
    ns_key=$(get_tmux_option "@powerkit_plugin_kubernetes_namespace_selector_key" "$POWERKIT_PLUGIN_KUBERNETES_NAMESPACE_SELECTOR_KEY")
    ns_w=$(get_tmux_option "@powerkit_plugin_kubernetes_namespace_selector_width" "$POWERKIT_PLUGIN_KUBERNETES_NAMESPACE_SELECTOR_WIDTH")
    ns_h=$(get_tmux_option "@powerkit_plugin_kubernetes_namespace_selector_height" "$POWERKIT_PLUGIN_KUBERNETES_NAMESPACE_SELECTOR_HEIGHT")
    
    conn_timeout=$(get_tmux_option "@powerkit_plugin_kubernetes_connectivity_timeout" "$POWERKIT_PLUGIN_KUBERNETES_CONNECTIVITY_TIMEOUT")
    
    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit"
    
    # Context selector - can switch context even if current cluster is down
    [[ -n "$ctx_key" ]] && tmux bind-key "$ctx_key" display-popup -E -w "$ctx_w" -h "$ctx_h" \
        'selected=$(kubectl config get-contexts -o name | fzf --header="Select Kubernetes Context" --reverse) && [ -n "$selected" ] && kubectl config use-context "$selected" && rm -f '"'${cache_dir}/kubernetes.cache'"' '"'${cache_dir}/kubernetes_connectivity.cache'"' && tmux refresh-client -S'
    
    # Namespace selector - requires cluster connectivity (can't list namespaces if cluster is down)
    [[ -n "$ns_key" ]] && tmux bind-key "$ns_key" display-popup -E -w "$ns_w" -h "$ns_h" \
        'if ! kubectl cluster-info --request-timeout='"${conn_timeout}"'s &>/dev/null; then echo "❌ Cluster not reachable. Press any key to close."; read -n1; exit 1; fi; selected=$(kubectl get namespaces -o name | sed "s/namespace\///" | fzf --header="Select Namespace" --reverse) && [ -n "$selected" ] && kubectl config set-context --current --namespace="$selected" && rm -f '"'${cache_dir}/kubernetes.cache'"' && tmux refresh-client -S'
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -n "$content" ]] && echo "1:::" || echo "0:::"
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    # Check if kubeconfig changed (invalidates cache if needed)
    check_kubeconfig_changed
    
    local cached
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL") && { printf '%s' "$cached"; return 0; }
    
    local result
    result=$(get_k8s_info) || return 0
    
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
