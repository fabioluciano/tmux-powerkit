#!/usr/bin/env bash
# =============================================================================
# Plugin: nowplaying
# Description: Display currently playing music (macOS/Linux)
# Dependencies: powerkit-nowplaying binary (macOS), playerctl (Linux)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "nowplaying"
    metadata_set "name" "Now Playing"
    metadata_set "description" "Display currently playing music"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        # macOS: require native binary (downloaded on-demand from releases)
        require_macos_binary "powerkit-nowplaying" "nowplaying" || return 1
    else
        require_cmd "playerctl" || return 1
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "format" "string" "%artist% - %title%" "Format: %artist%, %title%, %album%, %app%"
    declare_option "max_length" "number" "40" "Maximum display length"
    declare_option "truncate_suffix" "string" "..." "Truncation suffix"
    declare_option "not_playing" "string" "" "Text when not playing (empty = hide plugin)"
    declare_option "ignore_players" "string" "" "Comma-separated list of players to ignore"

    # Behavior
    declare_option "info_when_paused" "bool" "false" "Use info health when paused"

    # Icons
    declare_option "icon" "icon" $'\U000F075A' "Plugin icon (music note)"
    declare_option "icon_paused" "icon" $'\U000F03E6' "Paused icon"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }
plugin_get_state() {
    local playing=$(plugin_data_get "playing")
    [[ "$playing" == "1" ]] && printf 'active' || printf 'inactive'
}
plugin_get_health() {
    local state=$(plugin_data_get "state")
    local info_when_paused=$(get_option "info_when_paused")

    if [[ "$state" == "paused" && "$info_when_paused" == "true" ]]; then
        printf 'info'
    else
        printf 'ok'
    fi
}

plugin_get_context() {
    local state=$(plugin_data_get "state")
    printf '%s' "${state:-stopped}"
}

plugin_get_icon() {
    local state=$(plugin_data_get "state")
    local app=$(plugin_data_get "app")

    # Check if paused first
    if [[ "$state" != "playing" ]]; then
        get_option "icon_paused"
        return
    fi

    # Check if app has a known icon
    if [[ -n "$app" && -n "${_PLAYER_ICONS[$app]:-}" ]]; then
        printf '%s' "${_PLAYER_ICONS[$app]}"
    else
        get_option "icon"
    fi
}

# =============================================================================
# Main Logic
# =============================================================================

# Unit Separator (ASCII 31) - matches binary output
_FIELD_SEP=$'\x1F'

# Known player icons (app name lowercase -> icon)
declare -A _PLAYER_ICONS=(
    [spotify]=$'\U0000F1BC'        # Spotify logo
    [music]=$'\U000F075A'          # Apple Music (music note)
    [apple music]=$'\U000F075A'    # Apple Music alternate name
    [itunes]=$'\U000F075A'         # iTunes (legacy)
    [youtube]=$'\U000F05A9'        # YouTube
    [youtube music]=$'\U000F05A9'  # YouTube Music
    [vlc]=$'\U000F057C'            # VLC cone
    [firefox]=$'\U000F0239'        # Firefox
    [chrome]=$'\U000F0288'         # Chrome
    [chromium]=$'\U000F0288'       # Chromium
    [brave]=$'\U000F097D'          # Brave
    [safari]=$'\U000F0585'         # Safari
    [edge]=$'\U000F0845'           # Edge
    [tidal]=$'\U000F075A'          # TIDAL (music note)
    [deezer]=$'\U000F075A'         # Deezer (music note)
    [amazon music]=$'\U000F075A'   # Amazon Music (music note)
    [soundcloud]=$'\U000F04F5'     # SoundCloud
    [audacious]=$'\U000F075A'      # Audacious
    [rhythmbox]=$'\U000F075A'      # Rhythmbox
    [clementine]=$'\U000F075A'     # Clementine
    [cmus]=$'\U000F075A'           # cmus
    [mpv]=$'\U000F057C'            # mpv
    [mplayer]=$'\U000F057C'        # mplayer
    [foobar2000]=$'\U000F075A'     # foobar2000
    [winamp]=$'\U000F075A'         # Winamp
    [strawberry]=$'\U000F075A'     # Strawberry
    [elisa]=$'\U000F075A'          # Elisa
    [lollypop]=$'\U000F075A'       # Lollypop
    [gnome music]=$'\U000F075A'    # GNOME Music
    [plasma-browser-integration]=$'\U000F075A'  # KDE browser integration
)

# macOS: Native binary using ScriptingBridge for Spotify/Music
_get_nowplaying_macos() {
    local binary="${POWERKIT_ROOT}/bin/powerkit-nowplaying"
    [[ -x "$binary" ]] || return 1

    local output
    output=$("$binary" 2>/dev/null) || return 1
    [[ -z "$output" ]] && return 1

    # Check if app should be ignored
    local ignore_players
    ignore_players=$(get_option "ignore_players")
    if [[ -n "$ignore_players" ]]; then
        local app
        app=$(echo "$output" | cut -d"$_FIELD_SEP" -f5)
        local IFS=','
        local p
        for p in $ignore_players; do
            p=$(trim "$p")
            # Case-insensitive comparison
            [[ "${app,,}" == "${p,,}" ]] && return 1
        done
    fi

    # Output format: state\x1Fartist\x1Ftitle\x1Falbum\x1Fapp
    printf '%s' "$output"
}

# Linux: playerctl backend
_get_nowplaying_linux() {
    local state artist title album app
    local ignore_opt=""
    local ignore_players
    ignore_players=$(get_option "ignore_players")

    # Build ignore player options
    if [[ -n "$ignore_players" ]]; then
        local IFS=','
        local p
        for p in $ignore_players; do
            p=$(trim "$p")
            [[ -n "$p" ]] && ignore_opt+=" --ignore-player=$p"
        done
    fi

    # shellcheck disable=SC2086
    state=$(playerctl $ignore_opt status 2>/dev/null | tr '[:upper:]' '[:lower:]')
    [[ -z "$state" ]] && return 1

    # Get all metadata in one call using format string
    # shellcheck disable=SC2086
    local metadata
    metadata=$(playerctl $ignore_opt metadata --format '{{artist}}'"$_FIELD_SEP"'{{title}}'"$_FIELD_SEP"'{{album}}'"$_FIELD_SEP"'{{playerName}}' 2>/dev/null)

    IFS="$_FIELD_SEP" read -r artist title album app <<< "$metadata"

    [[ -z "$title" ]] && return 1

    # Output: state, artist, title, album, app (same format as macOS)
    printf '%s%s%s%s%s%s%s%s%s' "$state" "$_FIELD_SEP" "$artist" "$_FIELD_SEP" "$title" "$_FIELD_SEP" "$album" "$_FIELD_SEP" "$app"
}

plugin_collect() {
    local nowplaying

    if is_macos; then
        nowplaying=$(_get_nowplaying_macos)
    else
        nowplaying=$(_get_nowplaying_linux)
    fi

    if [[ -n "$nowplaying" ]]; then
        local state artist title album app
        IFS="$_FIELD_SEP" read -r state artist title album app <<< "$nowplaying"

        # Validate we have at least a title
        [[ -z "$title" ]] && { plugin_data_set "playing" "0"; return; }

        # Normalize app name to lowercase
        app="${app,,}"

        plugin_data_set "playing" "1"
        plugin_data_set "state" "$state"
        plugin_data_set "artist" "$artist"
        plugin_data_set "title" "$title"
        plugin_data_set "album" "$album"
        plugin_data_set "app" "$app"
    else
        plugin_data_set "playing" "0"
    fi
}

plugin_render() {
    local playing format max_len suffix
    playing=$(plugin_data_get "playing")
    format=$(get_option "format")
    max_len=$(get_option "max_length")
    suffix=$(get_option "truncate_suffix")

    [[ "$playing" != "1" ]] && return 0

    local artist title album app
    artist=$(plugin_data_get "artist")
    title=$(plugin_data_get "title")
    album=$(plugin_data_get "album")
    app=$(plugin_data_get "app")

    # Escape & in values before substitution
    # In bash parameter expansion replacement, & means "the matched pattern"
    # So "Day & Night" replacing %title% becomes "Day %title% Night"
    # We escape & as \& to make it literal
    artist="${artist//&/\\&}"
    title="${title//&/\\&}"
    album="${album//&/\\&}"
    app="${app//&/\\&}"

    # Replace placeholders in format
    local result="$format"
    result="${result//%artist%/$artist}"
    result="${result//%title%/$title}"
    result="${result//%album%/$album}"
    result="${result//%app%/$app}"

    # Clean up format when fields are empty
    result="${result#- }"      # Remove leading "- "
    result="${result# - }"     # Remove leading " - "
    result="${result% -}"      # Remove trailing " -"
    result="${result% - }"     # Remove trailing " - "

    # Truncate if needed (truncate_words respects word boundaries)
    result=$(truncate_words "$result" "$max_len" "$suffix")

    printf '%s' "$result"
}

