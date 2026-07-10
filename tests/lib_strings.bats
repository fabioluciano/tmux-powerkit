#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/utils/strings.sh
# Covers: trim, truncate_text, truncate_words, join_with_separator,
#         case conversion, search/replace, contains, starts_with, ends_with
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# trim / trim_left / trim_right
# =============================================================================

@test "trim removes leading and trailing whitespace" {
    run bash -c 'source "$1" && trim "  hello  "' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "hello"
}

@test "trim leaves strings without whitespace unchanged" {
    run bash -c 'source "$1" && trim "hello"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "hello"
}

@test "trim returns empty for whitespace-only input" {
    run bash -c 'source "$1" && trim "   "' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output ""
}

@test "trim_left only strips leading whitespace" {
    run bash -c 'source "$1" && trim_left "  hello  "' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "hello  "
}

@test "trim_right only strips trailing whitespace" {
    run bash -c 'source "$1" && trim_right "  hello  "' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "  hello"
}

# =============================================================================
# collapse_spaces
# =============================================================================

@test "collapse_spaces collapses multiple spaces into one" {
    run bash -c 'source "$1" && collapse_spaces "hello    world"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "hello world"
}

@test "collapse_spaces leaves single spaces unchanged" {
    run bash -c 'source "$1" && collapse_spaces "a b c"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "a b c"
}

# =============================================================================
# Case conversion
# =============================================================================

@test "to_lower converts uppercase to lowercase" {
    run bash -c 'source "$1" && to_lower "HELLO"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "hello"
}

@test "to_upper converts lowercase to uppercase" {
    run bash -c 'source "$1" && to_upper "hello"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "HELLO"
}

@test "capitalize uppercases the first character" {
    # Note: current implementation uses `read -r first rest` which drops internal
    # whitespace (read's last-field rule). Documented behavior verified here.
    run bash -c 'source "$1" && capitalize "hello"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "Hello"
}

# =============================================================================
# Truncation
# =============================================================================

@test "truncate_text returns text unchanged when shorter than max_len" {
    run bash -c 'source "$1" && truncate_text "hi" 10' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "hi"
}

@test "truncate_text cuts at max_len when text is longer" {
    run bash -c 'source "$1" && truncate_text "Hello World" 5' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "Hello"
}

@test "truncate_text appends ellipsis when provided" {
    run bash -c 'source "$1" && truncate_text "Hello World" 5 "..."' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "Hello..."
}

@test "truncate_text returns full text when max_len is zero or negative" {
    run bash -c 'source "$1" && truncate_text "hello" 0' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "hello"
}

@test "truncate_words cuts at word boundary, not mid-word" {
    run bash -c 'source "$1" && truncate_words "Hello World Example" 12 "..."' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "Hello..."
}

@test "truncate_words returns text unchanged when shorter than max_len" {
    run bash -c 'source "$1" && truncate_words "Hello" 20' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "Hello"
}

# =============================================================================
# Joining
# =============================================================================

@test "join_with_separator joins multiple items with the separator" {
    run bash -c 'source "$1" && join_with_separator " | " "a" "b" "c"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "a | b | c"
}

@test "join_with_separator with a single item returns it unchanged" {
    run bash -c 'source "$1" && join_with_separator ", " "only"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "only"
}

# =============================================================================
# Search
# =============================================================================

@test "contains returns success when substring is present" {
    run bash -c 'source "$1" && contains "hello world" "world"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
}

@test "contains returns failure when substring is absent" {
    run bash -c 'source "$1" && contains "hello world" "xyz"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_failure
}

@test "starts_with matches only the prefix" {
    run bash -c 'source "$1" && starts_with "hello" "he"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success

    run bash -c 'source "$1" && starts_with "hello" "lo"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_failure
}

@test "ends_with matches only the suffix" {
    run bash -c 'source "$1" && ends_with "hello" "lo"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success

    run bash -c 'source "$1" && ends_with "hello" "he"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_failure
}

@test "replace_first replaces only the first occurrence" {
    run bash -c 'source "$1" && replace_first "foo foo foo" "foo" "bar"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "bar foo foo"
}

@test "replace_all replaces every occurrence" {
    run bash -c 'source "$1" && replace_all "foo foo foo" "foo" "bar"' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "bar bar bar"
}

# =============================================================================
# format_timer
# =============================================================================

@test "format_timer pads minutes and seconds to two digits" {
    run bash -c 'source "$1" && format_timer 125' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "02:05"
}

@test "format_timer allows minutes >= 60" {
    run bash -c 'source "$1" && format_timer 3661' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "61:01"
}

@test "format_timer formats zero correctly" {
    run bash -c 'source "$1" && format_timer 0' _ "$POWERKIT_ROOT/src/utils/strings.sh"
    assert_success
    assert_output "00:00"
}