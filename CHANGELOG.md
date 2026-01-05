# Changelog

All notable changes to tmux-powerkit will be documented in this file.

## [5.7.1](https://github.com/fabioluciano/tmux-powerkit/compare/v5.7.0...v5.7.1) (2026-01-05)

### Bug Fixes

* correct spacing for the first window ([bebcd13](https://github.com/fabioluciano/tmux-powerkit/commit/bebcd134a7a46b0efc8f2f675cefe81f98a88b69))

## [5.7.0](https://github.com/fabioluciano/tmux-powerkit/compare/v5.6.0...v5.7.0) (2026-01-05)

### Features

* Add popup and menu color definitions across various themes ([2bf0369](https://github.com/fabioluciano/tmux-powerkit/commit/2bf03698feefc2f1d0e159dd169ab77cde11bb57))

## [5.6.0](https://github.com/fabioluciano/tmux-powerkit/compare/v5.5.0...v5.6.0) (2026-01-05)

### Features

* **pane:** add border status background and unified border options ([8c40e47](https://github.com/fabioluciano/tmux-powerkit/commit/8c40e4730253bae1bedf15759bfcd8003107f3b5))
* **plugins:** add plugin groups with group() syntax ([7d17301](https://github.com/fabioluciano/tmux-powerkit/commit/7d1730192c0a40a847375ed398392775a72b917c))
* **plugins:** add plugin groups with group() syntax ([dac7f15](https://github.com/fabioluciano/tmux-powerkit/commit/dac7f15dd8c516268cd19ed7bf4313141bb4d50f))
* **plugins:** implement external plugin rendering support ([9d972a6](https://github.com/fabioluciano/tmux-powerkit/commit/9d972a6fe27bc6866382c37fe5610f5ddb9b754b)), closes [#S](https://github.com/fabioluciano/tmux-powerkit/issues/S) [#I](https://github.com/fabioluciano/tmux-powerkit/issues/I) [#W](https://github.com/fabioluciano/tmux-powerkit/issues/W)
* **themes:** add 19 new themes with 29 variants ([d4f0b30](https://github.com/fabioluciano/tmux-powerkit/commit/d4f0b301c180c7637290fc61cdbf9f48312ec4e7))

### Bug Fixes

* **windows:** correct window index icon codepoints and support base-index ([74dc99b](https://github.com/fabioluciano/tmux-powerkit/commit/74dc99b298bc0e558733b9a7036791565efa7691))

## [5.5.0](https://github.com/fabioluciano/tmux-powerkit/compare/v5.4.0...v5.5.0) (2025-12-30)

### Features

* implement macOS native binary download system with interactive prompt ([#148](https://github.com/fabioluciano/tmux-powerkit/issues/148)) ([1c79677](https://github.com/fabioluciano/tmux-powerkit/commit/1c796779c2ef01b77b391dddda46696bf83b9d61))

## [5.4.0](https://github.com/fabioluciano/tmux-powerkit/compare/v5.3.0...v5.4.0) (2025-12-30)

### Features

* refactor semantic-release configuration for improved artifact handling and build process ([34a8e75](https://github.com/fabioluciano/tmux-powerkit/commit/34a8e75f77c5e68fd6f24dcd6e07e9134530a932))

## [5.3.0](https://github.com/fabioluciano/tmux-powerkit/compare/v5.2.0...v5.3.0) (2025-12-30)

### Features

* Add native macOS helpers for microphone status, now playing info, and temperature readings ([#147](https://github.com/fabioluciano/tmux-powerkit/issues/147)) ([33054db](https://github.com/fabioluciano/tmux-powerkit/commit/33054db175af277a50aab915ebbce8400a77bb51))
* update macOS versions in semantic release workflow to support macOS 15 ([0ba4335](https://github.com/fabioluciano/tmux-powerkit/commit/0ba4335a8f9cec4bfe04c6548ae503af4ef8923d))
* update semantic-release and related packages to latest versions ([c258e93](https://github.com/fabioluciano/tmux-powerkit/commit/c258e93e890d178e8ae5c72f585f7941a5321b9c))

### Bug Fixes

* correct variable reference in prepare and publish commands ([20ac6d9](https://github.com/fabioluciano/tmux-powerkit/commit/20ac6d9614545366a7fafee2f439516d2aca8d21))

# [5.2.0](https://github.com/fabioluciano/tmux-powerkit/compare/v5.1.0...v5.2.0) (2025-12-29)


### Features

* implement lazy loading for plugin data with stale-while-revalid… ([#146](https://github.com/fabioluciano/tmux-powerkit/issues/146)) ([1d628bb](https://github.com/fabioluciano/tmux-powerkit/commit/1d628bbaf2dfcbf3aa83882bbc2c70fd0bd44857))

# [5.1.0](https://github.com/fabioluciano/tmux-powerkit/compare/v5.0.2...v5.1.0) (2025-12-28)


### Features

* refactor rendering system with entity-based compositor architecture; enhance Linux plugin support ([#145](https://github.com/fabioluciano/tmux-powerkit/issues/145)) ([ce0a11a](https://github.com/fabioluciano/tmux-powerkit/commit/ce0a11a7760fbd2f835c79ba3839afb414639f94))

## [5.0.2](https://github.com/fabioluciano/tmux-powerkit/compare/v5.0.1...v5.0.2) (2025-12-27)


### Bug Fixes

* update Options Reference link in README for direct access ([9cd35b6](https://github.com/fabioluciano/tmux-powerkit/commit/9cd35b6a07c001ab57db1162bd6925b16e6b0ec2))

## [5.0.1](https://github.com/fabioluciano/tmux-powerkit/compare/v5.0.0...v5.0.1) (2025-12-27)


### Bug Fixes

* update links in README for documentation consistency ([7553fd9](https://github.com/fabioluciano/tmux-powerkit/commit/7553fd9e72bde30a45907ac5413452515b5a6dbd))

# [5.0.0](https://github.com/fabioluciano/tmux-powerkit/compare/v4.4.0...v5.0.0) (2025-12-27)


* feat!: rewrite to v5 contract-based architecture ([#142](https://github.com/fabioluciano/tmux-powerkit/issues/142)) ([3f36b6f](https://github.com/fabioluciano/tmux-powerkit/commit/3f36b6f7ef3d91130733d785011784916a7db3f9))


### BREAKING CHANGES

* Complete architectural overhaul. All plugins, themes,
and configurations must be updated to the new v5 contract system.

Architecture Changes:
- Introduce contract-based plugin system with strict separation of concerns
- Plugins now provide data and semantics only (no UI decisions)
- Renderer handles all visual presentation (colors, icons, formatting)
- Themes define colors only (no logic or functions)

New Directory Structure:
- src/core/       Core framework (bootstrap, lifecycle, cache, options)
- src/contract/   Contract definitions (plugin, theme, helper, session, window)
- src/renderer/   Visual rendering (segments, separators, colors)
- src/plugins/    All 42 plugins migrated to v5 contract
- src/utils/      Utility functions (platform, strings, numbers, etc.)
- src/helpers/    Interactive UI helpers

Plugin Contract Changes:
- Mandatory functions: plugin_collect(), plugin_render(), plugin_get_state(),
  plugin_get_health(), plugin_get_content_type(), plugin_get_presence()
- plugin_render() returns TEXT ONLY (no colors, no tmux formatting)
- Health levels: ok, good, info, warning, error
- States: inactive, active, degraded, failed
- Removed: accent_color, plugin_get_display_info(), plugin_get_type()

Theme Contract Changes:
- 22 required base colors
- Auto-generated variants (lighter/darker) via color_generator
- Removed all logic from theme files
- 24-hour theme color caching

New Features:
- Multi-layer caching system (memory, render, operation, theme)
- Cache-before-source optimization for performance
- macOS native binaries for efficient metrics (temperature, gpu, microphone, nowplaying)
- Plugin validator for contract compliance checking
- Template generator for new plugins/helpers/themes
- Centralized registry for constants and enums
- Helper contract with UI backend abstraction (gum/fzf)

Plugins:
- All 42 plugins migrated to v5 contract
- New plugins: crypto, stocks, iops, pomodoro
- Renamed: network → netspeed
- Platform-specific plugins return inactive state on unsupported platforms

Breaking Configuration Changes:
- Plugin options format: @powerkit_plugin_<name>_<option>
- Theme format: @powerkit_theme, @powerkit_theme_variant
- Removed: legacy plugin options, accent_color settings

# [4.4.0](https://github.com/fabioluciano/tmux-powerkit/compare/v4.3.0...v4.4.0) (2025-12-20)


### Features

* Refactor and enhance various scripts and themes ([#140](https://github.com/fabioluciano/tmux-powerkit/issues/140)) ([0c51938](https://github.com/fabioluciano/tmux-powerkit/commit/0c51938caf2b0e9f3d7fc6ffdca7f1ffe56c468c))

# [4.3.0](https://github.com/fabioluciano/tmux-powerkit/compare/v4.2.0...v4.3.0) (2025-12-19)


### Features

* **external:** expand #{...} tmux variables inside $(command) and #(command) ([#139](https://github.com/fabioluciano/tmux-powerkit/issues/139)) ([672fe8d](https://github.com/fabioluciano/tmux-powerkit/commit/672fe8d0fa159742fad11e200e0c7873fec71df4))

# [4.2.0](https://github.com/fabioluciano/tmux-powerkit/compare/v4.1.2...v4.2.0) (2025-12-19)


### Features

* enhance plugin display logic and add customization options for element spacing ([1e848e5](https://github.com/fabioluciano/tmux-powerkit/commit/1e848e513c0e49e631a77df8e5b33756521e5f4f))

## [4.1.2](https://github.com/fabioluciano/tmux-powerkit/compare/v4.1.1...v4.1.2) (2025-12-19)


### Bug Fixes

* streamline cache handling and improve plugin display logic; add … ([#137](https://github.com/fabioluciano/tmux-powerkit/issues/137)) ([3f76c89](https://github.com/fabioluciano/tmux-powerkit/commit/3f76c89ec24517890323b6f101f45d8ff96e870a))

## [4.1.1](https://github.com/fabioluciano/tmux-powerkit/compare/v4.1.0...v4.1.1) (2025-12-19)


### Bug Fixes

* streamline cache handling and improve plugin display logic; add … ([#136](https://github.com/fabioluciano/tmux-powerkit/issues/136)) ([5651ed2](https://github.com/fabioluciano/tmux-powerkit/commit/5651ed269005dfe1182b3b27666cfff77431e74d))

# [4.1.0](https://github.com/fabioluciano/tmux-powerkit/compare/v4.0.4...v4.1.0) (2025-12-18)


### Features

* Update theme color definitions and add new themes ([#135](https://github.com/fabioluciano/tmux-powerkit/issues/135)) ([f1b4a03](https://github.com/fabioluciano/tmux-powerkit/commit/f1b4a03b0aee511959936622240e9839063c7802))

## [4.0.4](https://github.com/fabioluciano/tmux-powerkit/compare/v4.0.3...v4.0.4) (2025-12-17)


### Bug Fixes

* handle unbound variable errors in battery display and package manager detection; enhance SSH destination retrieval ([1ff6133](https://github.com/fabioluciano/tmux-powerkit/commit/1ff613319aa1c19e212c06484c757d28d57c2cf3))

## [4.0.3](https://github.com/fabioluciano/tmux-powerkit/compare/v4.0.2...v4.0.3) (2025-12-17)


### Bug Fixes

* update theme colors for improved consistency across various themes ([#133](https://github.com/fabioluciano/tmux-powerkit/issues/133)) ([8b7d092](https://github.com/fabioluciano/tmux-powerkit/commit/8b7d092bdf490384a3777dfc223cc55777cea009))

## [4.0.2](https://github.com/fabioluciano/tmux-powerkit/compare/v4.0.1...v4.0.2) (2025-12-17)


### Bug Fixes

* correct typo in Bitwarden unlock height variable ([#132](https://github.com/fabioluciano/tmux-powerkit/issues/132)) ([127517a](https://github.com/fabioluciano/tmux-powerkit/commit/127517a42704b24601ca3fe8e31c189db014c89c))

## [4.0.1](https://github.com/fabioluciano/tmux-powerkit/compare/v4.0.0...v4.0.1) (2025-12-17)


### Bug Fixes

* adding a missing color ([#130](https://github.com/fabioluciano/tmux-powerkit/issues/130)) ([2789c08](https://github.com/fabioluciano/tmux-powerkit/commit/2789c08b06e2a710be793213c62ceebdd8fca84b))

# [4.0.0](https://github.com/fabioluciano/tmux-powerkit/compare/v3.9.2...v4.0.0) (2025-12-17)


* feat!: add 7 new themes, bitwarden plugin, and reorganize keybindings ([#129](https://github.com/fabioluciano/tmux-powerkit/issues/129)) ([e8d5430](https://github.com/fabioluciano/tmux-powerkit/commit/e8d54308ae8d686f4769e5d3d9bcfe39f543a992))


### BREAKING CHANGES

* Interactive keybindings have been reorganized to avoid conflicts
and improve usability. Users must update their tmux.conf if using custom keybindings.

Keybinding Changes:

    Keybindings viewer: C-g -> C-y
    Clear cache: C-x -> C-d
    Audio input selector: C-i -> C-q
    Audio output selector: C-s -> C-u
    Kubernetes context: C-q -> C-g
    Kubernetes namespace: C-w -> C-s
    Terraform workspace: C-t -> C-f

New Themes (7):

    Catppuccin (mocha, macchiato, frappe, latte)
    Dracula (dark)
    Gruvbox (dark, light)
    Nord (dark)
    One Dark (dark)
    Rosé Pine (main, moon, dawn)
    Solarized (dark, light)

New Plugin:

    bitwarden: Vault status indicator with password selector keybindings
        prefix + C-v: Password selector (copies to tmux buffer)
        prefix + C-w: Unlock vault
        prefix + C-x: Lock vault

New Keybindings:

    prefix + C-r: Theme selector (switch themes interactively)

Improvements:

    DRY refactoring with _plugin_defaults() for automatic color inheritance
    Plugins now use build_display_info() helper for consistent output
    Simplified plugin code using cache_get_or_compute()
    Optional telemetry system for performance monitoring
    Source guards to prevent multiple file sourcing
    Batch tmux option loading for faster startup
    Updated all wiki pages with new keybindings
    Created Bitwarden plugin documentation
    Updated Theme-Variations with all 9 themes
    Updated CLAUDE.md with architecture details

## [3.9.2](https://github.com/fabioluciano/tmux-powerkit/compare/v3.9.1...v3.9.2) (2025-12-16)


### Bug Fixes

* enhance cache invalidation for Homebrew package updates by checking multiple directories ([#128](https://github.com/fabioluciano/tmux-powerkit/issues/128)) ([eaf5e91](https://github.com/fabioluciano/tmux-powerkit/commit/eaf5e9105d9ef8cf7ec5851163e568ad7a3dd1e0))

## [3.9.1](https://github.com/fabioluciano/tmux-powerkit/compare/v3.9.0...v3.9.1) (2025-12-16)


### Bug Fixes

* improve pane border color configuration for clarity and semantic naming ([#127](https://github.com/fabioluciano/tmux-powerkit/issues/127)) ([0bedffe](https://github.com/fabioluciano/tmux-powerkit/commit/0bedffe74eae82ca4e715e344929694a9f8e5614))

# [3.9.0](https://github.com/fabioluciano/tmux-powerkit/compare/v3.8.3...v3.9.0) (2025-12-16)


### Features

* enhance session colors and update keybindings for improved usability ([#125](https://github.com/fabioluciano/tmux-powerkit/issues/125)) ([e78ec89](https://github.com/fabioluciano/tmux-powerkit/commit/e78ec89d9082a47902b7fa03cee1a8cf750ec1e3))

## [3.8.3](https://github.com/fabioluciano/tmux-powerkit/compare/v3.8.2...v3.8.3) (2025-12-15)


### Bug Fixes

* interoperability between oses ([#120](https://github.com/fabioluciano/tmux-powerkit/issues/120)) ([e92b559](https://github.com/fabioluciano/tmux-powerkit/commit/e92b559faddd10dee76f874a0de8b39eaed7f481))

## [3.8.2](https://github.com/fabioluciano/tmux-powerkit/compare/v3.8.1...v3.8.2) (2025-12-15)


### Bug Fixes

* update keybindings to use Alt modifier and improve toast notifications ([#119](https://github.com/fabioluciano/tmux-powerkit/issues/119)) ([f7b598f](https://github.com/fabioluciano/tmux-powerkit/commit/f7b598f2a6e494a91f8a3d08f8ab34ab10e6d408))

## [3.8.1](https://github.com/fabioluciano/tmux-powerkit/compare/v3.8.0...v3.8.1) (2025-12-15)


### Bug Fixes

* **bluetooth:** fixing bluetooth plugin ([#118](https://github.com/fabioluciano/tmux-powerkit/issues/118)) ([5c31fb0](https://github.com/fabioluciano/tmux-powerkit/commit/5c31fb0b6714e382cc4b133901eeb9ad91c51e42))

# [3.8.0](https://github.com/fabioluciano/tmux-powerkit/compare/v3.7.1...v3.8.0) (2025-12-14)


### Features

* **github:** add github plugin ([#117](https://github.com/fabioluciano/tmux-powerkit/issues/117)) ([3907f64](https://github.com/fabioluciano/tmux-powerkit/commit/3907f648a66518d9da67eb8cf7bad837c938c3e2))

## [3.7.1](https://github.com/fabioluciano/tmux-powerkit/compare/v3.7.0...v3.7.1) (2025-12-13)


### Bug Fixes

* **cache:** add cache_init in init file ([#114](https://github.com/fabioluciano/tmux-powerkit/issues/114)) ([c42c6c7](https://github.com/fabioluciano/tmux-powerkit/commit/c42c6c7b5720caab52601cc59cf5ada790eb3250))

# [3.7.0](https://github.com/fabioluciano/tmux-powerkit/compare/v3.6.0...v3.7.0) (2025-12-12)


### Features

* **weather:** add dynamic icon fetching and update weather format ([#112](https://github.com/fabioluciano/tmux-powerkit/issues/112)) ([0073530](https://github.com/fabioluciano/tmux-powerkit/commit/0073530f47252c4e201492f69e8e9006ce076e81))

# [3.6.0](https://github.com/fabioluciano/tmux-powerkit/compare/v3.5.0...v3.6.0) (2025-12-12)


### Features

* **separators:** add customizable separator styles and update documentation ([#110](https://github.com/fabioluciano/tmux-powerkit/issues/110)) ([f7921f9](https://github.com/fabioluciano/tmux-powerkit/commit/f7921f9f071878f81d2648eaf31391f126841e70))

# [3.5.0](https://github.com/fabioluciano/tmux-powerkit/compare/v3.4.0...v3.5.0) (2025-12-11)


### Features

* Add new plugins for system monitoring and management ([#105](https://github.com/fabioluciano/tmux-powerkit/issues/105)) ([5b86642](https://github.com/fabioluciano/tmux-powerkit/commit/5b866428071c5f13c913fe90a8dca0bb2d0d1d2e))

# [3.4.0](https://github.com/fabioluciano/tmux-powerkit/compare/v3.3.0...v3.4.0) (2025-12-11)


### Features

* **cache:** add option to custom set the cache directory inside XDG cache directory ([#104](https://github.com/fabioluciano/tmux-powerkit/issues/104)) ([686f476](https://github.com/fabioluciano/tmux-powerkit/commit/686f476fc0401265beed90ea94acfc5a1ba9b4de))

# [3.3.0](https://github.com/fabioluciano/tmux-powerkit/compare/v3.2.0...v3.3.0) (2025-12-11)


### Features

* **packages:** add cache invalidation for package upgrades ([#103](https://github.com/fabioluciano/tmux-powerkit/issues/103)) ([becef26](https://github.com/fabioluciano/tmux-powerkit/commit/becef26b65d9d33383fbdf59a02de80aab2c2c66))

# [3.2.0](https://github.com/fabioluciano/tmux-powerkit/compare/v3.1.0...v3.2.0) (2025-12-10)


### Features

* **separators:** add rounded separator options for left and right separators ([74c11ea](https://github.com/fabioluciano/tmux-powerkit/commit/74c11ea7b4ce5ab3a28bde4e11c58d897504291a))

# [3.1.0](https://github.com/fabioluciano/tmux-powerkit/compare/v3.0.1...v3.1.0) (2025-12-10)


### Features

* **options_viewer:** enhance plugin option handling with default values and descriptions ([#102](https://github.com/fabioluciano/tmux-powerkit/issues/102)) ([6767de4](https://github.com/fabioluciano/tmux-powerkit/commit/6767de4e30c32321ea127d938b22a78682685d48))

## [3.0.1](https://github.com/fabioluciano/tmux-powerkit/compare/v3.0.0...v3.0.1) (2025-12-10)


### Bug Fixes

* update references from tmux-powerkit to tmux-powerkit in configuration and scripts ([#101](https://github.com/fabioluciano/tmux-powerkit/issues/101)) ([a3e644b](https://github.com/fabioluciano/tmux-powerkit/commit/a3e644b91bc4c7f65a772eec671bfa4cdb782552))

# [3.0.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.16.1...v3.0.0) (2025-12-10)


* refactor(core)!: project rename, plugin/theme system overhaul, and configuration interface update ([#100](https://github.com/fabioluciano/tmux-powerkit/issues/100)) ([984ce88](https://github.com/fabioluciano/tmux-powerkit/commit/984ce88cf7b2a75a0f4477ce9377d4d7bbf07dd2))


### BREAKING CHANGES

* Project Renaming:
- tmux-powerkit → tmux-powerkit
- Main script renamed: tmux-powerkit.tmux → tmux-powerkit.tmux
- All references, variables, and options migrated to the new name

Complete plugin system refactor:
- Old plugin rendering and initialization pipeline removed
- New modular system for plugin initialization, configuration, and rendering
- Plugins now use a unified interface for options, colors, and types
- Added new conditional display options (e.g., display_condition, display_threshold)
- Plugins now support dynamic hiding based on state (e.g., battery 100% and charging)

New semantic theme and color architecture:
- PowerKit Theme Mapping implemented: themes now use universal semantic names (accent, warning, error, etc.)
- Added alternative themes (e.g., kiribyte, tokyo-night)
- Colors and styles are now resolved dynamically via utility functions

Major changes to tmux configuration:
- tmux options migrated to new @powerkit_* prefix
-  New status bar layouts: support for single/double layout, separators, and final formats
- Help and option viewer keybindings are now configurable and modular
- Appearance, borders, messages, and status bar options now use the theme system

Documentation update and restructuring:
- Wiki submodule updated with complete option tables for all plugins
- Migration documentation, examples, and plugin behavior reviewed
- ew options documented: conditional display, state-based hiding, custom thresholds

Utility function removal and simplification:
- utils.sh rewritten to follow KISS/DRY, removing old and duplicate functions
- Color, OS detection, and tmux option getter functions are now universal and centralized

Impact: Full breaking change: old configurations, scripts, and themes are incompatible Users must migrate all options to the new @powerkit_* standard Old plugins, custom themes, and automations may not work without adaptation

This refactor prepares the project for extensibility, modularity, and standardization, but requires manual migration of existing configurations and scripts.

## [2.16.1](https://github.com/fabioluciano/tmux-powerkit/compare/v2.16.0...v2.16.1) (2025-12-04)


### Bug Fixes

* Linux distribution icons not rendering correctly ([#98](https://github.com/fabioluciano/tmux-powerkit/issues/98)) ([7cee3a8](https://github.com/fabioluciano/tmux-powerkit/commit/7cee3a87c0613c0f553862ac1f02cae5d01e5439))

# [2.16.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.15.0...v2.16.0) (2025-12-04)


### Features

* Enhance git plugin with dynamic color changes for modified branches and improve volume plugin responsiveness ([#97](https://github.com/fabioluciano/tmux-powerkit/issues/97)) ([715caed](https://github.com/fabioluciano/tmux-powerkit/commit/715caedde5c39896170810c8cb9e239df1d3cbd4))

# [2.15.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.14.0...v2.15.0) (2025-12-03)


### Features

* **plugin:** rename yubikey plugin to smartkey with expanded hardwar… ([#95](https://github.com/fabioluciano/tmux-powerkit/issues/95)) ([89bd3b6](https://github.com/fabioluciano/tmux-powerkit/commit/89bd3b675c382b481e6145b467475a4060219966))

# [2.14.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.13.0...v2.14.0) (2025-12-03)


### Features

* Disable camera and microphone plugins on macOS ([7338e41](https://github.com/fabioluciano/tmux-powerkit/commit/7338e411cbe0e5ecea9ed7fa20ab52fa2ea07c06))

# [2.13.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.12.0...v2.13.0) (2025-12-03)


### Features

* Enhance performance and add camera plugin ([#94](https://github.com/fabioluciano/tmux-powerkit/issues/94)) ([10c9740](https://github.com/fabioluciano/tmux-powerkit/commit/10c9740369dcd96a1d04f76638897e93c0f9731f))

# [2.12.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.11.0...v2.12.0) (2025-12-02)


### Features

* add audiodevices ([#93](https://github.com/fabioluciano/tmux-powerkit/issues/93)) ([9329369](https://github.com/fabioluciano/tmux-powerkit/commit/9329369f590a4386d974dcb7d085c673477c52f8))

# [2.11.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.10.0...v2.11.0) (2025-12-01)


### Features

* weather plugin and enhance media management ([#92](https://github.com/fabioluciano/tmux-powerkit/issues/92)) ([11ccb0c](https://github.com/fabioluciano/tmux-powerkit/commit/11ccb0c05c4f12ee93065d3e8356714f6205f3ce))

# [2.10.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.9.0...v2.10.0) (2025-12-01)


### Features

* add brightness and cloud plugins with configuration options ([#89](https://github.com/fabioluciano/tmux-powerkit/issues/89)) ([8274609](https://github.com/fabioluciano/tmux-powerkit/commit/8274609ad28c24922885f4d1a769d3663dfcc320))

# [2.9.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.8.0...v2.9.0) (2025-12-01)


### Features

* enhance Bluetooth plugin to display connected devices and battery status ([ba92854](https://github.com/fabioluciano/tmux-powerkit/commit/ba92854625a9f3da3a09b8cd7e70c119e5137722))

# [2.8.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.7.2...v2.8.0) (2025-11-30)


### Features

* add workflows and icon per session ([#88](https://github.com/fabioluciano/tmux-powerkit/issues/88)) ([42414df](https://github.com/fabioluciano/tmux-powerkit/commit/42414df9f39d1760457553f189f8edf0ecb8c2c1))

## [2.7.2](https://github.com/fabioluciano/tmux-powerkit/compare/v2.7.1...v2.7.2) (2025-11-30)


### Bug Fixes

* improve memory display function by removing unused variable ([#87](https://github.com/fabioluciano/tmux-powerkit/issues/87)) ([5a909b8](https://github.com/fabioluciano/tmux-powerkit/commit/5a909b8e0413a1ee2efa8e76ce23dbaff48453cc))

## [2.7.1](https://github.com/fabioluciano/tmux-powerkit/compare/v2.7.0...v2.7.1) (2025-11-30)


### Bug Fixes

* separators ([325afc1](https://github.com/fabioluciano/tmux-powerkit/commit/325afc1421b0bdd6194cffc34eb36c1f4b40bd75))

# [2.7.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.6.0...v2.7.0) (2025-11-30)


### Features

* add conditional visibility for Bluetooth plugin ([#84](https://github.com/fabioluciano/tmux-powerkit/issues/84)) ([43c312d](https://github.com/fabioluciano/tmux-powerkit/commit/43c312d249f33824a113a522bdc23e956b2d513a))

# [2.6.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.5.0...v2.6.0) (2025-11-30)


### Features

* add external IP, temperature, VPN, and WiFi plugins ([#83](https://github.com/fabioluciano/tmux-powerkit/issues/83)) ([3eb8d57](https://github.com/fabioluciano/tmux-powerkit/commit/3eb8d57d180e405b632c53bef4c8463f272d9215))

# [2.5.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.4.0...v2.5.0) (2025-11-30)


### Features

* add tmux keybindings and options viewer scripts ([251bf57](https://github.com/fabioluciano/tmux-powerkit/commit/251bf57d507af1453b67e00e4824c4050776b568))
* Enhance weather plugin with customizable formats and caching ([ea82a81](https://github.com/fabioluciano/tmux-powerkit/commit/ea82a81e24a41ce3b3a589f224de1db3e4ecc207))
* implement volume plugin with customizable icons and caching ([#82](https://github.com/fabioluciano/tmux-powerkit/issues/82)) ([04f81b4](https://github.com/fabioluciano/tmux-powerkit/commit/04f81b45d7be1f30985ea01b6e78379919bd9047))
* add tmux keybindings and options viewer scripts ([251bf57](https://github.com/fabioluciano/tmux-powerkit/commit/251bf57d507af1453b67e00e4824c4050776b568))
* Enhance weather plugin with customizable formats and caching ([ea82a81](https://github.com/fabioluciano/tmux-powerkit/commit/ea82a81e24a41ce3b3a589f224de1db3e4ecc207))

# [2.4.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.3.0...v2.4.0) (2025-11-29)


### Features

* Implement dynamic color thresholds and conditional display for plugins ([#79](https://github.com/fabioluciano/tmux-powerkit/issues/79)) ([f3a61ad](https://github.com/fabioluciano/tmux-powerkit/commit/f3a61addaf36a7675082f709bf033a9f6ea06c93))

# [2.3.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.2.1...v2.3.0) (2025-11-27)


### Features

* Add disk and load average plugins with caching and performance optimizations ([#78](https://github.com/fabioluciano/tmux-powerkit/issues/78)) ([908f1d1](https://github.com/fabioluciano/tmux-powerkit/commit/908f1d1e1e629cf4686a12604b1a3c85a38ef65b))

## [2.2.1](https://github.com/fabioluciano/tmux-powerkit/compare/v2.2.0...v2.2.1) (2025-11-27)


### Bug Fixes

* Improve CPU usage calculation on macOS by averaging over cores ([#77](https://github.com/fabioluciano/tmux-powerkit/issues/77)) ([a14aa11](https://github.com/fabioluciano/tmux-powerkit/commit/a14aa11b1a8243fab930f04fe8c5a55c7cab8448))

# [2.2.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.1.0...v2.2.0) (2025-11-27)


### Features

* Enhance caching and performance optimizations across plugins ([#75](https://github.com/fabioluciano/tmux-powerkit/issues/75)) ([2b6f386](https://github.com/fabioluciano/tmux-powerkit/commit/2b6f386c10270543484d5b19654b72ac7b2ae10f))

# [2.1.0](https://github.com/fabioluciano/tmux-powerkit/compare/v2.0.0...v2.1.0) (2025-11-27)


### Features

* implement configurable cache TTL for plugins ([49aa909](https://github.com/fabioluciano/tmux-powerkit/commit/49aa909b2cca06593628be1f21bdd442d9b0c1bd))

# [2.0.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.11.0...v2.0.0) (2025-11-27)


* feat!: fixes and other things ([#74](https://github.com/fabioluciano/tmux-powerkit/issues/74)) ([e24e503](https://github.com/fabioluciano/tmux-powerkit/commit/e24e503c3d5fc7ca4bed727baf38ceb948242d74))


### BREAKING CHANGES

* just for version bump

# [1.11.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.10.1...v1.11.0) (2025-07-27)


### Features

* **playerctl:** add ability to ignore players ([eef5451](https://github.com/fabioluciano/tmux-powerkit/commit/eef5451ce3e30d4681f4dbeab3ca015f7290a6bf))

## [1.10.1](https://github.com/fabioluciano/tmux-powerkit/compare/v1.10.0...v1.10.1) (2025-06-28)


### Bug Fixes

* Improve tmux compatibility ([6c67c7b](https://github.com/fabioluciano/tmux-powerkit/commit/6c67c7b591f5d017bfd27b3716ae08e18ad4b529))

# [1.10.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.9.0...v1.10.0) (2024-11-29)


### Features

* **weather:** add support for overriding IP-based location ([8f2421a](https://github.com/fabioluciano/tmux-powerkit/commit/8f2421acb443ce1ab206d1d090fecb7a59efeffd))

# [1.9.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.8.1...v1.9.0) (2024-10-29)


### Features

* Allow customizing the window title string ([e064b37](https://github.com/fabioluciano/tmux-powerkit/commit/e064b37f00c6b5cd3754c6da1d4f7fbff11c225b))

## [1.8.1](https://github.com/fabioluciano/tmux-powerkit/compare/v1.8.0...v1.8.1) (2024-10-24)


### Bug Fixes

* extra space after active window name ([29a086e](https://github.com/fabioluciano/tmux-powerkit/commit/29a086e354fb9e99fef60058cab9a112818a6dd4))
* Forgot transparent and left_separator_inverse ([a0228fe](https://github.com/fabioluciano/tmux-powerkit/commit/a0228fec97267dbf395862787a3bb981b44a3dc3))
* removing theme_enable_icons ([c053ee2](https://github.com/fabioluciano/tmux-powerkit/commit/c053ee2562cfdecbadca59fde6d62f15194c1602))
* run shellcheck on pull_requests ([31d10c0](https://github.com/fabioluciano/tmux-powerkit/commit/31d10c065af23fee3bd1f59cf27cc24b3429e13f))
* shellcheck warnings ([8d706a9](https://github.com/fabioluciano/tmux-powerkit/commit/8d706a9631e88f5aba35f41ce7c3c71e22ca2833))
* shellcheck warnings about unused vars ([6a340c8](https://github.com/fabioluciano/tmux-powerkit/commit/6a340c80148eee0a1d7af78ac38376971d2bb73f))
* **shellcheck:** run files together to fix SC1091 ([df678f1](https://github.com/fabioluciano/tmux-powerkit/commit/df678f107726f1463667b5e2f5290bae13ff87fd))

# [1.8.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.7.1...v1.8.0) (2024-10-01)


### Features

* fix [#37](https://github.com/fabioluciano/tmux-powerkit/issues/37) transparency support ([3be2aa2](https://github.com/fabioluciano/tmux-powerkit/commit/3be2aa280242941947d31a0386764e7f78b734bd))

## [1.7.1](https://github.com/fabioluciano/tmux-powerkit/compare/v1.7.0...v1.7.1) (2024-09-11)


### Bug Fixes

* add battery to list of plugins in table ([bc4d532](https://github.com/fabioluciano/tmux-powerkit/commit/bc4d5321a60c160844f85fb6a9c48f6d7c628f89))
* **battery:** Colors / icons not updating ([106bc2b](https://github.com/fabioluciano/tmux-powerkit/commit/106bc2bd33cd99ffdf042df2f5aff8448550fea6))
* **battery:** remove space after battery icon ([1d7ca1f](https://github.com/fabioluciano/tmux-powerkit/commit/1d7ca1fbdf63e427b998b7dbc7d4ac8bcdbf44a6))
* removing unused line ([8e51ec2](https://github.com/fabioluciano/tmux-powerkit/commit/8e51ec211cf6286997db5acfe3ba594492020bfe))

# [1.7.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.6.0...v1.7.0) (2024-08-06)


### Features

* added additional icons customization options ([0b686ee](https://github.com/fabioluciano/tmux-powerkit/commit/0b686ee22f02ae1ac437b06a1bf8241861b3c07b))

# [1.6.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.5.2...v1.6.0) (2024-07-29)


### Features

* add synchronized panes indicator ([ecde261](https://github.com/fabioluciano/tmux-powerkit/commit/ecde2617a5eece581d9f78e07e53e36eea5980da))

## [1.5.2](https://github.com/fabioluciano/tmux-powerkit/compare/v1.5.1...v1.5.2) (2024-06-04)


### Bug Fixes

* typos ([c698679](https://github.com/fabioluciano/tmux-powerkit/commit/c6986790a5a48d4d04da9f5c03919a70b1eb58fd))

## [1.5.1](https://github.com/fabioluciano/tmux-powerkit/compare/v1.5.0...v1.5.1) (2024-06-03)


### Bug Fixes

* yay and homebrew signals when there is no packages to update ([bf7b935](https://github.com/fabioluciano/tmux-powerkit/commit/bf7b935a4458b4ab2700255bb237661eff48c28f))

# [1.5.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.4.1...v1.5.0) (2024-06-02)


### Features

* add yay plugin ([6209478](https://github.com/fabioluciano/tmux-powerkit/commit/6209478e2df93d957e647a5c028ffaf2dc1c53c2))

## [1.4.1](https://github.com/fabioluciano/tmux-powerkit/compare/v1.4.0...v1.4.1) (2024-06-01)


### Bug Fixes

* fixing typo ([5fa4885](https://github.com/fabioluciano/tmux-powerkit/commit/5fa4885bbf28bb743e54f46f0e999846d162d2b7))

# [1.4.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.3.0...v1.4.0) (2024-06-01)


### Features

* add homebrew plugin ([31d411c](https://github.com/fabioluciano/tmux-powerkit/commit/31d411c4c4d5a131142906f2d9bdf768e81b46f7))

# [1.3.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.2.1...v1.3.0) (2024-05-31)


### Features

* adding the option to customize the session icon ([1f768eb](https://github.com/fabioluciano/tmux-powerkit/commit/1f768eb941840b778b8c2b68f1d3abfdfbed9fc3))

## [1.2.1](https://github.com/fabioluciano/tmux-powerkit/compare/v1.2.0...v1.2.1) (2024-05-31)


### Bug Fixes

* fixing [@theme-plugins](https://github.com/theme-plugins) parameter for [@theme](https://github.com/theme)_plugins ([d8b0253](https://github.com/fabioluciano/tmux-powerkit/commit/d8b0253288c4b101eddeaf4c879de3c9ee65184d))

# [1.2.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.1.0...v1.2.0) (2024-05-31)


### Features

* **spt-plugin:** add spotify-tui plugin ([377248d](https://github.com/fabioluciano/tmux-powerkit/commit/377248de5784ba7da3a6c912a8005d4bdc403acb))

# [1.1.0](https://github.com/fabioluciano/tmux-powerkit/compare/v1.0.0...v1.1.0) (2024-05-30)


### Features

* **weather-plugin:** check for jq first ([e80576b](https://github.com/fabioluciano/tmux-powerkit/commit/e80576b2d771b2a134f75820d3852ce3de2651a8))
