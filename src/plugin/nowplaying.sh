#!/usr/bin/env bash
# =============================================================================
# Plugin: nowplaying
# Description: Display currently playing media
# Backends: osascript (macOS), playerctl (Linux MPRIS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    if is_linux; then
        require_cmd "playerctl" || return 1
    fi
    # macOS: no external dependencies
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "format" "string" "%artist% - %track%" "Display format (%artist%, %track%, %album%)"
    declare_option "max_length" "number" "40" "Maximum text length (0 = unlimited)"
    declare_option "not_playing" "string" "" "Text when not playing (empty = hide)"
    declare_option "backend" "string" "auto" "Backend: auto, spotify, music"
    declare_option "ignore_players" "string" "IGNORE" "Comma-separated list of players to ignore (Linux)"

    # Icons
    declare_option "icon" "icon" "󰝚" "Plugin icon"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

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

    format=$(get_option "format")
    max_len=$(get_option "max_length")

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
    has_cmd playerctl || return 1

    local ignore_opt=""
    local ignore_players
    ignore_players=$(get_option "ignore_players")

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
    not_playing=$(get_option "not_playing")
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
        not_playing=$(get_option "not_playing")
        result="$not_playing"
    fi

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
