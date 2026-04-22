---
name: copilot-review
description: "Request, wait for, and resolve GitHub Copilot's automated PR review. Use after creating or marking a PR ready. Copilot reviews EVERY PR automatically — this skill handles the full lifecycle: request review, poll until received, then resolve all feedback. MUST be used before merging any PR."
---

# Copilot Review

Request, wait for, and resolve GitHub Copilot's automated PR review on a pull request.

## ⛔ Copilot Is Automatic and Mandatory

**Copilot reviews EVERY pull request automatically. It does NOT need to be "configured" or "enabled" — it is ALWAYS active on every repo.**

- Copilot review is **completely independent of CI**. They are separate systems. CI passing has NOTHING to do with Copilot.
- You MUST NOT merge ANY PR until Copilot has reviewed it and all feedback is resolved.
- No exceptions — not for "first PRs", not for "small PRs", not because "CI isn't set up yet", not because "nothing is configured yet".
- **NEVER use raw `gh api repos/.../reviews` commands to check Copilot status.** Use the script provided by this skill.

## When to Use

- After creating a draft PR (SDLC Step 6.3)
- Before merging any PR (team coordinator merge gate)
- When user says "check copilot", "wait for copilot", "copilot review"

## Arguments

This skill expects a PR number. Pass it as args: `skill='fx-dev:copilot-review', args='<PR_NUMBER>'`

## Workflow

### Step 1: Request Copilot Review

```bash
# Get repo info
REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

# Request Copilot review using JSON body format (most reliable)
gh api --method POST "/repos/${REPO_NWO}/pulls/<PR_NUMBER>/requested_reviewers" \
  --input - <<'EOF'
{"reviewers":["copilot-pull-request-reviewer[bot]"]}
EOF
```

If the request fails with a 422 (already reviewed or already requested), that's fine — proceed to Step 2.

### Step 2: Wait for Review

Run the bundled script **in the FOREGROUND** with `timeout: 660000` (11 minutes) on the Bash tool call:

```bash
bash [SKILL_BASE_DIR]/skills/copilot-review/scripts/wait-for-copilot-review.sh <PR_NUMBER>
```

**⚠️ CRITICAL: Run in FOREGROUND — do NOT use `run_in_background`.** The output must be directly available to determine the result.

Script exit codes:
- **Exit 0**: Review received → proceed to Step 3
- **Exit 1**: Timeout after 15 minutes → STOP. Report to user: "Copilot review timed out on PR #N. Cannot merge without it."
- **Exit 2**: Review not requested → go back to Step 1 to request, then re-run this script
- **Exit 3**: Invalid arguments or gh error → report error to user

### Step 3: Resolve Feedback

After the review is received, invoke the resolve-pr-feedback skill to process all automated review threads (Copilot, CodeRabbit, Codecov):

```
Skill tool: skill="fx-dev:resolve-pr-feedback", args="<PR_NUMBER>"
```

This skill will:
1. Find all unresolved Copilot threads
2. Categorize each (nitpick, valid, incorrect, outdated, deferred)
3. Fix valid concerns, reply to and resolve all threads
4. Report a summary table of actions taken

### Step 4: Confirm Resolution

After resolve-pr-feedback completes, verify zero unresolved threads remain:

```bash
OWNER="${REPO_NWO%%/*}"
REPO="${REPO_NWO##*/}"
gh api graphql -f query="
query {
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    pullRequest(number: <PR_NUMBER>) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 1) {
            nodes { author { login } }
          }
        }
      }
    }
  }
}" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)] | length'
```

If the count is 0, Copilot gate is PASSED. If > 0, re-invoke resolve-pr-feedback.

## Success Criteria

This skill is complete when ALL of:
- ✅ Copilot review has been received (script exited 0)
- ✅ All Copilot threads resolved (0 unresolved)
- ✅ Any valid code concerns have been fixed and pushed
