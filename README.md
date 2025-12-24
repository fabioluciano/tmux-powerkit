# PowerKit

**A powerful, contract-based tmux status bar framework with 42 plugins and 13 themes.**

[![Version](https://img.shields.io/github/v/release/fabioluciano/tmux-powerkit?style=flat-square)](https://github.com/fabioluciano/tmux-powerkit/releases)
[![License](https://img.shields.io/github/license/fabioluciano/tmux-powerkit?style=flat-square)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/fabioluciano/tmux-powerkit/plugin-tests.yml?branch=main&style=flat-square&label=tests)](https://github.com/fabioluciano/tmux-powerkit/actions)
[![ShellCheck](https://img.shields.io/github/actions/workflow/status/fabioluciano/tmux-powerkit/shellcheck.yml?branch=main&style=flat-square&label=shellcheck)](https://github.com/fabioluciano/tmux-powerkit/actions)

---

## Features

- **42 Plugins** - System monitoring, development tools, productivity, and more
- **13 Themes** - 27 variants including Catppuccin, Dracula, Nord, Tokyo Night
- **Contract-Based Architecture** - Clean separation between data, rendering, and theming
- **Cross-Platform** - macOS and Linux support
- **Extensible** - Create your own plugins, themes, and helpers
- **Performance Optimized** - Smart caching, lazy loading, minimal overhead

## Quick Start

### Installation (TPM)

Add to your `~/.tmux.conf`:

```bash
set -g @plugin 'fabioluciano/tmux-powerkit'

# Initialize TPM (keep at bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
```

Then press `prefix + I` to install.

### Basic Configuration

```bash
# Choose your plugins
set -g @powerkit_plugins "battery,cpu,memory,datetime"

# Select a theme
set -g @powerkit_theme "tokyo-night"
set -g @powerkit_theme_variant "night"

# Optional: customize separators
set -g @powerkit_separator_style "rounded"
```

## Documentation

Full documentation is available in the [Wiki](wiki/Home.md).

| Section | Description |
|---------|-------------|
| [Installation](wiki/Installation.md) | Detailed setup guide |
| [Quick Start](wiki/Quick-Start.md) | Get started in 5 minutes |
| [Configuration](wiki/Configuration.md) | All configuration options |
| [Plugins](wiki/Home.md#available-plugins) | 42 available plugins |
| [Themes](wiki/Themes.md) | 13 themes with 27 variants |
| [Developing Plugins](wiki/DevelopingPlugins.md) | Create your own plugins |
| [Developing Themes](wiki/DevelopingThemes.md) | Create custom themes |

## Available Plugins

<details>
<summary><strong>System Monitoring</strong> (12 plugins)</summary>

`battery` `cpu` `memory` `disk` `loadavg` `temperature` `fan` `gpu` `iops` `uptime` `volume` `brightness`

</details>

<details>
<summary><strong>Network</strong> (7 plugins)</summary>

`network` `wifi` `vpn` `ping` `external_ip` `ssh` `weather`

</details>

<details>
<summary><strong>Development</strong> (8 plugins)</summary>

`git` `github` `gitlab` `bitbucket` `jira` `kubernetes` `terraform` `cloud`

</details>

<details>
<summary><strong>Media & Hardware</strong> (4 plugins)</summary>

`nowplaying` `audiodevices` `camera` `microphone`

</details>

<details>
<summary><strong>Productivity</strong> (5 plugins)</summary>

`datetime` `timezones` `pomodoro` `smartkey` `bitwarden`

</details>

<details>
<summary><strong>Financial & Services</strong> (6 plugins)</summary>

`crypto` `stocks` `cloudstatus` `packages` `bluetooth` `hostname`

</details>

## Themes

| Theme | Variants |
|-------|----------|
| **Catppuccin** | Frappe, Latte, Macchiato, Mocha |
| **Tokyo Night** | Night, Storm, Day |
| **Rose Pine** | Main, Moon, Dawn |
| **Gruvbox** | Dark, Light |
| **Everforest** | Dark, Light |
| **Solarized** | Dark, Light |
| **GitHub** | Dark, Light |
| **Nord** | Dark |
| **Dracula** | Dark |
| **OneDark** | Dark |
| **Kanagawa** | Dragon, Lotus |
| **Kiribyte** | Dark, Light |
| **Pastel** | Dark, Light |

See [Themes Documentation](wiki/Themes.md) for previews and configuration.

## Architecture

PowerKit v2 uses a contract-based architecture with strict separation of concerns:

```text
Plugin          Renderer         Theme
  |                |               |
  +-- Data         +-- Colors      +-- Color definitions
  +-- State        +-- Icons
  +-- Health       +-- Separators
  +-- Context      +-- Formatting
```

- **Plugins** collect data and report state/health
- **Renderer** handles all UI decisions (colors, icons, formatting)
- **Themes** define color palettes only

Learn more in the [Architecture Documentation](wiki/Architecture.md).

## Requirements

- **tmux** 3.0+
- **Bash** 4.0+
- **TPM** (Tmux Plugin Manager)

Some plugins require additional dependencies. See individual plugin documentation.

## Contributing

Contributions are welcome! Please read the [Development Guide](wiki/DevelopingPlugins.md) before submitting PRs.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Made with care by [@fabioluciano](https://github.com/fabioluciano)
