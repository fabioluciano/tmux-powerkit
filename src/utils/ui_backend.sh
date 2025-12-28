#!/usr/bin/env bash
# =============================================================================
# PowerKit Utils: UI Backend
# Description: Abstract UI backend for helpers (gum > fzf > basic)
# =============================================================================

# Source guard
POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/core/guard.sh"
source_guard "utils_ui_backend" && return 0
#
# This module provides a unified API for interactive UI elements that can
# use different backends depending on what's available:
#   1. gum (preferred) - Modern, beautiful CLI from Charmbracelet
#   2. fzf (fallback)  - Widely available fuzzy finder
#   3. basic (minimal) - Native bash select/read
#
# Configuration:
#   @powerkit_ui_backend "fzf"   - Use fzf (default, fast)
#   @powerkit_ui_backend "gum"   - Force gum (slower startup)
#   @powerkit_ui_backend "auto"  - Auto-detect (prefers gum > fzf > basic)
#   @powerkit_ui_backend "basic" - Force basic
#
# =============================================================================

. "${POWERKIT_ROOT}/src/core/logger.sh"
. "${POWERKIT_ROOT}/src/utils/platform.sh"

# =============================================================================
# Backend Detection
# =============================================================================

# Cache the detected backend for performance
_UI_BACKEND_CACHE=""

# Get configured or auto-detected backend
# Returns: "gum" | "fzf" | "basic"
ui_get_backend() {
    # Return cached value if available
    [[ -n "$_UI_BACKEND_CACHE" ]] && { echo "$_UI_BACKEND_CACHE"; return 0; }

    # Check for forced backend via option
    local forced_backend
    forced_backend=$(get_tmux_option "@powerkit_ui_backend" "fzf")

    case "$forced_backend" in
        gum)
            if has_cmd "gum"; then
                _UI_BACKEND_CACHE="gum"
            else
                log_warn "ui_backend" "gum requested but not found, falling back"
                _UI_BACKEND_CACHE=$(ui_detect_backend)
            fi
            ;;
        fzf)
            if has_cmd "fzf"; then
                _UI_BACKEND_CACHE="fzf"
            else
                log_warn "ui_backend" "fzf requested but not found, falling back"
                _UI_BACKEND_CACHE=$(ui_detect_backend)
            fi
            ;;
        basic)
            _UI_BACKEND_CACHE="basic"
            ;;
        auto|*)
            _UI_BACKEND_CACHE=$(ui_detect_backend)
            ;;
    esac

    echo "$_UI_BACKEND_CACHE"
}

# Auto-detect best available backend
# Returns: "gum" | "fzf" | "basic"
ui_detect_backend() {
    has_cmd "gum" && { echo "gum"; return 0; }
    has_cmd "fzf" && { echo "fzf"; return 0; }
    echo "basic"
}

# Check if a specific backend is available
# Usage: ui_has_backend BACKEND
ui_has_backend() {
    local backend="$1"
    case "$backend" in
        gum)   has_cmd "gum" ;;
        fzf)   has_cmd "fzf" ;;
        basic) return 0 ;;
        *)     return 1 ;;
    esac
}

# Reset backend cache (useful after installing new tools)
ui_reset_backend_cache() {
    _UI_BACKEND_CACHE=""
}

# =============================================================================
# UI Functions: Filtering and Selection
# =============================================================================

# Interactive fuzzy filter
# Usage: echo -e "item1\nitem2" | ui_filter [OPTIONS]
#
# Options:
#   -p, --prompt PROMPT    Prompt/placeholder text
#   -h, --header HEADER    Header text above list
#   -m, --multi            Allow multiple selection
#   -q, --query QUERY      Initial query/filter text
#   -a, --ansi             Enable ANSI color processing
#   --height HEIGHT        Height (fzf only, default: 40%)
#   --reverse              Reverse layout (fzf only)
#
ui_filter() {
    local prompt="Select:" header="" multi="" height="40%" reverse="--reverse" query="" ansi=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--prompt)   prompt="$2"; shift 2 ;;
            -h|--header)   header="$2"; shift 2 ;;
            -m|--multi)    multi="1"; shift ;;
            -q|--query)    query="$2"; shift 2 ;;
            -a|--ansi)     ansi="1"; shift ;;
            --height)      height="$2"; shift 2 ;;
            --reverse)     reverse="--reverse"; shift ;;
            --no-reverse)  reverse=""; shift ;;
            *)             shift ;;
        esac
    done

    local backend
    backend=$(ui_get_backend)

    case "$backend" in
        gum)
            local gum_args=(filter)
            gum_args+=(--placeholder "$prompt")
            [[ -n "$header" ]] && gum_args+=(--header "$header")
            [[ -n "$multi" ]] && gum_args+=(--no-limit)
            [[ -n "$query" ]] && gum_args+=(--value "$query")
            gum "${gum_args[@]}"
            ;;
        fzf)
            local fzf_args=()
            fzf_args+=(--prompt "$prompt ")
            [[ -n "$header" ]] && fzf_args+=(--header "$header")
            [[ -n "$multi" ]] && fzf_args+=(-m)
            [[ -n "$query" ]] && fzf_args+=(--query "$query")
            [[ -n "$ansi" ]] && fzf_args+=(--ansi)
            [[ -n "$height" ]] && fzf_args+=(--height="$height")
            [[ -n "$reverse" ]] && fzf_args+=("$reverse")
            fzf "${fzf_args[@]}"
            ;;
        basic)
            _ui_basic_select "$prompt"
            ;;
    esac
}

# Simple choice selection (no fuzzy matching)
# Usage: ui_choose [OPTIONS] "opt1" "opt2" "opt3"
#
# Options:
#   -p, --prompt PROMPT    Prompt text
#   -h, --header HEADER    Header text
#
ui_choose() {
    local prompt="Select:" header=""
    local options=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--prompt) prompt="$2"; shift 2 ;;
            -h|--header) header="$2"; shift 2 ;;
            *)           options+=("$1"); shift ;;
        esac
    done

    [[ ${#options[@]} -eq 0 ]] && return 1

    local backend
    backend=$(ui_get_backend)

    case "$backend" in
        gum)
            local gum_args=(choose)
            [[ -n "$header" ]] && gum_args+=(--header "$header")
            gum "${gum_args[@]}" "${options[@]}"
            ;;
        fzf)
            local fzf_args=(--no-sort --height=40% --reverse)
            [[ -n "$header" ]] && fzf_args+=(--header "$header")
            fzf_args+=(--prompt "$prompt ")
            printf '%s\n' "${options[@]}" | fzf "${fzf_args[@]}"
            ;;
        basic)
            PS3="$prompt "
            select opt in "${options[@]}"; do
                [[ -n "$opt" ]] && { echo "$opt"; break; }
            done
            ;;
    esac
}

# =============================================================================
# UI Functions: Tables
# =============================================================================

# Interactive table selection
# Usage: ui_table [OPTIONS] < data.csv
#
# Options:
#   -c, --columns COLS     Column names (comma-separated)
#   -s, --separator SEP    Field separator (default: ,)
#   -h, --header           First line is header (fzf/basic)
#   -w, --widths WIDTHS    Column widths (gum only)
#
ui_table() {
    local columns="" separator="," has_header="" widths=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--columns)   columns="$2"; shift 2 ;;
            -s|--separator) separator="$2"; shift 2 ;;
            -h|--header)    has_header="1"; shift ;;
            -w|--widths)    widths="$2"; shift 2 ;;
            *)              shift ;;
        esac
    done

    local backend
    backend=$(ui_get_backend)

    case "$backend" in
        gum)
            local gum_args=(table)
            [[ -n "$columns" ]] && gum_args+=(--columns "$columns")
            [[ -n "$separator" ]] && gum_args+=(--separator "$separator")
            [[ -n "$widths" ]] && gum_args+=(--widths "$widths")
            gum "${gum_args[@]}"
            ;;
        fzf)
            local fzf_args=(--height=60% --reverse)
            [[ -n "$has_header" || -n "$columns" ]] && fzf_args+=(--header-lines=1)
            if [[ -n "$columns" && -z "$has_header" ]]; then
                # Add column header if provided but data doesn't have one
                { echo "$columns"; cat; } | fzf "${fzf_args[@]}"
            else
                fzf "${fzf_args[@]}"
            fi
            ;;
        basic)
            # Format with column and use basic select
            if [[ -n "$columns" ]]; then
                { echo "$columns"; cat; } | column -t -s"$separator" | _ui_basic_select "Select row:"
            else
                column -t -s"$separator" | _ui_basic_select "Select row:"
            fi
            ;;
    esac
}

# =============================================================================
# UI Functions: Input
# =============================================================================

# Text input prompt
# Usage: ui_input [OPTIONS]
#
# Options:
#   -p, --prompt PROMPT       Prompt text
#   -P, --placeholder TEXT    Placeholder text (gum only)
#   -v, --value DEFAULT       Default value
#   -w, --width WIDTH         Input width (gum only)
#   --password                Hide input (password mode)
#
ui_input() {
    local prompt="Input:" placeholder="" default="" width="" password=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--prompt)      prompt="$2"; shift 2 ;;
            -P|--placeholder) placeholder="$2"; shift 2 ;;
            -v|--value)       default="$2"; shift 2 ;;
            -w|--width)       width="$2"; shift 2 ;;
            --password)       password="1"; shift ;;
            *)                shift ;;
        esac
    done

    local backend
    backend=$(ui_get_backend)

    case "$backend" in
        gum)
            local gum_args=(input)
            gum_args+=(--prompt "$prompt ")
            [[ -n "$placeholder" ]] && gum_args+=(--placeholder "$placeholder")
            [[ -n "$default" ]] && gum_args+=(--value "$default")
            [[ -n "$width" ]] && gum_args+=(--width "$width")
            [[ -n "$password" ]] && gum_args+=(--password)
            gum "${gum_args[@]}"
            ;;
        *)
            if [[ -n "$password" ]]; then
                read -rsp "$prompt " response
                echo
                echo "$response"
            else
                read -rp "$prompt " -i "$default" response
                echo "$response"
            fi
            ;;
    esac
}

# Multi-line text input
# Usage: ui_write [OPTIONS]
#
# Options:
#   -p, --prompt PROMPT       Header/prompt text
#   -P, --placeholder TEXT    Placeholder text
#   -v, --value DEFAULT       Initial value
#   --width WIDTH             Editor width (gum only)
#   --height HEIGHT           Editor height (gum only)
#
ui_write() {
    local prompt="" placeholder="" default="" width="" height=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--prompt)      prompt="$2"; shift 2 ;;
            -P|--placeholder) placeholder="$2"; shift 2 ;;
            -v|--value)       default="$2"; shift 2 ;;
            --width)          width="$2"; shift 2 ;;
            --height)         height="$2"; shift 2 ;;
            *)                shift ;;
        esac
    done

    local backend
    backend=$(ui_get_backend)

    case "$backend" in
        gum)
            local gum_args=(write)
            [[ -n "$prompt" ]] && gum_args+=(--header "$prompt")
            [[ -n "$placeholder" ]] && gum_args+=(--placeholder "$placeholder")
            [[ -n "$default" ]] && gum_args+=(--value "$default")
            [[ -n "$width" ]] && gum_args+=(--width "$width")
            [[ -n "$height" ]] && gum_args+=(--height "$height")
            gum "${gum_args[@]}"
            ;;
        *)
            # Fallback to simple read loop
            [[ -n "$prompt" ]] && echo "$prompt"
            local lines=()
            local line
            while IFS= read -r line; do
                [[ -z "$line" ]] && break
                lines+=("$line")
            done
            printf '%s\n' "${lines[@]}"
            ;;
    esac
}

# =============================================================================
# UI Functions: Confirmation
# =============================================================================

# Yes/No confirmation
# Usage: ui_confirm [OPTIONS] "Are you sure?"
#
# Options:
#   --affirmative TEXT    Yes button text (gum only)
#   --negative TEXT       No button text (gum only)
#   --default             Default to yes
#
# Returns: 0 for yes, 1 for no
#
ui_confirm() {
    local prompt="Continue?" affirmative="" negative="" default_yes=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --affirmative) affirmative="$2"; shift 2 ;;
            --negative)    negative="$2"; shift 2 ;;
            --default)     default_yes="1"; shift ;;
            *)             prompt="$1"; shift ;;
        esac
    done

    local backend
    backend=$(ui_get_backend)

    case "$backend" in
        gum)
            local gum_args=(confirm "$prompt")
            [[ -n "$affirmative" ]] && gum_args+=(--affirmative "$affirmative")
            [[ -n "$negative" ]] && gum_args+=(--negative "$negative")
            [[ -n "$default_yes" ]] && gum_args+=(--default)
            gum "${gum_args[@]}"
            ;;
        *)
            local yn_prompt
            if [[ -n "$default_yes" ]]; then
                yn_prompt="$prompt [Y/n] "
            else
                yn_prompt="$prompt [y/N] "
            fi
            read -rp "$yn_prompt" response
            if [[ -n "$default_yes" ]]; then
                [[ ! "$response" =~ ^[Nn] ]]
            else
                [[ "$response" =~ ^[Yy] ]]
            fi
            ;;
    esac
}

# =============================================================================
# UI Functions: Progress and Feedback
# =============================================================================

# Spinner while running a command
# Usage: ui_spin [OPTIONS] -- COMMAND [ARGS...]
#
# Options:
#   -t, --title TEXT      Spinner title
#   -s, --spinner STYLE   Spinner style (gum only: dot, line, minidot, jump, etc.)
#
ui_spin() {
    local title="Loading..." spinner=""
    local cmd_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--title)   title="$2"; shift 2 ;;
            -s|--spinner) spinner="$2"; shift 2 ;;
            --)           shift; cmd_args=("$@"); break ;;
            *)            cmd_args+=("$1"); shift ;;
        esac
    done

    [[ ${#cmd_args[@]} -eq 0 ]] && return 1

    local backend
    backend=$(ui_get_backend)

    case "$backend" in
        gum)
            local gum_args=(spin --title "$title")
            [[ -n "$spinner" ]] && gum_args+=(--spinner "$spinner")
            gum_args+=(-- "${cmd_args[@]}")
            gum "${gum_args[@]}"
            ;;
        *)
            echo "$title"
            "${cmd_args[@]}"
            ;;
    esac
}

# =============================================================================
# UI Functions: Display
# =============================================================================

# Pager for long text
# Usage: ui_pager [OPTIONS] < long_text.txt
#
# Options:
#   --soft-wrap           Soft wrap lines
#   --use-gum             Force gum pager (slower startup)
#
# Note: Always uses less -R by default for fast startup.
#       gum pager has slow initialization (~1s) so it's opt-in.
#
ui_pager() {
    local soft_wrap="" use_gum=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --soft-wrap) soft_wrap="1"; shift ;;
            --use-gum)   use_gum="1"; shift ;;
            *)           shift ;;
        esac
    done

    # Use gum pager only if explicitly requested
    if [[ -n "$use_gum" ]] && has_cmd "gum"; then
        local gum_args=(pager)
        [[ -n "$soft_wrap" ]] && gum_args+=(--soft-wrap)
        gum "${gum_args[@]}"
        return
    fi

    # Default: use less -R (fast startup)
    if [[ -n "$soft_wrap" ]]; then
        less -RS
    else
        less -R
    fi
}

# Style text with formatting
# Usage: ui_style [OPTIONS] "TEXT"
#
# Options:
#   --bold                Bold text
#   --italic              Italic text
#   --underline           Underline text
#   --strikethrough       Strikethrough text
#   --foreground COLOR    Text color
#   --background COLOR    Background color
#   --border STYLE        Border style (none, hidden, normal, rounded, double, thick)
#   --padding PADDING     Padding (e.g., "1 2" for vertical horizontal)
#   --margin MARGIN       Margin (e.g., "1 2")
#   --align ALIGN         Text alignment (left, center, right)
#   --width WIDTH         Fixed width
#
ui_style() {
    local text=""
    local gum_args=(style)
    local has_gum_options=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --bold)          gum_args+=(--bold); has_gum_options="1"; shift ;;
            --italic)        gum_args+=(--italic); has_gum_options="1"; shift ;;
            --underline)     gum_args+=(--underline); has_gum_options="1"; shift ;;
            --strikethrough) gum_args+=(--strikethrough); has_gum_options="1"; shift ;;
            --foreground)    gum_args+=(--foreground "$2"); has_gum_options="1"; shift 2 ;;
            --background)    gum_args+=(--background "$2"); has_gum_options="1"; shift 2 ;;
            --border)        gum_args+=(--border "$2"); has_gum_options="1"; shift 2 ;;
            --padding)       gum_args+=(--padding "$2"); has_gum_options="1"; shift 2 ;;
            --margin)        gum_args+=(--margin "$2"); has_gum_options="1"; shift 2 ;;
            --align)         gum_args+=(--align "$2"); has_gum_options="1"; shift 2 ;;
            --width)         gum_args+=(--width "$2"); has_gum_options="1"; shift 2 ;;
            *)               text="$1"; shift ;;
        esac
    done

    [[ -z "$text" ]] && return 0

    local backend
    backend=$(ui_get_backend)

    case "$backend" in
        gum)
            if [[ -n "$has_gum_options" ]]; then
                gum "${gum_args[@]}" "$text"
            else
                echo "$text"
            fi
            ;;
        *)
            # Basic ANSI fallback - just echo the text
            # Could be extended to support basic ANSI codes
            echo "$text"
            ;;
    esac
}

# Format text (markdown, code, emoji)
# Usage: ui_format [OPTIONS] < input.txt
# Usage: echo "text" | ui_format [OPTIONS]
#
# Options:
#   -t, --type TYPE       Format type: markdown, template, code, emoji
#   -l, --language LANG   Code language (for code type)
#   --theme THEME         Theme name (gum only)
#
ui_format() {
    local format_type="markdown" language="" theme=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--type)     format_type="$2"; shift 2 ;;
            -l|--language) language="$2"; shift 2 ;;
            --theme)       theme="$2"; shift 2 ;;
            *)             shift ;;
        esac
    done

    local backend
    backend=$(ui_get_backend)

    case "$backend" in
        gum)
            local gum_args=(format --type "$format_type")
            [[ -n "$language" ]] && gum_args+=(--language "$language")
            [[ -n "$theme" ]] && gum_args+=(--theme "$theme")
            gum "${gum_args[@]}"
            ;;
        *)
            # Fallback: just cat the input
            cat
            ;;
    esac
}

# =============================================================================
# UI Functions: File Selection
# =============================================================================

# File picker
# Usage: ui_file [OPTIONS] [DIRECTORY]
#
# Options:
#   -a, --all             Show hidden files
#   -d, --directory       Only show directories
#   -f, --file            Only show files (gum only)
#   -h, --height HEIGHT   Picker height (gum only)
#
ui_file() {
    local show_all="" dir_only="" file_only="" height="" directory="."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)       show_all="1"; shift ;;
            -d|--directory) dir_only="1"; shift ;;
            -f|--file)      file_only="1"; shift ;;
            -h|--height)    height="$2"; shift 2 ;;
            *)              directory="$1"; shift ;;
        esac
    done

    local backend
    backend=$(ui_get_backend)

    case "$backend" in
        gum)
            local gum_args=(file "$directory")
            [[ -n "$show_all" ]] && gum_args+=(--all)
            [[ -n "$dir_only" ]] && gum_args+=(--directory)
            [[ -n "$file_only" ]] && gum_args+=(--file)
            [[ -n "$height" ]] && gum_args+=(--height "$height")
            gum "${gum_args[@]}"
            ;;
        fzf)
            local find_args=("$directory")
            if [[ -n "$dir_only" ]]; then
                find_args+=(-type d)
            elif [[ -n "$file_only" ]]; then
                find_args+=(-type f)
            fi
            [[ -z "$show_all" ]] && find_args+=(-not -path '*/.*')
            find "${find_args[@]}" 2>/dev/null | fzf --height=40% --reverse
            ;;
        basic)
            local ls_args=("-1")
            [[ -n "$show_all" ]] && ls_args+=("-a")
            if [[ -n "$dir_only" ]]; then
                find "$directory" -maxdepth 1 -type d -not -path '*/.*' 2>/dev/null | _ui_basic_select "Select directory:"
            else
                ls "${ls_args[@]}" "$directory" | _ui_basic_select "Select file:"
            fi
            ;;
    esac
}

# =============================================================================
# UI Functions: Toast Notifications (tmux display-message)
# =============================================================================

# Show a simple toast notification via tmux display-message
# Usage: ui_toast MESSAGE [LEVEL]
#   LEVEL: info (default), warning, error, success
ui_toast() {
    local message="${1:-}"
    local level="${2:-info}"
    [[ -z "$message" ]] && return 0

    # Get theme colors from loaded theme (via powerkit_bootstrap_minimal)
    # bg = base color, fg = base-darkest for contrast
    local bg_color fg_color icon

    case "$level" in
        warning)
            bg_color=$(get_color "warning-base")
            fg_color=$(get_color "warning-base-darkest")
            icon=$'\U0000F071'
            ;;
        error)
            bg_color=$(get_color "error-base")
            fg_color=$(get_color "error-base-darkest")
            icon=$'\U0000EA87'
            ;;
        success)
            bg_color=$(get_color "ok-base")
            fg_color=$(get_color "ok-base-darkest")
            icon=$'\U0000F058'
            ;;
        info)
            bg_color=$(get_color "info-base")
            fg_color=$(get_color "info-base-darkest")
            icon=$'\U0000F05A'
            ;;
        *)
            tmux display-message "$message"
            return 0
            ;;
    esac

    # If colors not available, fall back to plain message
    if [[ -z "$bg_color" || -z "$fg_color" ]]; then
        tmux display-message " ${icon} ${message}"
        return 0
    fi

    # Get terminal width and pad message to fill the entire status bar
    local term_width
    term_width=$(tmux display-message -p '#{client_width}' 2>/dev/null || echo 80)

    # Calculate padding needed (message + icon + spaces)
    local content=" ${icon} ${message} "
    local content_len=${#content}
    local padding_needed=$((term_width - content_len))

    # Create padding string
    local padding=""
    if (( padding_needed > 0 )); then
        padding=$(printf '%*s' "$padding_needed" '')
    fi

    local styled_message="#[bg=${bg_color},fg=${fg_color},bold]${content}${padding}#[default]"
    tmux display-message "$styled_message"
}

# Show a centered popup toast with a message
# Usage: ui_toast_popup MESSAGE [WIDTH] [HEIGHT]
ui_toast_popup() {
    local message="${1:-}"
    local width="${2:-50%}"
    local height="${3:-30%}"

    [[ -z "$message" ]] && return 0

    tmux display-popup -E -w "$width" -h "$height" \
        "printf '%s\n\nPress any key...' '$message'; read -rsn1"
}

# Display toast notification (convenience wrapper)
# Usage: toast "message" [STYLE] [LEVEL]
#   STYLE: simple (default), center, warning, error, success
#   LEVEL: info (default), warning, error, success
toast() {
    local message="${1:-}"
    local style="${2:-simple}"
    local level="${3:-info}"

    [[ -z "$message" ]] && return 0

    case "$style" in
        simple)
            ui_toast "$message" "$level"
            ;;
        center)
            ui_toast_popup "$message"
            ;;
        warning)
            # Shorthand: toast "msg" warning -> toast "msg" simple warning
            ui_toast "$message" "warning"
            ;;
        error)
            ui_toast "$message" "error"
            ;;
        success)
            ui_toast "$message" "success"
            ;;
        *)
            ui_toast "$message" "$level"
            ;;
    esac
}

# =============================================================================
# Internal Helper Functions
# =============================================================================

# Basic select fallback for systems without fzf/gum
# Usage: _ui_basic_select PROMPT < items
_ui_basic_select() {
    local prompt="${1:-Select:}"
    local items=()

    while IFS= read -r line; do
        [[ -n "$line" ]] && items+=("$line")
    done

    [[ ${#items[@]} -eq 0 ]] && return 1

    PS3="$prompt "
    select item in "${items[@]}"; do
        [[ -n "$item" ]] && { echo "$item"; break; }
    done
}

# =============================================================================
# Logging
# =============================================================================

log_debug "ui_backend" "UI backend module loaded (detected: $(ui_detect_backend))"
