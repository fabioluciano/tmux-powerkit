#!/usr/bin/env bash
# =============================================================================
# Helper: bitwarden_totp_selector
# Description: Interactive Bitwarden TOTP selector with fzf/gum
# Type: popup
# Strategy: Pre-cache item list (only items with TOTP), fetch TOTP code on selection
# Session Management: Uses tmux environment to persist BW_SESSION across commands
# =============================================================================

# Source helper base (handles all initialization)
# Using minimal bootstrap for faster startup - bitwarden helpers only need:
# cache, platform, clipboard, ui_backend (all available in minimal)
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init
# Note: ui_backend.sh is loaded by helper_contract.sh

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "bitwarden_totp_selector"
    helper_metadata_set "name" "Bitwarden TOTP Selector"
    helper_metadata_set "description" "Copy TOTP codes from Bitwarden vault"
    helper_metadata_set "type" "popup"
}

helper_get_actions() {
    echo "select - Select and copy TOTP (default)"
    echo "check-and-select - Check vault status and open popup"
    echo "refresh - Refresh cache"
    echo "clear - Clear cache"
}

# Source Bitwarden common functions
# shellcheck source=src/helpers/_bitwarden_common.sh
. "$(dirname "${BASH_SOURCE[0]}")/_bitwarden_common.sh"

# =============================================================================
# Constants
# =============================================================================

_CACHE_BASE_DIR="$(dirname "$(get_cache_dir)")"
TOTP_CACHE="${_CACHE_BASE_DIR}/bitwarden_totp_items.cache"
TOTP_CACHE_TTL=600  # 10 minutes

# ANSI colors from defaults.sh
_BW_YELLOW="${POWERKIT_ANSI_YELLOW}"
_BW_RESET="${POWERKIT_ANSI_RESET}"

# =============================================================================
# Cache Management
# =============================================================================

# Build cache - only items with TOTP configured
build_cache_bw() {
    load_bw_session
    # Only login items (type 1) with TOTP, tab-separated: name, username, id
    bw list items 2>/dev/null | \
        jq -r '.[] | select(.type == 1 and .login.totp != null and .login.totp != "") | [.name, (.login.username // ""), .id] | @tsv' \
        > "$TOTP_CACHE.tmp" 2>/dev/null && \
        mv "$TOTP_CACHE.tmp" "$TOTP_CACHE"
}

build_cache_rbw() {
    # rbw list items with totp - we need to filter
    rbw list --fields name,user,id 2>/dev/null | while IFS=$'\t' read -r name user id; do
        # Check if item has TOTP (rbw code will fail if no TOTP)
        if rbw code "$name" ${user:+"$user"} &>/dev/null; then
            printf '%s\t%s\t%s\n' "$name" "$user" "$id"
        fi
    done > "$TOTP_CACHE"
}

# =============================================================================
# Main Selection - BW
# =============================================================================

select_totp_bw() {
    load_bw_session
    local items selected

    # Use cache if valid, otherwise show loading
    if is_bitwarden_cache_valid "$TOTP_CACHE" "$TOTP_CACHE_TTL" && [[ -s "$TOTP_CACHE" ]]; then
        items=$(cat "$TOTP_CACHE")
    else
        # No cache - need to fetch (slow)
        printf '%s Loading TOTP items...%s\n' "$_BW_YELLOW" "$_BW_RESET"
        items=$(bw list items 2>/dev/null | \
            jq -r '.[] | select(.type == 1 and .login.totp != null and .login.totp != "") | [.name, (.login.username // ""), .id] | @tsv' 2>/dev/null)

        [[ -z "$items" ]] && { toast " No TOTP items found" "simple"; return 0; }

        # Save to cache for next time
        echo "$items" > "$TOTP_CACHE"
    fi

    [[ -z "$items" ]] && { toast " No TOTP items found" "simple"; return 0; }

    # Format for fzf: "name (user)" with hidden id
    selected=$(echo "$items" | awk -F'\t' '{
        user = ($2 != "") ? " ("$2")" : ""
        print $1 user "\t" $3
    }' | fzf --prompt=" " --height=100% --layout=reverse --border \
        --header="Enter: copy TOTP | Esc: cancel" \
        --with-nth=1 --delimiter='\t' \
        --preview-window=hidden) || true

    [[ -z "$selected" ]] && return 0

    # Extract ID and fetch TOTP
    local item_id item_name totp_code
    item_id=$(echo "$selected" | cut -f2)
    item_name=$(echo "$selected" | cut -f1 | sed 's/ ([^)]*)$//')

    # Show feedback while fetching
    printf '%s Generating TOTP...%s' "$_BW_YELLOW" "$_BW_RESET"

    # Get TOTP code
    totp_code=$(bw get totp "$item_id" 2>/dev/null) || true

    # Clear the fetching message
    printf '\r%s' "$_BW_RESET"
    tput el 2>/dev/null || printf '\033[K'

    if [[ -n "$totp_code" ]]; then
        printf '%s' "$totp_code" | copy_to_clipboard
        toast " ${item_name:0:25} ($totp_code)" "simple"
    else
        toast " Failed to get TOTP" "simple"
    fi
}

# =============================================================================
# Main Selection - RBW
# =============================================================================

select_totp_rbw() {
    local items selected

    printf '%s Loading TOTP items...%s\n' "$_BW_YELLOW" "$_BW_RESET"

    # Build list of items with TOTP
    items=""
    while IFS=$'\t' read -r name user; do
        # Check if item has TOTP
        if rbw code "$name" ${user:+"$user"} &>/dev/null; then
            local user_display=""
            [[ -n "$user" ]] && user_display=" ($user)"
            items+="${name}${user_display}"$'\t'"${name}"$'\t'"${user}"$'\n'
        fi
    done < <(rbw list --fields name,user 2>/dev/null)

    [[ -z "$items" ]] && { toast " No TOTP items found" "simple"; return 0; }

    selected=$(printf '%s' "$items" | fzf --prompt=" " --height=100% --layout=reverse --border \
        --header="Enter: copy TOTP | Esc: cancel" \
        --with-nth=1 --delimiter='\t' \
        --preview-window=hidden) || true

    [[ -z "$selected" ]] && return 0

    local item_name username totp_code
    item_name=$(echo "$selected" | cut -f2)
    username=$(echo "$selected" | cut -f3)

    printf '%s Generating TOTP...%s' "$_BW_YELLOW" "$_BW_RESET"

    if [[ -n "$username" ]]; then
        totp_code=$(rbw code "$item_name" "$username" 2>/dev/null)
    else
        totp_code=$(rbw code "$item_name" 2>/dev/null)
    fi

    printf '\r%s' "$_BW_RESET"
    tput el 2>/dev/null || printf '\033[K'

    if [[ -n "$totp_code" ]]; then
        printf '%s' "$totp_code" | copy_to_clipboard
        toast " ${item_name:0:25} ($totp_code)" "simple"
    else
        toast " Failed to get TOTP" "simple"
    fi
}

# =============================================================================
# Entry Points
# =============================================================================

select_totp() {
    local backend
    backend=$(ui_get_backend)
    [[ "$backend" == "basic" ]] && { toast "❯ fzf or gum required" "simple"; return 0; }

    local client
    client=$(detect_bitwarden_client) || { toast " bw/rbw not found" "simple"; return 0; }

    # Check vault status BEFORE opening selector
    local is_unlocked=false
    case "$client" in
        bw)  is_bitwarden_unlocked_bw && is_unlocked=true ;;
        rbw) is_bitwarden_unlocked_rbw && is_unlocked=true ;;
    esac

    if [[ "$is_unlocked" != "true" ]]; then
        # Vault is locked - show warning toast and exit
        toast "Vault locked" "warning"
        return 0
    fi

    case "$client" in
        bw)  select_totp_bw ;;
        rbw) select_totp_rbw ;;
    esac
}

refresh_cache() {
    local client
    client=$(detect_bitwarden_client) || { toast " bw/rbw not found" "simple"; return 1; }

    toast "󰑓 Refreshing TOTP cache..." "simple"

    case "$client" in
        bw)
            is_bitwarden_unlocked_bw || { toast "Vault locked" "warning"; return 1; }
            build_cache_bw
            ;;
        rbw)
            is_bitwarden_unlocked_rbw || { toast "Vault locked" "warning"; return 1; }
            build_cache_rbw
            ;;
    esac

    toast " TOTP cache refreshed" "simple"
}

clear_cache() {
    rm -f "$TOTP_CACHE" "$TOTP_CACHE.tmp" 2>/dev/null
    toast "󰃨 TOTP cache cleared" "simple"
}

# =============================================================================
# Check and Select (vault status check before popup)
# =============================================================================

# Check vault status and open popup only if unlocked
# Usage: check_and_select <popup_width> <popup_height>
check_and_select() {
    local popup_width="${1:-60%}"
    local popup_height="${2:-60%}"

    has_cmd "fzf" || { toast "󰍉 fzf required" "simple"; return 0; }

    local client
    client=$(detect_bitwarden_client) || { toast " bw/rbw not found" "simple"; return 0; }

    # Check vault status BEFORE opening popup
    local is_unlocked=false
    case "$client" in
        bw)  is_bitwarden_unlocked_bw && is_unlocked=true ;;
        rbw) is_bitwarden_unlocked_rbw && is_unlocked=true ;;
    esac

    if [[ "$is_unlocked" != "true" ]]; then
        # Vault is locked - show warning toast and exit (no popup opened)
        toast "Vault locked" "warning"
        return 0
    fi

    # Vault is unlocked - open the popup with the selector
    local script_path="${BASH_SOURCE[0]}"
    tmux display-popup -E -w "$popup_width" -h "$popup_height" \
        "bash '$script_path' select"
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-select}"
    shift 2>/dev/null || true

    case "$action" in
        select|"")        select_totp ;;
        check-and-select) check_and_select "${1:-}" "${2:-}" ;;
        refresh)          refresh_cache ;;
        clear)            clear_cache ;;
        *)
            echo "Unknown action: $action" >&2
            return 1
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
