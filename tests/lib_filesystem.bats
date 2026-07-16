#!/usr/bin/env bats
# =============================================================================
# BATS tests for src/utils/filesystem.sh
# Covers: file_exists, dir_exists, get_file_mtime, get_file_size,
#         get_file_age, is_file_older_than, is_file_newer_than,
#         expand_path, get_absolute_path, get_parent_dir, get_filename,
#         get_basename, get_extension, ensure_dir, make_temp_dir,
#         make_temp_file, count_lines, read_line, read_first_line
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# file_exists
# =============================================================================

@test "file_exists returns 0 for an existing regular file" {
    local tmpfile="$BATS_TEST_TMPDIR/testfile.txt"
    touch "$tmpfile"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        file_exists "'"$tmpfile"'"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "file_exists returns 1 for a non-existent path" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        file_exists "'"$BATS_TEST_TMPDIR"'/nonexistent_12345"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# dir_exists
# =============================================================================

@test "dir_exists returns 0 for an existing directory" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        dir_exists "'"$BATS_TEST_TMPDIR"'"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "dir_exists returns 1 for a non-existent directory" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        dir_exists "'"$BATS_TEST_TMPDIR"'/nonexistent_dir_xyz"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# get_file_mtime
# =============================================================================

@test "get_file_mtime returns a positive number for an existing file" {
    local tmpfile="$BATS_TEST_TMPDIR/mtime_test"
    touch "$tmpfile"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_file_mtime "'"$tmpfile"'"
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" =~ ^[0-9]+$ ]] && (( output > 1000000000 ))
}

@test "get_file_mtime returns 0 and status 1 for non-existent file" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_file_mtime "'"$BATS_TEST_TMPDIR"'/no_such_file"
    ' _ "$POWERKIT_ROOT"
    assert_failure
    assert_output "0"
}

# =============================================================================
# get_file_size
# =============================================================================

@test "get_file_size returns correct byte count" {
    local tmpfile="$BATS_TEST_TMPDIR/size_test"
    printf '12345' > "$tmpfile"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_file_size "'"$tmpfile"'"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "5"
}

@test "get_file_size returns 0 and status 1 for non-existent file" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_file_size "'"$BATS_TEST_TMPDIR"'/no_such_file"
    ' _ "$POWERKIT_ROOT"
    assert_failure
    assert_output "0"
}

# =============================================================================
# get_file_age
# =============================================================================

@test "get_file_age returns a non-negative number for existing file" {
    local tmpfile="$BATS_TEST_TMPDIR/age_test"
    touch "$tmpfile"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_file_age "'"$tmpfile"'"
    ' _ "$POWERKIT_ROOT"
    assert_success
    [[ "$output" =~ ^[0-9]+$ ]]
}

# =============================================================================
# ensure_dir
# =============================================================================

@test "ensure_dir creates a directory that does not exist" {
    local newdir="$BATS_TEST_TMPDIR/created_by_ensure_dir"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        ensure_dir "'"$newdir"'" && [[ -d "'"$newdir"'" ]]
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "ensure_dir succeeds when directory already exists" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        ensure_dir "'"$BATS_TEST_TMPDIR"'"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

# =============================================================================
# expand_path
# =============================================================================

@test "expand_path expands tilde to home directory" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        expand_path "~"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "$HOME"
}

@test "expand_path expands tilde prefix with subpath" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        expand_path "~/Documents"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "${HOME}/Documents"
}

@test "expand_path returns absolute path unchanged" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        expand_path "/tmp/test"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "/tmp/test"
}

@test "expand_path expands \$HOME variable" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        expand_path "\$HOME/.config"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "${HOME}/.config"
}

# =============================================================================
# get_absolute_path
# =============================================================================

@test "get_absolute_path resolves relative path to absolute for directory" {
    local tmpdir="$BATS_TEST_TMPDIR/subdir"
    mkdir -p "$tmpdir"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        cd "'"$tmpdir"'" && get_absolute_path "."
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "$tmpdir"
}

# =============================================================================
# get_parent_dir
# =============================================================================

@test "get_parent_dir returns directory component" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_parent_dir "path/to/file.txt"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "path/to"
}

# =============================================================================
# get_filename
# =============================================================================

@test "get_filename returns the base filename" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_filename "path/to/file.txt"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "file.txt"
}

# =============================================================================
# get_basename
# =============================================================================

@test "get_basename returns filename without extension" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_basename "path/to/file.txt"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "file"
}

@test "get_basename returns full name when no extension present" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_basename "path/to/Makefile"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "Makefile"
}

# =============================================================================
# get_extension
# =============================================================================

@test "get_extension returns extension" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_extension "path/to/file.txt"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "txt"
}

@test "get_extension returns empty for file without extension" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        get_extension "path/to/Makefile"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

# =============================================================================
# make_temp_dir
# =============================================================================

@test "make_temp_dir creates a temporary directory that exists" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        tmpdir=$(make_temp_dir)
        [[ -d "$tmpdir" ]] && printf "%s" "$tmpdir"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
    local created_dir="$output"
    [[ -d "$created_dir" ]]
}

# =============================================================================
# make_temp_file
# =============================================================================

@test "make_temp_file creates a temporary file" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        tmpfile=$(make_temp_file)
        [[ -f "$tmpfile" ]] && printf "%s" "$tmpfile"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output ""
}

# =============================================================================
# count_lines
# =============================================================================

@test "count_lines returns correct line count" {
    local tmpfile="$BATS_TEST_TMPDIR/lines.txt"
    printf 'line1\nline2\nline3\n' > "$tmpfile"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        count_lines "'"$tmpfile"'"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "3"
}

@test "count_lines returns empty and status 1 for non-existent file" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        count_lines "'"$BATS_TEST_TMPDIR"'/no_file"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# read_line
# =============================================================================

@test "read_line returns specific line from file" {
    local tmpfile="$BATS_TEST_TMPDIR/lines.txt"
    printf 'alpha\nbeta\ngamma\n' > "$tmpfile"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        read_line "'"$tmpfile"'" 2
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "beta"
}

@test "read_line returns empty for out-of-bounds line number" {
    local tmpfile="$BATS_TEST_TMPDIR/lines.txt"
    printf 'alpha\n' > "$tmpfile"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        read_line "'"$tmpfile"'" 99
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

# =============================================================================
# read_first_line
# =============================================================================

@test "read_first_line returns first line of file" {
    local tmpfile="$BATS_TEST_TMPDIR/lines.txt"
    printf 'first\nsecond\nthird\n' > "$tmpfile"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        read_first_line "'"$tmpfile"'"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "first"
}

# =============================================================================
# is_file_older_than
# =============================================================================

@test "is_file_older_than returns 0 for a file older than threshold" {
    local tmpfile="$BATS_TEST_TMPDIR/old_file"
    touch -t 200001010000 "$tmpfile"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        is_file_older_than "'"$tmpfile"'" 1
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_file_older_than returns 1 for non-existent file" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        is_file_older_than "'"$BATS_TEST_TMPDIR"'/no_file" 10
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# =============================================================================
# is_file_newer_than
# =============================================================================

@test "is_file_newer_than returns 0 for a recently created file" {
    local tmpfile="$BATS_TEST_TMPDIR/new_file"
    touch "$tmpfile"

    run bash -c '
        source "$1/src/utils/filesystem.sh"
        is_file_newer_than "'"$tmpfile"'" 3600
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "is_file_newer_than returns 1 for non-existent file" {
    run bash -c '
        source "$1/src/utils/filesystem.sh"
        is_file_newer_than "'"$BATS_TEST_TMPDIR"'/no_file" 10
    ' _ "$POWERKIT_ROOT"
    assert_failure
}
