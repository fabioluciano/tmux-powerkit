#!/usr/bin/env bash
# =============================================================================
# PowerKit Utils: Filesystem
# Description: File and directory utilities
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_filesystem" && return 0

. "${POWERKIT_ROOT}/src/utils/platform.sh"

# =============================================================================
# File Information
# =============================================================================

# Get file modification time in seconds since epoch
# Usage: get_file_mtime "/path/to/file"
get_file_mtime() {
    local file="$1"

    if [[ ! -e "$file" ]]; then
        echo 0
        return 1
    fi

    if is_macos; then
        stat -f%m "$file" 2>/dev/null || echo 0
    else
        stat -c%Y "$file" 2>/dev/null || echo 0
    fi
}

# Get file size in bytes
# Usage: get_file_size "/path/to/file"
get_file_size() {
    local file="$1"

    if [[ ! -e "$file" ]]; then
        echo 0
        return 1
    fi

    if is_macos; then
        stat -f%z "$file" 2>/dev/null || echo 0
    else
        stat -c%s "$file" 2>/dev/null || echo 0
    fi
}

# Check if file exists and is readable
# Usage: file_exists "/path/to/file" && echo "exists"
file_exists() {
    [[ -f "$1" && -r "$1" ]]
}

# Check if directory exists
# Usage: dir_exists "/path/to/dir" && echo "exists"
dir_exists() {
    [[ -d "$1" ]]
}

# =============================================================================
# File Age
# =============================================================================

# Get file age in seconds
# Usage: get_file_age "/path/to/file"
get_file_age() {
    local file="$1"
    local mtime now

    mtime=$(get_file_mtime "$file")
    [[ "$mtime" == "0" ]] && { echo -1; return 1; }

    now=$(date +%s)
    echo $((now - mtime))
}

# Check if file is older than N seconds
# Usage: is_file_older_than "/path/to/file" 300 && echo "older than 5 min"
is_file_older_than() {
    local file="$1"
    local seconds="$2"
    local age

    age=$(get_file_age "$file")
    [[ "$age" == "-1" ]] && return 1

    (( age > seconds ))
}

# Check if file is newer than N seconds
# Usage: is_file_newer_than "/path/to/file" 60 && echo "newer than 1 min"
is_file_newer_than() {
    local file="$1"
    local seconds="$2"
    local age

    age=$(get_file_age "$file")
    [[ "$age" == "-1" ]] && return 1

    (( age < seconds ))
}

# =============================================================================
# Path Utilities
# =============================================================================

# Expand tilde and common environment variables in path (safe, no eval)
# Usage: expand_path "~/Documents"
# Supports: ~ (tilde), $HOME, $USER, $XDG_CONFIG_HOME, $XDG_CACHE_HOME, $XDG_DATA_HOME
expand_path() {
    local path="$1"

    # Handle escaped tilde
    path="${path//\\~/~}"

    # Expand tilde
    if [[ "$path" == "~"* ]]; then
        path="${HOME}${path:1}"
    fi

    # Expand common environment variables (safe substitution, no eval)
    # Only expand variables that are commonly used in paths
    path="${path//\$HOME/$HOME}"
    path="${path//\${HOME\}/$HOME}"
    path="${path//\$USER/${USER:-}}"
    path="${path//\${USER\}/${USER:-}}"
    path="${path//\$XDG_CONFIG_HOME/${XDG_CONFIG_HOME:-$HOME/.config}}"
    path="${path//\${XDG_CONFIG_HOME\}/${XDG_CONFIG_HOME:-$HOME/.config}}"
    path="${path//\$XDG_CACHE_HOME/${XDG_CACHE_HOME:-$HOME/.cache}}"
    path="${path//\${XDG_CACHE_HOME\}/${XDG_CACHE_HOME:-$HOME/.cache}}"
    path="${path//\$XDG_DATA_HOME/${XDG_DATA_HOME:-$HOME/.local/share}}"
    path="${path//\${XDG_DATA_HOME\}/${XDG_DATA_HOME:-$HOME/.local/share}}"

    printf '%s' "$path"
}

# Get absolute path
# Usage: get_absolute_path "relative/path"
get_absolute_path() {
    local path="$1"

    path=$(expand_path "$path")

    if [[ -d "$path" ]]; then
        (cd "$path" && pwd)
    elif [[ -f "$path" ]]; then
        local dir file
        dir=$(dirname "$path")
        file=$(basename "$path")
        printf '%s/%s' "$(cd "$dir" && pwd)" "$file"
    else
        printf '%s' "$path"
    fi
}

# Get directory containing a file
# Usage: get_parent_dir "/path/to/file"
get_parent_dir() {
    dirname "$1"
}

# Get filename without directory
# Usage: get_filename "/path/to/file.txt"
get_filename() {
    basename "$1"
}

# Get filename without extension
# Usage: get_basename "/path/to/file.txt"  # Returns "file"
get_basename() {
    local filename
    filename=$(basename "$1")
    printf '%s' "${filename%.*}"
}

# Get file extension
# Usage: get_extension "/path/to/file.txt"  # Returns "txt"
get_extension() {
    local filename
    filename=$(basename "$1")
    if [[ "$filename" == *.* ]]; then
        printf '%s' "${filename##*.}"
    fi
}

# =============================================================================
# Directory Operations
# =============================================================================

# Ensure directory exists, create if not
# Usage: ensure_dir "/path/to/dir"
ensure_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

# Create temporary directory
# Usage: temp_dir=$(make_temp_dir "prefix")
make_temp_dir() {
    local prefix="${1:-powerkit}"
    mktemp -d -t "${prefix}.XXXXXX"
}

# Create temporary file
# Usage: temp_file=$(make_temp_file "prefix")
make_temp_file() {
    local prefix="${1:-powerkit}"
    mktemp -t "${prefix}.XXXXXX"
}

# =============================================================================
# File Content
# =============================================================================

# Read first line of file
# Usage: first_line=$(read_first_line "/path/to/file")
read_first_line() {
    local file="$1"
    [[ -f "$file" ]] && head -n1 "$file" 2>/dev/null
}

# Read specific line from file
# Usage: line=$(read_line "/path/to/file" 5)
read_line() {
    local file="$1"
    local line_num="$2"
    [[ -f "$file" ]] && sed -n "${line_num}p" "$file" 2>/dev/null
}

# Count lines in file
# Usage: count=$(count_lines "/path/to/file")
count_lines() {
    local file="$1"
    [[ -f "$file" ]] && wc -l < "$file" 2>/dev/null | tr -d ' '
}

