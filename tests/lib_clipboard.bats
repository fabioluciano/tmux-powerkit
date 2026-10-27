#!/usr/bin/env bats

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

@test "clipboard: bootstrap restores the Bitwarden copy function" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        declare -F copy_to_clipboard
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "copy_to_clipboard"
}

@test "clipboard: system backends receive exact stdin without secret arguments" {
    run bash -c '
        source "$1/src/utils/clipboard.sh"
        for backend in pbcopy wl-copy xclip xsel; do
            _detect_clipboard_cmd() { printf "%s" "$backend"; }
            capture() {
                case "$backend" in
                    pbcopy|wl-copy) [[ $# == 0 ]] || return 1 ;;
                    xclip) [[ "$*" == "-selection clipboard" ]] || return 1 ;;
                    xsel) [[ "$*" == "--clipboard --input" ]] || return 1 ;;
                esac
                cat
            }
            pbcopy() { capture "$@"; }
            wl-copy() { capture "$@"; }
            xclip() { capture "$@"; }
            xsel() { capture "$@"; }
            input=$'"'"'fake secret\nsecond line\n'"'"'
            output=$(printf "%s" "$input" | copy_to_clipboard; printf .)
            [[ "$output" == "$input." ]] || exit 1
        done
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "clipboard: tmux fallback uses stdin and propagates failures" {
    run bash -c '
        source "$1/src/utils/clipboard.sh"
        _detect_clipboard_cmd() { :; }
        is_in_tmux() { return 0; }
        tmux() { [[ "$*" == "load-buffer -" ]] || return 1; cat; }
        [[ "$(copy_to_clipboard "fake secret")" == "fake secret" ]] || exit 1
        tmux() { return 42; }
        copy_to_clipboard "fake secret"
    ' _ "$POWERKIT_ROOT"
    assert_failure 42
}

@test "clipboard: missing backend fails without tmux" {
    run bash -c '
        source "$1/src/utils/clipboard.sh"
        _detect_clipboard_cmd() { :; }
        is_in_tmux() { return 1; }
        copy_to_clipboard "fake secret"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

@test "clipboard: explicit empty argument does not read stdin" {
    run bash -c '
        source "$1/src/utils/clipboard.sh"
        _detect_clipboard_cmd() { printf pbcopy; }
        pbcopy() { cat; }
        printf unexpected | copy_to_clipboard ""
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

@test "clipboard: Wayland is preferred over X11" {
    run bash -c '
        source "$1/src/utils/clipboard.sh"
        is_macos() { return 1; }
        has_cmd() { return 0; }
        WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 _detect_clipboard_cmd
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "wl-copy"
}

@test "clipboard: system backend failures are not reported as success" {
    run bash -c '
        source "$1/src/utils/clipboard.sh"
        _detect_clipboard_cmd() { printf pbcopy; }
        pbcopy() { return 42; }
        copy_to_clipboard "fake secret"
    ' _ "$POWERKIT_ROOT"
    assert_failure 42
}

@test "clipboard: paste backends use the matching clipboard selection" {
    run bash -c '
        source "$1/src/utils/clipboard.sh"
        for backend in pbpaste wl-paste xclip xsel tmux; do
            is_macos() { [[ "$backend" == pbpaste ]]; }
            is_in_tmux() { return 0; }
            has_cmd() { [[ "$1" == "$backend" ]]; }
            capture() {
                case "$backend" in
                    pbpaste) [[ $# == 0 ]] || return 1 ;;
                    wl-paste) [[ "$*" == "--no-newline" ]] || return 1 ;;
                    xclip) [[ "$*" == "-selection clipboard -o" ]] || return 1 ;;
                    xsel) [[ "$*" == "--clipboard --output" ]] || return 1 ;;
                    tmux) [[ "$*" == "save-buffer -" ]] || return 1 ;;
                esac
                printf "fake clipboard"
            }
            pbpaste() { capture "$@"; }
            wl-paste() { capture "$@"; }
            xclip() { capture "$@"; }
            xsel() { capture "$@"; }
            tmux() { capture "$@"; }
            [[ "$(WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 paste_from_clipboard)" == "fake clipboard" ]] || exit 1
        done
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "clipboard: availability and detection respect display and installed commands" {
    run bash -c '
        source "$1/src/utils/clipboard.sh"
        is_macos() { return 1; }
        is_in_tmux() { return 1; }
        has_cmd() { [[ "$1" == xsel ]]; }
        [[ "$(WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 _detect_clipboard_cmd)" == xsel ]] || exit 1
        WAYLAND_DISPLAY= DISPLAY= clipboard_available && exit 1
        is_in_tmux() { return 0; }
        WAYLAND_DISPLAY= DISPLAY= clipboard_available
    ' _ "$POWERKIT_ROOT"
    assert_success
}
