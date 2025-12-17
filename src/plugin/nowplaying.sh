#!/usr/bin/env bash
# =============================================================================
# Plugin: nowplaying
# Description: Display currently playing media
# Backends: osascript (macOS), playerctl (Linux MPRIS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "nowplaying"

# =============================================================================
# Helper Functions
# =============================================================================

# Escape special characters for bash string replacement
escape_replacement() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//&/\\&}"
    printf '%s' "$str"
}

format_output() {
    local artist="$1" track="$2" album="$3"
    local format max_len

    format=$(get_cached_option "@powerkit_plugin_nowplaying_format" "$POWERKIT_PLUGIN_NOWPLAYING_FORMAT")
    max_len=$(get_cached_option "@powerkit_plugin_nowplaying_max_length" "$POWERKIT_PLUGIN_NOWPLAYING_MAX_LENGTH")

    # Escape special chars
    local safe_artist safe_track safe_album
    safe_artist=$(escape_replacement "$artist")
    safe_track=$(escape_replacement "$track")
    safe_album=$(escape_replacement "$album")

    local out="${format//%artist%/$safe_artist}"
    out="${out//%track%/$safe_track}"
    out="${out//%album%/$safe_album}"

    [[ "$max_len" -gt 0 && ${#out} -gt $max_len ]] && out="${out:0:$((max_len - 1))}…"
    printf '%s' "$out"
}

# =============================================================================
# Backend Functions
# =============================================================================

# macOS: Spotify/Music via osascript
get_macos() {
    local r
    r=$(osascript -e '
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is playing then
                    return "playing|" & artist of current track & "|" & name of current track & "|" & album of current track
                end if
            end tell
        end if
        if application "Music" is running then
            tell application "Music"
                if player state is playing then
                    return "playing|" & artist of current track & "|" & name of current track & "|" & album of current track
                end if
            end tell
        end if
        return ""
    ' 2>/dev/null)

    [[ "$r" != playing* ]] && return 1

    local a t b
    IFS='|' read -r _ a t b <<< "$r"
    [[ -z "$t" ]] && return 1
    format_output "$a" "$t" "$b"
}

# Linux: MPRIS via playerctl
get_linux() {
    require_cmd playerctl 1 || return 1

    local ignore_opt=""
    local ignore_players
    ignore_players=$(get_cached_option "@powerkit_plugin_nowplaying_ignore_players" "$POWERKIT_PLUGIN_NOWPLAYING_IGNORE_PLAYERS")

    if [[ -n "$ignore_players" && "$ignore_players" != "IGNORE" ]]; then
        IFS=',' read -ra players <<< "$ignore_players"
        for p in "${players[@]}"; do
            ignore_opt+=" --ignore-player=$p"
        done
    fi

    local r
    # shellcheck disable=SC2086
    r=$(playerctl $ignore_opt metadata --format '{{status}}|{{artist}}|{{title}}|{{album}}' 2>/dev/null)

    [[ "$r" != Playing* ]] && return 1

    local a t b
    IFS='|' read -r _ a t b <<< "$r"
    [[ -z "$t" ]] && return 1
    format_output "$a" "$t" "$b"
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    local not_playing
    not_playing=$(get_cached_option "@powerkit_plugin_nowplaying_not_playing" "$POWERKIT_PLUGIN_NOWPLAYING_NOT_PLAYING")
    [[ -z "$content" || "$content" == "$not_playing" ]] && printf '0:::' || printf '1:::'
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local result=""

    if is_macos; then
        result=$(get_macos)
    else
        result=$(get_linux)
    fi

    if [[ -z "$result" ]]; then
        local not_playing
        not_playing=$(get_cached_option "@powerkit_plugin_nowplaying_not_playing" "$POWERKIT_PLUGIN_NOWPLAYING_NOT_PLAYING")
        result="$not_playing"
    fi

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
