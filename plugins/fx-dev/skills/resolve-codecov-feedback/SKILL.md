---
name: resolve-codecov-feedback
description: Process Codecov coverage reports on PRs and add missing tests for uncovered lines. Use when Codecov reports insufficient coverage, the user says "check codecov", "fix coverage", "add missing tests", or after CI passes and Codecov posts its report. Also invoked automatically by the SDLC workflow and resolve-pr-feedback skill.
---

# Resolve Codecov Feedback

Process Codecov coverage reports on pull requests, identify uncovered lines introduced by the PR, and delegate test creation via the coder skill to close coverage gaps.

## WHEN TO USE THIS SKILL

- Codecov has posted a coverage report on a PR (commit status, PR comment, or review comments)
- User says "check codecov" / "fix coverage" / "add missing tests for coverage"
- Invoked by `fx-dev:resolve-pr-feedback` when Codecov feedback is detected
- As part of the SDLC workflow (Step 7.5) after CI checks pass

## Prerequisites

**CRITICAL: Load the `fx-dev:github` skill FIRST** before running any GitHub API operations.

## Core Workflow

### 1. Determine PR Number and Repo

If not provided, get from current branch:

```bash
PR_NUMBER=$(gh pr view --json number -q '.number')
REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
```

### 2. Collect Codecov Report Data

Gather all coverage data from three possible sources:

#### 2a. Commit Statuses (codecov/patch, codecov/project)

```bash
HEAD_SHA=$(gh pr view $PR_NUMBER --json headRefOid --jq '.headRefOid')
gh api "/repos/$REPO_NWO/commits/$HEAD_SHA/statuses" \
  --jq '.[] | select(.context | startswith("codecov/")) | {context, state, description, target_url}'
```

Key statuses:
- `codecov/patch` — Coverage of lines changed in the PR (most actionable)
- `codecov/project` — Overall project coverage impact

**If both statuses show `success`**: Coverage meets thresholds. Report clean and exit.

#### 2b. PR Comment from codecov[bot]

```bash
gh api "/repos/$REPO_NWO/issues/$PR_NUMBER/comments" \
  --jq '.[] | select(.user.login == "codecov[bot]" or .user.login == "codecov-commenter") | .body' | tail -1
```

The PR comment contains:
- Patch coverage percentage
- Project coverage delta
- Links to the full Codecov report
- File-by-file coverage breakdown (often in a table)

Parse the comment body to extract:
- **Patch coverage %** — The coverage of new/changed lines
- **Files with missing coverage** — Listed in the coverage table
- **Codecov report URL** — Use `target_url` from commit status or links in the comment

#### 2c. Line-level Review Comments (if Codecov annotations are enabled)

```bash
gh api "/repos/$REPO_NWO/pulls/$PR_NUMBER/comments" \
  --jq '.[] | select(.user.login == "codecov[bot]" or .user.login == "codecov-commenter") | {path, line: (.line // .original_line), body}'
```

These pinpoint exact uncovered lines in changed files.

### 3. Assess Coverage Status

**⚠️ CRITICAL: CI status alone is NOT sufficient.** The `codecov/patch` CI check may pass at a lower threshold (e.g., 80%) than the project actually requires. You MUST always read the codecov[bot] PR comment to determine the actual patch coverage percentage and identify missing lines.

**Step 3a: Check the PR comment (MANDATORY — do this FIRST)**

Read the codecov[bot] PR comment from Step 2b. Extract:
- The **patch coverage percentage** (e.g., "Patch coverage is 86.45%")
- The **list of files with missing lines** and their per-file coverage
- The **number of missing lines** (e.g., "13 lines missing coverage")

**Step 3b: Determine the project's coverage requirement**

Check the project's `CLAUDE.md` for coverage requirements. Look for patch coverage targets. If not specified, **default to 100% patch coverage** — all new/changed lines must be covered.

**Step 3c: Decide action**

| Condition | Action |
|-----------|--------|
| PR comment shows **0 missing lines** AND patch coverage meets project requirement | Report clean and exit |
| PR comment shows **any missing lines** (even if CI passes) | Coverage gap — **proceed to Step 4** |
| No PR comment but CI status is `failure` | Coverage gap — **proceed to Step 4** |
| No Codecov data at all | Report: "No Codecov data found" and exit |

**IMPORTANT:** A `codecov/patch` CI status of `success` does NOT mean coverage is adequate. Always trust the PR comment data over CI status.

### 4. Identify Uncovered Lines

Build a list of files and line ranges that need test coverage:

**From line-level review comments** (most precise):
- Each comment points to a specific file and line
- Collect all `{path, line, body}` tuples

**From the PR comment table** (when no line-level comments):
- Parse the file-by-file coverage table from the codecov[bot] comment
- Extract filenames and their patch coverage percentages
- For files with ANY missing lines (below 100% patch coverage, or below the project's requirement), read the file diff to identify new/changed lines

**From the Codecov report URL** (fallback):
- Use `WebFetch` on the `target_url` from the commit status to get detailed coverage data
- Extract file-level and line-level coverage information

### 5. Delegate Test Creation via Coder Skill

For each file with uncovered lines, launch a sub-agent with the coder skill:

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

           Add tests to improve coverage for PR #[PR_NUMBER].

           The following files have uncovered lines that need test coverage:

           [LIST OF FILES WITH UNCOVERED LINES]

           For each file:
           1. Read the file to understand the uncovered code
           2. Identify the appropriate test file (existing or new)
           3. Write tests that exercise the uncovered lines
           4. Follow existing test patterns in the codebase
           5. Run tests to verify they pass

           IMPORTANT:
           - Only add tests for lines changed in this PR (patch coverage)
           - Follow existing test patterns and conventions
           - Do NOT skip tests (test.skip is FORBIDDEN)
           - Run bun run test to verify all tests pass
           - Run bun run lint and bun run type-check
           - Commit with: test: add coverage for [brief description]
           - Push to the PR branch"
  description: "Add tests for uncovered lines"
```

### 6. Verify Coverage Improvement

After the coder sub-agent pushes new tests:

1. Wait for CI to re-run (tests must pass)
2. Wait for Codecov to post an updated report
3. Check if `codecov/patch` status is now `success`

If coverage still fails after one iteration, report the remaining gaps to the user rather than looping indefinitely. Coverage is often an iterative process and some lines may be intentionally untestable.

### 7. Report Summary

```
## Codecov Coverage Summary for PR #[NUMBER]

### Before
- Patch coverage: X%
- Files with gaps: [list]

### After
- Patch coverage: Y%
- Tests added: [count] test(s) across [count] file(s)

### Remaining Gaps (if any)
- [file]: [reason why not covered]
```

## Handling Edge Cases

### Codecov Not Configured

If no Codecov data is found on the PR:
- Check if `.codecov.yml` or `codecov.yml` exists in the repo root
- Check if CI uploads coverage (look for `codecov/codecov-action` in workflows)
- Report to user: "Codecov does not appear to be configured for this repository."
- Exit without error — this is not a failure condition

### Coverage Report Shows All Green

If the codecov[bot] PR comment shows **0 missing lines** and patch coverage is 100% (or meets the project's explicit requirement):
- Report: "Codecov patch coverage is 100%. No action needed."
- Exit cleanly

**Do NOT rely solely on CI status.** Always verify via the PR comment.

### Untestable Code

Some code is intentionally hard to test (error handlers, edge cases, platform-specific code). If the coder sub-agent cannot reasonably test certain lines:
- Document which lines are intentionally uncovered and why
- Report to user for manual decision
- Do NOT add meaningless tests just to hit a number

## Success Criteria

1. All Codecov report data collected and analyzed
2. Uncovered lines identified from PR changes
3. Tests delegated via coder skill and pushed
4. Coverage improvement verified (or gaps reported)
5. Summary output provided
