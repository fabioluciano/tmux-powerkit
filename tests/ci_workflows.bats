#!/usr/bin/env bats

setup() {
    POWERKIT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WORKFLOW="$POWERKIT_ROOT/.github/workflows/semantic-release.yaml"
}

@test "semantic release exports the Homebrew Bash executable" {
    run grep -F 'homebrew_bash="$(brew --prefix bash)/bin/bash"' "$WORKFLOW"
    [ "$status" -eq 0 ]

    run grep -F 'echo "HOMEBREW_BASH=$homebrew_bash" >>"$GITHUB_ENV"' "$WORKFLOW"
    [ "$status" -eq 0 ]
}

@test "semantic release builds with Homebrew Bash instead of sh" {
    run grep -F 'NEXT_RELEASE_VERSION=build "$HOMEBREW_BASH" scripts/build.sh "$BUILD_SUFFIX"' "$WORKFLOW"
    [ "$status" -eq 0 ]

    run grep -E '(^|[[:space:]])sh[[:space:]]+scripts/build\.sh' "$WORKFLOW"
    [ "$status" -ne 0 ]
}
