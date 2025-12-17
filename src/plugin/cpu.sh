#!/usr/bin/env bash
# Plugin: cpu - Display CPU usage percentage

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "cpu"

# Linux: /proc/stat with sampling
get_cpu_linux() {
    local line vals idle1 total1 idle2 total2 v

    line=$(grep '^cpu ' /proc/stat)
    read -ra vals <<< "${line#cpu }"
    idle1=${vals[3]}; total1=0
    for v in "${vals[@]}"; do total1=$((total1 + v)); done

    sleep "$POWERKIT_TIMING_CPU_SAMPLE"

    line=$(grep '^cpu ' /proc/stat)
    read -ra vals <<< "${line#cpu }"
    idle2=${vals[3]}; total2=0
    for v in "${vals[@]}"; do total2=$((total2 + v)); done

    local di=$((idle2 - idle1)) dt=$((total2 - total1))
    [[ $dt -gt 0 ]] && printf '%d' "$(( (1000 * (dt - di) / dt + 5) / 10 ))" || printf '0'
}

# macOS: iostat or ps fallback
get_cpu_macos() {
    local cpu=$(iostat -c "$POWERKIT_IOSTAT_COUNT" 2>/dev/null | tail -1 | \
        awk -v b="$POWERKIT_IOSTAT_BASELINE" -v f="$POWERKIT_IOSTAT_CPU_FIELD" '{printf "%.0f", b-$f}')

    if [[ -z "$cpu" || "$cpu" == "100" ]]; then
        local cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
        cpu=$(ps -axo %cpu | awk -v c="$cores" -v l="$POWERKIT_PERF_CPU_PROCESS_LIMIT" \
            'NR>1 && NR<=l {s+=$1} END {a=s/c; if(a>100)a=100; printf "%.0f", a}')
    fi
    printf '%s' "${cpu:-0}"
}

plugin_get_type() { printf 'static'; }

plugin_get_display_info() {
    local content="${1:-}"
    [[ -z "$content" || "$content" == "N/A" ]] && { build_display_info "0" "" "" ""; return; }
    build_display_info "1" "" "" ""
}

_compute_cpu() {
    local r
    is_linux && r=$(get_cpu_linux) || { is_macos && r=$(get_cpu_macos) || r="N/A"; }
    [[ "$r" != "N/A" ]] && r=$(printf '%3d%%' "$r")
    printf '%s' "$r"
}

load_plugin() {
    cache_get_or_compute "$CACHE_KEY" "$CACHE_TTL" _compute_cpu
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
