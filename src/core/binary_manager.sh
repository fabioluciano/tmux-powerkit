#!/usr/bin/env bash
# =============================================================================
# PowerKit Core: Binary Manager
# Description: Manage macOS native binaries (download on-demand from releases)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "binary_manager" && return 0

. "${POWERKIT_ROOT}/src/core/cache.sh"
. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/utils/platform.sh"
. "${POWERKIT_ROOT}/src/utils/ui_backend.sh"

# =============================================================================
# Constants
# =============================================================================

POWERKIT_GITHUB_REPO="fabioluciano/tmux-powerkit"
_BINARY_DIR="${POWERKIT_ROOT}/bin"

# Track missing binaries during initialization
declare -ga _MISSING_BINARIES=()
declare -gA _MISSING_BINARY_PLUGINS=()

# User-private runtime dir for transient state. Using a fixed path under
# world-writable /tmp would allow other local users to pre-create/symlink
# these files (TOCTOU), including the popup script we execute.
_BINARY_RUNTIME_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit/runtime"

# File to persist missing binaries across subshells (stable name)
_MISSING_BINARIES_FILE="${_BINARY_RUNTIME_DIR}/missing_binaries"

# Ensure the runtime dir exists and is private to the user
_binary_runtime_init() {
    [[ -d "$_BINARY_RUNTIME_DIR" ]] && return 0
    mkdir -p "$_BINARY_RUNTIME_DIR" 2>/dev/null && chmod 700 "$_BINARY_RUNTIME_DIR"
}

# =============================================================================
# Internal Functions
# =============================================================================

# Check if binary exists and is executable
# Usage: binary_exists "binary_name"
binary_exists() {
    local binary="$1"
    [[ -x "${_BINARY_DIR}/${binary}" ]]
}

# Get architecture suffix for downloads
# Returns: darwin-arm64 or darwin-amd64
binary_get_arch_suffix() {
    local arch
    arch=$(get_arch)
    case "$arch" in
    arm64 | aarch64) echo "darwin-arm64" ;;
    x86_64 | amd64) echo "darwin-amd64" ;;
    *) return 1 ;;
    esac
}

# Get PowerKit version from GitHub API (cached for 1 hour)
_get_powerkit_version() {
    local cache_key="powerkit_latest_version"
    local cached

    # Check cache first (1 hour TTL)
    cached=$(cache_get "$cache_key" 3600)
    if [[ -n "$cached" ]]; then
        printf '%s' "$cached"
        return 0
    fi

    # Fetch from GitHub API with proper timeout to avoid hangs
    local version
    version=$(curl -fsSL --connect-timeout 5 --max-time 10 \
        "https://api.github.com/repos/${POWERKIT_GITHUB_REPO}/releases/latest" 2>/dev/null |
        grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/')

    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]]; then
        cache_set "$cache_key" "$version"
        printf '%s' "$version"
    else
        log_error "binary_manager" "Failed to fetch a valid release version from GitHub API"
        return 1
    fi
}

# Get download URL for binary
# Usage: binary_get_download_url "binary_name"
binary_get_download_url() {
    local binary="$1"
    local version arch_suffix
    version=$(_get_powerkit_version) || return 1
    arch_suffix=$(binary_get_arch_suffix) || return 1
    printf 'https://github.com/%s/releases/download/v%s/%s-%s' "$POWERKIT_GITHUB_REPO" "$version" "$binary" "$arch_suffix"
}

# Get checksum manifest URL for the selected macOS architecture.
binary_get_checksum_url() {
    local version arch_suffix
    version=$(_get_powerkit_version) || return 1
    arch_suffix=$(binary_get_arch_suffix) || return 1
    printf 'https://github.com/%s/releases/download/v%s/SHA256SUMS-%s.txt' "$POWERKIT_GITHUB_REPO" "$version" "$arch_suffix"
}

# Check cached user decision
# Usage: _binary_decision_get "binary_name"
_binary_decision_get() {
    local binary="$1"
    cache_get "binary_decision_${binary}" 86400 # 24h TTL
}

# Store user decision in cache
# Usage: _binary_decision_set "binary_name" "yes|no"
_binary_decision_set() {
    local binary="$1"
    local decision="$2"
    cache_set "binary_decision_${binary}" "$decision"
}

# Track a missing binary for batch prompt
# Usage: _track_missing_binary "binary_name" "plugin_name"
_track_missing_binary() {
    local binary="$1"
    local plugin="$2"

    # Avoid duplicates in memory
    local b
    for b in "${_MISSING_BINARIES[@]}"; do
        [[ "$b" == "$binary" ]] && return 0
    done

    _MISSING_BINARIES+=("$binary")
    _MISSING_BINARY_PLUGINS["$binary"]="$plugin"

    # Also write to file for persistence across subshells
    # Check if already in file
    if [[ -f "$_MISSING_BINARIES_FILE" ]] && grep -q "^${binary}:" "$_MISSING_BINARIES_FILE" 2>/dev/null; then
        return 0
    fi
    _binary_runtime_init
    echo "${binary}:${plugin}" >>"$_MISSING_BINARIES_FILE"

    log_debug "binary_manager" "Tracked missing binary: $binary for plugin $plugin"
}

# Get list of missing binaries (space-separated)
# Usage: binary_get_missing
binary_get_missing() {
    printf '%s\n' "${_MISSING_BINARIES[@]}"
}

# Check if there are missing binaries
# Usage: binary_has_missing
binary_has_missing() {
    [[ ${#_MISSING_BINARIES[@]} -gt 0 ]]
}

# Show combined popup for all missing binaries
# Usage: binary_prompt_missing
# Called after all plugins are initialized
binary_prompt_missing() {
    local pending_file="${_BINARY_RUNTIME_DIR}/binary_pending_all"

    # Check if popup is already pending
    if [[ -f "$pending_file" ]]; then
        return 0
    fi

    # Read from file (persisted across subshells)
    if [[ ! -f "$_MISSING_BINARIES_FILE" || ! -s "$_MISSING_BINARIES_FILE" ]]; then
        return 0
    fi

    # Build binary list from file
    local binary_list=""
    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        binary_list+="${line} "
        ((count++))
    done <"$_MISSING_BINARIES_FILE"
    binary_list="${binary_list% }" # Remove trailing space

    [[ $count -eq 0 ]] && return 0

    # Mark as pending
    _binary_runtime_init
    echo "1" >"$pending_file"

    log_info "binary_manager" "Prompting for ${count} missing binaries"

    # Write command to temp file for execution
    local cmd_file="${_BINARY_RUNTIME_DIR}/popup_cmd"
    cat >"$cmd_file" <<EOF
#!/usr/bin/env bash
tmux display-popup -E -w 60% -h 70% -T ' PowerKit - Binary Download ' \
    '${POWERKIT_ROOT}/bin/powerkit-binary-prompt' '${binary_list}'
rm -f '${pending_file}'
rm -f '${_MISSING_BINARIES_FILE}'
rm -f '${cmd_file}'
EOF
    chmod +x "$cmd_file"

    # Execute via tmux run-shell in background
    tmux run-shell -b "'$cmd_file'"
}

# Download and install binary
# Usage: binary_download "binary_name"
# Returns: 0 on success, 1 on failure
binary_download() {
    local binary="$1"
    local url checksum_url arch_suffix temp_file

    url=$(binary_get_download_url "$binary") || return 1
    checksum_url=$(binary_get_checksum_url) || return 1
    arch_suffix=$(binary_get_arch_suffix) || return 1
    temp_file=$(mktemp "${TMPDIR:-/tmp}/powerkit-binary.XXXXXX") || {
        log_error "binary_manager" "Failed to create temp file for ${binary}"
        return 1
    }

    log_info "binary_manager" "Downloading ${binary} from ${url}"

    # Download using curl (available on macOS)
    if ! curl -fsSL "$url" -o "$temp_file" 2>/dev/null; then
        log_error "binary_manager" "Failed to download ${binary} from ${url}"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi

    # Verify we got an executable for the requested architecture (not HTML).
    local file_info expected_arch
    file_info=$(file "$temp_file" 2>/dev/null)
    expected_arch="${arch_suffix##*-}"
    [[ "$expected_arch" == "amd64" ]] && expected_arch="x86_64"
    if [[ "$file_info" != *"Mach-O"* || "$file_info" != *"$expected_arch"* ]]; then
        log_error "binary_manager" "Downloaded file is not a valid macOS binary"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi

    # Checksum manifests are release assets and are mandatory for installation.
    local expected_sha actual_sha
    expected_sha=$(curl -fsSL --connect-timeout 5 --max-time 10 "$checksum_url" 2>/dev/null | awk -v name="${binary}-${arch_suffix}" '$2 == name { print $1; exit }')
    if [[ ! "$expected_sha" =~ ^[0-9a-fA-F]{64}$ ]]; then
        log_error "binary_manager" "Missing checksum for ${binary} in ${checksum_url}"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi

    actual_sha=$(shasum -a 256 "$temp_file" 2>/dev/null | awk '{print $1}')
    if [[ "$actual_sha" != "$expected_sha" ]]; then
        log_error "binary_manager" "Checksum mismatch for ${binary}"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
    log_debug "binary_manager" "Checksum verified for ${binary}"

    # Make executable and move to bin dir
    chmod +x "$temp_file"
    mkdir -p "$_BINARY_DIR"
    mv "$temp_file" "${_BINARY_DIR}/${binary}"

    log_info "binary_manager" "Installed ${binary} to ${_BINARY_DIR}"
    toast "Binary ${binary} installed successfully" "success"
    return 0
}

# =============================================================================
# Public API
# =============================================================================

# Ensure macOS binary exists, prompt user for download if needed
# Usage: require_macos_binary "binary_name" "plugin_name"
# Returns: 0 if binary is available, 1 if not (plugin should be inactive)
require_macos_binary() {
    local binary="$1"
    local plugin="$2"

    # Not macOS? Binary not needed, return success
    is_macos || return 0

    # Binary already exists? OK
    binary_exists "$binary" && return 0

    # Check cached decision
    local decision
    decision=$(_binary_decision_get "$binary")

    case "$decision" in
    yes)
        # User said yes before but binary is missing - try download again
        if binary_download "$binary"; then
            return 0
        fi
        return 1
        ;;
    no)
        # User declined before - skip silently
        log_debug "binary_manager" "Skipping ${binary} (user declined)"
        return 1
        ;;
    esac

    # No cached decision - track for batch prompt later
    # Decision will be saved by powerkit-binary-prompt after user interaction
    _track_missing_binary "$binary" "$plugin"
    return 1
}

# Clear cached decision for a binary (allow re-prompting)
# Usage: binary_clear_decision "binary_name"
binary_clear_decision() {
    local binary="$1"
    cache_clear "binary_decision_${binary}"
}

# Clear all binary decisions
binary_clear_all_decisions() {
    cache_clear_prefix "binary_decision_"
}
