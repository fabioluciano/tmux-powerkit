#!/usr/bin/env bash
# =============================================================================
# Plugin: smartkey
# Description: Display hardware key touch indicator (YubiKey, SoloKeys, Nitrokey)
# Dependencies: gpg-connect-agent (optional), pcsc_scan (optional)
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Hardware key is waiting for touch
#   - inactive: No key is waiting for touch
#
# Health:
#   - error: Key is waiting for touch (urgent attention needed)
#   - ok: No key activity
#
# Context:
#   - waiting: Key is waiting for touch interaction
#   - idle: No key activity
#
# =============================================================================
# Only shows when hardware key is actively waiting for touch interaction.
# Uses multiple detection methods to minimize false positives.
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "smartkey"
    metadata_set "name" "SmartKey"
    metadata_set "description" "Hardware key touch indicator (YubiKey, SoloKeys, Nitrokey)"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    # All dependencies are optional - different detection methods use different tools
    require_cmd "gpg-connect-agent" 1  # Optional: for scdaemon checks
    require_cmd "pcsc_scan" 1          # Optional: for PCSC checks
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U000F0237' "Default plugin icon (key)"
    declare_option "icon_waiting" "icon" $'\U000F0237' "Icon when waiting for touch"

    # Cache - very short TTL since touch state changes quickly
    declare_option "cache_ttl" "number" "2" "Cache duration in seconds"
}

# =============================================================================
# YubiKey Touch Detection Methods
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

# Method 3: Check for SSH/FIDO2 operations waiting for hardware key
_check_ssh_fido_waiting() {
    # Generic: any ssh-keygen process (stays active only while waiting for touch)
    # This catches: -Y sign (git signing), -K (resident keys), etc.
    pgrep -x "ssh-keygen" &>/dev/null && return 0

    # ssh-sk-helper: FIDO2/U2F authenticator helper for SSH auth
    pgrep -f "ssh-sk-helper" &>/dev/null && return 0

    # libfido2 tools
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
    # EPOCHREALTIME format: seconds.microseconds (e.g., 1704412800.123456)
    local start_us=${EPOCHREALTIME//./}
    timeout 0.3 gpg-connect-agent "SCD GETINFO status" /bye &>/dev/null 2>&1
    local result_code=$?
    local end_us=${EPOCHREALTIME//./}

    # If command timed out or took > 200ms, likely waiting for user
    if [[ $result_code -eq 124 ]]; then
        return 0  # Timeout = blocked waiting
    fi

    # Convert elapsed from microseconds to milliseconds
    local elapsed_ms=$(( (end_us - start_us) / 1000 ))
    [[ $elapsed_ms -gt 200 ]] && return 0

    return 1
}

# =============================================================================
# Generic Detection: Check if YubiKey is in transaction (LED blinking)
# =============================================================================

# Most generic method: check if YubiKey USB device is busy (transaction in progress)
_check_smartcard_transaction() {
    if is_macos; then
        # Check ioreg for YubiKey with busy > 0 (active transaction)
        # Format: "busy N" where N > 0 means device is in use
        local busy_count
        busy_count=$(ioreg -p IOUSB -l -w0 2>/dev/null | \
            grep -A50 "YubiKey" | \
            grep -o "busy [0-9]*" | \
            awk '{sum += $2} END {print sum+0}')
        [[ "$busy_count" -gt 0 ]] && return 0
    else
        # Linux: check /sys/class/hidraw for active YubiKey device
        for hidraw in /sys/class/hidraw/hidraw*/device/uevent; do
            if grep -q "Yubico" "$hidraw" 2>/dev/null; then
                # Check if device is open by any process
                local dev="/dev/$(basename "$(dirname "$(dirname "$hidraw")")")"
                lsof "$dev" &>/dev/null && return 0
            fi
        done
    fi

    return 1
}

# Main detection orchestrator - checks all methods in priority order
_is_waiting_for_touch() {
    # 1. yubikey-touch-detector daemon (most reliable if installed)
    _check_yubikey_touch_detector && return 0

    # 2. Generic: any ssh-keygen process (blocked waiting for touch)
    _check_ssh_fido_waiting && return 0

    # 3. GPG pinentry waiting for card
    _check_gpg_card_prompt && return 0

    # 4. scdaemon blocked on crypto operation
    _check_scdaemon_signing && return 0

    # 5. ykman waiting
    _check_ykman_waiting && return 0

    # 6. Generic smartcard transaction detection
    _check_smartcard_transaction && return 0

    return 1
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    if _is_waiting_for_touch; then
        plugin_data_set "waiting" "1"
    else
        plugin_data_set "waiting" "0"
    fi
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() {
    printf 'dynamic'
}

plugin_get_presence() {
    # Only show when key is waiting for touch
    printf 'conditional'
}

# =============================================================================
# Plugin Contract: State
# =============================================================================

plugin_get_state() {
    local waiting
    waiting=$(plugin_data_get "waiting")
    [[ "$waiting" == "1" ]] && printf 'active' || printf 'inactive'
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================
# When key is waiting for touch, it's urgent (error level) to get attention

plugin_get_health() {
    local waiting
    waiting=$(plugin_data_get "waiting")
    [[ "$waiting" == "1" ]] && printf 'error' || printf 'ok'
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================

plugin_get_context() {
    local waiting
    waiting=$(plugin_data_get "waiting")
    [[ "$waiting" == "1" ]] && printf 'waiting' || printf 'idle'
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() {
    local waiting
    waiting=$(plugin_data_get "waiting")

    if [[ "$waiting" == "1" ]]; then
        local icon_waiting
        icon_waiting=$(get_option "icon_waiting")
        [[ -n "$icon_waiting" ]] && printf '%s' "$icon_waiting" || get_option "icon"
    else
        get_option "icon"
    fi
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local waiting
    waiting=$(plugin_data_get "waiting")

    # Only render when waiting for touch
    [[ "$waiting" == "1" ]] && printf 'TOUCH'
}

