#!/usr/bin/env bash
# =============================================================================
# Plugin: uptime
# Description: Display system uptime
# Contract-based plugin (PowerKit)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

plugin_get_metadata() {
    metadata_set "id" "uptime"
    metadata_set "name" "Uptime"
    metadata_set "description" "Display system uptime"
}

plugin_declare_options() {
    declare_option "icon" "icon" $'\uf254' "Plugin icon"

    # Cache - uptime changes slowly, no need for frequent updates
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local uptime_str=$(plugin_data_get "uptime")
    # Parse uptime to determine category
    if [[ "$uptime_str" == *d* ]]; then
        printf 'days'
    elif [[ "$uptime_str" == *h* ]]; then
        printf 'hours'
    else
        printf 'minutes'
    fi
}

plugin_collect() {
    local uptime_seconds=""
    if is_linux && [[ -r /proc/uptime ]]; then
        uptime_seconds=$(awk '{printf "%d", $1}' /proc/uptime 2>/dev/null)
    elif is_macos; then
        # macOS: use sysctl to get boot time ('sec' field)
        local boot_time now=$EPOCHSECONDS
        boot_time=$(sysctl -n kern.boottime 2>/dev/null | awk '{gsub(",", "", $4); print $4}')
        if [[ "$boot_time" =~ ^[0-9]+$ ]]; then
            ((uptime_seconds = now - boot_time))
        fi
    else
        # Fallback: parse uptime output. The canonical uptime layout
        # (after the "hh:mm" prefix) is "up N day(s), hh:mm, N users,
        # load averages: ...". With FS='( |,|:)+', the field layout
        # is: $1=hh, $2=mm, $3=up, $4=count, $5=unit. Days may be
        # followed by an additional hh:mm at $6 and $7. Returning -1
        # on anything unparseable lets the caller fail collection so
        # the lifecycle can keep the previous record as stale.
        uptime_seconds=$(uptime 2>/dev/null | awk '{
            sub(/^[[:space:]]+/, "")
            up_idx = 0
            for (i = 1; i <= NF; i++) {
                if ($i == "up") {
                    up_idx = i
                    break
                }
            }
            if (!up_idx) { print -1; exit }
            val = $(up_idx + 1)
            unit = $(up_idx + 2)
            gsub(/,/, "", val)
            gsub(/,/, "", unit)

            if (unit ~ /^min/) {
                print val * 60
            } else if (unit ~ /^hr/) {
                print val * 3600
            } else if (unit ~ /^day/) {
                base = val * 86400
                time_str = $(up_idx + 3)
                gsub(/,/, "", time_str)
                if (split(time_str, t, ":") == 2) {
                    base += (t[1] * 3600) + (t[2] * 60)
                }
                print base
            } else if (split(val, t, ":") == 2) {
                print (t[1] * 3600) + (t[2] * 60)
            } else {
                print -1
            }
        }')
        if [[ "$uptime_seconds" == "-1" ]]; then
            return 1
        fi
    fi
    # If every branch failed to populate uptime_seconds, fail collection
    # so the lifecycle can keep the previous record as stale instead of
    # reporting 0m which is indistinguishable from a fresh boot.
    if [[ -z "$uptime_seconds" ]]; then
        return 1
    fi
    plugin_data_set "uptime" "$(format_uptime_seconds "$uptime_seconds")"
}

plugin_render() {
    plugin_data_get "uptime"
}

plugin_get_icon() {
    get_option "icon"
}
