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
# DEPENDENCIES: helper_contract.sh or powerkit_bootstrap_minimal
# =============================================================================

# Source guard and bootstrap
_BITWARDEN_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_BITWARDEN_COMMON_ROOT="$_BITWARDEN_COMMON_DIR/../.."

# shellcheck source=src/core/guard.sh
. "$_BITWARDEN_COMMON_ROOT/src/core/guard.sh"
source_guard "bitwarden_common" && return 0

# Source framework utilities (toast, cache, platform, etc.)
# Only bootstrap if not already loaded via helper_base
if ! type toast &>/dev/null; then
    # shellcheck source=src/core/bootstrap.sh
    . "$_BITWARDEN_COMMON_ROOT/src/core/bootstrap.sh"
    powerkit_bootstrap_minimal
fi

# =============================================================================
# Constants
# =============================================================================

# Cache key for bitwarden plugin data (used with cache API)
BITWARDEN_PLUGIN_CACHE_KEY="plugin_bitwarden_data"

# ANSI colors from defaults.sh
_BW_BOLD="${POWERKIT_ANSI_BOLD}"
_BW_DIM="${POWERKIT_ANSI_DIM}"
_BW_RESET="${POWERKIT_ANSI_RESET}"
_BW_RED="${POWERKIT_ANSI_RED}"
_BW_GREEN="${POWERKIT_ANSI_GREEN}"
_BW_YELLOW="${POWERKIT_ANSI_YELLOW}"
_BW_CYAN="${POWERKIT_ANSI_CYAN}"

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
    has_cmd "bw" && { echo "bw"; return 0; }
    has_cmd "rbw" && { echo "rbw"; return 0; }
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
    cache_clear "$BITWARDEN_PLUGIN_CACHE_KEY"
    tmux refresh-client -S 2>/dev/null || true
}

# =============================================================================
# Unlock Vault UI
# =============================================================================

# Print unlock header
# Usage: print_bitwarden_unlock_header "client_name"
print_bitwarden_unlock_header() {
    local client="$1"
    printf '%s%s' "$_BW_BOLD" "$_BW_CYAN"
    printf '╭─────────────────────────────────────╮\n'
    printf '│      🔐 Bitwarden Vault Unlock      │\n'
    printf '╰─────────────────────────────────────╯%s\n' "$_BW_RESET"
    printf '\n'
    printf '%sClient: %s%s\n\n' "$_BW_DIM" "$client" "$_BW_RESET"
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
            printf '%s%s✓ Vault already unlocked%s\n' "$_BW_BOLD" "$_BW_GREEN" "$_BW_RESET"
            sleep 1
            return 0
            ;;
        unauthenticated)
            printf '%s%s✗ Please login first: bw login%s\n' "$_BW_BOLD" "$_BW_RED" "$_BW_RESET"
            printf '\n%sPress any key to close...%s' "$_BW_DIM" "$_BW_RESET"
            read -rsn1
            return 1
            ;;
        locked)
            # Prompt for master password and unlock
            printf '%sEnter master password:%s ' "$_BW_BOLD" "$_BW_RESET"
            local password
            read -rs password
            echo

            if [[ -z "$password" ]]; then
                printf '%s%s✗ Password required%s\n' "$_BW_BOLD" "$_BW_RED" "$_BW_RESET"
                sleep 1
                return 1
            fi

            printf '%s⏳ Unlocking vault...%s\n' "$_BW_YELLOW" "$_BW_RESET"
            local session
            session=$(bw unlock --raw "$password" 2>/dev/null) || true

            if [[ -n "$session" ]]; then
                save_bw_session "$session"
                export BW_SESSION="$session"
                invalidate_bitwarden_plugin_cache
                printf '%s%s✓ Vault unlocked!%s\n' "$_BW_BOLD" "$_BW_GREEN" "$_BW_RESET"
                toast " Vault unlocked" "simple"
                sleep 1
                return 0
            else
                printf '%s%s✗ Invalid password%s\n' "$_BW_BOLD" "$_BW_RED" "$_BW_RESET"
                printf '\n%sPress any key to try again or Ctrl-C to cancel...%s' "$_BW_DIM" "$_BW_RESET"
                read -rsn1
                # Clear screen and retry
                clear
                _unlock_bitwarden_bw
                return $?
            fi
            ;;
        *)
            printf '%s%s✗ Unknown status: %s%s\n' "$_BW_BOLD" "$_BW_RED" "$status" "$_BW_RESET"
            printf '\n%sPress any key to close...%s' "$_BW_DIM" "$_BW_RESET"
            read -rsn1
            return 1
            ;;
    esac
}

# Unlock vault (rbw)
_unlock_bitwarden_rbw() {
    print_bitwarden_unlock_header "rbw (unofficial Rust client)"

    if rbw unlocked 2>/dev/null; then
        printf '%s%s✓ Vault already unlocked%s\n' "$_BW_BOLD" "$_BW_GREEN" "$_BW_RESET"
        sleep 1
        return 0
    fi

    printf '%srbw will prompt for your password...%s\n\n' "$_BW_DIM" "$_BW_RESET"
    # rbw unlock handles its own prompting
    if rbw unlock 2>/dev/null; then
        invalidate_bitwarden_plugin_cache
        printf '%s%s✓ Vault unlocked!%s\n' "$_BW_BOLD" "$_BW_GREEN" "$_BW_RESET"
        toast " Vault unlocked" "simple"
        sleep 1
        return 0
    else
        printf '%s%s✗ Failed to unlock%s\n' "$_BW_BOLD" "$_BW_RED" "$_BW_RESET"
        printf '\n%sPress any key to close...%s' "$_BW_DIM" "$_BW_RESET"
        read -rsn1
        return 1
    fi
}

# Unlock vault (auto-detect client)
# Returns: 0 on success, 1 on failure
unlock_bitwarden_vault() {
    local client
    client=$(detect_bitwarden_client) || {
        printf '%s%s✗ bw/rbw not found%s\n' "$_BW_BOLD" "$_BW_RED" "$_BW_RESET"
        printf '%sInstall Bitwarden CLI (bw) or rbw%s\n' "$_BW_DIM" "$_BW_RESET"
        printf '\n%sPress any key to close...%s' "$_BW_DIM" "$_BW_RESET"
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
