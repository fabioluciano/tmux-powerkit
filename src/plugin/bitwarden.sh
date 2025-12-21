#!/usr/bin/env bash
# =============================================================================
# Plugin: bitwarden
# Description: Display Bitwarden vault status (locked/unlocked/logged out)
# Type: conditional (hidden based on lock/unlock status configuration)
# Dependencies: bw (Bitwarden CLI) or rbw (unofficial Rust client), jq (optional)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "bw" "rbw" || return 1
    require_cmd "jq" 1  # Optional
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "show_when_locked" "bool" "true" "Show plugin when vault is locked"
    declare_option "show_when_unlocked" "bool" "true" "Show plugin when vault is unlocked"

    # Icons
    declare_option "icon" "icon" $'\U000F0306' "Plugin icon"
    declare_option "icon_unlocked" "icon" $'\U000F0FC6' "Icon when vault is unlocked"
    declare_option "icon_locked" "icon" $'\U000F033E' "Icon when vault is locked"
    declare_option "icon_logged_out" "icon" $'\U000F0425' "Icon when logged out"

    # Colors - Default
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Colors - Unlocked state
    declare_option "unlocked_accent_color" "color" "success" "Background color when unlocked"
    declare_option "unlocked_accent_color_icon" "color" "success-strong" "Icon background color when unlocked"

    # Colors - Locked state
    declare_option "locked_accent_color" "color" "warning" "Background color when locked"
    declare_option "locked_accent_color_icon" "color" "warning-strong" "Icon background color when locked"

    # Colors - Logged out state
    declare_option "logged_out_accent_color" "color" "error" "Background color when logged out"
    declare_option "logged_out_accent_color_icon" "color" "error-strong" "Icon background color when logged out"

    # Keybindings - Password selector
    declare_option "password_selector_key" "key" "C-v" "Key binding for password selector"
    declare_option "password_selector_width" "string" "80%" "Password selector popup width"
    declare_option "password_selector_height" "string" "80%" "Password selector popup height"

    # Keybindings - Unlock
    declare_option "unlock_key" "key" "C-w" "Key binding for vault unlock"
    declare_option "unlock_width" "string" "40%" "Unlock popup width"
    declare_option "unlock_height" "string" "20%" "Unlock popup height"

    # Keybindings - Lock
    declare_option "lock_key" "key" "" "Key binding for vault lock (disabled by default)"

    # Keybindings - TOTP selector
    declare_option "totp_selector_key" "key" "C-t" "Key binding for TOTP selector"
    declare_option "totp_selector_width" "string" "60%" "TOTP selector popup width"
    declare_option "totp_selector_height" "string" "60%" "TOTP selector popup height"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

plugin_init "bitwarden"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    local show="0"
    local icon="" accent="" accent_icon=""

    # Get configured options
    local show_when_locked show_when_unlocked
    show_when_locked=$(get_option "show_when_locked")
    show_when_unlocked=$(get_option "show_when_unlocked")

    case "$content" in
        unlocked)
            if [[ "$show_when_unlocked" == "true" ]]; then
                show="1"
                icon=$(get_option "icon_unlocked")
                accent=$(get_option "unlocked_accent_color")
                accent_icon=$(get_option "unlocked_accent_color_icon")
            fi
            ;;
        locked)
            if [[ "$show_when_locked" == "true" ]]; then
                show="1"
                icon=$(get_option "icon_locked")
                accent=$(get_option "locked_accent_color")
                accent_icon=$(get_option "locked_accent_color_icon")
            fi
            ;;
        unauthenticated)
            # Always show if logged out (security concern)
            show="1"
            icon=$(get_option "icon_logged_out")
            accent=$(get_option "logged_out_accent_color")
            accent_icon=$(get_option "logged_out_accent_color_icon")
            ;;
    esac

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Logic
# =============================================================================

_load_bw_session() {
    local session output
    output=$(tmux show-environment BW_SESSION 2>/dev/null) || true
    # Filter out unset marker (-BW_SESSION) and extract value
    if [[ -n "$output" && "$output" != "-BW_SESSION" ]]; then
        session="${output#BW_SESSION=}"
        [[ -n "$session" ]] && export BW_SESSION="$session"
    fi
}

_get_bw_status() {
    has_cmd bw || return 1

    # Load session from tmux environment
    _load_bw_session

    local status_json
    status_json=$(bw status 2>/dev/null) || return 1

    # Parse status from JSON
    local status
    if has_cmd jq; then
        status=$(echo "$status_json" | jq -r '.status' 2>/dev/null)
    else
        # Fallback: extract status with grep/sed
        status=$(echo "$status_json" | grep -o '"status":"[^"]*"' | sed 's/"status":"//;s/"//')
    fi

    echo "$status"
}

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

load_plugin() {
    # Runtime check - dependency contract handles notification
    has_cmd bw || has_cmd rbw || return 0

    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local status
    status=$(_get_vault_status) || return 0

    cache_set "$CACHE_KEY" "$status"
    printf '%s' "$status"
}

setup_keybindings() {
    local helpers_dir="${ROOT_DIR}/../helpers"

    # Password selector (prefix + C-v for Vault passwords)
    # Check vault status BEFORE opening popup - if locked, show toast instead
    local pw_key pw_width pw_height
    pw_key=$(get_option "password_selector_key")
    pw_width=$(get_option "password_selector_width")
    pw_height=$(get_option "password_selector_height")

    [[ -n "$pw_key" ]] && tmux bind-key "$pw_key" run-shell \
        "bash '$helpers_dir/bitwarden_password_selector.sh' check-and-select '$pw_width' '$pw_height'"

    # Unlock vault (prefix + C-w for Warden unlock)
    local unlock_key unlock_width unlock_height
    unlock_key=$(get_option "unlock_key")
    unlock_width=$(get_option "unlock_width")
    unlock_height=$(get_option "unlock_height")
    [[ -n "$unlock_key" ]] && tmux bind-key "$unlock_key" display-popup -E -w "$unlock_width" -h "$unlock_height" \
        "bash '$helpers_dir/bitwarden_password_selector.sh' unlock"

    # Lock vault (prefix + C-l for Lock) - disabled by default to avoid conflict
    local lock_key
    lock_key=$(get_option "lock_key")
    [[ -n "$lock_key" ]] && tmux bind-key "$lock_key" run-shell \
        "bash '$helpers_dir/bitwarden_password_selector.sh' lock"

    # TOTP selector (prefix + C-t for TOTP codes)
    # Check vault status BEFORE opening popup - if locked, show toast instead
    local totp_key totp_width totp_height
    totp_key=$(get_option "totp_selector_key")
    totp_width=$(get_option "totp_selector_width")
    totp_height=$(get_option "totp_selector_height")
    [[ -n "$totp_key" ]] && tmux bind-key "$totp_key" run-shell \
        "bash '$helpers_dir/bitwarden_totp_selector.sh' check-and-select '$totp_width' '$totp_height'"
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
