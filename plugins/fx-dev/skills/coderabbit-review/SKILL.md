---
name: coderabbit-review
description: "Wait for and resolve CodeRabbit's automated PR review on a pull request. CodeRabbit auto-reviews every PR (no request needed) and re-reviews after each push, exposing its state via the 'CodeRabbit' GitHub check. This skill handles the full lifecycle: poll the check, resolve all feedback, and loop until the check is terminal AND zero CodeRabbit threads remain unresolved. MUST be used before merging any PR alongside fx-dev:copilot-review."
---

# CodeRabbit Review

Wait for, then resolve, CodeRabbit's automated PR review on a pull request. Cycle until CodeRabbit's check is terminal **and** there are zero unresolved CodeRabbit threads.

## ⛔ CodeRabbit Is Automatic and Mandatory

**CodeRabbit reviews every PR automatically when configured for the repo.** It exposes its state through a GitHub check named `CodeRabbit` (visible in `gh pr checks`).

- CodeRabbit review is **completely independent of CI**. They are separate systems. CI passing has NOTHING to do with CodeRabbit.
- CodeRabbit **re-reviews on every push** that changes the PR's head SHA. After you push fixes for its feedback, the `CodeRabbit` check goes pending again until the new review completes.
- You MUST NOT merge ANY PR until CodeRabbit's check is in a terminal state AND every CodeRabbit thread is resolved.
- This skill is the canonical way to wait for + resolve CodeRabbit. Pair it with `fx-dev:copilot-review` to satisfy both reviewer gates.
- **NEVER use raw `gh api repos/.../reviews` or `gh pr view --json reviews` to make merge decisions about CodeRabbit.** Use this skill's bundled script.

## When to Use

- After creating or marking a PR ready (SDLC Step 6.3)
- Before merging any PR (team coordinator merge gate)
- Any time the PR's head SHA changes after addressing CodeRabbit feedback (re-review cycle)
- When the user says "wait for coderabbit", "check rabbit", "did rabbit re-review yet"

## Arguments

This skill expects a PR number. Pass it as args: `skill='fx-dev:coderabbit-review', args='<PR_NUMBER>'`

## Workflow

### Step 1: Wait for the CodeRabbit Check

CodeRabbit auto-runs — there is **no review-request step**. Just wait for its check.

Run the bundled script **in the FOREGROUND** with `timeout: 1320000` (22 minutes) on the Bash tool call:

```bash
bash [SKILL_BASE_DIR]/skills/coderabbit-review/scripts/wait-for-coderabbit-review.sh <PR_NUMBER>
```

**⚠️ CRITICAL: Run in FOREGROUND — do NOT use `run_in_background`.** Running in the background loses the script output and breaks the cycle.

Script exit codes:
- **Exit 0**: CodeRabbit check reached a terminal state (success/failure/skipped/etc.). Output also reports the unresolved-thread count → proceed to Step 2.
- **Exit 1**: Timeout (default 20 min) waiting for the check to settle → STOP. Report to user: "CodeRabbit check did not settle within 20 min on PR #N." Do not merge.
- **Exit 2**: No CodeRabbit check present on the PR after a one-cycle grace period → CodeRabbit is not configured for this repo. Skip the gate; report this to the user once and proceed without CodeRabbit. (Do NOT silently skip if CodeRabbit IS expected to run — confirm with the user first.)
- **Exit 3**: Invalid arguments or gh error → report error to user.

### Step 2: Resolve Feedback

If the script reports unresolved CodeRabbit threads (count > 0), invoke the rabbit-feedback-resolver to address every unresolved thread:

```
Skill tool: skill="fx-dev:rabbit-feedback-resolver", args="<PR_NUMBER>"
```

That skill handles per-thread categorisation (nitpick / actionable-with-AI-prompt / committable / general / deferred), pushes any code fixes, replies, and resolves each thread.

### Step 3: Loop Until Settled (REQUIRED)

CodeRabbit re-reviews after every push. So once Step 2 pushes fixes, the `CodeRabbit` check goes pending again — you must go back to Step 1.

**Repeat Steps 1 → 2 until BOTH conditions hold:**

1. The most-recent CodeRabbit check is in a terminal state with conclusion `success` (or `skipped` / `neutral` if the repo configures it that way).
2. Re-querying review threads shows 0 unresolved CodeRabbit threads.

```bash
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: <PR_NUMBER>) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 1) { nodes { author { login } } }
        }
      }
    }
  }
}' --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and (.comments.nodes[0].author.login | tostring | contains("coderabbitai")))] | length'
```

If this count is 0 AND the CodeRabbit check is `success`, the gate is PASSED.

**Cap the loop at 4 iterations** — if CodeRabbit is still posting new feedback after 4 wait+resolve cycles, escalate to the user. Almost always this means CodeRabbit and the codebase disagree on a design decision that needs human input, not more code edits.

## Concurrency With Other Reviewers

This skill can run **in parallel** with `fx-dev:copilot-review` and any future automated-reviewer skills. The SDLC step that gates PR-ready on automated review should:

- Wait for every configured reviewer (Copilot, CodeRabbit, ...) to settle (terminal + 0 unresolved threads each)
- Loop the entire group: any reviewer that re-runs after a push (CodeRabbit always does) re-triggers its waiter, which re-triggers its resolver, which may push more commits, which may re-trigger other reviewers' waiters, and so on

**⛔ Pick the right execution mode for your context (see `fx-dev:dev` Step 6.3):**

- **Root session / standalone caller** → spawn one sub-agent per reviewer in a single Agent-tool message (mode A — true parallel).
- **`fx-dev:team` coordinator OR a sub-agent yourself** → sub-agents CANNOT spawn sub-agents. Use mode B: invoke each reviewer's wait+resolve lifecycle sequentially, optionally launching this skill's wait script as a background `Bash` process while another reviewer is handled in the foreground.

Treat reviewers as independent feedback channels, not as a strict sequence. Copilot and CodeRabbit have very different latencies; overlap is normal. But never call the Agent tool from inside a sub-agent context — it will fail or produce an inline-implementation cargo-cult.

## Success Criteria

This skill is complete when ALL of:

- ✅ CodeRabbit check is in terminal state with a passing conclusion (`success`, or `skipped`/`neutral` per repo config)
- ✅ All CodeRabbit threads resolved (0 unresolved)
- ✅ Any valid code concerns have been fixed and pushed
- ✅ The loop has converged (no new CodeRabbit feedback after the last fix push)
