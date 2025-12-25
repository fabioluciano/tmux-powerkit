#!/usr/bin/env bash
# =============================================================================
# Plugin: network
# Description: Display network traffic (upload/download speed)
# Dependencies: ifstat or netstat
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "network"
    metadata_set "name" "Network"
    metadata_set "description" "Display network traffic"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_any_cmd "ifstat" "netstat" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "interface" "string" "auto" "Network interface to monitor"
    declare_option "show_upload" "bool" "true" "Show upload speed"
    declare_option "show_download" "bool" "true" "Show download speed"
    declare_option "separator" "string" " " "Separator between up/down"

    # Icons
    declare_option "icon" "icon" $'\U000F090C' "Plugin icon"
    declare_option "icon_upload" "icon" $'\U000F0552' "Upload icon"
    declare_option "icon_download" "icon" $'\U000F0151' "Download icon"

    # Cache
    declare_option "cache_ttl" "number" "2" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local rx_rate tx_rate
    rx_rate=$(plugin_data_get "rx_rate")
    tx_rate=$(plugin_data_get "tx_rate")
    
    rx_rate="${rx_rate:-0}"
    tx_rate="${tx_rate:-0}"
    
    # Determine activity context
    local total=$((rx_rate + tx_rate))
    if (( total == 0 )); then
        printf 'idle'
    elif (( rx_rate > tx_rate )); then
        printf 'downloading'
    elif (( tx_rate > rx_rate )); then
        printf 'uploading'
    else
        printf 'active'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Main Logic
# =============================================================================

_get_active_interface() {
    if is_macos; then
        route -n get default 2>/dev/null | awk '/interface:/ {print $2}'
    else
        ip route | awk '/default/ {print $5; exit}'
    fi
}

_get_network_stats() {
    local interface=$(get_option "interface")
    [[ "$interface" == "auto" ]] && interface=$(_get_active_interface)
    [[ -z "$interface" ]] && return 1

    # Try ifstat first (more accurate)
    if has_cmd "ifstat"; then
        local stats
        stats=$(ifstat -i "$interface" -b 0.1 1 2>/dev/null | tail -1)
        [[ -z "$stats" ]] && return 1
        
        local rx_rate tx_rate
        read -r rx_rate tx_rate <<< "$stats"
        
        # Convert to KB/s
        rx_rate=$(awk "BEGIN {printf \"%.0f\", $rx_rate / 1024}")
        tx_rate=$(awk "BEGIN {printf \"%.0f\", $tx_rate / 1024}")
        
        printf '%s|%s' "$rx_rate" "$tx_rate"
    else
        # Fallback: read from /sys or netstat
        if [[ -f "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
            local rx_bytes tx_bytes
            rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null)
            tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null)
            
            local prev_rx prev_tx prev_time
            prev_rx=$(plugin_data_get "prev_rx_bytes")
            prev_tx=$(plugin_data_get "prev_tx_bytes")
            prev_time=$(plugin_data_get "prev_time")
            
            local curr_time
            curr_time=$(date +%s)
            
            if [[ -n "$prev_rx" && -n "$prev_time" ]]; then
                local time_diff=$((curr_time - prev_time))
                [[ "$time_diff" -eq 0 ]] && time_diff=1
                
                local rx_rate=$(( (rx_bytes - prev_rx) / time_diff / 1024 ))
                local tx_rate=$(( (tx_bytes - prev_tx) / time_diff / 1024 ))
                
                plugin_data_set "prev_rx_bytes" "$rx_bytes"
                plugin_data_set "prev_tx_bytes" "$tx_bytes"
                plugin_data_set "prev_time" "$curr_time"
                
                printf '%s|%s' "$rx_rate" "$tx_rate"
            else
                plugin_data_set "prev_rx_bytes" "$rx_bytes"
                plugin_data_set "prev_tx_bytes" "$tx_bytes"
                plugin_data_set "prev_time" "$curr_time"
                printf '0|0'
            fi
        else
            return 1
        fi
    fi
}

_format_speed() {
    local kb_per_sec=${1:-0}
    if (( kb_per_sec >= 1024 )); then
        awk "BEGIN {printf \"%.1fM\", $kb_per_sec / 1024}"
    else
        printf '%dK' "$kb_per_sec"
    fi
}

plugin_collect() {
    local stats
    stats=$(_get_network_stats) || return 1

    IFS='|' read -r rx_rate tx_rate <<< "$stats"

    plugin_data_set "rx_rate" "$rx_rate"
    plugin_data_set "tx_rate" "$tx_rate"
}

plugin_render() {
    local show_upload show_download separator
    show_upload=$(get_option "show_upload")
    show_download=$(get_option "show_download")
    separator=$(get_option "separator")

    local rx_rate tx_rate
    rx_rate=$(plugin_data_get "rx_rate")
    tx_rate=$(plugin_data_get "tx_rate")

    local parts=()
    
    if [[ "$show_download" == "true" ]]; then
        parts+=("↓$(_format_speed "$rx_rate")")
    fi
    
    if [[ "$show_upload" == "true" ]]; then
        parts+=("↑$(_format_speed "$tx_rate")")
    fi

    local IFS="$separator"
    printf '%s' "${parts[*]}"
}

