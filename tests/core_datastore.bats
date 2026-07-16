#!/usr/bin/env bats
# =============================================================================
# Tests: core/datastore.sh
# Description: Tests for the PowerKit plugin-scoped data storage API
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
}

# ---------------------------------------------------------------------------
# plugin_data_set / plugin_data_get
# ---------------------------------------------------------------------------

@test "plugin_data_set and plugin_data_get store and retrieve a value" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplugin"
        plugin_data_set "mykey" "myvalue"
        plugin_data_get "mykey"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "myvalue"
}

@test "plugin_data_get returns empty string for nonexistent key" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplugin"
        plugin_data_get "nope"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output ""
}

@test "plugin_data_set overwrites existing key" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplugin"
        plugin_data_set "key" "original"
        plugin_data_set "key" "updated"
        plugin_data_get "key"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "updated"
}

@test "multiple keys work independently in same plugin context" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplugin"
        plugin_data_set "a" "alpha"
        plugin_data_set "b" "beta"
        printf "%s-%s" "$(plugin_data_get "a")" "$(plugin_data_get "b")"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "alpha-beta"
}

# ---------------------------------------------------------------------------
# plugin_data_has
# ---------------------------------------------------------------------------

@test "plugin_data_has returns 0 when key exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplugin"
        plugin_data_set "exists" "yes"
        plugin_data_has "exists"
    ' _ "$POWERKIT_ROOT"
    assert_success
}

@test "plugin_data_has returns 1 when key does not exist" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplugin"
        plugin_data_has "nonexistent"
    ' _ "$POWERKIT_ROOT"
    assert_failure
}

# ---------------------------------------------------------------------------
# plugin_data_clear
# ---------------------------------------------------------------------------

@test "plugin_data_clear removes all data for current plugin" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplugin"
        plugin_data_set "k1" "v1"
        plugin_data_set "k2" "v2"
        plugin_data_clear
        plugin_data_has "k1" && echo "has_k1" || echo "no_k1"
        plugin_data_has "k2" && echo "has_k2" || echo "no_k2"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output - <<'EOF'
no_k1
no_k2
EOF
}

# ---------------------------------------------------------------------------
# Data isolation between plugin contexts
# ---------------------------------------------------------------------------

@test "data isolation: two plugin contexts don't see each other's data" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "alpha"
        plugin_data_set "shared" "alpha-value"

        _set_plugin_context "beta"
        plugin_data_set "shared" "beta-value"

        # Switch back to alpha and read
        _set_plugin_context "alpha"
        plugin_data_get "shared"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "alpha-value"
}

@test "clearing one plugin does not affect another" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "alpha"
        plugin_data_set "key" "alpha-val"

        _set_plugin_context "beta"
        plugin_data_set "key" "beta-val"

        # Clear beta
        plugin_data_clear

        # Alpha should still have its data
        _set_plugin_context "alpha"
        plugin_data_get "key"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "alpha-val"
}

# ---------------------------------------------------------------------------
# Metadata API
# ---------------------------------------------------------------------------

@test "metadata_set and metadata_get store and retrieve values" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "testplugin"
        metadata_set "id" "my_plugin"
        metadata_set "name" "My Plugin"
        printf "%s:%s" "$(metadata_get "id")" "$(metadata_get "name")"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "my_plugin:My Plugin"
}

@test "metadata is isolated per plugin context" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "p1"
        metadata_set "desc" "plugin one"

        _set_plugin_context "p2"
        metadata_set "desc" "plugin two"

        _set_plugin_context "p1"
        metadata_get "desc"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "plugin one"
}

# ---------------------------------------------------------------------------
# Cross-plugin access (core internal API)
# ---------------------------------------------------------------------------

@test "_datastore_get reads data from any plugin's scope" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "someservice"
        plugin_data_set "token" "abc123"

        # Read cross-plugin without switching context
        _datastore_get "someservice" "token"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "abc123"
}

@test "_datastore_set writes data to any plugin's scope" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "current"
        _datastore_set "other" "val" "cross-data"

        # Switch context and verify
        _set_plugin_context "other"
        plugin_data_get "val"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "cross-data"
}

@test "_datastore_has checks key existence cross-plugin" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "svc"
        plugin_data_set "key" "x"

        _datastore_has "svc" "key" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "yes"
}

@test "_datastore_has returns 1 for nonexistent cross-plugin key" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _datastore_has "ghost" "nope" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "no"
}

# ---------------------------------------------------------------------------
# _datastore_clear_all
# ---------------------------------------------------------------------------

@test "_datastore_clear_all removes all plugin data" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "a"
        plugin_data_set "x" "1"

        _set_plugin_context "b"
        plugin_data_set "y" "2"

        _datastore_clear_all

        _set_plugin_context "a"
        plugin_data_has "x" && echo "has" || echo "gone"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "gone"
}

# ---------------------------------------------------------------------------
# plugin_data_set/get without context
# ---------------------------------------------------------------------------

@test "plugin_data_set without context returns error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        plugin_data_set "k" "v" 2>/dev/null && echo "ok" || echo "fail"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "fail"
}

@test "plugin_data_get without context returns error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        plugin_data_get "k" 2>/dev/null && echo "ok" || echo "fail"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "fail"
}

@test "plugin_data_has without context returns 1" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        plugin_data_has "k" && echo "yes" || echo "no"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "no"
}

# ---------------------------------------------------------------------------
# Edge: values with special characters
# ---------------------------------------------------------------------------

@test "plugin_data stores values with spaces and special chars" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        _set_plugin_context "t"
        plugin_data_set "msg" "hello world with spaces"
        plugin_data_get "msg"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "hello world with spaces"
}
