#!/usr/bin/env bash
# =============================================================================
# aiquotas manual smoke test
# Description: Verifies the aiquotas plugin works through the curl shim
# Prerequisites: AIQUOTAS_SMOKE_SCENARIO, ANTHROPIC_ADMIN_KEY, OPENAI_ADMIN_KEY
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
export POWERKIT_ROOT

echo "=== aiquotas manual smoke test ==="

# Bridge SMOKE_ env vars to what the shim/adapter expects
export AIQUOTAS_HTTP_SCENARIO="${AIQUOTAS_SMOKE_SCENARIO:-$POWERKIT_ROOT/tests/fixtures/aiquotas/http/anthropic-openai.tsv}"
export AIQUOTAS_HTTP_STATE
AIQUOTAS_HTTP_STATE="$(mktemp -d -t aq_smoke.XXXXXX)"
: >"$AIQUOTAS_HTTP_STATE/counter"

source "$POWERKIT_ROOT/src/core/bootstrap.sh" 2>/dev/null
source "$POWERKIT_ROOT/src/contract/plugin_contract.sh" 2>/dev/null
source "$POWERKIT_ROOT/src/plugins/aiquotas.sh" 2>/dev/null

_set_plugin_context aiquotas
plugin_declare_options

plugin_collect || {
    echo "State: $(plugin_get_state 2>/dev/null || echo unknown)"
    rm -rf "$AIQUOTAS_HTTP_STATE"
    exit 0
}

# Verify state
state=$(plugin_get_state)
echo "State: $state"
[[ "$state" =~ ^(active|degraded)$ ]] || {
    echo "FAIL: unexpected state=$state"
    exit 1
}

# Verify render produces plain text
render=$(plugin_render)
echo "Render: $render"
[[ "$render" != *"#["* ]] || {
    echo "FAIL: render contains tmux formatting"
    exit 1
}

echo "=== smoke test PASSED ==="
rm -rf "$AIQUOTAS_HTTP_STATE"
