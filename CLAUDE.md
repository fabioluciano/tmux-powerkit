# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Migration Summary

**Status**: ✅ COMPLETE - All 42 plugins migrated to contract system

### Migration Statistics

- **Total Plugins**: 42
- **Migration Date**: January 2025
- **Architecture**: Contract-based plugin system with strict separation of concerns
- **Lines of Code**: ~5,500 lines (plugins only)

### Migrated Plugins (Alphabetical)

1. **audiodevices** - Audio output device (macOS, SwitchAudioSource)
2. **battery** - Battery level with charge state (pmset/upower)
3. **bitbucket** - Pull requests count (API)
4. **bitwarden** - Vault lock status (bw CLI)
5. **bluetooth** - BT status + connected devices (blueutil/bluetoothctl)
6. **brightness** - Screen brightness (Linux only - sysfs/brightnessctl/light/xbacklight)
7. **camera** - Camera usage indicator (macOS, lsof)
8. **cloud** - Cloud provider profile (AWS/Azure/GCP)
9. **cloudstatus** - Service status monitoring (status APIs)
10. **cpu** - CPU usage with thresholds (sysctl/top)
11. **crypto** - Cryptocurrency prices (CoinGecko API)
12. **datetime** - Date/time with 15 format presets
13. **disk** - Disk usage with thresholds (df)
14. **external_ip** - Public IP address (ipify API)
15. **fan** - Fan speed (macOS: osx-cpu-temp/iStats, Linux: hwmon/dell_smm/thinkpad)
16. **git** - Branch + modified files status
17. **github** - Notifications/PRs/issues (gh CLI)
18. **gitlab** - Merge requests/todos (glab CLI)
19. **gpu** - GPU usage (NVIDIA: nvidia-smi, AMD: sysfs, Intel: frequency-based, macOS: powerkit-gpu)
20. **hostname** - System hostname
21. **iops** - Disk I/O operations (iostat)
22. **jira** - Assigned issues count (API)
23. **kubernetes** - Context + namespace (kubectl)
24. **loadavg** - Load average with cores (uptime)
25. **memory** - Memory usage with thresholds (vm_stat/free)
26. **microphone** - Mic mute status (macOS, osascript)
27. **network** - Upload/download speed (ifstat/netstat)
28. **nowplaying** - Current music track (Music/Spotify)
29. **packages** - Pending updates (brew/apt/yum/pacman)
30. **ping** - Network latency with thresholds
31. **pomodoro** - Timer with work/break phases
32. **smartkey** - Custom environment variable display
33. **ssh** - SSH session indicator
34. **stocks** - Stock prices (Yahoo Finance API)
35. **temperature** - CPU temperature (macOS, osx-cpu-temp)
36. **terraform** - Workspace indicator
37. **timezones** - Multi-timezone display
38. **uptime** - System uptime
39. **volume** - System volume (macOS, osascript)
40. **vpn** - VPN connection status (tun/tap interfaces)
41. **weather** - Weather from wttr.in
42. **wifi** - WiFi SSID + signal strength

### Plugin Categories

- **System Monitoring** (12): battery, cpu, disk, fan, gpu, iops, loadavg, memory, temperature, uptime, volume, brightness
- **Network** (7): external_ip, network, ping, vpn, weather, wifi, ssh
- **Development** (8): git, github, gitlab, bitbucket, jira, kubernetes, terraform, cloud
- **Media** (4): nowplaying, audiodevices, camera, microphone
- **Productivity** (5): datetime, timezones, pomodoro, smartkey, bitwarden
- **Financial** (2): crypto, stocks
- **Services** (4): cloudstatus, packages, bluetooth, hostname

### Platform-Specific Plugins

- **macOS only**: volume, temperature, camera, microphone, audiodevices
- **Linux only**: brightness
- **Cross-platform**: All other plugins (including fan and gpu with platform-specific backends)

---

## Project Overview

PowerKit is a contract-based tmux status bar framework with strict separation of concerns:

- **Core**: Orchestration, lifecycle, cache, options
- **Plugin**: Data + semantics ONLY (no UI)
- **Renderer**: ALL UI decisions (colors, icons, formatting)
- **Theme**: Color definitions ONLY

**Target**: Bash 4+ | **Architecture**: Contract-based plugin system

## Directory Structure

```text
tmux-powerkit/
├── tmux-powerkit.tmux              # TPM entry point
├── bin/
│   ├── powerkit-render             # Status-right renderer entry point
│   ├── powerkit-plugin             # Single plugin executor
│   ├── powerkit-icon               # Icon resolver
│   └── powerkit-binary-prompt      # Interactive macOS binary download prompt
├── src/
│   ├── core/                       # Core Framework
│   │   ├── bootstrap.sh            # Entry point, module loading
│   │   ├── lifecycle.sh            # Plugin lifecycle phases
│   │   ├── datastore.sh            # plugin_data_set/get/has/clear API
│   │   ├── cache.sh                # TTL-based cache (core-managed)
│   │   ├── options.sh              # Tmux options batch loader
│   │   ├── logger.sh               # Centralized logging
│   │   ├── guard.sh                # Source guard
│   │   ├── defaults.sh             # Default values and constants
│   │   ├── theme_loader.sh         # Theme loading
│   │   ├── color_generator.sh      # Generates variants (-lighter/-darker)
│   │   ├── color_palette.sh        # State/health → semantic color mapping
│   │   └── binary_manager.sh       # macOS native binary download manager
│   ├── utils/                      # Utility Functions
│   │   ├── platform.sh             # OS/distro detection
│   │   ├── strings.sh              # String manipulation
│   │   ├── numbers.sh              # Numeric utilities
│   │   ├── filesystem.sh           # File operations
│   │   └── clipboard.sh            # Clipboard operations
│   ├── contract/                   # Contract Definitions
│   │   ├── plugin_contract.sh      # Plugin interface + helpers
│   │   ├── session_contract.sh     # Session interface
│   │   └── window_contract.sh      # Window interface
│   ├── renderer/                   # Rendering System
│   │   ├── segment_builder.sh      # Build status segments
│   │   ├── separator.sh            # Powerline separators
│   │   ├── color_resolver.sh       # state/health → color
│   │   ├── icon_resolver.sh        # OS/session/window icons
│   │   └── format_builder.sh       # tmux format strings
│   ├── plugins/                    # Status Bar Plugins
│   │   └── battery.sh              # Reference implementation
│   └── themes/                     # Theme Files
│       └── tokyo-night/night.sh
```

## Bootstrap System

The bootstrap system loads modules in strict dependency order:

```bash
# Module loading order (critical - do not reorder)
1. guard.sh           # Source guard (must be first)
2. defaults.sh        # Default values (no deps except guard)
3. logger.sh          # Logging system
4. datastore.sh       # Plugin data API (depends on logger)
5. options.sh         # Tmux options batch loader (depends on logger)
6. cache.sh           # TTL-based cache (depends on logger)
7. color_generator.sh # Color variants (depends on logger)
8. color_palette.sh   # State/health colors (depends on color_generator)
9. theme_loader.sh    # Theme loading (depends on color_generator, options, cache)
10. lifecycle.sh      # Plugin lifecycle (depends on all above)
11. binary_manager.sh # macOS binary download (depends on cache, logger, platform)
```

### Bootstrap Functions

```bash
powerkit_bootstrap()          # Full bootstrap with theme and keybindings
powerkit_bootstrap_minimal()  # Core + utils only (no plugins)
powerkit_run()                # Bootstrap + run full lifecycle
```

## Plugin Contract

Plugins provide **data and semantics**, NOT UI decisions.

### Mandatory Functions

```bash
plugin_collect()           # Collect data using plugin_data_set() only
plugin_render()            # TEXT ONLY - no colors, no icons, no formatting
plugin_get_icon()          # Returns icon based on plugin's internal data
plugin_get_state()         # "inactive" | "active" | "degraded" | "failed"
plugin_get_health()        # "ok" | "good" | "info" | "warning" | "error"
```

### Functions with Defaults (override only if needed)

```bash
plugin_get_content_type()  # Default: "dynamic" (most plugins)
plugin_get_presence()      # Default: "conditional" (hide when inactive)
plugin_get_context()       # Default: no-op (empty context)
plugin_check_dependencies()# Default: return 0 (no dependencies)
plugin_get_metadata()      # Default: no-op (id derived from filename)
```

### Optional Functions (no default)

```bash
plugin_declare_options()     # Declare configurable options
plugin_setup_keybindings()   # Setup tmux keybindings
```

### Contract Rules

1. **Plugin NEVER decides colors** - Colors are determined by renderer based on state/health
2. **Plugin NEVER outputs formatting** - `plugin_render()` returns plain text only
3. **Plugin decides icon based on internal data** - NOT based on health
4. **`plugin_collect()` can run external commands**
5. **`plugin_render()` CANNOT run external commands** - must use cached data
6. **Platform-unsupported plugins return `inactive` state** - e.g., brightness on macOS

### Valid States and Health

```bash
# States (controls visibility for conditional plugins)
PLUGIN_STATES=("inactive" "active" "degraded" "failed")
# - inactive: Plugin hidden (resource doesn't exist, platform unsupported)
# - active: Plugin visible and working
# - degraded: Plugin visible but with reduced functionality
# - failed: Plugin visible with error indication

# Health levels (controls colors)
PLUGIN_HEALTH=("ok" "good" "info" "warning" "error")
# - ok: Normal operation (neutral)
# - good: Better than ok, positive state (e.g., connected, synced)
# - info: Informational state (e.g., charging, on)
# - warning: Needs attention (threshold reached)
# - error: Critical condition

# Content types
PLUGIN_CONTENT_TYPES=("static" "dynamic")

# Presence modes
PLUGIN_PRESENCE=("always" "conditional")
# - always: Always show plugin regardless of state
# - conditional: Hide plugin when state is "inactive"

# Stale indicator (controls visual dimming)
# - stale=0: Fresh data (normal colors)
# - stale=1: Cached data being displayed (colors use -darker variant)
```

### Health Precedence

```bash
# Maps health to numeric level for comparison (from registry.sh)
# Uses HEALTH_PRECEDENCE associative array: info=-1, ok=0, good=1, warning=2, error=3
get_health_level() {
    local health="$1"
    echo "${HEALTH_PRECEDENCE[$health]:-0}"
}
```

## Separation of Concerns

| Module | Responsibility | Can Have | Cannot Have |
|--------|---------------|----------|-------------|
| `src/core/` | Orchestration, lifecycle | Cache, options, logging | Colors, icons, formatting |
| `src/plugins/` | Data collection, semantics | state, health, context | Colors, formatting, UI logic |
| `src/renderer/` | UI rendering | Colors, icons, separators | Business logic, data collection |
| `src/themes/` | Color definitions | Base colors only | Logic, icons, functions |

### Data Flow

```text
Plugin                          Lifecycle                       Renderer
  │                                │                                │
  ├─ plugin_collect()              │                                │
  │    └─ plugin_data_set()        │                                │
  │                                │                                │
  ├─ plugin_get_state() ──────────►│                                │
  ├─ plugin_get_health() ─────────►├── stale=0|1 ─────────────────►│─► resolve_plugin_colors_full()
  ├─ plugin_get_context() ────────►│   (from cache state)           │
  │                                │                                │
  ├─ plugin_render() ─────────────►│──────────────────────────────►│─► render_plugin_segment()
  ├─ plugin_get_icon() ───────────►│                                │
  │                                │                                │
  └─ Returns: DATA only            └─ Returns: 5-field output       └─► Returns: Formatted tmux string
```

**Lifecycle Output Format**: `icon<US>content<US>state<US>health<US>stale`

- Delimiter: `\x1f` (Unit Separator)
- `stale`: 0=fresh, 1=cached data (triggers `-darker` color variant)

## Datastore API

```bash
plugin_data_set "key" "value"   # Store in plugin scope
plugin_data_get "key"           # Retrieve value
plugin_data_has "key"           # Check existence
plugin_data_clear               # Clear plugin scope
```

**Implementation**: Associative array `_DATASTORE["plugin:key"]`

## Cache System

Core-managed cache with performance optimizations:

```bash
cache_get "key" "ttl"           # Get cached value
cache_set "key" "value"         # Store value
cache_valid "key" "ttl"         # Check if valid
cache_age "key"                 # Get age in seconds
cache_reset_cycle               # Reset per-render cycle cache
cache_clear "key"               # Clear specific entry
cache_clear_all                 # Clear all cache
```

**Performance Features**:

- In-memory cache per render cycle (avoids disk reads)
- Cached timestamp per cycle (single `date +%s` call)
- Cache location: `$XDG_CACHE_HOME/tmux-powerkit/data` or `~/.cache/tmux-powerkit/data`

### Stale-While-Revalidate (Lazy Loading)

The lifecycle implements a stale-while-revalidate pattern for plugin data:

| Cache State | Age | Behavior | Visual |
|-------------|-----|----------|--------|
| **FRESH** | ≤ TTL | Return cached data immediately | Normal colors |
| **STALE** | TTL < age ≤ TTL×3 | Return cached + background refresh | `-darker` variant |
| **VERY OLD** | > TTL×3 | Synchronous (blocking) refresh | Normal after refresh |

**Configuration** (in `tmux.conf`):

```bash
set -g @powerkit_lazy_loading "true"           # Enable stale-while-revalidate
set -g @powerkit_stale_multiplier "3"          # Max age = TTL × multiplier
set -g @powerkit_stale_color_variant "-darker" # Color variant for stale data
```

**Plugin Implementation**:

Plugins return `1` from `plugin_collect()` when data collection fails. The lifecycle preserves the previous cache and marks the output as stale:

```bash
plugin_collect() {
    local result
    result=$(fetch_api_data) || return 1  # Let lifecycle handle stale
    plugin_data_set "value" "$result"
}
```

**Visual Indication**:

When `stale=1`, the renderer applies `@powerkit_stale_color_variant` (default: `-darker`) to background colors, providing visual feedback that cached data is being displayed.

## Options API

```bash
# Declare options in plugin_declare_options()
declare_option "name" "type" "default" "description"

# Get option value (with caching and validation)
get_option "name"

# Tmux option functions
get_tmux_option "option" "default"
set_tmux_option "option" "value"
```

**Option Types**: `string`, `number`, `bool`, `color`, `icon`, `key`, `path`, `enum`

## Dependency Checking

Use in `plugin_check_dependencies()` only:

```bash
# Required dependency (fails if missing)
require_cmd "curl" || return 1

# Optional dependency (logs warning, doesn't fail)
require_cmd "jq" 1

# At least one of these (alternative dependencies)
require_any_cmd "nvidia-smi" "rocm-smi" || return 1

# Check multiple at once
check_dependencies "curl" "jq" || return 1
```

**Runtime check** (use in plugin logic):

```bash
# has_cmd does NOT track dependencies - use for runtime decisions
has_cmd "fzf" && use_fzf_feature
```

## macOS Native Binary System

Some plugins require native macOS binaries for hardware access (GPU, temperature, microphone, etc.). These binaries are **not included in the repository** - they are downloaded on-demand from GitHub releases.

### Affected Plugins

| Plugin | Binary | Purpose |
|--------|--------|---------|
| `gpu` | `powerkit-gpu` | GPU usage via IOKit |
| `temperature` | `powerkit-temperature` | CPU temp via SMC |
| `microphone` | `powerkit-microphone` | Mic mute state |
| `nowplaying` | `powerkit-nowplaying` | Current track info |
| `brightness` | `powerkit-brightness` | Screen brightness |

### How It Works

1. Plugin calls `require_macos_binary "binary_name" "plugin_name"` in `plugin_check_dependencies()`
2. If binary doesn't exist in `${POWERKIT_ROOT}/bin/`, it's tracked for batch prompt
3. After all plugins are collected, `binary_prompt_missing()` shows a single popup listing all missing binaries
4. User chooses: download all, select individually, or skip
5. Decision is cached for 24h (skip won't re-prompt until cache expires)

### Plugin Usage

```bash
plugin_check_dependencies() {
    # Check for native macOS binary (downloaded on-demand)
    require_macos_binary "powerkit-gpu" "gpu" || return 1
    return 0
}
```

### Binary Manager API

```bash
# Check if binary exists
binary_exists "powerkit-gpu"           # Returns: 0 if exists and executable

# Require binary (tracks for prompt if missing)
require_macos_binary "binary" "plugin" # Returns: 0 if available, 1 if not

# Download binary from GitHub releases
binary_download "powerkit-gpu"         # Returns: 0 on success

# Clear user decisions (allow re-prompting)
binary_clear_decision "powerkit-gpu"   # Clear single
binary_clear_all_decisions             # Clear all
```

### User Interaction

When binaries are missing, a popup appears via `tmux display-popup`:

```text
╔════════════════════════════════════════════════════════════════════╗
║                 PowerKit - Binary Download                          ║
╚════════════════════════════════════════════════════════════════════╝

The following plugins require native macOS binaries that are not
installed:

  • powerkit-gpu                (plugin: gpu)
  • powerkit-temperature        (plugin: temperature)

Download all binaries? [Y]es / [N]o / [S]elect:
```

### Binary Source Code

Native binaries are compiled from Swift source in `src/native/macos/`. Users can build manually if they prefer not to download pre-compiled binaries.

### Troubleshooting

```bash
# Clear all binary decisions (force re-prompt)
rm -f ~/.cache/tmux-powerkit/data/binary_decision_*

# Clear tracking files
rm -f /tmp/powerkit_missing_binaries /tmp/powerkit_binary_pending_all

# Remove binaries to force re-download
rm -f ~/.config/tmux/plugins/tmux-powerkit/bin/powerkit-{gpu,temperature,microphone,nowplaying,brightness}

# Reload tmux
tmux source ~/.tmux.conf
```

## Utility Libraries

### Platform Detection (`src/utils/platform.sh`)

```bash
# OS Detection
get_os()          # Returns: darwin, linux, freebsd
is_macos()        # Check if macOS
is_linux()        # Check if Linux
is_freebsd()      # Check if FreeBSD
is_wsl()          # Check if WSL

# Linux Distribution
get_distro()      # Returns: ubuntu, debian, fedora, arch, etc.
is_debian_based() # Ubuntu, Debian, Mint, Pop
is_fedora_based() # Fedora, CentOS, RHEL, Rocky
is_arch_based()   # Arch, Manjaro, EndeavourOS

# Architecture
get_arch()        # Returns: x86_64, arm64, etc.
is_64bit()
is_arm()

# Environment
is_in_tmux()      # Check if running inside tmux
is_interactive()  # Check if in terminal
get_terminal()    # Get terminal emulator name

# Command availability
has_cmd "git"     # Check if command exists
get_cmd_path "git"  # Get full path or empty
```

### String Utilities (`src/utils/strings.sh`)

```bash
# Truncation
truncate_text "text" 10           # Truncate to max length
truncate_words "text" 10 "…"      # Truncate at word boundary (no cut mid-word)
truncate_middle "text" 10         # Truncate with ellipsis in middle

# Joining
join_with_separator " | " "a" "b" "c"  # "a | b | c"
join_non_empty " " "a" "" "b"          # "a b"

# Whitespace
trim "  hello  "        # "hello"
trim_left "  hello"     # "hello"
trim_right "hello  "    # "hello"
collapse_spaces "a  b"  # "a b"

# Case conversion
to_lower "HELLO"        # "hello"
to_upper "hello"        # "HELLO"
capitalize "hello"      # "Hello"
to_title "hello world"  # "Hello World"

# Search and replace
contains "hello" "ell"  # true
starts_with "hello" "he"  # true
ends_with "hello" "lo"    # true
replace_first "a a" "a" "b"  # "b a"
replace_all "a a" "a" "b"    # "b b"

# Validation
is_blank "   "         # true
is_identifier "my_var" # true
is_numeric "123"       # true

# Padding
pad_right "hi" 5       # "hi   "
pad_left "hi" 5        # "   hi"
center "hi" 10         # "    hi    "
```

### Number Utilities (`src/utils/numbers.sh`)

```bash
# Extraction
extract_numeric "CPU: 45%"      # "45"
extract_decimal "Load: 1.25"    # "1.25"
extract_all_numbers "1 2 3"     # "1 2 3"

# Formatting
format_number 1234567           # "1,234,567"
format_bytes 1073741824         # "1.0G"
format_percent 45.678 1         # "45.7%"
pad_number 5 2                  # "05"

# Range and validation
clamp 150 0 100                 # 100
in_range 50 0 100               # true
validate_number "abc" 10        # "10"

# Calculations
calc_percent 25 100             # "25"
calc_percent_decimal 25 100 2   # "25.00"
round 3.7                       # "4"
floor 3.7                       # "3"
ceiling 3.2                     # "4"

# Condition evaluation
evaluate_condition 50 ">" 25    # true
# Operators: >, >=, <, <=, ==, !=, gt, gte, lt, lte, eq, ne
```

## Separator System

### Available Styles

| Style | Right (▶) | Left (◀) | Unicode |
|-------|-----------|----------|---------|
| `normal` |  |  | E0B0/E0B2 |
| `rounded` |  |  | E0B4/E0B6 |
| `flame` |  |  | E0C0/E0C2 |
| `pixel` |  |  | E0C4/E0C6 |
| `honeycomb` |  |  | E0CC/E0CD |
| `none` | (empty) | (empty) | - |

### Configuration

```bash
@powerkit_separator_style "rounded"       # Main separator style
@powerkit_edge_separator_style "rounded" # Edge separators: end of windows, start of plugins (or "same")
@powerkit_elements_spacing "false"        # false, true, both, windows, plugins
```

### Separator Functions

```bash
get_separator_style()     # Get current style
get_left_separator()      # Get ◀ character
get_right_separator()     # Get ▶ character
get_final_separator()     # Get end-of-list separator

# Building separators
build_right_separator "prev_bg" "next_bg"  # For status-left, windows
build_left_separator "prev_bg" "next_bg"   # For status-right (plugins)
```

## Segment Builder Template System

### Template Variables

```bash
{sep_left}        # Left separator with colors
{sep_right}       # Right separator with colors
{sep_internal}    # Internal separator (icon→content)
{icon}            # Icon character
{icon_bg}         # Icon background color
{icon_fg}         # Icon foreground color
{content}         # Text content
{content_bg}      # Content background color
{content_fg}      # Content foreground color
{prev_bg}         # Previous element background
{next_bg}         # Next element background
{icon_section}    # Complete icon section with colors
{content_section} # Complete content section with colors
```

### Default Template

```bash
DEFAULT_SEGMENT_TEMPLATE='{sep_left}{icon_section}{sep_internal}{content_section}{sep_right}'
```

### Configuration

```bash
# Global template
@powerkit_segment_template "{sep_left}{icon_section}{content_section}"

# Per-plugin template
@powerkit_plugin_battery_template "{icon} {content}%"
```

## Theme System

Themes declare base colors only. Variants are auto-generated.

### Required Theme Colors

```bash
declare -A THEME_COLORS=(
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
    [info-base]="#7dcfff"
    [warning-base]="#e0af68"
    [error-base]="#f7768e"
    [disabled-base]="#565f89"

    # Messages
    [message-bg]="#1a1b26"
    [message-fg]="#c0caf5"
)
```

### Color Variant Generation

The system auto-generates 6 variants per base color:

| Variant | Direction | Percentage | Purpose |
|---------|-----------|------------|---------|
| `-light` | Toward white | +10% | Subtle lightening |
| `-lighter` | Toward white | +20% | Medium lightening |
| `-lightest` | Toward white | +55% | Strong lightening (text on dark) |
| `-dark` | Toward black | -10% | Subtle darkening |
| `-darker` | Toward black | -20% | Medium darkening (icons) |
| `-darkest` | Toward black | -55% | Strong darkening |

**Colors with variants** (defined in defaults.sh):

```bash
POWERKIT_COLORS_WITH_VARIANTS="window-active-base window-inactive-base ok-base good-base info-base warning-base error-base disabled-base"
```

### Color Resolution

```bash
resolve_color "ok-base"           # Get base color
resolve_color "ok-base-lighter"   # Get auto-generated variant
get_color "warning-base"          # From color_generator
```

## Health States and Colors

| Health | Meaning | Color Mapping |
|--------|---------|---------------|
| `ok` | Normal operation | `ok-base` (green) |
| `good` | Better than ok, positive state | `ok-base` (green) |
| `info` | Informational | `info-base` (blue) |
| `warning` | Needs attention | `warning-base` (yellow) |
| `error` | Critical/failed | `error-base` (red) |

| State | Meaning | Visibility |
|-------|---------|------------|
| `active` | Plugin working | Visible |
| `inactive` | No data/disabled/unsupported platform | Hidden (if conditional) |
| `degraded` | Partial function | Visible with warning |
| `failed` | Error occurred | Visible with error |

### State vs Health

- **State** controls **visibility** for conditional plugins
- **Health** controls **colors** via the color palette
- A plugin can be `active` with `error` health (visible but critical)
- A plugin with `inactive` state is hidden regardless of health

## Default Values

### Core Options

```bash
POWERKIT_DEFAULT_THEME="tokyo-night"
POWERKIT_DEFAULT_THEME_VARIANT="night"
POWERKIT_DEFAULT_TRANSPARENT="false"
POWERKIT_DEFAULT_PLUGINS="datetime,battery,cpu,memory,hostname,git"
POWERKIT_DEFAULT_PLUGIN_GROUP_COLORS="info-base-darker,window-active-base-darker,ok-base-darker,warning-base-darker,error-base-darker,disabled-base"
POWERKIT_DEFAULT_PLUGIN_GROUP_COLORS="info-base-darker,window-active-base-darker,ok-base-darker,warning-base-darker,error-base-darker,disabled-base"
POWERKIT_DEFAULT_STATUS_INTERVAL="5"
POWERKIT_DEFAULT_BAR_LAYOUT="single"                      # single or double (2 status lines)
POWERKIT_DEFAULT_STATUS_ORDER="session,plugins"           # Element rendering order
```

### Plugin Groups

Use `group(...)` syntax to visually group related plugins with a shared background color:

```bash
# Group related plugins
set -g @powerkit_plugins "group(cpu,memory,loadavg),group(git,github),datetime"
```

Groups are assigned colors from `@powerkit_plugin_group_colors` palette in order:

- Group 1: `info-base-darker` (blue)
- Group 2: `window-active-base-darker` (purple/accent)
- Group 3: `ok-base-darker` (green)
- Group 4: `warning-base-darker` (yellow)
- Group 5: `error-base-darker` (red)
- Group 6: `disabled-base` (gray)

### Status Bar Layouts

**Single Layout** (default): Traditional single status line with session+windows and plugins.

**Double Layout**: Two status lines:

- Line 0: Session + Windows
- Line 1: Plugins only (right-aligned)

```bash
set -g @powerkit_bar_layout "double"
```

### Status Element Ordering

The `@powerkit_status_order` option controls the position of session, windows, and plugins.

**2-element orders** (auto-expanded, windows inserted before last element):

```bash
# Default order (session+windows left, plugins right)
set -g @powerkit_status_order "session,plugins"

# Inverted order (plugins left, session+windows right)
set -g @powerkit_status_order "plugins,session"
```

**3-element orders** (explicit windows - enables CENTERED layout):

```bash
# Windows centered (most common)
set -g @powerkit_status_order "session,windows,plugins"
# Result: session LEFT, windows CENTER, plugins RIGHT

# Plugins centered
set -g @powerkit_status_order "session,plugins,windows"
# Result: session LEFT, plugins CENTER, windows RIGHT

# Session centered (inverted with center)
set -g @powerkit_status_order "plugins,session,windows"
# Result: plugins LEFT, session CENTER, windows RIGHT
```

**Notes**:

- 2-element orders are auto-expanded (windows is inserted automatically)
- 3-element orders with explicit `windows` enable centered layout
- Any element can be in the center position - it will be visually centered
- Centered layout uses `status-format[0]` with `#[align=centre]` for true centering
- The centered element gets edge separators on both sides

### Thresholds

```bash
_DEFAULT_WARNING_THRESHOLD="70"
_DEFAULT_CRITICAL_THRESHOLD="90"
```

### Timeouts and TTLs

```bash
_DEFAULT_TIMEOUT_SHORT="5"       # 5 seconds
_DEFAULT_TIMEOUT_MEDIUM="10"     # 10 seconds
_DEFAULT_TIMEOUT_LONG="30"       # 30 seconds
_DEFAULT_CACHE_TTL_SHORT="60"    # 1 minute
_DEFAULT_CACHE_TTL_MEDIUM="300"  # 5 minutes
_DEFAULT_CACHE_TTL_LONG="3600"   # 1 hour
```

### Keybindings

```bash
POWERKIT_DEFAULT_OPTIONS_KEY="C-e"        # Options viewer
POWERKIT_DEFAULT_KEYBINDINGS_KEY="C-y"    # Keybindings viewer
POWERKIT_DEFAULT_THEME_SELECTOR_KEY="C-r" # Theme selector
POWERKIT_DEFAULT_CACHE_CLEAR_KEY="C-d"    # Cache clear
```

### Byte Size Constants

```bash
POWERKIT_BYTE_KB=1024
POWERKIT_BYTE_MB=1048576
POWERKIT_BYTE_GB=1073741824
POWERKIT_BYTE_TB=1099511627776
```

## Plugin Lifecycle Phases

```text
1. BOOTSTRAP   → Load core modules
2. DISCOVER    → Parse @powerkit_plugins
3. VALIDATE    → Check contract compliance
4. INITIALIZE  → Call declare_options, setup_keybindings
5. COLLECT     → Cache check → plugin_collect() → store data
6. RESOLVE     → Get state/health/context from plugin
7. RENDER      → Build segments with colors/icons (renderer)
8. OUTPUT      → Apply to tmux
```

## Development Commands

```bash
# Validate syntax
bash -n src/**/*.sh

# Run shellcheck
shellcheck src/**/*.sh

# Test render
POWERKIT_ROOT="$(pwd)" ./bin/powerkit-render

# Test specific plugin
POWERKIT_ROOT="$(pwd)" ./bin/powerkit-plugin battery
```

## Code Style

### Function Naming

- **Public**: `get_color`, `plugin_render`
- **Private**: `_internal_helper` (single underscore)
- **NEVER**: `__double_underscore` (causes bugs)

### Source Guard Pattern

Every module must use the source guard:

```bash
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "module_name" && return 0
```

### Contract Violations to Avoid

```bash
# WRONG: Color logic in plugin
plugin_render() {
    if [[ $percent -lt 20 ]]; then
        printf '#[fg=red]%d%%' "$percent"  # Plugin deciding UI!
    fi
}

# CORRECT: Plugin returns data, renderer decides UI
plugin_render() {
    printf '%d%%' "$percent"  # Plain text only
}

plugin_get_health() {
    [[ $percent -lt 20 ]] && printf 'error' || printf 'ok'
}
# Renderer maps health='error' → red color

# WRONG: Icon based on health
plugin_get_icon() {
    local health=$(plugin_get_health)
    [[ "$health" == "error" ]] && printf '%s' "$critical_icon"  # UI logic!
}

# CORRECT: Icon based on internal data
plugin_get_icon() {
    local percent=$(plugin_data_get "percent")
    (( percent < 15 )) && printf '%s' "$(get_option 'icon_critical')"
}
```

## Plugin Example (battery.sh)

```bash
#!/usr/bin/env bash
# Plugin: battery
# Description: Display battery status with charging indicator
# Type: conditional (hidden on desktop without battery)

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    if is_macos; then
        require_cmd "pmset" || return 1
    fi
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    declare_option "warning_threshold" "number" "30" "Warning threshold"
    declare_option "critical_threshold" "number" "15" "Critical threshold"
    declare_option "icon" "icon" $'\uf240' "Default battery icon"
    declare_option "icon_charging" "icon" $'\uf0e7' "Charging icon"
    declare_option "cache_ttl" "number" "5" "Cache duration"
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local percent charging
    # ... collect data ...
    plugin_data_set "percent" "$percent"
    plugin_data_set "charging" "$charging"
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

# =============================================================================
# Plugin Contract: State and Health
# =============================================================================

plugin_get_state() {
    local available
    available=$(plugin_data_get "available")
    [[ "$available" != "1" ]] && { printf 'inactive'; return; }
    printf 'active'
}

plugin_get_health() {
    local percent warn_th crit_th
    percent=$(plugin_data_get "percent")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    if (( percent <= crit_th )); then
        printf 'error'
    elif (( percent <= warn_th )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}

plugin_get_context() {
    local charging
    charging=$(plugin_data_get "charging")
    [[ "$charging" == "1" ]] && printf 'charging'
}

# =============================================================================
# Plugin Contract: Render (TEXT ONLY)
# =============================================================================

plugin_render() {
    local percent
    percent=$(plugin_data_get "percent")
    printf '%s%%' "${percent:-0}"
}

# =============================================================================
# Plugin Contract: Icon (based on internal data, NOT health)
# =============================================================================

plugin_get_icon() {
    local percent context
    percent=$(plugin_data_get "percent")
    context=$(plugin_get_context)

    [[ "$context" == "charging" ]] && { printf '%s' "$(get_option 'icon_charging')"; return; }

    printf '%s' "$(get_option 'icon')"
}
```

## Key Files

| File | Purpose |
|------|---------|
| `bin/powerkit-render` | Main entry point for status-right |
| `bin/powerkit-binary-prompt` | Interactive macOS binary download prompt |
| `src/core/bootstrap.sh` | Module loading and initialization |
| `src/core/lifecycle.sh` | Plugin lifecycle orchestration |
| `src/core/defaults.sh` | All default values and constants |
| `src/core/cache.sh` | TTL-based caching with memory optimization |
| `src/core/color_generator.sh` | Color variant generation |
| `src/core/binary_manager.sh` | macOS native binary download manager |
| `src/contract/plugin_contract.sh` | Plugin interface + helpers |
| `src/renderer/segment_builder.sh` | Builds formatted segments |
| `src/renderer/separator.sh` | Powerline separator management |
| `src/renderer/color_resolver.sh` | state/health → color resolution |
| `src/plugins/battery.sh` | Reference plugin implementation |

## Performance Notes

- **42 plugins** will be migrated - performance is critical
- Cache data, not rendered output (allows dynamic color changes)
- Use pure bash arithmetic over external commands
- One `date +%s` call per render cycle
- In-memory cache avoids repeated disk reads
- Source guards prevent multiple module loading
- Batch tmux option loading in single call

## Recent Improvements (December 2025)

### macOS Binary On-Demand Download System

Removed native macOS binaries from git repository. They are now downloaded on-demand from GitHub releases:

- **Binaries removed**: `powerkit-gpu`, `powerkit-temperature`, `powerkit-microphone`, `powerkit-nowplaying`, `powerkit-brightness`
- **New module**: `src/core/binary_manager.sh` manages binary downloads
- **New script**: `bin/powerkit-binary-prompt` provides interactive download UI
- **Batch prompting**: Single popup lists all missing binaries (not one per plugin)
- **User decision caching**: Decisions are cached for 24h
- **Graceful degradation**: Plugins return `inactive` state if binary unavailable

### Health System Enhancement

Added `good` health level for positive states:

- `ok`: Normal operation (neutral)
- `good`: Better than ok, positive state (e.g., connected, synced, authenticated)
- Both map to green colors but `good` semantically indicates a positive achievement

### Bluetooth Plugin Improvements

- Removed legacy options: `show_device`, `truncate_suffix`, `show_when_off`
- Uses `inactive` state when Bluetooth is off (plugin hidden)
- Health mapping:
  - `off`: state=inactive (hidden)
  - `on`: health=info (blue)
  - `connected`: health=success/good (green), or warning if battery low
- Uses `join_with_separator()` and `truncate_words()` for device display
- Fixed battery detection to not capture disconnected device batteries
- Default format changed to `all` (shows all connected devices)
- Default max_length increased to 50

### Brightness Plugin (Linux Only)

- Removed all macOS functionality (BetterDisplay, ioreg)
- Plugin now Linux-only with multiple backends:
  - sysfs (`/sys/class/backlight`)
  - brightnessctl
  - light
  - xbacklight
- Returns `inactive` state on macOS (plugin hidden)
- `plugin_check_dependencies()` returns 1 on macOS

### GPU Plugin (Multi-Platform)

Cross-platform GPU monitoring with vendor-specific backends:

**Supported GPUs**:

| Vendor | Backend | Metrics Available |
|--------|---------|-------------------|
| NVIDIA | `nvidia-smi` | usage, memory, temp |
| AMD | sysfs (`gpu_busy_percent`) | usage, memory, temp |
| Intel | sysfs (i915/xe driver) | usage (freq-based), freq |
| macOS | `powerkit-gpu` binary | usage, memory, temp |

**Metrics**:

- `usage`: GPU utilization percentage (Intel: calculated from freq_cur/freq_max)
- `memory`: VRAM usage (not available for Intel - uses shared system memory)
- `temp`: GPU temperature (not available for Intel via sysfs)
- `freq`: Current/max frequency in MHz (mainly useful for Intel)

**Options**:

```bash
# Metrics to display (comma-separated)
set -g @powerkit_plugin_gpu_metric "usage"           # Default
set -g @powerkit_plugin_gpu_metric "usage,freq"      # Intel recommended
set -g @powerkit_plugin_gpu_metric "usage,memory,temp"  # NVIDIA/AMD
set -g @powerkit_plugin_gpu_metric "all"             # All available for GPU type

# Memory format (NVIDIA/AMD only)
set -g @powerkit_plugin_gpu_memory_format "memory_usage"      # "409M/4.1G"
set -g @powerkit_plugin_gpu_memory_format "memory_use"        # "409M"
set -g @powerkit_plugin_gpu_memory_format "memory_percentage" # "10%"

# Show metric icons
set -g @powerkit_plugin_gpu_show_metric_icons "true"  # Default

# Thresholds
set -g @powerkit_plugin_gpu_usage_warning_threshold "70"
set -g @powerkit_plugin_gpu_usage_critical_threshold "90"
```

**Intel GPU Detection**:

- Uses `/sys/class/drm/card{0,1}/gt/gt0/rps_cur_freq_mhz` for current frequency
- Uses `/sys/class/drm/card{0,1}/gt/gt0/rps_max_freq_mhz` for max frequency
- Usage calculated as: `(freq_cur * 100) / freq_max`

**Data stored** (`plugin_data_set`):

- `gpu_type`: "nvidia", "amd", "intel", or "macos"
- `usage`: Utilization percentage
- `mem_used_mb`, `mem_total_mb`: Memory in MB (NVIDIA/AMD/macOS)
- `temp`: Temperature in °C (NVIDIA/AMD/macOS)
- `freq_cur`, `freq_max`: Frequency in MHz (Intel only)

### Fan Plugin (Multi-Platform)

Cross-platform fan speed monitoring:

**Linux backends** (in order of priority):

- Dell SMM (`/sys/class/hwmon/hwmon*/name == "dell_smm"`)
- ThinkPad (`/proc/acpi/ibm/fan`)
- Generic hwmon (`/sys/class/hwmon/hwmon*/fan*_input`)

**macOS backends**:

- `osx-cpu-temp -f`
- `smctemp`
- `istats`

**Options**:

```bash
# Fan source (Linux)
set -g @powerkit_plugin_fan_source "auto"  # auto|dell|thinkpad|hwmon

# Display format
set -g @powerkit_plugin_fan_format "icon_k"  # rpm|krpm|number|icon|icon_k

# Fan selection
set -g @powerkit_plugin_fan_selection "active"  # active (RPM>0) or all

# Thresholds (RPM)
set -g @powerkit_plugin_fan_warning_threshold "4000"
set -g @powerkit_plugin_fan_critical_threshold "6000"
```

### Platform-Specific Plugin Pattern

For plugins that only work on one platform:

```bash
plugin_check_dependencies() {
    # Linux only - return 1 on macOS to fail dependency check
    is_macos && return 1
    # Check Linux dependencies...
    return 0
}

plugin_get_state() {
    # Return inactive on unsupported platform
    is_macos && { printf 'inactive'; return; }
    printf 'active'
}
```

### Icon Format Standardization

All icons now use UTF-32 format (`\U0000XXXX` for BMP, `\UXXXXXXXX` for surrogate pairs):

- **Plugins**: battery, cpu, memory, hostname, uptime
- **System**: session icons, window icons, pane sync icon
- **Format**: `$'\U0000f240'` for U+F240, `$'\U000F0954'` for U+F0954 (surrogate)

### Color Cache System

Consolidated theme color cache replaces per-color calculation caching:

**Architecture**:

- Single cache file per theme: `theme_colors__<theme>__<variant>` (e.g., `theme_colors__tokyo-night__night`)
- Contains all base colors + 6 variants per color (light/lighter/lightest/dark/darker/darkest)
- TTL: 24 hours
- Cache key format uses `__` separator for filesystem compatibility

**Flow**:

1. `load_theme()` checks cache first via `cache_get("theme_colors__theme__variant")`
2. If cache hit: `deserialize_theme_colors()` populates `THEME_COLORS` + `_COLOR_VARIANTS`
3. If cache miss: load theme file → `generate_color_variants()` → `serialize_theme_colors()` → `cache_set()`
4. All components (`get_color()`, `resolve_color()`, etc.) use in-memory arrays - no recalculation

**Validation**:

- Fast path: reuses in-memory theme if same theme/variant + arrays populated
- Cache validation: checks `${#THEME_COLORS[@]}` and `${#_COLOR_VARIANTS[@]}` after deserialize
- If invalid/empty: falls back to file load + regeneration

**Implementation**:

- `src/core/color_generator.sh`: `serialize_theme_colors()`, `deserialize_theme_colors()`
- `src/core/theme_loader.sh`: cache integration in `load_theme()`
- `src/core/cache.sh`: sanitizes keys (alphanumeric + `_` + `-`)

### Plugin Options

Default option added to all plugins:

```bash
declare_option "show_only_on_threshold" "bool" "false" "Only show when warning or critical threshold is exceeded"
```

- Default: `false` (show always)
- Injected automatically via `_inject_default_plugin_options()` in `src/core/options.sh`
- Renderer filters via `get_named_plugin_option()` in `src/renderer/segment_builder.sh`

## Plugin Migration Rules (CRITICAL)

### Separation of Concerns

**Plugins** (what they DO):

1. Collect data via `plugin_data_set()`
2. Return state: `inactive|active|degraded|failed`
3. Return health: `ok|info|warning|error`
4. Render TEXT ONLY (no colors, no tmux formatting)
5. Return icon character (can vary by context)
6. Declare options (icon, thresholds, format, cache_ttl)

**Plugins** (what they MUST NOT do):

- ❌ Decide colors (no `accent_color`, `accent_color_icon`)
- ❌ Apply tmux formatting (no `#[fg=...]` in render)
- ❌ Build segments
- ❌ Implement `plugin_get_display_info()` (legacy)
- ❌ Implement `plugin_get_type()` (use `plugin_get_content_type()`)

**Renderer** (what it does):

1. Resolve colors via `color_resolver.sh` based on state/health
2. Build segments via `segment_builder.sh` with separators
3. Apply tmux color codes and formatting

### Color Resolution Flow

```text
Plugin → state="active", health="warning"
  ↓
Renderer → resolve_plugin_colors_full(state, health, context)
  ↓
color_palette → get_plugin_colors(state, health)
  health="warning" → base="warning-base"
  content_bg = warning-base
  icon_bg = warning-base-lighter
  content_fg = warning-base-darkest (for contrast)
  icon_fg = warning-base-darkest
  ↓
segment_builder → applies #[fg=...,bg=...]
```

**IMPORTANT**: Context does NOT affect colors. Plugin sets health based on context.

### Migration Checklist

For each plugin being migrated from `src-old/plugin/`:

**Structure**:

- [ ] Change `ROOT_DIR` to `POWERKIT_ROOT`
- [ ] Source `plugin_contract.sh` (not `plugin_bootstrap.sh`)
- [ ] Add `plugin_get_metadata()` with id/name/description (only these 3 fields)

**Options**:

- [ ] Remove `accent_color` declarations
- [ ] Remove `accent_color_icon` declarations  
- [ ] Keep `icon` and contextual icons (`icon_charging`, etc)
- [ ] Keep thresholds, format, cache_ttl
- [ ] Verify icons are UTF-32 (`$'\U0000XXXX'`)

**Contract Functions**:

- [ ] Remove `plugin_get_type()` → use `plugin_get_content_type()`
- [ ] Remove `plugin_get_display_info()` → use state/health/presence
- [ ] Implement `plugin_get_content_type()`: `static|dynamic`
- [ ] Implement `plugin_get_presence()`: `always|conditional`
- [ ] Implement `plugin_get_state()` correctly
- [ ] Implement `plugin_get_health()` correctly
- [ ] Optional: `plugin_get_context()` for descriptive info

**Data Flow**:

- [ ] Remove `load_plugin()` function
- [ ] Create `plugin_collect()`: only use `plugin_data_set()`
- [ ] Create `plugin_render()`: only use `plugin_data_get()` + return text
- [ ] Create `plugin_get_icon()`: can use context/state to choose icon

**Example Patterns**:

Platform-independent static plugin (always visible):

```bash
plugin_get_content_type() { printf 'static'; }
plugin_get_presence() { printf 'always'; }
plugin_get_state() { printf 'active'; }
plugin_get_health() { printf 'ok'; }
```

Platform-specific plugin (Linux only):

```bash
plugin_check_dependencies() {
    is_macos && return 1  # Not supported on macOS
    has_cmd "brightnessctl" || [[ -d "/sys/class/backlight" ]] || return 1
    return 0
}

plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    is_macos && { printf 'inactive'; return; }  # Hidden on macOS
    printf 'active'
}
```

Dynamic plugin with thresholds:

```bash
plugin_get_content_type() { printf 'dynamic'; }
plugin_get_presence() { printf 'conditional'; }

plugin_get_state() {
    local value=$(plugin_data_get "value")
    [[ -n "$value" ]] && printf 'active' || printf 'failed'
}

plugin_get_health() {
    local value=$(plugin_data_get "value")
    local warn=$(get_option "warning_threshold")
    local crit=$(get_option "critical_threshold")
    if (( value >= crit )); then
        printf 'error'
    elif (( value >= warn )); then
        printf 'warning'
    else
        printf 'ok'
    fi
}
```

Conditional plugin with multiple health states (e.g., bluetooth):

```bash
plugin_get_state() {
    local status=$(plugin_data_get "status")
    case "$status" in
        on|connected) printf 'active' ;;
        *)            printf 'inactive' ;;  # off = hidden
    esac
}

plugin_get_health() {
    local status=$(plugin_data_get "status")
    case "$status" in
        on)        printf 'info' ;;      # Blue - BT on, no devices
        connected) printf 'good' ;;      # Green - devices connected
        *)         printf 'ok' ;;
    esac
}
```

---

## New Files Created (December 2025 Refactoring)

### Core Modules

| File | Purpose |
|------|---------|
| `src/core/registry.sh` | Centralized constants and enums (PLUGIN_STATES, SESSION_MODES, WINDOW_ICON_MAP, HEALTH_LEVELS) |

### Contract Modules

| File | Purpose |
|------|---------|
| `src/contract/theme_contract.sh` | Theme contract definition and validation |
| `src/contract/helper_contract.sh` | Helper base contract with UI abstraction |

### Utility Modules

| File | Purpose |
|------|---------|
| `src/utils/validation.sh` | Generic validation functions (validate_against_enum, validate_hex_color, etc.) |

---

## Registry System

The Registry (`src/core/registry.sh`) provides a single source of truth for all constants:

### Plugin Constants

```bash
PLUGIN_STATES=("inactive" "active" "degraded" "failed")
PLUGIN_CONTENT_TYPES=("static" "dynamic")
PLUGIN_PRESENCE_MODES=("always" "conditional")
PLUGIN_STATE_DESCRIPTIONS=(
    [inactive]="Plugin hidden (resource doesn't exist, platform unsupported)"
    [active]="Plugin visible and working"
    [degraded]="Plugin visible but with reduced functionality"
    [failed]="Plugin visible with error indication"
)
```

### Health System

```bash
HEALTH_LEVELS=("ok" "good" "info" "warning" "error")
HEALTH_PRECEDENCE=(
    [ok]=0
    [good]=0
    [info]=1
    [warning]=2
    [error]=3
)

# Functions
get_health_level "warning"  # Returns: 2
health_is_worse "error" "warning"  # Returns: true (0)
health_max "ok" "warning" "error"  # Returns: error
```

### Session Constants

```bash
SESSION_STATES=("attached" "detached")
SESSION_MODES=("normal" "prefix" "copy" "command" "search")
```

### Window Constants

```bash
WINDOW_STATES=("active" "inactive" "activity" "bell" "zoomed" "last" "marked")

# Command → icon mapping
declare -A WINDOW_ICON_MAP=(
    [vim]="󰈔"
    [nvim]="󰈔"
    [docker]=""
    [git]=""
    [ssh]=""
    # ... more mappings
)

# Functions
get_window_icon "vim"      # Returns: 󰈔
has_window_icon "docker"   # Returns: true (0)
```

### Helper Constants

```bash
HELPER_TYPES=("popup" "menu" "command" "toast")
```

---

## Validation Utilities

The Validation module (`src/utils/validation.sh`) provides reusable validation functions:

### Enum Validation

```bash
# Using nameref (requires bash 4.3+)
validate_against_enum "active" PLUGIN_STATES

# Without nameref (safer)
validate_against_enum_safe "active" "${PLUGIN_STATES[@]}"
```

### Type Validation

```bash
validate_numeric "$value"              # Integer check
validate_positive_integer "$value"     # > 0
validate_non_negative_integer "$value" # >= 0
validate_boolean "$value"              # true/false/yes/no/1/0
validate_percentage "$value"           # 0-100
validate_hex_color "$value"            # #RRGGBB or #RGB
```

### Range Validation

```bash
validate_in_range "$value" 0 100       # Inclusive range check
```

### Path Validation

```bash
validate_path_exists "$path"
validate_file_readable "$path"
validate_directory_accessible "$path"
```

---

## Theme Contract

The Theme Contract (`src/contract/theme_contract.sh`) defines theme requirements:

### Required Colors (20)

| Category | Colors |
|----------|--------|
| Status Bar | `statusbar-bg`, `statusbar-fg` |
| Session | `session-bg`, `session-fg`, `session-prefix-bg`, `session-copy-bg` |
| Windows | `window-active-base`, `window-inactive-base` |
| Pane Borders | `pane-border-active`, `pane-border-inactive` |
| Health States | `ok-base`, `good-base`, `info-base`, `warning-base`, `error-base`, `disabled-base` |
| Messages | `message-bg`, `message-fg` |

### Optional Colors

- `session-command-bg`, `session-search-bg`
- `neutral-base`
- `selection-bg`, `selection-fg`
- `search-match-bg`, `search-match-fg`

### Validation

```bash
# Validate single theme
validate_theme "src/themes/tokyo-night/night.sh"

# Validate all themes
validate_all_themes "src/themes"

# List requirements
list_required_theme_colors
list_optional_theme_colors
```

---

## Helper Contract

The Helper Contract (`src/contract/helper_contract.sh`) standardizes helper creation:

### Architecture

```text
┌─────────────────────────────────────────────────┐
│                 HELPER LAYER                     │
│  ┌─────────────┐  ┌─────────────┐               │
│  │ password_sel│  │ theme_select│  ...          │
│  └──────┬──────┘  └──────┬──────┘               │
└─────────┼────────────────┼──────────────────────┘
          │                │
┌─────────▼────────────────▼──────────────────────┐
│              HELPER CONTRACT LAYER               │
│  helper_init(), helper_dispatch()               │
│  helper_filter(), helper_choose(), toast()      │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│                UI BACKEND LAYER                  │
│  Priority: gum > fzf > basic                    │
└─────────────────────────────────────────────────┘
```

### Helper Types

| Type | Description | Example |
|------|-------------|---------|
| `popup` | Interactive UI in display-popup | bitwarden_selector |
| `menu` | Native tmux display-menu | theme_selector |
| `command` | Executes via run-shell | cache_clear |
| `toast` | Brief notification | keybinding_conflict_toast |

### Mandatory Functions

```bash
helper_main(action, ...)  # Main entry point
```

### Optional Functions

```bash
helper_get_metadata()  # Set id, name, description, type (version removed)
helper_get_actions()   # List available actions
```

### UI Wrapper Functions

| Function | Description |
|----------|-------------|
| `helper_filter` | Fuzzy filter from stdin |
| `helper_choose` | Select from options |
| `helper_table` | Interactive table selection |
| `helper_input` | Text input prompt |
| `helper_confirm` | Yes/No confirmation |
| `helper_spin` | Spinner while running |
| `helper_pager` | Page through text |

### Toast Notifications (via ui_backend.sh)

Use `toast()` directly from `ui_backend.sh` (loaded by bootstrap):

```bash
toast "message"                # info style (default)
toast "message" "warning"      # yellow with ⚠ icon
toast "message" "error"        # red with ✗ icon
toast "message" "success"      # green with ✓ icon
```

### Helper Example

```bash
#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init

helper_get_metadata() {
    helper_metadata_set "id" "my_helper"
    helper_metadata_set "name" "My Helper"
    helper_metadata_set "description" "Brief description"
    helper_metadata_set "type" "popup"
}

helper_main() {
    local action="${1:-select}"
    case "$action" in
        select) do_selection ;;
        *) echo "Unknown: $action" >&2 ;;
    esac
}

helper_dispatch "$@"
```

---

## Module Loading Rules

### Bootstrap Loading Order

The bootstrap system loads modules in strict dependency order:

1. **Core modules** via `_load_core_modules()`:
   - guard.sh, defaults.sh, logger.sh, datastore.sh, options.sh
   - cache.sh, keybindings.sh, color_generator.sh, color_palette.sh
   - theme_loader.sh, lifecycle.sh, registry.sh

2. **Utility modules** via `_load_utils_modules()`:
   - ALL files in `src/utils/`

3. **Contract modules** via `_load_contract_modules()`:
   - ALL files in `src/contract/`

4. **Renderer modules** via `_load_renderer_modules()`:
   - ALL files in `src/renderer/`

### Plugin Source Rules

**DO**:

```bash
# Source ONLY plugin_contract.sh at the top of your plugin
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"
```

**DON'T**:

```bash
# WRONG: Re-sourcing utilities that plugin_contract.sh already provides
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"
. "${POWERKIT_ROOT}/src/utils/platform.sh"  # REDUNDANT!
. "${POWERKIT_ROOT}/src/utils/strings.sh"   # REDUNDANT!
```

### Utilities Provided by plugin_contract.sh

| Module | Main Functions |
|--------|---------------|
| `platform.sh` | `is_macos()`, `is_linux()`, `has_cmd()`, `get_os()` |
| `network.sh` | `fetch_url()`, `is_online()` |
| `strings.sh` | `trim()`, `join_with_separator()`, `truncate_text()` |
| `keybinding.sh` | `register_keybinding()`, `pk_bind_popup()` |
| `validation.sh` | `validate_against_enum()`, `validate_hex_color()` |

### Utilities NOT in Contract (source if needed)

- `numbers.sh` - Numeric formatting (`format_bytes()`, `format_percent()`)
- `filesystem.sh` - File operations
- `clipboard.sh` - Clipboard operations
- `json.sh` - JSON parsing
- `ui_backend.sh` - UI backend abstraction

### Keybinding Convention

Plugins with keybindings must:

1. **Declare options with `keybinding_` prefix** and type `key`
2. **Use empty string as default** for optional keybindings
3. The system **auto-discovers keybindings** from declared options

```bash
plugin_declare_options() {
    # Keybindings are auto-discovered by prefix "keybinding_"
    declare_option "keybinding_select" "key" "C-s" "Keybinding for selector"
    declare_option "keybinding_toggle" "key" "" "Optional: Toggle keybinding"
}
```

### Keybinding Auto-Discovery

Bootstrap uses data-driven keybinding discovery instead of hardcoded case statements:

```bash
# In src/core/options.sh
get_plugin_keybinding_options() {
    local plugin="$1"
    local options="${_PLUGIN_OPTIONS[$plugin]:-}"
    # Returns all options starting with "keybinding_"
}
```

This means:

- **No manual updates needed** when adding new plugins with keybindings
- Just follow the `keybinding_*` naming convention
- Conflict detection works automatically

---

## Contract Simplifications (December 2025)

### Plugin Metadata Simplified

`plugin_get_metadata()` now only requires 3 fields:

```bash
plugin_get_metadata() {
    metadata_set "id" "my_plugin"
    metadata_set "name" "My Plugin"
    metadata_set "description" "What this plugin does"
}
```

**Removed fields**:

- `version` - Not used by the system
- `priority` - Plugin order is determined by user configuration in `@powerkit_plugins`

### Helper Metadata Simplified

`helper_get_metadata()` also simplified:

```bash
helper_get_metadata() {
    helper_metadata_set "id" "my_helper"
    helper_metadata_set "name" "My Helper"
    helper_metadata_set "description" "What this helper does"
    helper_metadata_set "type" "popup"  # popup|menu|command|toast
}
```

**Removed fields**:

- `version` - Not used by the system

### Toast Notifications Centralized

Toast notifications moved from `helper_contract.sh` to `ui_backend.sh`:

**Old approach** (deprecated):

```bash
helper_toast "message" "simple"  # No longer exists
```

**New approach**:

```bash
toast "message"                # info style (default)
toast "message" "warning"      # yellow with ⚠ icon
toast "message" "error"        # red with ✗ icon
toast "message" "success"      # green with ✓ icon
```

The `toast()` function is available globally after bootstrap via `ui_backend.sh`
