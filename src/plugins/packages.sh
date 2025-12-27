#!/usr/bin/env bash
# =============================================================================
# Plugin: packages
# Description: Display pending package updates
# Dependencies: package manager (brew/apt/yum/dnf/pacman/yay)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "packages"
    metadata_set "name" "Packages"
    metadata_set "description" "Display pending package updates"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "brew" "apt" "yum" "dnf" "pacman" "yay" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Backend selection
    declare_option "backend" "enum" "auto" "Package manager: auto, brew, yay, apt, dnf, yum, pacman"
    declare_option "brew_options" "string" "--greedy" "Additional options for brew outdated"

    # Display options
    declare_option "show_count" "bool" "true" "Show update count"

    # Icons
    declare_option "icon" "icon" $'\U0000eb29' "Plugin icon"

    # Thresholds
    declare_option "warning_threshold" "number" "10" "Warning threshold"
    declare_option "critical_threshold" "number" "50" "Critical threshold"

    # Cache (check for updates infrequently)
    declare_option "cache_ttl" "number" "3600" "Cache duration in seconds (1 hour)"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }
plugin_get_state() {
    local count=$(plugin_data_get "update_count")
    [[ "${count:-0}" -gt 0 ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local count warn_th crit_th
    count=$(plugin_data_get "update_count")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    count="${count:-0}"
    warn_th="${warn_th:-10}"
    crit_th="${crit_th:-50}"

    if (( count >= crit_th )); then
        printf 'error'
    elif (( count >= warn_th )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

plugin_get_context() {
    local count=$(plugin_data_get "update_count")
    count="${count:-0}"

    if (( count == 0 )); then
        printf 'up_to_date'
    elif (( count <= 5 )); then
        printf 'few_updates'
    elif (( count <= 20 )); then
        printf 'some_updates'
    else
        printf 'many_updates'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Cache Invalidation (detects when packages were upgraded)
# =============================================================================

# Log files that change when packages are upgraded
declare -A _PKG_LOG_FILES=(
    [pacman]="/var/log/pacman.log"
    [yay]="/var/log/pacman.log"
    [apt]="/var/log/dpkg.log"
    [dnf]="/var/log/dnf.log"
)

_invalidate_if_upgraded() {
    local backend="$1"
    local log_file="${_PKG_LOG_FILES[$backend]:-}"

    # brew: use var/homebrew/linked dir mtime (updated on install/upgrade/uninstall)
    if [[ "$backend" == "brew" ]]; then
        local brew_prefix
        brew_prefix="$(command brew --prefix 2>/dev/null)"
        # Try linked dir first (most reliable), then locks, then Cellar
        for dir in "$brew_prefix/var/homebrew/linked" "$brew_prefix/var/homebrew/locks" "$brew_prefix/Cellar"; do
            if [[ -d "$dir" ]]; then
                log_file="$dir"
                break
            fi
        done
    fi

    [[ -z "$log_file" || ! -e "$log_file" ]] && return 0

    # Check if log/dir is newer than our cache
    local cache_age
    cache_age=$(cache_age "$_PACKAGES_CACHE_KEY")
    [[ -z "$cache_age" || "$cache_age" == "0" ]] && return 0

    local log_mtime current_time log_age
    current_time=$(date +%s)
    if is_macos; then
        log_mtime=$(stat -f %m "$log_file" 2>/dev/null || echo 0)
    else
        log_mtime=$(stat -c %Y "$log_file" 2>/dev/null || echo 0)
    fi

    log_age=$((current_time - log_mtime))

    # If log was modified more recently than cache was created, invalidate
    if (( log_age < cache_age )); then
        cache_clear "$_PACKAGES_CACHE_KEY"
    fi
}

# =============================================================================
# Cache Key
# =============================================================================

_PACKAGES_CACHE_KEY="packages_updates"

# =============================================================================
# Backend Detection
# =============================================================================

_DETECTED_BACKEND=""

_detect_backend() {
    [[ -n "$_DETECTED_BACKEND" ]] && { printf '%s' "$_DETECTED_BACKEND"; return; }

    local backend
    backend=$(get_option "backend")

    case "$backend" in
        brew|yay|apt|dnf|yum|pacman)
            if has_cmd "$backend"; then
                _DETECTED_BACKEND="$backend"
                printf '%s' "$backend"
                return
            fi
            ;;
    esac

    # Auto-detect in priority order
    for pm in brew yay dnf apt yum pacman; do
        if has_cmd "$pm"; then
            _DETECTED_BACKEND="$pm"
            printf '%s' "$pm"
            return
        fi
    done

    printf ''
}

# =============================================================================
# Package Manager Implementations
# =============================================================================

_count_updates_brew() {
    local brew_opts outdated count
    brew_opts=$(get_option "brew_options")
    outdated=$(command brew outdated $brew_opts 2>/dev/null || echo '')
    if [[ -z "$outdated" ]]; then
        count=0
    else
        count=$(printf '%s' "$outdated" | grep -c .)
    fi
    printf '%s' "$count"
}

_count_updates_yay() {
    local outdated count
    outdated=$(command yay -Qu 2>/dev/null || echo "")
    if [[ -z "$outdated" ]]; then
        count=0
    else
        count=$(printf '%s' "$outdated" | wc -l | tr -d ' ')
    fi
    printf '%s' "$count"
}

_count_updates_apt() {
    local count
    count=$(command apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0)
    printf '%s' "$count"
}

_count_updates_dnf() {
    local count
    count=$(command dnf check-update -q 2>/dev/null | grep -c . || echo 0)
    # dnf adds header lines, subtract them
    (( count > 3 )) && count=$((count - 3)) || count=0
    printf '%s' "$count"
}

_count_updates_yum() {
    local count
    count=$(command yum check-update -q 2>/dev/null | grep -c '^[^[:space:]]' || echo 0)
    printf '%s' "$count"
}

_count_updates_pacman() {
    command pacman -Qu 2>/dev/null | wc -l | tr -d ' '
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    local backend count cache_ttl cached
    backend=$(_detect_backend)

    [[ -z "$backend" ]] && {
        plugin_data_set "update_count" "0"
        return 0
    }

    # Invalidate cache if packages were upgraded
    _invalidate_if_upgraded "$backend"

    # Check cache first
    cache_ttl=$(get_option "cache_ttl")
    cached=$(cache_get "$_PACKAGES_CACHE_KEY" "$cache_ttl" 2>/dev/null)

    if [[ -n "$cached" ]]; then
        plugin_data_set "update_count" "$cached"
        plugin_data_set "backend" "$backend"
        return 0
    fi

    # No cache - get fresh count
    case "$backend" in
        brew)   count=$(_count_updates_brew) ;;
        yay)    count=$(_count_updates_yay) ;;
        apt)    count=$(_count_updates_apt) ;;
        dnf)    count=$(_count_updates_dnf) ;;
        yum)    count=$(_count_updates_yum) ;;
        pacman) count=$(_count_updates_pacman) ;;
        *)      count=0 ;;
    esac

    count="${count:-0}"

    # Store in cache
    cache_set "$_PACKAGES_CACHE_KEY" "$count"

    plugin_data_set "update_count" "$count"
    plugin_data_set "backend" "$backend"
}

plugin_render() {
    local count show_count
    count=$(plugin_data_get "update_count")
    show_count=$(get_option "show_count")

    count="${count:-0}"
    [[ "$count" -eq 0 ]] && return 0

    if [[ "$show_count" == "true" ]]; then
        if [[ "$count" -eq 1 ]]; then
            printf '1 update'
        else
            printf '%s updates' "$count"
        fi
    else
        printf 'Updates available'
    fi
}

