#!/usr/bin/env bash
# =============================================================================
# PowerKit BATS Test Runner
# Description: Runs all .bats test files under tests/ via bats-core
# Fails when bats or its helpers are unavailable.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v bats >/dev/null 2>&1; then
    echo "ERROR: bats (bats-core) is not installed." >&2
    echo "       Install it via 'brew install bats-core' or your package manager." >&2
    exit 1
fi

# Ensure submodule-based test helpers are available.
# Submodules checked out via 'git submodule update --init'.
HELPER_DIR="$SCRIPT_DIR/test_helper"
if [[ ! -f "$HELPER_DIR/bats-support/load.bash" ]] || [[ ! -f "$HELPER_DIR/bats-assert/load.bash" ]]; then
    echo "ERROR: bats-support / bats-assert not initialized in tests/test_helper/." >&2
    echo "       Run: git submodule update --init --recursive" >&2
    exit 1
fi

# Keep the suite list explicit so missing coverage cannot be hidden by a glob.
BATS_FILES=(
    "$SCRIPT_DIR/lib_platform.bats"
    "$SCRIPT_DIR/lib_strings.bats"
    "$SCRIPT_DIR/cache.bats"
    "$SCRIPT_DIR/docker.bats"
    "$SCRIPT_DIR/lifecycle.bats"
    "$SCRIPT_DIR/renderer.bats"
    "$SCRIPT_DIR/security.bats"
    "$SCRIPT_DIR/tmux_smoke.bats"
)

for test_file in "${BATS_FILES[@]}"; do
    [[ -f "$test_file" ]] || {
        echo "ERROR: Required Bats suite missing: $test_file" >&2
        exit 1
    }
done

exec bats "${BATS_FILES[@]}"
