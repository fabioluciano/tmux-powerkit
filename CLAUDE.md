# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerKit is a modular tmux status bar framework (formerly tmux-tokyo-night). It provides 36+ plugins for displaying system information with a semantic color system that works across multiple themes. Distributed through TPM (Tmux Plugin Manager).

## Development Commands

### Linting

```bash
# Run shellcheck on all shell scripts
shellcheck src/**/*.sh src/*.sh tmux-powerkit.tmux
```

Note: The project uses GitHub Actions to run shellcheck automatically on push/PR.

### Testing

Manual testing is required:

1. Install the plugin via TPM in a test tmux configuration
2. Source the plugin: `tmux source ~/.tmux.conf`
3. Verify visual appearance and plugin functionality
4. Test different themes and plugin combinations

## Architecture

### Entry Point

- `tmux-powerkit.tmux` - Main entry point called by TPM, delegates to `src/theme.sh`

### Core Components

**`src/defaults.sh`** - Centralized Default Values (DRY/KISS)

- Contains ALL default values in one place
- Uses semantic color names (`secondary`, `warning`, `error`, etc.)
- Source guard: `_POWERKIT_DEFAULTS_LOADED`
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

- `get_tmux_option(option, default)` - Retrieves tmux options with fallback
- `get_powerkit_color(semantic_name)` - Resolves semantic color to hex
- `load_powerkit_theme()` - Loads theme file and populates `POWERKIT_THEME_COLORS`
- `get_os()` / `is_macos()` / `is_linux()` - OS detection (cached)
- Status bar generation functions

**`src/cache.sh`** - Caching System

- `cache_get(key, ttl)` - Returns cached value if valid
- `cache_set(key, value)` - Stores value in cache
- `cache_clear_all()` - Clears all cached data
- Cache location: `$XDG_CACHE_HOME/tmux-powerkit/` or `~/.cache/tmux-powerkit/`

**`src/render_plugins.sh`** - Plugin Rendering

- Processes `@powerkit_plugins` option
- Builds status-right string with separators and colors
- Handles transparent mode
- Resolves semantic colors via `get_powerkit_color()`
- Handles external plugins with format: `EXTERNAL|icon|content|accent|accent_icon|ttl`
- Executes `$(command)` and `#(command)` in external plugin content
- Supports caching for external plugins via TTL parameter

**`src/plugin_bootstrap.sh`** - Plugin Bootstrap

- Common initialization for all plugins
- Sets up `ROOT_DIR`, sources utilities
- Provides `plugin_init(name)` function

### Theme System

Located in `src/themes/<theme>/<variant>.sh`:

```text
src/themes/
├── tokyo-night/
│   ├── night.sh
└── kiribyte/
    └── dark.sh
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
3. Define `plugin_get_type()` - returns `static` or `dynamic`
4. Define `plugin_get_display_info()` - returns `visible:accent:accent_icon:icon`
5. Define `load_plugin()` - outputs the display content
6. Optional: `setup_keybindings()` for interactive features

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

**Available Plugins (26+):**

| Category | Plugins |
|----------|---------|
| Time | datetime |
| System | cpu, memory, disk, loadavg, temperature, uptime, brightness |
| Network | network, wifi, vpn, external_ip, bluetooth, weather |
| Development | git, kubernetes, cloud |
| Security | smartkey |
| Media | audiodevices, microphone, nowplaying, volume, camera |
| Packages | packages |
| Info | battery, hostname |
| External | `external()` - integrate external tmux plugins |

### Configuration Options

All options use `@powerkit_*` prefix:

```bash
# Core
@powerkit_theme              # Theme name (tokyo-night, kiribyte)
@powerkit_theme_variant      # Variant (night, storm, moon, day, dark)
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
@powerkit_plugin_<name>_*    # Plugin-specific options
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

- **Source guards**: Prevent multiple sourcing of utilities
- **Cached OS detection**: `_CACHED_OS` variable set once
- **File-based caching**: Plugins cache expensive operations
- **Single execution**: Plugins sourced once, `load_plugin()` called
- **Semantic color caching**: Colors resolved once per render

## Important Notes

- All scripts use `#!/usr/bin/env bash`
- Strict mode in render_plugins.sh: `set -euo pipefail`
- Options read via `get_tmux_option()` with defaults from `defaults.sh`
- Plugin colors use semantic names resolved via `get_powerkit_color()`
- Keybindings always set up even when plugin `show='off'`
