#!/usr/bin/env bash
# =============================================================================
# PowerKit Entity: Plugins
# Description: Renders the plugins section via powerkit-render
# =============================================================================
# This entity is simple - it just returns the #() call to powerkit-render
# which handles all plugin rendering dynamically.
#
# External separators (to/from other entities) are handled by the compositor.
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "entity_plugins" && return 0

. "${POWERKIT_ROOT}/src/core/defaults.sh"
. "${POWERKIT_ROOT}/src/renderer/color_resolver.sh"

# =============================================================================
# Entity Interface (Required)
# =============================================================================

# Render the plugins content
# Usage: plugins_render [side]
# Returns: #() call to powerkit-render
plugins_render() {
    # side parameter determines separator direction in powerkit-render
    local side="${1:-right}"

    # Pass side to powerkit-render so it knows which direction separators should point
    printf '#(%s %s)' "${POWERKIT_ROOT}/bin/powerkit-render" "$side"
}

# Get the background color of plugins
# Returns: statusbar-bg (plugins blend with status bar background)
plugins_get_bg() {
    resolve_color "statusbar-bg"
}

# =============================================================================
# Entity Interface (Optional)
# =============================================================================

# Plugins have uniform background
plugins_get_first_bg() {
    plugins_get_bg
}

plugins_get_last_bg() {
    plugins_get_bg
}

# No additional configuration needed for plugins
plugins_configure() {
    : # No-op - plugins are configured dynamically via powerkit-render
}
