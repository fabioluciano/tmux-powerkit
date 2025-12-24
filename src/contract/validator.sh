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
#  VALIDATOR - Compatibility Wrapper
#  This file maintains backward compatibility with the original API
#
# =============================================================================
#
# DEPRECATION NOTICE
# ==================
#
# This file is a COMPATIBILITY WRAPPER. The validation functionality has been
# split into dedicated modules:
#
#   - Plugin validation: src/contract/plugin_validator.sh
#   - Theme validation:  src/contract/theme_contract.sh
#   - Templates:         src/core/template_generator.sh
#
# All functions in this file delegate to those modules. New code should source
# the specific modules directly instead of this wrapper.
#
# This wrapper will be maintained for backward compatibility but may be
# removed in a future major version.
#
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "contract_validator" && return 0

. "${POWERKIT_ROOT}/src/core/logger.sh"

# =============================================================================
# Load Validation Modules
# =============================================================================

# Plugin validation
. "${POWERKIT_ROOT}/src/contract/plugin_validator.sh"

# Theme validation (contract defines structure and provides validation)
. "${POWERKIT_ROOT}/src/contract/theme_contract.sh"

# Template generator
. "${POWERKIT_ROOT}/src/core/template_generator.sh"

# =============================================================================
# Backward Compatibility Aliases
# =============================================================================

# These arrays are maintained for backward compatibility
# New code should use the arrays from the respective modules

# Plugin functions (forwarded from plugin_validator.sh)
# PLUGIN_MANDATORY_FUNCTIONS - available via plugin_validator.sh
# PLUGIN_OPTIONAL_FUNCTIONS - available via plugin_validator.sh

# Theme colors (forwarded from theme_contract.sh)
# THEME_REQUIRED_COLORS - available via theme_contract.sh
# THEME_OPTIONAL_COLORS - available via theme_contract.sh

# =============================================================================
# Deprecated Array Names (backward compatibility)
# =============================================================================

# Old array names pointing to new ones
# shellcheck disable=SC2034
declare -gra _PLUGIN_MANDATORY_FUNCTIONS=("${PLUGIN_MANDATORY_FUNCTIONS[@]}")
# shellcheck disable=SC2034
declare -gra _PLUGIN_OPTIONAL_FUNCTIONS=("${PLUGIN_OPTIONAL_FUNCTIONS[@]}")
# shellcheck disable=SC2034
declare -gra _THEME_REQUIRED_COLORS=("${THEME_REQUIRED_COLORS[@]}")

# =============================================================================
# API Functions (all delegate to new modules)
# =============================================================================

# The following functions are automatically available after sourcing the modules:
#
# From plugin_validator.sh:
#   - validate_plugin FILE
#   - validate_all_plugins DIRECTORY
#   - list_mandatory_plugin_functions
#   - list_optional_plugin_functions
#   - list_deprecated_plugin_functions
#   - is_mandatory_plugin_function FUNC
#   - is_optional_plugin_function FUNC
#   - is_deprecated_plugin_function FUNC
#
# From theme_contract.sh:
#   - validate_theme FILE
#   - validate_all_themes DIRECTORY
#   - list_required_theme_colors
#   - list_optional_theme_colors
#   - is_required_theme_color COLOR
#   - is_optional_theme_color COLOR
#
# From template_generator.sh:
#   - generate_plugin_template NAME [TYPE]
#   - generate_helper_template NAME [TYPE]
#   - generate_theme_template NAME [VARIANT]
#   - generate_plugin NAME [TYPE]
#   - generate_helper NAME [TYPE]
#   - generate_theme NAME [VARIANT]

log_debug "validator" "Loaded compatibility wrapper (consider using modules directly)"
