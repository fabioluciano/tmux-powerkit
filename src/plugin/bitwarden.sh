#!/usr/bin/env bash
# =============================================================================
# Plugin: bitwarden
# Description: Display Bitwarden vault status (locked/unlocked/logged out)
# Dependencies: bw (Bitwarden CLI) or rbw (unofficial Rust client)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "bitwarden"

# =============================================================================
# BW Session Management (tmux environment)
# =============================================================================

# Load BW_SESSION from tmux environment into current shell
load_bw_session() {
    local session output
    output=$(tmux show-environment BW_SESSION 2>/dev/null) || true
    # Filter out unset marker (-BW_SESSION) and extract value
    if [[ -n "$output" && "$output" != "-BW_SESSION" ]]; then
        session="${output#BW_SESSION=}"
        [[ -n "$session" ]] && export BW_SESSION="$session"
    fi
}

# =============================================================================
# Status Functions
# =============================================================================

# Get vault status using official Bitwarden CLI
get_bw_status() {
    require_cmd bw 1 || return 1

    # Load session from tmux environment
    load_bw_session

    local status_json
    status_json=$(bw status 2>/dev/null) || return 1

    # Parse status from JSON
    local status
    if require_cmd jq 1; then
        status=$(echo "$status_json" | jq -r '.status' 2>/dev/null)
    else
        # Fallback: extract status with grep/sed
        status=$(echo "$status_json" | grep -o '"status":"[^"]*"' | sed 's/"status":"//;s/"//')
    fi

    echo "$status"
}

# Get vault status using rbw (unofficial Rust client)
get_rbw_status() {
    require_cmd rbw 1 || return 1

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

# Get status from available client
get_vault_status() {
    local status=""

    # Try bw first, then rbw
    status=$(get_bw_status) || status=$(get_rbw_status) || return 1

    # Normalize status names
    case "$status" in
        unlocked)        echo "unlocked" ;;
        locked)          echo "locked" ;;
        unauthenticated) echo "unauthenticated" ;;
        *)               echo "locked" ;;
    esac
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    local show="0"
    local icon="" accent="" accent_icon=""

    # Get configured options
    local show_when_locked show_when_unlocked
    show_when_locked=$(get_cached_option "@powerkit_plugin_bitwarden_show_when_locked" "$POWERKIT_PLUGIN_BITWARDEN_SHOW_WHEN_LOCKED")
    show_when_unlocked=$(get_cached_option "@powerkit_plugin_bitwarden_show_when_unlocked" "$POWERKIT_PLUGIN_BITWARDEN_SHOW_WHEN_UNLOCKED")

    case "$content" in
        unlocked)
            if [[ "$show_when_unlocked" == "true" ]]; then
                show="1"
                icon=$(get_cached_option "@powerkit_plugin_bitwarden_icon_unlocked" "$POWERKIT_PLUGIN_BITWARDEN_ICON_UNLOCKED")
                accent=$(get_cached_option "@powerkit_plugin_bitwarden_unlocked_accent_color" "$POWERKIT_PLUGIN_BITWARDEN_UNLOCKED_ACCENT_COLOR")
                accent_icon=$(get_cached_option "@powerkit_plugin_bitwarden_unlocked_accent_color_icon" "$POWERKIT_PLUGIN_BITWARDEN_UNLOCKED_ACCENT_COLOR_ICON")
            fi
            ;;
        locked)
            if [[ "$show_when_locked" == "true" ]]; then
                show="1"
                icon=$(get_cached_option "@powerkit_plugin_bitwarden_icon_locked" "$POWERKIT_PLUGIN_BITWARDEN_ICON_LOCKED")
                accent=$(get_cached_option "@powerkit_plugin_bitwarden_locked_accent_color" "$POWERKIT_PLUGIN_BITWARDEN_LOCKED_ACCENT_COLOR")
                accent_icon=$(get_cached_option "@powerkit_plugin_bitwarden_locked_accent_color_icon" "$POWERKIT_PLUGIN_BITWARDEN_LOCKED_ACCENT_COLOR_ICON")
            fi
            ;;
        unauthenticated)
            # Always show if logged out (security concern)
            show="1"
            icon=$(get_cached_option "@powerkit_plugin_bitwarden_icon_logged_out" "$POWERKIT_PLUGIN_BITWARDEN_ICON_LOGGED_OUT")
            accent=$(get_cached_option "@powerkit_plugin_bitwarden_logged_out_accent_color" "$POWERKIT_PLUGIN_BITWARDEN_LOGGED_OUT_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@powerkit_plugin_bitwarden_logged_out_accent_color_icon" "$POWERKIT_PLUGIN_BITWARDEN_LOGGED_OUT_ACCENT_COLOR_ICON")
            ;;
    esac

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    # Check if any supported client is available
    require_any_cmd bw rbw || return 0

    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local status
    status=$(get_vault_status) || return 0

    cache_set "$CACHE_KEY" "$status"
    printf '%s' "$status"
}

# =============================================================================
# Keybindings
# =============================================================================

setup_keybindings() {
    local helpers_dir="${ROOT_DIR}/../helpers"

    # Password selector (prefix + C-v for Vault passwords)
    local pw_key pw_width pw_height
    pw_key=$(get_tmux_option "@powerkit_plugin_bitwarden_password_selector_key" "$POWERKIT_PLUGIN_BITWARDEN_PASSWORD_SELECTOR_KEY")
    pw_width=$(get_tmux_option "@powerkit_plugin_bitwarden_password_selector_width" "$POWERKIT_PLUGIN_BITWARDEN_PASSWORD_SELECTOR_WIDTH")
    pw_height=$(get_tmux_option "@powerkit_plugin_bitwarden_password_selector_height" "$POWERKIT_PLUGIN_BITWARDEN_PASSWORD_SELECTOR_HEIGHT")

    [[ -n "$pw_key" ]] && tmux bind-key "$pw_key" display-popup -E -w "$pw_width" -h "$pw_height" \
        "bash '$helpers_dir/bitwarden_password_selector.sh' select"

    # Unlock vault (prefix + C-w for Warden unlock)
    local unlock_key unlock_width unlock_height
    unlock_key=$(get_tmux_option "@powerkit_plugin_bitwarden_unlock_key" "$POWERKIT_PLUGIN_BITWARDEN_UNLOCK_KEY")
    unlock_width=$(get_tmux_option "@powerkit_plugin_bitwarden_unlock_width" "$POWERKIT_PLUGIN_BITWARDEN_UNLOCK_WIDTH")
    unlock_height=$(get_tmux_option "@powerkit_plugin_bitwarden_unlock_height" "$POWERKIT_PLUGIN_BITWARDEN_UNLOCK_HEIGHT")
    [[ -n "$unlock_key" ]] && tmux bind-key "$unlock_key" display-popup -E -w "$unlock_width" -h "$unlock_height" \
        "bash '$helpers_dir/bitwarden_password_selector.sh' unlock"

    # Lock vault (prefix + C-l for Lock) - disabled by default to avoid conflict
    local lock_key
    lock_key=$(get_tmux_option "@powerkit_plugin_bitwarden_lock_key" "$POWERKIT_PLUGIN_BITWARDEN_LOCK_KEY")
    [[ -n "$lock_key" ]] && tmux bind-key "$lock_key" run-shell \
        "bash '$helpers_dir/bitwarden_password_selector.sh' lock"

    # TOTP selector (prefix + C-t for TOTP codes)
    local totp_key totp_width totp_height
    totp_key=$(get_tmux_option "@powerkit_plugin_bitwarden_totp_selector_key" "$POWERKIT_PLUGIN_BITWARDEN_TOTP_SELECTOR_KEY")
    totp_width=$(get_tmux_option "@powerkit_plugin_bitwarden_totp_selector_width" "$POWERKIT_PLUGIN_BITWARDEN_TOTP_SELECTOR_WIDTH")
    totp_height=$(get_tmux_option "@powerkit_plugin_bitwarden_totp_selector_height" "$POWERKIT_PLUGIN_BITWARDEN_TOTP_SELECTOR_HEIGHT")
    [[ -n "$totp_key" ]] && tmux bind-key "$totp_key" display-popup -E -w "$totp_width" -h "$totp_height" \
        "bash '$helpers_dir/bitwarden_totp_selector.sh' select"
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
