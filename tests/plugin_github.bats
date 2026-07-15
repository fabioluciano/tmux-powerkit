#!/usr/bin/env bats
# =============================================================================
# BATS tests for github plugin
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# Contract Minimum
# =============================================================================

@test "contract: all required functions exist and return valid enums" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        _set_plugin_context github
        plugin_declare_options
        _is_authenticated() { return 1; }
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

@test "github: unauthenticated → state=failed, health=error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        _set_plugin_context github
        plugin_declare_options
        _is_authenticated() { return 1; }
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=failed"
    assert_output --partial "health=error"
}

@test "github: auth + repos + 0 issues → state=inactive, health=ok" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        _set_plugin_context github
        plugin_declare_options
        _is_authenticated() { return 0; }
        _has_repos_configured() { return 0; }
        _get_github_info() { echo "0 0 0"; return 0; }
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health) total=$(plugin_data_get total)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
    assert_output --partial "health=ok"
    assert_output --partial "total=0"
}

@test "github: auth + repos + 12 issues → state=active, health=warning" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        _set_plugin_context github
        plugin_declare_options
        _is_authenticated() { return 0; }
        _has_repos_configured() { return 0; }
        _get_github_info() { echo "12 0 0"; return 0; }
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health) total=$(plugin_data_get total)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=warning"
    assert_output --partial "total=12"
}

@test "github: auth + repos + 1 issue + 0 PRs → state=active, health=ok" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        _set_plugin_context github
        plugin_declare_options
        _is_authenticated() { return 0; }
        _has_repos_configured() { return 0; }
        _get_github_info() { echo "1 0 0"; return 0; }
        get_option() {
            case "$1" in
                warning_threshold_issues) printf "10" ;;
                warning_threshold_prs) printf "5" ;;
                *) printf "" ;;
            esac
        }
        plugin_collect
        echo "state=$(plugin_get_state) health=$(plugin_get_health) total=$(plugin_data_get total)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
    assert_output --partial "total=1"
}

@test "github: auth + no repos → state=degraded" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        _set_plugin_context github
        plugin_declare_options
        _is_authenticated() { return 0; }
        _has_repos_configured() { return 1; }
        plugin_collect
        echo "state=$(plugin_get_state)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=degraded"
}

@test "github: render does NOT contain tmux formatting" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        _set_plugin_context github
        plugin_declare_options
        _is_authenticated() { return 0; }
        _has_repos_configured() { return 0; }
        _get_github_info() { echo "5 2 0"; return 0; }
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial '#['
}

@test "github: plugin_get_icon returns non-empty string" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        _set_plugin_context github
        plugin_declare_options
        icon=$(plugin_get_icon)
        [[ -n "$icon" ]] && echo "icon_ok" || echo "icon_empty"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "icon_ok"
}

@test "github: plugin_get_metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/github.sh"
        _set_plugin_context github
        plugin_get_metadata
        id=$(metadata_get "id")
        echo "id=$id"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=github"
}
