#!/usr/bin/env bash
# Plugin: swap
# Description: Display swap memory usage with threshold support
# Type: conditional (hidden on systems without swap)

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "swap"
    metadata_set "name" "Swap"
    metadata_set "description" "Display swap memory usage with threshold support"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "vm_stat" 1
        require_cmd "sysctl" 1
    else
        [[ -f /proc/meminfo ]] || return 1
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display format
    declare_option "format" "string" "usage" "Display format (percent|usage|free)"

    # Icons - Use correct UTF-32 format (4-digit for BMP)
    declare_option "icon" "icon" $'\U0000f0cf' "Plugin icon (swap/exchange)"

    # Thresholds (higher = worse)
    declare_option "warning_threshold" "number" "60" "Warning threshold percentage"
    declare_option "critical_threshold" "number" "80" "Critical threshold percentage"

    # Cache
    declare_option "cache_ttl" "number" "30" "Cache duration in seconds"

    # Optional: Include compressed memory (macOS only)
    declare_option "include_compressed" "bool" "false" "Include compressed memory in swap total (macOS only)"
}

# =============================================================================
# Internal: Data Collection
# =============================================================================

# Linux collection using /proc/meminfo
_collect_linux() {
    # Check if swap exists (including WSL)
    if [[ ! -f /proc/meminfo ]]; then
        plugin_data_set "available" "0"
        return 1
    fi

    local swap_total swap_free swap_used
    swap_total=$(grep "^SwapTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}')
    swap_free=$(grep "^SwapFree:" /proc/meminfo 2>/dev/null | awk '{print $2}')

    # Handle no swap or permission errors
    if [[ -z "$swap_total" ]] || [[ "$swap_total" == "0" ]]; then
        plugin_data_set "available" "0"
        return 1
    fi

    # Calculate used (values are in KB)
    swap_used=$((swap_total - swap_free))

    # Convert to bytes
    local total_bytes=$((swap_total * 1024))
    local used_bytes=$((swap_used * 1024))

    # Calculate percentage
    local percent
    percent=$(calc_percent "$swap_used" "$swap_total")

    plugin_data_set "available" "1"
    plugin_data_set "percent" "$percent"
    plugin_data_set "used" "$used_bytes"
    plugin_data_set "total" "$total_bytes"
    return 0
}

# macOS collection with dual-method approach
_collect_macos() {
    # Method 1: Try sysctl vm.swapusage (most accurate)
    local swap_info
    swap_info=$(sysctl -n vm.swapusage 2>/dev/null)

    if [[ -n "$swap_info" ]]; then
        # Parse format: "total = 2048.00M  used = 1024.00M  free = 1024.00M  (encrypted)"
        local total used

        # Extract total value and unit
        if [[ "$swap_info" =~ total\ =\ ([0-9.]+)([MGT]) ]]; then
            local value="${BASH_REMATCH[1]}"
            local unit="${BASH_REMATCH[2]}"
            total=$(_to_bytes "$value" "$unit")
        fi

        # Extract used value and unit
        if [[ "$swap_info" =~ used\ =\ ([0-9.]+)([MGT]) ]]; then
            local value="${BASH_REMATCH[1]}"
            local unit="${BASH_REMATCH[2]}"
            used=$(_to_bytes "$value" "$unit")
        fi

        if [[ -n "$total" ]] && [[ "$total" != "0" ]] && [[ -n "$used" ]]; then
            local percent
            percent=$(calc_percent "$used" "$total")

            plugin_data_set "available" "1"
            plugin_data_set "percent" "$percent"
            plugin_data_set "used" "$used"
            plugin_data_set "total" "$total"
            plugin_data_set "method" "sysctl"
            return 0
        fi
    fi

    # Method 2: Fallback to vm_stat for swap activity indication
    local vm_stat_output
    vm_stat_output=$(vm_stat 2>/dev/null)

    if [[ -z "$vm_stat_output" ]]; then
        plugin_data_set "available" "0"
        return 1
    fi

    # Parse swap activity from vm_stat (provides degraded info)
    local swapins swapouts
    swapins=$(echo "$vm_stat_output" | awk '/Swapins:/ {print $2}' | tr -d '.')
    swapouts=$(echo "$vm_stat_output" | awk '/Swapouts:/ {print $2}' | tr -d '.')

    if [[ -n "$swapins" ]] && [[ -n "$swapouts" ]]; then
        local swap_activity=$((swapins + swapouts))

        # Provide degraded information (activity-based approximation)
        plugin_data_set "available" "1"
        plugin_data_set "degraded" "1"  # Mark as degraded data
        plugin_data_set "swap_activity" "$swap_activity"
        plugin_data_set "method" "vm_stat"

        # Cannot provide accurate percentage with vm_stat alone
        # Set placeholder values for display
        plugin_data_set "percent" "0"  # Unknown
        plugin_data_set "used" "$swap_activity"  # Activity count as proxy
        plugin_data_set "total" "0"  # Unknown
        return 0
    fi

    plugin_data_set "available" "0"
    return 1
}

# Helper to convert value with unit to bytes
_to_bytes() {
    local value="$1"
    local unit="$2"

    case "$unit" in
        M) echo "$((${value%.*} * 1024 * 1024))" ;;
        G) echo "$((${value%.*} * 1024 * 1024 * 1024))" ;;
        T) echo "$((${value%.*} * 1024 * 1024 * 1024 * 1024))" ;;
        *) echo "0" ;;
    esac
}

# Convert bytes to human-readable format
# Note: numbers.sh is NOT automatically loaded, must implement own function
_bytes_to_human() {
    local bytes="${1:-0}"
    local gb=$((1024 * 1024 * 1024))
    local mb=$((1024 * 1024))
    local kb=1024

    if (( bytes >= gb )); then
        # Show GB with one decimal place
        local gb_val=$((bytes * 10 / gb))
        printf '%d.%dG' $((gb_val / 10)) $((gb_val % 10))
    elif (( bytes >= mb )); then
        # Show MB with no decimals
        printf '%dM' $((bytes / mb))
    elif (( bytes >= kb )); then
        # Show KB
        printf '%dK' $((bytes / kb))
    else
        # Show bytes
        printf '%dB' "$bytes"
    fi
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    if is_macos; then
        _collect_macos
    else
        _collect_linux
    fi
    # Return the exit code from collection function
    return $?
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

# =============================================================================
# Plugin Contract: Quick Context Check (Optional)
# =============================================================================

# Implement for quick validation of cached data relevance
plugin_should_be_active() {
    # Quick check if swap is still present
    if is_macos; then
        # Quick check for swap on macOS
        sysctl -n vm.swapusage &>/dev/null || vm_stat &>/dev/null
    else
        # Quick check for swap on Linux
        [[ -f /proc/meminfo ]] && grep -q "^SwapTotal:" /proc/meminfo 2>/dev/null
    fi
}

# =============================================================================
# Plugin Contract: State and Health
# =============================================================================

plugin_get_state() {
    local available degraded
    available=$(plugin_data_get "available")
    degraded=$(plugin_data_get "degraded")

    if [[ "$available" != "1" ]]; then
        printf 'inactive'
    elif [[ "$degraded" == "1" ]]; then
        printf 'degraded'  # macOS vm_stat fallback provides limited info
    else
        printf 'active'
    fi
}

plugin_get_health() {
    local percent degraded method
    percent=$(plugin_data_get "percent")
    degraded=$(plugin_data_get "degraded")
    method=$(plugin_data_get "method")

    # For degraded data (vm_stat activity), show info state
    if [[ "$degraded" == "1" ]] || [[ "$method" == "vm_stat" ]]; then
        # Check swap activity for approximation
        local activity=$(plugin_data_get "swap_activity")
        if [[ -n "$activity" ]] && (( activity > 0 )); then
            printf 'info'  # Swap is active (approximation)
        else
            printf 'ok'
        fi
        return
    fi

    # Use standard threshold evaluation for accurate data
    local warn_th crit_th
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    # Inline threshold evaluation (higher is worse)
    if (( ${percent:-0} >= ${crit_th:-80} )); then
        printf 'error'
    elif (( ${percent:-0} >= ${warn_th:-60} )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

plugin_get_context() {
    local health=$(plugin_get_health)
    case "$health" in
        error)   printf 'critical_usage' ;;
        warning) printf 'high_usage' ;;
        *)       printf 'normal_usage' ;;
    esac
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local format percent used total degraded method
    format=$(get_option "format")
    percent=$(plugin_data_get "percent")
    used=$(plugin_data_get "used")
    total=$(plugin_data_get "total")
    degraded=$(plugin_data_get "degraded")
    method=$(plugin_data_get "method")

    # Handle degraded data (vm_stat fallback)
    if [[ "$degraded" == "1" ]] || [[ "$method" == "vm_stat" ]]; then
        local activity=$(plugin_data_get "swap_activity")
        if [[ -n "$activity" ]] && (( activity > 0 )); then
            printf 'swap active'  # Indicate swap is being used
        else
            printf 'no swap'
        fi
        return
    fi

    # Normal rendering for accurate data
    case "$format" in
        usage)
            printf '%s/%s' "$(_bytes_to_human "${used:-0}")" "$(_bytes_to_human "${total:-0}")"
            ;;
        free)
            local free=$(( ${total:-0} - ${used:-0} ))
            printf '%s free' "$(_bytes_to_human "$free")"
            ;;
        percent|*)
            printf '%3d%%' "${percent:-0}"
            ;;
    esac
}

# =============================================================================
# Plugin Contract: Icon (based on internal data, NOT health)
# =============================================================================

plugin_get_icon() {
    # Simple icon - no health-based changes per contract
    get_option "icon"
}
