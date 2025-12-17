feat!: add 7 new themes, bitwarden plugin, and reorganize keybindings

BREAKING CHANGE: Interactive keybindings have been reorganized to avoid conflicts
and improve usability. Users must update their tmux.conf if using custom keybindings.

Keybinding Changes:
- Keybindings viewer: C-g -> C-y
- Clear cache: C-x -> C-d
- Audio input selector: C-i -> C-q
- Audio output selector: C-s -> C-u
- Kubernetes context: C-q -> C-g
- Kubernetes namespace: C-w -> C-s
- Terraform workspace: C-t -> C-f

New Themes (7):
- Catppuccin (mocha, macchiato, frappe, latte)
- Dracula (dark)
- Gruvbox (dark, light)
- Nord (dark)
- One Dark (dark)
- Rosé Pine (main, moon, dawn)
- Solarized (dark, light)

New Plugin:
- bitwarden: Vault status indicator with password selector keybindings
  - prefix + C-v: Password selector (copies to tmux buffer)
  - prefix + C-w: Unlock vault
  - prefix + C-x: Lock vault

New Keybindings:
- prefix + C-r: Theme selector (switch themes interactively)

Improvements:
- DRY refactoring with _plugin_defaults() for automatic color inheritance
- Plugins now use build_display_info() helper for consistent output
- Simplified plugin code using cache_get_or_compute()
- Optional telemetry system for performance monitoring
- Source guards to prevent multiple file sourcing
- Batch tmux option loading for faster startup
- Updated all wiki pages with new keybindings
- Created Bitwarden plugin documentation
- Updated Theme-Variations with all 9 themes
- Updated CLAUDE.md with architecture details
