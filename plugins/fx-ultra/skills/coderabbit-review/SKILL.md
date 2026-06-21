---
name: coderabbit-review
description: "Run CodeRabbit's AI review. PRIMARY path: run it LOCALLY via the `cr` CLI BEFORE opening a PR (part of pre-PR self-review) and only open the PR once the review comes back clean. FALLBACK path: wait for + resolve CodeRabbit's automated review on an already-open PR via its `CodeRabbit` GitHub check. Use during pre-PR self-review, and as a merge gate alongside fx-ultra:copilot-review."
---

# CodeRabbit Review

CodeRabbit reviews code with AI. The **primary** way to use it is **locally, via the `cr` CLI, BEFORE opening a PR** — as part of pre-PR self-review, alongside `/review` and `/simplify`. Only open the PR once the local review comes back clean. A **fallback** path handles CodeRabbit's PR-level review for repos where its GitHub App is configured to auto-review PRs.

## ⛔ Local-First: Run CodeRabbit BEFORE Opening the PR

Catch CodeRabbit's feedback **before** a PR exists, using the `cr` CLI on your local changes:

- Run `cr` during pre-PR self-review (alongside `/simplify` and `/review`), fix everything it flags, and re-run until clean.
- **Only open the PR once the local CodeRabbit review is clean.** This avoids review churn on the PR and the slow push → re-review → resolve loop.
- A clean local review does NOT remove the merge gates — but it usually means CodeRabbit's PR-level review (when the GitHub App is configured) lands clean on the first pass, and often there is nothing left to resolve on the PR at all.

## The `cr` CLI

`cr` is the CodeRabbit CLI (run `cr --help` / `cr review --help`). Key usage:

- `cr review --agent` — review all local changes and emit **structured findings for agent workflows**. **Use this** — it is the easiest to parse and act on. Bare `cr` or `cr review` prints a plain-text review (default mode).
- `cr review --base main` — compare the current branch against `main` (scope the review to the branch's diff).
- `cr review --type committed|uncommitted|all` — scope by change state (default `all` = committed + uncommitted).
- `cr review findings` — reprint findings from the previous local review (no new review).
- `cr doctor` — check installation / local-review readiness (read-only, safe to run).

**⛔ NEVER run `cr auth login` (or any interactive `cr auth …`).** It is interactive and the workspace is expected to be authenticated already. If `cr` reports it is not authenticated, **STOP and report it to the user** — do not attempt to log in.

## When to Use

- **Pre-PR self-review (PRIMARY)** — after implementation + `/simplify`, before `fx-ultra:pr-preparer` opens the PR (`fx-ultra:dev` Step 4.5).
- **PR-level merge gate (FALLBACK)** — when the repo's CodeRabbit GitHub App auto-reviews PRs and you must clear its `CodeRabbit` check before merging, or when `cr` wasn't available locally.
- When the user says "run coderabbit", "cr review", "check rabbit", "did rabbit re-review yet".

## Arguments

- Mode 1 (local): no argument needed — reviews the current working tree / branch.
- Mode 2 (PR-level): pass the PR number — `skill='fx-ultra:coderabbit-review', args='<PR_NUMBER>'`.

---

## Mode 1 (PRIMARY): Local Pre-PR Review via `cr`

Run BEFORE creating the PR, after implementation and `/simplify`.

### Step 1: Run the review

Run in the **FOREGROUND**:

```bash
cr review --agent
```

Use `cr review --agent --base main` to scope to the branch's diff against `main`.

- If `cr` reports it is **not authenticated**, **STOP and report to the user** — the workspace is expected to be authed. **Do NOT run `cr auth login`** (it is interactive). Do not work around it.
- If `cr` is **not installed / unavailable**, skip to Mode 2 (resolve at the PR level after opening) and report this to the user once.

### Step 2: Resolve every actionable finding

Treat findings like self-review feedback:

- **Fix real issues** in code and tests; make atomic commits for the fixes.
- **Nitpicks** may be applied or consciously skipped — don't churn on style the project doesn't care about.
- There are no PR threads to resolve here — this is local. Resolution = the code is fixed (or the finding is a deliberate non-issue).

### Step 3: Re-run until clean (REQUIRED)

Run `cr review --agent` again after fixes. **Repeat Steps 1 → 2 until the review reports no actionable findings.**

- **Cap at 4 iterations.** If CodeRabbit keeps flagging the same design decision after 4 passes, that is a human call, not more code edits — escalate to the user.

### Step 4: Open the PR only when clean

A clean local CodeRabbit review is the gate to PR creation in the SDLC (`fx-ultra:dev` Step 4.5 → Step 5). Do not open the PR with unresolved local CodeRabbit findings.

---

## Mode 2 (FALLBACK): PR-Level Review Wait + Resolve

Use this only when the repo's CodeRabbit GitHub App auto-reviews PRs (it exposes a `CodeRabbit` GitHub check) and you must clear it as a merge gate, or when `cr` was unavailable locally. Cycle until CodeRabbit's check is terminal **and** there are zero unresolved CodeRabbit threads.

### Facts

- CodeRabbit's PR review is **completely independent of CI**. CI passing has NOTHING to do with CodeRabbit.
- CodeRabbit **re-reviews on every push** that changes the PR's head SHA. After you push fixes, the `CodeRabbit` check goes pending again until the new review completes.
- You MUST NOT merge until CodeRabbit's check is terminal AND every CodeRabbit thread is resolved (when the App is configured for the repo).
- **NEVER use raw `gh api repos/.../reviews` or `gh pr view --json reviews` to make merge decisions about CodeRabbit.** Use this skill's bundled script.

### Step 1: Wait for the CodeRabbit Check

CodeRabbit auto-runs — there is **no review-request step**. Run the bundled script **in the FOREGROUND** with `timeout: 1320000` (22 minutes) on the Bash tool call:

```bash
bash [SKILL_BASE_DIR]/skills/coderabbit-review/scripts/wait-for-coderabbit-review.sh <PR_NUMBER>
```

**⚠️ CRITICAL: Run in FOREGROUND — do NOT use `run_in_background`.** Running in the background loses the script output and breaks the cycle.

Script exit codes:
- **Exit 0**: CodeRabbit check reached a terminal state. Output also reports the unresolved-thread count → proceed to Step 2.
- **Exit 1**: Timeout (default 20 min) waiting for the check to settle → STOP. Report: "CodeRabbit check did not settle within 20 min on PR #N." Do not merge.
- **Exit 2**: No CodeRabbit check present after a one-cycle grace period → the CodeRabbit GitHub App is not configured for this repo. If you already ran a clean local `cr` review (Mode 1), the gate is satisfied — proceed. Otherwise report once and proceed without the PR-level gate.
- **Exit 3**: Invalid arguments or gh error → report error to user.

### Step 2: Resolve Feedback

If the script reports unresolved CodeRabbit threads (count > 0), invoke the rabbit-feedback-resolver:

```
Skill tool: skill="fx-ultra:rabbit-feedback-resolver", args="<PR_NUMBER>"
```

That skill handles per-thread categorisation, pushes any code fixes, replies, and resolves each thread.

### Step 3: Loop Until Settled (REQUIRED)

CodeRabbit re-reviews after every push. Once Step 2 pushes fixes, the `CodeRabbit` check goes pending again — go back to Step 1.

**Repeat Steps 1 → 2 until BOTH hold:**

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

**Cap the loop at 4 iterations** — if CodeRabbit is still posting new feedback after 4 wait+resolve cycles, escalate to the user. Almost always this means CodeRabbit and the codebase disagree on a design decision that needs human input.

## Concurrency With Other Reviewers (Mode 2)

Mode 2 can run **in parallel** with `fx-ultra:copilot-review` and any future automated-reviewer skills. The SDLC step that gates merge on automated review should:

- Wait for every configured reviewer (Copilot, CodeRabbit, ...) to settle (terminal + 0 unresolved threads each)
- Loop the entire group: any reviewer that re-runs after a push (CodeRabbit always does) re-triggers its waiter → resolver → possibly more commits → other reviewers' waiters, and so on

**⛔ Pick the right execution mode for your context (see `fx-ultra:dev` Step 6.3):**

- **Root session / standalone caller** → spawn one sub-agent per reviewer in a single Agent-tool message (mode A — true parallel).
- **`fx-ultra:team` coordinator OR a sub-agent yourself** → sub-agents CANNOT spawn sub-agents. Use mode B: invoke each reviewer's wait+resolve lifecycle sequentially, optionally launching this skill's wait script as a background `Bash` process while another reviewer is handled in the foreground.

Never call the Agent tool from inside a sub-agent context.

## Success Criteria

**Mode 1 (local, primary):**
- ✅ `cr review --agent` reports no actionable findings (after fixes)
- ✅ All fixes committed
- ✅ The loop converged (no new findings after the last fix) — PR is now safe to open

**Mode 2 (PR-level, fallback / merge gate):**
- ✅ CodeRabbit check is terminal with a passing conclusion (`success`, or `skipped`/`neutral` per repo config)
- ✅ All CodeRabbit threads resolved (0 unresolved)
- ✅ Any valid concerns fixed and pushed; the loop has converged
