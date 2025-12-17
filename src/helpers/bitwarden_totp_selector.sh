#!/usr/bin/env bash
# Helper: bitwarden_totp_selector - Interactive Bitwarden TOTP selector with fzf
# Strategy: Pre-cache item list (only items with TOTP), fetch TOTP code on selection
# Session Management: Uses tmux environment to persist BW_SESSION across commands

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$CURRENT_DIR/.."
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit"
TOTP_CACHE="$CACHE_DIR/bitwarden_totp_items.cache"
TOTP_CACHE_TTL=600  # 10 minutes
PLUGIN_STATUS_CACHE="$CACHE_DIR/bitwarden.cache"

mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Minimal dependencies - avoid slow sourcing
toast() { tmux display-message "$1" 2>/dev/null || true; }

# =============================================================================
# BW Session Management (tmux environment)
# =============================================================================

get_bw_session() {
    local session output
    output=$(tmux show-environment BW_SESSION 2>/dev/null) || true
    if [[ -n "$output" && "$output" != "-BW_SESSION" ]]; then
        session="${output#BW_SESSION=}"
        [[ -n "$session" ]] && echo "$session"
    fi
}

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
    [[ -f "$TOTP_CACHE" ]] || return 1
    local file_time now
    if [[ "$(uname)" == "Darwin" ]]; then
        file_time=$(stat -f "%m" "$TOTP_CACHE" 2>/dev/null) || return 1
    else
        file_time=$(stat -c "%Y" "$TOTP_CACHE" 2>/dev/null) || return 1
    fi
    now=$(date +%s)
    (( now - file_time < TOTP_CACHE_TTL ))
}

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
    if is_cache_valid && [[ -s "$TOTP_CACHE" ]]; then
        items=$(cat "$TOTP_CACHE")
    else
        # No cache - need to fetch (slow)
        printf '\033[33m Loading TOTP items...\033[0m\n'
        items=$(bw list items 2>/dev/null | \
            jq -r '.[] | select(.type == 1 and .login.totp != null and .login.totp != "") | [.name, (.login.username // ""), .id] | @tsv' 2>/dev/null)

        [[ -z "$items" ]] && { toast " No TOTP items found"; return 0; }

        # Save to cache for next time
        echo "$items" > "$TOTP_CACHE"
    fi

    [[ -z "$items" ]] && { toast " No TOTP items found"; return 0; }

    # Format for fzf: "name (user)" with hidden id
    selected=$(echo "$items" | awk -F'\t' '{
        user = ($2 != "") ? " ("$2")" : ""
        print $1 user "\t" $3
    }' | fzf --prompt=" " --height=100% --layout=reverse --border \
        --header="Enter: copy TOTP | Esc: cancel" \
        --with-nth=1 --delimiter='\t' \
        --preview-window=hidden)

    [[ -z "$selected" ]] && return 0

    # Extract ID and fetch TOTP
    local item_id item_name totp_code
    item_id=$(echo "$selected" | cut -f2)
    item_name=$(echo "$selected" | cut -f1 | sed 's/ ([^)]*)$//')

    # Show feedback while fetching
    printf '\033[33m Generating TOTP...\033[0m'

    # Get TOTP code
    totp_code=$(bw get totp "$item_id" 2>/dev/null) || true

    # Clear the fetching message
    printf '\r\033[K'

    if [[ -n "$totp_code" ]]; then
        printf '%s' "$totp_code" | copy_to_clipboard
        toast " ${item_name:0:25} ($totp_code)"
    else
        toast " Failed to get TOTP"
    fi
}

# =============================================================================
# Main Selection - RBW
# =============================================================================

select_totp_rbw() {
    local items selected

    printf '\033[33m Loading TOTP items...\033[0m\n'

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

    [[ -z "$items" ]] && { toast " No TOTP items found"; return 0; }

    selected=$(printf '%s' "$items" | fzf --prompt=" " --height=100% --layout=reverse --border \
        --header="Enter: copy TOTP | Esc: cancel" \
        --with-nth=1 --delimiter='\t' \
        --preview-window=hidden)

    [[ -z "$selected" ]] && return 0

    local item_name username totp_code
    item_name=$(echo "$selected" | cut -f2)
    username=$(echo "$selected" | cut -f3)

    printf '\033[33m Generating TOTP...\033[0m'

    if [[ -n "$username" ]]; then
        totp_code=$(rbw code "$item_name" "$username" 2>/dev/null)
    else
        totp_code=$(rbw code "$item_name" 2>/dev/null)
    fi

    printf '\r\033[K'

    if [[ -n "$totp_code" ]]; then
        printf '%s' "$totp_code" | copy_to_clipboard
        toast " ${item_name:0:25} ($totp_code)"
    else
        toast " Failed to get TOTP"
    fi
}

# =============================================================================
# Unlock Vault (for locked vault prompt)
# =============================================================================

# Save BW_SESSION to tmux environment
save_bw_session() {
    local session="$1"
    tmux set-environment BW_SESSION "$session" 2>/dev/null
}

# Invalidate plugin status cache so status bar updates immediately
invalidate_plugin_cache() {
    rm -f "$PLUGIN_STATUS_CACHE" 2>/dev/null || true
    tmux refresh-client -S 2>/dev/null || true
}

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
                sleep 1
                return 0
            else
                printf '\033[1;31m✗ Invalid password\033[0m\n'
                printf '\n\033[2mPress any key to try again or Ctrl-C to cancel...\033[0m'
                read -rsn1
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
    if rbw unlock 2>/dev/null; then
        invalidate_plugin_cache
        printf '\033[1;32m✓ Vault unlocked!\033[0m\n'
        toast " Vault unlocked"
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

# =============================================================================
# Entry Points
# =============================================================================

select_totp() {
    command -v fzf &>/dev/null || { toast "󰍉 fzf required"; return 0; }

    local client
    client=$(detect_client) || { toast " bw/rbw not found"; return 0; }

    # Check vault status BEFORE opening selector
    local is_unlocked=false
    case "$client" in
        bw)  is_unlocked_bw && is_unlocked=true ;;
        rbw) is_unlocked_rbw && is_unlocked=true ;;
    esac

    if [[ "$is_unlocked" != "true" ]]; then
        # Vault is locked - show prompt to unlock
        printf '\033[1;33m'
        printf '╭─────────────────────────────────────╮\n'
        printf '│       🔒 Vault is Locked            │\n'
        printf '╰─────────────────────────────────────╯\033[0m\n'
        printf '\n'
        printf '\033[2mThe vault must be unlocked to access TOTP codes.\033[0m\n\n'
        printf '\033[1;37mPress Enter to unlock or Esc to cancel...\033[0m'

        local key
        read -rsn1 key

        # Check for Escape key (27 = ESC)
        if [[ "$key" == $'\x1b' ]]; then
            return 0
        fi

        # Clear and proceed to unlock
        clear
        unlock_vault || return 0

        # Re-check if now unlocked
        case "$client" in
            bw)  is_unlocked_bw || return 0 ;;
            rbw) is_unlocked_rbw || return 0 ;;
        esac

        clear
    fi

    case "$client" in
        bw)  select_totp_bw ;;
        rbw) select_totp_rbw ;;
    esac
}

refresh_cache() {
    local client
    client=$(detect_client) || { toast " bw/rbw not found"; return 1; }

    toast "󰑓 Refreshing TOTP cache..."

    case "$client" in
        bw)
            is_unlocked_bw || { toast " Vault locked"; return 1; }
            build_cache_bw
            ;;
        rbw)
            is_unlocked_rbw || { toast " Vault locked"; return 1; }
            build_cache_rbw
            ;;
    esac

    toast " TOTP cache refreshed"
}

clear_cache() {
    rm -f "$TOTP_CACHE" "$TOTP_CACHE.tmp" 2>/dev/null
    toast "󰃨 TOTP cache cleared"
}

# =============================================================================
# Main
# =============================================================================

case "${1:-select}" in
    select)   select_totp ;;
    refresh)  refresh_cache ;;
    clear)    clear_cache ;;
    *)        echo "Usage: $0 {select|refresh|clear}"; exit 1 ;;
esac
