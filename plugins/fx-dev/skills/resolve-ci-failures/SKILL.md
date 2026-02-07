---
name: resolve-ci-failures
description: "Analyze and fix CI check failures on a PR. Use when CI checks fail, build errors occur, or tests fail in CI. Invoked automatically by the SDLC workflow (Step 7.4) when checks fail, or manually via 'resolve CI failures', 'fix CI', 'fix failing checks'."
---

# Resolve CI Failures

Meta-skill that analyzes failing CI checks on a PR, fetches failure logs, categorizes failures, and delegates fixes to the coder agent.

## WHEN TO USE THIS SKILL

**USE THIS SKILL** when ANY of the following occur:

- SDLC Step 7.4 invokes it after `wait-for-ci-checks.sh` exits with code 1
- User says "resolve CI failures" / "fix CI" / "fix failing checks" / "fix the build"
- CI checks are red and fixes need to be coordinated
- After pushing code to a PR when checks fail

## Prerequisites

**CRITICAL: Load the `fx-dev:github` skill FIRST** before running any GitHub API operations.

## CRITICAL RULES

- ❌ NEVER skip or disable tests to make CI pass (`test.skip`, `it.skip`, `describe.skip` are FORBIDDEN)
- ❌ NEVER suppress lint errors with ignore comments unless truly justified and explained
- ❌ NEVER leave comments directly on the GitHub PR
- ❌ NEVER retry a check without pushing a fix first
- ✅ ALWAYS fix root causes, not symptoms
- ✅ ALWAYS push changes after fixing
- ✅ ALWAYS report infrastructure failures to user — do not attempt to fix them

## Core Workflow

### 1. Determine PR Number

If not provided, get from current branch:

```bash
gh pr view --json number,headRefName -q '.number'
```

### 2. Get Failing Check Details

Query the PR for failed checks:

```bash
gh pr checks [PR_NUMBER] --json name,state,conclusion
```

Filter for checks with conclusion `FAILURE`, `CANCELLED`, `TIMED_OUT`, or `ACTION_REQUIRED`.

### 3. Fetch Failure Logs

For each failing check, fetch detailed logs to understand the root cause.

**Step 3a: Get the head SHA and repo info:**

```bash
gh pr view [PR_NUMBER] --json headRefOid,headRefName -q '.headRefOid'
```

**Step 3b: Get check run IDs for failing checks:**

**IMPORTANT:** Use inline values, NOT `$variable` syntax. The `$` character causes shell escaping issues.

```bash
# Replace OWNER, REPO, SHA with actual values
gh api repos/OWNER/REPO/commits/SHA/check-runs --jq '.check_runs[] | select(.conclusion == "failure") | {name: .name, id: .id}'
```

**Step 3c: Fetch annotations (structured error details):**

```bash
# Replace OWNER, REPO, CHECK_RUN_ID with actual values
gh api repos/OWNER/REPO/check-runs/CHECK_RUN_ID/annotations
```

**Step 3d: Fetch GitHub Actions workflow run logs (if applicable):**

```bash
# List failed workflow runs for the branch
gh run list --branch [BRANCH] --json databaseId,name,conclusion --jq '.[] | select(.conclusion == "failure")'

# View the failed run's log output (truncated to failed steps)
gh run view [RUN_ID] --log-failed
```

**⚠️ NOTE:** `gh run view --log-failed` can produce very large output. If the output is too large, try fetching specific job logs:

```bash
# List jobs in the run
gh run view [RUN_ID] --json jobs --jq '.jobs[] | select(.conclusion == "failure") | {name: .name, id: .databaseId}'

# View a specific job's log
gh api repos/OWNER/REPO/actions/jobs/JOB_ID/logs
```

### 4. Categorize Each Failure

| Category | Indicator | Action |
|----------|-----------|--------|
| **Test failure** | Test runner output, assertion errors, `FAIL` in test logs | Delegate to coder to fix test or code |
| **Build error** | Compilation errors, missing deps, `tsc` errors, module not found | Delegate to coder to fix build |
| **Lint/Format error** | ESLint, Prettier, stylelint, `--fix` suggestions | Delegate to coder to run formatter/fix lint |
| **Security scan** | Vulnerability alerts, `npm audit`, Dependabot | Delegate to coder to update deps or fix |
| **Flaky test** | Test passed locally, intermittent failure, no code change caused it | Note as flaky — may pass on re-run without changes |
| **Infrastructure** | Runner errors, timeout, network failures, Docker pull errors | Report to user — not fixable by code changes |

### 5. Delegate Fixes

For each fixable failure, delegate to the coder agent:

```
Task tool:
  subagent_type: "fx-dev:coder"
  prompt: "Fix the following CI failure on PR #[NUMBER]:

           Check name: [CHECK_NAME]
           Conclusion: [CONCLUSION]
           Error details:
           [LOGS/ANNOTATIONS FROM STEP 3]

           - Analyze the error and fix the root cause
           - Do NOT suppress errors or skip tests
           - Commit with format: fix(ci): description
           - Push changes after committing"
  description: "Fix CI failure: [CHECK_NAME]"
```

If multiple checks failed with independent root causes, delegate fixes for ALL of them. Sequential delegation is preferred to avoid merge conflicts.

### 6. Push Changes

Verify all fixes are committed and pushed:

```bash
git status
git push
```

If the coder agent already pushed, verify with:

```bash
git log --oneline -3
gh pr view [PR_NUMBER] --json commits --jq '.commits[-1].oid'
```

### 7. Verify Fix Was Pushed

Confirm the latest commit on the PR includes the fix:

```bash
# Local HEAD should match the PR's head
git rev-parse HEAD
gh pr view [PR_NUMBER] --json headRefOid -q '.headRefOid'
```

If they differ, push is needed:
```bash
git push
```

## Output Format

```
## CI Failure Resolution — PR #123

### Failing Checks Detected
- tests (FAILURE)
- lint (FAILURE)
- deploy (TIMED_OUT)

### Resolution

| Check Name | Category | Action Taken | Status |
|------------|----------|--------------|--------|
| tests | Test failure | Fixed assertion in foo.test.ts | ✅ Fixed |
| lint | Lint error | Ran prettier, fixed imports | ✅ Fixed |
| deploy | Infrastructure | Runner timeout — not code-related | ⚠️ Reported |

### Next Steps
- Fixes pushed. SDLC workflow will re-run wait-for-ci-checks.sh to verify.
- Infrastructure issue (deploy): Requires manual intervention or re-run.
```

## Success Criteria

1. ✅ All fixable CI failures analyzed and root causes identified
2. ✅ Fixes delegated to coder agent and committed
3. ✅ Changes pushed to PR branch
4. ✅ Summary table output with categories and actions
5. ✅ Non-fixable failures (infrastructure/flaky) clearly reported to user

## Error Handling

- If no PR found: Ask user for PR number
- If coder agent fails to fix: Report the failure with full context including logs
- If failure is infrastructure-related: Report to user, do not attempt fix
- If check logs cannot be fetched: Use check name and conclusion to infer the issue, delegate to coder with available context
- If `gh run view --log-failed` is too large: Fetch individual job logs instead
