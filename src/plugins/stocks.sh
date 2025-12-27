#!/usr/bin/env bash
# =============================================================================
# Plugin: stocks
# Description: Display stock prices with direction indicators
# Dependencies: curl
# =============================================================================
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: Stock data retrieved
#   - inactive: No stock data available
#
# Health:
#   - warning: At least one stock is down
#   - ok: All stocks stable or up
#
# Context:
#   - unavailable: No data
#   - down: Some stocks declining
#   - up: All stocks rising or stable
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "stocks"
    metadata_set "name" "Stocks"
    metadata_set "description" "Display stock prices with direction indicators"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "symbols" "string" "AAPL" "Stock symbols (comma-separated)"
    declare_option "format" "string" "short" "Display format: short or full"
    declare_option "show_symbol" "bool" "true" "Show stock symbol"
    declare_option "show_change" "bool" "true" "Show price change with direction"
    declare_option "separator" "string" " | " "Separator between stocks"

    # Icons
    declare_option "icon" "icon" $'\U000F0590' "Stock icon"

    # Cache (check every 5 minutes)
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local prices
    prices=$(plugin_data_get "prices")
    [[ -n "$prices" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    # Check if any stock is down
    local changes
    changes=$(plugin_data_get "changes")
    [[ "$changes" == *"-"* ]] && printf 'warning' || printf 'ok'
}

plugin_get_context() {
    local changes
    changes=$(plugin_data_get "changes")

    if [[ -z "$changes" ]]; then
        printf 'unavailable'
    elif [[ "$changes" == *"-"* ]]; then
        printf 'down'
    else
        printf 'up'
    fi
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# API Functions
# =============================================================================

_fetch_stock_price() {
    local symbol="$1"

    # Using Yahoo Finance API (unofficial but reliable)
    local url="https://query1.finance.yahoo.com/v8/finance/chart/${symbol}?interval=1d&range=1d"

    local response
    response=$(safe_curl "$url" 10 \
        -H "User-Agent: Mozilla/5.0 (compatible; tmux-powerkit)" \
        -H "Accept: application/json" 2>/dev/null)

    [[ -z "$response" ]] && return 1

    # Parse JSON manually (no jq dependency)
    local price prev_close change_pct
    price=$(echo "$response" | sed -n 's/.*"regularMarketPrice":\([0-9.]*\).*/\1/p' | head -1)
    prev_close=$(echo "$response" | sed -n 's/.*"chartPreviousClose":\([0-9.]*\).*/\1/p' | head -1)

    [[ -z "$price" ]] && return 1

    # Calculate change percentage
    if [[ -n "$prev_close" && "$prev_close" != "0" ]]; then
        # Use awk for floating point calculation
        change_pct=$(awk -v p="$price" -v pc="$prev_close" 'BEGIN { printf "%.2f", ((p - pc) / pc) * 100 }')
    else
        change_pct="0.00"
    fi

    printf '%s|%s' "$price" "$change_pct"
}

# =============================================================================
# Formatting Functions
# =============================================================================

# Format price for display
_format_price() {
    local price="$1"
    local format="$2"

    if [[ "$format" == "short" ]]; then
        # Short format: no $ sign, round large numbers
        if awk -v p="$price" 'BEGIN { exit (p >= 1000) ? 0 : 1 }' 2>/dev/null; then
            awk -v p="$price" 'BEGIN { printf "%.0f", p }'
        else
            awk -v p="$price" 'BEGIN { printf "%.2f", p }'
        fi
    else
        # Full format: with $ sign
        printf '$%.2f' "$price"
    fi
}

# Format change with direction indicator
_format_change() {
    local change="$1"
    local indicator=""

    # Determine direction
    if awk -v c="$change" 'BEGIN { exit (c > 0.01) ? 0 : 1 }' 2>/dev/null; then
        indicator="↑"
    elif awk -v c="$change" 'BEGIN { exit (c < -0.01) ? 0 : 1 }' 2>/dev/null; then
        indicator="↓"
        change="${change#-}"  # Remove negative sign for display
    else
        indicator="→"
    fi

    printf '%s%.1f%%' "$indicator" "$change"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local symbols
    symbols=$(get_option "symbols")
    IFS=',' read -ra symbol_list <<< "$symbols"

    local prices_data="" changes_data=""
    for symbol in "${symbol_list[@]}"; do
        symbol=$(trim "$symbol")
        symbol=$(echo "$symbol" | tr '[:lower:]' '[:upper:]')
        [[ -z "$symbol" ]] && continue

        local stock_data
        stock_data=$(_fetch_stock_price "$symbol")

        if [[ -n "$stock_data" ]]; then
            IFS='|' read -r price change <<< "$stock_data"
            [[ -n "$prices_data" ]] && prices_data+="|"
            prices_data+="${symbol}:${price}"

            [[ -n "$changes_data" ]] && changes_data+="|"
            changes_data+="${symbol}:${change}"
        fi
    done

    [[ -n "$prices_data" ]] && plugin_data_set "prices" "$prices_data"
    [[ -n "$changes_data" ]] && plugin_data_set "changes" "$changes_data"
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local prices changes show_symbol show_change format separator
    prices=$(plugin_data_get "prices")
    changes=$(plugin_data_get "changes")
    show_symbol=$(get_option "show_symbol")
    show_change=$(get_option "show_change")
    format=$(get_option "format")
    separator=$(get_option "separator")

    [[ -z "$prices" ]] && return 0

    local result="" stock_output
    IFS='|' read -ra price_list <<< "$prices"
    IFS='|' read -ra change_list <<< "$changes"

    for i in "${!price_list[@]}"; do
        IFS=':' read -r symbol price <<< "${price_list[$i]}"
        IFS=':' read -r _ change <<< "${change_list[$i]:-:0}"

        stock_output=""

        # Add symbol if enabled
        if [[ "$show_symbol" == "true" ]]; then
            stock_output="${symbol} "
        fi

        # Add formatted price
        stock_output+="$(_format_price "$price" "$format")"

        # Add change with direction if enabled
        if [[ "$show_change" == "true" && -n "$change" ]]; then
            stock_output+=" $(_format_change "$change")"
        fi

        # Append to result with separator
        if [[ -n "$result" ]]; then
            result+="${separator}"
        fi
        result+="$stock_output"
    done

    printf '%s' "$result"
}

