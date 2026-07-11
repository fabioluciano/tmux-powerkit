#!/usr/bin/env bash
if (( BASH_VERSINFO[0] < 5 )); then
    printf 'PowerKit requires Bash 5+, you have %s\n' "$BASH_VERSION" >&2
    exit 1
fi
# =============================================================================
# PowerKit - tmux Status Bar Framework
# TPM Entry Point
# =============================================================================

# Note: Don't use 'set -e' as some functions return non-zero on cache miss
set -uo pipefail

# Get the plugin directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export POWERKIT_ROOT="$CURRENT_DIR"

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    # Source bootstrap
    . "${POWERKIT_ROOT}/src/core/bootstrap.sh"

    # Initialize PowerKit
    powerkit_bootstrap

    # Run renderer
    . "${POWERKIT_ROOT}/src/renderer/renderer.sh"
    run_powerkit
}

# Run main
main
