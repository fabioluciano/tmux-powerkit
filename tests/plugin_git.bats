#!/usr/bin/env bats
# =============================================================================
# BATS tests for git plugin
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Contract Minimum
# =============================================================================

@test "contract: all required functions exist and return valid enums" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *pane_current_path*) echo "/tmp" ;;
    *) echo "unknown tmux call: $*" >&2 ;;
esac
EOF
    chmod +x "$mock_dir/tmux"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
case "$3" in
        rev-parse) echo "true" ;;
    status)
        echo "## main"
        ;;
    *) echo "ok" ;;
esac
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/git.sh"
        _set_plugin_context git
        plugin_declare_options
        plugin_collect
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(active|inactive|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#"
}

# =============================================================================
# Behavioral Tests
# =============================================================================

@test "git: clean repo → health=ok" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *pane_current_path*) echo "/tmp" ;;
esac
EOF
    chmod +x "$mock_dir/tmux"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
case "$3" in
        rev-parse) echo "true" ;;
    status)
        echo "## main"
        ;;
    *) echo "ok" ;;
esac
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/git.sh"
        _set_plugin_context git
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health) render=$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
    assert_output --partial "render=main"
}

@test "git: modified files → health=info" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *pane_current_path*) echo "/tmp" ;;
esac
EOF
    chmod +x "$mock_dir/tmux"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
case "$3" in
        rev-parse) echo "true" ;;
    status)
        echo "## main"
        echo " M file1.txt"
        echo "?? untracked.txt"
        ;;
    *) echo "ok" ;;
esac
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/git.sh"
        _set_plugin_context git
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=info"
}

@test "git: unpushed commits → health=warning" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *pane_current_path*) echo "/tmp" ;;
esac
EOF
    chmod +x "$mock_dir/tmux"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
case "$3" in
        rev-parse) echo "true" ;;
    status)
        echo "## main...origin/main [ahead 3]"
        ;;
    config)
        case "$4" in
            branch.main.remote) echo "origin" ;;
            branch.main.merge) echo "refs/heads/main" ;;
        esac
        ;;
    rev-parse) echo "" ;;  # origin/main doesn't exist (fallback config)
    rev-list) echo "3" ;;
    *) echo "ok" ;;
esac
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/git.sh"
        _set_plugin_context git
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=warning"
}

@test "git: merge conflicts → health=error" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *pane_current_path*) echo "/tmp" ;;
esac
EOF
    chmod +x "$mock_dir/tmux"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
case "$3" in
        rev-parse) echo "true" ;;
    status)
        echo "## main"
        echo "UU conflicted.txt"
        ;;
    *) echo "ok" ;;
esac
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/git.sh"
        _set_plugin_context git
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=error"
}

@test "git: plugin_should_be_active returns 0 inside git repo" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *pane_current_path*) echo "/tmp" ;;
esac
EOF
    chmod +x "$mock_dir/tmux"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
case "$3" in
        rev-parse) echo "true" ;;
    *) echo "ok" ;;
esac
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/git.sh"
        _set_plugin_context git
        plugin_should_be_active && echo "active" || echo "inactive"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "active"
}

@test "git: plugin_should_be_active returns 1 outside git repo" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *pane_current_path*) echo "/tmp" ;;
esac
EOF
    chmod +x "$mock_dir/tmux"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
case "$3" in
        rev-parse)
        echo "fatal: not a git repository" >&2
        exit 128
        ;;
    *) echo "ok" ;;
esac
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/git.sh"
        _set_plugin_context git
        plugin_should_be_active && echo "active" || echo "inactive"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "inactive"
}

@test "git: render does NOT contain tmux formatting" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *pane_current_path*) echo "/tmp" ;;
esac
EOF
    chmod +x "$mock_dir/tmux"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
case "$3" in
        rev-parse) echo "true" ;;
    status)
        echo "## main"
        echo " M file.txt"
        ;;
    *) echo "ok" ;;
esac
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/git.sh"
        _set_plugin_context git
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "git: plugin_get_metadata exists" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/tmux" <<'EOF'
#!/usr/bin/env bash
echo "/tmp"
EOF
    chmod +x "$mock_dir/tmux"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
echo "true"
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/git.sh"
        _set_plugin_context git
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=git"
}

@test "git: state=inactive when not in a git repo" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *pane_current_path*) echo "/tmp" ;;
esac
EOF
    chmod +x "$mock_dir/tmux"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
case "$3" in
        rev-parse)
        echo "fatal: not a git repository" >&2
        exit 128
        ;;
    *) echo "ok" ;;
esac
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/git.sh"
        _set_plugin_context git
        plugin_declare_options
        plugin_collect
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}
