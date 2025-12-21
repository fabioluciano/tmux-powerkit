#!/usr/bin/env bash
# =============================================================================
# Plugin: smartkey
# Description: Display hardware key touch indicator (YubiKey, SoloKeys, Nitrokey)
# Dependencies: None (uses system indicators)
# =============================================================================
# Only shows when hardware key is actively waiting for touch interaction.
# Uses multiple detection methods to minimize false positives.
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_cmd "gpg-connect-agent" || return 1
    require_cmd "pcsc_scan" 1  # Optional
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show_when_inactive" "bool" "false" "Show plugin when not waiting"

    # Icons
    declare_option "icon" "icon" $'\U000F0084' "Plugin icon"
    declare_option "waiting_icon" "icon" "" "Icon when waiting for touch"

    # Colors - Waiting state
    declare_option "waiting_accent_color" "color" "error" "Background color when waiting"
    declare_option "waiting_accent_color_icon" "color" "error" "Icon background when waiting"

    # Cache
    declare_option "cache_ttl" "number" "2" "Cache duration in seconds"
}

plugin_init "smartkey"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    if [[ -n "$content" ]]; then
        local icon accent accent_icon
        icon=$(get_option "waiting_icon")
        accent=$(get_option "waiting_accent_color")
        accent_icon=$(get_option "waiting_accent_color_icon")
        build_display_info "1" "$accent" "$accent_icon" "$icon"
    else
        build_display_info "0" "" "" ""
    fi
}

# =============================================================================
# YubiKey Touch Detection
# =============================================================================

# Method 1: Check for yubikey-touch-detector (most reliable if installed)
# https://github.com/maximbaz/yubikey-touch-detector
_check_yubikey_touch_detector() {
    # Check if the socket exists and has pending notification
    local socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/yubikey-touch-detector.socket"
    [[ -S "$socket" ]] || return 1

    # Check if detector process indicates waiting state
    local state_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/yubikey-touch-detector.state"
    if [[ -f "$state_file" ]]; then
        local state
        state=$(cat "$state_file" 2>/dev/null)
        [[ "$state" == "1" || "$state" == "GPG" || "$state" == "U2F" ]] && return 0
    fi

    return 1
}

# Method 2: Check for gpg-agent waiting for card (specific pinentry prompt)
# Only triggers when pinentry is specifically waiting for smartcard PIN/touch
_check_gpg_card_prompt() {
    # Look for pinentry processes with smartcard-related prompts
    # pinentry shows specific window titles when waiting for card
    if is_macos; then
        # macOS: check for pinentry-mac with card prompt
        pgrep -f "pinentry-mac" &>/dev/null || return 1
        # Verify it's actually waiting (has a window)
        osascript -e 'tell application "System Events" to return (name of processes) contains "pinentry-mac"' 2>/dev/null | grep -q "true"
    else
        # Linux: check for pinentry with specific card-related environment
        local pinentry_pid
        pinentry_pid=$(pgrep -f "pinentry" 2>/dev/null | head -1) || return 1

        # Check if pinentry has TTY (interactive prompt active)
        [[ -d "/proc/$pinentry_pid/fd" ]] || return 1
        # Use find instead of ls|grep to check for tty/pts file descriptors
        find -L "/proc/$pinentry_pid/fd" -maxdepth 1 -type c 2>/dev/null | while read -r fd; do
            [[ "$(readlink "$fd" 2>/dev/null)" =~ (tty|pts) ]] && exit 0
        done && return 0
        return 1
    fi
}

# Method 3: Check for SSH FIDO2 authentication waiting
# ssh-agent prompts for FIDO2 key touch with specific behavior
_check_ssh_fido_waiting() {
    # Look for ssh-sk-helper process (FIDO2/U2F authenticator helper)
    pgrep -f "ssh-sk-helper" &>/dev/null && return 0

    # Alternative: check for libfido2 waiting
    pgrep -f "fido2-" &>/dev/null && return 0

    return 1
}

# Method 4: Check YubiKey Manager notification (ykman)
_check_ykman_waiting() {
    # ykman sometimes spawns helper processes when waiting
    pgrep -f "ykman.*--wait" &>/dev/null
}

# Method 5: Check for active CCID transaction (low-level)
# PC/SC daemon shows specific state when card is being accessed
_check_pcscd_waiting() {
    has_cmd pcsc_scan || return 1

    # Check if pcscd is running
    pgrep -f "pcscd" &>/dev/null || return 1

    # Check for recent card activity (file modification)
    local pcsc_dir="/var/run/pcscd"
    [[ -d "$pcsc_dir" ]] || return 1

    # Only return true if there's very recent activity (within 2 seconds)
    find "$pcsc_dir" -type s -mmin -0.05 2>/dev/null | grep -q . && return 0

    return 1
}

# Method 6: Check gpg-agent scdaemon for PKSIGN/PKAUTH waiting
# This is more specific than just checking if scdaemon is busy
_check_scdaemon_signing() {
    has_cmd gpg-connect-agent || return 1

    # Quick check: is scdaemon even running?
    pgrep -f "scdaemon" &>/dev/null || return 1

    # Check if gpg-agent is in a blocked state waiting for card
    # GETINFO scd_running returns quickly if not blocked
    local start end elapsed
    start=$(date +%s%N)
    timeout 0.3 gpg-connect-agent "SCD GETINFO status" /bye &>/dev/null 2>&1
    local result_code=$?
    end=$(date +%s%N)

    # If command timed out or took > 200ms, likely waiting for user
    if [[ $result_code -eq 124 ]]; then
        return 0  # Timeout = blocked waiting
    fi

    elapsed=$(( (end - start) / 1000000 ))  # Convert to ms
    [[ $elapsed -gt 200 ]] && return 0

    return 1
}

# =============================================================================
# Main Logic
# =============================================================================

_is_waiting_for_touch() {
    # Priority order (most reliable first):
    # 1. yubikey-touch-detector (explicit touch detection daemon)
    # 2. ssh-sk-helper (FIDO2 SSH authentication)
    # 3. gpg card prompt (pinentry for smartcard)
    # 4. scdaemon signing (GPG smartcard operation)
    # 5. ykman waiting

    _check_yubikey_touch_detector && return 0
    _check_ssh_fido_waiting && return 0
    _check_gpg_card_prompt && return 0
    _check_scdaemon_signing && return 0
    _check_ykman_waiting && return 0

    return 1
}

load_plugin() {
    # Very short cache TTL since touch state changes quickly
    local cached
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL") && { printf '%s' "$cached"; return 0; }

    local result=""
    _is_waiting_for_touch && result="TOUCH"

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
