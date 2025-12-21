#!/usr/bin/env bash
# =============================================================================
# Plugin: crypto - Display cryptocurrency prices
# Description: Show current prices for configured cryptocurrencies
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
    # Display options
    declare_option "coins" "string" "BTC,ETH" "Comma-separated list of cryptocurrency symbols"
    declare_option "currency" "string" "USD" "Fiat currency for price display"
    declare_option "format" "string" "full" "Price format (full|short)"
    declare_option "api" "string" "coingecko" "API provider (coingecko)"
    declare_option "api_key" "string" "" "API key (if required by provider)"
    declare_option "show_change" "bool" "false" "Show 24-hour price change percentage"
    declare_option "separator" "string" " | " "Separator between coin prices"

    # Icons
    declare_option "icon" "icon" $'\U0000f10f' "Plugin icon (nf-fa-bitcoin)"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "600" "Cache duration in seconds"
}

plugin_init "crypto"

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
)

# Coin symbols for display
declare -A COIN_SYMBOLS=(
    ["BTC"]="₿"
    ["ETH"]="Ξ"
    ["SOL"]="◎"
    ["DEFAULT"]="$"
)

# =============================================================================
# API Functions
# =============================================================================

# Get coin ID for CoinGecko API
get_coin_id() {
    local symbol="${1^^}"
    printf '%s' "${COIN_IDS[$symbol]:-${symbol,,}}"
}

# Get coin display symbol
get_coin_symbol() {
    local symbol="${1^^}"
    printf '%s' "${COIN_SYMBOLS[$symbol]:-${COIN_SYMBOLS[DEFAULT]}}"
}

# Fetch prices from CoinGecko (free, no API key needed)
fetch_coingecko() {
    local coins_list="$1"
    local currency
    currency=$(get_option "currency")
    local curr="${currency,,}"

    # Convert comma-separated symbols to CoinGecko IDs
    local ids=""
    IFS=',' read -ra COINS <<<"$coins_list"
    for coin in "${COINS[@]}"; do
        coin=$(echo "$coin" | xargs)  # Trim whitespace
        local coin_id=$(get_coin_id "$coin")
        [[ -n "$ids" ]] && ids+=","
        ids+="$coin_id"
    done

    local url="https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=${curr}&include_24hr_change=true"
    safe_curl "$url" 10
}

# =============================================================================
# Formatting Functions
# =============================================================================

# Format price for display
format_price() {
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
format_change() {
    local change="$1"

    # Use awk for consistent numeric comparison and formatting
    # This avoids bc inconsistencies and ensures stable output
    # Output wrapped in parentheses for visual clarity
    awk -v c="$change" 'BEGIN {
        if (c > 0) printf "(+%.1f%%)", c
        else printf "(%.1f%%)", c
    }'
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() { default_plugin_display_info "${1:-}"; }

_compute_crypto() {
    # Check dependencies - hide plugin if missing
    check_dependencies curl jq || return 0

    local coins currency format show_change separator
    coins=$(get_option "coins")
    currency=$(get_option "currency")
    format=$(get_option "format")
    show_change=$(get_option "show_change")
    separator=$(get_option "separator")

    # No coins configured - hide plugin
    [[ -z "$coins" ]] && return 0

    local response
    response=$(fetch_coingecko "$coins")
    # API error (rate limit, network issue, etc.) - hide plugin
    [[ -z "$response" ]] && return 0

    local output_parts=()
    local currency_lower="${currency,,}"

    IFS=',' read -ra COINS <<<"$coins"
    for coin in "${COINS[@]}"; do
        coin=$(echo "$coin" | xargs)
        local coin_id=$(get_coin_id "$coin")
        local coin_sym=$(get_coin_symbol "$coin")

        # Extract price from JSON response
        local price
        price=$(echo "$response" | jq -r ".\"$coin_id\".\"$currency_lower\" // empty" 2>/dev/null)
        [[ -z "$price" || "$price" == "null" ]] && continue

        local formatted_price
        formatted_price=$(format_price "$price" "$format")

        local coin_output="${coin_sym}${formatted_price}"

        # Add 24h change if enabled
        if [[ "$show_change" == "true" ]]; then
            local change
            change=$(echo "$response" | jq -r ".\"$coin_id\".\"${currency_lower}_24h_change\" // empty" 2>/dev/null)
            if [[ -n "$change" && "$change" != "null" ]]; then
                coin_output+=" $(format_change "$change")"
            fi
        fi

        output_parts+=("$coin_output")
    done

    # No valid prices extracted - hide plugin
    [[ ${#output_parts[@]} -eq 0 ]] && return 0
    join_with_separator "$separator" "${output_parts[@]}"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_crypto
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
