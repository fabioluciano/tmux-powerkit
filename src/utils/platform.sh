#!/usr/bin/env bash
# =============================================================================
# PowerKit Utils: Platform
# Description: OS and platform detection utilities
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_platform" && return 0

# =============================================================================
# Cached Values
# =============================================================================

declare -g _CACHED_OS=""
declare -g _CACHED_DISTRO=""

# =============================================================================
# OS Detection
# =============================================================================

# Get OS name (cached)
# Usage: get_os
# Returns: darwin, linux, freebsd, etc.
get_os() {
    if [[ -z "$_CACHED_OS" ]]; then
        local os_raw
        os_raw=$(uname -s)
        _CACHED_OS="${os_raw,,}"  # Bash 4.0+ lowercase
    fi
    printf '%s' "$_CACHED_OS"
}

# Check if running on macOS
# Usage: is_macos && echo "macOS"
is_macos() {
    [[ "$(get_os)" == "darwin" ]]
}

# Check if running on Linux
# Usage: is_linux && echo "Linux"
is_linux() {
    [[ "$(get_os)" == "linux" ]]
}

# Check if running on FreeBSD
# Usage: is_freebsd && echo "FreeBSD"
is_freebsd() {
    [[ "$(get_os)" == "freebsd" ]]
}

# Check if running on WSL (Windows Subsystem for Linux)
# Usage: is_wsl && echo "WSL"
is_wsl() {
    is_linux && [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null
}

# =============================================================================
# Linux Distribution Detection
# =============================================================================

# Get Linux distribution name (cached)
# Usage: get_distro
# Returns: ubuntu, debian, fedora, arch, etc.
get_distro() {
    if [[ -n "$_CACHED_DISTRO" ]]; then
        printf '%s' "$_CACHED_DISTRO"
        return
    fi

    if ! is_linux; then
        _CACHED_DISTRO="none"
        printf '%s' "$_CACHED_DISTRO"
        return
    fi

    # Try /etc/os-release first (most reliable)
    if [[ -f /etc/os-release ]]; then
        _CACHED_DISTRO=$(. /etc/os-release && echo "${ID:-unknown}")
    # Try lsb_release
    elif command -v lsb_release &>/dev/null; then
        local distro_raw
        distro_raw=$(lsb_release -is 2>/dev/null)
        _CACHED_DISTRO="${distro_raw,,}"  # Bash 4.0+ lowercase
    # Fallback to checking specific files
    elif [[ -f /etc/debian_version ]]; then
        _CACHED_DISTRO="debian"
    elif [[ -f /etc/fedora-release ]]; then
        _CACHED_DISTRO="fedora"
    elif [[ -f /etc/arch-release ]]; then
        _CACHED_DISTRO="arch"
    else
        _CACHED_DISTRO="unknown"
    fi

    printf '%s' "$_CACHED_DISTRO"
}

# Distribution family checks
is_debian_based() {
    local distro
    distro=$(get_distro)
    [[ "$distro" == "debian" || "$distro" == "ubuntu" || "$distro" == "linuxmint" || "$distro" == "pop" ]]
}

is_fedora_based() {
    local distro
    distro=$(get_distro)
    [[ "$distro" == "fedora" || "$distro" == "centos" || "$distro" == "rhel" || "$distro" == "rocky" || "$distro" == "alma" ]]
}

is_arch_based() {
    local distro
    distro=$(get_distro)
    [[ "$distro" == "arch" || "$distro" == "manjaro" || "$distro" == "endeavouros" ]]
}

# =============================================================================
# Command Availability
# =============================================================================

# Check if a command exists
# Usage: has_cmd "git" && echo "git available"
has_cmd() {
    command -v "$1" &>/dev/null
}

# Get path to a command or empty string
# Usage: cmd_path=$(get_cmd_path "git")
get_cmd_path() {
    command -v "$1" 2>/dev/null || true
}

# =============================================================================
# Architecture Detection
# =============================================================================

# Get CPU architecture
# Usage: get_arch
# Returns: x86_64, arm64, i386, etc.
get_arch() {
    uname -m
}

# Check if 64-bit
is_64bit() {
    local arch
    arch=$(get_arch)
    [[ "$arch" == "x86_64" || "$arch" == "amd64" || "$arch" == "arm64" || "$arch" == "aarch64" ]]
}

# Check if ARM
is_arm() {
    local arch
    arch=$(get_arch)
    [[ "$arch" == arm* || "$arch" == "aarch64" ]]
}

# =============================================================================
# macOS Hardware Detection
# =============================================================================

# Cached values for macOS hardware
declare -g _CACHED_MAC_MODEL=""
declare -g _CACHED_MAC_CHIP=""

# Get Mac model identifier (cached)
# Usage: get_mac_model
# Returns: MacBookPro18,1, MacBookAir10,1, iMac21,1, etc.
get_mac_model() {
    if [[ -z "$_CACHED_MAC_MODEL" ]]; then
        if is_macos; then
            _CACHED_MAC_MODEL=$(sysctl -n hw.model 2>/dev/null || echo "")
        fi
    fi
    printf '%s' "$_CACHED_MAC_MODEL"
}

# Get Mac chip name (cached)
# Usage: get_mac_chip
# Returns: Apple M1, Apple M2 Pro, Apple M3 Max, Intel Core i7, etc.
get_mac_chip() {
    if [[ -z "$_CACHED_MAC_CHIP" ]]; then
        if is_macos; then
            _CACHED_MAC_CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "")
        fi
    fi
    printf '%s' "$_CACHED_MAC_CHIP"
}

# Check if running on Apple Silicon (M1, M2, M3, etc.)
# Usage: is_apple_silicon && echo "Apple Silicon"
is_apple_silicon() {
    is_macos || return 1
    local arch chip
    arch=$(get_arch)
    # Primary check: ARM architecture on macOS
    [[ "$arch" == "arm64" ]] && return 0
    # Fallback: check CPU brand string
    chip=$(get_mac_chip)
    [[ "$chip" == Apple* ]] && return 0
    return 1
}

# Check if running on Intel Mac
# Usage: is_intel_mac && echo "Intel Mac"
is_intel_mac() {
    is_macos || return 1
    local arch
    arch=$(get_arch)
    [[ "$arch" == "x86_64" ]]
}

# Check if running on a MacBook Air
# Usage: is_macbook_air && echo "MacBook Air"
# Note: Newer MacBook Air models (M2+) use Mac* identifiers instead of MacBookAir*
is_macbook_air() {
    is_macos || return 1
    local model
    model=$(get_mac_model)

    # Traditional MacBook Air identifiers (M1 and earlier)
    [[ "$model" == MacBookAir* ]] && return 0

    # MacBook Air M2 (13" and 15")
    [[ "$model" == "Mac14,2" || "$model" == "Mac14,15" ]] && return 0

    # MacBook Air M3 (13" and 15")
    [[ "$model" == "Mac15,12" || "$model" == "Mac15,13" ]] && return 0

    # MacBook Air M4 (13" and 15")
    [[ "$model" == "Mac16,12" || "$model" == "Mac16,13" ]] && return 0

    return 1
}

# Check if running on a fanless Mac (MacBook Air, some Mac mini, iPad-based)
# Usage: is_fanless_mac && echo "Fanless Mac"
is_fanless_mac() {
    is_macos || return 1

    # All MacBook Air models with Apple Silicon are fanless
    is_macbook_air && is_apple_silicon && return 0

    # Mac mini M1 base model is fanless (Macmini9,1)
    # Note: Mac mini M2/M2 Pro has a fan
    local model
    model=$(get_mac_model)
    [[ "$model" == "Macmini9,1" ]] && return 0

    return 1
}

# =============================================================================
# Environment Detection
# =============================================================================

# Check if running inside tmux
is_in_tmux() {
    [[ -n "${TMUX:-}" ]]
}

# Check if running in a terminal
is_interactive() {
    [[ -t 0 ]]
}

# Get terminal emulator name
get_terminal() {
    # Try TERM_PROGRAM first (macOS)
    if [[ -n "${TERM_PROGRAM:-}" ]]; then
        printf '%s' "$TERM_PROGRAM"
        return
    fi

    # Check common terminal environment variables
    if [[ -n "${KITTY_WINDOW_ID:-}" ]]; then
        printf 'kitty'
    elif [[ -n "${ALACRITTY_SOCKET:-}" ]]; then
        printf 'alacritty'
    elif [[ -n "${WEZTERM_PANE:-}" ]]; then
        printf 'wezterm'
    elif [[ -n "${GNOME_TERMINAL_SCREEN:-}" ]]; then
        printf 'gnome-terminal'
    else
        printf '%s' "${TERM:-unknown}"
    fi
}

# =============================================================================
# System Information
# =============================================================================

# Get hostname (short form)
# Usage: get_hostname
get_hostname() {
    hostname -s 2>/dev/null || hostname | cut -d. -f1
}

# Get hostname (full form with domain)
# Usage: get_hostname_full
get_hostname_full() {
    hostname -f 2>/dev/null || hostname
}

# Get current user
# Usage: get_current_user
get_current_user() {
    printf '%s' "${USER:-${USERNAME:-unknown}}"
}

# Get shell name
# Usage: get_shell
get_shell() {
    basename "${SHELL:-/bin/sh}"
}

# =============================================================================
# OS/Distro Icons (Nerd Fonts)
# =============================================================================

# Get OS/Distro icon based on current platform
# Usage: get_os_icon
# Returns: Nerd Font icon for the current OS/distro
get_os_icon() {
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
