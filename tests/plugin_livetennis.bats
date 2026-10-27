#!/usr/bin/env bats
load './helpers/test_helper.bash'

setup() {
    setup_test_root
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    export LIVETENNIS_API_KEY="local-fixture-secret"
    export LIVETENNIS_TEST_PLAYER=""
    export LIVETENNIS_TEST_PAYLOAD="$BATS_TEST_TMPDIR/result.json"
    export LIVETENNIS_TEST_ARGS="$BATS_TEST_TMPDIR/args"
    export LIVETENNIS_TEST_ENV="$BATS_TEST_TMPDIR/key-env"
    export LIVETENNIS_TEST_EXIT=0
    LIVETENNIS_TEST_REAL_PYTHON=$(command -v python3)
    export LIVETENNIS_TEST_REAL_PYTHON
    mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/python3" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" >"$LIVETENNIS_TEST_ARGS"
printf '%s' "${LIVETENNIS_API_KEY:-}" >"$LIVETENNIS_TEST_ENV"
cat "$LIVETENNIS_TEST_PAYLOAD"
exit "$LIVETENNIS_TEST_EXIT"
EOF
    chmod +x "$mock_dir/python3"
    printf '%s\n' '{"text":"Tennis 3 live (05:42 UTC)","state":"active","health":"ok","context":"live","count":3,"partial":false,"snapshot_at":1791610920,"last_attempt":1791610920,"stale":false,"configured":true}' >"$LIVETENNIS_TEST_PAYLOAD"
}

run_livetennis() {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/livetennis.sh"
        _set_plugin_context livetennis
        plugin_declare_options
        get_option() {
            case "$1" in
                player) printf "%s" "$LIVETENNIS_TEST_PLAYER" ;;
                icon) printf "T" ;;
                cache_ttl) printf "60" ;;
                *) printf "" ;;
            esac
        }
        eval "$2"
    ' _ "$POWERKIT_ROOT" "$1"
}

@test "livetennis metadata identifies the plugin" {
    run_livetennis 'plugin_get_metadata; printf "%s|%s" "$(metadata_get id)" "$(metadata_get name)"'
    assert_success
    assert_output --partial "livetennis|"
    refute_output "livetennis|"
}

@test "livetennis declares its player and cache options" {
    run_livetennis '
        declare_option() { printf "%s=%s:%s\n" "$1" "$2" "$3"; }
        plugin_declare_options
    '
    assert_success
    assert_output --partial "player=string:"
    assert_output --partial "cache_ttl=number:60"
    assert_output --partial "icon=icon:"
}

@test "livetennis dependencies include Python and jq" {
    run_livetennis '
        require_cmd() { printf "%s\n" "$1"; }
        plugin_check_dependencies
    '
    assert_success
    assert_output --partial "python3"
    assert_output --partial "jq"
}

@test "livetennis fails dependency checks when Python is missing" {
    run_livetennis '
        require_cmd() { [[ "$1" != python3 ]]; }
        plugin_check_dependencies
    '
    assert_failure
}

@test "livetennis fails dependency checks when jq is missing" {
    run_livetennis '
        require_cmd() { [[ "$1" != jq ]]; }
        plugin_check_dependencies
    '
    assert_failure
}

@test "livetennis stores the collected snapshot and contract values" {
    run_livetennis '
        plugin_collect || exit
        printf "%s|%s|%s|%s|%s|%s" "$(plugin_render)" \
            "$(plugin_get_state)" "$(plugin_get_health)" "$(plugin_get_context)" \
            "$(plugin_get_content_type)" "$(plugin_get_presence)"
    '
    assert_success
    assert_output "Tennis 3 live (05:42 UTC)|active|ok|live|dynamic|always"
}

@test "livetennis reports missing credentials as a visible failure" {
    unset LIVETENNIS_API_KEY
    printf '%s\n' '{"text":"Tennis key missing","state":"failed","health":"error","context":"missing-key","count":0,"partial":false,"snapshot_at":0,"last_attempt":0,"stale":false,"configured":false}' >"$LIVETENNIS_TEST_PAYLOAD"
    run_livetennis 'plugin_collect || exit; printf "%s|%s|%s" "$(plugin_render)" "$(plugin_get_state)" "$(plugin_get_health)"'
    assert_success
    assert_output "Tennis key missing|failed|error"
}

@test "livetennis keeps a successful empty snapshot visible" {
    printf '%s\n' '{"text":"Tennis 0 live (05:42 UTC)","state":"active","health":"ok","context":"empty","count":0,"partial":false,"snapshot_at":1791610920,"last_attempt":1791610920,"stale":false,"configured":true}' >"$LIVETENNIS_TEST_PAYLOAD"
    run_livetennis 'plugin_collect || exit; printf "%s|%s" "$(plugin_render)" "$(plugin_get_state)"'
    assert_success
    assert_output "Tennis 0 live (05:42 UTC)|active"
}

@test "livetennis displays partial and stale snapshots with warning health" {
    printf '%s\n' '{"text":"Tennis 3+ live (05:42 UTC, stale)","state":"degraded","health":"warning","context":"stale","count":3,"partial":true,"snapshot_at":1791610920,"last_attempt":1791611920,"stale":true,"configured":true}' >"$LIVETENNIS_TEST_PAYLOAD"
    run_livetennis 'plugin_collect || exit; printf "%s|%s|%s" "$(plugin_render)" "$(plugin_get_state)" "$(plugin_get_health)"'
    assert_success
    assert_output "Tennis 3+ live (05:42 UTC, stale)|degraded|warning"
}

@test "livetennis passes a player name as one argument" {
    export LIVETENNIS_TEST_PLAYER='-player with spaces; $(touch forbidden)'
    run_livetennis '
        plugin_collect || exit
        mapfile -d "" -t args <"$LIVETENNIS_TEST_ARGS"
        printf "%s|%s" "${#args[@]}" "${args[1]}"
    '
    assert_success
    assert_output '2|--player=-player with spaces; $(touch forbidden)'
    [ ! -e "$POWERKIT_ROOT/forbidden" ]
}

@test "livetennis keeps credentials out of helper command arguments" {
    run_livetennis '
        plugin_collect || exit
        mapfile -d "" -t args <"$LIVETENNIS_TEST_ARGS"
        for arg in "${args[@]}"; do
            [[ "$arg" != *"$LIVETENNIS_API_KEY"* ]] || exit 1
        done
        [[ $(cat "$LIVETENNIS_TEST_ENV") == "$LIVETENNIS_API_KEY" ]]
    '
    assert_success
    refute_output --partial "local-fixture-secret"
}

@test "livetennis render and metadata reads do not fetch another snapshot" {
    run_livetennis '
        plugin_collect || exit
        rm "$LIVETENNIS_TEST_ARGS"
        plugin_render
        plugin_get_state
        plugin_get_health
        plugin_get_context
        plugin_get_icon
        [[ ! -e "$LIVETENNIS_TEST_ARGS" ]]
    '
    assert_success
}

@test "livetennis uses its configured icon independently of health" {
    run_livetennis '
        plugin_get_health() { printf error; return 1; }
        plugin_get_icon
    '
    assert_success
    assert_output "T"
}

@test "livetennis renders plain text without tmux formatting" {
    run_livetennis 'plugin_collect || exit; plugin_render'
    assert_success
    assert_output "Tennis 3 live (05:42 UTC)"
    refute_output --partial '#['
}

@test "livetennis leaves collected data intact when the helper crashes" {
    run_livetennis '
        plugin_collect || exit
        export LIVETENNIS_TEST_EXIT=1
        plugin_collect && exit 1
        printf "%s|%s" "$(plugin_render)" "$(plugin_get_state)"
    '
    assert_success
    assert_output "Tennis 3 live (05:42 UTC)|active"
}

@test "livetennis rejects malformed JSON without replacing the snapshot" {
    run_livetennis '
        plugin_collect || exit
        printf "{broken\n" >"$LIVETENNIS_TEST_PAYLOAD"
        plugin_collect && exit 1
        printf "%s|%s" "$(plugin_render)" "$(plugin_get_state)"
    '
    assert_success
    assert_output "Tennis 3 live (05:42 UTC)|active"
}

@test "livetennis rejects incomplete JSON without replacing the snapshot" {
    run_livetennis '
        plugin_collect || exit
        printf "{}\n" >"$LIVETENNIS_TEST_PAYLOAD"
        plugin_collect && exit 1
        printf "%s|%s" "$(plugin_render)" "$(plugin_get_state)"
    '
    assert_success
    assert_output "Tennis 3 live (05:42 UTC)|active"
}

@test "livetennis rejects invalid state values" {
    printf '%s\n' '{"text":"Tennis invalid","state":"unknown","health":"ok","context":"live","count":0,"partial":false,"snapshot_at":0,"last_attempt":0,"stale":false,"configured":true}' >"$LIVETENNIS_TEST_PAYLOAD"
    run_livetennis 'plugin_collect'
    assert_failure
}

@test "livetennis rejects invalid health values" {
    printf '%s\n' '{"text":"Tennis invalid","state":"active","health":"unknown","context":"live","count":0,"partial":false,"snapshot_at":0,"last_attempt":0,"stale":false,"configured":true}' >"$LIVETENNIS_TEST_PAYLOAD"
    run_livetennis 'plugin_collect'
    assert_failure
}

@test "livetennis cache passes its Python regression suite" {
    cd "$POWERKIT_ROOT"
    run "$LIVETENNIS_TEST_REAL_PYTHON" -m unittest discover -s tests -p livetennis_cache_test.py -v
    assert_success
    assert_output --partial "OK"
}

@test "livetennis command reports a missing key through the real helper" {
    unset LIVETENNIS_API_KEY
    export PATH="${PATH#"$mock_dir:"}"
    run "$POWERKIT_ROOT/bin/powerkit-plugin" livetennis
    assert_success
    assert_output "Set LIVETENNIS_API_KEY"
    [ ! -e "$XDG_STATE_HOME/tmux-powerkit/livetennis/state.json" ]
}
