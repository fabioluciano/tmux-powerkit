#!/usr/bin/env bash
# =============================================================================
# Plugin: crypto
# Description: Display cryptocurrency prices
# Dependencies: curl, jq (optional)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "crypto"
    metadata_set "name" "Crypto"
    metadata_set "version" "2.1.0"
    metadata_set "description" "Display cryptocurrency prices"
    metadata_set "priority" "75"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    require_cmd "curl" || return 1
    require_cmd "jq" 1  # Optional - better JSON parsing
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Display options
    declare_option "coins" "string" "BTC,ETH" "Crypto symbols (comma-separated)"
    declare_option "currency" "string" "USD" "Fiat currency"
    declare_option "format" "string" "full" "Price format (full|short)"
    declare_option "show_change" "bool" "false" "Show 24h price change percentage"
    declare_option "separator" "string" " | " "Separator between coin prices"

    # Icons
    declare_option "icon" "icon" $'\U000F0132' "Plugin icon"

    # Cache (prices don't change very frequently)
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds (5 min)"
}

# =============================================================================
# Coin Mappings
# =============================================================================

# Coin ID mapping for CoinGecko
declare -A COIN_IDS=(
    ["BTC"]="bitcoin"
    ["ETH"]="ethereum"
    ["SOL"]="solana"
    ["ADA"]="cardano"
    ["DOT"]="polkadot"
    ["DOGE"]="dogecoin"
    ["XRP"]="ripple"
    ["LTC"]="litecoin"
    ["LINK"]="chainlink"
    ["MATIC"]="matic-network"
    ["AVAX"]="avalanche-2"
    ["UNI"]="uniswap"
    ["ATOM"]="cosmos"
    ["BNB"]="binancecoin"
    ["USDT"]="tether"
)

# Coin symbols for display
declare -A COIN_SYMBOLS=(
    ["BTC"]="₿"
    ["ETH"]="Ξ"
    ["SOL"]="◎"
)

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local prices=$(plugin_data_get "prices")
    [[ -n "$prices" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() { printf 'ok'; }

plugin_get_context() {
    local prices=$(plugin_data_get "prices")
    [[ -n "$prices" ]] && printf 'available' || printf 'unavailable'
}

plugin_get_icon() { get_option "icon"; }

# =============================================================================
# Helper Functions
# =============================================================================

# Get coin ID for CoinGecko API
_get_coin_id() {
    local symbol="${1^^}"
    printf '%s' "${COIN_IDS[$symbol]:-${symbol,,}}"
}

# Get coin display symbol (₿, Ξ, ◎)
_get_coin_symbol() {
    local symbol="${1^^}"
    printf '%s' "${COIN_SYMBOLS[$symbol]:-$symbol}"
}

# Format price for display
_format_price() {
    local price="$1"
    local format="$2"

    if [[ "$format" == "short" ]]; then
        # Convert to K, M notation
        if [[ $(echo "$price >= 1000000" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
            awk -v p="$price" 'BEGIN { printf "%.1fM", p/1000000 }'
        elif [[ $(echo "$price >= 1000" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
            awk -v p="$price" 'BEGIN { printf "%.1fk", p/1000 }'
        else
            awk -v p="$price" 'BEGIN { printf "%.0f", p }'
        fi
    else
        # Full format with commas
        printf "%'.2f" "$price" 2>/dev/null || printf "%.2f" "$price"
    fi
}

# Format 24h change (wrapped in parentheses)
_format_change() {
    local change="$1"
    awk -v c="$change" 'BEGIN {
        if (c > 0) printf "(+%.1f%%)", c
        else printf "(%.1f%%)", c
    }'
}

# Fetch prices from CoinGecko (free, no API key needed)
_fetch_coingecko() {
    local coins_list="$1"
    local currency show_change
    currency=$(get_option "currency")
    show_change=$(get_option "show_change")
    local curr="${currency,,}"

    # Convert comma-separated symbols to CoinGecko IDs
    local ids=""
    IFS=',' read -ra COINS <<< "$coins_list"
    for coin in "${COINS[@]}"; do
        coin=$(trim "$coin")
        local coin_id=$(_get_coin_id "$coin")
        [[ -n "$ids" ]] && ids+=","
        ids+="$coin_id"
    done

    local url="https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=${curr}"
    [[ "$show_change" == "true" ]] && url+="&include_24hr_change=true"

    safe_curl "$url" 10
}

# =============================================================================
# Main Logic
# =============================================================================

plugin_collect() {
    local coins
    coins=$(get_option "coins")
    [[ -z "$coins" ]] && return 0

    local response
    response=$(_fetch_coingecko "$coins")
    [[ -z "$response" ]] && return 0

    local currency currency_lower show_change
    currency=$(get_option "currency")
    currency_lower="${currency,,}"
    show_change=$(get_option "show_change")

    local prices_data=""
    IFS=',' read -ra coin_list <<< "$coins"

    for coin in "${coin_list[@]}"; do
        coin=$(trim "$coin")
        [[ -z "$coin" ]] && continue

        local coin_id=$(_get_coin_id "$coin")
        local price change=""

        # Extract price from JSON
        if has_cmd jq; then
            price=$(echo "$response" | jq -r ".\"$coin_id\".\"$currency_lower\" // empty" 2>/dev/null)
            if [[ "$show_change" == "true" ]]; then
                change=$(echo "$response" | jq -r ".\"$coin_id\".\"${currency_lower}_24h_change\" // empty" 2>/dev/null)
            fi
        else
            # Fallback: manual JSON parsing
            price=$(echo "$response" | sed -n 's/.*"'$coin_id'"[^}]*"'$currency_lower'":\([0-9.]*\).*/\1/p')
        fi

        [[ -z "$price" || "$price" == "null" ]] && continue

        # Store: SYMBOL:PRICE:CHANGE
        [[ -n "$prices_data" ]] && prices_data+="|"
        prices_data+="${coin}:${price}:${change}"
    done

    [[ -n "$prices_data" ]] && plugin_data_set "prices" "$prices_data"
}

plugin_render() {
    local prices format show_change separator
    prices=$(plugin_data_get "prices")
    format=$(get_option "format")
    show_change=$(get_option "show_change")
    separator=$(get_option "separator")

    [[ -z "$prices" ]] && return 0

    local output_parts=()
    IFS='|' read -ra price_list <<< "$prices"

    for price_entry in "${price_list[@]}"; do
        IFS=':' read -r symbol price change <<< "$price_entry"
        [[ -z "$price" ]] && continue

        local coin_sym=$(_get_coin_symbol "$symbol")
        local formatted_price=$(_format_price "$price" "$format")
        local coin_output="${coin_sym}${formatted_price}"

        # Add 24h change if enabled
        if [[ "$show_change" == "true" && -n "$change" && "$change" != "null" ]]; then
            coin_output+=" $(_format_change "$change")"
        fi

        output_parts+=("$coin_output")
    done

    [[ ${#output_parts[@]} -eq 0 ]] && return 0

    join_with_separator "$separator" "${output_parts[@]}"
}

