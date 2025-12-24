#!/usr/bin/env bash
# =============================================================================
# PowerKit Renderer: Icon Resolver
# Description: Resolves icons based on state, health, context, and platform
# =============================================================================
# This module handles ALL icon resolution logic:
# - OS/Distro icons (for session segment)
# - Plugin icons (based on state/health/context)
# - Window icons
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "renderer_icon_resolver" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/utils/platform.sh"

# =============================================================================
# OS/Distro Icons (for session segment with @powerkit_session_icon="auto")
# =============================================================================

# Get OS/Distro icon based on current platform
# Usage: resolve_os_icon
# Returns: Nerd Font icon for the current OS/distro
resolve_os_icon() {
    local os distro

    os=$(get_os)

    case "$os" in
        darwin)
            # macOS - Apple icon
            printf '%s' $'\uf302'
            ;;
        linux)
            distro=$(get_distro)
            case "$distro" in
                ubuntu)         printf '%s' $'\uf31b' ;;
                debian)         printf '%s' $'\uf306' ;;
                fedora)         printf '%s' $'\uf30a' ;;
                arch|archarm)   printf '%s' $'\uf303' ;;
                manjaro)        printf '%s' $'\uf312' ;;
                centos)         printf '%s' $'\uf304' ;;
                rhel|redhat)    printf '%s' $'\uf304' ;;
                opensuse*)      printf '%s' $'\uf314' ;;
                alpine)         printf '%s' $'\uf300' ;;
                gentoo)         printf '%s' $'\uf30d' ;;
                linuxmint|mint) printf '%s' $'\uf30e' ;;
                elementary)     printf '%s' $'\uf309' ;;
                pop|pop_os)     printf '%s' $'\uf32a' ;;
                kali)           printf '%s' $'\uf327' ;;
                void)           printf '%s' $'\uf32e' ;;
                nixos|nix)      printf '%s' $'\uf313' ;;
                raspbian)       printf '%s' $'\uf315' ;;
                rocky)          printf '%s' $'\uf32b' ;;
                alma|almalinux) printf '%s' $'\uf31d' ;;
                endeavouros)    printf '%s' $'\uf322' ;;
                garuda)         printf '%s' $'\uf337' ;;
                artix)          printf '%s' $'\uf31f' ;;
                *)              printf '%s' $'\uf31a' ;;  # Generic Linux
            esac
            ;;
        freebsd)
            printf '%s' $'\uf30c'
            ;;
        openbsd|netbsd)
            printf '%s' $'\uf328'
            ;;
        *)
            # Unknown - use generic terminal icon
            printf '%s' $'\uf11c'
            ;;
    esac
}

# =============================================================================
# Session Icon Resolution
# =============================================================================

# Resolve session icon based on user configuration
# Usage: resolve_session_icon
# Returns: Icon character for session segment
resolve_session_icon() {
    local session_icon
    session_icon=$(get_tmux_option "@powerkit_session_icon" "${POWERKIT_DEFAULT_SESSION_ICON}")

    if [[ "$session_icon" == "auto" ]]; then
        resolve_os_icon
    else
        printf '%s' "$session_icon"
    fi
}

# =============================================================================
# Window Icon Resolution
# =============================================================================

# Resolve window icon based on window state
# Usage: resolve_window_icon "active|inactive" "is_zoomed"
# Returns: Icon character for window
resolve_window_icon() {
    local state="$1"
    local is_zoomed="${2:-false}"

    if [[ "$is_zoomed" == "true" || "$is_zoomed" == "1" ]]; then
        get_tmux_option "@powerkit_zoomed_window_icon" "${POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON}"
        return
    fi

    if [[ "$state" == "active" ]]; then
        get_tmux_option "@powerkit_active_window_icon" "${POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON}"
    else
        get_tmux_option "@powerkit_inactive_window_icon" "${POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON}"
    fi
}
