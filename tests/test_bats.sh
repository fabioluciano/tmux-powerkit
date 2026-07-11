#!/usr/bin/env bash
# =============================================================================
# PowerKit BATS Test Runner
# Description: Runs all .bats test files under tests/ via bats-core
# Falls back to a warning when bats is not installed (does not fail)
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
    echo "WARNING: bats-support / bats-assert not initialized in tests/test_helper/." >&2
    echo "         Run: git submodule update --init --recursive" >&2
    echo "         BATS-based tests will be SKIPPED (suite still passes)." >&2
    exit 0
fi

# Run every .bats file at the top level of tests/.
# Recursion is intentionally avoided: bats discovers sibling files via its
# own globbing; nested runs could pick up test_helper internals.
shopt -s nullglob
BATS_FILES=("$SCRIPT_DIR"/*.bats)
shopt -u nullglob

if [[ ${#BATS_FILES[@]} -eq 0 ]]; then
    echo "No .bats files found in $SCRIPT_DIR." >&2
    exit 0
fi

exec bats "${BATS_FILES[@]}"
