#!/usr/bin/env bash
# =============================================================================
# Plugin: kubernetes
# Description: Display current Kubernetes context and namespace
# Dependencies: kubectl (optional for basic info - reads kubeconfig directly)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "kubernetes"
    metadata_set "name" "Kubernetes"
    metadata_set "description" "Display Kubernetes context and namespace"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    # kubectl is optional - we can read kubeconfig directly
    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    [[ -f "$kubeconfig" ]] || require_cmd "kubectl" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "display_mode" "string" "connected" "Display mode: connected (only when cluster reachable) or always"
    declare_option "show_context" "bool" "true" "Show context name"
    declare_option "show_namespace" "bool" "true" "Show namespace"
    declare_option "separator" "string" "/" "Separator between context and namespace"

    # Connectivity options
    declare_option "connectivity_timeout" "number" "2" "Cluster connectivity timeout in seconds"
    declare_option "connectivity_cache_ttl" "number" "120" "Connectivity check cache duration"

    # Production warning
    declare_option "warn_on_prod" "bool" "true" "Show warning health when in production context"
    declare_option "prod_keywords" "string" "prod,production,prd" "Comma-separated production keywords"

    # Icons
    declare_option "icon" "icon" $'\U000F10FE' "Plugin icon"

    # Keybindings
    declare_option "keybinding_context" "string" "" "Keybinding for context selector"
    declare_option "keybinding_namespace" "string" "" "Keybinding for namespace selector"
    declare_option "popup_width" "string" "50%" "Popup width"
    declare_option "popup_height" "string" "50%" "Popup height"

    # Cache - context/namespace rarely changes during a session
    declare_option "cache_ttl" "number" "60" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local context=$(plugin_data_get "context")
    local connected=$(plugin_data_get "connected")
    local display_mode=$(get_option "display_mode")
    
    if [[ -z "$context" ]]; then
        printf 'inactive'
    elif [[ "$display_mode" == "connected" && "$connected" != "1" ]]; then
        printf 'degraded'
    else
        printf 'active'
    fi
}

plugin_get_health() {
    local context=$(plugin_data_get "context")
    local connected=$(plugin_data_get "connected")
    local warn_on_prod=$(get_option "warn_on_prod")
    local prod_keywords=$(get_option "prod_keywords")
    
    # Check if disconnected
    if [[ "$connected" == "0" ]]; then
        printf 'warning'
        return
    fi
    
    # Check if in production context
    if [[ "$warn_on_prod" == "true" && -n "$context" ]]; then
        local IFS=','
        for keyword in $prod_keywords; do
            if [[ "${context,,}" == *"${keyword,,}"* ]]; then
                printf 'error'
                return
            fi
        done
    fi
    
    printf 'ok'
}

plugin_get_context() {
    local context=$(plugin_data_get "context")
    local connected=$(plugin_data_get "connected")
    local prod_keywords=$(get_option "prod_keywords")
    
    if [[ -z "$context" ]]; then
        printf 'no_context'
        return
    fi
    
    if [[ "$connected" == "0" ]]; then
        printf 'disconnected'
        return
    fi
    
    # Detect environment type from context name
    local IFS=','
    for keyword in $prod_keywords; do
        if [[ "${context,,}" == *"${keyword,,}"* ]]; then
            printf 'production'
            return
        fi
    done
    
    if [[ "${context,,}" == *stag* || "${context,,}" == *staging* ]]; then
        printf 'staging'
    elif [[ "${context,,}" == *dev* || "${context,,}" == *development* ]]; then
        printf 'development'
    elif [[ "${context,,}" == *local* || "${context,,}" == *minikube* || "${context,,}" == *docker-desktop* || "${context,,}" == *kind* || "${context,,}" == *k3* ]]; then
        printf 'local'
    else
        printf 'connected'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Kubeconfig Handling
# =============================================================================

_get_kubeconfig_path() {
    printf '%s' "${KUBECONFIG:-$HOME/.kube/config}"
}

# Check if kubeconfig changed since last cache
_check_kubeconfig_changed() {
    local kubeconfig=$(_get_kubeconfig_path)
    local mtime_cache="${POWERKIT_CACHE_DIR:-/tmp}/kubernetes_mtime.cache"
    
    [[ ! -f "$kubeconfig" ]] && return 1
    
    local current_mtime
    if is_macos; then
        current_mtime=$(stat -f "%m" "$kubeconfig" 2>/dev/null) || return 1
    else
        current_mtime=$(stat -c "%Y" "$kubeconfig" 2>/dev/null) || return 1
    fi
    
    local cached_mtime=""
    [[ -f "$mtime_cache" ]] && cached_mtime=$(<"$mtime_cache")
    
    if [[ "$current_mtime" != "$cached_mtime" ]]; then
        printf '%s' "$current_mtime" > "$mtime_cache"
        return 0  # Changed
    fi
    
    return 1  # Not changed
}

# Get current context directly from kubeconfig (no kubectl required)
_get_current_context_from_file() {
    local kubeconfig=$(_get_kubeconfig_path)
    [[ ! -f "$kubeconfig" ]] && return 1
    awk '/^current-context:/ {print $2; exit}' "$kubeconfig" 2>/dev/null
}

# Get namespace for context from kubeconfig
_get_namespace_from_file() {
    local context="$1"
    local kubeconfig=$(_get_kubeconfig_path)
    
    awk -v ctx="$context" '
        /^contexts:/ { in_contexts=1; next }
        in_contexts && /^[^ -]/ { in_contexts=0 }
        in_contexts && /^- context:/ { in_context_block=1; ns=""; next }
        in_context_block && /^    namespace:/ { ns=$2; next }
        in_context_block && /^  name:/ && $2 == ctx { print ns; exit }
        in_context_block && /^- / { in_context_block=0; ns="" }
    ' "$kubeconfig" 2>/dev/null
}

# =============================================================================
# Connectivity Check
# =============================================================================

_check_k8s_connectivity() {
    local timeout=$(get_option "connectivity_timeout")
    
    if has_cmd kubectl; then
        kubectl cluster-info --request-timeout="${timeout}s" &>/dev/null
        return $?
    fi
    
    return 1
}

_get_cached_connectivity() {
    local conn_cache="${POWERKIT_CACHE_DIR:-/tmp}/kubernetes_connectivity.cache"
    local conn_ttl=$(get_option "connectivity_cache_ttl")
    
    # Check if cache exists and is fresh
    if [[ -f "$conn_cache" ]]; then
        local now=$(date +%s)
        local cache_mtime
        if is_macos; then
            cache_mtime=$(stat -f "%m" "$conn_cache" 2>/dev/null || echo 0)
        else
            cache_mtime=$(stat -c "%Y" "$conn_cache" 2>/dev/null || echo 0)
        fi
        local cache_age=$((now - cache_mtime))
        if (( cache_age < conn_ttl )); then
            cat "$conn_cache"
            return
        fi
    fi
    
    # Check connectivity and cache result
    if _check_k8s_connectivity; then
        printf '1' | tee "$conn_cache"
    else
        printf '0' | tee "$conn_cache"
    fi
}

# =============================================================================
# Main Logic
# =============================================================================

_get_k8s_context() {
    # Try kubectl first, fall back to file parsing
    if has_cmd kubectl; then
        kubectl config current-context 2>/dev/null && return
    fi
    _get_current_context_from_file
}

_get_k8s_namespace() {
    local context="$1"
    
    # Try kubectl first
    if has_cmd kubectl; then
        local ns=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
        [[ -n "$ns" ]] && { printf '%s' "$ns"; return; }
    fi
    
    # Fall back to file parsing
    _get_namespace_from_file "$context"
}

plugin_collect() {
    # Check for kubeconfig changes (invalidates connectivity cache)
    if _check_kubeconfig_changed; then
        rm -f "${POWERKIT_CACHE_DIR:-/tmp}/kubernetes_connectivity.cache" 2>/dev/null
    fi
    
    local context namespace connected display_mode
    
    context=$(_get_k8s_context)
    [[ -z "$context" ]] && return 0
    
    namespace=$(_get_k8s_namespace "$context")
    [[ -z "$namespace" ]] && namespace="default"
    
    display_mode=$(get_option "display_mode")
    
    # Check connectivity if display_mode is "connected"
    if [[ "$display_mode" == "connected" ]]; then
        connected=$(_get_cached_connectivity)
    else
        connected="1"
    fi
    
    plugin_data_set "context" "$context"
    plugin_data_set "namespace" "$namespace"
    plugin_data_set "connected" "$connected"
}

plugin_render() {
    local show_context show_namespace separator context namespace connected display_mode
    show_context=$(get_option "show_context")
    show_namespace=$(get_option "show_namespace")
    separator=$(get_option "separator")
    display_mode=$(get_option "display_mode")
    
    context=$(plugin_data_get "context")
    namespace=$(plugin_data_get "namespace")
    connected=$(plugin_data_get "connected")
    
    [[ -z "$context" ]] && return 0
    
    # If display_mode is "connected" and not connected, don't render
    if [[ "$display_mode" == "connected" && "$connected" == "0" ]]; then
        return 0
    fi
    
    # Shorten context name (remove user@ and cluster: prefixes)
    local display="${context##*@}"
    display="${display##*:}"
    
    local result=""
    
    if [[ "$show_context" == "true" ]]; then
        result="$display"
    fi
    
    if [[ "$show_namespace" == "true" ]]; then
        [[ -n "$result" ]] && result+="$separator"
        result+="$namespace"
    fi
    
    printf '%s' "$result"
}

# =============================================================================
# Keybindings
# =============================================================================

plugin_setup_keybindings() {
    local ctx_key ns_key popup_w popup_h
    ctx_key=$(get_option "keybinding_context")
    ns_key=$(get_option "keybinding_namespace")
    popup_w=$(get_option "popup_width")
    popup_h=$(get_option "popup_height")
    
    local conn_timeout=$(get_option "connectivity_timeout")
    local cache_dir="${POWERKIT_CACHE_DIR:-/tmp}"
    
    # Context selector - can switch even if current cluster is down
    if [[ -n "$ctx_key" ]] && has_cmd kubectl && has_cmd fzf; then
        register_keybinding "$ctx_key" "display-popup -E -w '$popup_w' -h '$popup_h' \
            'selected=\$(kubectl config get-contexts -o name | fzf --header=\"Select Kubernetes Context\" --reverse) && \
            [ -n \"\$selected\" ] && kubectl config use-context \"\$selected\" && \
            rm -f \"${cache_dir}/kubernetes.cache\" \"${cache_dir}/kubernetes_connectivity.cache\" && \
            tmux refresh-client -S'"
    fi
    
    # Namespace selector - requires cluster connectivity
    if [[ -n "$ns_key" ]] && has_cmd kubectl && has_cmd fzf; then
        register_keybinding "$ns_key" "display-popup -E -w '$popup_w' -h '$popup_h' \
            'if ! kubectl cluster-info --request-timeout=${conn_timeout}s &>/dev/null; then \
                echo \"❌ Cluster not reachable. Press any key to close.\"; read -n1; exit 1; \
            fi; \
            selected=\$(kubectl get namespaces -o name | sed \"s/namespace\\///\" | fzf --header=\"Select Namespace\" --reverse) && \
            [ -n \"\$selected\" ] && kubectl config set-context --current --namespace=\"\$selected\" && \
            rm -f \"${cache_dir}/kubernetes.cache\" && \
            tmux refresh-client -S'"
    fi
}

