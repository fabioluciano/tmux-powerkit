#!/usr/bin/env bash
# =============================================================================
# Plugin: git
# Description: Display current git branch and status
# Type: conditional (hidden when not in a git repository)
# Dependencies: git
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Dependency Check (Plugin Contract)
# =============================================================================

plugin_check_dependencies() {
    require_cmd "git" || return 1
    return 0
}

# =============================================================================
# Options Declaration
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U000F01D2' "Plugin icon"

    # Colors - Default (clean state)
    declare_option "accent_color" "color" "secondary" "Background color for clean state"
    declare_option "accent_color_icon" "color" "active" "Icon background color for clean state"

    # Colors - Modified state
    declare_option "modified_accent_color" "color" "warning" "Background color for modified state"
    declare_option "modified_accent_color_icon" "color" "warning-subtle" "Icon background color for modified state"

    # Cache
    declare_option "cache_ttl" "number" "15" "Cache duration in seconds"
}

plugin_init "git"

# =============================================================================
# Main Logic
# =============================================================================

_get_git_info() {
    local path=$(tmux display-message -p '#{pane_current_path}')
    [[ -z "$path" || ! -d "$path" ]] && return

    # Use git -C instead of subshell (performance: avoids fork overhead)
    git -C "$path" rev-parse --is-inside-work-tree &>/dev/null || return

    git -C "$path" status --porcelain=v1 --branch 2>/dev/null | awk '
        NR==1 { gsub(/^## /, ""); gsub(/\.\.\..*/, ""); branch=$0 }
        NR>1 { s=substr($0,1,2); if(s=="??") u++; else if(s!="  ") c++; mod=1 }
        END {
            if(branch) {
                r=branch; if(c>0) r=r" ~"c; if(u>0) r=r" +"u
                if(mod) r="MODIFIED:"r
                print r
            }
        }'
}

# =============================================================================
# Plugin Contract Implementation
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    if [[ "$content" == modified:* ]]; then
        local a=$(get_option "modified_accent_color")
        local ai=$(get_option "modified_accent_color_icon")
        printf '1:%s:%s:' "$a" "$ai"
    else
        local a=$(get_option "accent_color")
        local ai=$(get_option "accent_color_icon")
        printf '1:%s:%s:' "$a" "$ai"
    fi
}

_get_cache_key() {
    local path=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
    # Use pure bash hash (avoids fork to md5sum/md5)
    local hash="${path//[^a-zA-Z0-9]/_}"
    printf 'git_%s' "$hash"
}

load_plugin() {
    local key=$(_get_cache_key)
    cache_get_or_compute "$key" "$CACHE_TTL" _get_git_info
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
