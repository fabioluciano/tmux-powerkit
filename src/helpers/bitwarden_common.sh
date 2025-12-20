#!/usr/bin/env bash
# =============================================================================
# Bitwarden Common Functions
# =============================================================================
# Shared functionality for Bitwarden helpers (password & TOTP selectors).
# Eliminates code duplication between bitwarden_password_selector.sh and
# bitwarden_totp_selector.sh.
#
# FUNCTIONS PROVIDED:
#   - Session: get_bw_session(), save_bw_session(), clear_bw_session(), load_bw_session()
#   - Client: detect_bitwarden_client()
#   - Status: is_bitwarden_unlocked_bw(), is_bitwarden_unlocked_rbw()
#   - Cache: is_bitwarden_cache_valid(), invalidate_bitwarden_plugin_cache()
#   - Unlock: unlock_bitwarden_vault(), print_bitwarden_unlock_header()
#   - Lock: lock_bitwarden_vault()
#
# DEPENDENCIES: helper_bootstrap.sh (for utils.sh, cache.sh, etc.)
# =============================================================================

# Source guard
_BITWARDEN_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_BITWARDEN_COMMON_ROOT="$_BITWARDEN_COMMON_DIR/.."
# shellcheck source=src/source_guard.sh
. "$_BITWARDEN_COMMON_ROOT/source_guard.sh"
source_guard "bitwarden_common" && return 0

# Ensure utils.sh is loaded for toast, log functions, etc.
if ! command -v toast &>/dev/null; then
    # shellcheck source=src/helper_bootstrap.sh
    . "$_BITWARDEN_COMMON_ROOT/helper_bootstrap.sh"
fi

# =============================================================================
# Constants
# =============================================================================

BITWARDEN_PLUGIN_STATUS_CACHE="${POWERKIT_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit}/bitwarden.cache"

# =============================================================================
# BW Session Management (tmux environment)
# =============================================================================

# Get BW_SESSION from tmux environment
# Returns: session token or empty string
get_bw_session() {
    local session output
    output=$(tmux show-environment BW_SESSION 2>/dev/null) || true
    # Filter out unset marker (-BW_SESSION) and extract value
    if [[ -n "$output" && "$output" != "-BW_SESSION" ]]; then
        session="${output#BW_SESSION=}"
        [[ -n "$session" ]] && echo "$session"
    fi
}

# Save BW_SESSION to tmux environment
# Usage: save_bw_session "session_token"
save_bw_session() {
    local session="$1"
    tmux set-environment BW_SESSION "$session" 2>/dev/null
}

# Clear BW_SESSION from tmux environment
clear_bw_session() {
    tmux set-environment -u BW_SESSION 2>/dev/null || true
}

# Load BW_SESSION into current shell
# Usage: load_bw_session (exports BW_SESSION if found)
load_bw_session() {
    local session
    session=$(get_bw_session) || true
    [[ -n "$session" ]] && export BW_SESSION="$session"
    return 0
}

# =============================================================================
# Client Detection & Status
# =============================================================================

# Detect which Bitwarden client is available
# Returns: "bw" or "rbw", exit 1 if neither found
detect_bitwarden_client() {
    command -v bw &>/dev/null && { echo "bw"; return 0; }
    command -v rbw &>/dev/null && { echo "rbw"; return 0; }
    return 1
}

# Check if vault is unlocked (bw)
is_bitwarden_unlocked_bw() {
    load_bw_session
    local status
    status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    [[ "$status" == "unlocked" ]]
}

# Check if vault is unlocked (rbw)
is_bitwarden_unlocked_rbw() {
    rbw unlocked 2>/dev/null
}

# =============================================================================
# Cache Management
# =============================================================================

# Check if cache file is valid based on TTL
# Usage: is_bitwarden_cache_valid <cache_file> <ttl_seconds>
# Returns: 0 if valid, 1 if expired or not found
is_bitwarden_cache_valid() {
    local cache_file="$1"
    local ttl="${2:-600}"

    [[ -f "$cache_file" ]] || return 1

    local file_mtime
    file_mtime=$(get_file_mtime "$cache_file") || return 1
    [[ "$file_mtime" == "-1" ]] && return 1

    local now age
    now=$(date +%s)
    age=$((now - file_mtime))

    (( age < ttl ))
}

# Invalidate plugin status cache to trigger status bar refresh
invalidate_bitwarden_plugin_cache() {
    rm -f "$BITWARDEN_PLUGIN_STATUS_CACHE" 2>/dev/null || true
    tmux refresh-client -S 2>/dev/null || true
}

# =============================================================================
# Unlock Vault UI
# =============================================================================

# Print unlock header
# Usage: print_bitwarden_unlock_header "client_name"
print_bitwarden_unlock_header() {
    local client="$1"
    printf '\033[1;36m'
    printf '╭─────────────────────────────────────╮\n'
    printf '│      🔐 Bitwarden Vault Unlock      │\n'
    printf '╰─────────────────────────────────────╯\033[0m\n'
    printf '\n'
    printf '\033[2mClient: %s\033[0m\n\n' "$client"
}

# Unlock vault (bw)
_unlock_bitwarden_bw() {
    print_bitwarden_unlock_header "bw (official CLI)"

    # Check current status first
    load_bw_session
    local status
    status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

    case "$status" in
        unlocked)
            printf '\033[1;32m✓ Vault already unlocked\033[0m\n'
            sleep 1
            return 0
            ;;
        unauthenticated)
            printf '\033[1;31m✗ Please login first: bw login\033[0m\n'
            printf '\n\033[2mPress any key to close...\033[0m'
            read -rsn1
            return 1
            ;;
        locked)
            # Prompt for master password and unlock
            printf '\033[1;37mEnter master password:\033[0m '
            local password
            read -rs password
            echo

            if [[ -z "$password" ]]; then
                printf '\033[1;31m✗ Password required\033[0m\n'
                sleep 1
                return 1
            fi

            printf '\033[33m⏳ Unlocking vault...\033[0m\n'
            local session
            session=$(bw unlock --raw "$password" 2>/dev/null) || true

            if [[ -n "$session" ]]; then
                save_bw_session "$session"
                export BW_SESSION="$session"
                invalidate_bitwarden_plugin_cache
                printf '\033[1;32m✓ Vault unlocked!\033[0m\n'
                toast " Vault unlocked" "simple"
                sleep 1
                return 0
            else
                printf '\033[1;31m✗ Invalid password\033[0m\n'
                printf '\n\033[2mPress any key to try again or Ctrl-C to cancel...\033[0m'
                read -rsn1
                # Clear screen and retry
                clear
                _unlock_bitwarden_bw
                return $?
            fi
            ;;
        *)
            printf '\033[1;31m✗ Unknown status: %s\033[0m\n' "$status"
            printf '\n\033[2mPress any key to close...\033[0m'
            read -rsn1
            return 1
            ;;
    esac
}

# Unlock vault (rbw)
_unlock_bitwarden_rbw() {
    print_bitwarden_unlock_header "rbw (unofficial Rust client)"

    if rbw unlocked 2>/dev/null; then
        printf '\033[1;32m✓ Vault already unlocked\033[0m\n'
        sleep 1
        return 0
    fi

    printf '\033[2mrbw will prompt for your password...\033[0m\n\n'
    # rbw unlock handles its own prompting
    if rbw unlock 2>/dev/null; then
        invalidate_bitwarden_plugin_cache
        printf '\033[1;32m✓ Vault unlocked!\033[0m\n'
        toast " Vault unlocked" "simple"
        sleep 1
        return 0
    else
        printf '\033[1;31m✗ Failed to unlock\033[0m\n'
        printf '\n\033[2mPress any key to close...\033[0m'
        read -rsn1
        return 1
    fi
}

# Unlock vault (auto-detect client)
# Returns: 0 on success, 1 on failure
unlock_bitwarden_vault() {
    local client
    client=$(detect_bitwarden_client) || {
        printf '\033[1;31m✗ bw/rbw not found\033[0m\n'
        printf '\033[2mInstall Bitwarden CLI (bw) or rbw\033[0m\n'
        printf '\n\033[2mPress any key to close...\033[0m'
        read -rsn1
        return 1
    }

    case "$client" in
        bw)  _unlock_bitwarden_bw ;;
        rbw) _unlock_bitwarden_rbw ;;
    esac
}

# =============================================================================
# Lock Vault
# =============================================================================

# Lock vault (bw)
_lock_bitwarden_bw() {
    load_bw_session
    bw lock &>/dev/null || true
    clear_bw_session
    invalidate_bitwarden_plugin_cache
}

# Lock vault (rbw)
_lock_bitwarden_rbw() {
    rbw lock &>/dev/null || true
    invalidate_bitwarden_plugin_cache
}

# Lock vault (auto-detect client)
# Usage: lock_bitwarden_vault
lock_bitwarden_vault() {
    local client
    client=$(detect_bitwarden_client) || { toast " bw/rbw not found" "simple"; return 1; }

    case "$client" in
        bw)  _lock_bitwarden_bw ;;
        rbw) _lock_bitwarden_rbw ;;
    esac

    toast " Vault locked" "simple"
}
