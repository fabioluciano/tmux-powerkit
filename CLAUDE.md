# CLAUDE.md

This file providdes guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerKit is a modular tmux status bar framework (formerly tmux-tokyo-night). It provides 42+ plugins for displaying system information with a semantic color system that works across 14 themes (with 25+ variants). Distributed through TPM (Tmux Plugin Manager).

## Development Commands

### Linting

```bash
# Run shellcheck on all shell scripts
shellcheck src/**/*.sh src/*.sh tmux-powerkit.tmux
```

Note: The project uses GitHub Actions to run shellcheck automatically on push/PR.

### Testing

**Automated Testing:**

```bash
# Run plugin test suite
./tests/test_plugins.sh

# Test specific plugin
./tests/test_plugins.sh cpu

# Test multiple plugins
./tests/test_plugins.sh cpu memory disk

# Available test categories:

# Structure Tests (Contract Compliance):
# - syntax: bash -n validation
# - source: file readable
# - required_functions: plugin_get_type, load_plugin exist
# - plugin_declare_options: options declaration exists
# - display_info: plugin_get_display_info uses build_display_info
# - plugin_init: uses plugin_init for setup
# - standard_header: has standard header with Type declaration
# - function_naming: no double underscore function definitions
# - function_consistency: all called functions are defined
# - caching: uses cache_get/cache_set
# - shellcheck: static analysis

# Behavior Tests:
# - execution: plugin runs without errors/timeout
# - plugin_type: returns valid type (static/conditional, dynamic is deprecated)
# - cache_ttl_default: has cache TTL in defaults.sh
# - dry_pattern: uses default_plugin_display_info or build_display_info
# - anti_patterns: no echo|grep, cat|pipe patterns
# - output_format: validates output format for specific plugins
```

**Manual testing:**

1. Install the plugin via TPM in a test tmux configuration
2. Source the plugin: `tmux source ~/.tmux.conf`
3. Verify visual appearance and plugin functionality
4. Test different themes and plugin combinations

## Architecture

### Entry Point

- `tmux-powerkit.tmux` - Main entry point called by TPM, delegates to `src/theme.sh`

### Core Components

**`src/source_guard.sh`** - Source Guard Helper (Base Module)

- Prevents multiple sourcing of files for performance
- Must be sourced first by all other modules
- Provides `source_guard(module_name)` function
- Usage: `source_guard "module_name" && return 0`
- Creates guard variables: `_POWERKIT_<MODULE>_LOADED`

**`src/defaults.sh`** - Centralized Default Values (DRY/KISS)

- Contains ALL default values in one place
- Uses semantic color names (`secondary`, `warning`, `error`, etc.)
- Uses `source_guard "defaults"` for protection
- Helper: `get_powerkit_plugin_default(plugin, option)`
- Variables follow: `POWERKIT_PLUGIN_<NAME>_<OPTION>` (e.g., `POWERKIT_PLUGIN_BATTERY_ICON`)
- Base defaults reused across plugins: `_DEFAULT_ACCENT`, `_DEFAULT_WARNING`, `_DEFAULT_CRITICAL`

**`src/theme.sh`** - Main Orchestration

- Sources `defaults.sh` first
- Loads theme from `src/themes/<theme>/<variant>.sh`
- Configures status bar, windows, borders, panes
- Dynamically loads plugins from `src/plugin/`
- Handles plugin rendering with proper separators

**`src/utils.sh`** - Utility Functions

- `get_tmux_option(option, default)` - Retrieves tmux options with fallback (uses batch loading cache)
- `get_powerkit_color(semantic_name)` - Resolves semantic color to hex
- `load_powerkit_theme()` - Loads theme file and populates `POWERKIT_THEME_COLORS`
- `get_os()` / `is_macos()` / `is_linux()` - OS detection (cached in `_CACHED_OS`)
- `extract_numeric(string)` - Extracts first numeric value using bash regex (no fork)
- `_batch_load_tmux_options()` - Pre-loads all `@powerkit_*` options in single tmux call
- Status bar generation functions

**`src/cache.sh`** - Caching System

- `cache_get(key, ttl)` - Returns cached value if valid
- `cache_set(key, value)` - Stores value in cache
- `cache_clear_all()` - Clears all cached data
- `cache_get_or_compute(key, ttl, cmd...)` - Get cached value or compute and cache
- `cache_age(key)` - Get cache age in seconds
- Cache location: `$XDG_CACHE_HOME/tmux-powerkit/` or `~/.cache/tmux-powerkit/`

**`src/render_plugins.sh`** - Plugin Rendering

- Processes `@powerkit_plugins` option
- Builds status-right string with separators and colors
- Handles transparent mode
- Resolves semantic colors via `get_powerkit_color()`
- Handles external plugins with format: `EXTERNAL|icon|content|accent|accent_icon|ttl`
- Executes `$(command)` and `#(command)` in external plugin content
- Supports caching for external plugins via TTL parameter
- Uses `set -eu` (note: `pipefail` removed due to issues with `grep -q` in pipes)
- `_string_hash()` - Pure bash hash function (avoids md5sum fork)
- `_process_external_plugin()` / `_process_internal_plugin()` - Modular plugin processing

**`src/init.sh`** - Module Initialization

- Central initialization for loading all core modules
- Defines dependency loading order (critical for correct operation)
- Sources: `source_guard.sh` → `defaults.sh` → `utils.sh` → `cache.sh` → `keybindings.sh` → `tmux_ui.sh` → `plugin_integration.sh`
- Uses `set -eu` (note: `pipefail` removed due to issues with `grep -q` in pipes)

**`src/tmux_ui.sh`** - Tmux UI (Consolidated)

- Consolidated UI module combining: separators, window formatting, status bar, tmux config
- **Separator System:**
  - `get_separator_char()` - Get separator character
  - `get_previous_window_background()` - Calculate previous window background
  - `create_index_content_separator()` - Separator between window number and content
  - `create_window_separator()` - Separator between windows
  - `create_spacing_segment()` - Spacing between elements
  - `create_final_separator()` - End of window list separator
- **Window System:**
  - `get_window_index_colors()` / `create_window_index_segment()` - Window index styling
  - `get_window_content_colors()` / `create_window_content_segment()` - Window content styling
  - `get_window_icon()` / `get_window_title()` - Window icons and titles
  - `create_active_window_format()` / `create_inactive_window_format()` - Complete window formats
- **Status Bar:**
  - `create_session_segment()` - Left side session segment
  - `build_status_left_format()` / `build_status_right_format()` - Status format builders
  - `build_window_list_format()` / `build_tmux_window_format()` - Window list formatting
  - `build_single_layout_status_format()` / `build_double_layout_windows_format()` - Layout builders
- **Tmux Config:**
  - `configure_tmux_appearance()` - Apply all tmux appearance settings

**`src/plugin_bootstrap.sh`** - Plugin Bootstrap

- Common initialization for all plugins
- Sets up `ROOT_DIR`, sources utilities via `init.sh`
- Provides `plugin_init(name)` function

**`src/plugin_helpers.sh`** - Plugin Helper Functions

- **Options Declaration Contract** (use in `plugin_declare_options()`):
  - `declare_option(name, type, default, description)` - Declare a plugin option
  - `get_option(name)` - Get option value with lazy loading and caching
  - `clear_options_cache()` - Clear cached option values (for testing)
  - `get_plugin_declared_options(plugin)` - Get all declared options for a plugin
  - `has_declared_options(plugin)` - Check if plugin has declared options
- **Dependency Checking Contract** (use ONLY in `plugin_check_dependencies()`):
  - `require_cmd(cmd, optional)` - Declare dependency (optional=1 for non-required)
  - `require_any_cmd(cmd1, cmd2, ...)` - Declare alternative dependencies (need at least one)
  - `check_dependencies(cmd1, cmd2, ...)` - Check multiple dependencies at once
  - `get_missing_deps()` - Get list of missing required dependencies
  - `get_missing_optional_deps()` - Get list of missing optional dependencies
  - `reset_dependency_check()` - Reset dependency arrays before checking
  - `run_plugin_dependency_check()` - Execute plugin's dependency check if defined
- **Runtime Command Check** (use in plugin logic):
  - `has_cmd(cmd)` - Check if command exists (no side effects, for runtime logic)
- **Timeout & Safe Execution:**
  - `run_with_timeout(seconds, cmd...)` - Run command with timeout
  - `safe_curl(url, timeout, args...)` - Safe curl with error handling
- **Configuration Validation:**
  - `validate_range(value, min, max, default)` - Validate numeric range
  - `validate_option(value, default, opt1, opt2, ...)` - Validate against options
  - `validate_bool(value, default)` - Validate boolean value
- **Threshold Colors:**
  - `apply_threshold_colors(value, plugin, invert)` - Apply warning/critical colors (returns `accent:accent_icon`)
  - `threshold_plugin_display_info(content, value)` - Unified threshold display (handles visibility, colors, icons)
- **API & Audio:**
  - `make_api_call(url, auth_type, token)` - Authenticated API call
  - `detect_audio_backend()` - Detect macos/pipewire/pulseaudio/alsa

**Logging System** (in `src/utils.sh`)

- **Centralized Logging** (logs to `~/.cache/tmux-powerkit/powerkit.log`):
  - `log_debug(source, message)` - Debug level (only when @powerkit_debug=true)
  - `log_info(source, message)` - Info level
  - `log_warn(source, message)` - Warning level
  - `log_error(source, message)` - Error level
  - `log_plugin_error(plugin, message, show_toast)` - Plugin error with optional toast
  - `log_missing_dep(plugin, dependency)` - Log missing dependency
  - `get_log_file()` - Get log file path
- Log rotation: automatically rotates when > 1MB

### Theme System

Located in `src/themes/<theme>/<variant>.sh`:

```text
src/themes/
├── ayu/
│   ├── dark.sh
│   ├── light.sh
│   └── mirage.sh
├── catppuccin/
│   ├── frappe.sh
│   ├── latte.sh
│   ├── macchiato.sh
│   └── mocha.sh
├── dracula/
│   └── dark.sh
├── everforest/
│   ├── dark.sh
│   └── light.sh
├── github/
│   ├── dark.sh
│   └── light.sh
├── gruvbox/
│   ├── dark.sh
│   └── light.sh
├── kanagawa/
│   ├── dragon.sh
│   ├── lotus.sh
│   └── wave.sh
├── kiribyte/
│   ├── dark.sh
│   └── light.sh
├── nord/
│   └── dark.sh
├── onedark/
│   └── dark.sh
├── rose-pine/
│   ├── dawn.sh
│   ├── main.sh
│   └── moon.sh
├── solarized/
│   ├── dark.sh
│   └── light.sh
└── tokyo-night/
    ├── day.sh
    ├── night.sh
    └── storm.sh
```

Each theme defines a `THEME_COLORS` associative array with semantic color names:

```bash
declare -A THEME_COLORS=(
    # Core
    [background]="#1a1b26"
    [text]="#c0caf5"
    
    # Semantic
    [primary]="#7aa2f7"
    [secondary]="#394b70"
    [accent]="#bb9af7"
    
    # Status
    [success]="#9ece6a"
    [warning]="#e0af68"
    [error]="#f7768e"
    [info]="#7dcfff"
    
    # Interactive
    [active]="#3d59a1"
    [disabled]="#565f89"
    # ... more colors
)
```

#### Custom Themes

PowerKit supports loading custom theme files from any location:

**Configuration:**

```bash
# In ~/.tmux.conf
set -g @powerkit_theme "custom"
set -g @powerkit_custom_theme_path "~/path/to/my-custom-theme.sh"
```

**Creating a Custom Theme:**

1. Create a `.sh` file with your theme colors
2. Define a `THEME_COLORS` associative array with all semantic colors
3. Export the array: `export THEME_COLORS`

See `assets/example-custom-theme.sh` for a complete reference implementation.

**Example custom theme file:**

```bash
#!/usr/bin/env bash
# My Custom Theme

declare -A THEME_COLORS=(
    # Core
    [background]="#1e1e2e"
    [surface]="#313244"
    [text]="#cdd6f4"
    [border]="#585b70"

    # Semantic
    [primary]="#89b4fa"
    [secondary]="#45475a"
    [accent]="#cba6f7"

    # Status
    [success]="#a6e3a1"
    [warning]="#f9e2af"
    [error]="#f38ba8"
    [info]="#89dceb"

    # Interactive
    [active]="#6c7086"
    [disabled]="#313244"
    [hover]="#7f849c"
    [focus]="#89b4fa"

    # Subtle variants (for icons)
    [primary-subtle]="#313244"
    [success-subtle]="#313244"
    [warning-subtle]="#313244"
    [error-subtle]="#313244"
    [info-subtle]="#313244"

    # Strong variants (emphasized)
    [border-strong]="#7f849c"
    [border-subtle]="#45475a"
)

export THEME_COLORS
```

**Required Semantic Colors:**

- **Core:** `background`, `surface`, `text`, `border`
- **Semantic:** `primary`, `secondary`, `accent`
- **Status:** `success`, `warning`, `error`, `info`
- **Interactive:** `active`, `disabled`, `hover`, `focus`
- **Variants:** `*-subtle`, `*-strong`, `border-strong`, `border-subtle`

**Notes:**

- Custom themes persist across `tmux kill-server` (stored in cache)
- If the custom theme file is not found, PowerKit falls back to tokyo-night/night
- Use the built-in themes as reference (see `src/themes/*/`)
- Theme selector (`prefix + C-r`) will show "custom" when active
- **Path expansion:** The tilde (`~`) in `@powerkit_custom_theme_path` is automatically expanded to the user's home directory. Both `~/path` and absolute paths work correctly. The expansion handles escaped tildes (`\~`) and environment variables.

### Plugin System

**Plugin Contract Overview:**

Every plugin follows a standard contract that enables:
- Self-documenting options (displayed in options viewer)
- Lazy loading and caching of configuration values
- Type validation for option values
- Dependency checking before plugin execution
- Consistent error handling and logging

**Plugin Structure (`src/plugin/*.sh`):**

1. Source `plugin_bootstrap.sh`
2. Define `plugin_check_dependencies()` - declares required/optional dependencies
3. Define `plugin_declare_options()` - declares configurable options with types and defaults
4. Call `plugin_init "name"` - sets up cache, TTL, and auto-calls contract functions
5. Define `plugin_get_type()` - returns `static`, `dynamic`, or `conditional`
6. Define `plugin_get_display_info()` - returns `visible:accent:accent_icon:icon`
7. Define `load_plugin()` - outputs the display content
8. Optional: `setup_keybindings()` for interactive features

**Important:** Define `plugin_check_dependencies()` and `plugin_declare_options()` **before** calling `plugin_init()`, as it auto-invokes them if defined.

**Options Declaration Contract (`plugin_declare_options`):**

Plugins SHOULD implement this function to declare their configurable options.
This enables self-documenting plugins, lazy loading, type validation, and potential auto-generation of wiki documentation.

**Syntax:**

```bash
declare_option "<name>" "<type>" "<default>" "<description>"
```

**Option Types:**

| Type | Description | Validation | Examples |
|------|-------------|------------|----------|
| `string` | Any string value | None | `"both"`, `" \| "` |
| `number` | Integer value | Must be numeric | `"0"`, `"300"`, `"5"` |
| `bool` | Boolean value | `true/false/on/off/yes/no/1/0` | `"true"`, `"false"` |
| `color` | Semantic color name | None (resolved at render) | `"secondary"`, `"warning"` |
| `icon` | Nerd Font icon | None | `$'\uf025'`, `$'\uf130'` |
| `key` | Keybinding | None | `"C-i"`, `"M-x"`, `"C-S-j"` |
| `path` | File system path | None | `"/etc/config"`, `"~/.cache"` |
| `enum` | Predefined values | Document in description | `"simple"` (see description) |

**Example - Complete Options Declaration:**

```bash
plugin_declare_options() {
    # Behavior options
    declare_option "show" "string" "both" "Show devices (off|input|output|both)"
    declare_option "max_length" "number" "0" "Maximum name length (0=unlimited)"
    declare_option "separator" "string" " | " "Separator between items"
    declare_option "show_device_icons" "bool" "false" "Show icons next to names"

    # Keybindings
    declare_option "input_key" "key" "C-i" "Key for input selector"
    declare_option "output_key" "key" "C-o" "Key for output selector"

    # Icons (use $'...' for literal Unicode)
    declare_option "icon" "icon" $'\uf025' "Plugin icon"
    declare_option "input_icon" "icon" $'\uf130' "Input device icon"
    declare_option "output_icon" "icon" $'\uf026' "Output device icon"

    # Colors (semantic names resolved via theme)
    declare_option "accent_color" "color" "secondary" "Content background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}
```

**Getting Option Values - `get_option()`:**

Use `get_option "name"` instead of `get_tmux_option` for declared options:

```bash
# Old pattern (still works but deprecated for declared options):
local show=$(get_tmux_option "@powerkit_plugin_example_show" "$POWERKIT_PLUGIN_EXAMPLE_SHOW")

# New pattern (recommended):
local show=$(get_option "show")
```

**How `get_option()` Works:**

1. Checks in-memory cache for previously resolved value
2. Searches declared options for default and type info
3. Falls back to `POWERKIT_PLUGIN_<NAME>_<OPTION>` variable
4. Gets value from tmux option `@powerkit_plugin_<plugin>_<option>`
5. Applies type validation (number, bool)
6. Caches and returns the resolved value

**Benefits of `get_option()`:**

- **Lazy loading**: Values fetched only when needed
- **Caching**: Subsequent calls return cached value (no tmux call)
- **Type validation**: Numbers validated, bools normalized to `true`/`false`
- **Automatic lookup**: Builds tmux option name from plugin context
- **Fallback chain**: Tmux option → declared default → defaults.sh variable

**Internal Implementation Details:**

The options system uses the following internal structures (in `plugin_helpers.sh`):

- `_PLUGIN_OPTIONS[plugin]` - Stores declared options as semicolon-separated entries
- `_PLUGIN_OPTIONS_CACHE[plugin_option]` - Caches resolved values
- `_CURRENT_PLUGIN_NAME` - Set by `plugin_init()` for option context
- `_OPT_DELIM` (`\x1F`) - ASCII Unit Separator used as field delimiter

Each option entry format: `name<0x1F>type<0x1F>default<0x1F>description`

**Utility Functions for Options:**

```bash
# Clear cached options (useful for testing)
clear_options_cache [plugin_name]

# Get all declared options for a plugin (for options viewer)
get_plugin_declared_options <plugin_name>

# Check if plugin has declared options
has_declared_options <plugin_name>
```

**Dependency Check Contract (`plugin_check_dependencies`):**

Every plugin SHOULD implement this function to declare its external dependencies.
This allows the system to check dependencies before loading and provide helpful error messages.

```bash
plugin_check_dependencies() {
    # Required dependencies (plugin won't work without these)
    require_cmd "curl" || return 1
    require_cmd "jq" || return 1

    # Optional dependencies (plugin works but with reduced features)
    require_cmd "fzf" 1  # 1 = optional, won't fail if missing

    # Alternative dependencies (need at least one)
    require_any_cmd "nvidia-smi" "rocm-smi" || return 1

    # Platform-specific dependencies
    if is_linux; then
        require_cmd "sensors" || return 1
    fi

    return 0
}
```

**Dependency Check Functions** (use ONLY in `plugin_check_dependencies()`):
- `require_cmd "cmd"` - Returns 1 if command missing (fails check)
- `require_cmd "cmd" 1` - Logs warning but returns 0 (optional)
- `require_any_cmd "cmd1" "cmd2" ...` - Returns 0 if ANY command exists

**Runtime Command Check** (use in plugin logic):
- `has_cmd "cmd"` - Returns 0 if exists, 1 if not (no side effects)

**IMPORTANT:** Never use `require_cmd` in plugin logic (e.g., `detect_backend()`, `load_plugin()`).
Use `has_cmd` instead, as `require_cmd` modifies global dependency arrays and is only for the contract.

**Plugin Types:**

- `static` - Always visible, no threshold colors
  - Examples: datetime, hostname, uptime, volume
  - Use when: Plugin shows static/informational data that doesn't need color changes or visibility control

- `conditional` - Can be hidden and/or have threshold colors
  - Examples: cpu, memory, disk, battery, network, git, packages
  - Use when: Plugin may need to hide itself OR change colors based on values
  - Supports `threshold_mode` option for automatic threshold colors
  - Use `threshold_plugin_display_info()` helper for standard threshold behavior

**Threshold Options (for `conditional` plugins):**

Plugins that display numeric values can declare threshold options:

```bash
plugin_declare_options() {
    # ... other options ...

    # Thresholds
    declare_option "threshold_mode" "string" "normal" "Threshold mode (none|normal|inverted)"
    declare_option "warning_threshold" "number" "70" "Warning threshold percentage"
    declare_option "critical_threshold" "number" "90" "Critical threshold percentage"
    declare_option "show_only_warning" "bool" "false" "Only show when threshold exceeded"
}
```

**Threshold Modes:**
- `none` - No automatic threshold colors (plugin handles manually or not at all)
- `normal` - Higher value = worse (CPU, memory, disk usage)
- `inverted` - Lower value = worse (battery level)

**Framework Standard Visibility Options (`display_condition` / `display_threshold`):**

These options are **automatically available to ALL plugins** without needing to be declared.
They control plugin visibility based on severity state (info/warning/error), not numeric values.
Works automatically for any plugin using `threshold_plugin_display_info()`.

| Severity | Numeric | Description |
|----------|---------|-------------|
| `info` | 0 | Normal state (no threshold triggered) |
| `warning` | 1 | Warning threshold exceeded |
| `error` | 2 | Critical threshold exceeded |

| Condition | Description |
|-----------|-------------|
| `always` | Always show (default) |
| `eq` | Show only when severity equals threshold |
| `lt` | Show when severity is less than threshold |
| `lte` | Show when severity is less than or equal |
| `gt` | Show when severity is greater than threshold |
| `gte` | Show when severity is greater than or equal |

**Examples:**

```bash
# Always show (default behavior)
display_condition="always"  # or display_threshold=""

# Show only when critical
set -g @powerkit_plugin_cpu_display_condition "eq"
set -g @powerkit_plugin_cpu_display_threshold "error"

# Show when warning OR error (severity > info)
set -g @powerkit_plugin_memory_display_condition "gt"
set -g @powerkit_plugin_memory_display_threshold "info"

# Show when NOT critical (severity < error)
set -g @powerkit_plugin_disk_display_condition "lt"
set -g @powerkit_plugin_disk_display_threshold "error"
```

**Using `threshold_plugin_display_info()`:**

```bash
# Store numeric value during computation
_MY_PLUGIN_LAST_VALUE=""

plugin_get_display_info() {
    threshold_plugin_display_info "${1:-}" "$_MY_PLUGIN_LAST_VALUE"
}

_compute_my_plugin() {
    local value=75  # computed value
    _MY_PLUGIN_LAST_VALUE="$value"  # store for threshold check
    printf '%d%%' "$value"
}
```

The helper automatically:
1. Hides plugin if content is empty/N/A
2. Calculates current severity based on value and thresholds
3. Applies `display_condition`/`display_threshold` visibility rules
4. Hides plugin if `show_only_warning=true` and value below threshold (legacy)
5. Applies warning/critical colors based on severity
6. Returns proper `build_display_info` output

**Note:** The `dynamic` type is deprecated. Use `conditional` with `threshold_mode="normal"` instead.

**Complete Example Plugin (audiodevices pattern):**

```bash
#!/usr/bin/env bash
# Plugin: example - Brief description of what this plugin does
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_check_dependencies() {
    # Required dependencies (plugin won't work without)
    require_cmd "curl" || return 1

    # Optional dependencies (reduced features without)
    require_cmd "jq" 1  # 1 = optional

    return 0
}

# =============================================================================
# Plugin Contract: Options Declaration
# =============================================================================

plugin_declare_options() {
    # Behavior
    declare_option "show" "string" "both" "Display mode (off|simple|detailed|both)"
    declare_option "max_length" "number" "0" "Max text length (0=unlimited)"
    declare_option "separator" "string" " | " "Separator between items"
    declare_option "show_icons" "bool" "false" "Show icons next to items"

    # Keybindings
    declare_option "selector_key" "key" "C-e" "Key for selector popup"

    # Icons
    declare_option "icon" "icon" $'\uf0e8' "Plugin icon"
    declare_option "item_icon" "icon" $'\uf111' "Icon for items"

    # Colors
    declare_option "accent_color" "color" "secondary" "Background color"
    declare_option "accent_color_icon" "color" "active" "Icon background color"

    # Cache
    declare_option "cache_ttl" "number" "30" "Cache duration in seconds"
}

# =============================================================================
# Initialize Plugin (auto-calls dependencies and options contracts)
# =============================================================================

plugin_init "example"

# =============================================================================
# Plugin Logic
# =============================================================================

get_data() {
    # Use has_cmd for runtime checks (NOT require_cmd!)
    if has_cmd jq; then
        safe_curl "https://api.example.com/data" 5 | jq -r '.value'
    else
        safe_curl "https://api.example.com/data" 5
    fi
}

get_cached_data() {
    local val
    if val=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        echo "$val"
    else
        local result
        result=$(get_data)
        cache_set "$CACHE_KEY" "$result"
        echo "$result"
    fi
}

# =============================================================================
# Plugin Contract: Display Info
# =============================================================================

plugin_get_display_info() {
    local show
    show=$(get_option "show")

    if [[ "$show" == "off" ]]; then
        echo "0:::"
        return
    fi

    local icon
    icon=$(get_option "icon")

    echo "1:::${icon}"
}

# =============================================================================
# Plugin Contract: Keybindings (optional)
# =============================================================================

setup_keybindings() {
    local selector_key
    selector_key=$(get_option "selector_key")

    local script="${ROOT_DIR%/plugin}/helpers/example_selector.sh"
    [[ -n "$selector_key" ]] && tmux bind-key "$selector_key" run-shell "bash '$script'"
}

# =============================================================================
# Plugin Contract: Load Plugin (main output)
# =============================================================================

load_plugin() {
    local show max_len show_icons
    show=$(get_option "show")
    max_len=$(get_option "max_length")
    show_icons=$(get_option "show_icons")

    [[ "$show" == "off" ]] && return

    local data item_icon parts=()
    data=$(get_cached_data)

    if [[ "$show_icons" == "true" ]]; then
        item_icon=$(get_option "item_icon")
        data="${item_icon} ${data}"
    fi

    data=$(truncate_text "$data" "$max_len")
    parts+=("$data")

    if [[ ${#parts[@]} -gt 0 ]]; then
        local sep
        sep=$(get_option "separator")
        join_with_separator "$sep" "${parts[@]}"
    fi
}

# =============================================================================
# Entry Point
# =============================================================================

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
```

**Available Plugins (42+):**

| Category | Plugins |
|----------|---------|
| Time | datetime, timezones |
| System | cpu, gpu, memory, disk, loadavg, temperature, fan, uptime, brightness, iops |
| Network | network, wifi, vpn, external_ip, ping, ssh, bluetooth, weather |
| Development | git, github, gitlab, bitbucket, kubernetes, cloud, cloudstatus, terraform, jira |
| Security | smartkey, bitwarden |
| Media | audiodevices, microphone, nowplaying, volume, camera |
| Packages | packages |
| Info | battery, hostname |
| Productivity | pomodoro |
| Finance | crypto, stocks |
| External | `external()` - integrate external tmux plugins |

### Configuration Options

All options use `@powerkit_*` prefix:

```bash
# Core
@powerkit_theme              # Theme name (ayu, catppuccin, dracula, everforest, github, gruvbox, kanagawa, kiribyte, nord, onedark, rose-pine, solarized, tokyo-night, custom)
@powerkit_theme_variant      # Variant (depends on theme - see theme list below)
@powerkit_custom_theme_path  # Path to custom theme file (required when @powerkit_theme is "custom")
@powerkit_plugins            # Comma-separated plugin list
@powerkit_transparent        # true/false

# Separators
@powerkit_separator_style    # rounded (pill) or normal (arrows)
@powerkit_elements_spacing   # false (default), both, windows, plugins - adds visual gaps between elements
@powerkit_left_separator
@powerkit_right_separator

# Session/Window
@powerkit_session_icon       # auto, or custom icon
@powerkit_active_window_*
@powerkit_inactive_window_*

# Per-plugin options
@powerkit_plugin_<name>_icon
@powerkit_plugin_<name>_accent_color
@powerkit_plugin_<name>_accent_color_icon
@powerkit_plugin_<name>_cache_ttl
@powerkit_plugin_<name>_show           # on/off - enable/disable plugin
@powerkit_plugin_<name>_*              # Plugin-specific options

# Telemetry (optional performance tracking)
@powerkit_telemetry          # true/false - enable performance telemetry
@powerkit_telemetry_log_file # Custom telemetry log file path
@powerkit_telemetry_slow_threshold  # Milliseconds to consider plugin "slow" (default: 500)

# Helper keybindings
@powerkit_options_key        # Key for options viewer (default: C-e)
@powerkit_keybindings_key    # Key for keybindings viewer (default: C-y)
@powerkit_theme_selector_key # Key for theme selector (default: C-r)
```

### External Plugins

Integrate external tmux plugins with PowerKit styling:

```bash
# Format: external("icon"|"content"|"accent"|"accent_icon"|"ttl")
external("🐏"|"$(~/.../ram_percentage.sh)"|"warning"|"warning-strong"|"30")
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| icon | Yes | - | Nerd Font icon |
| content | Yes | - | `$(command)` or `#(command)` to execute |
| accent | No | secondary | Background color for content |
| accent_icon | No | active | Background color for icon |
| ttl | No | 0 | Cache duration in seconds |

## Key Implementation Details

### Semantic Color System

Colors are defined semantically and resolved at runtime:

1. User sets: `@powerkit_plugin_cpu_accent_color 'warning'`
2. Theme defines: `THEME_COLORS[warning]="#e0af68"`
3. `get_powerkit_color("warning")` returns `#e0af68`

This allows:

- Theme switching without reconfiguring plugins
- Consistent colors across all plugins
- User customization with meaningful names

### Plugin Display Info Format

`plugin_get_display_info()` returns: `visible:accent_color:accent_color_icon:icon`

- `visible`: `1` to show, `0` to hide
- `accent_color`: Semantic color for content background
- `accent_color_icon`: Semantic color for icon background
- `icon`: Icon character to display

### Threshold Colors

All threshold handling is now managed by plugins themselves using the unified threshold system.

**Using `threshold_plugin_display_info()` (Recommended):**

- Declare threshold options in `plugin_declare_options()`
- Use `threshold_plugin_display_info()` in `plugin_get_display_info()`
- Supports `normal` (higher=worse) and `inverted` (lower=worse) modes
- Supports `show_only_warning` option to hide plugin when below threshold
- Examples: cpu, memory, disk (normal mode), battery (inverted mode)

**Custom Threshold Logic:**

- Plugin implements its own logic in `plugin_get_display_info()`
- Use `apply_threshold_colors()` helper for standard threshold color calculation
- Plugin returns explicit colors via `build_display_info()`
- Examples:
  - Temperature plugin: implements Celsius/Fahrenheit-aware thresholds
  - Loadavg plugin: implements CPU core-aware threshold logic
  - cloudstatus plugin: uses severity markers (E:/W:) in cached content

**No Thresholds (informational plugins):**

- Plugin returns empty colors via `default_plugin_display_info()` or `build_display_info "1" "" "" ""`
- Examples: datetime, hostname, weather, git

### Cache Key Format

Cache files: `~/.cache/tmux-powerkit/<plugin_name>`

Plugins use their name as cache key with configurable TTL.

### Transparency Support

When `@powerkit_transparent` is `true`:

- Status bar uses `default` background
- Inverse separators are used between plugins
- Plugins float on transparent background

## Adding New Plugins

1. Create `src/plugin/<name>.sh`
2. Source `plugin_bootstrap.sh`
3. Call `plugin_init "<name>"`
4. Define `plugin_check_dependencies()` to declare external dependencies:

   ```bash
   plugin_check_dependencies() {
       require_cmd "curl" || return 1       # Required
       require_cmd "jq" 1                   # Optional
       require_any_cmd "cmd1" "cmd2" || return 1  # Need one of
       return 0
   }
   ```

5. Define required functions:
   - `plugin_get_type()` - `static`, `dynamic`, or `conditional`
   - `plugin_get_display_info()` - visibility and colors
   - `load_plugin()` - content output (use `has_cmd` for runtime checks, NOT `require_cmd`)
6. Add defaults to `src/defaults.sh`:

   ```bash
   POWERKIT_PLUGIN_<NAME>_ICON="..."
   POWERKIT_PLUGIN_<NAME>_ACCENT_COLOR="$_DEFAULT_ACCENT"
   POWERKIT_PLUGIN_<NAME>_ACCENT_COLOR_ICON="$_DEFAULT_ACCENT_ICON"
   POWERKIT_PLUGIN_<NAME>_CACHE_TTL="..."
   ```

7. Use semantic colors from `_DEFAULT_*` variables
8. Document in `wiki/<Name>.md`

## Adding New Themes

1. Create directory: `src/themes/<theme_name>/`
2. Create variant file: `src/themes/<theme_name>/<variant>.sh`
3. Define `THEME_COLORS` associative array with all semantic colors
4. Export: `export THEME_COLORS`

Required semantic colors:

- `background`, `surface`, `text`, `border`
- `primary`, `secondary`, `accent`
- `success`, `warning`, `error`, `info`
- `active`, `disabled`, `hover`, `focus`

## Performance Optimizations

- **Source guards**: Centralized in `source_guard.sh`, prevents multiple sourcing of modules
- **Batch tmux options**: All `@powerkit_*` options loaded in single tmux call via `_batch_load_tmux_options()`
- **Cached OS detection**: `_CACHED_OS` variable set once, avoids repeated `uname` calls
- **Bash regex over grep**: `extract_numeric()` uses `[[ =~ ]]` with `BASH_REMATCH` instead of forking grep
- **Pure bash hash**: `_string_hash()` avoids md5sum fork for cache key generation
- **File-based caching**: Plugins cache expensive operations to disk
- **Single execution**: Plugins sourced once, `load_plugin()` called
- **Semantic color caching**: Colors resolved once per render
- **Cache-based optimization**: File-based caching for expensive operations
- **Timeout protection**: External commands protected via `run_with_timeout()`
- **Safe curl**: Network requests with proper timeouts via `safe_curl()`
- **Audio backend caching**: `detect_audio_backend()` cached in `_AUDIO_BACKEND`
- **Telemetry system**: Optional performance tracking with `telemetry_plugin_start/end()`
- **DRY plugin defaults**: `_plugin_defaults()` function auto-applies standard colors

## Important Notes

- All scripts use `#!/usr/bin/env bash`
- Strict mode: `set -eu` (note: `pipefail` was removed - causes issues with `grep -q` in pipes)
- Options read via `get_tmux_option()` with defaults from `defaults.sh`
- Plugin colors use semantic names resolved via `get_powerkit_color()`
- Keybindings always set up even when plugin `show='off'`
- Battery plugin: threshold colors persist even when charging (intentional behavior)

## Theme Persistence

The selected theme persists across `tmux kill-server` via a cache file:

- **Cache file**: `~/.cache/tmux-powerkit/current_theme`
- **Format**: `theme/variant` (e.g., `tokyo-night/night`)
- **Loading order**: Cache file → tmux options → defaults
- **Implementation**: `load_powerkit_theme()` in `src/utils.sh` reads cache first
- **Theme selector**: `src/helpers/theme_selector.sh` saves selection to cache

## Available Themes and Variants

| Theme | Variants | Description |
|-------|----------|-------------|
| **ayu** | dark, light, mirage | Minimal with warm accents |
| **catppuccin** | frappe, latte, macchiato, mocha | Pastel colors, 4 flavors |
| **dracula** | dark | Classic purple/pink dark theme |
| **everforest** | dark, light | Green-based, easy on eyes |
| **github** | dark, light | GitHub's familiar colors |
| **gruvbox** | dark, light | Retro groove colors |
| **kanagawa** | dragon, lotus, wave | Japanese art inspired |
| **kiribyte** | dark, light | Soft pastel theme |
| **nord** | dark | Arctic, north-bluish colors |
| **onedark** | dark | Atom One Dark inspired |
| **rose-pine** | dawn, main, moon | All natural pine colors |
| **solarized** | dark, light | Ethan Schoonover's classic |
| **tokyo-night** | day, night, storm | Neo-Tokyo inspired |

## Code Style Guidelines

### Variable Naming Conventions

- **Plugin names**: Use `plugin_name` for the raw name, `plugin_name_normalized` for uppercase with underscores
- **Colors**: Use descriptive suffixes for clarity
  - `accent` or `accent_bg` - background color value
  - `accent_icon` or `accent_icon_bg` - icon background color value
  - `accent_strong` - emphasized/bold version of accent color
  - Avoid ambiguous names like `cfg_accent` without context
- **Temporary variables**: Use descriptive names over single letters
  - Good: `result`, `threshold_value`, `file_mtime`
  - Avoid: `r`, `t`, `x` (except for loop counters `i`, `j`)
- **Boolean/state variables**: Use clear yes/no names
  - Good: `is_critical`, `cache_hit`, `has_threshold`
  - Avoid: `state`, `flag`, `check`

### Function Naming

- **Public functions**: Use verb-noun pattern (`get_file_mtime`, `apply_threshold_colors`)
- **Private/internal functions**: Prefix with **single** underscore (`_process_external_plugin`, `_string_hash`)
- **Predicates**: Start with `is_` or `has_` (`is_macos`, `has_threshold`)

**IMPORTANT: Never use double underscores (`__`) for function names.** This is a common source of bugs where `__function_name()` is defined but `_function_name()` is called, causing "command not found" errors.

```bash
# ✓ CORRECT: Single underscore for internal functions
_get_data() { ... }
_compute_result() { ... }

# ✗ WRONG: Double underscore (causes bugs!)
__get_data() { ... }  # Will break if called as _get_data
```

### Plugin Standard Header Format

Every plugin MUST include a standardized header comment:

```bash
#!/usr/bin/env bash
# =============================================================================
# Plugin: plugin_name
# Description: Brief description of what this plugin does
# Type: static|dynamic|conditional (with explanation in parentheses)
# Dependencies: list dependencies or "None"
# =============================================================================
```

**Example:**

```bash
#!/usr/bin/env bash
# =============================================================================
# Plugin: cpu
# Description: Display CPU usage percentage
# Type: dynamic (supports automatic threshold colors)
# Dependencies: None (uses /proc/stat on Linux, iostat/ps on macOS)
# =============================================================================
```

**Section Organization:**

Plugins should organize their code into clearly marked sections:

```bash
# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() { ... }

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() { ... }

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { ... }
plugin_get_display_info() { ... }

# =============================================================================
# Helper Functions (optional)
# =============================================================================

_internal_helper() { ... }

# =============================================================================
# Main Logic
# =============================================================================

_compute_data() { ... }
load_plugin() { ... }
```

### Error Handling Patterns

**Standardized patterns for consistent error handling:**

```bash
# 1. Silent failure with fallback value (stat, calculations)
size=$(stat -f%z "$file" 2>/dev/null || echo 0)
mtime=$(stat -c "%Y" "$file" 2>/dev/null || printf '-1')

# 2. Command that should never fail the script (tmux display, cleanup)
tmux display-message "Message" 2>/dev/null || true
rm -f "$temp_file" 2>/dev/null || true

# 3. Silent command existence check (&&, ||)
command -v apt &>/dev/null && echo "apt available"

# 4. Function with error return (validation, file checks)
[[ ! -f "$file" ]] && { log_error "source" "File not found"; return 1; }

# 5. Named constants with fallbacks (prefer over hardcoded values)
timeout="${_DEFAULT_TIMEOUT_SHORT:-5}"
size_limit="${POWERKIT_BYTE_MB:-1048576}"
```

**Guidelines:**

- Use `2>/dev/null` to suppress stderr when errors are expected and handled
- Use `&>/dev/null` only for command existence checks
- Always provide fallback values for critical operations (`|| echo 0`, `|| printf '-1'`)
- Use `|| true` for non-critical operations that shouldn't fail the script
- Log errors with `log_error()` before returning from functions
- Prefer named constants with `${VAR:-default}` pattern over magic numbers

## Known Issues / Gotchas

- **`set -o pipefail`**: Do NOT use in scripts that pipe to `grep -q`. When grep finds a match and exits early, the pipe breaks and pipefail treats this as an error, causing the entire script to fail.
- **Source order matters**: Always source `source_guard.sh` before any other module. The dependency order is documented in `init.sh`.
