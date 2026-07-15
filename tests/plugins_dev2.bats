#!/usr/bin/env bats
# =============================================================================
# BATS tests for dev/API plugins (group 2)
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# gitlab
# =============================================================================

@test "gitlab: contract functions" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/gitlab.sh"
        _set_plugin_context gitlab
        plugin_declare_options
        get_option() { case "$1" in token) printf "test-token" ;; repos) printf "owner/repo" ;; *) printf "" ;; esac; }
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(inactive|active|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "gitlab: unauthenticated → state=failed, health=error" {
    # Clear env vars and override has_cmd for glab to ensure non-auth path
    run bash -c '
        unset GITLAB_TOKEN GITLAB_PRIVATE_TOKEN
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/gitlab.sh"
        _set_plugin_context gitlab
        plugin_declare_options
        get_option() { case "$1" in token) printf "" ;; repos) printf "" ;; *) printf "" ;; esac; }
        has_cmd() { [[ "$1" == "glab" ]] && return 1; command -v "$1" &>/dev/null; }
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=failed"
    assert_output --partial "health=error"
}

@test "gitlab: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/gitlab.sh"
        _set_plugin_context gitlab
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=gitlab"
}

# =============================================================================
# bitbucket
# =============================================================================

@test "bitbucket: contract functions" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bitbucket.sh"
        _set_plugin_context bitbucket
        plugin_declare_options
        get_option() { case "$1" in email) printf "test@example.com" ;; token) printf "test-token" ;; repos) printf "workspace/repo" ;; *) printf "" ;; esac; }
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(inactive|active|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "bitbucket: not configured → state=failed, health=error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bitbucket.sh"
        _set_plugin_context bitbucket
        plugin_declare_options
        get_option() { case "$1" in email) printf "" ;; token) printf "" ;; repos) printf "" ;; *) printf "" ;; esac; }
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=failed"
    assert_output --partial "health=error"
}

@test "bitbucket: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bitbucket.sh"
        _set_plugin_context bitbucket
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=bitbucket"
}

# =============================================================================
# jira
# =============================================================================

@test "jira: contract functions" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$mock_dir/curl"
    cat >"$mock_dir/jq" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$mock_dir/jq"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/jira.sh"
        _set_plugin_context jira
        plugin_declare_options
        get_option() { case "$1" in domain) printf "test.atlassian.net" ;; email) printf "test@example.com" ;; token) printf "test-token" ;; *) printf "" ;; esac; }
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(inactive|active|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "jira: not configured → state=failed, health=error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/jira.sh"
        _set_plugin_context jira
        plugin_declare_options
        get_option() { case "$1" in domain) printf "" ;; email) printf "" ;; token) printf "" ;; *) printf "" ;; esac; }
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=failed"
    assert_output --partial "health=error"
}

@test "jira: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/jira.sh"
        _set_plugin_context jira
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=jira"
}

# =============================================================================
# cloud
# =============================================================================

@test "cloud: contract functions (no provider → inactive)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cloud.sh"
        _set_plugin_context cloud
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(inactive|active|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "cloud: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cloud.sh"
        _set_plugin_context cloud
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=cloud"
}

# =============================================================================
# cloudstatus
# =============================================================================

@test "cloudstatus: contract functions" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
printf '{"status":{"indicator":"none","description":"All Systems Operational"}}'
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cloudstatus.sh"
        _set_plugin_context cloudstatus
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(inactive|active|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "cloudstatus: all operational → state=inactive" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    # Return per-provider response format so each parser gets valid data
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *status.cloud.google.com*)
        printf '[]'
        ;;
    *health.aws.amazon.com*)
        printf '<html>All services are operating normally</html>'
        ;;
    *status.azure.com*)
        printf '{"status":{"health":"good"}}'
        ;;
    *)
        printf '{"status":{"indicator":"none","description":"All Systems Operational"}}'
        ;;
esac
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cloudstatus.sh"
        _set_plugin_context cloudstatus
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
    assert_output --partial "health=ok"
}

@test "cloudstatus: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/cloudstatus.sh"
        _set_plugin_context cloudstatus
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=cloudstatus"
}

# =============================================================================
# yadm
# =============================================================================

@test "yadm: contract functions" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/yadm" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "rev-parse" ]]; then
    echo "true"
    exit 0
fi
echo "## main...origin/main"
EOF
    chmod +x "$mock_dir/yadm"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/yadm.sh"
        _set_plugin_context yadm
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(inactive|active|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "yadm: active with branch → state=active" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/yadm" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "rev-parse" ]]; then
    echo "true"
    exit 0
fi
echo "## main...origin/main"
EOF
    chmod +x "$mock_dir/yadm"
    cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$mock_dir/git"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/yadm.sh"
        _set_plugin_context yadm
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) branch=$(plugin_data_get branch)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "branch=main"
}

@test "yadm: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/yadm.sh"
        _set_plugin_context yadm
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=yadm"
}

# =============================================================================
# chezmoi
# =============================================================================

@test "chezmoi: contract functions" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    mkdir -p "$mock_dir/../chezmoi-source"
    cat >"$mock_dir/chezmoi" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "source-path" ]]; then
    dir="$(dirname "$(dirname "$(which chezmoi 2>/dev/null)")")"
    echo "$dir/../chezmoi-source"
    exit 0
fi
printf ""
EOF
    chmod +x "$mock_dir/chezmoi"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/chezmoi.sh"
        _set_plugin_context chezmoi
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(inactive|active|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "chezmoi: no source dir → state=inactive" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/chezmoi" <<'EOF'
#!/usr/bin/env bash
echo "/nonexistent/path"
exit 0
EOF
    chmod +x "$mock_dir/chezmoi"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/chezmoi.sh"
        _set_plugin_context chezmoi
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) available=$(plugin_data_get available)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}

@test "chezmoi: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/chezmoi.sh"
        _set_plugin_context chezmoi
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=chezmoi"
}

# =============================================================================
# packages
# =============================================================================

@test "packages: contract functions (no backend → zero updates)" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/packages.sh"
        _set_plugin_context packages
        plugin_declare_options
        has_cmd() { return 1; }
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=conditional"
    assert_output --regexp "st=(inactive|active|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "packages: no backend → state=inactive" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/packages.sh"
        _set_plugin_context packages
        plugin_declare_options
        has_cmd() { return 1; }
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) count=$(plugin_data_get update_count)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
    assert_output --partial "count=0"
}

@test "packages: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/packages.sh"
        _set_plugin_context packages
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=packages"
}
