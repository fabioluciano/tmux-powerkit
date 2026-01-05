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
# Debug Validation (LSP - Liskov Substitution Principle)
# =============================================================================
# When POWERKIT_DEBUG=true, validate that plugins return valid values
# for state, health, content_type, and presence.

# Validate plugin contract return values in debug mode
# Usage: _debug_validate_contract_values plugin_name state health content_type presence
_debug_validate_contract_values() {
    # Skip validation if not in debug mode
    [[ "${POWERKIT_DEBUG:-}" != "true" ]] && return 0

    local name="$1"
    local state="$2"
    local health="$3"
    local content_type="$4"
    local presence="$5"

    # Validate state
    if ! is_valid_state "$state"; then
        log_warn "lifecycle" "Plugin '$name' returned invalid state: '$state' (expected: inactive, active, degraded, failed)"
    fi

    # Validate health
    if ! is_valid_health "$health"; then
        log_warn "lifecycle" "Plugin '$name' returned invalid health: '$health' (expected: ok, good, info, warning, error)"
    fi

    # Validate content_type
    if ! is_valid_content_type "$content_type"; then
        log_warn "lifecycle" "Plugin '$name' returned invalid content_type: '$content_type' (expected: static, dynamic)"
    fi

    # Validate presence
    if ! is_valid_presence "$presence"; then
        log_warn "lifecycle" "Plugin '$name' returned invalid presence: '$presence' (expected: always, conditional)"
    fi
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

    # After all plugins are initialized, show prompt for any missing binaries
    if declare -F binary_prompt_missing &>/dev/null; then
        binary_prompt_missing
    fi
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

    # Debug validation: check contract compliance
    _debug_validate_contract_values "$name" "$state" "$health" "$content_type" "$presence"

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
# Lazy Loading: Background Refresh Functions
# =============================================================================

# Spawn background refresh for a plugin
# Uses lock file to prevent concurrent refreshes
# Usage: _spawn_plugin_refresh "plugin_name"
_spawn_plugin_refresh() {
    local name="$1"
    local lock_file="${_CACHE_DIR}/.lock_${name}"

    # Check if refresh already in progress
    if [[ -f "$lock_file" ]]; then
        local lock_age now lock_mtime
        now=$(_get_now)
        lock_mtime=$(_file_mtime "$lock_file")
        lock_age=$((now - lock_mtime))
        # Stale lock (> 60s) - remove it
        if (( lock_age > 60 )); then
            rm -f "$lock_file"
        else
            return 0  # Refresh already running
        fi
    fi

    # Create lock
    touch "$lock_file"

    # Spawn background process using bash explicitly
    # Pass all needed variables as arguments to avoid subshell issues
    bash -c '
        name="$1"
        lock_file="$2"
        POWERKIT_ROOT="$3"
        export POWERKIT_ROOT

        # Cleanup lock on exit
        trap "rm -f \"$lock_file\"" EXIT

        plugin_file="${POWERKIT_ROOT}/src/plugins/${name}.sh"
        [[ ! -f "$plugin_file" ]] && exit 1

        # Source bootstrap (auto-loads core + utils modules)
        . "${POWERKIT_ROOT}/src/core/bootstrap.sh"

        # Set plugin context
        _set_plugin_context "$name"

        # Source plugin
        . "$plugin_file"

        # Declare options
        declare -F plugin_declare_options &>/dev/null && plugin_declare_options

        # Collect data
        plugin_data_clear
        plugin_collect || exit 1

        # Get state
        state=$(plugin_get_state)

        # Check visibility
        presence=$(plugin_get_presence)
        if [[ "$presence" == "hidden" || ( "$presence" == "conditional" && "$state" == "inactive" ) ]]; then
            cache_set "plugin_${name}_data" "HIDDEN"
            exit 0
        fi

        # Get health
        health="ok"
        declare -F plugin_get_health &>/dev/null && health=$(plugin_get_health)

        # Get icon
        icon=""
        declare -F plugin_get_icon &>/dev/null && icon=$(plugin_get_icon) || icon=$(get_option "icon" 2>/dev/null || echo "")

        # Get content
        content=$(plugin_render)

        # Build and save output (format: icon<US>content<US>state<US>health<US>stale)
        # stale=0 means fresh data
        _delim=$'"'"'\x1f'"'"'
        stale="0"
        output="${icon}${_delim}${content}${_delim}${state}${_delim}${health}${_delim}${stale}"

        cache_set "plugin_${name}_data" "$output"

        # Cache TTL
        ttl=$(get_option "cache_ttl" 2>/dev/null || echo 30)
        cache_set "plugin_${name}_ttl" "$ttl"
    ' _ "$name" "$lock_file" "$POWERKIT_ROOT" &>/dev/null &
    disown
}

# Actually perform the plugin refresh (runs in background)
# Usage: _do_plugin_refresh "plugin_name"
_do_plugin_refresh() {
    local name="$1"
    local plugin_file="${POWERKIT_ROOT}/src/plugins/${name}.sh"

    [[ ! -f "$plugin_file" ]] && return 1

    # Set plugin context
    _set_plugin_context "$name"

    # Source plugin
    # shellcheck disable=SC1090
    . "$plugin_file"

    # Declare options
    declare -F plugin_declare_options &>/dev/null && plugin_declare_options

    # Collect data
    plugin_data_clear
    plugin_collect || return 1

    # Get state
    local state
    state=$(plugin_get_state)

    # Check visibility
    local presence
    presence=$(plugin_get_presence)
    if [[ "$presence" == "hidden" || ( "$presence" == "conditional" && "$state" == "inactive" ) ]]; then
        cache_set "plugin_${name}_data" "HIDDEN"
        return 0
    fi

    # Get health
    local health="ok"
    declare -F plugin_get_health &>/dev/null && health=$(plugin_get_health)

    # Get icon
    local icon=""
    declare -F plugin_get_icon &>/dev/null && icon=$(plugin_get_icon) || icon=$(get_option "icon" 2>/dev/null || echo "")

    # Get content
    local content
    content=$(plugin_render)

    # Build and save output (format: icon<US>content<US>state<US>health<US>stale)
    # stale=0 means fresh data
    local _delim=$'\x1f'
    local stale="0"
    local output="${icon}${_delim}${content}${_delim}${state}${_delim}${health}${_delim}${stale}"

    cache_set "plugin_${name}_data" "$output"

    # Also cache TTL for future reference
    local ttl
    ttl=$(get_option "cache_ttl" 2>/dev/null || echo 30)
    cache_set "plugin_${name}_ttl" "$ttl"
}

# Synchronous plugin collection (blocking)
# Usage: _collect_plugin_sync "plugin_name" "plugin_file" "cache_key" "ttl_cache_key"
_collect_plugin_sync() {
    local name="$1"
    local plugin_file="$2"
    local cache_key="$3"
    local ttl_cache_key="$4"

    # Source plugin
    # shellcheck disable=SC1090
    . "$plugin_file"

    # Check dependencies (calls require_macos_binary for macOS plugins)
    if declare -F plugin_check_dependencies &>/dev/null; then
        if ! plugin_check_dependencies; then
            # Dependencies not met - return HIDDEN and cache it
            cache_set "$cache_key" "HIDDEN"
            printf 'HIDDEN'
            return 0
        fi
    fi

    # Declare options
    declare -F plugin_declare_options &>/dev/null && plugin_declare_options

    # Get and cache TTL
    local ttl
    ttl=$(get_option "cache_ttl" 2>/dev/null || echo 30)
    cache_set "$ttl_cache_key" "$ttl"

    # Collect data
    plugin_data_clear
    if ! plugin_collect; then
        # Collection failed - try to return existing cache (stale is better than nothing)
        # Uses _DEFAULT_CACHE_TTL_DAY (24h) as max fallback window
        local existing_cache
        existing_cache=$(cache_get "$cache_key" "${_DEFAULT_CACHE_TTL_DAY:-86400}" 2>/dev/null)
        if [[ -n "$existing_cache" && "$existing_cache" != "HIDDEN" ]]; then
            # Touch cache file to prevent repeated collection attempts
            # This extends the stale window, reducing API hammering on failures
            local cache_file="${_CACHE_DIR}/${cache_key}"
            [[ -f "$cache_file" ]] && touch "$cache_file"
            # Mark as stale by updating the 5th field (or appending if missing)
            local _delim=$'\x1f'
            if [[ "$existing_cache" == *"${_delim}"*"${_delim}"*"${_delim}"*"${_delim}"* ]]; then
                # Already has 5 fields, replace last with "1"
                existing_cache="${existing_cache%${_delim}*}${_delim}1"
            else
                # Only 4 fields, append stale=1
                existing_cache="${existing_cache}${_delim}1"
            fi
            printf '%s' "$existing_cache"
            return 0
        fi
        # No valid cache - return HIDDEN (but don't cache HIDDEN on failure)
        printf 'HIDDEN'
        return 1
    fi

    # Get state
    local state
    state=$(plugin_get_state)

    # Check visibility
    local presence
    presence=$(plugin_get_presence)
    if [[ "$presence" == "hidden" || ( "$presence" == "conditional" && "$state" == "inactive" ) ]]; then
        cache_set "$cache_key" "HIDDEN"
        printf 'HIDDEN'
        return 0
    fi

    # Get health
    local health="ok"
    declare -F plugin_get_health &>/dev/null && health=$(plugin_get_health)

    # Get icon
    local icon=""
    declare -F plugin_get_icon &>/dev/null && icon=$(plugin_get_icon) || icon=$(get_option "icon" 2>/dev/null || echo "")

    # Get content
    local content
    content=$(plugin_render)

    # Build output (format: icon<US>content<US>state<US>health<US>stale)
    # stale=0 means fresh data
    local _delim=$'\x1f'
    local stale="0"
    local output="${icon}${_delim}${content}${_delim}${state}${_delim}${health}${_delim}${stale}"

    # Cache and return
    cache_set "$cache_key" "$output"
    printf '%s' "$output"
}

# =============================================================================
# Plugin Data Collection (for renderer)
# =============================================================================

# Collect all data needed for rendering a plugin
# Uses cache when available, collects fresh data when needed
# Implements Stale-While-Revalidate pattern for non-blocking updates
#
# Usage: collect_plugin_render_data "plugin_name"
#
# OUTPUT FORMAT (5 fields, Unit Separator delimited):
#   "icon<US>content<US>state<US>health<US>stale"
#   - icon: Plugin icon character
#   - content: Rendered text from plugin_render()
#   - state: inactive|active|degraded|failed
#   - health: ok|good|info|warning|error
#   - stale: 0=fresh data, 1=cached/stale data
#   - Returns "HIDDEN" if plugin not visible
#
# STALE-WHILE-REVALIDATE PATTERN:
#   Cache State        | Age              | Behavior                    | stale
#   -------------------|------------------|-----------------------------|---------
#   FRESH              | age ≤ TTL        | Return cache immediately    | 0
#   STALE              | TTL < age ≤ TTL×3| Return cache + bg refresh   | 1
#   VERY OLD           | age > TTL×3      | Synchronous collection      | 0
#   MISSING            | no cache         | Synchronous collection      | 0
#   COLLECTION FAILED  | any              | Return previous cache       | 1
#
# VISUAL INDICATION:
#   When stale=1, renderer applies @powerkit_stale_color_variant (default: -darker)
#   to background colors, providing visual feedback that cached data is displayed.
#
# NOTE: Colors are NOT resolved here - that's the renderer's responsibility
#       per the contract separation (lifecycle = data, renderer = UI)
collect_plugin_render_data() {
    local name="$1"
    local plugin_file="${POWERKIT_ROOT}/src/plugins/${name}.sh"

    [[ ! -f "$plugin_file" ]] && return 1

    # Set plugin context
    _set_plugin_context "$name"

    # Cache keys
    local cache_key="plugin_${name}_data"
    local ttl_cache_key="plugin_${name}_ttl"

    # Get TTL (use cached value to avoid sourcing plugin just for TTL)
    local ttl
    ttl=$(cache_get "$ttl_cache_key" 86400 2>/dev/null) || ttl="${_DEFAULT_CACHE_TTL_SHORT:-30}"

    # Get cache file info directly (avoid cache_get overhead for age calculation)
    local cache_file="${_CACHE_DIR}/${cache_key}"
    local cache_age=-1
    local cached_data=""

    if [[ -f "$cache_file" ]]; then
        local now mtime
        now=$(_get_now)
        mtime=$(_file_mtime "$cache_file")
        cache_age=$((now - mtime))
        cached_data=$(< "$cache_file")
    fi

    # =========================================================================
    # LAZY LOADING DECISION LOGIC
    # =========================================================================

    # Check if lazy loading is enabled
    local lazy_loading
    lazy_loading=$(get_tmux_option "@powerkit_lazy_loading" "${POWERKIT_DEFAULT_LAZY_LOADING:-true}")

    if [[ "$lazy_loading" != "true" ]]; then
        # Lazy loading disabled - use original behavior
        if [[ $cache_age -ge 0 && $cache_age -le $ttl && -n "$cached_data" ]]; then
            printf '%s' "$cached_data"
            return 0
        fi
        _collect_plugin_sync "$name" "$plugin_file" "$cache_key" "$ttl_cache_key"
        return
    fi

    # FRESH: age <= TTL → return cache immediately
    if [[ $cache_age -ge 0 && $cache_age -le $ttl && -n "$cached_data" ]]; then
        printf '%s' "$cached_data"
        return 0
    fi

    # Get stale multiplier
    local stale_multiplier
    stale_multiplier="${POWERKIT_DEFAULT_STALE_MULTIPLIER:-3}"
    local stale_limit=$((ttl * stale_multiplier))

    # STALE WINDOW: TTL < age <= TTL*multiplier → return cache + background refresh
    # Skip if cached_data is "HIDDEN" (not valid plugin data)
    #
    # IMPORTANT: Do NOT mark as stale=1 here. Natural cache aging is normal behavior.
    # The stale indicator (darker colors) should ONLY appear when there's an actual
    # problem (API failure, collection error). This is handled in _collect_plugin_sync
    # when plugin_collect() returns non-zero.
    #
    # This ensures plugins don't constantly appear "stale" just because their cache
    # is slightly older than TTL - which would happen with TTL close to status-interval.
    if [[ $cache_age -gt $ttl && $cache_age -le $stale_limit && -n "$cached_data" && "$cached_data" != "HIDDEN" ]]; then
        _spawn_plugin_refresh "$name"
        # Return cached data AS-IS (preserve existing stale flag)
        # If data was previously marked stale due to failure, it stays stale until fresh collection succeeds
        printf '%s' "$cached_data"
        return 0
    fi

    # VERY OLD or MISSING: collect synchronously (blocking)
    _collect_plugin_sync "$name" "$plugin_file" "$cache_key" "$ttl_cache_key"
}

# =============================================================================
# External Plugin Data Collection
# =============================================================================

# Collect render data for external plugin
# Returns data in same format as regular plugins: icon<US>content<US>state<US>health<US>stale
# Also returns accent colors via global variables for renderer to use
#
# Usage: collect_external_plugin_render_data "external_id" "spec"
# Sets: _EXTERNAL_ACCENT, _EXTERNAL_ACCENT_ICON (global vars for renderer)
collect_external_plugin_render_data() {
    local id="$1"
    local spec="$2"

    # Parse external plugin format: external("icon"|"content"|"accent"|"accent_icon"|"ttl")
    local icon="" content="" accent="" accent_icon="" ttl=""

    if [[ "$spec" =~ external\(\"([^\"]*)\"\|\"([^\"]*)\"\|\"([^\"]*)\"\|\"([^\"]*)\"\|\"([^\"]*)\"\) ]]; then
        icon="${BASH_REMATCH[1]}"
        content="${BASH_REMATCH[2]}"
        accent="${BASH_REMATCH[3]:-ok-base}"
        accent_icon="${BASH_REMATCH[4]:-ok-base-lighter}"
        ttl="${BASH_REMATCH[5]:-60}"
    else
        log_warn "lifecycle" "Invalid external plugin format: $spec"
        return 1
    fi

    # Cache key for this external plugin
    local cache_key="external_${id}_data"

    # Check cache - try to get cached data within TTL
    local cached_data=""
    if cached_data=$(cache_get "$cache_key" "$ttl"); then
        # Cache hit - return cached data
        printf '%s' "$cached_data"
        return 0
    fi

    # Execute content command if it looks like a command
    local output=""
    if [[ "$content" == *'$('* || "$content" == *'#('* ]]; then
        # Command substitution - execute it
        local cmd="${content}"
        # Convert #(...) to $(...) for eval
        cmd="${cmd//#\(/\$(}"
        output=$(eval "printf '%s' \"$cmd\"" 2>/dev/null || printf '%s' "$content")
    else
        output="$content"
    fi

    # Build output in standard format: icon<US>content<US>state<US>health<US>stale<US>accent<US>accent_icon
    # We add accent and accent_icon as extra fields for external plugins
    local _delim=$'\x1f'
    local result="${icon}${_delim}${output}${_delim}active${_delim}ok${_delim}0${_delim}${accent}${_delim}${accent_icon}"

    # Cache the result using cache API
    cache_set "$cache_key" "$result"

    printf '%s' "$result"
}

# Find external plugin ID by spec string
# Since external plugins are registered with unique IDs, we need to find the ID
# Usage: find_external_plugin_id "external(...)"
find_external_plugin_id() {
    local spec="$1"
    local name
    for name in "${!_PLUGINS[@]}"; do
        [[ "$name" == external_* ]] || continue
        [[ "${_PLUGINS[$name]}" == "$spec" ]] && {
            printf '%s' "$name"
            return 0
        }
    done
    return 1
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
