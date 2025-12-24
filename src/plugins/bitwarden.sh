#!/usr/bin/env bash
# =============================================================================
# Plugin: bitwarden
# Description: Display Bitwarden vault status
# Dependencies: bw (Bitwarden CLI)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "bitwarden"
    metadata_set "name" "Bitwarden"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display Bitwarden vault status"
    metadata_set "priority" "140"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "bw" "rbw" || return 1
    require_cmd "jq" 1  # Optional
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Cache - higher TTL because bw status is slow (~1.5s)
    declare_option "cache_ttl" "number" "60" "Cache duration (bw status is slow)"

    # Icons
    declare_option "icon" "icon" $'\U000F0306' "Default icon"
    declare_option "icon_locked" "icon" $'\U000F033E' "Locked icon"
    declare_option "icon_unlocked" "icon" $'\U000F0FC6' "Unlocked icon"
    declare_option "icon_unauthenticated" "icon" $'\U000F0425' "Unauthenticated icon"

    # Keybindings
    declare_option "keybinding_password" "key" "C-v" "Keybinding for password selector"
    declare_option "keybinding_totp" "key" "C-t" "Keybinding for TOTP selector"
    declare_option "keybinding_unlock" "key" "C-w" "Keybinding to unlock vault"
    declare_option "keybinding_lock" "key" "" "Keybinding to lock vault"
    
    # Popup dimensions
    declare_option "popup_width" "string" "60%" "Popup width"
    declare_option "popup_height" "string" "80%" "Popup height"
    declare_option "popup_unlock_width" "string" "40%" "Unlock popup width"
    declare_option "popup_unlock_height" "string" "30%" "Unlock popup height"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }

plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local status=$(plugin_data_get "status")
    # active: plugin is working (unlocked or locked)
    # inactive: no logged user (unauthenticated)
    [[ "$status" == "unauthenticated" ]] && printf 'inactive' || printf 'active'
}

plugin_get_health() {
    local status=$(plugin_data_get "status")
    case "$status" in
        unlocked) printf 'ok' ;;
        locked) printf 'warning' ;;
        unauthenticated|*) printf 'error' ;;
    esac
}

plugin_get_context() {
    plugin_data_get "status"
}

plugin_get_icon() {
    local status=$(plugin_data_get "status")
    case "$status" in
        unlocked) get_option "icon_unlocked" ;;
        locked) get_option "icon_locked" ;;
        unauthenticated|*) get_option "icon_unauthenticated" ;;
    esac
}

# =============================================================================
# Main Logic
# =============================================================================

# Load BW_SESSION from tmux environment
_load_bw_session() {
    local session output
    output=$(tmux show-environment BW_SESSION 2>/dev/null) || true
    if [[ -n "$output" && "$output" != "-BW_SESSION" ]]; then
        session="${output#BW_SESSION=}"
        [[ -n "$session" ]] && export BW_SESSION="$session"
    fi
}

# Get status via official bw CLI
_get_bw_status() {
    has_cmd bw || return 1

    # Load session from tmux environment
    _load_bw_session

    local status_json status
    status_json=$(bw status 2>/dev/null) || return 1

    # Parse status from JSON
    if has_cmd jq; then
        status=$(echo "$status_json" | jq -r '.status' 2>/dev/null)
    else
        # Fallback: extract status with grep/sed
        status=$(echo "$status_json" | grep -o '"status":"[^"]*"' | sed 's/"status":"//;s/"//')
    fi

    echo "$status"
}

# Get status via rbw (unofficial Rust client)
_get_rbw_status() {
    has_cmd rbw || return 1

    # rbw unlocked returns 0 if unlocked, 1 if locked
    if rbw unlocked &>/dev/null 2>&1; then
        echo "unlocked"
    else
        # Check if logged in at all
        if rbw config show &>/dev/null 2>&1; then
            echo "locked"
        else
            echo "unauthenticated"
        fi
    fi
}

# Get vault status (tries bw first, then rbw)
_get_vault_status() {
    local status=""

    # Try bw first, then rbw
    status=$(_get_bw_status) || status=$(_get_rbw_status) || return 1

    # Normalize status names
    case "$status" in
        unlocked)        echo "unlocked" ;;
        locked)          echo "locked" ;;
        unauthenticated) echo "unauthenticated" ;;
        *)               echo "locked" ;;
    esac
}

plugin_collect() {
    # Runtime check - dependency contract handles notification
    has_cmd bw || has_cmd rbw || return 0

    local status
    status=$(_get_vault_status) || return 0

    if [[ "$status" == "unlocked" ]]; then
        plugin_data_set "unlocked" "1"
    else
        plugin_data_set "unlocked" "0"
    fi

    plugin_data_set "status" "${status:-locked}"
}

plugin_render() {
    local status
    status=$(plugin_data_get "status")

    # Renderer decides visibility via state/health
    case "$status" in
        unlocked)       printf 'Unlocked' ;;
        locked)         printf 'Locked' ;;
        unauthenticated) printf 'Logged Out' ;;
    esac
}

# =============================================================================
# Keybindings
# =============================================================================

plugin_setup_keybindings() {
    local pw_key totp_key unlock_key lock_key width height unlock_width unlock_height
    local pw_helper totp_helper
    
    pw_key=$(get_option "keybinding_password")
    totp_key=$(get_option "keybinding_totp")
    unlock_key=$(get_option "keybinding_unlock")
    lock_key=$(get_option "keybinding_lock")
    width=$(get_option "popup_width")
    height=$(get_option "popup_height")
    unlock_width=$(get_option "popup_unlock_width")
    unlock_height=$(get_option "popup_unlock_height")
    
    pw_helper="${POWERKIT_ROOT}/src/helpers/bitwarden_password_selector.sh"
    totp_helper="${POWERKIT_ROOT}/src/helpers/bitwarden_totp_selector.sh"
    
    pk_bind_popup "$pw_key" "bash '$pw_helper' select" "$width" "$height" "bitwarden:password"
    pk_bind_popup "$totp_key" "bash '$totp_helper' select" "$width" "$height" "bitwarden:totp"
    pk_bind_popup "$unlock_key" "bash '$pw_helper' unlock" "$unlock_width" "$unlock_height" "bitwarden:unlock"
    pk_bind_shell "$lock_key" "bash '$pw_helper' lock" "bitwarden:lock"
}

