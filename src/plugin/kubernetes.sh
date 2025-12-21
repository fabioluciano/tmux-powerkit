#!/usr/bin/env bash
# =============================================================================
# Plugin: kubernetes
# Description: Display current Kubernetes context and namespace
# Dependencies: kubectl (optional, reads from kubeconfig directly)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_cmd "kubectl" || return 1
    require_cmd "fzf" 1  # Optional (for selectors)
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "display_mode" "string" "connected" "Display mode (connected|always)"
    declare_option "show_namespace" "bool" "false" "Show namespace in display"

    # Connectivity
    declare_option "connectivity_timeout" "number" "2" "Cluster connectivity timeout in seconds"
    declare_option "connectivity_cache_ttl" "number" "120" "Connectivity check cache duration"

    # Icons
    declare_option "icon" "icon" $'\ue81d' "Plugin icon"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Keybindings - Context selector
    declare_option "context_selector_key" "key" "C-g" "Keybinding for context selector"
    declare_option "context_selector_width" "string" "50%" "Context selector popup width"
    declare_option "context_selector_height" "string" "50%" "Context selector popup height"

    # Keybindings - Namespace selector
    declare_option "namespace_selector_key" "key" "C-s" "Keybinding for namespace selector"
    declare_option "namespace_selector_width" "string" "50%" "Namespace selector popup width"
    declare_option "namespace_selector_height" "string" "50%" "Namespace selector popup height"

    # Cache
    declare_option "cache_ttl" "number" "60" "Cache duration in seconds"
}

plugin_init "kubernetes"

# =============================================================================
# Main Logic
# =============================================================================

# Check if kubeconfig changed since last cache and invalidate if needed
# This ensures namespace/context changes outside PowerKit are detected
_check_kubeconfig_changed() {
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

_get_current_context() {
    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    [[ ! -f "$kubeconfig" ]] && return 1
    awk '/^current-context:/ {print $2; exit}' "$kubeconfig" 2>/dev/null
}

_get_namespace_for_context() {
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
_check_k8s_connectivity() {
    local timeout
    timeout=$(get_option "connectivity_timeout")

    # Try to connect to the cluster with timeout
    if has_cmd kubectl; then
        kubectl cluster-info --request-timeout="${timeout}s" &>/dev/null
        return $?
    fi
    return 1
}

# Get cached connectivity status
_get_cached_connectivity() {
    local conn_cache_key="${CACHE_KEY}_connectivity"
    local conn_ttl
    conn_ttl=$(get_option "connectivity_cache_ttl")

    local cached
    if cached=$(cache_get "$conn_cache_key" "$conn_ttl"); then
        [[ "$cached" == "1" ]] && return 0 || return 1
    fi

    if _check_k8s_connectivity; then
        cache_set "$conn_cache_key" "1"
        return 0
    else
        cache_set "$conn_cache_key" "0"
        return 1
    fi
}

_get_k8s_info() {
    local context
    context=$(_get_current_context) || return 1
    [[ -z "$context" ]] && return 1

    # Check display mode
    local display_mode
    display_mode=$(get_option "display_mode")

    # If display_mode is "connected", check connectivity
    if [[ "$display_mode" == "connected" ]]; then
        _get_cached_connectivity || return 1
    fi

    # Shorten context name (remove user@ and cluster: prefixes)
    local display="${context##*@}"
    display="${display##*:}"

    # Add namespace if configured
    local show_ns
    show_ns=$(get_option "show_namespace")

    if [[ "$show_ns" == "true" ]]; then
        local ns
        ns=$(_get_namespace_for_context "$context")
        display+="/${ns:-default}"
    fi

    echo "$display"
}

# =============================================================================
# Keybinding Setup
# =============================================================================

setup_keybindings() {
    # Check prerequisites before setting up keybindings
    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"

    # Don't set up keybindings if:
    # 1. kubectl is not installed
    # 2. kubeconfig file doesn't exist
    # 3. No contexts are available
    has_cmd kubectl || return 0
    [[ ! -f "$kubeconfig" ]] && return 0

    # Check if there are any contexts configured
    local context_count
    context_count=$(kubectl config get-contexts -o name 2>/dev/null | wc -l)
    [[ "$context_count" -eq 0 ]] && return 0

    local ctx_key ns_key ctx_w ctx_h ns_w ns_h cache_dir conn_timeout

    ctx_key=$(get_option "context_selector_key")
    ctx_w=$(get_option "context_selector_width")
    ctx_h=$(get_option "context_selector_height")

    ns_key=$(get_option "namespace_selector_key")
    ns_w=$(get_option "namespace_selector_width")
    ns_h=$(get_option "namespace_selector_height")

    conn_timeout=$(get_option "connectivity_timeout")

    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit"

    # Context selector - can switch context even if current cluster is down
    [[ -n "$ctx_key" ]] && tmux bind-key "$ctx_key" display-popup -E -w "$ctx_w" -h "$ctx_h" \
        'selected=$(kubectl config get-contexts -o name | fzf --header="Select Kubernetes Context" --reverse) && [ -n "$selected" ] && kubectl config use-context "$selected" && rm -f '"'${cache_dir}/kubernetes.cache'"' '"'${cache_dir}/kubernetes_connectivity.cache'"' && tmux refresh-client -S'

    # Namespace selector - requires cluster connectivity (can't list namespaces if cluster is down)
    [[ -n "$ns_key" ]] && tmux bind-key "$ns_key" display-popup -E -w "$ns_w" -h "$ns_h" \
        'if ! kubectl cluster-info --request-timeout='"${conn_timeout}"'s &>/dev/null; then echo "❌ Cluster not reachable. Press any key to close."; read -n1; exit 1; fi; selected=$(kubectl get namespaces -o name | sed "s/namespace\///" | fzf --header="Select Namespace" --reverse) && [ -n "$selected" ] && kubectl config set-context --current --namespace="$selected" && rm -f '"'${cache_dir}/kubernetes.cache'"' && tmux refresh-client -S'
}

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -n "$content" ]] && echo "1:::" || echo "0:::"
}

load_plugin() {
    # Check if kubeconfig changed (invalidates cache if needed)
    _check_kubeconfig_changed

    local cached
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL") && { printf '%s' "$cached"; return 0; }

    local result
    result=$(_get_k8s_info) || return 0
    
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
