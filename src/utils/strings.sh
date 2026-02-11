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
    # Pure bash: replace double spaces until none remain
    while [[ "$text" == *"  "* ]]; do
        text="${text//  / }"
    done
    printf '%s' "$text"
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

# =============================================================================
# String Hashing
# =============================================================================

# Generate a simple hash from a string (djb2 algorithm - pure bash, no subshells)
# Usage: string_hash "some string"  # Returns numeric hash
# Note: This is for generating unique IDs, NOT for cryptographic purposes
string_hash() {
    local str="$1"
    local hash=5381
    local i char_code

    for ((i = 0; i < ${#str}; i++)); do
        # Get ASCII code of character using printf
        printf -v char_code '%d' "'${str:i:1}"
        hash=$(( ((hash << 5) + hash) + char_code ))
    done

    # Return positive 32-bit integer
    printf '%d' "$((hash & 0x7FFFFFFF))"
}

# =============================================================================
# Format Helpers
# =============================================================================

# NOTE: format_bytes is in numbers.sh - use that for byte formatting
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
