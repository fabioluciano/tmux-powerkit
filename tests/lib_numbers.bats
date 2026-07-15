#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/utils/numbers.sh
# Covers: extract_numeric, extract_decimal, extract_all_numbers,
#         format_number, format_bytes, format_metric, format_percent,
#         pad_number, clamp, in_range, validate_number,
#         calc_percent, calc_percent_decimal, round, floor, ceiling,
#         evaluate_condition, format_uptime_seconds, format_speed
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Numeric Extraction
# =============================================================================

@test "extract_numeric returns first integer from string with numbers" {
    run bash -c 'source "$1" && extract_numeric "CPU: 45%"' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "45"
}

@test "extract_numeric returns 0 when no digits are found" {
    run bash -c 'source "$1" && extract_numeric "no numbers"' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "0"
}

@test "extract_numeric returns first number from mixed content" {
    run bash -c 'source "$1" && extract_numeric "test123abc456"' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "123"
}

@test "extract_decimal returns decimal value from string" {
    run bash -c 'source "$1" && extract_decimal "Load: 1.25"' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1.25"
}

@test "extract_decimal returns integer when no decimal point present" {
    run bash -c 'source "$1" && extract_decimal "value is 42"' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "42"
}

@test "extract_decimal returns 0 when no numbers found" {
    run bash -c 'source "$1" && extract_decimal "nothing"' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "0"
}

@test "extract_all_numbers returns space-separated numbers" {
    run bash -c 'source "$1" && extract_all_numbers "1 2 3"' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1 2 3"
}

@test "extract_all_numbers extracts numbers from mixed content" {
    run bash -c 'source "$1" && extract_all_numbers "there are 1 or 2 items"' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1 2"
}

# =============================================================================
# Byte/Metric Formatting
# =============================================================================

@test "format_bytes returns 0B for zero bytes" {
    run bash -c 'source "$1" && format_bytes 0' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "0B"
}

@test "format_bytes returns 1.0K for 1024 bytes" {
    run bash -c 'source "$1" && format_bytes 1024' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1.0K"
}

@test "format_bytes returns 1.0M for 1048576 bytes" {
    run bash -c 'source "$1" && format_bytes 1048576' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1.0M"
}

@test "format_bytes returns 1.0G for 1073741824 bytes" {
    run bash -c 'source "$1" && format_bytes 1073741824' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1.0G"
}

@test "format_metric returns value with SI suffix" {
    run bash -c 'source "$1" && format_metric 1500 1' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1.5K"
}

@test "format_metric returns raw value when under 1000" {
    run bash -c 'source "$1" && format_metric 500 1' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "500"
}

@test "format_metric handles millions" {
    run bash -c 'source "$1" && format_metric 1500000 1' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1.5M"
}

# =============================================================================
# Percentage Formatting
# =============================================================================

@test "format_percent formats with specified precision" {
    run bash -c 'source "$1" && format_percent 45.678 1' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "45.7%"
}

@test "format_percent defaults to 0 precision" {
    run bash -c 'source "$1" && format_percent 50' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "50%"
}

# =============================================================================
# Padding
# =============================================================================

@test "pad_number pads with leading zeros" {
    run bash -c 'source "$1" && pad_number 5 3' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "005"
}

@test "pad_number defaults to width 2" {
    run bash -c 'source "$1" && pad_number 7' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "07"
}

# =============================================================================
# Range and Validation
# =============================================================================

@test "clamp caps value at maximum" {
    run bash -c 'source "$1" && clamp 150 0 100' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "100"
}

@test "clamp floors value at minimum" {
    run bash -c 'source "$1" && clamp -10 0 100' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "0"
}

@test "clamp returns value unchanged when within range" {
    run bash -c 'source "$1" && clamp 50 0 100' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "50"
}

@test "in_range returns success when value is within range" {
    run bash -c 'source "$1" && in_range 50 0 100' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
}

@test "in_range returns failure when value exceeds maximum" {
    run bash -c 'source "$1" && in_range 150 0 100' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_failure
}

@test "in_range returns success at lower boundary" {
    run bash -c 'source "$1" && in_range 0 0 100' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
}

@test "in_range returns success at upper boundary" {
    run bash -c 'source "$1" && in_range 100 0 100' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
}

@test "validate_number returns default when input is not numeric" {
    run bash -c 'source "$1" && validate_number "abc" 10' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "10"
}

@test "validate_number returns the value when it is numeric" {
    run bash -c 'source "$1" && validate_number "42" 10' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "42"
}

@test "validate_number accepts negative numbers" {
    run bash -c 'source "$1" && validate_number "-5" 0' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "-5"
}

# =============================================================================
# Calculations
# =============================================================================

@test "calc_percent computes correct percentage" {
    run bash -c 'source "$1" && calc_percent 25 100' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "25"
}

@test "calc_percent returns 0 for zero numerator" {
    run bash -c 'source "$1" && calc_percent 0 100' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "0"
}

@test "calc_percent guards against division by zero" {
    run bash -c 'source "$1" && calc_percent 100 0' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "0"
}

@test "calc_percent_decimal formats with specified precision" {
    run bash -c 'source "$1" && calc_percent_decimal 25 100 2' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "25.00"
}

@test "calc_percent_decimal guards against division by zero" {
    run bash -c 'source "$1" && calc_percent_decimal 50 0 1' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "0.0"
}

# =============================================================================
# Rounding
# =============================================================================

@test "round rounds up to nearest integer" {
    run bash -c 'source "$1" && round 3.7' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "4"
}

@test "round rounds down to nearest integer" {
    run bash -c 'source "$1" && round 3.2' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "3"
}

@test "floor truncates toward zero" {
    run bash -c 'source "$1" && floor 3.7' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "3"
}

@test "ceiling rounds up to nearest integer" {
    run bash -c 'source "$1" && ceiling 3.2' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "4"
}

@test "ceiling returns same value for integer input" {
    run bash -c 'source "$1" && ceiling 4' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "4"
}

# =============================================================================
# Condition Evaluation
# =============================================================================

@test "evaluate_condition greater than returns success" {
    run bash -c 'source "$1" && evaluate_condition 5 ">" 3' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
}

@test "evaluate_condition less than returns failure" {
    run bash -c 'source "$1" && evaluate_condition 5 "<" 3' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_failure
}

@test "evaluate_condition equality with ==" {
    run bash -c 'source "$1" && evaluate_condition 5 "==" 5' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
}

@test "evaluate_condition inequality with !=" {
    run bash -c 'source "$1" && evaluate_condition 5 "!=" 3' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
}

@test "evaluate_condition supports gt alias" {
    run bash -c 'source "$1" && evaluate_condition 5 "gt" 3' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
}

@test "evaluate_condition supports lt alias" {
    run bash -c 'source "$1" && evaluate_condition 3 "lt" 5' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
}

# =============================================================================
# Uptime Formatting
# =============================================================================

@test "format_uptime_seconds formats days and hours" {
    run bash -c 'source "$1" && format_uptime_seconds 90000' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1d 1h"
}

@test "format_uptime_seconds formats hours and minutes" {
    run bash -c 'source "$1" && format_uptime_seconds 3661' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1h 1m"
}

@test "format_uptime_seconds shows only minutes for sub-hour" {
    run bash -c 'source "$1" && format_uptime_seconds 59' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "0m"
}

@test "format_uptime_seconds formats exactly one day" {
    run bash -c 'source "$1" && format_uptime_seconds 86400' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1d 0h"
}

# =============================================================================
# Speed Formatting
# =============================================================================

@test "format_speed returns KB when under 1024" {
    run bash -c 'source "$1" && format_speed 512' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "512K"
}

@test "format_speed returns MB when 1024 KB or more" {
    run bash -c 'source "$1" && format_speed 1536 1' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "1.5M"
}

@test "format_speed handles zero input" {
    run bash -c 'source "$1" && format_speed 0' _ "$POWERKIT_ROOT/src/utils/numbers.sh"
    assert_success
    assert_output "0K"
}
