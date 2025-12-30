#!/usr/bin/env bash
# =============================================================================
#
#  ██████╗  ██████╗ ██╗    ██╗███████╗██████╗ ██╗  ██╗██╗████████╗
#  ██╔══██╗██╔═══██╗██║    ██║██╔════╝██╔══██╗██║ ██╔╝██║╚══██╔══╝
#  ██████╔╝██║   ██║██║ █╗ ██║█████╗  ██████╔╝█████╔╝ ██║   ██║
#  ██╔═══╝ ██║   ██║██║███╗██║██╔══╝  ██╔══██╗██╔═██╗ ██║   ██║
#  ██║     ╚██████╔╝╚███╔███╔╝███████╗██║  ██║██║  ██╗██║   ██║
#  ╚═╝      ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝
#
#  TEMPLATE GENERATOR - Version 1.0.0
#  Generate boilerplate code for plugins, helpers, and themes
#
# =============================================================================
#
# TABLE OF CONTENTS
# =================
#   1. Overview
#   2. API Reference
#   3. Usage Examples
#
# =============================================================================
#
# 1. OVERVIEW
# ===========
#
# The Template Generator provides functions to create boilerplate code for
# new PowerKit components. It ensures consistency and adherence to contracts.
#
# Available Generators:
#   - generate_plugin_template()  - Create a new plugin
#   - generate_helper_template()  - Create a new helper
#   - generate_theme_template()   - Create a new theme
#
# =============================================================================
#
# 2. API REFERENCE
# ================
#
#   generate_plugin_template NAME [TYPE]
#       Generate a plugin template file.
#       NAME: Plugin name (e.g., "battery", "cpu")
#       TYPE: "conditional" (default) or "always"
#
#   generate_helper_template NAME [TYPE]
#       Generate a helper template file.
#       NAME: Helper name (e.g., "selector", "viewer")
#       TYPE: "popup" (default), "menu", "command", or "toast"
#
#   generate_theme_template NAME [VARIANT]
#       Generate a theme template file.
#       NAME: Theme name (e.g., "my-theme")
#       VARIANT: "dark" (default) or "light"
#
# =============================================================================
#
# 3. USAGE EXAMPLES
# =================
#
#   # Generate a new plugin
#   generate_plugin_template "weather" > src/plugins/weather.sh
#
#   # Generate a popup helper
#   generate_helper_template "device_selector" "popup" > src/helpers/device_selector.sh
#
#   # Generate a dark theme
#   generate_theme_template "my-theme" "dark" > src/themes/my-theme/dark.sh
#
# =============================================================================
# END OF DOCUMENTATION
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "template_generator" && return 0

# =============================================================================
# Plugin Template Generator
# =============================================================================

# Generate a plugin template
# Usage: generate_plugin_template "plugin_name" ["conditional"|"always"]
generate_plugin_template() {
    local name="$1"
    # shellcheck disable=SC2034 # Used in template heredoc
    local presence="${2:-conditional}"

    cat << 'TEMPLATE_EOF'
#!/usr/bin/env bash
# =============================================================================
# Plugin: PLUGIN_NAME
# Description: TODO - Add description
# Type: PLUGIN_PRESENCE
# Dependencies: TODO - List dependencies
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    # Add required commands
    # require_cmd "curl" || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    declare_option "icon" "icon" $'\U0000f111' "Plugin icon"
    declare_option "cache_ttl" "number" "30" "Cache duration in seconds"
    # NOTE: Colors are determined by renderer based on state/health - do NOT add accent_color
}

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "PLUGIN_NAME"
    metadata_set "name" "PLUGIN_NAME_TITLE"
    metadata_set "description" "TODO - Add description"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    # Collect data and store with plugin_data_set
    plugin_data_set "value" "example"
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'PLUGIN_PRESENCE'; }

# =============================================================================
# Plugin Contract: State and Health
# =============================================================================

plugin_get_state() {
    plugin_data_has "value" || { printf 'failed'; return; }
    printf 'active'
}

plugin_get_health() {
    printf 'ok'
}

plugin_get_context() {
    printf ''
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() {
    # Return icon based on plugin's internal data/context
    # NOT based on health - renderer handles health colors
    printf '%s' "$(get_option 'icon')"
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY - no colors, no formatting)
# =============================================================================

plugin_render() {
    printf '%s' "$(plugin_data_get 'value')"
}
TEMPLATE_EOF
}

# =============================================================================
# Helper Template Generator
# =============================================================================

# Generate a helper template
# Usage: generate_helper_template "helper_name" ["popup"|"menu"|"command"|"toast"]
generate_helper_template() {
    local name="$1"
    local type="${2:-popup}"

    cat << 'TEMPLATE_EOF'
#!/usr/bin/env bash
# =============================================================================
# Helper: HELPER_NAME
# Description: TODO - Add description
# Type: HELPER_TYPE
# =============================================================================

# Source helper contract (handles all initialization)
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "HELPER_NAME"
    helper_metadata_set "name" "HELPER_NAME_TITLE"
    helper_metadata_set "description" "TODO - Add description"
    helper_metadata_set "type" "HELPER_TYPE"
}

helper_get_actions() {
    echo "default - Default action"
    # Add more actions here
}

# =============================================================================
# Implementation
# =============================================================================

_do_default_action() {
    # TODO: Implement default action
    helper_toast "Action executed" "simple"
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-default}"

    case "$action" in
        default|"")
            _do_default_action
            ;;
        *)
            echo "Unknown action: $action" >&2
            return 1
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
TEMPLATE_EOF
}

# =============================================================================
# Theme Template Generator
# =============================================================================

# Generate a theme template
# Usage: generate_theme_template "theme_name" ["dark"|"light"]
generate_theme_template() {
    local name="$1"
    local variant="${2:-dark}"

    cat << 'TEMPLATE_EOF'
#!/usr/bin/env bash
# =============================================================================
# Theme: THEME_NAME
# Variant: THEME_VARIANT
# Description: TODO - Add description
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "theme_THEME_NAME_THEME_VARIANT" && return 0

# =============================================================================
# Theme Colors
# =============================================================================

declare -gA THEME_COLORS=(
    # Status bar
    [statusbar-bg]="#1a1b26"
    [statusbar-fg]="#c0caf5"

    # Session
    [session-bg]="#7aa2f7"
    [session-fg]="#1a1b26"
    [session-prefix-bg]="#e0af68"
    [session-copy-bg]="#bb9af7"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#7aa2f7"
    [window-inactive-base]="#3b4261"

    # Pane borders
    [pane-border-active]="#7aa2f7"
    [pane-border-inactive]="#3b4261"

    # Health states (base colors - variants auto-generated)
    [ok-base]="#9ece6a"
    [good-base]="#73daca"
    [info-base]="#7dcfff"
    [warning-base]="#e0af68"
    [error-base]="#f7768e"
    [disabled-base]="#565f89"

    # Messages
    [message-bg]="#1a1b26"
    [message-fg]="#c0caf5"


# =============================================================================
# Theme Metadata
# =============================================================================

THEME_NAME="THEME_NAME"
THEME_VARIANT="THEME_VARIANT"
THEME_DESCRIPTION="TODO - Add description"
THEME_AUTHOR="TODO - Add author"
THEME_LICENSE="MIT"
TEMPLATE_EOF
}

# =============================================================================
# Post-processing helpers
# =============================================================================

# Replace placeholders in generated template
# Usage: _apply_template_vars "template_content" "name" "type"
_apply_template_vars() {
    local content="$1"
    local name="$2"
    local type="$3"

    # Convert name to title case
    local name_title="${name//_/ }"
    name_title="$(echo "$name_title" | sed 's/\b\(.\)/\u\1/g')"

    content="${content//PLUGIN_NAME/$name}"
    content="${content//PLUGIN_NAME_TITLE/$name_title}"
    content="${content//PLUGIN_PRESENCE/$type}"
    content="${content//HELPER_NAME/$name}"
    content="${content//HELPER_NAME_TITLE/$name_title}"
    content="${content//HELPER_TYPE/$type}"
    content="${content//THEME_NAME/$name}"
    content="${content//THEME_VARIANT/$type}"

    printf '%s' "$content"
}

# Generate and apply template vars in one step
# Usage: generate_plugin "battery" "conditional"
generate_plugin() {
    local name="$1"
    local type="${2:-conditional}"
    local template
    template=$(generate_plugin_template "$name" "$type")
    _apply_template_vars "$template" "$name" "$type"
}

# Generate and apply helper template
# Usage: generate_helper "device_selector" "popup"
generate_helper() {
    local name="$1"
    local type="${2:-popup}"
    local template
    template=$(generate_helper_template "$name" "$type")
    _apply_template_vars "$template" "$name" "$type"
}

# Generate and apply theme template
# Usage: generate_theme "my-theme" "dark"
generate_theme() {
    local name="$1"
    local variant="${2:-dark}"
    local template
    template=$(generate_theme_template "$name" "$variant")
    _apply_template_vars "$template" "$name" "$variant"
}
