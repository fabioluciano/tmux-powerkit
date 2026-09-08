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
#   - degraded: No tickers configured (plugin visible but needs setup)
#   - inactive: No stock data available
#
# Health:
#   - error: No tickers configured
#   - warning: At least one stock is down
#   - ok: All stocks stable or up
#
# Context:
#   - not_configured: No tickers defined
#   - unavailable: No data from API
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
    declare_option "tickers" "string" "AAPL" "Stock tickers to track (comma-separated, e.g., AAPL,MSFT,GOOGL)"
    declare_option "format" "string" "short" "Display format: short or full"
    declare_option "show_ticker" "bool" "true" "Show stock ticker symbol"
    declare_option "show_change" "bool" "true" "Show price change with direction"
    declare_option "separator" "string" " | " "Separator between stocks"

    # Icons
    declare_option "icon" "icon" $'\U0000F437' "Stock icon"

    # Cache (check every 5 minutes)
    declare_option "cache_ttl" "number" "300" "Cache duration in seconds"
}

# =============================================================================
# Plugin Contract: Implementation
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'always'; }

plugin_get_state() {
    local tickers prices
    tickers=$(get_option "tickers")

    # No tickers configured - degraded state (visible but needs setup)
    [[ -z "$tickers" ]] && {
        printf 'degraded'
        return
    }

    prices=$(plugin_data_get "prices")
    [[ -n "$prices" ]] && printf 'active' || printf 'inactive'
}

plugin_get_health() {
    local tickers
    tickers=$(get_option "tickers")

    # No tickers configured - error health
    [[ -z "$tickers" ]] && {
        printf 'error'
        return
    }

    # Check if any stock is down
    local changes
    changes=$(plugin_data_get "changes")
    [[ "$changes" == *"-"* ]] && printf 'warning' || printf 'ok'
}

plugin_get_context() {
    local tickers
    tickers=$(get_option "tickers")

    # No tickers configured
    [[ -z "$tickers" ]] && {
        printf 'not_configured'
        return
    }

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

    # Validate JSON shape before regex extraction. The previous code
    # applied a sed pattern to whatever the server returned, which
    # silently succeeded on HTML error pages, captive portals, or 429
    # bodies. A successful empty grep is what produced zero prices
    # without raising the cache.
    if has_cmd jq; then
        api_validate_json "$response" || return 1
        # Use jq's structural path so we do not depend on a regex that
        # the provider can change at any release.
        local price prev_close
        price=$(printf '%s' "$response" | jq -r '.chart.result[0].meta.regularMarketPrice // empty' 2>/dev/null) || return 1
        prev_close=$(printf '%s' "$response" | jq -r '.chart.result[0].meta.chartPreviousClose // empty' 2>/dev/null) || return 1
        [[ -z "$price" ]] && return 1

        local change_pct
        if [[ -n "$prev_close" && "$prev_close" != "0" ]]; then
            change_pct=$(awk -v p="$price" -v pc="$prev_close" 'BEGIN { printf "%.2f", ((p - pc) / pc) * 100 }')
        else
            change_pct="0.00"
        fi
        printf '%s|%s' "$price" "$change_pct"
        return 0
    fi

    # Fallback: regex parsing (kept for environments without jq).
    local price prev_close change_pct
    price=$(echo "$response" | sed -n 's/.*"regularMarketPrice":\([0-9.]*\).*/\1/p' | head -1)
    prev_close=$(echo "$response" | sed -n 's/.*"chartPreviousClose":\([0-9.]*\).*/\1/p' | head -1)

    [[ -z "$price" ]] && return 1

    if [[ -n "$prev_close" && "$prev_close" != "0" ]]; then
        change_pct=$(awk -v p="$price" -v pc="$prev_close" 'BEGIN { printf "%.2f", ((p - pc) / pc) * 100 }')
    else
        change_pct="0.00"
    fi

    printf '%s|%s' "$price" "$change_pct"
}

# =============================================================================
# Formatting Functions
# =============================================================================

# Format price for display (pure bash, no awk fork)
_format_price() {
    local price="$1"
    local format="$2"

    if [[ "$format" == "short" ]]; then
        # Short format: no $ sign, round large numbers
        # Shift decimal 2 places, integer math, then format.
        if (($(printf '%.0f' "$price") >= 1000)); then
            printf '%.0f' "$price"
        else
            printf '%.2f' "$price"
        fi
    else
        # Full format: with $ sign
        printf '$%.2f' "$price"
    fi
}

# Format change with direction indicator (pure bash, no awk fork)
_format_change() {
    local change="$1"
    local indicator=""

    # Split "[-]X.Y[Z...]" into integer and fractional parts without awk.
    local sign="" int_part frac_part
    if [[ "$change" == -* ]]; then
        sign="-"
        change="${change#-}"
    fi
    int_part="${change%%.*}"
    [[ "$int_part" == "$change" ]] && int_part="${change}" || int_part="${int_part:-0}"
    frac_part="${change#*.}"
    [[ "$frac_part" == "$change" ]] && frac_part="0"

    # One decimal digit for display (matches original "%.1f%%").
    local d1="${frac_part:0:1}"
    d1="${d1:-0}"

    # Determine direction from sign and magnitude using integer cents:
    # 5 cents = 0.05% threshold; below that is flat.
    local f2="${frac_part:0:2}"
    [[ ${#f2} -eq 1 ]] && f2="${f2}0"
    [[ ${#f2} -eq 0 ]] && f2="00"
    local cents=$(( 10#${int_part:-0} * 100 + 10#$f2 ))

    if (( cents <= 5 )); then
        indicator="→"
    elif [[ -n "$sign" ]]; then
        indicator="↓"
    else
        indicator="↑"
    fi
    change="${int_part}.${d1}"

    printf '%s%s%%' "$indicator" "$change"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local tickers
    tickers=$(get_option "tickers")

    # No tickers configured - nothing to collect
    [[ -z "$tickers" ]] && return 0

    IFS=',' read -ra ticker_list <<<"$tickers"

    local prices_data="" changes_data=""
    local attempted=0 parsed=0
    for ticker in "${ticker_list[@]}"; do
        ticker=$(trim "$ticker")
        ticker="${ticker^^}" # Bash 4.0+ uppercase
        [[ -z "$ticker" ]] && continue

        ((attempted++))
        local stock_data
        if ! stock_data=$(_fetch_stock_price "$ticker"); then
            continue
        fi

        if [[ -n "$stock_data" ]]; then
            IFS='|' read -r price change <<<"$stock_data"
            [[ -n "$prices_data" ]] && prices_data+="|"
            prices_data+="${ticker}:${price}"

            [[ -n "$changes_data" ]] && changes_data+="|"
            changes_data+="${ticker}:${change}"
            ((parsed++))
        fi
    done

    # When no ticker produced a price, refuse to overwrite the prior
    # cache so the lifecycle can keep the previous record and mark it
    # stale.
    if ((attempted > 0 && parsed == 0)); then
        return 1
    fi

    [[ -n "$prices_data" ]] && plugin_data_set "prices" "$prices_data"
    [[ -n "$changes_data" ]] && plugin_data_set "changes" "$changes_data"

    # Build formatted render output
    if [[ -n "$prices_data" ]]; then
        local format show_ticker show_change separator
        format=$(get_option "format")
        show_ticker=$(get_option "show_ticker")
        show_change=$(get_option "show_change")
        separator=$(get_option "separator")

        local result="" stock_output
        IFS='|' read -ra price_list <<<"$prices_data"
        IFS='|' read -ra change_list <<<"$changes_data"

        for i in "${!price_list[@]}"; do
            IFS=':' read -r ticker price <<<"${price_list[$i]}"
            IFS=':' read -r _ change <<<"${change_list[$i]:-:0}"

            stock_output=""

            # Add ticker if enabled
            if [[ "$show_ticker" == "true" ]]; then
                stock_output="${ticker} "
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

        plugin_data_set "formatted" "$result"
    fi
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local tickers formatted

    tickers=$(get_option "tickers")

    # No tickers configured - show message
    [[ -z "$tickers" ]] && {
        printf 'not configured'
        return
    }

    formatted=$(plugin_data_get "formatted")
    [[ -z "$formatted" ]] && return 0

    printf '%s' "$formatted"
}
