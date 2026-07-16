#!/usr/bin/env bats
load './helpers/test_helper.bash'

setup() {
    setup_test_root
    mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"
    export PATH="$mock_dir:$PATH"
}

@test "terraform active workspace displayed correctly" {
    cat >"$mock_dir/terraform" <<'TOOL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"workspace show"*) echo "default" ;;
    *) exit 1 ;;
esac
TOOL_EOF
    chmod +x "$mock_dir/terraform"

    local fake_dir="$BATS_TEST_TMPDIR/tfdir"
    mkdir -p "$fake_dir/.terraform"
    touch "$fake_dir/main.tf"

    cat >"$mock_dir/tmux" <<TMUX_EOF
#!/usr/bin/env bash
echo "${fake_dir}"
TMUX_EOF
    chmod +x "$mock_dir/tmux"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/terraform.sh"
        get_option() {
            case "$1" in
                tool) printf "auto" ;;
                show_pending) printf "true" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod,production,prd" ;;
                icon) printf "TF" ;;
                icon_pending) printf "TF*" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context terraform
        plugin_declare_options
        plugin_collect
        printf "state=%s workspace=%s health=%s pending=%s render=%s" \
            "$(plugin_get_state)" \
            "$(plugin_data_get workspace)" \
            "$(plugin_get_health)" \
            "$(plugin_data_get has_pending)" \
            "$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "workspace=default"
    assert_output --partial "health=ok"
    assert_output --partial "pending=0"
    assert_output --partial "render=default"
}

@test "terraform prod workspace triggers error health" {
    cat >"$mock_dir/terraform" <<'TOOL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"workspace show"*) echo "production" ;;
    *) exit 1 ;;
esac
TOOL_EOF
    chmod +x "$mock_dir/terraform"

    local fake_dir="$BATS_TEST_TMPDIR/tfdir"
    mkdir -p "$fake_dir/.terraform"
    touch "$fake_dir/main.tf"

    cat >"$mock_dir/tmux" <<TMUX_EOF
#!/usr/bin/env bash
echo "${fake_dir}"
TMUX_EOF
    chmod +x "$mock_dir/tmux"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/terraform.sh"
        get_option() {
            case "$1" in
                tool) printf "auto" ;;
                show_pending) printf "true" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod,production,prd" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context terraform
        plugin_declare_options
        plugin_collect
        printf "health=%s workspace=%s" \
            "$(plugin_get_health)" \
            "$(plugin_data_get workspace)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=error"
    assert_output --partial "workspace=production"
}

@test "terraform pending changes marks state=degraded" {
    cat >"$mock_dir/terraform" <<'TOOL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"workspace show"*) echo "staging" ;;
    *) exit 1 ;;
esac
TOOL_EOF
    chmod +x "$mock_dir/terraform"

    local fake_dir="$BATS_TEST_TMPDIR/tfdir"
    mkdir -p "$fake_dir/.terraform"
    touch "$fake_dir/main.tf"
    touch "$fake_dir/tfplan"

    cat >"$mock_dir/tmux" <<TMUX_EOF
#!/usr/bin/env bash
echo "${fake_dir}"
TMUX_EOF
    chmod +x "$mock_dir/tmux"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/terraform.sh"
        get_option() {
            case "$1" in
                tool) printf "auto" ;;
                show_pending) printf "true" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod,production,prd" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context terraform
        plugin_declare_options
        plugin_collect
        printf "state=%s health=%s pending=%s render=%s" \
            "$(plugin_get_state)" \
            "$(plugin_get_health)" \
            "$(plugin_data_get has_pending)" \
            "$(plugin_render)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=degraded"
    assert_output --partial "health=warning"
    assert_output --partial "pending=1"
    assert_output --partial "staging*"
}

@test "terraform not in tf directory leads to inactive" {
    local fake_dir="$BATS_TEST_TMPDIR/emptydir"
    mkdir -p "$fake_dir"

    cat >"$mock_dir/tmux" <<TMUX_EOF
#!/usr/bin/env bash
echo "${fake_dir}"
TMUX_EOF
    chmod +x "$mock_dir/tmux"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/terraform.sh"
        get_option() {
            case "$1" in
                tool) printf "auto" ;;
                show_pending) printf "true" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod,production,prd" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context terraform
        plugin_declare_options
        plugin_collect
        plugin_get_state
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "inactive"
}

@test "terraform plugin_should_be_active detects .tf files" {
    local tf_dir="$BATS_TEST_TMPDIR/tf_project"
    mkdir -p "$tf_dir"
    touch "$tf_dir/main.tf"

    cat >"$mock_dir/tmux" <<TMUX_EOF
#!/usr/bin/env bash
echo "${tf_dir}"
TMUX_EOF
    chmod +x "$mock_dir/tmux"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/terraform.sh"
        _set_plugin_context terraform
        plugin_should_be_active && echo "active" || echo "not_active"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "active"
}

@test "terraform tofu tool support" {
    cat >"$mock_dir/tofu" <<'TOOL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"workspace show"*) echo "dev" ;;
    *) exit 1 ;;
esac
TOOL_EOF
    chmod +x "$mock_dir/tofu"

    local fake_dir="$BATS_TEST_TMPDIR/tfdir2"
    mkdir -p "$fake_dir/.terraform"
    touch "$fake_dir/main.tf"

    cat >"$mock_dir/tmux" <<TMUX_EOF
#!/usr/bin/env bash
echo "${fake_dir}"
TMUX_EOF
    chmod +x "$mock_dir/tmux"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/terraform.sh"
        get_option() {
            case "$1" in
                tool) printf "tofu" ;;
                show_pending) printf "true" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod" ;;
                *) printf "" ;;
            esac
        }
        has_cmd() { [[ "$1" == "tofu" ]] && return 0; return 1; }
        _set_plugin_context terraform
        plugin_declare_options
        plugin_collect
        printf "workspace=%s tool=%s" \
            "$(plugin_data_get workspace)" \
            "$(plugin_data_get tool)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "workspace=dev"
    assert_output --partial "tool=tofu"
}

@test "terraform prod with pending shows production_pending context" {
    cat >"$mock_dir/terraform" <<'TOOL_EOF'
#!/usr/bin/env bash
case "$*" in
    *"workspace show"*) echo "production" ;;
    *) exit 1 ;;
esac
TOOL_EOF
    chmod +x "$mock_dir/terraform"

    local fake_dir="$BATS_TEST_TMPDIR/tfdir3"
    mkdir -p "$fake_dir/.terraform"
    touch "$fake_dir/main.tf"
    touch "$fake_dir/tfplan"

    cat >"$mock_dir/tmux" <<TMUX_EOF
#!/usr/bin/env bash
echo "${fake_dir}"
TMUX_EOF
    chmod +x "$mock_dir/tmux"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/terraform.sh"
        get_option() {
            case "$1" in
                tool) printf "auto" ;;
                show_pending) printf "true" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod,production,prd" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context terraform
        plugin_declare_options
        plugin_collect
        plugin_get_context
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "production_pending"
}

@test "terraform plugin has contract functions" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/terraform.sh"
        printf "content_type=%s presence=%s" \
            "$(plugin_get_content_type)" \
            "$(plugin_get_presence)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "content_type=dynamic"
    assert_output --partial "presence=conditional"
}
