#!/usr/bin/env bash
# Plugin: network - Display network upload/download speeds (delta-based, no sleep)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "network"
CACHE_KEY_PREV="network_prev"

plugin_get_type() { printf 'conditional'; }

bytes_to_speed() {
    local bytes=$1
    [[ $bytes -le 0 ]] && { printf '0B'; return; }

    # Compact output with consistent formatting
    if [[ $bytes -ge $POWERKIT_BYTE_GB ]]; then
        awk "BEGIN {printf \"%.1fG\", $bytes / $POWERKIT_BYTE_GB}"
    elif [[ $bytes -ge $POWERKIT_BYTE_MB ]]; then
        awk "BEGIN {printf \"%.1fM\", $bytes / $POWERKIT_BYTE_MB}"
    elif [[ $bytes -ge $POWERKIT_BYTE_KB ]]; then
        awk "BEGIN {printf \"%.0fK\", $bytes / $POWERKIT_BYTE_KB}"
    else
        printf '%dB' "$bytes"
    fi
}

get_default_interface() {
    local cache_key="network_interface"
    local cached_interface
    
    if cached_interface=$(cache_get "$cache_key" "$POWERKIT_TIMING_CACHE_INTERFACE"); then
        printf '%s' "$cached_interface"
        return
    fi
    
    local interface=""
    is_linux && interface=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
    is_macos && interface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2; exit}')
    
    [[ -n "$interface" ]] && cache_set "$cache_key" "$interface"
    printf '%s' "$interface"
}

get_bytes_linux() {
    local interface="$1"
    local rx_file="/sys/class/net/${interface}/statistics/rx_bytes"
    local tx_file="/sys/class/net/${interface}/statistics/tx_bytes"
    [[ -f "$rx_file" && -f "$tx_file" ]] && printf '%s %s' "$(< "$rx_file")" "$(< "$tx_file")"
}

get_bytes_macos() {
    local interface="$1"
    netstat -I "$interface" -b 2>/dev/null | awk 'NR==2 {print $7, $10}'
}

get_timestamp() {
    if is_macos; then
        python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || printf '%s000' "$(date +%s)"
    else
        date +%s%3N 2>/dev/null || printf '%s000' "$(date +%s)"
    fi
}

plugin_get_display_info() {
    local content="${1:-}"
    local show="1"
    [[ -z "$content" || "$content" == "n/a" ]] && show="0"
    build_display_info "$show" "" "" ""
}

load_plugin() {
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return
    fi

    local interface
    interface=$(get_cached_option "@powerkit_plugin_network_interface" "$POWERKIT_PLUGIN_NETWORK_INTERFACE")
    [[ -z "$interface" ]] && interface=$(get_default_interface)
    [[ -z "$interface" ]] && { printf 'N/A'; return; }
    
    local current_bytes current_time
    is_linux && current_bytes=$(get_bytes_linux "$interface")
    is_macos && current_bytes=$(get_bytes_macos "$interface")
    [[ -z "$current_bytes" ]] && { printf 'N/A'; return; }
    
    current_time=$(get_timestamp)
    
    local current_rx current_tx
    read -r current_rx current_tx <<< "$current_bytes"
    
    local prev_data
    prev_data=$(cache_get "$CACHE_KEY_PREV" "$POWERKIT_TIMING_CACHE_LONG" 2>/dev/null || echo "")
    cache_set "$CACHE_KEY_PREV" "$current_rx $current_tx $current_time"

    # First run - no previous data, don't cache empty result (so next run recalculates immediately)
    if [[ -z "$prev_data" ]]; then
        return
    fi
    
    local prev_rx prev_tx prev_time
    read -r prev_rx prev_tx prev_time <<< "$prev_data"
    
    local time_delta
    time_delta=$(awk "BEGIN {printf \"%.3f\", ($current_time - $prev_time) / 1000}")
    awk "BEGIN {exit !($time_delta <= $POWERKIT_TIMING_MIN_DELTA)}" 2>/dev/null && time_delta="$POWERKIT_TIMING_FALLBACK"
    
    local rx_speed tx_speed
    rx_speed=$(awk "BEGIN {printf \"%.0f\", ($current_rx - $prev_rx) / $time_delta}")
    tx_speed=$(awk "BEGIN {printf \"%.0f\", ($current_tx - $prev_tx) / $time_delta}")
    
    [[ $rx_speed -lt 0 ]] && rx_speed=0
    [[ $tx_speed -lt 0 ]] && tx_speed=0
    
    local threshold
    threshold=$(get_cached_option "@powerkit_plugin_network_threshold" "$POWERKIT_PLUGIN_NETWORK_THRESHOLD")
    
    local total_speed
    total_speed=$(awk "BEGIN {printf \"%.0f\", $rx_speed + $tx_speed}")
    
    if [[ $total_speed -le $threshold ]]; then
        cache_set "$CACHE_KEY" ""
        return
    fi
    
    local down up result
    down=$(bytes_to_speed "$rx_speed")
    up=$(bytes_to_speed "$tx_speed")
    # Fixed width: 4 chars right-aligned + arrow
    printf -v result '%4s↓ %4s↑' "$down" "$up"
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
