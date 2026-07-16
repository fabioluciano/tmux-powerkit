#!/usr/bin/env bats
# =============================================================================
# BATS tests for productivity/financial plugins
# =============================================================================

load './helpers/test_helper.bash'

setup() {
    setup_test_root
}

# =============================================================================
# timezones
# =============================================================================

@test "timezones: contract functions" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/timezones.sh"
        _set_plugin_context timezones
        plugin_declare_options
        get_option() { case "$1" in zones) printf "UTC,America/New_York" ;; *) printf "" ;; esac; }
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=always"
    assert_output --regexp "st=(inactive|active|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "timezones: no zones → state=degraded, health=error" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/timezones.sh"
        _set_plugin_context timezones
        plugin_declare_options
        get_option() { case "$1" in zones) printf "" ;; *) printf "" ;; esac; }
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=degraded"
    assert_output --partial "health=error"
}

@test "timezones: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/timezones.sh"
        _set_plugin_context timezones
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=timezones"
}

# =============================================================================
# pomodoro
# =============================================================================

@test "pomodoro: contract functions (idle → inactive)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/pomodoro.sh"
        _set_plugin_context pomodoro
        plugin_declare_options
        cache_clear_all 2>/dev/null || true
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

@test "pomodoro: idle state → state=inactive, health=ok" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/pomodoro.sh"
        _set_plugin_context pomodoro
        plugin_declare_options
        cache_clear_all 2>/dev/null || true
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health) phase=$(plugin_data_get phase)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
    assert_output --partial "health=ok"
    assert_output --partial "phase=idle"
}

@test "pomodoro: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/pomodoro.sh"
        _set_plugin_context pomodoro
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=pomodoro"
}

# =============================================================================
# bitwarden
# =============================================================================

@test "bitwarden: contract functions" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/bw" <<'EOF'
#!/usr/bin/env bash
printf '{"status":"unlocked","email":"test@example.com"}'
EOF
    chmod +x "$mock_dir/bw"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bitwarden.sh"
        _set_plugin_context bitwarden
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

@test "bitwarden: unlocked → state=active, health=good" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/bw" <<'EOF'
#!/usr/bin/env bash
printf '{"status":"unlocked","email":"test@example.com"}'
EOF
    chmod +x "$mock_dir/bw"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bitwarden.sh"
        _set_plugin_context bitwarden
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health) status=$(plugin_data_get status)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=good"
    assert_output --partial "status=unlocked"
}

@test "bitwarden: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/bitwarden.sh"
        _set_plugin_context bitwarden
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=bitwarden"
}

# =============================================================================
# smartkey
# =============================================================================

@test "smartkey: contract functions (idle)" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/smartkey.sh"
        _set_plugin_context smartkey
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

@test "smartkey: idle → state=inactive, health=ok" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/smartkey.sh"
        _set_plugin_context smartkey
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health) waiting=$(plugin_data_get waiting)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
    assert_output --partial "health=ok"
    assert_output --partial "waiting=0"
}

@test "smartkey: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/smartkey.sh"
        _set_plugin_context smartkey
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=smartkey"
}

# =============================================================================
# appearance
# =============================================================================

@test "appearance: contract functions" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/appearance.sh"
        source "$1/src/utils/platform.sh"
        is_macos() { return 0; }
        get_macos_appearance_mode() { echo "dark"; }
        get_macos_appearance() { echo "1"; }
        _set_plugin_context appearance
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

@test "appearance: dark mode → health=good, context=dark" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/appearance.sh"
        source "$1/src/utils/platform.sh"
        is_macos() { return 0; }
        get_macos_appearance_mode() { echo "dark"; }
        get_macos_appearance() { echo "1"; }
        _set_plugin_context appearance
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) health=$(plugin_get_health) mode=$(plugin_data_get mode) context=$(plugin_get_context)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=good"
    assert_output --partial "mode=dark"
    assert_output --partial "context=dark"
}

@test "appearance: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/appearance.sh"
        _set_plugin_context appearance
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=appearance"
}

# =============================================================================
# crypto
# =============================================================================

@test "crypto: contract functions" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
printf "{}"
EOF
    chmod +x "$mock_dir/curl"
    cat >"$mock_dir/jq" <<'EOF'
#!/usr/bin/env bash
printf "null"
EOF
    chmod +x "$mock_dir/jq"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/crypto.sh"
        _set_plugin_context crypto
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

@test "crypto: no price data → state=inactive" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
printf "{}"
EOF
    chmod +x "$mock_dir/curl"
    cat >"$mock_dir/jq" <<'EOF'
#!/usr/bin/env bash
printf "null"
EOF
    chmod +x "$mock_dir/jq"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/crypto.sh"
        _set_plugin_context crypto
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) prices=$(plugin_data_get prices)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}

@test "crypto: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/crypto.sh"
        _set_plugin_context crypto
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=crypto"
}

# =============================================================================
# stocks
# =============================================================================

@test "stocks: contract functions" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/stocks.sh"
        _set_plugin_context stocks
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        ct=$(plugin_get_content_type) && ps=$(plugin_get_presence) && st=$(plugin_get_state) && hl=$(plugin_get_health) && ic=$(plugin_get_icon) && rd=$(plugin_render) && cx=$(plugin_get_context)
        echo "ct=${ct} ps=${ps} st=${st} hl=${hl} ic=${ic} rd=${rd} cx=${cx}"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "ct=dynamic"
    assert_output --partial "ps=always"
    assert_output --regexp "st=(inactive|active|degraded|failed)"
    assert_output --regexp "hl=(ok|good|info|warning|error)"
    refute_output --partial "rd=#["
}

@test "stocks: no price data → state=inactive" {
    mock_dir=$(create_mock_path)
    export PATH="$mock_dir:$PATH"
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$mock_dir/curl"

    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/stocks.sh"
        _set_plugin_context stocks
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) prices=$(plugin_data_get prices)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}

@test "stocks: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/stocks.sh"
        _set_plugin_context stocks
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=stocks"
}

# =============================================================================
# brightness
# =============================================================================

@test "brightness: contract functions" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/brightness.sh"
        source "$1/src/utils/platform.sh"
        is_macos() { return 1; }
        is_linux() { return 0; }
        has_cmd() { return 1; }
        _set_plugin_context brightness
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

@test "brightness: no brightness control → state=inactive" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/brightness.sh"
        source "$1/src/utils/platform.sh"
        is_macos() { return 1; }
        is_linux() { return 0; }
        has_cmd() { return 1; }
        _set_plugin_context brightness
        plugin_declare_options
        plugin_collect 2>/dev/null || true
        echo "state=$(plugin_get_state) level=$(plugin_data_get level)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=inactive"
}

@test "brightness: metadata exists" {
    run bash -c '
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/brightness.sh"
        _set_plugin_context brightness
        plugin_get_metadata
        echo "id=$(metadata_get id)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "id=brightness"
}
