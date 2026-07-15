#!/usr/bin/env bats
load './helpers/test_helper.bash'

setup() {
    setup_test_root
    mock_dir="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_dir"
    export PATH="$mock_dir:$PATH"
}

mock_curl_for_weather() {
    cat >"$mock_dir/curl" <<'CURL_EOF'
#!/usr/bin/env bash
case "$*" in
    *geocoding*)
        echo '{"results":[{"id":1,"name":"Sao Paulo","latitude":-23.5505,"longitude":-46.6333,"country":"Brazil","country_code":"BR"}]}'
        ;;
    *forecast*)
        echo '{"latitude":-23.55,"longitude":-46.63,"current":{"time":"2025-01-01T12:00","temperature_2m":25.5,"relative_humidity_2m":65,"apparent_temperature":27.0,"precipitation":0.0,"weather_code":0,"cloud_cover":10,"wind_speed_10m":12.3,"wind_direction_10m":180,"is_day":1},"current_units":{"temperature_2m":"°C","wind_speed_10m":"km/h"}}'
        ;;
    *)
        echo '{"error":true,"reason":"Unknown endpoint"}'
        ;;
esac
CURL_EOF
    chmod +x "$mock_dir/curl"

    cat >"$mock_dir/date" <<'DATE_EOF'
#!/usr/bin/env bash
echo "2025010112"
DATE_EOF
    chmod +x "$mock_dir/date"
}

@test "weather compact format shows temperature" {
    mock_curl_for_weather

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/weather.sh"
        get_option() {
            case "$1" in
                location) printf "" ;;
                units) printf "m" ;;
                format) printf "compact" ;;
                language) printf "" ;;
                hide_plus_sign) printf "true" ;;
                icon_mode) printf "static" ;;
                icon) printf "W" ;;
                max_requests_per_hour) printf "1000" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context weather
        plugin_collect
        printf "state=%s weather=%s health=%s" \
            "$(plugin_get_state)" \
            "$(plugin_data_get weather)" \
            "$(plugin_get_health)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "health=ok"
    assert_output --partial "25.5°C"
}

@test "weather API failure leads to inactive state" {
    cat >"$mock_dir/curl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$mock_dir/curl"

    cat >"$mock_dir/date" <<'EOF'
#!/usr/bin/env bash
echo "2025010112"
EOF
    chmod +x "$mock_dir/date"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/weather.sh"
        get_option() {
            case "$1" in
                location) printf "" ;;
                units) printf "m" ;;
                format) printf "compact" ;;
                language) printf "" ;;
                hide_plus_sign) printf "true" ;;
                icon_mode) printf "static" ;;
                icon) printf "W" ;;
                max_requests_per_hour) printf "1000" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context weather
        plugin_collect
        plugin_get_state
    ' _ "$POWERKIT_ROOT"
    refute_output "active"
}

@test "weather reports unavailable context when no data" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/weather.sh"
        _set_plugin_context weather
        plugin_get_context
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "unavailable"
}

@test "weather dynamic icon mode stores symbol from WMO code" {
    mock_curl_for_weather

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/weather.sh"
        get_option() {
            case "$1" in
                location) printf "" ;;
                units) printf "m" ;;
                format) printf "compact" ;;
                language) printf "" ;;
                hide_plus_sign) printf "true" ;;
                icon_mode) printf "dynamic" ;;
                icon) printf "W" ;;
                max_requests_per_hour) printf "1000" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context weather
        plugin_collect
        printf "state=%s has_symbol=%s" \
            "$(plugin_get_state)" \
            "$([ -n "$(plugin_data_get symbol)" ] && echo yes || echo no)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "state=active"
    assert_output --partial "has_symbol=yes"
}

@test "weather full format shows humidity" {
    mock_curl_for_weather

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/weather.sh"
        get_option() {
            case "$1" in
                location) printf "" ;;
                units) printf "m" ;;
                format) printf "full" ;;
                language) printf "" ;;
                hide_plus_sign) printf "true" ;;
                icon_mode) printf "static" ;;
                icon) printf "W" ;;
                max_requests_per_hour) printf "1000" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context weather
        plugin_collect
        printf "weather=%s" "$(plugin_data_get weather)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "H:65%"
}

@test "weather minimal format hides plus sign when configured" {
    cat >"$mock_dir/curl" <<'CURL_EOF'
#!/usr/bin/env bash
case "$*" in
    *geocoding*)
        echo '{"results":[{"latitude":1,"longitude":1,"name":"Test","country":"XX"}]}'
        ;;
    *forecast*)
        echo '{"latitude":1,"longitude":1,"current":{"temperature_2m":5.2,"relative_humidity_2m":50,"weather_code":0,"wind_speed_10m":5,"wind_direction_10m":90,"is_day":1,"precipitation":0},"current_units":{"temperature_2m":"°C","wind_speed_10m":"km/h"}}'
        ;;
esac
CURL_EOF
    chmod +x "$mock_dir/curl"

    cat >"$mock_dir/date" <<'DATE_EOF'
#!/usr/bin/env bash
echo "2025010112"
DATE_EOF
    chmod +x "$mock_dir/date"

    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/weather.sh"
        get_option() {
            case "$1" in
                location) printf "" ;;
                units) printf "m" ;;
                format) printf "minimal" ;;
                language) printf "" ;;
                hide_plus_sign) printf "true" ;;
                icon_mode) printf "static" ;;
                icon) printf "W" ;;
                max_requests_per_hour) printf "1000" ;;
                *) printf "" ;;
            esac
        }
        _set_plugin_context weather
        plugin_collect
        printf "weather=%s" "$(plugin_data_get weather)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    refute_output --partial "+"
}

@test "weather plugin has contract functions" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/weather.sh"
        printf "content_type=%s presence=%s" \
            "$(plugin_get_content_type)" \
            "$(plugin_get_presence)"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output --partial "content_type=dynamic"
    assert_output --partial "presence=conditional"
}

@test "weather resolve_format returns correct preset" {
    run bash -c '
        POWERKIT_ROOT="$1"; export POWERKIT_ROOT
        source "$1/src/core/bootstrap.sh"
        source "$1/src/plugins/weather.sh"
        _resolve_format "minimal"
    ' _ "$POWERKIT_ROOT"
    assert_success
    assert_output "%t"
}
