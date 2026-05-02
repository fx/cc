---
name: resolve-pr-feedback
description: Check a PR for unresolved automated review feedback (Copilot, CodeRabbit, Codecov) and invoke the appropriate resolver skills. Use when the user says "resolve PR feedback", "check PR comments", "address review comments", "fix coverage", or wants to handle all automated review feedback on a PR.
---

# Resolve PR Feedback

Meta-skill that checks a PR for unresolved automated review feedback and invokes the appropriate resolver skills.

## WHEN TO USE THIS SKILL

**USE THIS SKILL** when ANY of the following occur:

- User says "resolve PR feedback" / "check PR comments" / "address review comments"
- User wants to handle all automated review feedback on a PR
- After PR creation to ensure all automated reviewers are addressed
- As part of the SDLC workflow before finalizing a PR

## Supported Reviewers

| Reviewer | Author Pattern | Resolver Skill |
|----------|---------------|----------------|
| GitHub Copilot | `Copilot` | `fx-dev:copilot-feedback-resolver` |
| CodeRabbit | `coderabbitai[bot]` | `fx-dev:rabbit-feedback-resolver` |
| Codecov | `codecov[bot]` / `codecov-commenter` | `fx-dev:resolve-codecov-feedback` |

## Prerequisites

**CRITICAL: Load the `fx-dev:github` skill FIRST** before running any GitHub API operations.

## Core Workflow

### 1. Determine PR Number

If not provided, get from current branch:

```bash
gh pr view --json number -q '.number'
```

### 2. Query All Unresolved Review Threads

**IMPORTANT:** Use inline values, NOT `$variable` syntax. The `$` character causes shell escaping issues.

```bash
# Replace OWNER, REPO, PR_NUMBER with actual values
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 1) {
            nodes {
              author { login }
            }
          }
        }
      }
    }
  }
}'
```

### 3. Identify Unresolved Feedback by Source

Parse the response and categorize unresolved threads by author:

- **Copilot threads**: author login is `Copilot`
- **CodeRabbit threads**: author login contains `coderabbitai`

### 3b. Check for Codecov Coverage Feedback

Codecov uses PR comments and commit statuses, NOT review threads. Query separately:

```bash
# Check for Codecov commit statuses
HEAD_SHA=$(gh pr view PR_NUMBER --json headRefOid --jq '.headRefOid')
gh api "/repos/OWNER/REPO/commits/$HEAD_SHA/statuses" \
  --jq '[.[] | select(.context | startswith("codecov/"))] | {count: length, statuses: [.[] | {context, state, description}]}'

# Check for Codecov PR comments
gh api "/repos/OWNER/REPO/issues/PR_NUMBER/comments" \
  --jq '[.[] | select(.user.login == "codecov[bot]" or .user.login == "codecov-commenter")] | length'
```

Codecov feedback exists if:
- Any `codecov/*` commit status has state `failure` or `error`
- OR Codecov PR comment indicates patch coverage below threshold

### 4. Invoke Appropriate Resolver Skills

**If Copilot threads exist:**
```
Skill tool: skill="fx-dev:copilot-feedback-resolver"
```

**If CodeRabbit threads exist:**
```
Skill tool: skill="fx-dev:rabbit-feedback-resolver"
```

**If Codecov coverage gaps detected:**
```
Skill tool: skill="fx-dev:resolve-codecov-feedback"
```

**If multiple exist:** Prefer running Copilot and CodeRabbit resolvers **in parallel** by spawning each as a sub-agent in the same message (see `fx-dev:dev` Step 6.3 for the exact pattern). Codecov is sequential after them since coverage fixes typically require code from the other resolvers to be in place first.

### 5. Verify All Resolved AND Loop Until Convergence

After invoking resolver skills, re-query to confirm all threads are resolved AND that no reviewer has posted new feedback in response to the fixes that were pushed.

**Cycle, don't single-shot.** CodeRabbit specifically re-runs after every push and may post new threads on the new commits. Single-pass resolvers leave a stale "settled" state behind. Loop:

1. Wait for all reviewer checks to reach terminal state (use the dedicated waiters: `fx-dev:copilot-review` for Copilot, `fx-dev:coderabbit-review` for CodeRabbit).
2. Re-query unresolved threads (per below).
3. If count > 0, re-invoke the relevant resolver(s).
4. After fixes are pushed, restart at step 1.
5. Stop when two consecutive passes produce zero new feedback. Cap at 4 outer iterations and escalate to the user if not converged.

Re-query to count remaining unresolved threads:

```bash
# Replace OWNER, REPO, PR_NUMBER with actual values
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 1) {
            nodes {
              author { login }
            }
          }
        }
      }
    }
  }
}' | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)] | length'
```

If unresolved threads remain, report which reviewers still have open feedback.

## Output Format

```
## PR #123 Feedback Summary

### Detection
- Copilot: 2 unresolved threads found
- CodeRabbit: 3 unresolved threads found
- Codecov: patch coverage 65% (below threshold)

### Resolution
- Invoked fx-dev:copilot-feedback-resolver
- Invoked fx-dev:rabbit-feedback-resolver
- Invoked fx-dev:resolve-codecov-feedback

### Final Status
- All automated review threads resolved
- Coverage improved to 85%
```

## Success Criteria

1. All unresolved automated review threads identified
2. Appropriate resolver skill(s) invoked (Copilot + CodeRabbit in parallel where applicable)
3. The wait-and-resolve loop has CONVERGED — two consecutive passes produced zero new feedback from any reviewer
4. CodeRabbit's check is in a terminal passing state (or absent if not configured)
5. Final verification confirms all threads resolved
6. Summary output provided

## Error Handling

- If no PR found: Ask user for PR number
- If resolver skill fails: Report which reviewer's feedback remains unresolved
- If API errors: Retry with proper auth context
