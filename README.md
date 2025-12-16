# ⚡ PowerKit for tmux

A powerful, modular tmux status bar framework with 36+ built-in plugins for displaying system information, development tools, security monitoring, and media status. Ships with beautiful themes including Tokyo Night and Kiribyte.

> **📢 Note:** This project was formerly known as `tmux-tokyo-night`. See [Migration Guide](../../wiki/Migration-Guide) for upgrade instructions.

![PowerKit Theme](./assets/tokyo-night-theme.png)

<details>
<summary><b>📍 Status Bar Elements</b></summary>

| # | Element | Description |
|---|---------|-------------|
| ① | **Session Indicator** | Shows OS icon and session name. Changes color based on state: 🟢 normal, 🟡 prefix pressed, 🟣 copy mode |
| ② | **Window List** | Active and inactive windows with icons. Active window is highlighted |
| ③ | **Plugins** | Right-side status plugins (datetime, cpu, memory, git, battery, etc.) |

</details>

## ✨ Features

- 🎨 **Multiple themes** - Tokyo Night (night, storm, moon, day) and Kiribyte (dark)
- 🔌 **36+ built-in plugins** - System monitoring, development tools, security keys, media players
- ⚡ **Performance optimized** - Intelligent caching with configurable TTL
- 🎯 **Fully customizable** - Semantic colors, icons, formats, and separators
- 🖥️ **Cross-platform** - macOS, Linux, and BSD support
- ⌨️ **Interactive features** - Popup helpers, device selectors, and context switchers
- 🔧 **DRY configuration** - Semantic color system with consistent defaults

## 📚 Documentation

- **[Installation](../../wiki/Installation)** - Setup with TPM or manual installation
- **[Quick Start](../../wiki/Quick-Start)** - Get up and running in minutes
- **[Migration Guide](../../wiki/Migration-Guide)** - Upgrade from tmux-tokyo-night
- **[Theme Variations](../../wiki/Theme-Variations)** - Explore available themes
- **[Global Configuration](../../wiki/Global-Configuration)** - Configure status bar layout and separators
- **[Plugin System](../../wiki/Plugin-System-Overview)** - Complete reference for all 36+ plugins
- **[Interactive Keybindings](../../wiki/Interactive-Keybindings)** - Popup helpers and selectors
- **[Custom Colors & Theming](../../wiki/Custom-Colors-Theming)** - Advanced customization
- **[Performance & Caching](../../wiki/Performance-Caching)** - Optimize for your workflow
- **[Troubleshooting](../../wiki/Troubleshooting)** - Common issues and solutions

## 🚀 Quick Start

### Installation

Add to your `~/.tmux.conf`:

```bash
set -g @plugin 'fabioluciano/tmux-powerkit'
```

Press `prefix + I` to install with [TPM](https://github.com/tmux-plugins/tpm).

### Basic Configuration

```bash
# Choose theme and variant
set -g @powerkit_theme 'tokyo-night'
set -g @powerkit_theme_variant 'night'

# Enable plugins
set -g @powerkit_plugins 'datetime,weather,battery,cpu,memory'

# Auto-detect OS icon
set -g @powerkit_session_icon 'auto'
```

See **[Quick Start Guide](../../wiki/Quick-Start)** for more examples.

## 🎨 Available Themes

### Tokyo Night

| Variant | Description |
|---------|-------------|
| `night` | Deep dark theme (default) |

### Kiribyte

| Variant | Description |
|---------|-------------|
| `dark` | Pastel dark theme with soft colors |

```bash
# Tokyo Night (default)
set -g @powerkit_theme 'tokyo-night'
set -g @powerkit_theme_variant 'night'

# Kiribyte
set -g @powerkit_theme 'kiribyte'
set -g @powerkit_theme_variant 'dark'
```

Learn more: **[Theme Variations](../../wiki/Theme-Variations)**

## ⌨️ Interactive Features

All interactive keybindings use `Ctrl` modifier (`prefix + Ctrl+key`) for cross-platform compatibility.

| Keybinding | Feature |
|------------|---------||
| `prefix + Ctrl-e` | **Options viewer** - Browse all theme settings |
| `prefix + Ctrl-g` | **Keybindings viewer** - View all keybindings |
| `prefix + Ctrl-x` | **Cache cleaner** - Clear all plugin caches (refresh) |
| `prefix + Ctrl-i` | **Audio input selector** - Switch microphone devices |
| `prefix + Ctrl-s` | **Audio output selector** - Switch speaker/headphone devices |
| `prefix + Ctrl-q` | **Kubernetes context selector** - Switch contexts |
| `prefix + Ctrl-w` | **Kubernetes namespace selector** - Switch namespaces |
| `prefix + Ctrl-t` | **Terraform workspace selector** - Switch workspaces |

![Options Viewer](./assets/keybinding-options-viewer.gif)

Learn more: **[Interactive Keybindings](../../wiki/Interactive-Keybindings)**

## 🔌 Available Plugins

The theme includes 36+ built-in plugins organized by category:

### 📅 Time & Date

- **[datetime](../../wiki/Datetime)** - Customizable date and time display
- **[timezones](../../wiki/Timezones)** - Display multiple time zones simultaneously

### 🌡️ System Monitoring

- **[cpu](../../wiki/CPU)** - CPU usage with dynamic thresholds
- **[gpu](../../wiki/GPU)** - GPU utilization (NVIDIA, AMD, Intel, Apple Silicon)
- **[memory](../../wiki/Memory)** - RAM usage with format options
- **[disk](../../wiki/Disk)** - Disk space with threshold warnings
- **[loadavg](../../wiki/LoadAvg)** - System load average monitoring
- **[temperature](../../wiki/Temperature)** - CPU temperature <br> <sub>(Linux only; partial support on WSL/macOS)</sub>
- **[fan](../../wiki/Fan)** - Fan speed (RPM) monitoring
- **[uptime](../../wiki/Uptime)** - System uptime display
- **[brightness](../../wiki/Brightness)** - Screen brightness level

### 🌐 Network & Connectivity

- **[network](../../wiki/Network)** - Bandwidth monitoring
- **[wifi](../../wiki/WiFi)** - WiFi status with signal strength
- **[vpn](../../wiki/VPN)** - VPN connection with multiple providers
- **[external_ip](../../wiki/External_IP)** - Public IP address display
- **[ping](../../wiki/Ping)** - Network latency monitoring
- **[ssh](../../wiki/SSH)** - SSH session indicator
- **[bluetooth](../../wiki/Bluetooth)** - Bluetooth devices with battery
- **[weather](../../wiki/Weather)** - Weather with custom formats

### 💻 Development

- **[git](../../wiki/Git)** - Git branch with dynamic color for modified repos
- **[github](../../wiki/GitHub)** - Monitor GitHub open issues and PRs with filtering
- **[gitlab](../../wiki/GitLab)** - Monitor GitLab open issues and MRs with filtering
- **[bitbucket](../../wiki/Bitbucket)** - Monitor Bitbucket open issues and PRs with filtering
- **[kubernetes](../../wiki/Kubernetes)** - K8s context with interactive selectors
- **[cloud](../../wiki/Cloud)** - Cloud provider context (AWS/GCP/Azure)
- **[terraform](../../wiki/Terraform)** - Terraform/OpenTofu workspace with prod warnings

### 🔐 Security

- **[smartkey](../../wiki/SmartKey)** - Hardware security key detection (YubiKey, SoloKeys, Nitrokey)

### 🎵 Media & Audio

- **[audiodevices](../../wiki/AudioDevices)** - Audio device selector with keybindings
- **[microphone](../../wiki/Microphone)** - Microphone activity detection
- **[nowplaying](../../wiki/NowPlaying)** - Unified media player (Spotify, Music.app, playerctl)
- **[volume](../../wiki/Volume)** - Volume level
- **[camera](../../wiki/Camera)** - Privacy-focused camera activity monitoring

### 📦 Package Managers

- **[packages](../../wiki/Packages)** - Unified package manager (brew, yay, apt, dnf, pacman)

### 🔌 External Plugins

- **[external()](../../wiki/External-Plugins)** - Integrate external tmux plugins (tmux-cpu, tmux-ping, etc.) with PowerKit styling

### 🖥️ System Info

- **[battery](../../wiki/Battery)** - Battery with intelligent 3-tier thresholds
- **[hostname](../../wiki/Hostname)** - System hostname display

**Enable plugins:**

```bash
set -g @powerkit_plugins 'datetime,battery,cpu,memory,git'
```

**Integrate external plugins:**

```bash
# Format: external("icon"|"command"|"accent"|"accent_icon"|"ttl")
set -g @powerkit_plugins 'cpu,memory,external("🐏"|"$(~/.config/tmux/plugins/tmux-cpu/scripts/ram_percentage.sh)"|"warning"|"warning-strong"|"30")'
```

See **[Plugin System Overview](../../wiki/Plugin-System-Overview)** for complete documentation.

### Platform Compatibility

| Plugin | Linux | macOS | WSL | Notes |
|--------|-------|-------|-----|-------|
| **audiodevices** | ✅ | ✅ | ✅ | Requires `pactl` (Linux), `SwitchAudioSource` (macOS) |
| **battery** | ✅ | ✅ | ✅ | Requires `acpi`/`upower` (Linux), `pmset` (macOS) |
| **bluetooth** | ✅ | ✅ | ⚠️ | Limited battery support on macOS |
| **brightness** | ✅ | ❌ | ✅ | Requires `brightnessctl`/`light`/`xbacklight` |
| **camera** | ✅ | ❌ | ❌ | Requires `v4l2`/`lsof` (Linux) |
| **cloud** | ✅ | ✅ | ✅ | AWS/GCP/Azure context detection |
| **cpu** | ✅ | ✅ | ✅ | Native support |
| **datetime** | ✅ | ✅ | ✅ | Universal |
| **disk** | ✅ | ✅ | ✅ | Uses `df` command |
| **external_ip** | ✅ | ✅ | ✅ | Requires internet connection |
| **fan** | ✅ | ⚠️ | ✅ | Linux: hwmon, macOS: requires smctemp |
| **git** | ✅ | ✅ | ✅ | Requires git repository |
| **github** | ✅ | ✅ | ✅ | Status issues/PRs from GitHub |
| `bitbucket` | ✅ | ✅ | ✅ | Status issues/PRs from Bitbucket Cloud |
| **gitlab** | ✅ | ✅ | ✅ | Status issues/MRs from GitLab |
| **hostname** | ✅ | ✅ | ✅ | Universal |
| **kubernetes** | ✅ | ✅ | ✅ | Requires `kubectl` |
| **loadavg** | ✅ | ✅ | ✅ | Native support |
| **memory** | ✅ | ✅ | ✅ | Native support |
| **microphone** | ✅ | ❌ | ⚠️ | Requires `pactl` (Linux) |
| **network** | ✅ | ✅ | ✅ | Bandwidth monitoring |
| **nowplaying** | ✅ | ✅ | ✅ | Auto-detects: Spotify/Music.app/playerctl |
| **packages** | ✅ | ✅ | ✅ | Auto-detects: brew/yay/apt/dnf/pacman |
| **ping** | ✅ | ✅ | ✅ | Uses system ping command |
| **smartkey** | ✅ | ✅ | ❌ | YubiKey/SoloKeys/Nitrokey |
| **ssh** | ✅ | ✅ | ✅ | Detects SSH session environment |
| **temperature** | ✅ | ⚠️ | ⚠️ | Multiple sources available |
| **terraform** | ✅ | ✅ | ✅ | Requires terraform/tofu |
| **timezones** | ✅ | ✅ | ✅ | Universal |
| **uptime** | ✅ | ✅ | ✅ | Universal |
| **volume** | ✅ | ✅ | ⚠️ | Linux: pactl/pamixer, macOS: osascript |
| **vpn** | ✅ | ✅ | ⚠️ | Multiple providers supported |
| **weather** | ✅ | ✅ | ✅ | Requires internet connection |
| **wifi** | ✅ | ✅ | ❌ | Linux: nmcli/iwconfig, macOS: airport |

**Legend:** ✅ Fully supported | ⚠️ Partial support | ❌ Not supported

## ⚙️ Configuration

### Global Options

```bash
# Theme selection
set -g @powerkit_theme 'tokyo-night'
set -g @powerkit_theme_variant 'night'

# Transparent status bar
set -g @powerkit_transparent 'true'

# Separators (requires Nerd Font)
set -g @powerkit_left_separator ''
set -g @powerkit_right_separator ''

# Session icon (auto-detects OS)
set -g @powerkit_session_icon 'auto'

# Cache management keybinding
set -g @powerkit_plugin_cache_clear_key 'Q'
```

### Plugin Customization

Each plugin supports semantic color configuration:

```bash
# Example: Customize CPU plugin
set -g @powerkit_plugin_cpu_icon ''
set -g @powerkit_plugin_cpu_accent_color 'secondary'
set -g @powerkit_plugin_cpu_accent_color_icon 'active'
set -g @powerkit_plugin_cpu_cache_ttl '3'

# Threshold colors (semantic names)
set -g @powerkit_plugin_cpu_warning_threshold '70'
set -g @powerkit_plugin_cpu_warning_accent_color 'warning'
set -g @powerkit_plugin_cpu_critical_threshold '90'
set -g @powerkit_plugin_cpu_critical_accent_color 'error'
```

**Available semantic colors:**

- `primary`, `secondary`, `accent`
- `success`, `warning`, `error`, `info`
- `active`, `disabled`, `hover`, `focus`
- `background`, `surface`, `text`, `border`

Learn more:

- **[Global Configuration](../../wiki/Global-Configuration)**
- **[Custom Colors & Theming](../../wiki/Custom-Colors-Theming)**
- **[Performance & Caching](../../wiki/Performance-Caching)**

## 📝 Example Configuration

```bash
# ~/.tmux.conf

# Theme selection
set -g @powerkit_theme 'tokyo-night'
set -g @powerkit_theme_variant 'night'

# Auto-detect OS icon
set -g @powerkit_session_icon 'auto'

# Enable plugins
set -g @powerkit_plugins 'datetime,weather,battery,cpu,memory,git,kubernetes,smartkey'

# Customize datetime
set -g @powerkit_plugin_datetime_format 'datetime'

# Set weather location
set -g @powerkit_plugin_weather_location 'New York'

# Kubernetes with namespace
set -g @powerkit_plugin_kubernetes_show_namespace 'true'

# Load TPM
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'fabioluciano/tmux-powerkit'
run '~/.tmux/plugins/tpm/tpm'
```

See **[Quick Start](../../wiki/Quick-Start)** for more configuration examples.

## 🙏 Credits

- Color schemes inspired by [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) by enkia
- Weather data provided by [wttr.in](https://wttr.in)

## 📄 License

MIT License - see LICENSE file for details
