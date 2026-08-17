#!/usr/bin/env bash
# =============================================================================
# Plugin: packages
# Description: Display pending package updates (multi-backend)
# Dependencies: package manager (brew/zb/apt/yum/dnf/pacman/yay/nix-env/mise/
#               flatpak/zypper/emerge/apk/pkg/snap/pamac/port)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "packages"
    metadata_set "name" "Packages"
    metadata_set "description" "Display pending package updates (multi-backend)"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd \
        "brew" "zb" "apt" "yum" "dnf" "pacman" "yay" \
        "nix-env" "mise" "flatpak" "zypper" "emerge" \
        "apk" "pkg" "snap" "pamac" "port" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Backend selection
    declare_option "backend"  "enum"   "auto" "Single package manager (legacy): auto, brew, zb, yay, apt, dnf, yum, pacman, nix, mise, flatpak, zypper, emerge, apk, pkg, snap, pamac, port"
    declare_option "backends" "string" ""     "Comma-separated backends to aggregate (e.g. 'brew,zb'). Overrides 'backend' option."
    declare_option "brew_options" "string" "" "Additional options for brew outdated (e.g., '--greedy' for all casks)"

    # Display options
    declare_option "show_count" "bool" "true" "Show update count"
    declare_option "update_display" "enum" "total" "Show total, security, or both update counts"

    # Icons
    declare_option "icon" "icon" $'\U0000eb29' "Plugin icon"

    # Thresholds
    declare_option "warning_threshold" "number" "10" "Warning threshold"
    declare_option "critical_threshold" "number" "50" "Critical threshold"

    # Cache settings:
    # - cache_ttl: render cache (short) - how often to check for invalidation
    # - packages_cache_ttl: expensive operation cache (long) - how often to actually run brew outdated
    declare_option "cache_ttl" "number" "60" "Render cache duration (short, for invalidation checks)"
    declare_option "packages_cache_ttl" "number" "3600" "Package check cache duration (1 hour)"
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

    if ((count >= crit_th)); then
        printf 'error'
    elif ((count >= warn_th)); then
        printf 'warning'
    else
        printf 'info'
    fi
}

plugin_get_context() {
    local count=$(plugin_data_get "update_count")
    count="${count:-0}"

    if ((count == 0)); then
        printf 'up_to_date'
    elif ((count <= 5)); then
        printf 'few_updates'
    elif ((count <= 20)); then
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
    [pamac]="/var/log/pacman.log"
    [apt]="/var/log/dpkg.log"
    [dnf]="/var/log/dnf.log"
    [zypper]="/var/log/zypp/history"
    [apk]="/var/log/apk/world"
    [snap]="/var/log/syslog"
)

# Invalidate the per-backend cache if the package log/dir was modified
# more recently than the cache was written (i.e., packages were upgraded
# since the last check).
_invalidate_backend_cache() {
    local backend="$1"
    local log_file="${_PKG_LOG_FILES[$backend]:-}"

    # brew / zb / port: use a directory mtime instead of a log file
    case "$backend" in
    brew)
        local brew_prefix
        brew_prefix="$(command brew --prefix 2>/dev/null)"
        for dir in "$brew_prefix/var/homebrew/linked" \
                   "$brew_prefix/var/homebrew/locks" \
                   "$brew_prefix/Cellar"; do
            [[ -d "$dir" ]] && { log_file="$dir"; break; }
        done
        ;;
    zb)
        for dir in "/opt/zerobrew/var/homebrew/linked" \
                   "/opt/zerobrew/Cellar" \
                   "/opt/zerobrew"; do
            [[ -d "$dir" ]] && { log_file="$dir"; break; }
        done
        ;;
    port)
        for dir in "/opt/local/var/db/port" "/opt/local"; do
            [[ -d "$dir" ]] && { log_file="$dir"; break; }
        done
        ;;
    esac

    [[ -z "$log_file" || ! -e "$log_file" ]] && return 0

    local log_mtime log_age
    local current_time=$EPOCHSECONDS
    if is_macos; then
        log_mtime=$(stat -f %m "$log_file" 2>/dev/null || echo 0)
    else
        log_mtime=$(stat -c %Y "$log_file" 2>/dev/null || echo 0)
    fi

    log_age=$((current_time - log_mtime))

    local pkg_cache_age
    pkg_cache_age=$(cache_age "$(_pkg_cache_key "$backend")")

    [[ "${pkg_cache_age:-0}" -le 0 ]] && return 0

    if ((log_age < pkg_cache_age)); then
        cache_clear "$(_pkg_cache_key "$backend")"
        cache_clear "$(_pkg_security_cache_key "$backend")"
        cache_clear "plugin_packages_data"
    fi
}

_invalidate_if_upgraded() {
    local backends_str="$1"
    local backend
    for backend in $backends_str; do
        _invalidate_backend_cache "$backend"
    done
}

# =============================================================================
# Cache Keys (per-backend)
# =============================================================================

_pkg_cache_key()          { printf 'packages_updates_%s' "$1"; }
_pkg_security_cache_key() { printf 'packages_security_updates_%s' "$1"; }

# =============================================================================
# Backend Detection (multi-backend)
# =============================================================================

_DETECTED_BACKENDS=""

_detect_backends() {
    [[ -n "$_DETECTED_BACKENDS" ]] && { printf '%s' "$_DETECTED_BACKENDS"; return; }

    # Mode 1 — explicit list: @powerkit_packages_backends "brew,zb"
    local configured
    configured=$(get_option "backends")
    if [[ -n "$configured" ]]; then
        local active=()
        IFS=',' read -ra requested <<< "$configured"
        local b
        for b in "${requested[@]}"; do
            b="$(trim "$b")"
            [[ -n "$b" ]] && has_cmd "$b" && active+=("$b")
        done
        _DETECTED_BACKENDS="${active[*]}"
        printf '%s' "$_DETECTED_BACKENDS"
        return
    fi

    # Mode 2 — legacy single: @powerkit_packages_backend "brew"
    local single
    single=$(get_option "backend")
    if [[ "$single" != "auto" ]]; then
        if has_cmd "$single"; then
            _DETECTED_BACKENDS="$single"
        fi
        printf '%s' "$_DETECTED_BACKENDS"
        return
    fi

    # Mode 3 — auto: detect ALL available package managers
    local detected=()
    local pm
    for pm in brew zb port yay pacman pamac dnf apt yum \
              nix-env mise flatpak zypper emerge apk pkg snap; do
        has_cmd "$pm" && detected+=("$pm")
    done
    _DETECTED_BACKENDS="${detected[*]}"
    printf '%s' "$_DETECTED_BACKENDS"
}

# =============================================================================
# Package Manager Implementations
# =============================================================================

# Timeout wrapper for package manager calls (prevents hanging)
_timeout_pkg() {
    local timeout=30
    if has_cmd "timeout"; then
        timeout "$timeout" "$@"
    elif has_cmd "gtimeout"; then
        gtimeout "$timeout" "$@"
    else
        "$@" # no timeout available
    fi
}

_count_updates_brew() {
    local brew_opts outdated count
    brew_opts=$(get_option "brew_options")

    local brew_args=("outdated")
    if [[ -n "$brew_opts" ]]; then
        IFS=',' read -ra opts <<< "$brew_opts"
        local opt
        for opt in "${opts[@]}"; do
            brew_args+=("$(trim "$opt")")
        done
    fi

    outdated=$(_timeout_pkg command brew "${brew_args[@]}" 2>/dev/null || echo '')
    if [[ -z "$outdated" ]]; then
        count=0
    else
        count=$(printf '%s' "$outdated" | grep -c .)
    fi
    printf '%s' "$count"
}

_count_updates_zb() {
    local outdated count
    outdated=$(_timeout_pkg command zb outdated 2>/dev/null || echo '')
    if [[ -z "$outdated" ]]; then
        count=0
    else
        count=$(printf '%s' "$outdated" | grep -c .)
    fi
    printf '%s' "${count:-0}"
}

_count_updates_yay() {
    local outdated count
    outdated=$(_timeout_pkg command yay -Qu 2>/dev/null || echo "")
    if [[ -z "$outdated" ]]; then
        count=0
    else
        count=$(printf '%s' "$outdated" | wc -l | tr -d ' ')
    fi
    printf '%s' "$count"
}

_count_updates_apt() {
    local count
    count=$(_timeout_pkg command apt list --upgradable 2>/dev/null | grep -c '/.*upgradable' || echo 0)
    printf '%s' "$count"
}

_count_updates_dnf() {
    local count
    count=$(_timeout_pkg command dnf check-update -q 2>/dev/null | grep -c . || echo 0)
    # dnf adds header lines, subtract them
    ((count > 3)) && count=$((count - 3)) || count=0
    printf '%s' "$count"
}

_count_updates_yum() {
    local count
    count=$(_timeout_pkg command yum check-update -q 2>/dev/null | grep -c '^[^[:space:]]' || echo 0)
    printf '%s' "$count"
}

_count_updates_pacman() {
    _timeout_pkg command pacman -Qu 2>/dev/null | wc -l | tr -d ' '
}

_count_updates_nix-env() {
    # nix-env -qc: '<' = newer version available, '=' = up to date, '>' = newer than channel
    local count
    count=$(_timeout_pkg command nix-env -qc 2>/dev/null | grep -c ' < ' || echo 0)
    printf '%s' "${count:-0}"
}

_count_updates_mise() {
    local count
    count=$(_timeout_pkg command mise outdated 2>/dev/null | grep -c . || echo 0)
    printf '%s' "${count:-0}"
}

_count_updates_flatpak() {
    local count
    count=$(_timeout_pkg command flatpak remote-ls --updates 2>/dev/null | grep -c . || echo 0)
    printf '%s' "${count:-0}"
}

_count_updates_zypper() {
    # zypper lu: update lines start with 'v' (version) or 'i' (install candidate)
    local count
    count=$(_timeout_pkg command zypper --non-interactive lu 2>/dev/null \
        | grep -c '^v\|^i' || echo 0)
    printf '%s' "${count:-0}"
}

_count_updates_emerge() {
    local count
    if has_cmd "eix"; then
        # eix is much faster than emerge -p
        count=$(_timeout_pkg command eix -u --only-names 2>/dev/null | grep -c . || echo 0)
    else
        # Fallback: emerge -puDN can be slow (30-60s); the 1h TTL cache mitigates this
        count=$(_timeout_pkg command emerge -puDN --quiet @world 2>/dev/null \
            | grep -c '^\[ebuild' || echo 0)
    fi
    printf '%s' "${count:-0}"
}

_count_updates_apk() {
    local count
    count=$(_timeout_pkg command apk list -u 2>/dev/null | grep -c . || echo 0)
    printf '%s' "${count:-0}"
}

_count_updates_pkg() {
    # FreeBSD: pkg version -l '<' lists packages with an older installed version
    local count
    count=$(_timeout_pkg command pkg version -l '<' 2>/dev/null | grep -c . || echo 0)
    printf '%s' "${count:-0}"
}

_count_updates_snap() {
    # snap refresh --list: first line is a header; skip it
    local outdated count
    outdated=$(_timeout_pkg command snap refresh --list 2>/dev/null | tail -n +2 || echo '')
    if [[ -z "$outdated" ]]; then
        count=0
    else
        count=$(printf '%s' "$outdated" | grep -c .)
    fi
    printf '%s' "${count:-0}"
}

_count_updates_pamac() {
    local count
    count=$(_timeout_pkg command pamac checkupdates --quiet 2>/dev/null | grep -c . || echo 0)
    printf '%s' "${count:-0}"
}

_count_updates_port() {
    # MacPorts: port outdated lists outdated ports, one per line
    local count
    count=$(_timeout_pkg command port outdated 2>/dev/null | grep -c . || echo 0)
    printf '%s' "${count:-0}"
}

_count_security_updates() {
    local backend="$1"

    case "$backend" in
    apt)
        _timeout_pkg command apt-get -s upgrade 2>/dev/null | awk '/^Inst .*security/ { count++ } END { print count + 0 }'
        ;;
    dnf | yum)
        _timeout_pkg command "$backend" check-update --security -q 2>/dev/null | grep -c '^[^[:space:]]' || true
        ;;
    *)
        return 1
        ;;
    esac
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    local backends_str packages_cache_ttl display
    backends_str=$(_detect_backends)

    [[ -z "$backends_str" ]] && {
        plugin_data_set "update_count" "0"
        return 0
    }

    # Invalidate per-backend caches when packages were upgraded
    _invalidate_if_upgraded "$backends_str"

    packages_cache_ttl=$(get_option "packages_cache_ttl")
    display=$(get_option "update_display")

    local total=0
    local -a backends
    read -ra backends <<< "$backends_str"

    for backend in "${backends[@]}"; do
        local cache_key count cached
        cache_key=$(_pkg_cache_key "$backend")
        cached=$(cache_get "$cache_key" "$packages_cache_ttl" 2>/dev/null)

        if [[ -n "$cached" ]]; then
            count="$cached"
        else
            # Dispatch to per-backend implementation.
            # nix-env has a hyphen, so we cannot use a simple function name dispatch —
            # we handle it explicitly in the case statement.
            case "$backend" in
            brew)    count=$(_count_updates_brew) ;;
            zb)      count=$(_count_updates_zb) ;;
            yay)     count=$(_count_updates_yay) ;;
            apt)     count=$(_count_updates_apt) ;;
            dnf)     count=$(_count_updates_dnf) ;;
            yum)     count=$(_count_updates_yum) ;;
            pacman)  count=$(_count_updates_pacman) ;;
            nix-env) count=$(_count_updates_nix-env) ;;
            mise)    count=$(_count_updates_mise) ;;
            flatpak) count=$(_count_updates_flatpak) ;;
            zypper)  count=$(_count_updates_zypper) ;;
            emerge)  count=$(_count_updates_emerge) ;;
            apk)     count=$(_count_updates_apk) ;;
            pkg)     count=$(_count_updates_pkg) ;;
            snap)    count=$(_count_updates_snap) ;;
            pamac)   count=$(_count_updates_pamac) ;;
            port)    count=$(_count_updates_port) ;;
            *)       count=0 ;;
            esac

            count="${count:-0}"
            cache_set "$cache_key" "$count"
        fi

        (( total += count ))
    done

    plugin_data_set "update_count" "$total"
    plugin_data_set "backends"     "$backends_str"

    [[ "$display" == "total" ]] && return 0

    # Security update counts (only for backends that support it: apt, dnf, yum)
    local sec_total=0
    for backend in "${backends[@]}"; do
        local sec_key sec_count sec_cached
        sec_key=$(_pkg_security_cache_key "$backend")
        sec_cached=$(cache_get "$sec_key" "$packages_cache_ttl" 2>/dev/null)

        if [[ -n "$sec_cached" ]]; then
            sec_count="$sec_cached"
        else
            sec_count=$(_count_security_updates "$backend") || sec_count=""
            [[ -n "$sec_count" ]] && cache_set "$sec_key" "$sec_count"
        fi
        (( sec_total += ${sec_count:-0} ))
    done
    plugin_data_set "security_update_count" "$sec_total"
}

plugin_render() {
    local count security_count show_count display
    count=$(plugin_data_get "update_count")
    show_count=$(get_option "show_count")
    display=$(get_option "update_display")
    security_count=$(plugin_data_get "security_update_count")

    count="${count:-0}"
    [[ "$count" -eq 0 ]] && return 0

    if [[ "$display" == "security" && -n "$security_count" ]]; then
        printf '%s security updates' "$security_count"
    elif [[ "$display" == "both" && -n "$security_count" ]]; then
        printf '%s updates (%s security)' "$count" "$security_count"
    elif [[ "$show_count" == "true" ]]; then
        if [[ "$count" -eq 1 ]]; then
            printf '1 update'
        else
            printf '%s updates' "$count"
        fi
    else
        printf 'Updates available'
    fi
}
