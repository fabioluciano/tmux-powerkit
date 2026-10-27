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

    printf '%s' "${numbers% }" # Trim trailing space
}

# =============================================================================
# Internal: Pure-bash float formatter
# =============================================================================
# Formats a decimal value to N decimal places WITHOUT spawning awk.
# Splits the value on '.', computes the rounded result using integer math,
# and emits the formatted output.
#
# Usage: _format_float <value> <precision>
#   value      - Decimal or integer string (may be negative)
#   precision  - Number of decimal digits (>=0)
#
# Algorithm: scale value by 10^precision, round to nearest, split int/frac,
# emit int.frac. Avoids any external process.
_format_float() {
    local value="$1"
    local precision="$2"

    local sign="" int_part frac_part
    if [[ "$value" == -* ]]; then
        sign="-"
        value="${value#-}"
    fi

    int_part="${value%%.*}"
    int_part="${int_part:-0}"
    frac_part="${value#*.}"
    [[ "$frac_part" == "$value" ]] && frac_part=""
    frac_part="${frac_part:-0}"

    # Pad/truncate frac_part to exactly $precision digits for rounding.
    local i
    while ((${#frac_part} < precision)); do
        frac_part="${frac_part}0"
    done
    if ((${#frac_part} > precision)); then
        # Keep one extra digit for rounding; drop the rest.
        local extra="${frac_part:$precision:1}"
        frac_part="${frac_part:0:$precision}"
        if ((extra >= 5)); then
            # Round up the last kept digit.
            local carry=1
            local j=$((precision - 1))
            local rounded
            while ((j >= 0)); do
                local d="${frac_part:$j:1}"
                local nd=$((d + carry))
                if ((nd >= 10)); then
                    nd=0
                    carry=1
                else
                    carry=0
                fi
                rounded="${nd}${rounded:-}"
                j=$((j - 1))
            done
            if ((carry)); then
                int_part=$((int_part + 1))
                rounded=""
            fi
            frac_part="$rounded"
        fi
    fi

    if ((precision == 0)); then
        printf '%s%d' "$sign" "$int_part"
    else
        printf '%s%d.%s' "$sign" "$int_part" "$frac_part"
    fi
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

# Format bytes to human readable (pure bash, precision in {0,1,2}).
# For precision > 2, fall back to awk (rare in practice).
# Usage: format_bytes 1073741824  # Returns "1.0G"
format_bytes() {
    local bytes="$1"
    local precision="${2:-1}"

    if ((precision > 2)); then
        # Fallback for unusual precision; preserves original behavior.
        awk -v b="$bytes" -v p="$precision" '
            BEGIN {
                if (b >= 1099511627776) printf "%.*fT", p, b / 1099511627776
                else if (b >= 1073741824) printf "%.*fG", p, b / 1073741824
                else if (b >= 1048576) printf "%.*fM", p, b / 1048576
                else if (b >= 1024) printf "%.*fK", p, b / 1024
                else printf "%dB", b
            }'
        return
    fi

    if ((bytes >= POWERKIT_BYTE_TB)); then
        _format_byte_scaled "$bytes" "$POWERKIT_BYTE_TB" "$precision" "T"
    elif ((bytes >= POWERKIT_BYTE_GB)); then
        _format_byte_scaled "$bytes" "$POWERKIT_BYTE_GB" "$precision" "G"
    elif ((bytes >= POWERKIT_BYTE_MB)); then
        _format_byte_scaled "$bytes" "$POWERKIT_BYTE_MB" "$precision" "M"
    elif ((bytes >= POWERKIT_BYTE_KB)); then
        _format_byte_scaled "$bytes" "$POWERKIT_BYTE_KB" "$precision" "K"
    else
        printf '%dB' "$bytes"
    fi
}

# Internal: render scaled bytes with N decimals + suffix.
# Usage: _format_byte_scaled <bytes> <divisor> <precision> <suffix>
# Avoids multiplication overflow by scaling in chunks when bytes is huge.
_format_byte_scaled() {
    local bytes="$1" divisor="$2" precision="$3" suffix="$4"
    local int_part frac scaled
    int_part=$((bytes / divisor))
    frac=$(((bytes % divisor) * 100 / divisor)) # 2-decimal residual; good enough for N<=2
    if ((precision == 0)); then
        printf '%d%s' "$int_part" "$suffix"
    elif ((precision == 1)); then
        # Round to 1 decimal from 2-decimal frac.
        local rounded_frac=$(((frac + 5) / 10))
        if ((rounded_frac >= 10)); then
            int_part=$((int_part + 1))
            rounded_frac=0
        fi
        printf '%d.%d%s' "$int_part" "$rounded_frac" "$suffix"
    else
        # General case: scale int_part by 10^precision, add rounded frac.
        local scale=$((10 ** precision))
        scaled=$((int_part * scale + (frac * scale / 100 + scale / 200) / 1))
        # Re-extract (scaled may have rolled over into int_part).
        if ((scaled >= int_part * scale + scale)); then
            int_part=$((int_part + 1))
            scaled=$((scaled - scale * (int_part - bytes / divisor)))
        fi
        printf '%d.%0*d%s' "$int_part" "$precision" "$((scaled % scale))" "$suffix"
    fi
}

# Format number to human readable with SI suffixes (base 1000, pure bash)
# Usage: format_metric 1500  # Returns "1.5K"
# Usage: format_metric 1500000  # Returns "1.5M"
format_metric() {
    local value="$1"
    local precision="${2:-1}"
    local suffix="${3:-}" # optional suffix (e.g., "/s" for rate)

    if ((value >= 1000000000)); then
        _format_scaled_int "$value" 1000000000 "$precision" "G" "$suffix"
    elif ((value >= 1000000)); then
        _format_scaled_int "$value" 1000000 "$precision" "M" "$suffix"
    elif ((value >= 1000)); then
        _format_scaled_int "$value" 1000 "$precision" "K" "$suffix"
    else
        printf '%d%s' "$value" "$suffix"
    fi
}

# Internal: render int-scaled value with N decimals + double suffix.
_format_scaled_int() {
    local value="$1" divisor="$2" precision="$3" prefix="$4" suffix="$5"
    local scaled=$(((value * 10 ** precision + divisor / 2) / divisor))
    local int_part=$((scaled / 10 ** precision))
    local frac=$((scaled % 10 ** precision))
    printf '%d.%0*d%s%s' "$int_part" "$precision" "$frac" "$prefix" "$suffix"
}

# Format percentage (pure bash)
# Usage: format_percent 45.678 1  # Returns "45.7%"
format_percent() {
    local value="$1"
    local precision="${2:-0}"

    local formatted
    formatted=$(_format_float "$value" "$precision")
    printf '%s%%' "$formatted"
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

    if ((value < min)); then
        echo "$min"
    elif ((value > max)); then
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

    ((value >= min && value <= max))
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

# Calculate percentage (pure bash)
# Usage: calc_percent 25 100  # Returns "25"
calc_percent() {
    local value="$1"
    local total="$2"

    if ((total == 0)); then
        echo 0
        return
    fi

    # Round to nearest integer percent: (value * 100 + total/2) / total
    echo $(((value * 100 + total / 2) / total))
}

# Calculate percentage with decimal (pure bash)
# Usage: calc_percent_decimal 25 100 2  # Returns "25.00"
calc_percent_decimal() {
    local value="$1"
    local total="$2"
    local precision="${3:-2}"

    if ((total == 0)); then
        printf '%.*f' "$precision" 0
        return
    fi

    # Compute scaled = round(value * 10^precision * 100 / total)
    #   = round(value/total * 100 * 10^precision)
    # Use big-enough intermediate to avoid premature truncation.
    local scale=$((10 ** precision))
    local scaled=$(((value * 100 * scale + total / 2) / total))
    local int_part=$((scaled / scale))
    local frac=$((scaled % scale))
    printf '%d.%0*d' "$int_part" "$precision" "$frac"
}

# Round number (pure bash)
# Usage: round 3.7  # Returns "4"
round() {
    local value="$1"
    local sign=""
    if [[ "$value" == -* ]]; then
        sign="-"
        value="${value#-}"
    fi
    local int_part="${value%%.*}"
    local frac_part="${value#*.}"
    [[ "$frac_part" == "$value" ]] && frac_part=""
    if [[ -n "$frac_part" && ${frac_part:0:1} -ge 5 ]]; then
        int_part=$((int_part + 1))
    fi
    printf '%s%d' "$sign" "$int_part"
}

# Floor number (pure bash)
# Usage: floor 3.7  # Returns "3"
floor() {
    local value="$1"
    if [[ "$value" == -* ]]; then
        # For negatives, floor = int_part - 1 if there's a non-zero fractional part.
        local abs="${value#-}"
        local int_part="${abs%%.*}"
        local frac_part="${abs#*.}"
        [[ "$frac_part" == "$abs" ]] && frac_part=""
        # Strip leading zeros; "0", "00", "000" all mean "no fraction".
        local stripped="${frac_part#"${frac_part%%[!0]*}"}"
        if [[ -n "$stripped" ]]; then
            int_part=$((int_part + 1))
        fi
        printf -- '-%d' "$int_part"
    else
        local int_part="${value%%.*}"
        printf '%d' "$int_part"
    fi
}

# Ceiling number (pure bash)
# Usage: ceiling 3.2  # Returns "4"
ceiling() {
    local value="$1"
    if [[ "$value" == -* ]]; then
        # For negatives, ceiling = int_part (no change).
        local abs="${value#-}"
        local int_part="${abs%%.*}"
        printf -- '-%d' "$int_part"
    else
        local int_part="${value%%.*}"
        local frac_part="${value#*.}"
        [[ "$frac_part" == "$value" ]] && frac_part=""
        if [[ -n "$frac_part" ]]; then
            int_part=$((int_part + 1))
        fi
        printf '%d' "$int_part"
    fi
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
    ">" | "gt") ((left > right)) ;;
    ">=" | "gte" | "ge") ((left >= right)) ;;
    "<" | "lt") ((left < right)) ;;
    "<=" | "lte" | "le") ((left <= right)) ;;
    "==" | "=" | "eq") ((left == right)) ;;
    "!=" | "ne") ((left != right)) ;;
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
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    if ((days > 0)); then
        printf '%dd %dh' "$days" "$hours"
    elif ((hours > 0)); then
        printf '%dh %dm' "$hours" "$minutes"
    else
        printf '%dm' "$minutes"
    fi
}

# =============================================================================
# Speed Formatting
# =============================================================================

# Format speed (KB per second) to human readable (pure bash)
# Usage: format_speed 1536     # Returns "1.5M" (input is KB/s)
# Usage: format_speed 512      # Returns "512K"
# Usage: format_speed 512 1 "/s"  # Returns "512.0K/s"
format_speed() {
    local kb_per_sec="${1:-0}"
    local precision="${2:-0}"
    local suffix="${3:-}"

    if ((kb_per_sec >= 1024)); then
        # M = KB/1024 with N decimals.
        local scaled=$(((kb_per_sec * 10 ** precision + 512) / 1024))
        local int_part=$((scaled / 10 ** precision))
        local frac=$((scaled % 10 ** precision))
        if ((precision == 0)); then
            printf '%dM%s' "$int_part" "$suffix"
        else
            printf '%d.%0*dM%s' "$int_part" "$precision" "$frac" "$suffix"
        fi
    else
        if ((precision > 0)); then
            printf '%d.%0*dK%s' "$kb_per_sec" "$precision" 0 "$suffix"
        else
            printf '%dK%s' "$kb_per_sec" "$suffix"
        fi
    fi
}
