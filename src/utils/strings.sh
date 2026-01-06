#!/usr/bin/env bash
# =============================================================================
# PowerKit Utils: Strings
# Description: String manipulation utilities
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_strings" && return 0

# =============================================================================
# String Truncation
# =============================================================================

# Truncate text to maximum length
# Usage: truncate_text "Hello World" 5  # Returns "Hello"
truncate_text() {
    local text="$1"
    local max_len="$2"
    local ellipsis="${3:-}"

    [[ "$max_len" -le 0 ]] && { printf '%s' "$text"; return; }

    if [[ ${#text} -le $max_len ]]; then
        printf '%s' "$text"
    else
        local truncated="${text:0:$max_len}"
        printf '%s%s' "$truncated" "$ellipsis"
    fi
}

# Truncate text at word boundary (doesn't cut words in the middle)
# Usage: truncate_words "Hello World Example" 12  # Returns "Hello World"
# Usage: truncate_words "Hello World Example" 12 "..."  # Returns "Hello..."
truncate_words() {
    local text="$1"
    local max_len="$2"
    local ellipsis="${3:-}"

    [[ "$max_len" -le 0 ]] && { printf '%s' "$text"; return; }

    if [[ ${#text} -le $max_len ]]; then
        printf '%s' "$text"
        return
    fi

    # Account for ellipsis length
    local effective_max=$((max_len - ${#ellipsis}))
    [[ $effective_max -le 0 ]] && { printf '%s' "$ellipsis"; return; }

    # Get substring up to effective max
    local truncated="${text:0:$effective_max}"

    # If we're not at a space and text continues, find last word boundary
    if [[ "${text:$effective_max:1}" != " " && "${text:$effective_max:1}" != "" ]]; then
        # Find last space
        if [[ "$truncated" == *" "* ]]; then
            truncated="${truncated% *}"
        fi
    fi

    # Trim trailing spaces
    truncated="${truncated%"${truncated##*[![:space:]]}"}"

    printf '%s%s' "$truncated" "$ellipsis"
}

# Truncate with ellipsis in the middle
# Usage: truncate_middle "very_long_filename.txt" 15  # Returns "very_l...me.txt"
truncate_middle() {
    local text="$1"
    local max_len="$2"
    local ellipsis="${3:-...}"

    [[ "$max_len" -le 0 ]] && { printf '%s' "$text"; return; }

    if [[ ${#text} -le $max_len ]]; then
        printf '%s' "$text"
        return
    fi

    local ellipsis_len=${#ellipsis}
    local available=$((max_len - ellipsis_len))
    local front=$((available / 2))
    local back=$((available - front))

    printf '%s%s%s' "${text:0:$front}" "$ellipsis" "${text: -$back}"
}

# =============================================================================
# String Joining
# =============================================================================

# Join array elements with separator
# Usage: join_with_separator " | " "a" "b" "c"  # Returns "a | b | c"
join_with_separator() {
    local separator="$1"
    shift

    local result=""
    local first=1

    for item in "$@"; do
        if [[ $first -eq 1 ]]; then
            result="$item"
            first=0
        else
            result+="${separator}${item}"
        fi
    done

    printf '%s' "$result"
}

# Join non-empty items only
# Usage: join_non_empty " " "a" "" "b"  # Returns "a b"
join_non_empty() {
    local separator="$1"
    shift

    local items=()
    for item in "$@"; do
        [[ -n "$item" ]] && items+=("$item")
    done

    join_with_separator "$separator" "${items[@]}"
}

# =============================================================================
# Whitespace Handling
# =============================================================================

# Trim leading whitespace
# Usage: trim_left "  hello  "  # Returns "hello  "
trim_left() {
    local text="$1"
    printf '%s' "${text#"${text%%[![:space:]]*}"}"
}

# Trim trailing whitespace
# Usage: trim_right "  hello  "  # Returns "  hello"
trim_right() {
    local text="$1"
    printf '%s' "${text%"${text##*[![:space:]]}"}"
}

# Trim both leading and trailing whitespace (no subshells - pure parameter expansion)
# Usage: trim "  hello  "  # Returns "hello"
trim() {
    local text="$1"
    # Trim leading whitespace
    text="${text#"${text%%[![:space:]]*}"}"
    # Trim trailing whitespace
    printf '%s' "${text%"${text##*[![:space:]]}"}"
}

# Trim in-place using nameref (Bash 4.3+) - ZERO subshells
# Usage: trim_inplace varname  # Modifies variable directly
# Example:
#   name="  hello  "
#   trim_inplace name
#   echo "$name"  # "hello"
trim_inplace() {
    local -n _trim_ref="$1"
    # Trim leading whitespace
    _trim_ref="${_trim_ref#"${_trim_ref%%[![:space:]]*}"}"
    # Trim trailing whitespace
    _trim_ref="${_trim_ref%"${_trim_ref##*[![:space:]]}"}"
}

# Collapse multiple spaces to single space
# Usage: collapse_spaces "hello    world"  # Returns "hello world"
collapse_spaces() {
    local text="$1"
    printf '%s' "$text" | tr -s ' '
}

# =============================================================================
# Case Conversion
# =============================================================================

# Convert to lowercase
# Usage: to_lower "HELLO"  # Returns "hello"
to_lower() {
    printf '%s' "${1,,}"
}

# Convert to uppercase
# Usage: to_upper "hello"  # Returns "HELLO"
to_upper() {
    printf '%s' "${1^^}"
}

# Capitalize first letter
# Usage: capitalize "hello world"  # Returns "Hello world"
capitalize() {
    local text="$1"
    printf '%s%s' "${text:0:1}" "${text:1}" | { read -r first rest; printf '%s%s' "${first^}" "$rest"; }
}

# Convert to title case
# Usage: to_title "hello world"  # Returns "Hello World"
to_title() {
    local text="$1"
    local result=""
    local word

    for word in $text; do
        result+="${word^} "
    done

    printf '%s' "${result% }"  # Trim trailing space
}

# =============================================================================
# String Search and Replace
# =============================================================================

# Check if string contains substring
# Usage: contains "hello world" "world" && echo "found"
contains() {
    local string="$1"
    local substring="$2"
    [[ "$string" == *"$substring"* ]]
}

# Check if string starts with prefix
# Usage: starts_with "hello" "he" && echo "yes"
starts_with() {
    local string="$1"
    local prefix="$2"
    [[ "$string" == "$prefix"* ]]
}

# Check if string ends with suffix
# Usage: ends_with "hello" "lo" && echo "yes"
ends_with() {
    local string="$1"
    local suffix="$2"
    [[ "$string" == *"$suffix" ]]
}

# Replace first occurrence
# Usage: replace_first "hello hello" "hello" "hi"  # Returns "hi hello"
replace_first() {
    local string="$1"
    local search="$2"
    local replace="$3"
    printf '%s' "${string/$search/$replace}"
}

# Replace all occurrences
# Usage: replace_all "hello hello" "hello" "hi"  # Returns "hi hi"
replace_all() {
    local string="$1"
    local search="$2"
    local replace="$3"
    printf '%s' "${string//$search/$replace}"
}

# Remove all occurrences
# Usage: remove_all "hello world" "o"  # Returns "hell wrld"
remove_all() {
    local string="$1"
    local pattern="$2"
    printf '%s' "${string//$pattern/}"
}

# =============================================================================
# String Extraction
# =============================================================================

# Get substring
# Usage: substring "hello world" 0 5  # Returns "hello"
substring() {
    local string="$1"
    local start="$2"
    local length="${3:-}"

    if [[ -n "$length" ]]; then
        printf '%s' "${string:$start:$length}"
    else
        printf '%s' "${string:$start}"
    fi
}

# Get string length
# Usage: str_length "hello"  # Returns "5"
str_length() {
    printf '%d' "${#1}"
}

# Split string by delimiter
# Usage: IFS=',' read -ra parts <<< "$(split_string "a,b,c" ",")"
split_string() {
    local string="$1"
    local delimiter="$2"

    local IFS="$delimiter"
    printf '%s\n' $string
}

# =============================================================================
# String Validation
# =============================================================================

# Check if string is empty or whitespace only
# Usage: is_blank "   " && echo "blank"
is_blank() {
    local text="$1"
    [[ -z "${text// /}" ]]
}

# Check if string is a valid identifier (alphanumeric + underscore)
# Usage: is_identifier "my_var" && echo "valid"
is_identifier() {
    local text="$1"
    [[ "$text" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}

# Check if string is numeric
# Usage: is_numeric "123" && echo "numeric"
is_numeric() {
    local text="$1"
    [[ "$text" =~ ^-?[0-9]+\.?[0-9]*$ ]]
}

# =============================================================================
# Padding
# =============================================================================

# Pad string to the right
# Usage: pad_right "hi" 5  # Returns "hi   "
pad_right() {
    local text="$1"
    local width="$2"
    local char="${3:- }"

    printf '%-*s' "$width" "$text"
}

# Pad string to the left
# Usage: pad_left "hi" 5  # Returns "   hi"
pad_left() {
    local text="$1"
    local width="$2"
    # shellcheck disable=SC2034 # Reserved for future use with custom padding char
    local char="${3:- }"

    printf '%*s' "$width" "$text"
}

# Center string
# Usage: center "hi" 10  # Returns "    hi    "
center() {
    local text="$1"
    local width="$2"
    local text_len=${#text}

    if (( text_len >= width )); then
        printf '%s' "$text"
        return
    fi

    local total_padding=$((width - text_len))
    local left_padding=$((total_padding / 2))
    local right_padding=$((total_padding - left_padding))

    printf '%*s%s%*s' "$left_padding" "" "$text" "$right_padding" ""
}

# =============================================================================
# Format Helpers
# =============================================================================

# NOTE: format_bytes is in numbers.sh - use that for byte formatting

# Format seconds to human-readable duration
# Usage: format_duration 3665  # Returns "1h 1m 5s"
format_duration() {
    local seconds="${1:-0}"
    local show_seconds="${2:-true}"
    
    [[ -z "$seconds" || "$seconds" == "-" ]] && { echo "0s"; return; }
    seconds=${seconds%.*}  # Remove decimal part
    [[ "$seconds" -lt 0 ]] && seconds=0
    
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local mins=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))
    
    local result=""
    [[ $days -gt 0 ]] && result="${days}d "
    [[ $hours -gt 0 ]] && result="${result}${hours}h "
    [[ $mins -gt 0 ]] && result="${result}${mins}m "
    
    if [[ "$show_seconds" == "true" ]] || [[ -z "$result" ]]; then
        result="${result}${secs}s"
    fi
    
    echo "${result% }"  # Remove trailing space
}

# Format percentage with optional precision
# Usage: format_percentage 0.856 1  # Returns "85.6%"
format_percentage() {
    local value="${1:-0}"
    local precision="${2:-0}"
    
    [[ -z "$value" || "$value" == "-" ]] && { echo "0%"; return; }
    
    # If value is already percentage (>1), use as-is, otherwise multiply by 100
    local percent
    if (( $(echo "$value > 1" | bc -l 2>/dev/null || echo 0) )); then
        percent=$value
    else
        percent=$(awk "BEGIN {printf \"%.${precision}f\", $value * 100}")
    fi
    
    printf "%.${precision}f%%" "$percent"
}

# NOTE: format_number is in numbers.sh - use that for number formatting with thousands separator

# Format seconds to mm:ss timer format
# Usage: format_timer 125   # Returns "02:05"
# Usage: format_timer 3661  # Returns "61:01"
format_timer() {
    local seconds="${1:-0}"
    local minutes=$((seconds / 60))
    local secs=$((seconds % 60))
    printf '%02d:%02d' "$minutes" "$secs"
}
