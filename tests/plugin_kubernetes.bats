#!/usr/bin/env bats
load './helpers/test_helper.bash'

setup() {
    setup_test_root
    mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"
    export PATH="$mock_dir:$PATH"
}

@test "kubernetes context is parsed correctly" {
    cat >"$mock_dir/kubectl" <<'KUBE_EOF'
#!/usr/bin/env bash
case "$*" in
    *"cluster-info"*) exit 0 ;;
    *"config current-context"*) echo "my-cluster" ;;
    *"config view"*) echo "default" ;;
esac
KUBE_EOF
    chmod +x "$mock_dir/kubectl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/kubernetes.sh"
        get_option() {
            case "$1" in
                display_mode) printf "always" ;;
                show_context) printf "true" ;;
                show_namespace) printf "true" ;;
                separator) printf "/" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod,production,prd" ;;
                connectivity_cache_ttl) printf "120" ;;
                connectivity_timeout) printf "2" ;;
                icon) printf "K8S" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context kubernetes
        plugin_declare_options
        plugin_collect
        printf "state=%s context=%s namespace=%s health=%s" \
            "$(plugin_get_state)" \
            "$(plugin_data_get context)" \
            "$(plugin_data_get namespace)" \
            "$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "context=my-cluster"
    assert_output --partial "namespace=default"
    assert_output --partial "health=ok"
}

@test "kubernetes production keyword triggers error health" {
    cat >"$mock_dir/kubectl" <<'KUBE_EOF'
#!/usr/bin/env bash
case "$*" in
    *"cluster-info"*) exit 0 ;;
    *"config current-context"*) echo "prod-us-east-1" ;;
    *"config view"*) echo "kube-system" ;;
esac
KUBE_EOF
    chmod +x "$mock_dir/kubectl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/kubernetes.sh"
        get_option() {
            case "$1" in
                display_mode) printf "always" ;;
                show_context) printf "true" ;;
                show_namespace) printf "true" ;;
                separator) printf "/" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod,production,prd" ;;
                connectivity_cache_ttl) printf "120" ;;
                connectivity_timeout) printf "2" ;;
                icon) printf "K8S" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context kubernetes
        plugin_declare_options
        plugin_collect
        printf "health=%s context=%s" \
            "$(plugin_get_health)" \
            "$(plugin_data_get context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "health=error"
    assert_output --partial "context=prod-us-east-1"
}

@test "kubernetes no kubectl and no kubeconfig leads to inactive" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        HOME=/nonexistent; export HOME
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/kubernetes.sh"
        _set_plugin_context kubernetes
        plugin_declare_options
        plugin_collect
        plugin_get_state
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "inactive"
}

@test "kubernetes render shows context and namespace" {
    cat >"$mock_dir/kubectl" <<'KUBE_EOF'
#!/usr/bin/env bash
case "$*" in
    *"cluster-info"*) exit 0 ;;
    *"config current-context"*) echo "dev-cluster" ;;
    *"config view"*) echo "development" ;;
esac
KUBE_EOF
    chmod +x "$mock_dir/kubectl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/kubernetes.sh"
        get_option() {
            case "$1" in
                display_mode) printf "always" ;;
                show_context) printf "true" ;;
                show_namespace) printf "true" ;;
                separator) printf "/" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod,production,prd" ;;
                connectivity_cache_ttl) printf "120" ;;
                connectivity_timeout) printf "2" ;;
                icon) printf "K8S" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context kubernetes
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "dev-cluster/development"
}

@test "kubernetes GKE context is shortened in render" {
    cat >"$mock_dir/kubectl" <<'KUBE_EOF'
#!/usr/bin/env bash
case "$*" in
    *"cluster-info"*) exit 0 ;;
    *"config current-context"*) echo "admin@gke_my-project_us-central1_cluster-1" ;;
    *"config view"*) echo "default" ;;
esac
KUBE_EOF
    chmod +x "$mock_dir/kubectl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/kubernetes.sh"
        get_option() {
            case "$1" in
                display_mode) printf "always" ;;
                show_context) printf "true" ;;
                show_namespace) printf "true" ;;
                separator) printf "/" ;;
                warn_on_prod) printf "false" ;;
                prod_keywords) printf "" ;;
                connectivity_cache_ttl) printf "120" ;;
                connectivity_timeout) printf "2" ;;
                icon) printf "K8S" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context kubernetes
        plugin_declare_options
        plugin_collect
        plugin_render
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial "admin@"
}

@test "kubernetes staging context returns staging context type" {
    cat >"$mock_dir/kubectl" <<'KUBE_EOF'
#!/usr/bin/env bash
case "$*" in
    *"cluster-info"*) exit 0 ;;
    *"config current-context"*) echo "staging-eu-west" ;;
    *"config view"*) echo "default" ;;
esac
KUBE_EOF
    chmod +x "$mock_dir/kubectl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/kubernetes.sh"
        get_option() {
            case "$1" in
                display_mode) printf "always" ;;
                show_context) printf "true" ;;
                show_namespace) printf "true" ;;
                separator) printf "/" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod,production,prd" ;;
                connectivity_cache_ttl) printf "120" ;;
                connectivity_timeout) printf "2" ;;
                icon) printf "K8S" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context kubernetes
        plugin_declare_options
        plugin_collect
        plugin_get_context
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "staging"
}

@test "kubernetes minikube context returns local context type" {
    cat >"$mock_dir/kubectl" <<'KUBE_EOF'
#!/usr/bin/env bash
case "$*" in
    *"cluster-info"*) exit 0 ;;
    *"config current-context"*) echo "minikube" ;;
    *"config view"*) echo "default" ;;
esac
KUBE_EOF
    chmod +x "$mock_dir/kubectl"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/kubernetes.sh"
        get_option() {
            case "$1" in
                display_mode) printf "always" ;;
                show_context) printf "true" ;;
                show_namespace) printf "true" ;;
                separator) printf "/" ;;
                warn_on_prod) printf "true" ;;
                prod_keywords) printf "prod,production,prd" ;;
                connectivity_cache_ttl) printf "120" ;;
                connectivity_timeout) printf "2" ;;
                icon) printf "K8S" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context kubernetes
        plugin_declare_options
        plugin_collect
        plugin_get_context
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "local"
}

@test "kubernetes plugin has required contract functions" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/kubernetes.sh"
        printf "content_type=%s presence=%s" \
            "$(plugin_get_content_type)" \
            "$(plugin_get_presence)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "content_type=dynamic"
    assert_output --partial "presence=conditional"
}
