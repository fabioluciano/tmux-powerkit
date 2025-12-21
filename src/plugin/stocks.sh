#!/usr/bin/env bash
# =============================================================================
# Plugin: stocks - Display stock prices
# Description: Show current prices for configured stock symbols
# Dependencies: curl, jq
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    require_cmd "jq" 1  # Optional
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    declare_option "symbols" "string" "AAPL" "Comma-separated list of stock symbols"
    declare_option "format" "string" "short" "Display format: short or full"
    declare_option "show_change" "bool" "true" "Show percentage change"
    declare_option "up_color" "color" "success" "Color when stock is up"
    declare_option "down_color" "color" "error" "Color when stock is down"
    declare_option "api" "string" "yahoo" "API backend (currently only yahoo)"
    declare_option "separator" "string" " | " "Separator between stocks"
    declare_option "icon" "icon" $'\U000F0200' "Plugin icon"
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}

plugin_init "stocks"

# =============================================================================
# API Functions
# =============================================================================

# Fetch stock data from Yahoo Finance API (unofficial but reliable)
fetch_yahoo_finance() {
    local symbol="$1"
    local url="https://query1.finance.yahoo.com/v8/finance/chart/${symbol}?interval=1d&range=1d"

    safe_curl "$url" 10 \
        -H "User-Agent: Mozilla/5.0 (compatible; tmux-powerkit)" \
        -H "Accept: application/json"
}

# Parse Yahoo Finance response
parse_yahoo_response() {
    local response="$1"
    local symbol="$2"

    # Extract current price
    local price
    price=$(echo "$response" | jq -r '.chart.result[0].meta.regularMarketPrice // empty' 2>/dev/null)
    [[ -z "$price" || "$price" == "null" ]] && return 1

    # Extract previous close for change calculation
    local prev_close
    prev_close=$(echo "$response" | jq -r '.chart.result[0].meta.chartPreviousClose // empty' 2>/dev/null)

    # Calculate change
    local change_pct=""
    if [[ -n "$prev_close" && "$prev_close" != "null" && "$prev_close" != "0" ]]; then
        change_pct=$(awk -v p="$price" -v pc="$prev_close" 'BEGIN { printf "%.2f", ((p - pc) / pc) * 100 }')
    fi

    printf '%s|%s' "$price" "$change_pct"
}

# =============================================================================
# Formatting Functions
# =============================================================================

# Format price for display
format_price() {
    local price="$1"
    local format="$2"

    if [[ "$format" == "short" ]]; then
        if [[ $(echo "$price >= 1000" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
            awk -v p="$price" 'BEGIN { printf "%.0f", p }'
        else
            awk -v p="$price" 'BEGIN { printf "%.2f", p }'
        fi
    else
        printf "$%.2f" "$price"
    fi
}

# Format change percentage with direction indicator
format_change() {
    local change="$1"
    local indicator=""

    if [[ $(echo "$change > 0" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        indicator="↑"
    elif [[ $(echo "$change < 0" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        indicator="↓"
        change="${change#-}"  # Remove negative sign
    else
        indicator="→"
    fi

    printf '%s%.1f%%' "$indicator" "$change"
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -z "$content" ]] && { build_display_info "0" "" "" ""; return; }

    # Check if any stock is down and apply color
    local accent=""
    if [[ "$content" == *"↓"* ]]; then
        accent=$(get_option "down_color")
    elif [[ "$content" == *"↑"* ]]; then
        accent=$(get_option "up_color")
    fi

    build_display_info "1" "$accent" "" ""
}

_compute_stocks() {
    # Check dependencies
    check_dependencies curl jq || return 1

    local symbols format show_change separator
    symbols=$(get_option "symbols")
    format=$(get_option "format")
    show_change=$(get_option "show_change")
    separator=$(get_option "separator")

    [[ -z "$symbols" ]] && return 1

    local output=""

    IFS=',' read -ra SYMBOLS <<<"$symbols"
    for symbol in "${SYMBOLS[@]}"; do
        symbol=$(echo "$symbol" | xargs | tr '[:lower:]' '[:upper:]')
        [[ -z "$symbol" ]] && continue

        local response
        response=$(fetch_yahoo_finance "$symbol")
        [[ -z "$response" ]] && continue

        local price_data
        price_data=$(parse_yahoo_response "$response" "$symbol")
        [[ -z "$price_data" ]] && continue

        local price change
        IFS='|' read -r price change <<<"$price_data"

        local formatted_price
        formatted_price=$(format_price "$price" "$format")

        local stock_output
        if [[ "$format" == "short" ]]; then
            stock_output="${symbol} ${formatted_price}"
        else
            stock_output="${symbol} ${formatted_price}"
        fi

        # Add change if enabled and available
        if [[ "$show_change" == "true" && -n "$change" ]]; then
            stock_output+=" $(format_change "$change")"
        fi

        [[ -n "$output" ]] && output+="${separator}"
        output+="$stock_output"
    done

    [[ -z "$output" ]] && return 1
    printf '%s' "$output"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_stocks
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
