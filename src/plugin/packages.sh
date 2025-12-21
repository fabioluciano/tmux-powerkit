#!/usr/bin/env bash
# =============================================================================
# Plugin: packages
# Description: Display number of outdated packages (brew, yay, apt, dnf, pacman)
# Type: conditional (hides when no updates available)
# Dependencies: brew, yay, apt, dnf, or pacman (at least one required)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    # Need at least one package manager
    require_any_cmd "brew" "yay" "apt" "dnf" "pacman" || return 1
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "backend" "string" "auto" "Package manager: auto, brew, yay, apt, dnf, pacman"
    declare_option "brew_options" "string" "--greedy" "Additional options for brew outdated"

    # Icons
    declare_option "icon" "icon" $'\ueb29' "Plugin icon"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "3600" "Cache duration in seconds"
}

plugin_init "packages"
LOCK_DIR="${CACHE_DIR:-$HOME/.cache/tmux-powerkit}/packages_updating.lock"

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    local show="1"
    [[ -z "$content" || "$content" == "0" || "$content" == "0 updates" ]] && show="0"
    build_display_info "$show" "" "" ""
}

# =============================================================================
# Helper Functions
# =============================================================================

_DETECTED_PACKAGE_MANAGER=""

# Log files that change when packages are upgraded (for cache invalidation)
declare -A _PKG_LOG_FILES=(
    [pacman]="/var/log/pacman.log"
    [yay]="/var/log/pacman.log"
    [apt]="/var/log/dpkg.log"
    [dnf]="/var/log/dnf.log"
)

# Invalidate cache if packages were upgraded (log newer than cache)
_invalidate_if_upgraded() {
    local log_file="${_PKG_LOG_FILES[$1]:-}"
    local cache_file="${CACHE_DIR}/${CACHE_KEY}.cache"
    
    # brew: use var/homebrew/linked dir mtime (updated on install/upgrade/uninstall)
    if [[ "$1" == "brew" ]]; then
        local brew_prefix
        brew_prefix="$(command brew --prefix 2>/dev/null)"
        # Try linked dir first (most reliable), then locks, then Cellar
        for dir in "$brew_prefix/var/homebrew/linked" "$brew_prefix/var/homebrew/locks" "$brew_prefix/Cellar"; do
            [[ -d "$dir" ]] && { log_file="$dir"; break; }
        done
    fi
    
    [[ ! -e "$log_file" || ! -f "$cache_file" ]] && return
    [[ "$log_file" -nt "$cache_file" ]] && cache_invalidate "$CACHE_KEY"
}

_detect_backend() {
    [[ -n "$_DETECTED_PACKAGE_MANAGER" ]] && { echo "$_DETECTED_PACKAGE_MANAGER"; return; }

    local backend
    backend=$(get_option "backend")

    case "$backend" in
        brew|yay|apt|dnf|pacman)
            has_cmd "$backend" && _DETECTED_PACKAGE_MANAGER="$backend" && echo "$backend" && return ;;
        auto|*)
            for pm in brew yay dnf apt pacman; do
                has_cmd "$pm" && _DETECTED_PACKAGE_MANAGER="$pm" && echo "$pm" && return
            done ;;
    esac
    echo ""
}

_is_updating() {
    [[ ! -d "$LOCK_DIR" ]] && return 1
    local lock_age current_time dir_mtime
    current_time=$(date +%s)
    is_macos && dir_mtime=$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) || dir_mtime=$(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
    lock_age=$((current_time - dir_mtime))
    [[ $lock_age -lt 300 ]] && return 0
    rmdir "$LOCK_DIR" 2>/dev/null
    return 1
}

_count_with_background_update() {
    local cmd="$1"
    local cached
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null)

    { [[ -n "$cached" ]] || _is_updating; } && { printf '%s' "${cached:-0}"; return 0; }
    mkdir "$LOCK_DIR" 2>/dev/null || { printf '%s' "${cached:-0}"; return 0; }

    ( eval "$cmd"; rmdir "$LOCK_DIR" 2>/dev/null ) &>/dev/null &
    printf '%s' "${cached:-0}"
}

_count_packages_brew() {
    local brew_opts
    brew_opts=$(get_option "brew_options")
    _count_with_background_update "
        local outdated count
        outdated=\$(command brew outdated $brew_opts 2>/dev/null || echo '')
        [[ -z \"\$outdated\" ]] && count=0 || count=\$(printf '%s' \"\$outdated\" | grep -c .)
        cache_set '$CACHE_KEY' \"\$count\"
    "
}

_count_packages_yay() {
    local cached count outdated
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null)
    [[ -n "$cached" ]] && { printf '%s' "$cached"; return 0; }

    outdated=$(command yay -Qu 2>/dev/null || echo "")
    [[ -z "$outdated" ]] && count=0 || count=$(printf '%s' "$outdated" | wc -l)
    cache_set "$CACHE_KEY" "$count"
    printf '%s' "$count"
}

_count_packages_apt() {
    _count_with_background_update "
        command apt update &>/dev/null
        local count=\$(command apt list --upgradable 2>/dev/null | grep -c upgradable)
        cache_set '$CACHE_KEY' \"\$count\"
    "
}

_count_packages_dnf() {
    _count_with_background_update "
        local count=\$(command dnf check-update -q 2>/dev/null | grep -c .)
        [[ \$count -gt 3 ]] && count=\$((count - 3)) || count=0
        cache_set '$CACHE_KEY' \"\$count\"
    "
}

_count_packages_pacman() {
    local cached count
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null)
    [[ -n "$cached" ]] && { printf '%s' "$cached"; return 0; }

    count=$(command pacman -Qu 2>/dev/null | wc -l)
    cache_set "$CACHE_KEY" "$count"
    printf '%s' "$count"
}

_format_output() {
    local count="$1"
    [[ "$count" -eq 0 ]] && return 0
    [[ "$count" -eq 1 ]] && printf '1 update' || printf '%s updates' "$count"
}

# =============================================================================
# Main Logic
# =============================================================================

load_plugin() {
    local backend
    backend=$(_detect_backend)
    [[ -z "$backend" ]] && return 0

    _invalidate_if_upgraded "$backend"

    if [[ "$backend" != "yay" && "$backend" != "pacman" ]]; then
        local cached_value
        if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null); then
            _format_output "$cached_value"
            return 0
        fi
    fi

    local count=0
    case "$backend" in
        brew)   count=$(_count_packages_brew) ;;
        yay)    count=$(_count_packages_yay) ;;
        apt)    count=$(_count_packages_apt) ;;
        dnf)    count=$(_count_packages_dnf) ;;
        pacman) count=$(_count_packages_pacman) ;;
    esac

    [[ "$backend" == "yay" || "$backend" == "pacman" ]] && cache_set "$CACHE_KEY" "$count"
    _format_output "$count"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
