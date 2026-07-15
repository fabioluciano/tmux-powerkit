#!/usr/bin/env bash
# =============================================================================
# PowerKit Utility: Time/Date Helpers
# Description: Reusable time/date utilities (ISO 8601, Unix epoch)
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "time" && return 0

# Print ISO-8601 Zulu timestamp `days` days in the past (or "now" if 0).
# Usage: time_iso_start [days_in_past]
time_iso_start() {
    local days="${1:-0}"
    local ts
    if [[ "$days" == "0" ]]; then
        ts="$EPOCHSECONDS"
    else
        ts=$((EPOCHSECONDS - days * 86400))
    fi
    printf '%(%Y-%m-%dT%H:%M:%SZ)T' "$ts"
}

# Print ISO-8601 Zulu timestamp for "now".
time_iso_now() { printf '%(%Y-%m-%dT%H:%M:%SZ)T' "$EPOCHSECONDS"; }

# Print Unix epoch seconds `days` days in the past.
# Usage: time_epoch_start [days_in_past]
time_epoch_start() {
    local days="${1:-0}"
    if [[ "$days" == "0" ]]; then
        printf '%d' "$EPOCHSECONDS"
    else
        printf '%d' $((EPOCHSECONDS - days * 86400))
    fi
}

# Print Unix epoch seconds for "now".
time_epoch_now() { printf '%d' "$EPOCHSECONDS"; }

log_debug "time" "Time utilities loaded"
