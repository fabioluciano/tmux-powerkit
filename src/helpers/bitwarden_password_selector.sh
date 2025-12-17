#!/usr/bin/env bash
# Helper: bitwarden_password_selector - Interactive Bitwarden password selector with fzf
# Strategy: Pre-cache item list (without passwords), fetch password only on selection
# Session Management: Uses tmux environment to persist BW_SESSION across commands

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$CURRENT_DIR/.."
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit"
ITEMS_CACHE="$CACHE_DIR/bitwarden_items.cache"
ITEMS_CACHE_TTL=600  # 10 minutes
PLUGIN_STATUS_CACHE="$CACHE_DIR/bitwarden.cache"  # Plugin status cache

mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Minimal dependencies - avoid slow sourcing
toast() { tmux display-message "$1" 2>/dev/null || true; }

# Invalidate plugin status cache so status bar updates immediately
invalidate_plugin_cache() {
    rm -f "$PLUGIN_STATUS_CACHE" 2>/dev/null || true
    tmux refresh-client -S 2>/dev/null || true
}

# =============================================================================
# BW Session Management (tmux environment)
# =============================================================================

# Get BW_SESSION from tmux environment
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
save_bw_session() {
    local session="$1"
    tmux set-environment BW_SESSION "$session" 2>/dev/null
}

# Clear BW_SESSION from tmux environment
clear_bw_session() {
    tmux set-environment -u BW_SESSION 2>/dev/null || true
}

# Load BW_SESSION into current shell
load_bw_session() {
    local session
    session=$(get_bw_session) || true
    [[ -n "$session" ]] && export BW_SESSION="$session"
    return 0
}

# =============================================================================
# Client & Status
# =============================================================================

detect_client() {
    command -v bw &>/dev/null && { echo "bw"; return 0; }
    command -v rbw &>/dev/null && { echo "rbw"; return 0; }
    return 1
}

is_unlocked_bw() {
    load_bw_session
    local status
    status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    [[ "$status" == "unlocked" ]]
}

is_unlocked_rbw() {
    rbw unlocked 2>/dev/null
}

# =============================================================================
# Clipboard
# =============================================================================

copy_to_clipboard() {
    if [[ "$(uname)" == "Darwin" ]]; then
        pbcopy
    elif command -v wl-copy &>/dev/null; then
        wl-copy
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        xsel --clipboard --input
    else
        return 1
    fi
}

# =============================================================================
# Cache Management
# =============================================================================

is_cache_valid() {
    [[ -f "$ITEMS_CACHE" ]] || return 1
    local file_time now
    if [[ "$(uname)" == "Darwin" ]]; then
        file_time=$(stat -f "%m" "$ITEMS_CACHE" 2>/dev/null) || return 1
    else
        file_time=$(stat -c "%Y" "$ITEMS_CACHE" 2>/dev/null) || return 1
    fi
    now=$(date +%s)
    (( now - file_time < ITEMS_CACHE_TTL ))
}

# Build cache in background (called after successful selection or manually)
build_cache_bw() {
    load_bw_session
    # Only login items (type 1), tab-separated: name, username, id
    bw list items 2>/dev/null | \
        jq -r '.[] | select(.type == 1) | [.name, (.login.username // ""), .id] | @tsv' \
        > "$ITEMS_CACHE.tmp" 2>/dev/null && \
        mv "$ITEMS_CACHE.tmp" "$ITEMS_CACHE"
}

build_cache_rbw() {
    rbw list --fields name,user,id 2>/dev/null > "$ITEMS_CACHE"
}

# =============================================================================
# Main Selection - BW
# =============================================================================

select_bw() {
    load_bw_session
    local items selected

    # Use cache if valid, otherwise show loading
    if is_cache_valid && [[ -s "$ITEMS_CACHE" ]]; then
        items=$(cat "$ITEMS_CACHE")
    else
        # No cache - need to fetch (slow)
        printf '\033[33m Loading vault...\033[0m\n'
        items=$(bw list items 2>/dev/null | \
            jq -r '.[] | select(.type == 1) | [.name, (.login.username // ""), .id] | @tsv' 2>/dev/null)

        [[ -z "$items" ]] && { toast " No items found"; return 0; }

        # Save to cache for next time
        echo "$items" > "$ITEMS_CACHE"
    fi

    # Format for fzf: "name (user)" with hidden id
    selected=$(echo "$items" | awk -F'\t' '{
        user = ($2 != "") ? " ("$2")" : ""
        print $1 user "\t" $3
    }' | fzf --prompt=" " --height=100% --layout=reverse --border \
        --header="Enter: copy password | Esc: cancel" \
        --with-nth=1 --delimiter='\t' \
        --preview-window=hidden)

    [[ -z "$selected" ]] && return 0

    # Extract ID and fetch password
    local item_id item_name password
    item_id=$(echo "$selected" | cut -f2)
    item_name=$(echo "$selected" | cut -f1 | sed 's/ ([^)]*)$//')

    # Show feedback while fetching
    printf '\033[33m Fetching password...\033[0m'

    # Get password (may take a moment)
    password=$(bw get password "$item_id" 2>/dev/null) || true

    # Clear the fetching message
    printf '\r\033[K'

    if [[ -n "$password" ]]; then
        printf '%s' "$password" | copy_to_clipboard
        toast " ${item_name:0:30}"
    else
        toast " Failed to get password"
    fi
}

# =============================================================================
# Main Selection - RBW
# =============================================================================

select_rbw() {
    local items selected

    # rbw is fast, no cache needed
    items=$(rbw list --fields name,user 2>/dev/null)
    [[ -z "$items" ]] && { toast " No items found"; return 0; }

    selected=$(echo "$items" | awk -F'\t' '{
        user = ($2 != "") ? " ("$2")" : ""
        print $1 user "\t" $1 "\t" $2
    }' | fzf --prompt=" " --height=100% --layout=reverse --border \
        --header="Enter: copy password | Esc: cancel" \
        --with-nth=1 --delimiter='\t' \
        --preview-window=hidden)

    [[ -z "$selected" ]] && return 0

    local item_name username password
    item_name=$(echo "$selected" | cut -f2)
    username=$(echo "$selected" | cut -f3)

    if [[ -n "$username" ]]; then
        password=$(rbw get "$item_name" "$username" 2>/dev/null)
    else
        password=$(rbw get "$item_name" 2>/dev/null)
    fi

    if [[ -n "$password" ]]; then
        printf '%s' "$password" | copy_to_clipboard
        toast " ${item_name:0:30}"
    else
        toast " Failed to get password"
    fi
}

# =============================================================================
# Entry Points
# =============================================================================

select_password() {
    command -v fzf &>/dev/null || { toast "󰍉 fzf required"; return 0; }

    local client
    client=$(detect_client) || { toast " bw/rbw not found"; return 0; }

    case "$client" in
        bw)
            is_unlocked_bw || { toast " Vault locked"; return 0; }
            select_bw
            ;;
        rbw)
            is_unlocked_rbw || { toast " Vault locked"; return 0; }
            select_rbw
            ;;
    esac
}

refresh_cache() {
    local client
    client=$(detect_client) || { toast " bw/rbw not found"; return 1; }

    toast "󰑓 Refreshing cache..."

    case "$client" in
        bw)
            is_unlocked_bw || { toast " Vault locked"; return 1; }
            build_cache_bw
            ;;
        rbw)
            # rbw doesn't need cache
            toast " rbw doesn't use cache"
            return 0
            ;;
    esac

    toast " Cache refreshed"
}

clear_cache() {
    rm -f "$ITEMS_CACHE" "$ITEMS_CACHE.tmp" 2>/dev/null
    toast "󰃨 Cache cleared"
}

# =============================================================================
# Unlock Vault
# =============================================================================

# Print unlock header
print_unlock_header() {
    local client="$1"
    printf '\033[1;36m'
    printf '╭─────────────────────────────────────╮\n'
    printf '│      🔐 Bitwarden Vault Unlock      │\n'
    printf '╰─────────────────────────────────────╯\033[0m\n'
    printf '\n'
    printf '\033[2mClient: %s\033[0m\n\n' "$client"
}

unlock_bw() {
    print_unlock_header "bw (official CLI)"

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
                invalidate_plugin_cache
                printf '\033[1;32m✓ Vault unlocked!\033[0m\n'
                toast " Vault unlocked"
                # Pre-build cache in background
                build_cache_bw &
                sleep 1
                return 0
            else
                printf '\033[1;31m✗ Invalid password\033[0m\n'
                printf '\n\033[2mPress any key to try again or Ctrl-C to cancel...\033[0m'
                read -rsn1
                # Clear screen and retry
                clear
                unlock_bw
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

unlock_rbw() {
    print_unlock_header "rbw (unofficial Rust client)"

    if rbw unlocked 2>/dev/null; then
        printf '\033[1;32m✓ Vault already unlocked\033[0m\n'
        sleep 1
        return 0
    fi

    printf '\033[2mrbw will prompt for your password...\033[0m\n\n'
    # rbw unlock handles its own prompting
    if rbw unlock 2>/dev/null; then
        invalidate_plugin_cache
        printf '\033[1;32m✓ Vault unlocked!\033[0m\n'
        toast " Vault unlocked"  # Toast only on successful unlock (was locked)
        sleep 1
        return 0
    else
        printf '\033[1;31m✗ Failed to unlock\033[0m\n'
        printf '\n\033[2mPress any key to close...\033[0m'
        read -rsn1
        return 1
    fi
}

unlock_vault() {
    local client
    client=$(detect_client) || {
        printf '\033[1;31m✗ bw/rbw not found\033[0m\n'
        printf '\033[2mInstall Bitwarden CLI (bw) or rbw\033[0m\n'
        printf '\n\033[2mPress any key to close...\033[0m'
        read -rsn1
        return 1
    }

    case "$client" in
        bw)  unlock_bw ;;
        rbw) unlock_rbw ;;
    esac
}

lock_bw() {
    load_bw_session
    bw lock 2>/dev/null
    clear_bw_session
    clear_cache
    invalidate_plugin_cache
    toast " Vault locked"
}

lock_rbw() {
    rbw lock 2>/dev/null
    invalidate_plugin_cache
    toast " Vault locked"
}

lock_vault() {
    local client
    client=$(detect_client) || { toast " bw/rbw not found"; return 1; }

    case "$client" in
        bw)  lock_bw ;;
        rbw) lock_rbw ;;
    esac
}

# =============================================================================
# Main
# =============================================================================

case "${1:-select}" in
    select)   select_password ;;
    refresh)  refresh_cache ;;
    clear)    clear_cache ;;
    unlock)   unlock_vault ;;
    lock)     lock_vault ;;
    *)        echo "Usage: $0 {select|refresh|clear|unlock|lock}"; exit 1 ;;
esac
