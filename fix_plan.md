# fix_plan.md — persistent work-state file for multi-step editing sessions.
#
# Read this file before a multi-step session so the agent tracks real code
# changes instead of looping over formatting artifacts (CRLF/LF churn, whitespace
# diffs). Each entry records the semantic change and its verification status.
#
# Rules of thumb to avoid the prior loop:
#   1. All text files are LF (see .gitattributes); `tools/check-line-endings.sh`
#      exits 1 if CRLF is still present, so a check can hard-cap the session.
#   2. Diffs are inspected with `git diff --ignore-cr-at-eol` so line endings can
#      never masquerade as content changes.
#   3. Before any edit, mark "state=" as planned, then in-progress, then verified,
#      so a stalled session can resume on the current state.
#
# Format:
#   - [ ] <short title>
#     state: planned | in-progress | fixed | verified | blocked
#     verify: <command + expected output>

# Example entry (do not treat as work to be done; one per task):
# - [ ] Split src/metal_roof/main.rb into focused implementation files
#     state: planned
#     verify: `bundle exec rubocop --parallel` with zero offenses

# Current session entries:
- [ ] Apply CRLF/LF safeguard config (.gitattributes, core.autocrlf=input)
    state: fixed
    verify: `./tools/check-line-endings.sh --strict` exits 0 and `git status --short` shows only .gitattributes + tracked source changes
