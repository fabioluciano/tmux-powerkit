## Summary

<!-- 1-3 bullet points describing what changed and why -->

## Changes

<!-- List of changes with their types (feat/fix/chore/refactor/etc.) -->

- **`<type>(<scope>): <subject>`** - short description
  - Detail 1
  - Detail 2

## Test Plan

<!-- How was this validated? -->

- [ ] `bash tests/run_all_tests.sh` — passes
- [ ] `tests/test_shellcheck.sh` — 0 warnings
- [ ] `pre-commit validate-config` — passes
- [ ] CI matrix (ubuntu + macOS) — passes
- [ ] Manual smoke test of affected plugins

## Verification log

<!-- Paste command output here for reviewers -->

```text
$ bash tests/run_all_tests.sh
... (paste relevant output)

$ shellcheck -S warning bin/ scripts/ tests/
... (paste relevant output)
```

## Out of scope / known follow-up

<!-- Anything discovered but intentionally not fixed in this PR -->

## Checklist

- [ ] Branch is up-to-date with `main`
- [ ] Commit messages follow Conventional Commits
- [ ] No `Co-Authored-By` lines
- [ ] No emoji in commit messages or PR title
- [ ] All tests pass locally
- [ ] No new shellcheck warnings introduced
- [ ] Plugin contract still respected (data only, no UI logic)
- [ ] Cross-platform impact considered (Linux + macOS)