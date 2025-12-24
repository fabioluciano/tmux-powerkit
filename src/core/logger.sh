#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Logger
# Description: Centralized logging system with levels and rotation
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "logger" && return 0

# =============================================================================
# Configuration
# =============================================================================

# Log levels
declare -gA _LOG_LEVELS=(
    [debug]=0
    [info]=1
    [warn]=2
    [error]=3
)

# Default settings
_LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit"
_LOG_FILE="${_LOG_DIR}/powerkit.log"
_LOG_MAX_SIZE=1048576  # 1MB
_LOG_LEVEL="${POWERKIT_LOG_LEVEL:-info}"
_LOG_DEBUG="${POWERKIT_DEBUG:-false}"

# =============================================================================
# Internal Functions
# =============================================================================

# Ensure log directory exists
_ensure_log_dir() {
    [[ -d "$_LOG_DIR" ]] || mkdir -p "$_LOG_DIR"
}

# Rotate log file if too large
_rotate_log() {
    [[ ! -f "$_LOG_FILE" ]] && return 0

    local size
    size=$(stat -f%z "$_LOG_FILE" 2>/dev/null || stat -c%s "$_LOG_FILE" 2>/dev/null || echo 0)

    if (( size > _LOG_MAX_SIZE )); then
        mv "$_LOG_FILE" "${_LOG_FILE}.old" 2>/dev/null || true
    fi
}

# Check if log level should be output
_should_log() {
    local level="$1"
    local current_level="${_LOG_LEVELS[$_LOG_LEVEL]:-1}"
    local msg_level="${_LOG_LEVELS[$level]:-1}"

    (( msg_level >= current_level ))
}

# Format timestamp
_log_timestamp() {
    printf '%s' "$(date '+%Y-%m-%d %H:%M:%S')"
}

# =============================================================================
# Public Logging Functions
# =============================================================================

# Generic log function
# Usage: log "level" "source" "message"
log() {
    local level="$1"
    local source="$2"
    local message="$3"

    _should_log "$level" || return 0

    _ensure_log_dir
    _rotate_log

    local timestamp
    timestamp=$(_log_timestamp)
    local level_upper="${level^^}"

    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$level_upper" "$source" "$message" >> "$_LOG_FILE"
}

# Debug level (only when @powerkit_debug=true or POWERKIT_DEBUG=true)
log_debug() {
    [[ "$_LOG_DEBUG" == "true" ]] || return 0
    log "debug" "$1" "$2"
}

# Info level
log_info() {
    log "info" "$1" "$2"
}

# Warning level
log_warn() {
    log "warn" "$1" "$2"
}

# Error level
log_error() {
    log "error" "$1" "$2"
}

# Plugin-specific error with optional toast notification
# Usage: log_plugin_error "plugin_name" "message" [show_toast]
log_plugin_error() {
    local plugin="$1"
    local message="$2"
    local show_toast="${3:-false}"

    log_error "plugin:$plugin" "$message"

    if [[ "$show_toast" == "true" ]]; then
        tmux display-message -d 3000 "PowerKit [$plugin]: $message" 2>/dev/null || true
    fi
}

# Log missing dependency
log_missing_dep() {
    local plugin="$1"
    local dependency="$2"
    log_warn "plugin:$plugin" "Missing dependency: $dependency"
}

# =============================================================================
# Utility Functions
# =============================================================================

# Get log file path
get_log_file() {
    printf '%s' "$_LOG_FILE"
}

# Set log level
set_log_level() {
    local level="$1"
    if [[ -n "${_LOG_LEVELS[$level]:-}" ]]; then
        _LOG_LEVEL="$level"
    fi
}

# Enable/disable debug mode
set_debug() {
    _LOG_DEBUG="$1"
}

# Clear log file
clear_log() {
    _ensure_log_dir
    : > "$_LOG_FILE"
}

# Get recent log entries
# Usage: get_recent_logs [count]
get_recent_logs() {
    local count="${1:-20}"
    [[ -f "$_LOG_FILE" ]] && tail -n "$count" "$_LOG_FILE"
}