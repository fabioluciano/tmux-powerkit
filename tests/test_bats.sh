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
    # === Helpers ===
    "$SCRIPT_DIR/tmux_smoke.bats"
    "$SCRIPT_DIR/security.bats"
    "$SCRIPT_DIR/aiquotas.bats"

    # === Core ===
    "$SCRIPT_DIR/cache.bats"
    "$SCRIPT_DIR/core_bootstrap.bats"
    "$SCRIPT_DIR/core_logger.bats"
    "$SCRIPT_DIR/core_theme_loader.bats"
    "$SCRIPT_DIR/core_color_palette.bats"
    "$SCRIPT_DIR/core_color_generator.bats"
    "$SCRIPT_DIR/core_options.bats"
    "$SCRIPT_DIR/core_binary_manager.bats"
    "$SCRIPT_DIR/core_keybindings.bats"
    "$SCRIPT_DIR/core_datastore.bats"
    "$SCRIPT_DIR/core_registry.bats"
    "$SCRIPT_DIR/core_defaults.bats"
    "$SCRIPT_DIR/core_guard.bats"
    "$SCRIPT_DIR/lifecycle.bats"

    # === Utils ===
    "$SCRIPT_DIR/lib_platform.bats"
    "$SCRIPT_DIR/lib_strings.bats"
    "$SCRIPT_DIR/lib_api.bats"
    "$SCRIPT_DIR/lib_network.bats"
    "$SCRIPT_DIR/lib_filesystem.bats"
    "$SCRIPT_DIR/lib_ui_backend.bats"
    "$SCRIPT_DIR/lib_keybinding.bats"
    "$SCRIPT_DIR/lib_time.bats"
    "$SCRIPT_DIR/lib_validation.bats"
    "$SCRIPT_DIR/lib_numbers.bats"

    # === Contracts ===
    "$SCRIPT_DIR/contract_helper.bats"
    "$SCRIPT_DIR/contract_plugin.bats"
    "$SCRIPT_DIR/contract_window.bats"
    "$SCRIPT_DIR/contract_session.bats"
    "$SCRIPT_DIR/contract_pane.bats"
    "$SCRIPT_DIR/contract_theme.bats"
    "$SCRIPT_DIR/contract_message.bats"

    # === Renderer ===
    "$SCRIPT_DIR/renderer_color_resolver.bats"
    "$SCRIPT_DIR/renderer_styles.bats"
    "$SCRIPT_DIR/renderer_separator.bats"
    "$SCRIPT_DIR/renderer_renderer_compositor.bats"
    "$SCRIPT_DIR/renderer_segment_builder.bats"
    "$SCRIPT_DIR/renderer.bats"

    # === Plugins ===
    "$SCRIPT_DIR/docker.bats"
    "$SCRIPT_DIR/plugin_git.bats"
    "$SCRIPT_DIR/plugin_disk.bats"
    "$SCRIPT_DIR/plugin_battery.bats"
    "$SCRIPT_DIR/plugin_github.bats"
    "$SCRIPT_DIR/plugin_hostname.bats"
    "$SCRIPT_DIR/plugin_wifi.bats"
    "$SCRIPT_DIR/plugin_memory.bats"
    "$SCRIPT_DIR/plugin_cpu.bats"
    "$SCRIPT_DIR/plugin_netspeed.bats"
    "$SCRIPT_DIR/plugin_vpn.bats"
    "$SCRIPT_DIR/plugin_ping.bats"
    "$SCRIPT_DIR/plugin_uptime.bats"
    "$SCRIPT_DIR/plugin_loadavg.bats"
    "$SCRIPT_DIR/plugin_datetime.bats"
    "$SCRIPT_DIR/plugin_terraform.bats"
    "$SCRIPT_DIR/plugin_kubernetes.bats"
    "$SCRIPT_DIR/plugin_weather.bats"
    "$SCRIPT_DIR/plugin_nowplaying.bats"
    "$SCRIPT_DIR/plugin_volume.bats"
    "$SCRIPT_DIR/entities_windows.bats"
    "$SCRIPT_DIR/entities_session.bats"
    "$SCRIPT_DIR/plugins_dev2.bats"
    "$SCRIPT_DIR/plugins_prod_fin.bats"
    "$SCRIPT_DIR/plugins_system2.bats"
    "$SCRIPT_DIR/plugins_network2.bats"
    "$SCRIPT_DIR/plugins_media2.bats"
)

for test_file in "${BATS_FILES[@]}"; do
    [[ -f "$test_file" ]] || {
        echo "ERROR: Required Bats suite missing: $test_file" >&2
        exit 1
    }
done

exec bats "${BATS_FILES[@]}"
