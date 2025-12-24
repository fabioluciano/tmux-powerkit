#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Lifecycle Manager
# Description: Manages plugin lifecycle phases
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "lifecycle" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/core/datastore.sh"
. "${POWERKIT_ROOT}/src/core/options.sh"
. "${POWERKIT_ROOT}/src/core/cache.sh"

# =============================================================================
# Plugin Registry
# =============================================================================

# Registered plugins
declare -gA _PLUGINS=()

# Plugin states
declare -gA _PLUGIN_STATES=()

# =============================================================================
# Plugin Discovery
# =============================================================================

# Discover plugins from @powerkit_plugins option
# Usage: discover_plugins
discover_plugins() {
    local plugins_str
    plugins_str=$(get_tmux_option "@powerkit_plugins" "${POWERKIT_DEFAULT_PLUGINS}")

    [[ -z "$plugins_str" ]] && {
        log_warn "lifecycle" "No plugins configured in @powerkit_plugins"
        return 0
    }

    # Parse comma-separated list
    local IFS=','
    local plugin_name
    for plugin_name in $plugins_str; do
        # Trim whitespace
        plugin_name="${plugin_name#"${plugin_name%%[![:space:]]*}"}"
        plugin_name="${plugin_name%"${plugin_name##*[![:space:]]}"}"

        [[ -z "$plugin_name" ]] && continue

        # Check if it's an external plugin
        # External plugins have format: external("...")
        if [[ "$plugin_name" == external\(* ]]; then
            _register_external_plugin "$plugin_name"
        else
            _register_plugin "$plugin_name"
        fi
    done

    log_info "lifecycle" "Discovered ${#_PLUGINS[@]} plugins"
}

# Register an internal plugin
_register_plugin() {
    local name="$1"
    local plugin_file="${POWERKIT_ROOT}/src/plugins/${name}.sh"

    if [[ ! -f "$plugin_file" ]]; then
        log_warn "lifecycle" "Plugin file not found: $name"
        return 0  # Don't fail, just skip
    fi

    _PLUGINS["$name"]="$plugin_file"
    _PLUGIN_STATES["$name"]="discovered"

    log_debug "lifecycle" "Registered plugin: $name"
    return 0
}

# Register an external plugin
_register_external_plugin() {
    local spec="$1"
    # Format: external("icon"|"content"|"accent"|"accent_icon"|"ttl")

    # Generate unique ID
    local id="external_$(date +%s%N | cut -c1-16)"

    _PLUGINS["$id"]="$spec"
    _PLUGIN_STATES["$id"]="discovered"

    log_debug "lifecycle" "Registered external plugin: $id"
}

# =============================================================================
# Plugin Validation
# =============================================================================

# Validate all discovered plugins
# Usage: validate_plugins
validate_plugins() {
    local name
    for name in "${!_PLUGINS[@]}"; do
        [[ "$name" == external_* ]] && continue  # Skip external plugins

        if _validate_plugin "$name"; then
            _PLUGIN_STATES["$name"]="validated"
        else
            _PLUGIN_STATES["$name"]="invalid"
            log_warn "lifecycle" "Plugin validation failed: $name"
        fi
    done
}

# Validate a single plugin
_validate_plugin() {
    local name="$1"
    local plugin_file="${_PLUGINS[$name]}"

    # Source the plugin to check contract compliance
    (
        # Run in subshell to avoid polluting environment
        # shellcheck disable=SC1090
        . "$plugin_file" 2>/dev/null

        # Check mandatory functions exist
        declare -F plugin_collect &>/dev/null || exit 1
        declare -F plugin_get_content_type &>/dev/null || exit 1
        declare -F plugin_get_presence &>/dev/null || exit 1
        declare -F plugin_get_state &>/dev/null || exit 1
        # plugin_get_health is optional - defaults to "ok"
        declare -F plugin_render &>/dev/null || exit 1
    )
}

# =============================================================================
# Plugin Initialization
# =============================================================================

# Initialize all validated plugins
# Usage: initialize_plugins
initialize_plugins() {
    local name
    for name in "${!_PLUGINS[@]}"; do
        [[ "${_PLUGIN_STATES[$name]}" != "validated" ]] && continue

        if _initialize_plugin "$name"; then
            _PLUGIN_STATES["$name"]="initialized"
        else
            _PLUGIN_STATES["$name"]="init_failed"
        fi
    done
}

# Initialize a single plugin
_initialize_plugin() {
    local name="$1"
    local plugin_file="${_PLUGINS[$name]}"

    # Set plugin context
    _set_plugin_context "$name"

    # Source the plugin
    # shellcheck disable=SC1090
    . "$plugin_file"

    # Check dependencies if function exists
    if declare -F plugin_check_dependencies &>/dev/null; then
        if ! plugin_check_dependencies; then
            log_warn "lifecycle" "Plugin dependencies not met: $name"
            return 1
        fi
    fi

    # Declare options if function exists
    if declare -F plugin_declare_options &>/dev/null; then
        plugin_declare_options
    fi

    # Setup keybindings if function exists
    if declare -F plugin_setup_keybindings &>/dev/null; then
        plugin_setup_keybindings
    fi

    log_debug "lifecycle" "Initialized plugin: $name"
    return 0
}

# =============================================================================
# Plugin Collection
# =============================================================================

# Collect data from all initialized plugins
# Usage: collect_plugins
collect_plugins() {
    local name
    for name in "${!_PLUGINS[@]}"; do
        [[ "${_PLUGIN_STATES[$name]}" != "initialized" ]] && continue
        [[ "$name" == external_* ]] && continue  # External plugins collect differently

        _collect_plugin "$name"
    done
}

# Collect data from a single plugin
_collect_plugin() {
    local name="$1"

    # Get cache TTL for this plugin
    _set_plugin_context "$name"
    local ttl
    ttl=$(get_option "cache_ttl" 2>/dev/null || echo 30)

    # Check cache first
    if _plugin_cache_valid "$name" "$ttl"; then
        log_debug "lifecycle" "Using cached data for: $name"
        return 0
    fi

    # Source plugin and collect
    local plugin_file="${_PLUGINS[$name]}"
    # shellcheck disable=SC1090
    . "$plugin_file"

    # Clear previous data
    plugin_data_clear

    # Run collection
    if plugin_collect; then
        log_debug "lifecycle" "Collected data for: $name"
    else
        log_warn "lifecycle" "Collection failed for: $name"
        _PLUGIN_STATES["$name"]="collect_failed"
    fi
}

# =============================================================================
# Plugin Resolution
# =============================================================================

# Plugin output structure
declare -gA _PLUGIN_OUTPUT=()

# Resolve plugin state/health/context
# Usage: resolve_plugins
resolve_plugins() {
    local name
    for name in "${!_PLUGINS[@]}"; do
        [[ "$name" == external_* ]] && {
            _resolve_external_plugin "$name"
            continue
        }

        [[ "${_PLUGIN_STATES[$name]}" != "initialized" ]] && continue

        _resolve_plugin "$name"
    done
}

# Resolve a single plugin
_resolve_plugin() {
    local name="$1"

    _set_plugin_context "$name"

    # Source plugin
    local plugin_file="${_PLUGINS[$name]}"
    # shellcheck disable=SC1090
    . "$plugin_file"

    # Get plugin contract values
    local content_type presence state health context content icon

    content_type=$(plugin_get_content_type)
    presence=$(plugin_get_presence)
    state=$(plugin_get_state)
    
    # Health is optional - defaults to "ok"
    if declare -F plugin_get_health &>/dev/null; then
        health=$(plugin_get_health)
    else
        health="ok"
    fi

    # Get context if available
    if declare -F plugin_get_context &>/dev/null; then
        context=$(plugin_get_context)
    else
        context=""
    fi

    # Get rendered content
    content=$(plugin_render)

    # Get icon from plugin (plugin decides which icon to show)
    if declare -F plugin_get_icon &>/dev/null; then
        icon=$(plugin_get_icon)
    else
        # Fallback to default icon option
        icon=$(get_option "icon" 2>/dev/null || echo "")
    fi

    # Check visibility
    local visible=1
    if [[ "$presence" == "hidden" || ( "$presence" == "conditional" && "$state" == "inactive" ) ]]; then
        visible=0
    fi

    # Store output
    _PLUGIN_OUTPUT["${name}:content"]="$content"
    _PLUGIN_OUTPUT["${name}:content_type"]="$content_type"
    _PLUGIN_OUTPUT["${name}:presence"]="$presence"
    _PLUGIN_OUTPUT["${name}:state"]="$state"
    _PLUGIN_OUTPUT["${name}:health"]="$health"
    _PLUGIN_OUTPUT["${name}:context"]="$context"
    _PLUGIN_OUTPUT["${name}:icon"]="$icon"
    _PLUGIN_OUTPUT["${name}:visible"]="$visible"

    log_debug "lifecycle" "Resolved plugin $name: state=$state health=$health visible=$visible"
}

# Resolve an external plugin
_resolve_external_plugin() {
    local name="$1"
    local spec="${_PLUGINS[$name]}"

    # Parse external plugin spec
    # Format: external("icon"|"content"|"accent"|"accent_icon"|"ttl")
    local icon content accent accent_icon ttl

    # Parse external plugin format: external("icon"|"content"|"accent"|"accent_icon"|"ttl")
    local icon="" content="" accent="" accent_icon="" ttl=""
    
    if [[ "$spec" =~ external\(\"([^\"]*)\"\|\"([^\"]*)\"\|\"([^\"]*)\"\|\"([^\"]*)\"\|\"([^\"]*)\"\) ]]; then
        icon="${BASH_REMATCH[1]}"
        content="${BASH_REMATCH[2]}"
        accent="${BASH_REMATCH[3]:-secondary}"
        accent_icon="${BASH_REMATCH[4]:-active}"
        ttl="${BASH_REMATCH[5]:-0}"
    fi

    # Execute content command
    local output=""
    if [[ "$content" == "\$(("* || "$content" == "#("* ]]; then
        # Command to execute
        local cmd="${content#\$(}"
        cmd="${cmd%\)}"
        cmd="${cmd#\#(}"
        cmd="${cmd%\)}"
        output=$(eval "$cmd" 2>/dev/null || true)
    else
        output="$content"
    fi

    # Store output
    _PLUGIN_OUTPUT["${name}:content"]="$output"
    _PLUGIN_OUTPUT["${name}:icon"]="$icon"
    _PLUGIN_OUTPUT["${name}:accent"]="$accent"
    _PLUGIN_OUTPUT["${name}:accent_icon"]="$accent_icon"
    _PLUGIN_OUTPUT["${name}:visible"]="1"
    _PLUGIN_OUTPUT["${name}:external"]="1"

    _PLUGIN_STATES["$name"]="resolved"
}

# =============================================================================
# Plugin Output Access
# =============================================================================

# Get plugin output value
# Usage: get_plugin_output "plugin_name" "key"
get_plugin_output() {
    local plugin="$1"
    local key="$2"
    printf '%s' "${_PLUGIN_OUTPUT["${plugin}:${key}"]:-}"
}

# Check if plugin is visible
# Usage: is_plugin_visible "plugin_name"
is_plugin_visible() {
    local plugin="$1"
    [[ "${_PLUGIN_OUTPUT["${plugin}:visible"]:-0}" == "1" ]]
}

# Get list of visible plugins
# Usage: get_visible_plugins
get_visible_plugins() {
    local name
    for name in "${!_PLUGINS[@]}"; do
        is_plugin_visible "$name" && printf '%s\n' "$name"
    done
}

# =============================================================================
# Plugin Data Collection (for renderer)
# =============================================================================

# Collect all data needed for rendering a plugin
# Uses cache when available, collects fresh data when needed
# Usage: collect_plugin_render_data "plugin_name"
# Returns: "icon<US>content<US>state<US>health" or "HIDDEN" if not visible
#          (US = Unit Separator, ASCII 31, to avoid conflicts with | in content)
# NOTE: Colors are NOT resolved here - that's the renderer's responsibility
#       per the contract separation (lifecycle = data, renderer = UI)
collect_plugin_render_data() {
    local name="$1"
    local plugin_file="${POWERKIT_ROOT}/src/plugins/${name}.sh"

    [[ ! -f "$plugin_file" ]] && return 1

    # Set plugin context
    _set_plugin_context "$name"

    # Source plugin
    # shellcheck disable=SC1090
    . "$plugin_file"

    # Declare options (required before get_option calls)
    if declare -F plugin_declare_options &>/dev/null; then
        plugin_declare_options
    fi

    # Get cache TTL
    local ttl
    ttl=$(get_option "cache_ttl" 2>/dev/null || echo 30)
    local cache_key="plugin_${name}_data"

    # Check cache first
    local cached_data
    cached_data=$(cache_get "$cache_key" "$ttl" 2>/dev/null) || cached_data=""

    if [[ -n "$cached_data" ]]; then
        printf '%s' "$cached_data"
        return 0
    fi

    # Collect fresh data
    plugin_data_clear
    plugin_collect

    # Get plugin contract values
    local state presence health icon content
    local icon="" content="" accent="" accent_icon="" ttl=""

    state=$(plugin_get_state)
    presence=$(plugin_get_presence)

    # Check visibility - cache as HIDDEN if not visible
    # This prevents re-running slow dependency checks on every render
    if [[ "$presence" == "hidden" || ( "$presence" == "conditional" && "$state" == "inactive" ) ]]; then
        local output="HIDDEN"
        cache_set "$cache_key" "$output"
        printf '%s' "$output"
        return 0
    fi

    # Health is optional - defaults to "ok"
    if declare -F plugin_get_health &>/dev/null; then
        health=$(plugin_get_health)
    else
        health="ok"
    fi

    # Get icon (plugin decides based on its internal state)
    if declare -F plugin_get_icon &>/dev/null; then
        icon=$(plugin_get_icon)
    else
        icon=$(get_option "icon" 2>/dev/null || echo "")
    fi

    # Get content
    content=$(plugin_render)

    # Build output - DATA ONLY (colors are renderer's responsibility)
    # Use Unit Separator (ASCII 31) to avoid conflicts with content containing |
    local _delim=$'\x1f'
    local output="${icon}${_delim}${content}${_delim}${state}${_delim}${health}"

    # Cache the data
    cache_set "$cache_key" "$output"

    printf '%s' "$output"
}

# =============================================================================
# Full Lifecycle Run
# =============================================================================

# Run full plugin lifecycle
# Usage: run_plugin_lifecycle
run_plugin_lifecycle() {
    log_info "lifecycle" "Starting plugin lifecycle"

    discover_plugins
    validate_plugins
    initialize_plugins
    collect_plugins
    resolve_plugins

    log_info "lifecycle" "Plugin lifecycle complete"
}

# Get plugin state
# Usage: get_plugin_state "plugin_name"
get_plugin_state() {
    local name="$1"
    printf '%s' "${_PLUGIN_STATES[$name]:-unknown}"
}

# List all registered plugins
list_registered_plugins() {
    local name
    for name in "${!_PLUGINS[@]}"; do
        printf '%s: %s\n' "$name" "${_PLUGIN_STATES[$name]:-unknown}"
    done
}
