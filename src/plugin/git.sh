#!/usr/bin/env bash
# Plugin: git - Display current git branch and status

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "git"

get_git_info() {
    local path=$(tmux display-message -p '#{pane_current_path}')
    [[ -z "$path" || ! -d "$path" ]] && return

    (
        cd "$path" 2>/dev/null || return
        git rev-parse --is-inside-work-tree &>/dev/null || return

        git status --porcelain=v1 --branch 2>/dev/null | awk '
            NR==1 { gsub(/^## /, ""); gsub(/\.\.\..*/, ""); branch=$0 }
            NR>1 { s=substr($0,1,2); if(s=="??") u++; else if(s!="  ") c++; mod=1 }
            END {
                if(branch) {
                    r=branch; if(c>0) r=r" ~"c; if(u>0) r=r" +"u
                    if(mod) r="MODIFIED:"r
                    print r
                }
            }'
    )
}

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    if [[ "$content" == modified:* ]]; then
        local a=$(get_tmux_option "@powerkit_plugin_git_modified_accent_color" "$POWERKIT_PLUGIN_GIT_MODIFIED_ACCENT_COLOR")
        local ai=$(get_tmux_option "@powerkit_plugin_git_modified_accent_color_icon" "$POWERKIT_PLUGIN_GIT_MODIFIED_ACCENT_COLOR_ICON")
        printf '1:%s:%s:' "$a" "$ai"
    else
        local a=$(get_tmux_option "@powerkit_plugin_git_accent_color" "$POWERKIT_PLUGIN_GIT_ACCENT_COLOR")
        local ai=$(get_tmux_option "@powerkit_plugin_git_accent_color_icon" "$POWERKIT_PLUGIN_GIT_ACCENT_COLOR_ICON")
        printf '1:%s:%s:' "$a" "$ai"
    fi
}

get_cache_key() {
    local path=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
    local hash
    if require_cmd md5sum 1; then
        hash=$(printf '%s' "$path" | md5sum | cut -d' ' -f1)
    elif require_cmd md5 1; then
        hash=$(printf '%s' "$path" | md5 -q)
    else
        hash="${path//[^a-zA-Z0-9]/_}"
    fi
    printf 'git_%s' "$hash"
}

load_plugin() {
    local key=$(get_cache_key)
    local cached
    if cached=$(cache_get "$key" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local r=$(get_git_info)
    cache_set "$key" "$r"
    printf '%s' "$r"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
