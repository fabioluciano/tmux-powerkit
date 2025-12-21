#!/usr/bin/env bash
# Helper: bitwarden_password_selector - Interactive Bitwarden password selector with fzf
# Strategy: Pre-cache item list (without passwords), fetch password only on selection
# Session Management: Uses tmux environment to persist BW_SESSION across commands

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$_SCRIPT_DIR/.."

# Source common dependencies
# shellcheck source=src/helper_bootstrap.sh
. "$ROOT_DIR/helper_bootstrap.sh"

# Source Bitwarden common functions
# shellcheck source=src/helpers/bitwarden_common.sh
. "$_SCRIPT_DIR/bitwarden_common.sh"

# =============================================================================
# Constants
# =============================================================================

ITEMS_CACHE="$POWERKIT_CACHE_DIR/bitwarden_items.cache"
ITEMS_CACHE_TTL=600  # 10 minutes

# =============================================================================
# Cache Management
# =============================================================================

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
    if is_bitwarden_cache_valid "$ITEMS_CACHE" "$ITEMS_CACHE_TTL" && [[ -s "$ITEMS_CACHE" ]]; then
        items=$(cat "$ITEMS_CACHE")
    else
        # No cache - need to fetch (slow)
        printf '\033[33m Loading vault...\033[0m\n'
        items=$(bw list items 2>/dev/null | \
            jq -r '.[] | select(.type == 1) | [.name, (.login.username // ""), .id] | @tsv' 2>/dev/null)

        [[ -z "$items" ]] && { toast " No items found" "simple"; return 0; }

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
        --preview-window=hidden) || true

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
        toast " ${item_name:0:30}" "simple"
    else
        toast " Failed to get password" "simple"
    fi
}

# =============================================================================
# Main Selection - RBW
# =============================================================================

select_rbw() {
    local items selected

    # rbw is fast, no cache needed
    items=$(rbw list --fields name,user 2>/dev/null)
    [[ -z "$items" ]] && { toast " No items found" "simple"; return 0; }

    selected=$(echo "$items" | awk -F'\t' '{
        user = ($2 != "") ? " ("$2")" : ""
        print $1 user "\t" $1 "\t" $2
    }' | fzf --prompt=" " --height=100% --layout=reverse --border \
        --header="Enter: copy password | Esc: cancel" \
        --with-nth=1 --delimiter='\t' \
        --preview-window=hidden) || true

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
        toast " ${item_name:0:30}" "simple"
    else
        toast " Failed to get password" "simple"
    fi
}

# =============================================================================
# Entry Points
# =============================================================================

select_password() {
    command -v fzf &>/dev/null || { toast "󰍉 fzf required" "simple"; return 0; }

    local client
    client=$(detect_bitwarden_client) || { toast " bw/rbw not found" "simple"; return 0; }

    # Check vault status BEFORE opening selector
    local is_unlocked=false
    case "$client" in
        bw)  is_bitwarden_unlocked_bw && is_unlocked=true ;;
        rbw) is_bitwarden_unlocked_rbw && is_unlocked=true ;;
    esac

    if [[ "$is_unlocked" != "true" ]]; then
        # Vault is locked - show toast and exit
        toast " Vault locked" "simple"
        return 0
    fi

    case "$client" in
        bw)
            select_bw
            # Pre-build cache in background for next time
            build_cache_bw &
            ;;
        rbw)
            select_rbw
            ;;
    esac
}

refresh_cache() {
    local client
    client=$(detect_bitwarden_client) || { toast " bw/rbw not found" "simple"; return 1; }

    toast "󰑓 Refreshing cache..." "simple"

    case "$client" in
        bw)
            is_bitwarden_unlocked_bw || { toast " Vault locked" "simple"; return 1; }
            build_cache_bw
            ;;
        rbw)
            # rbw doesn't need cache
            toast " rbw doesn't use cache" "simple"
            return 0
            ;;
    esac

    toast " Cache refreshed" "simple"
}

clear_cache() {
    rm -f "$ITEMS_CACHE" "$ITEMS_CACHE.tmp" 2>/dev/null
    toast "󰃨 Cache cleared" "simple"
}

# =============================================================================
# Check and Select (vault status check before popup)
# =============================================================================

# Check vault status and open popup only if unlocked
# Usage: check_and_select <popup_width> <popup_height>
check_and_select() {
    local popup_width="${1:-60%}"
    local popup_height="${2:-60%}"

    command -v fzf &>/dev/null || { toast "󰍉 fzf required" "simple"; return 0; }

    local client
    client=$(detect_bitwarden_client) || { toast " bw/rbw not found" "simple"; return 0; }

    # Check vault status BEFORE opening popup
    local is_unlocked=false
    case "$client" in
        bw)  is_bitwarden_unlocked_bw && is_unlocked=true ;;
        rbw) is_bitwarden_unlocked_rbw && is_unlocked=true ;;
    esac

    if [[ "$is_unlocked" != "true" ]]; then
        # Vault is locked - show toast and exit (no popup opened)
        toast " Vault locked" "simple"
        return 0
    fi

    # Vault is unlocked - open the popup with the selector
    local script_path="${BASH_SOURCE[0]}"
    tmux display-popup -E -w "$popup_width" -h "$popup_height" \
        "bash '$script_path' select"
}

# =============================================================================
# Main
# =============================================================================

case "${1:-select}" in
    select)           select_password ;;
    check-and-select) check_and_select "${2:-}" "${3:-}" ;;
    refresh)          refresh_cache ;;
    clear)            clear_cache ;;
    unlock)           unlock_bitwarden_vault ;;
    lock)             lock_bitwarden_vault ;;
    *)                echo "Usage: $0 {select|check-and-select|refresh|clear|unlock|lock}"; exit 1 ;;
esac
