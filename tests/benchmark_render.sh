#!/usr/bin/env bash
# =============================================================================
# PowerKit: Render Cycle Benchmark
# Description: Measures wall-clock time of N consecutive powerkit-render
#              invocations to validate Sprint 1/2 performance gains.
#
# Usage:
#   tests/benchmark_render.sh                 # default 100 cycles, side=right
#   tests/benchmark_render.sh --cycles 500   # 500 cycles
#   tests/benchmark_render.sh --side left    # render status-left
#   tests/benchmark_render.sh --quiet        # only summary line
#
# Output (default):
#   - mean / median / p95 / min / max in ms
#   - cycles-per-second
#   - optional comparison vs baseline (tests/fixtures/baseline.txt)
#
# Environment:
#   POWERKIT_ROOT must point to the plugin checkout (auto-detected).
#   BASH must be 5.1+ (validated up front).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Require Bash 5.2+
if ((BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 2))); then
    printf 'benchmark_render: Bash 5.2+ required, found %s\n' "$BASH_VERSION" >&2
    exit 1
fi

# Defaults
cycles=100
side="right"
quiet=0
baseline=""

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
    --cycles)
        cycles="$2"
        shift 2
        ;;
    --side)
        side="$2"
        shift 2
        ;;
    --quiet)
        quiet=1
        shift
        ;;
    --baseline)
        baseline="$2"
        shift 2
        ;;
    -h | --help)
        cat <<'EOF'
Usage: tests/benchmark_render.sh [--cycles N] [--side left|right] [--quiet] [--baseline FILE]

Measures powerkit-render wall-clock time over N cycles.

Options:
  --cycles N        Number of render invocations (default 100)
  --side S          Render side: right | left (default right)
  --quiet           Print only the summary line (mean, median, p95)
  --baseline FILE   Compare against a baseline mean (ms) and report delta
EOF
        exit 0
        ;;
    *)
        printf 'unknown arg: %s\n' "$1" >&2
        exit 1
        ;;
    esac
done

if [[ ! -x "$POWERKIT_ROOT/bin/powerkit-render" ]]; then
    printf 'benchmark_render: powerkit-render not found at %s/bin/powerkit-render\n' "$POWERKIT_ROOT" >&2
    exit 1
fi

if ((quiet == 0)); then
    printf 'PowerKit Render Benchmark\n'
    printf '==========================\n'
    printf 'POWERKIT_ROOT: %s\n' "$POWERKIT_ROOT"
    printf 'Bash:          %s\n' "$BASH_VERSION"
    printf 'Cycles:        %d\n' "$cycles"
    printf 'Side:          %s\n' "$side"
    printf '\n'
fi

# Measure cycles via EPOCHREALTIME (microsecond precision; bash 5.0+).
declare -a timings_ms=()

# Warmup: 3 invocations to amortize first-run cost (cache prime).
for _ in 1 2 3; do
    "$POWERKIT_ROOT/bin/powerkit-render" "$side" >/dev/null 2>&1 || true
done

start_epoch=$EPOCHSECONDS
for ((i = 0; i < cycles; i++)); do
    t0=$EPOCHREALTIME
    "$POWERKIT_ROOT/bin/powerkit-render" "$side" >/dev/null 2>&1 || true
    t1=$EPOCHREALTIME
    # EPOCHREALTIME is "seconds.microseconds"; convert to integer ms.
    diff_s=$((${t1%%.*} - ${t0%%.*}))
    diff_us="${t1#*.}"
    diff_us="${diff_us:0:6}"
    diff_us="000000$diff_us"
    diff_us="${diff_us: -6}"
    diff_us_t0="${t0#*.}"
    diff_us_t0="${diff_us_t0:0:6}"
    diff_us_t0="000000$diff_us_t0"
    diff_us_t0="${diff_us_t0: -6}"
    elapsed_us=$((diff_s * 1000000 + 10#$diff_us - 10#$diff_us_t0))
    elapsed_ms=$(((elapsed_us + 500) / 1000))
    timings_ms+=("$elapsed_ms")
done
end_epoch=$EPOCHSECONDS

# Compute statistics in pure bash.
sum=0
min_ms=-1 max_ms=0
declare -a sorted=("${timings_ms[@]}")

# Sum + min/max
for t in "${timings_ms[@]}"; do
    sum=$((sum + t))
    ((t < min_ms || min_ms == -1)) && min_ms="$t"
    ((t > max_ms)) && max_ms="$t"
done

# Sort (simple bubble; sufficient for N<=10000).
for ((i = 0; i < cycles; i++)); do
    for ((j = i + 1; j < cycles; j++)); do
        if ((sorted[j] < sorted[i])); then
            tmp="${sorted[i]}"
            sorted[i]="${sorted[j]}"
            sorted[j]="$tmp"
        fi
    done
done

mean_ms=$(((sum + cycles / 2) / cycles))
median_ms="${sorted[$((cycles / 2))]}"
p95_idx=$(((cycles * 95 + 99) / 100))
((p95_idx >= cycles)) && p95_idx=$((cycles - 1))
p95_ms="${sorted[$p95_idx]}"
total_s=$((end_epoch - start_epoch))
if ((total_s == 0)); then total_s=1; fi
cps=$((cycles / total_s))

# Summary
if ((quiet == 0)); then
    printf 'Results (%d cycles, side=%s):\n' "$cycles" "$side"
    printf '  min:    %d ms\n' "$min_ms"
    printf '  p50:    %d ms\n' "$median_ms"
    printf '  mean:   %d ms\n' "$mean_ms"
    printf '  p95:    %d ms\n' "$p95_ms"
    printf '  max:    %d ms\n' "$max_ms"
    printf '  throughput: ~%d renders/sec\n' "$cps"
    printf '\n'
fi

summary_line="mean=${mean_ms}ms median=${median_ms}ms p95=${p95_ms}ms cycles=${cycles} side=${side} bash=${BASH_VERSION}"

# Baseline comparison (optional).
if [[ -n "$baseline" && -f "$baseline" ]]; then
    baseline_mean=$(grep -oE 'mean=[0-9]+' "$baseline" | head -1 | cut -d= -f2)
    if [[ -n "$baseline_mean" && "$baseline_mean" -gt 0 ]]; then
        delta_pct=$(((mean_ms * 100 + baseline_mean / 2) / baseline_mean - 100))
        printf '%s baseline_mean=%dms delta=+%d%%\n' "$summary_line" "$baseline_mean" "$delta_pct"
    else
        printf '%s baseline=%s (unparseable)\n' "$summary_line" "$baseline"
    fi
else
    printf '%s\n' "$summary_line"
fi
