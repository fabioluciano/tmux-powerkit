#!/usr/bin/env bash
# =============================================================================
# Plugin: stocks
# Description: Display stock prices
# Dependencies: curl
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "stocks"
    metadata_set "name" "Stocks"
    metadata_set "version" "2.0.0"
    metadata_set "description" "Display stock prices"
    metadata_set "priority" "180"
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
    declare_option "show_symbol" "bool" "true" "Show stock symbol"
    declare_option "show_change" "bool" "true" "Show price change"

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
    local prices=$(plugin_data_get "prices")
    [[ -n "$prices" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    # Check if any stock is down
    local changes=$(plugin_data_get "changes")
    [[ "$changes" == *"-"* ]] && printf 'warning' || printf 'ok'
}

plugin_get_context() {
    local changes=$(plugin_data_get "changes")
    
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
# Main Logic
# =============================================================================

_fetch_stock_price() {
    local symbol=$1

    # Using Yahoo Finance API alternative (finnhub.io or alpha vantage requires API key)
    # For demo, using a simple rate endpoint
    local url="https://query1.finance.yahoo.com/v8/finance/chart/${symbol}?interval=1d&range=1d"
    
    local response
    response=$(safe_curl "$url" 3)

    [[ -z "$response" ]] && return 1

    # Parse JSON manually (no jq dependency)
    local price change
    price=$(echo "$response" | sed -n 's/.*"regularMarketPrice":\([0-9.]*\).*/\1/p' | head -1)
    change=$(echo "$response" | sed -n 's/.*"regularMarketChange":\(-\?[0-9.]*\).*/\1/p' | head -1)

    [[ -n "$price" ]] && printf '%.2f|%.2f' "$price" "${change:-0}"
}

plugin_collect() {
    local symbols=$(get_option "symbols")
    IFS=',' read -ra symbol_list <<< "$symbols"

    local prices_data="" changes_data=""
    for symbol in "${symbol_list[@]}"; do
        symbol=$(trim "$symbol")
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

plugin_render() {
    local prices changes show_symbol show_change
    prices=$(plugin_data_get "prices")
    changes=$(plugin_data_get "changes")
    show_symbol=$(get_option "show_symbol")
    show_change=$(get_option "show_change")

    [[ -z "$prices" ]] && return 0

    local result=""
    IFS='|' read -ra price_list <<< "$prices"
    IFS='|' read -ra change_list <<< "$changes"
    
    for i in "${!price_list[@]}"; do
        IFS=':' read -r symbol price <<< "${price_list[$i]}"
        IFS=':' read -r _ change <<< "${change_list[$i]:-:0}"
        
        [[ -n "$result" ]] && result+=" "
        
        [[ "$show_symbol" == "true" ]] && result+="$symbol "
        result+="\$$price"
        
        if [[ "$show_change" == "true" ]]; then
            [[ "${change:0:1}" != "-" ]] && result+=" +"
            result+="${change}"
        fi
    done

    printf '%s' "$result"
}

