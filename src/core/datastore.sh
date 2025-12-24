#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Datastore
# Description: Plugin-scoped data storage API using associative arrays
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "datastore" && return 0

# =============================================================================
# Datastore Storage
# =============================================================================

# Main datastore - associative array with plugin:key format
declare -gA _DATASTORE=()

# Current plugin context (set by plugin_init)
declare -g _CURRENT_PLUGIN=""

# Metadata storage
declare -gA _METADATA=()

# =============================================================================
# Plugin Data API
# =============================================================================

# Set current plugin context
# Usage: _set_plugin_context "plugin_name"
_set_plugin_context() {
    _CURRENT_PLUGIN="$1"
}

# Get current plugin context
_get_plugin_context() {
    printf '%s' "$_CURRENT_PLUGIN"
}

# Store a value in plugin scope
# Usage: plugin_data_set "key" "value"
plugin_data_set() {
    local key="$1"
    local value="$2"

    if [[ -z "$_CURRENT_PLUGIN" ]]; then
        log_error "datastore" "plugin_data_set called without plugin context"
        return 1
    fi

    _DATASTORE["${_CURRENT_PLUGIN}:${key}"]="$value"
}

# Retrieve a value from plugin scope
# Usage: plugin_data_get "key"
plugin_data_get() {
    local key="$1"

    if [[ -z "$_CURRENT_PLUGIN" ]]; then
        log_error "datastore" "plugin_data_get called without plugin context"
        return 1
    fi

    printf '%s' "${_DATASTORE["${_CURRENT_PLUGIN}:${key}"]:-}"
}

# Check if a key exists in plugin scope
# Usage: plugin_data_has "key" && echo "exists"
plugin_data_has() {
    local key="$1"

    if [[ -z "$_CURRENT_PLUGIN" ]]; then
        return 1
    fi

    [[ -n "${_DATASTORE["${_CURRENT_PLUGIN}:${key}"]+x}" ]]
}

# Clear all data for current plugin
# Usage: plugin_data_clear
plugin_data_clear() {
    if [[ -z "$_CURRENT_PLUGIN" ]]; then
        return 1
    fi

    local prefix="${_CURRENT_PLUGIN}:"
    local key
    for key in "${!_DATASTORE[@]}"; do
        if [[ "$key" == "${prefix}"* ]]; then
            unset "_DATASTORE[$key]"
        fi
    done
}

# =============================================================================
# Cross-Plugin Data Access (for core use only)
# =============================================================================

# Get value from any plugin's data (core use only)
# Usage: _datastore_get "plugin_name" "key"
_datastore_get() {
    local plugin="$1"
    local key="$2"
    printf '%s' "${_DATASTORE["${plugin}:${key}"]:-}"
}

# Set value for any plugin's data (core use only)
# Usage: _datastore_set "plugin_name" "key" "value"
_datastore_set() {
    local plugin="$1"
    local key="$2"
    local value="$3"
    _DATASTORE["${plugin}:${key}"]="$value"
}

# Check if key exists for any plugin (core use only)
# Usage: _datastore_has "plugin_name" "key"
_datastore_has() {
    local plugin="$1"
    local key="$2"
    [[ -n "${_DATASTORE["${plugin}:${key}"]+x}" ]]
}

# Clear all data for a specific plugin (core use only)
# Usage: _datastore_clear_plugin "plugin_name"
_datastore_clear_plugin() {
    local plugin="$1"
    local prefix="${plugin}:"
    local key
    for key in "${!_DATASTORE[@]}"; do
        if [[ "$key" == "${prefix}"* ]]; then
            unset "_DATASTORE[$key]"
        fi
    done
}

# Clear entire datastore (core use only)
_datastore_clear_all() {
    _DATASTORE=()
}

# =============================================================================
# Metadata API
# =============================================================================

# Set metadata for current plugin
# Usage: metadata_set "key" "value"
metadata_set() {
    local key="$1"
    local value="$2"

    if [[ -z "$_CURRENT_PLUGIN" ]]; then
        log_error "datastore" "metadata_set called without plugin context"
        return 1
    fi

    _METADATA["${_CURRENT_PLUGIN}:${key}"]="$value"
}

# Get metadata for current plugin
# Usage: metadata_get "key"
metadata_get() {
    local key="$1"

    if [[ -z "$_CURRENT_PLUGIN" ]]; then
        return 1
    fi

    printf '%s' "${_METADATA["${_CURRENT_PLUGIN}:${key}"]:-}"
}

# Get metadata for any plugin (core use)
# Usage: _metadata_get "plugin_name" "key"
_metadata_get() {
    local plugin="$1"
    local key="$2"
    printf '%s' "${_METADATA["${plugin}:${key}"]:-}"
}

# =============================================================================
# Debug Functions
# =============================================================================

# Dump all datastore contents (for debugging)
datastore_dump() {
    local key
    printf 'Datastore contents:\n'
    for key in "${!_DATASTORE[@]}"; do
        printf '  %s = %s\n' "$key" "${_DATASTORE[$key]}"
    done
}

# Dump all metadata contents (for debugging)
metadata_dump() {
    local key
    printf 'Metadata contents:\n'
    for key in "${!_METADATA[@]}"; do
        printf '  %s = %s\n' "$key" "${_METADATA[$key]}"
    done
}

# =============================================================================
# Public API Aliases (for plugin convenience)
# =============================================================================

# Note: These functions are for core/debug use only.
# Plugins should use plugin_data_set/get/has/clear instead.
