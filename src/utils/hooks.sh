#!/usr/bin/env bash
# =============================================================================
#  HOOKS UTILITY
#  Generic tmux hooks management
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. Hook Registration
#   3. Hook Management
#   4. Delayed Commands
#   5. API Reference
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# The Hooks Utility provides a clean API for registering and managing tmux hooks.
# Hooks are triggered by tmux events like pane selection, window creation, etc.
#
# Supported hooks (tmux 3.0+):
#   - after-select-pane      - After pane selection
#   - after-select-window    - After window selection
#   - after-resize-pane      - After pane resize
#   - after-split-window     - After window split
#   - after-new-window       - After new window created
#   - after-new-session      - After new session created
#   - pane-focus-in          - Pane gains focus
#   - pane-focus-out         - Pane loses focus
#   - window-linked          - Window linked to session
#   - window-unlinked        - Window unlinked from session
#
# =============================================================================
#
# 2. API REFERENCE
# ================
#
#   Hook Registration:
#     register_hook "hook-name" "command"     - Register a global hook
#     register_hook_local "hook-name" "cmd"   - Register window/pane local hook
#     unregister_hook "hook-name"             - Remove a hook
#     unregister_hook_local "hook-name"       - Remove local hook
#
#   Hook Management:
#     list_hooks                              - List all registered hooks
#     has_hook "hook-name"                    - Check if hook exists
#     clear_all_hooks                         - Remove all PowerKit hooks
#
#   Delayed Commands:
#     run_delayed "command" "delay_seconds"   - Run command after delay
#     run_delayed_ms "command" "delay_ms"     - Run command after delay (ms)
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_hooks" && return 0

# Note: All core modules are loaded by bootstrap.sh

# =============================================================================
# Hook Registration
# =============================================================================

# Register a global tmux hook
# Usage: register_hook "after-select-pane" "run-shell 'echo selected'"
register_hook() {
    local hook_name="$1"
    local command="$2"

    [[ -z "$hook_name" || -z "$command" ]] && {
        log_error "hooks" "register_hook requires hook_name and command"
        return 1
    }

    # Use -g for global hooks
    tmux set-hook -g "$hook_name" "$command" 2>/dev/null || {
        log_error "hooks" "Failed to register hook: $hook_name"
        return 1
    }

    log_debug "hooks" "Registered hook: $hook_name"
    return 0
}

# Register a window/pane local hook
# Usage: register_hook_local "after-select-pane" "run-shell 'echo selected'"
register_hook_local() {
    local hook_name="$1"
    local command="$2"

    [[ -z "$hook_name" || -z "$command" ]] && {
        log_error "hooks" "register_hook_local requires hook_name and command"
        return 1
    }

    # Without -g for local hooks
    tmux set-hook "$hook_name" "$command" 2>/dev/null || {
        log_error "hooks" "Failed to register local hook: $hook_name"
        return 1
    }

    log_debug "hooks" "Registered local hook: $hook_name"
    return 0
}

# Unregister a global hook
# Usage: unregister_hook "after-select-pane"
unregister_hook() {
    local hook_name="$1"

    [[ -z "$hook_name" ]] && {
        log_error "hooks" "unregister_hook requires hook_name"
        return 1
    }

    tmux set-hook -gu "$hook_name" 2>/dev/null || {
        log_warn "hooks" "Hook not found or already removed: $hook_name"
        return 1
    }

    log_debug "hooks" "Unregistered hook: $hook_name"
    return 0
}

# Unregister a local hook
# Usage: unregister_hook_local "after-select-pane"
unregister_hook_local() {
    local hook_name="$1"

    [[ -z "$hook_name" ]] && {
        log_error "hooks" "unregister_hook_local requires hook_name"
        return 1
    }

    tmux set-hook -u "$hook_name" 2>/dev/null || {
        log_warn "hooks" "Local hook not found or already removed: $hook_name"
        return 1
    }

    log_debug "hooks" "Unregistered local hook: $hook_name"
    return 0
}

# =============================================================================
# Hook Management
# =============================================================================

# List all registered hooks
# Usage: list_hooks
list_hooks() {
    tmux show-hooks -g 2>/dev/null
}

# Check if a hook is registered
# Usage: has_hook "after-select-pane"
has_hook() {
    local hook_name="$1"

    [[ -z "$hook_name" ]] && return 1

    tmux show-hooks -g 2>/dev/null | grep -q "^$hook_name " && return 0
    return 1
}

# Clear all PowerKit-related hooks
# Usage: clear_all_hooks
clear_all_hooks() {
    local hooks=("after-select-pane" "pane-focus-in" "pane-focus-out")

    for hook in "${hooks[@]}"; do
        unregister_hook "$hook" 2>/dev/null || true
    done

    log_info "hooks" "Cleared all PowerKit hooks"
}

# =============================================================================
# Delayed Commands
# =============================================================================

# Run a command after a delay (in seconds)
# Usage: run_delayed "tmux set -w window-active-style ''" "0.1"
run_delayed() {
    local command="$1"
    local delay="${2:-0.1}"

    [[ -z "$command" ]] && {
        log_error "hooks" "run_delayed requires a command"
        return 1
    }

    # Use bash subshell with sleep
    (sleep "$delay" && eval "$command") &
    disown 2>/dev/null || true

    return 0
}

# Run a command after a delay (in milliseconds)
# Usage: run_delayed_ms "tmux set -w window-active-style ''" "100"
run_delayed_ms() {
    local command="$1"
    local delay_ms="${2:-100}"

    # Convert ms to seconds (using bc for floating point)
    local delay_s
    if command -v bc &>/dev/null; then
        delay_s=$(echo "scale=3; $delay_ms / 1000" | bc)
    else
        # Fallback: integer division (loses precision for < 1000ms)
        delay_s="0.${delay_ms}"
    fi

    run_delayed "$command" "$delay_s"
}

# =============================================================================
# Hook Command Builders
# =============================================================================

# Build a run-shell command for hooks
# Usage: build_run_shell_cmd "/path/to/script arg1 arg2"
build_run_shell_cmd() {
    local script="$1"
    printf 'run-shell "%s"' "$script"
}

# Build a delayed reset command (common pattern for flash effects)
# Usage: build_delayed_reset_cmd "window-active-style" "" "0.1"
build_delayed_reset_cmd() {
    local option="$1"
    local reset_value="${2:-}"
    local delay="${3:-0.1}"

    if [[ -n "$reset_value" ]]; then
        printf 'run-shell "sleep %s && tmux set -w %s \"%s\""' "$delay" "$option" "$reset_value"
    else
        printf 'run-shell "sleep %s && tmux set -w %s"' "$delay" "$option"
    fi
}
