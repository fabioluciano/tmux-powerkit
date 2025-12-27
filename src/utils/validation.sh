#!/usr/bin/env bash
# =============================================================================
#
#  ██████╗  ██████╗ ██╗    ██╗███████╗██████╗ ██╗  ██╗██╗████████╗
#  ██╔══██╗██╔═══██╗██║    ██║██╔════╝██╔══██╗██║ ██╔╝██║╚══██╔══╝
#  ██████╔╝██║   ██║██║ █╗ ██║█████╗  ██████╔╝█████╔╝ ██║   ██║
#  ██╔═══╝ ██║   ██║██║███╗██║██╔══╝  ██╔══██╗██╔═██╗ ██║   ██║
#  ██║     ╚██████╔╝╚███╔███╔╝███████╗██║  ██║██║  ██╗██║   ██║
#  ╚═╝      ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝
#
#  VALIDATION UTILITIES - Version 1.0.0
#  Generic validation functions for PowerKit contracts
#
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_validation" && return 0
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. API Reference
#   3. Examples
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# This module provides generic validation utilities used across all PowerKit
# contracts. It eliminates code duplication by providing a single, reusable
# implementation for common validation patterns.
#
# Key Functions:
#   - validate_against_enum()  - Check if value exists in an enum array
#   - validate_not_empty()     - Check if value is non-empty
#   - validate_numeric()       - Check if value is numeric
#   - validate_in_range()      - Check if numeric value is within range
#   - validate_matches()       - Check if value matches a regex pattern
#
# =============================================================================
#
# 2. API REFERENCE
# ================
#
#   validate_against_enum VALUE ENUM_ARRAY_NAME
#       Check if VALUE exists in the array referenced by ENUM_ARRAY_NAME.
#       Uses bash nameref for efficiency.
#
#       Returns: 0 if valid, 1 if invalid
#
#   validate_not_empty VALUE [NAME]
#       Check if VALUE is non-empty. NAME is used for error messages.
#
#       Returns: 0 if non-empty, 1 if empty
#
#   validate_numeric VALUE
#       Check if VALUE is a valid integer (positive or negative).
#
#       Returns: 0 if numeric, 1 if not
#
#   validate_in_range VALUE MIN MAX
#       Check if numeric VALUE is between MIN and MAX (inclusive).
#
#       Returns: 0 if in range, 1 if out of range or not numeric
#
#   validate_matches VALUE PATTERN
#       Check if VALUE matches the regex PATTERN.
#
#       Returns: 0 if matches, 1 if not
#
# =============================================================================
#
# 3. EXAMPLES
# ===========
#
#   # Validate against enum
#   declare -a PLUGIN_STATES=("inactive" "active" "degraded" "failed")
#   validate_against_enum "active" PLUGIN_STATES && echo "Valid state"
#
#   # Validate not empty
#   validate_not_empty "$username" "username" || echo "Username required"
#
#   # Validate numeric
#   validate_numeric "$port" && echo "Port is numeric"
#
#   # Validate range
#   validate_in_range "$percent" 0 100 && echo "Percent in valid range"
#
#   # Validate pattern
#   validate_matches "$color" '^#[0-9a-fA-F]{6}$' && echo "Valid hex color"
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# =============================================================================
# Enum Validation
# =============================================================================

# Validate value against an enum array
# Usage: validate_against_enum "value" ARRAY_NAME
# Returns: 0 if valid, 1 if invalid
#
# Note: Uses nameref (-n) for efficient array access without copying
validate_against_enum() {
    local value="$1"
    local -n enum_array="$2"  # nameref to the array
    local valid

    for valid in "${enum_array[@]}"; do
        [[ "$value" == "$valid" ]] && return 0
    done
    return 1
}

# Alternative without nameref (for older bash or when nameref causes issues)
# Usage: validate_against_enum_safe "value" "${ARRAY[@]}"
validate_against_enum_safe() {
    local value="$1"
    shift
    local valid

    for valid in "$@"; do
        [[ "$value" == "$valid" ]] && return 0
    done
    return 1
}

# =============================================================================
# Basic Validation
# =============================================================================

# Validate that value is not empty
# Usage: validate_not_empty "$value" ["field_name"]
# Returns: 0 if non-empty, 1 if empty
validate_not_empty() {
    local value="$1"
    # name parameter reserved for future error messaging
    # shellcheck disable=SC2034
    local name="${2:-value}"

    [[ -n "$value" ]]
}

# Validate that value is numeric (integer)
# Usage: validate_numeric "$value"
# Returns: 0 if numeric, 1 if not
validate_numeric() {
    local value="$1"

    # Check for optional negative sign followed by digits
    [[ "$value" =~ ^-?[0-9]+$ ]]
}

# Validate that value is a positive integer
# Usage: validate_positive_integer "$value"
# Returns: 0 if positive integer, 1 if not
validate_positive_integer() {
    local value="$1"

    [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -gt 0 ]]
}

# Validate that value is a non-negative integer (0 or positive)
# Usage: validate_non_negative_integer "$value"
# Returns: 0 if non-negative integer, 1 if not
validate_non_negative_integer() {
    local value="$1"

    [[ "$value" =~ ^[0-9]+$ ]]
}

# =============================================================================
# Range Validation
# =============================================================================

# Validate numeric value is within range (inclusive)
# Usage: validate_in_range "$value" MIN MAX
# Returns: 0 if in range, 1 if out of range or not numeric
validate_in_range() {
    local value="$1"
    local min="$2"
    local max="$3"

    # First check if numeric
    validate_numeric "$value" || return 1
    validate_numeric "$min" || return 1
    validate_numeric "$max" || return 1

    # Check range
    (( value >= min && value <= max ))
}

# Validate percentage (0-100)
# Usage: validate_percentage "$value"
# Returns: 0 if valid percentage, 1 if not
validate_percentage() {
    local value="$1"
    validate_in_range "$value" 0 100
}

# =============================================================================
# Pattern Validation
# =============================================================================

# Validate value matches a regex pattern
# Usage: validate_matches "$value" "PATTERN"
# Returns: 0 if matches, 1 if not
validate_matches() {
    local value="$1"
    local pattern="$2"

    [[ "$value" =~ $pattern ]]
}

# Validate hex color format (#RRGGBB)
# Usage: validate_hex_color "$value"
# Returns: 0 if valid hex color, 1 if not
validate_hex_color() {
    local value="$1"
    validate_matches "$value" '^#[0-9a-fA-F]{6}$'
}

# Validate hex color with optional alpha (#RRGGBB or #RRGGBBAA)
# Usage: validate_hex_color_alpha "$value"
# Returns: 0 if valid, 1 if not
validate_hex_color_alpha() {
    local value="$1"
    validate_matches "$value" '^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$'
}

# =============================================================================
# Type Validation
# =============================================================================

# Validate boolean value (true/false, yes/no, 1/0, on/off)
# Usage: validate_boolean "$value"
# Returns: 0 if valid boolean, 1 if not
validate_boolean() {
    local value="$1"
    local lower="${value,,}"  # lowercase

    case "$lower" in
        true|false|yes|no|1|0|on|off) return 0 ;;
        *) return 1 ;;
    esac
}

# Normalize boolean to "true" or "false"
# Usage: result=$(normalize_boolean "$value")
normalize_boolean() {
    local value="$1"
    local lower="${value,,}"

    case "$lower" in
        true|yes|1|on) echo "true" ;;
        false|no|0|off) echo "false" ;;
        *) echo "false" ;;  # Default to false for invalid values
    esac
}

# =============================================================================
# File/Path Validation
# =============================================================================

# Validate that path exists (file or directory)
# Usage: validate_path_exists "$path"
# Returns: 0 if exists, 1 if not
validate_path_exists() {
    local path="$1"
    [[ -e "$path" ]]
}

# Validate that file exists and is readable
# Usage: validate_file_readable "$path"
# Returns: 0 if readable, 1 if not
validate_file_readable() {
    local path="$1"
    [[ -f "$path" && -r "$path" ]]
}

# Validate that directory exists and is accessible
# Usage: validate_directory_accessible "$path"
# Returns: 0 if accessible, 1 if not
validate_directory_accessible() {
    local path="$1"
    [[ -d "$path" && -x "$path" ]]
}

# =============================================================================
# Compound Validation
# =============================================================================

# Validate multiple conditions (AND logic)
# Usage: validate_all condition1 condition2 ...
# Each condition should be a return value (0 or non-zero)
# Returns: 0 if all pass, 1 if any fail
validate_all() {
    local condition
    for condition in "$@"; do
        [[ "$condition" -eq 0 ]] || return 1
    done
    return 0
}

# Validate at least one condition (OR logic)
# Usage: validate_any condition1 condition2 ...
# Returns: 0 if any pass, 1 if all fail
validate_any() {
    local condition
    for condition in "$@"; do
        [[ "$condition" -eq 0 ]] && return 0
    done
    return 1
}
