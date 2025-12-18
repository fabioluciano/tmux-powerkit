# CLAUDE.md

This file providdes guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerKit is a modular tmux status bar framework (formerly tmux-tokyo-night). It provides 37+ plugins for displaying system information with a semantic color system that works across 14 themes (with 25+ variants). Distributed through TPM (Tmux Plugin Manager).

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

# Available test types:
# - syntax: bash -n validation
# - source: file can be sourced
# - functions: required functions exist (plugin_get_type, plugin_get_display_info, load_plugin)
# - display_info: output format validation
# - caching: cache functions work correctly
# - shellcheck: static analysis
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
- `cache_exists(key)` - Check if cache file exists (ignores TTL)
- `cache_size(key)` - Get cache file size in bytes
- `cache_list()` - List all cache keys
- `cache_total_size()` - Get total cache directory size
- `cache_invalidate_pattern(pattern)` - Invalidate caches matching glob pattern
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
- Sources: `source_guard.sh` → `defaults.sh` → `utils.sh` → `cache.sh`
- Uses `set -eu` (note: `pipefail` removed due to issues with `grep -q` in pipes)

**`src/plugin_bootstrap.sh`** - Plugin Bootstrap

- Common initialization for all plugins
- Sets up `ROOT_DIR`, sources utilities via `init.sh`
- Provides `plugin_init(name)` function

**`src/plugin_helpers.sh`** - Plugin Helper Functions

- **Dependency Checking:**
  - `require_cmd(cmd, optional)` - Check if command exists (logs if missing)
  - `require_any_cmd(cmd1, cmd2, ...)` - Check if ANY command exists
  - `check_dependencies(cmd1, cmd2, ...)` - Check multiple dependencies
  - `get_missing_deps()` - Get list of missing dependencies as string
- **Timeout & Safe Execution:**
  - `run_with_timeout(seconds, cmd...)` - Run command with timeout
  - `safe_curl(url, timeout, args...)` - Safe curl with error handling
- **Configuration Validation:**
  - `validate_range(value, min, max, default)` - Validate numeric range
  - `validate_option(value, default, opt1, opt2, ...)` - Validate against options
  - `validate_bool(value, default)` - Validate boolean value
- **Threshold Colors:**
  - `apply_threshold_colors(value, plugin, invert)` - Apply warning/critical colors
- **API & Audio:**
  - `make_api_call(url, auth_type, token)` - Authenticated API call
  - `detect_audio_backend()` - Detect macos/pipewire/pulseaudio/alsa
- **Lazy Loading:**
  - `should_load_plugin(name)` - Check if plugin should load
  - `precheck_plugin(name)` - Precheck plugin requirements
  - `get_plugin_priority(name)` - Get plugin load priority
  - `defer_plugin_load(name, callback)` - Deferred execution wrapper

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

### Plugin System

**Plugin Structure (`src/plugin/*.sh`):**

1. Source `plugin_bootstrap.sh`
2. Call `plugin_init "name"` to set up cache key and TTL
3. Define `plugin_get_type()` - returns `static`, `dynamic`, or `conditional`
4. Define `plugin_get_display_info()` - returns `visible:accent:accent_icon:icon`
5. Define `load_plugin()` - outputs the display content
6. Optional: `setup_keybindings()` for interactive features

**Plugin Types:**

- `static` - Always visible, content doesn't change colors based on value
- `dynamic` - Content can trigger threshold colors (warning/error)
- `conditional` - Can be hidden based on conditions (e.g., battery when full)

**Example Plugin:**

```bash
#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "example"

plugin_get_type() { printf 'static'; }

plugin_get_display_info() {
    echo "1:secondary:active:󰋼"
}

load_plugin() {
    echo "Hello World"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
```

**Available Plugins (37+):**

| Category | Plugins |
|----------|---------|
| Time | datetime, timezones |
| System | cpu, gpu, memory, disk, loadavg, temperature, fan, uptime, brightness |
| Network | network, wifi, vpn, external_ip, ping, ssh, bluetooth, weather |
| Development | git, github, gitlab, bitbucket, kubernetes, cloud, cloudstatus, terraform |
| Security | smartkey, bitwarden |
| Media | audiodevices, microphone, nowplaying, volume, camera |
| Packages | packages |
| Info | battery, hostname |
| External | `external()` - integrate external tmux plugins |

### Configuration Options

All options use `@powerkit_*` prefix:

```bash
# Core
@powerkit_theme              # Theme name (ayu, catppuccin, dracula, everforest, github, gruvbox, kanagawa, kiribyte, nord, onedark, rose-pine, solarized, tokyo-night)
@powerkit_theme_variant      # Variant (depends on theme - see theme list below)
@powerkit_plugins            # Comma-separated plugin list
@powerkit_transparent        # true/false

# Separators
@powerkit_separator_style    # rounded (pill) or normal (arrows)
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
@powerkit_plugin_<name>_lazy           # on/off - enable lazy loading for plugin
@powerkit_plugin_<name>_priority       # load priority (lower = first)
@powerkit_plugin_<name>_*              # Plugin-specific options

# Lazy Loading (optional)
@powerkit_lazy_loading       # on/off - enable lazy loading system

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
4. Define required functions:
   - `plugin_get_type()` - `static` or `dynamic`
   - `plugin_get_display_info()` - visibility and colors
   - `load_plugin()` - content output
5. Add defaults to `src/defaults.sh`:

   ```bash
   POWERKIT_PLUGIN_<NAME>_ICON="..."
   POWERKIT_PLUGIN_<NAME>_ACCENT_COLOR="$_DEFAULT_ACCENT"
   POWERKIT_PLUGIN_<NAME>_ACCENT_COLOR_ICON="$_DEFAULT_ACCENT_ICON"
   POWERKIT_PLUGIN_<NAME>_CACHE_TTL="..."
   ```

6. Use semantic colors from `_DEFAULT_*` variables
7. Document in `wiki/<Name>.md`

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
- **Lazy loading**: Optional deferred plugin loading with priority system
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

## Known Issues / Gotchas

- **`set -o pipefail`**: Do NOT use in scripts that pipe to `grep -q`. When grep finds a match and exits early, the pipe breaks and pipefail treats this as an error, causing the entire script to fail.
- **Source order matters**: Always source `source_guard.sh` before any other module. The dependency order is documented in `init.sh`.
