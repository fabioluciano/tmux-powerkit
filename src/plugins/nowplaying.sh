#!/usr/bin/env bash
# =============================================================================
# Plugin: nowplaying
# Description: Display currently playing music (macOS/Linux)
# Dependencies: osascript (macOS), playerctl (Linux)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "nowplaying"
    metadata_set "name" "Now Playing"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display currently playing music"
    metadata_set "priority" "120"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "osascript" || return 1
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
    declare_option "format" "string" "%artist% - %title%" "Format string (%artist%, %title%, %album%)"
    declare_option "max_length" "number" "40" "Maximum display length"
    declare_option "truncate_suffix" "string" "..." "Truncation suffix"
    declare_option "not_playing" "string" "" "Text when not playing (empty = hide plugin)"
    declare_option "backend" "string" "auto" "Backend: auto, nowplaying-cli, osascript, playerctl"
    declare_option "ignore_players" "string" "" "Comma-separated list of players to ignore (Linux)"

    # Icons
    declare_option "icon" "icon" $'\U000F075A' "Plugin icon (music note)"
    declare_option "icon_paused" "icon" $'\U000F03E4' "Paused icon"

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
plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local state=$(plugin_data_get "state")
    printf '%s' "${state:-stopped}"
}

plugin_get_icon() {
    local state=$(plugin_data_get "state")
    [[ "$state" == "playing" ]] && get_option "icon" || get_option "icon_paused"
}

# =============================================================================
# Main Logic
# =============================================================================

# nowplaying-cli backend (macOS) - works with ANY app that uses Now Playing
# Install: brew install nowplaying-cli
_get_nowplaying_cli() {
    has_cmd "nowplaying-cli" || return 1
    
    local state artist title
    state=$(nowplaying-cli get playbackRate 2>/dev/null)
    
    # playbackRate: 1 = playing, 0 = paused/stopped
    if [[ "$state" == "1" ]]; then
        state="playing"
    elif [[ "$state" == "0" ]]; then
        state="paused"
    else
        return 1
    fi
    
    artist=$(nowplaying-cli get artist 2>/dev/null)
    title=$(nowplaying-cli get title 2>/dev/null)
    
    # nowplaying-cli returns literal "null" for missing values
    [[ "$artist" == "null" ]] && artist=""
    [[ "$title" == "null" ]] && title=""
    
    [[ -z "$title" ]] && return 1
    
    printf '%s|%s|%s' "$state" "$artist" "$title"
}

# osascript backend (macOS) - only Spotify and Music
_get_nowplaying_osascript() {
    # Single osascript call - much faster than multiple calls
    # Returns: state|artist|title or empty if no player active
    osascript 2>/dev/null <<'EOF'
-- Try Music first
try
    tell application "System Events"
        if exists process "Music" then
            tell application "Music"
                set ps to player state as string
                if ps is in {"playing", "paused"} then
                    set a to artist of current track
                    set t to name of current track
                    return ps & "|" & a & "|" & t
                end if
            end tell
        end if
    end tell
end try

-- Try Spotify
try
    tell application "System Events"
        if exists process "Spotify" then
            tell application "Spotify"
                set ps to player state as string
                if ps is in {"playing", "paused"} then
                    set a to artist of current track
                    set t to name of current track
                    return ps & "|" & a & "|" & t
                end if
            end tell
        end if
    end tell
end try

return ""
EOF
}

_get_nowplaying_macos() {
    local backend
    backend=$(get_option "backend")
    
    case "$backend" in
        nowplaying-cli)
            _get_nowplaying_cli
            ;;
        osascript)
            _get_nowplaying_osascript
            ;;
        auto|*)
            # Try nowplaying-cli first (works with all apps), fallback to osascript
            _get_nowplaying_cli || _get_nowplaying_osascript
            ;;
    esac
}

_get_nowplaying_linux() {
    local state artist title
    local ignore_opt=""
    local ignore_players
    ignore_players=$(get_option "ignore_players")

    # Build ignore player options
    if [[ -n "$ignore_players" ]]; then
        local IFS=','
        local p
        for p in $ignore_players; do
            p="${p#"${p%%[![:space:]]*}"}"  # trim leading
            p="${p%"${p##*[![:space:]]}"}"  # trim trailing
            [[ -n "$p" ]] && ignore_opt+=" --ignore-player=$p"
        done
    fi

    # shellcheck disable=SC2086
    state=$(playerctl $ignore_opt status 2>/dev/null | tr '[:upper:]' '[:lower:]')
    [[ -z "$state" ]] && return 1

    # shellcheck disable=SC2086
    artist=$(playerctl $ignore_opt metadata artist 2>/dev/null)
    # shellcheck disable=SC2086
    title=$(playerctl $ignore_opt metadata title 2>/dev/null)

    printf '%s|%s|%s' "$state" "$artist" "$title"
}

plugin_collect() {
    local nowplaying

    if is_macos; then
        nowplaying=$(_get_nowplaying_macos)
    else
        nowplaying=$(_get_nowplaying_linux)
    fi

    if [[ -n "$nowplaying" ]]; then
        IFS='|' read -r state artist title <<< "$nowplaying"
        
        plugin_data_set "playing" "1"
        plugin_data_set "state" "$state"
        plugin_data_set "artist" "$artist"
        plugin_data_set "title" "$title"
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

    local artist title
    artist=$(plugin_data_get "artist")
    title=$(plugin_data_get "title")

    # Replace placeholders in format
    local result="$format"
    result="${result//%artist%/$artist}"
    result="${result//%title%/$title}"
    
    # Clean up format when artist is empty (e.g., "%artist% - %title%" -> "- title" -> "title")
    result="${result#- }"      # Remove leading "- "
    result="${result# - }"     # Remove leading " - "
    result="${result% -}"      # Remove trailing " -"
    result="${result% - }"     # Remove trailing " - "

    # Truncate if needed
    if [[ "${#result}" -gt "$max_len" ]]; then
        result="${result:0:$((max_len - ${#suffix}))}${suffix}"
    fi

    printf '%s' "$result"
}

