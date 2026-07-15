#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/utils/validation.sh
# Covers: validate_not_empty, validate_numeric, validate_positive_integer,
#         validate_non_negative_integer, validate_in_range, validate_percentage,
#         validate_hex_color, validate_hex_color_alpha, validate_boolean,
#         normalize_boolean, validate_path_exists, validate_file_readable,
#         validate_directory_accessible, validate_matches,
#         validate_against_enum, validate_against_enum_safe,
#         validate_all, validate_any
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# validate_not_empty
# =============================================================================

@test "validate_not_empty returns success for non-empty value" {
    run bash -c 'source "$1" && validate_not_empty "hello"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_not_empty returns failure for empty value" {
    run bash -c 'source "$1" && validate_not_empty ""' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

# =============================================================================
# validate_numeric
# =============================================================================

@test "validate_numeric returns success for positive integer" {
    run bash -c 'source "$1" && validate_numeric "42"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_numeric returns success for negative integer" {
    run bash -c 'source "$1" && validate_numeric "-5"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_numeric returns success for zero" {
    run bash -c 'source "$1" && validate_numeric "0"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_numeric returns failure for alphabetic string" {
    run bash -c 'source "$1" && validate_numeric "abc"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_numeric returns failure for empty string" {
    run bash -c 'source "$1" && validate_numeric ""' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

# =============================================================================
# validate_positive_integer
# =============================================================================

@test "validate_positive_integer returns success for positive value" {
    run bash -c 'source "$1" && validate_positive_integer "5"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_positive_integer returns failure for zero" {
    run bash -c 'source "$1" && validate_positive_integer "0"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_positive_integer returns failure for negative value" {
    run bash -c 'source "$1" && validate_positive_integer "-1"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_positive_integer returns failure for non-numeric" {
    run bash -c 'source "$1" && validate_positive_integer "abc"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

# =============================================================================
# validate_non_negative_integer
# =============================================================================

@test "validate_non_negative_integer returns success for zero" {
    run bash -c 'source "$1" && validate_non_negative_integer "0"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_non_negative_integer returns success for positive" {
    run bash -c 'source "$1" && validate_non_negative_integer "10"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_non_negative_integer returns failure for negative" {
    run bash -c 'source "$1" && validate_non_negative_integer "-1"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

# =============================================================================
# validate_in_range
# =============================================================================

@test "validate_in_range returns success when value is within range" {
    run bash -c 'source "$1" && validate_in_range "5" 0 10' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_in_range returns failure when value exceeds maximum" {
    run bash -c 'source "$1" && validate_in_range "15" 0 10' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_in_range returns failure when value is below minimum" {
    run bash -c 'source "$1" && validate_in_range "-5" 0 10' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_in_range returns success at boundaries" {
    run bash -c 'source "$1" && validate_in_range "0" 0 100 && validate_in_range "100" 0 100' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

# =============================================================================
# validate_percentage
# =============================================================================

@test "validate_percentage returns success for 50" {
    run bash -c 'source "$1" && validate_percentage "50"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_percentage returns success for 0" {
    run bash -c 'source "$1" && validate_percentage "0"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_percentage returns success for 100" {
    run bash -c 'source "$1" && validate_percentage "100"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_percentage returns failure for 101" {
    run bash -c 'source "$1" && validate_percentage "101"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_percentage returns failure for negative value" {
    run bash -c 'source "$1" && validate_percentage "-1"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

# =============================================================================
# validate_hex_color
# =============================================================================

@test "validate_hex_color returns success for valid #RRGGBB" {
    run bash -c 'source "$1" && validate_hex_color "#ff0000"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_hex_color returns success for uppercase hex" {
    run bash -c 'source "$1" && validate_hex_color "#FF00FF"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_hex_color returns failure for short form #RGB" {
    run bash -c 'source "$1" && validate_hex_color "#FFF"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_hex_color returns failure for non-color string" {
    run bash -c 'source "$1" && validate_hex_color "notacolor"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

# =============================================================================
# validate_hex_color_alpha
# =============================================================================

@test "validate_hex_color_alpha accepts #RRGGBB" {
    run bash -c 'source "$1" && validate_hex_color_alpha "#ff0000"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_hex_color_alpha accepts #RRGGBBAA" {
    run bash -c 'source "$1" && validate_hex_color_alpha "#ff000080"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_hex_color_alpha rejects #RGB" {
    run bash -c 'source "$1" && validate_hex_color_alpha "#FFF"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

# =============================================================================
# validate_boolean
# =============================================================================

@test "validate_boolean returns success for 'true'" {
    run bash -c 'source "$1" && validate_boolean "true"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_boolean returns success for 'false'" {
    run bash -c 'source "$1" && validate_boolean "false"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_boolean returns success for case-insensitive TRUE" {
    run bash -c 'source "$1" && validate_boolean "TRUE"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_boolean returns success for 'yes' and 'no'" {
    run bash -c 'source "$1" && validate_boolean "yes" && validate_boolean "no"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_boolean returns success for '1' and '0'" {
    run bash -c 'source "$1" && validate_boolean "1" && validate_boolean "0"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_boolean returns success for 'on' and 'off'" {
    run bash -c 'source "$1" && validate_boolean "on" && validate_boolean "off"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_boolean returns failure for arbitrary string" {
    run bash -c 'source "$1" && validate_boolean "maybe"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

# =============================================================================
# normalize_boolean
# =============================================================================

@test "normalize_boolean outputs 'true' for 'true'" {
    run bash -c 'source "$1" && normalize_boolean "true"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
    assert_output "true"
}

@test "normalize_boolean outputs 'true' for '1'" {
    run bash -c 'source "$1" && normalize_boolean "1"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
    assert_output "true"
}

@test "normalize_boolean outputs 'true' for 'yes'" {
    run bash -c 'source "$1" && normalize_boolean "yes"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
    assert_output "true"
}

@test "normalize_boolean outputs 'false' for 'no'" {
    run bash -c 'source "$1" && normalize_boolean "no"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
    assert_output "false"
}

@test "normalize_boolean outputs 'false' for '0'" {
    run bash -c 'source "$1" && normalize_boolean "0"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
    assert_output "false"
}

# =============================================================================
# validate_path_exists
# =============================================================================

@test "validate_path_exists returns success for /tmp" {
    run bash -c 'source "$1" && validate_path_exists "/tmp"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_path_exists returns failure for nonexistent path" {
    run bash -c 'source "$1" && validate_path_exists "/nonexistent_path_xyz_12345"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_file_readable returns failure for nonexistent file" {
    run bash -c 'source "$1" && validate_file_readable "/nonexistent_file_xyz_12345"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_directory_accessible returns success for /tmp" {
    run bash -c 'source "$1" && validate_directory_accessible "/tmp"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

# =============================================================================
# validate_matches
# =============================================================================

@test "validate_matches returns success when value matches pattern" {
    run bash -c 'source "$1" && validate_matches "hello" "^h.*o$"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_matches returns failure when value does not match" {
    run bash -c 'source "$1" && validate_matches "hello" "^[0-9]+$"' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

# =============================================================================
# validate_against_enum
# =============================================================================

@test "validate_against_enum returns success for valid enum value" {
    run bash -c '
        source "$1"
        declare -a PLUGIN_STATES=("inactive" "active" "degraded" "failed")
        validate_against_enum "active" PLUGIN_STATES
    ' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_against_enum returns failure for invalid enum value" {
    run bash -c '
        source "$1"
        declare -a PLUGIN_STATES=("inactive" "active" "degraded" "failed")
        validate_against_enum "unknown" PLUGIN_STATES
    ' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_against_enum_safe works without nameref" {
    run bash -c '
        source "$1"
        declare -a PLUGIN_STATES=("inactive" "active" "degraded" "failed")
        validate_against_enum_safe "active" "${PLUGIN_STATES[@]}"
    ' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

# =============================================================================
# Compound Validation
# =============================================================================

@test "validate_all returns success when all conditions pass" {
    run bash -c '
        source "$1"
        source "$1" 2>/dev/null  # idempotent
        true_cond() { return 0; }
        true_cond; rc1=$?
        true_cond; rc2=$?
        validate_all "$rc1" "$rc2"
    ' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_all returns failure when any condition fails" {
    run bash -c '
        source "$1"
        false_cond() { return 1; }
        true_cond() { return 0; }
        true_cond; rc1=$?
        false_cond; rc2=$?
        validate_all "$rc1" "$rc2"
    ' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}

@test "validate_any returns success when at least one condition passes" {
    run bash -c '
        source "$1"
        false_cond() { return 1; }
        true_cond() { return 0; }
        false_cond; rc1=$?
        false_cond; rc2=$?
        true_cond; rc3=$?
        validate_any "$rc1" "$rc2" "$rc3"
    ' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_success
}

@test "validate_any returns failure when all conditions fail" {
    run bash -c '
        source "$1"
        false_cond() { return 1; }
        false_cond; rc1=$?
        false_cond; rc2=$?
        validate_any "$rc1" "$rc2"
    ' _ "$POWERKIT_ROOT/src/utils/validation.sh"
    assert_failure
}
