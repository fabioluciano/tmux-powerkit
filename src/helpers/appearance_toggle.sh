#!/usr/bin/env bash
# =============================================================================
# Helper: appearance_toggle
# Description: Cycles macOS appearance mode: auto → dark → light → auto
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/utils/platform.sh"

macos_cycle_appearance

cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/tmux-powerkit/data"
rm -f "${cache_dir}"/rendered_right__* 2>/dev/null || true
bash "${POWERKIT_ROOT}/tmux-powerkit.tmux" 2>/dev/null || true
