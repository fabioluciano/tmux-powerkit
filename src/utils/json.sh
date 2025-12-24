#!/usr/bin/env bash
# =============================================================================
# PowerKit Utils: JSON
# Description: Simple JSON parsing utilities (no jq required)
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_json" && return 0

# =============================================================================
# JSON Value Extraction
# =============================================================================

# Extract string value from JSON
# Usage: json_get_string "$json" "key"
# Example: json_get_string '{"name":"value"}' "name"  # Returns: value
json_get_string() {
    local json="$1"
    local key="$2"
    echo "$json" | sed -n 's/.*"'"$key"'":"\([^"]*\)".*/\1/p' | head -1
}

# Extract number from JSON
# Usage: json_get_number "$json" "count"
# Example: json_get_number '{"count":42}' "count"  # Returns: 42
json_get_number() {
    local json="$1"
    local key="$2"
    echo "$json" | sed -n 's/.*"'"$key"'":\([0-9.-]*\).*/\1/p' | head -1
}

# Extract boolean from JSON
# Usage: json_get_bool "$json" "active"
json_get_bool() {
    local json="$1"
    local key="$2"
    # shellcheck disable=SC1078,SC1079 # Complex sed quoting
    echo "$json" | sed -n 's/.*"'"$key"'":\(true\|false\).*/\1/p' | head -1
}

# Check if JSON key exists
# Usage: json_has_key "$json" "key" && echo "exists"
json_has_key() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -q "\"$key\""
}

# Extract nested value (simple dot notation)
# Usage: json_get_nested "$json" "user.name"
json_get_nested() {
    local json="$1"
    local path="$2"
    
    # Split by dots and extract sequentially
    local IFS='.'
    # shellcheck disable=SC2206 # Intentional word splitting on path
    local -a keys=($path)
    local result="$json"
    
    for key in "${keys[@]}"; do
        result=$(json_get_string "$result" "$key")
        [[ -z "$result" ]] && return 1
    done
    
    printf '%s' "$result"
}

# =============================================================================
# JSON Array Operations
# =============================================================================

# Get array length
# Usage: json_array_length '{"items":[1,2,3]}'  # Returns: 3
json_array_length() {
    local json="$1"
    local count=0
    
    # Count comma-separated items between [ ]
    local array
    array=$(echo "$json" | sed -n 's/.*\[\(.*\)\].*/\1/p')
    [[ -z "$array" ]] && { echo "0"; return; }
    
    # Count commas and add 1
    count=$(echo "$array" | grep -o "," | wc -l)
    echo $((count + 1))
}

# =============================================================================
# JSON Validation
# =============================================================================

# Simple check if string looks like valid JSON
# Usage: is_valid_json "$string" && echo "valid"
is_valid_json() {
    local json="$1"
    
    # Basic validation: starts with { or [, ends with } or ]
    [[ "$json" =~ ^[[:space:]]*[\{\[] ]] && [[ "$json" =~ [\}\]][[:space:]]*$ ]]
}
