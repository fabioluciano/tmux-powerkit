#!/usr/bin/env bash
# =============================================================================
# PowerKit Utils: Numbers
# Description: Numeric utilities and calculations
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_numbers" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"

# =============================================================================
# Constants (from defaults.sh - POWERKIT_BYTE_KB, POWERKIT_BYTE_MB, etc.)
# =============================================================================

# =============================================================================
# Numeric Extraction
# =============================================================================

# Extract first numeric value from string using bash regex
# Usage: extract_numeric "CPU: 45.2%"  # Returns "45"
extract_numeric() {
    local input="$1"

    if [[ "$input" =~ ([0-9]+) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '0'
    fi
}

# Extract decimal number from string
# Usage: extract_decimal "Load: 1.25"  # Returns "1.25"
extract_decimal() {
    local input="$1"

    if [[ "$input" =~ ([0-9]+\.?[0-9]*) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '0'
    fi
}

# Extract all numbers from string
# Usage: extract_all_numbers "1 2 3"  # Returns "1 2 3" (space separated)
extract_all_numbers() {
    local input="$1"
    local numbers=""

    while [[ "$input" =~ ([0-9]+) ]]; do
        numbers+="${BASH_REMATCH[1]} "
        input="${input#*${BASH_REMATCH[1]}}"
    done

    printf '%s' "${numbers% }"  # Trim trailing space
}

# =============================================================================
# Number Formatting
# =============================================================================

# Format number with thousands separator
# Usage: format_number 1234567  # Returns "1,234,567"
format_number() {
    local num="$1"
    local separator="${2:-,}"

    # Handle negative numbers
    local prefix=""
    if [[ "$num" == -* ]]; then
        prefix="-"
        num="${num#-}"
    fi

    # Use printf with locale if available, otherwise manual
    if printf '%'"'"'d' "$num" &>/dev/null; then
        printf '%s%'"'"'d' "$prefix" "$num"
    else
        # Manual formatting
        local result=""
        local i=0
        while [[ -n "$num" ]]; do
            if [[ $i -gt 0 && $((i % 3)) -eq 0 ]]; then
                result="${separator}${result}"
            fi
            result="${num: -1}${result}"
            num="${num%?}"
            ((i++))
        done
        printf '%s%s' "$prefix" "$result"
    fi
}

# Format bytes to human readable
# Usage: format_bytes 1073741824  # Returns "1.0G"
format_bytes() {
    local bytes="$1"
    local precision="${2:-1}"

    if (( bytes >= POWERKIT_BYTE_TB )); then
        awk -v b="$bytes" -v p="$precision" 'BEGIN { printf "%.*fT", p, b / 1099511627776 }'
    elif (( bytes >= POWERKIT_BYTE_GB )); then
        awk -v b="$bytes" -v p="$precision" 'BEGIN { printf "%.*fG", p, b / 1073741824 }'
    elif (( bytes >= POWERKIT_BYTE_MB )); then
        awk -v b="$bytes" -v p="$precision" 'BEGIN { printf "%.*fM", p, b / 1048576 }'
    elif (( bytes >= POWERKIT_BYTE_KB )); then
        awk -v b="$bytes" -v p="$precision" 'BEGIN { printf "%.*fK", p, b / 1024 }'
    else
        printf '%dB' "$bytes"
    fi
}

# Format percentage
# Usage: format_percent 45.678 1  # Returns "45.7%"
format_percent() {
    local value="$1"
    local precision="${2:-0}"

    awk -v v="$value" -v p="$precision" 'BEGIN { printf "%.*f%%", p, v }'
}

# Pad number with zeros
# Usage: pad_number 5 2  # Returns "05"
pad_number() {
    local num="$1"
    local width="${2:-2}"

    printf '%0*d' "$width" "$num"
}

# =============================================================================
# Range and Validation
# =============================================================================

# Clamp value to range
# Usage: clamp 150 0 100  # Returns "100"
clamp() {
    local value="$1"
    local min="$2"
    local max="$3"

    if (( value < min )); then
        echo "$min"
    elif (( value > max )); then
        echo "$max"
    else
        echo "$value"
    fi
}

# Check if value is in range
# Usage: in_range 50 0 100 && echo "in range"
in_range() {
    local value="$1"
    local min="$2"
    local max="$3"

    (( value >= min && value <= max ))
}

# Validate numeric value with fallback
# Usage: validate_number "abc" 10  # Returns "10"
validate_number() {
    local value="$1"
    local default="$2"

    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        printf '%s' "$value"
    else
        printf '%s' "$default"
    fi
}

# =============================================================================
# Calculations
# =============================================================================

# Calculate percentage
# Usage: calc_percent 25 100  # Returns "25"
calc_percent() {
    local value="$1"
    local total="$2"

    if (( total == 0 )); then
        echo 0
        return
    fi

    awk -v v="$value" -v t="$total" 'BEGIN { printf "%.0f", (v / t) * 100 }'
}

# Calculate percentage with decimal
# Usage: calc_percent_decimal 25 100 2  # Returns "25.00"
calc_percent_decimal() {
    local value="$1"
    local total="$2"
    local precision="${3:-2}"

    if (( total == 0 )); then
        printf '%.*f' "$precision" 0
        return
    fi

    awk -v v="$value" -v t="$total" -v p="$precision" 'BEGIN { printf "%.*f", p, (v / t) * 100 }'
}

# Round number
# Usage: round 3.7  # Returns "4"
round() {
    local value="$1"
    awk -v v="$value" 'BEGIN { printf "%.0f", v }'
}

# Floor number
# Usage: floor 3.7  # Returns "3"
floor() {
    local value="$1"
    awk -v v="$value" 'BEGIN { printf "%.0f", v - (v % 1) }'
}

# Ceiling number
# Usage: ceiling 3.2  # Returns "4"
ceiling() {
    local value="$1"
    awk -v v="$value" 'BEGIN { printf "%.0f", v + (1 - (v % 1)) % 1 }'
}

# =============================================================================
# Condition Evaluation
# =============================================================================

# Evaluate numeric condition
# Usage: evaluate_condition 50 ">" 25 && echo "true"
evaluate_condition() {
    local left="$1"
    local op="$2"
    local right="$3"

    case "$op" in
        ">"|"gt")  (( left > right )) ;;
        ">="|"gte"|"ge") (( left >= right )) ;;
        "<"|"lt")  (( left < right )) ;;
        "<="|"lte"|"le") (( left <= right )) ;;
        "=="|"="|"eq") (( left == right )) ;;
        "!="|"ne") (( left != right )) ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# Uptime Formatting
# =============================================================================

# Converte segundos em formato amigável: 1d 2h, 2h 10m, 5m
# Usage: format_uptime_seconds 3661  # Returns "1h 1m"
format_uptime_seconds() {
    local seconds="$1"
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    if (( days > 0 )); then
        printf '%dd %dh' "$days" "$hours"
    elif (( hours > 0 )); then
        printf '%dh %dm' "$hours" "$minutes"
    else
        printf '%dm' "$minutes"
    fi
}