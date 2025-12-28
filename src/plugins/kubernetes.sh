#!/usr/bin/env bash
# =============================================================================
# Plugin: kubernetes
# Description: Display current Kubernetes context and namespace
# Dependencies: kubectl (optional - can read kubeconfig directly)
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
    require_cmd "fzf" 1  # Optional: for selectors
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

    # Cache
    declare_option "cache_ttl" "number" "60" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local context connected display_mode
    context=$(plugin_data_get "context")
    connected=$(plugin_data_get "connected")
    display_mode=$(get_option "display_mode")

    if [[ -z "$context" ]]; then
        printf 'inactive'
    elif [[ "$display_mode" == "connected" && "$connected" != "1" ]]; then
        # Cluster not reachable - hide plugin completely (don't show empty segment)
        printf 'inactive'
    else
        printf 'active'
    fi
}

plugin_get_health() {
    local context connected warn_on_prod prod_keywords
    context=$(plugin_data_get "context")
    connected=$(plugin_data_get "connected")
    warn_on_prod=$(get_option "warn_on_prod")
    prod_keywords=$(get_option "prod_keywords")
    
    # Check if disconnected
    [[ "$connected" == "0" ]] && { printf 'warning'; return; }
    
    # Check if in production context
    if [[ "$warn_on_prod" == "true" && -n "$context" ]]; then
        local IFS=','
        local keyword
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
    local context connected prod_keywords
    context=$(plugin_data_get "context")
    connected=$(plugin_data_get "connected")
    prod_keywords=$(get_option "prod_keywords")
    
    [[ -z "$context" ]] && { printf 'no_context'; return; }
    [[ "$connected" == "0" ]] && { printf 'disconnected'; return; }
    
    # Detect environment type from context name
    local IFS=','
    local keyword
    for keyword in $prod_keywords; do
        [[ "${context,,}" == *"${keyword,,}"* ]] && { printf 'production'; return; }
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

# Get kubeconfig modification time for change detection
_get_kubeconfig_mtime() {
    local kubeconfig=$(_get_kubeconfig_path)
    [[ ! -f "$kubeconfig" ]] && { printf '0'; return; }
    
    if is_macos; then
        stat -f "%m" "$kubeconfig" 2>/dev/null || printf '0'
    else
        stat -c "%Y" "$kubeconfig" 2>/dev/null || printf '0'
    fi
}

# Check if kubeconfig changed since last check
_kubeconfig_changed() {
    local current_mtime cached_mtime
    current_mtime=$(_get_kubeconfig_mtime)
    
    # Get cached mtime
    if cached_mtime=$(cache_get "kubernetes_kubeconfig_mtime" 86400); then
        if [[ "$current_mtime" != "$cached_mtime" ]]; then
            # Changed - update cache and invalidate connectivity
            cache_set "kubernetes_kubeconfig_mtime" "$current_mtime"
            cache_invalidate "kubernetes_connectivity"
            return 0
        fi
        return 1
    fi
    
    # First run - save mtime
    cache_set "kubernetes_kubeconfig_mtime" "$current_mtime"
    return 0
}

# Get current context directly from kubeconfig (no kubectl required)
_get_context_from_file() {
    local kubeconfig=$(_get_kubeconfig_path)
    [[ ! -f "$kubeconfig" ]] && return 1
    awk '/^current-context:/ {print $2; exit}' "$kubeconfig" 2>/dev/null
}

# Get namespace for context from kubeconfig
_get_namespace_from_file() {
    local context="$1"
    local kubeconfig=$(_get_kubeconfig_path)
    [[ ! -f "$kubeconfig" ]] && return 1
    
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

_check_connectivity() {
    local timeout
    timeout=$(get_option "connectivity_timeout")
    
    if has_cmd kubectl; then
        kubectl cluster-info --request-timeout="${timeout}s" &>/dev/null
        return $?
    fi
    
    return 1
}

_get_cached_connectivity() {
    local conn_ttl
    conn_ttl=$(get_option "connectivity_cache_ttl")
    
    # Try to get from cache
    local cached
    if cached=$(cache_get "kubernetes_connectivity" "$conn_ttl"); then
        printf '%s' "$cached"
        return
    fi
    
    # Check connectivity and cache result
    if _check_connectivity; then
        cache_set "kubernetes_connectivity" "1"
        printf '1'
    else
        cache_set "kubernetes_connectivity" "0"
        printf '0'
    fi
}

# =============================================================================
# Main Logic
# =============================================================================

_get_context() {
    # Try kubectl first (respects KUBECONFIG env var better)
    if has_cmd kubectl; then
        kubectl config current-context 2>/dev/null && return
    fi
    _get_context_from_file
}

_get_namespace() {
    local context="$1"
    
    # Try kubectl first
    if has_cmd kubectl; then
        local ns
        ns=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
        [[ -n "$ns" ]] && { printf '%s' "$ns"; return; }
    fi
    
    # Fall back to file parsing
    _get_namespace_from_file "$context"
}

plugin_collect() {
    # Check for kubeconfig changes (invalidates connectivity cache)
    _kubeconfig_changed
    
    local context namespace connected display_mode
    
    context=$(_get_context)
    [[ -z "$context" ]] && return 0
    
    namespace=$(_get_namespace "$context")
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
    local show_context show_namespace separator display_mode
    local context namespace connected
    
    show_context=$(get_option "show_context")
    show_namespace=$(get_option "show_namespace")
    separator=$(get_option "separator")
    display_mode=$(get_option "display_mode")
    
    context=$(plugin_data_get "context")
    namespace=$(plugin_data_get "namespace")
    connected=$(plugin_data_get "connected")
    
    [[ -z "$context" ]] && return 0
    
    # If display_mode is "connected" and not connected, don't render
    [[ "$display_mode" == "connected" && "$connected" == "0" ]] && return 0
    
    # Shorten context name (remove user@ and cluster: prefixes)
    local display="${context##*@}"
    display="${display##*:}"
    
    local result=""
    
    [[ "$show_context" == "true" ]] && result="$display"
    
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
    # Check prerequisites
    has_cmd kubectl || return 0
    has_cmd fzf || return 0

    local kubeconfig=$(_get_kubeconfig_path)
    [[ ! -f "$kubeconfig" ]] && return 0

    local ctx_key ns_key popup_w popup_h conn_timeout
    ctx_key=$(get_option "keybinding_context")
    ns_key=$(get_option "keybinding_namespace")
    popup_w=$(get_option "popup_width")
    popup_h=$(get_option "popup_height")
    conn_timeout=$(get_option "connectivity_timeout")

    # Context selector - can switch even if current cluster is down
    local helper_script="${POWERKIT_ROOT}/src/helpers/kubernetes_selector.sh"
    if [[ -n "$ctx_key" ]]; then
        pk_bind_popup "$ctx_key" "bash '$helper_script' context" "$popup_w" "$popup_h" "kubernetes:context"
    fi

    # Namespace selector - requires cluster connectivity
    # Check connectivity BEFORE opening popup, show message if not reachable
    # Uses kubectl cluster-info which handles auth and self-signed certs properly
    if [[ -n "$ns_key" ]]; then
        local ns_cmd
        ns_cmd="if kubectl cluster-info --request-timeout=${conn_timeout}s >/dev/null 2>&1; then "
        ns_cmd+="tmux display-popup -E -w '${popup_w}' -h '${popup_h}' \"bash '${helper_script}' namespace\"; "
        ns_cmd+="else tmux display-message 'Cluster not reachable'; fi"

        pk_bind_shell "$ns_key" "$ns_cmd" "kubernetes:namespace"
    fi
}

