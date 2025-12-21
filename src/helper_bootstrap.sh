#!/usr/bin/env bash
# =============================================================================
# Helper Bootstrap
# =============================================================================
# Single-source file that loads all common dependencies for helpers.
# This eliminates the need for each helper to individually source multiple files.
#
# Usage in helpers:
#   CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   ROOT_DIR="$CURRENT_DIR/.."
#   . "$ROOT_DIR/helper_bootstrap.sh"
#
# This file loads:
#   - init.sh        (loads all core modules in correct order)
#
# All files have source guards, so multiple includes are safe and fast.
# =============================================================================

# Source guard
if [[ -n "${_HELPER_BOOTSTRAP_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_HELPER_BOOTSTRAP_LOADED=1

# Determine script directory
_HELPER_BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load core dependencies (defaults, utils, cache)
# shellcheck source=src/defaults.sh
. "$_HELPER_BOOTSTRAP_DIR/defaults.sh"
# shellcheck source=src/utils.sh
. "$_HELPER_BOOTSTRAP_DIR/utils.sh"
# shellcheck source=src/cache.sh
. "$_HELPER_BOOTSTRAP_DIR/cache.sh"
# shellcheck source=src/plugin_helpers.sh
. "$_HELPER_BOOTSTRAP_DIR/plugin_helpers.sh"

# Export cache directory for helpers
export POWERKIT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit"

# Ensure cache directory exists
[[ ! -d "$POWERKIT_CACHE_DIR" ]] && mkdir -p "$POWERKIT_CACHE_DIR" 2>/dev/null || true
