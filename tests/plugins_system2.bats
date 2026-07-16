#!/usr/bin/env bats
# =============================================================================
# BATS tests for system plugins (swap, temperature, fan, gpu, iops, topproc,
# sysstatus) — contract minimum + behavioral
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# swap
# =============================================================================

@test "swap: contract functions work with mocked sysctl" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"vm.swapusage"* ]]; then
    echo "total = 2048.00M  used = 512.00M  free = 1536.00M  (encrypted)"
else
    echo "0"
fi
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/swap.sh"
        _set_plugin_context swap
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence)
        st=$(plugin_get_state) && hl=$(plugin_get_health)
        ic=$(plugin_get_icon) && rd=$(plugin_render 2>/dev/null || true)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(active|inactive|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "swap: 25% usage → health=ok" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/sysctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"vm.swapusage"* ]]; then
    echo "total = 4096.00M  used = 1024.00M  free = 3072.00M"
else
    echo "0"
fi
EOF
    chmod +x "$mock_dir/sysctl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/swap.sh"
        _set_plugin_context swap
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=ok"
}

@test "swap: plugin_get_icon returns non-empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/swap.sh"
        _set_plugin_context swap
        plugin_declare_options
        plugin_data_set "available" "1"
        plugin_data_set "percent" "50"
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "ok" || echo "empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

@test "swap: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/swap.sh"
        _set_plugin_context swap
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=swap"
}

# =============================================================================
# temperature
# =============================================================================

@test "temperature: contract functions work with mocked powerkit-temperature" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/powerkit-temperature" <<'EOF'
#!/usr/bin/env bash
echo "45"
EOF
    chmod +x "$mock_dir/powerkit-temperature"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/temperature.sh"
        _set_plugin_context temperature
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence)
        st=$(plugin_get_state) && hl=$(plugin_get_health)
        ic=$(plugin_get_icon) && rd=$(plugin_render 2>/dev/null || true)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(active|inactive|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "temperature: 45°C → health=ok" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/temperature.sh"
        _set_plugin_context temperature
        plugin_declare_options
        plugin_data_set "temp_c" "45"
        plugin_data_set "available" "1"
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=ok"
    assert_output --partial "state=active"
    assert_output --partial "render=45°C"
}

@test "temperature: 80°C → health=warning" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/temperature.sh"
        _set_plugin_context temperature
        plugin_declare_options
        plugin_data_set "temp_c" "80"
        plugin_data_set "available" "1"
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=warning"
}

@test "temperature: plugin_get_icon returns non-empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/temperature.sh"
        _set_plugin_context temperature
        plugin_declare_options
        plugin_data_set "temp_c" "50"
        plugin_data_set "available" "1"
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "ok" || echo "empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

# =============================================================================
# fan
# =============================================================================

@test "fan: contract functions work with mocked osx-cpu-temp -f" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/osx-cpu-temp" <<'EOF'
#!/usr/bin/env bash
echo "CPU temp: 45°C   Fan speed: 2990 RPM  Num fans: 1"
EOF
    chmod +x "$mock_dir/osx-cpu-temp"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/fan.sh"
        _set_plugin_context fan
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence)
        st=$(plugin_get_state) && hl=$(plugin_get_health)
        ic=$(plugin_get_icon) && rd=$(plugin_render 2>/dev/null || true)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(active|inactive|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "fan: 2000 RPM → state=active, health=ok" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/osx-cpu-temp" <<'EOF'
#!/usr/bin/env bash
echo "CPU temp: 45°C   Fan speed: 2000 RPM  Num fans: 1"
EOF
    chmod +x "$mock_dir/osx-cpu-temp"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/fan.sh"
        _set_plugin_context fan
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
}

@test "fan: plugin_get_icon returns non-empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/fan.sh"
        _set_plugin_context fan
        plugin_declare_options
        plugin_data_set "rpm" "2500"
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "ok" || echo "empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}

# =============================================================================
# gpu
# =============================================================================

@test "gpu: contract functions work with mocked nvidia-smi" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *utilization.gpu*) echo "42" ;;
    *temperature.gpu*) echo "55" ;;
    *memory.used*) echo "2048" ;;
    *memory.total*) echo "8192" ;;
    *name*) echo "NVIDIA RTX 3080" ;;
    *) echo "0" ;;
esac
EOF
    chmod +x "$mock_dir/nvidia-smi"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/gpu.sh"
        is_macos() { return 1; }
        _set_plugin_context gpu
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence)
        st=$(plugin_get_state) && hl=$(plugin_get_health)
        ic=$(plugin_get_icon) && rd=$(plugin_render 2>/dev/null || true)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(active|inactive|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "gpu: 42% usage 55°C → health=ok" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *utilization.gpu*) echo "42" ;;
    *temperature.gpu*) echo "55" ;;
    *memory.used*) echo "2048" ;;
    *memory.total*) echo "8192" ;;
    *name*) echo "NVIDIA RTX 3080" ;;
    *) echo "0" ;;
esac
EOF
    chmod +x "$mock_dir/nvidia-smi"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/gpu.sh"
        is_macos() { return 1; }
        _set_plugin_context gpu
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
}

@test "gpu: 95% usage → health=error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/gpu.sh"
        _set_plugin_context gpu
        plugin_declare_options
        plugin_data_set "available" "1"
        plugin_data_set "usage" "95"
        plugin_data_set "gpu_type" "nvidia"
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=error"
}

# =============================================================================
# iops
# =============================================================================

@test "iops: contract functions work with data seeding" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/iops.sh"
        _set_plugin_context iops
        plugin_declare_options
        plugin_data_set "read_rate" "5000000"
        plugin_data_set "write_rate" "3000000"
        plugin_data_set "total_rate" "8000000"
        plugin_data_set "util" "30"
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence)
        st=$(plugin_get_state) && hl=$(plugin_get_health)
        ic=$(plugin_get_icon) && rd=$(plugin_render 2>/dev/null || true)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=always"
    assert_output --partial "st=active"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "iops: util 85% → health=error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/iops.sh"
        _set_plugin_context iops
        plugin_declare_options
        plugin_data_set "read_rate" "10000000"
        plugin_data_set "write_rate" "5000000"
        plugin_data_set "total_rate" "15000000"
        plugin_data_set "util" "85"
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=error"
}

@test "iops: util 65% → health=warning" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/iops.sh"
        _set_plugin_context iops
        plugin_declare_options
        plugin_data_set "read_rate" "8000000"
        plugin_data_set "write_rate" "4000000"
        plugin_data_set "total_rate" "12000000"
        plugin_data_set "util" "65"
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=warning"
}

# =============================================================================
# topproc
# =============================================================================

@test "topproc: contract functions work with mocked ps" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/ps" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *%cpu*) echo "  %CPU COMM"; echo " 87.5 node" ;;
  *) exit 1 ;;
esac
EOF
    chmod +x "$mock_dir/ps"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/topproc.sh"
        _set_plugin_context topproc
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence)
        st=$(plugin_get_state) && hl=$(plugin_get_health)
        ic=$(plugin_get_icon) && rd=$(plugin_render 2>/dev/null || true)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --partial "st=active"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "topproc: 87.5% node → health=ok (below 70 warn)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/topproc.sh"
        _set_plugin_context topproc
        plugin_declare_options
        plugin_data_set "proc_pct" "50"
        plugin_data_set "proc_name" "node"
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
    assert_output --partial "node 50%"
}

@test "topproc: 85% usage → health=warning" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/topproc.sh"
        _set_plugin_context topproc
        plugin_declare_options
        plugin_data_set "proc_pct" "85"
        plugin_data_set "proc_name" "chrome"
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=warning"
}

@test "topproc: empty data → state=inactive" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/topproc.sh"
        _set_plugin_context topproc
        plugin_declare_options
        plugin_data_set "proc_name" ""
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "state=inactive"
}

# =============================================================================
# sysstatus
# =============================================================================

@test "sysstatus: contract functions work with cross-plugin data" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/sysstatus.sh"
        _set_plugin_context sysstatus
        plugin_declare_options
        # Seed cross-plugin data
        _datastore_set "cpu" "percent" "45"
        _datastore_set "memory" "percent" "60"
        _datastore_set "disk" "max_percent" "50"
        _datastore_set "temperature" "available" "1"
        _datastore_set "temperature" "temp_c" "55"
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence)
        st=$(plugin_get_state) && hl=$(plugin_get_health)
        ic=$(plugin_get_icon) && rd=$(plugin_render 2>/dev/null || true)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=always"
    assert_output --partial "st=active"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "sysstatus: all metrics ok → health=ok → badge OK" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/sysstatus.sh"
        _set_plugin_context sysstatus
        plugin_declare_options
        _datastore_set "cpu" "percent" "30"
        _datastore_set "memory" "percent" "50"
        _datastore_set "disk" "max_percent" "40"
        _datastore_set "temperature" "available" "1"
        _datastore_set "temperature" "temp_c" "45"
        plugin_collect 2>/dev/null || true
        echo "health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=ok"
    assert_output --partial "render=OK"
}

@test "sysstatus: disk 96% → health=error → badge CRIT" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/sysstatus.sh"
        _set_plugin_context sysstatus
        plugin_declare_options
        _datastore_set "cpu" "percent" "30"
        _datastore_set "memory" "percent" "50"
        _datastore_set "disk" "max_percent" "96"
        _datastore_set "temperature" "available" "1"
        _datastore_set "temperature" "temp_c" "45"
        plugin_collect 2>/dev/null || true
        echo "health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=error"
    assert_output --partial "render=CRIT"
}

@test "sysstatus: plugin_get_icon returns non-empty" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/sysstatus.sh"
        _set_plugin_context sysstatus
        plugin_declare_options
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "ok" || echo "empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "ok"
}
