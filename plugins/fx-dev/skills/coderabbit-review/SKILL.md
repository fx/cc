---
name: coderabbit-review
description: "Run CodeRabbit's optional AI review. PRIMARY path: run it LOCALLY via the `cr` CLI before opening a PR and resolve blocking findings. FALLBACK path: wait for + resolve its automated PR review when available. Pass a Scope Brief as args — findings MUST be triaged against the user's original request. Rate limits degrade gracefully: report once, skip CodeRabbit, and continue the SDLC."
---

# CodeRabbit Review

CodeRabbit reviews code with AI. The **primary** way to use it is **locally, via the `cr` CLI, BEFORE opening a PR** — as part of pre-PR self-review, alongside `/review` and `/simplify`. Prefer a clean local result when the service is available. A **fallback** path handles CodeRabbit's PR-level review for repos where its GitHub App is configured to auto-review PRs.

**IMPORTANT — CodeRabbit is optional when rate-limited.** If the CLI, API, GitHub check, or wait script reports a CodeRabbit quota/rate limit, report it once and continue without CodeRabbit. Do not sleep, poll, retry after a cooldown, ask the user to wait, or block PR creation/merge solely on CodeRabbit throttling. Resolve blocking findings already received before the limit, then mark the CodeRabbit pass as `skipped (rate-limited)`. Immaterial observations are not resolved by editing — actioning one manufactures the next round's input. This exception applies only to CodeRabbit; it does not relax Copilot, CI, tests, or other merge gates.

## ⛔ Local-First: Run CodeRabbit BEFORE Opening the PR

Catch CodeRabbit's feedback **before** a PR exists, using the `cr` CLI on your local changes:

- Run `cr` during pre-PR self-review (alongside `/simplify` and `/review`), fix every **blocking** finding, and re-run until none is left unresolved (`fx-dev/skills/dev/references/scope-contract.md` § Convergence — the ledger test, not "the latest pass was quiet"). Immaterial observations get one closing note and do not buy another run — see the materiality bar in `fx-dev/skills/dev/references/scope-contract.md`.
- Open the PR once the local review has **converged** — no blocking finding left unresolved — **or is correctly degraded as `skipped (rate-limited)`**. Resolve the blocking findings already received before proceeding; immaterial ones travel as a closing note.
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

- **Pre-PR self-review (PRIMARY)** — after implementation + `/simplify`, before `fx-dev:pr-preparer` opens the PR (`fx-dev:dev` Step 4.5).
- **PR-level merge gate (FALLBACK)** — when the repo's CodeRabbit GitHub App auto-reviews PRs and you must clear its `CodeRabbit` check before merging, or when `cr` wasn't available locally.
- When the user says "run coderabbit", "cr review", "check rabbit", "did rabbit re-review yet".

## Arguments

- Mode 1 (local): pass the **Scope Brief** (see below). No PR number needed — reviews the current working tree / branch.
- Mode 2 (PR-level): pass the PR number plus the Scope Brief — `skill='fx-dev:coderabbit-review', args='<PR_NUMBER> — <scope brief>'`.

## MANDATORY: Carry the Scope Brief

**Never review a bare diff.** A reviewer that does not know what was asked for
reports the work you deliberately did not do — missing implementation for a
docs-only change, missing tests for a spec, dependencies a later phase adds.
Each such finding costs a full cycle to filter by hand.

Every invocation of this skill MUST carry a **Scope Brief** (canonical definition
and field rules: `fx-dev/skills/dev/references/scope-contract.md`) holding the
user's **verbatim** request, the interpreted scope, the deliverable type, an
explicit out-of-scope list with reasons, and anything known-and-accepted.

**If you were invoked without one, reconstruct it from the conversation before
reviewing, and say that you did.**

How the brief is applied differs by mode:

- **Mode 1 (local `cr`)** — CodeRabbit's CLI reviews the diff and does not take a
  scope prompt. Apply the brief when **triaging** its output.
- **Mode 2 (PR-level GitHub App)** — the brief cannot reach the reviewer at all.
  Apply it entirely at triage.

In both modes, triage means: a finding covered by the out-of-scope list is
**recorded as deferred with the exclusion that covers it**, never silently fixed
and never silently dropped. Deferred findings belong in the PR description or the
coordinator's ledger.

**The brief never suppresses a real finding.** It excludes work deliberately not
done; it does not excuse defects in the work that *was* done. Security,
**privacy**, data-loss, and correctness problems inside the change are always in scope. If a
finding the brief excluded meets one of the two conditions in
`fx-dev/skills/dev/references/scope-contract.md` § Three filters, filter 1, the
exclusion was invalid — fix the work and correct the brief. Being merely correct
is not one of them.

Persistent out-of-scope noise across passes means the brief is too thin. Tighten
it rather than filtering the same findings by hand every round.

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
- If `cr` reports a **rate limit, quota limit, or cooldown**, stop the CodeRabbit loop immediately. Report the skip once, resolve any blocking findings already returned, and continue to PR creation without requiring a clean rerun.

### Step 2: Resolve every blocking finding

Treat findings like self-review feedback:

- **Triage in the contract's order — scope, then contract, then materiality** (`fx-dev/skills/dev/references/scope-contract.md`). An out-of-scope finding is deferred however material it looks, per the triage rules above; project rules and security/privacy invariants block regardless of the bar; only what remains is ranked. Blocking findings are fixed; immaterial ones — wording, formatting, a count nothing keys on, an entry missing from a list the artifact declares non-exhaustive — go in one closing note and MUST NOT drive another iteration. CodeRabbit's own `🟠 Major` / `🟡 Minor` / `🧹 Nitpick` labels are an input to that judgment, not a substitute for it.
- **Fix real issues** in code and tests; make atomic commits for the fixes.
- **Nitpicks are immaterial by definition, so do not apply them.** They go in the closing note. Applying one produces a commit, and Step 3 then reruns against it — manufacturing the next pass to change something that changes nothing. If a nitpick turns out to clear the bar, it was never a nitpick: fix it as the blocking finding it is.
- **Verify before fixing.** A finding's premise can be wrong. Check any claim it makes about the tree; when it does not hold, reject the finding with the evidence rather than changing working code to satisfy a misreading.
- There are no PR threads to resolve here — this is local. Resolution = the code is fixed (or the finding is a deliberate non-issue).

### Step 3: Re-run until it converges (REQUIRED)

Run `cr review --agent` again after fixes. **Repeat Steps 1 → 2 until no blocking finding is left unresolved** — including any carried from an earlier pass, not merely none new this pass.

**Converged does NOT mean zero output.** Waiting for silence spends full review cycles on wording. Stop when what remains would change nothing if it shipped uncorrected, and list those items once, non-blocking.

- **Cap at 15 iterations** (`fx-dev/skills/dev/references/scope-contract.md` § The iteration bound) — a runaway backstop, not a target. Convergence is the goal; reaching the bound is a failure to converge, and you report it as an escalation rather than a pass. If CodeRabbit keeps flagging the same design decision across two passes, that is a human call, not more code edits — escalate it **by name** and stop, without spending the remaining iterations.
- Watch the shape, and count only what blocks: blocking findings still arriving → keep going; **none left unresolved** → converged, however many immaterial observations it produced; the same disagreement twice → escalate. Converged is the ledger test in `fx-dev/skills/dev/references/scope-contract.md` § Convergence — a quiet latest pass does not discharge a blocker carried from an earlier one.
- **Rate-limit exception:** stop immediately on throttling; do not consume iterations waiting for cooldowns.
- When you stop, report the per-pass trend and whether the last round's fixes were themselves reviewed.

### Step 4: Open the PR when clean or correctly degraded

A **converged** local CodeRabbit review — no blocking finding left unresolved, per `fx-dev/skills/dev/references/scope-contract.md` § Convergence — is preferred before PR creation. A rate-limited review is correctly degraded and does not block PR creation once every blocking finding already received is resolved — the degradation waives the *unrun* remainder of the review, never a finding it already delivered. Do not open the PR with known unresolved blocking findings; immaterial observations travel as a closing note in the PR description.

---

## Mode 2 (FALLBACK): PR-Level Review Wait + Resolve

Use this only when the repo's CodeRabbit GitHub App auto-reviews PRs (it exposes a `CodeRabbit` GitHub check) and you must clear it as a merge gate, or when `cr` was unavailable locally. Cycle until CodeRabbit's check is terminal **and** there are zero unresolved CodeRabbit threads.

### Facts

- CodeRabbit's PR review is **completely independent of CI**. CI passing has NOTHING to do with CodeRabbit.
- CodeRabbit **re-reviews on every push** that changes the PR's head SHA. After you push fixes, the `CodeRabbit` check goes pending again until the new review completes.
- When CodeRabbit is available, wait until its check is terminal and resolve every CodeRabbit thread. If CodeRabbit itself reports rate limiting, report once and skip this optional gate; do not block merge solely on the throttled reviewer.
- **NEVER use raw `gh api repos/.../reviews` or `gh pr view --json reviews` to make merge decisions about CodeRabbit.** Use this skill's bundled script.

### Step 1: Wait for the CodeRabbit Check

CodeRabbit auto-runs — there is **no review-request step**. Run the bundled script **in the FOREGROUND** with `timeout: 1320000` (22 minutes) on the Bash tool call:

```bash
bash [SKILL_BASE_DIR]/skills/coderabbit-review/scripts/wait-for-coderabbit-review.sh <PR_NUMBER>
```

**⚠️ CRITICAL: Run in FOREGROUND — do NOT use `run_in_background`.** Running in the background loses the script output and breaks the cycle.

Script exit codes:
- **Exit 0**: CodeRabbit check reached a terminal state. Output also reports the unresolved-thread count → proceed to Step 2.
- **Exit 1**: Timeout (default 20 min) waiting for the check to settle → STOP. Report: "CodeRabbit check did not settle within 20 min on PR #N." Do not merge unless the output identifies CodeRabbit rate limiting; throttling uses the optional-review exception and may be skipped immediately.
- **Exit 2**: No CodeRabbit check present after a one-cycle grace period → the CodeRabbit GitHub App is not configured for this repo. Report once and proceed without the PR-level gate.
- **Exit 3**: Invalid arguments or gh error → report error to user. If the error specifically identifies a CodeRabbit rate/quota limit, report once and proceed without CodeRabbit.

### Step 2: Resolve Feedback

If the script reports unresolved CodeRabbit threads (count > 0), invoke the rabbit-feedback-resolver:

```
Skill tool: skill="fx-dev:rabbit-feedback-resolver",
            args="<PR_NUMBER> — <Scope Brief verbatim> — dispositions: <thread id> blocking, <thread id> immaterial, <thread id> deferred (<exclusion>)"
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

**Cap the loop at 15 iterations** (`fx-dev/skills/dev/references/scope-contract.md` § The iteration bound) — if CodeRabbit is still posting new blocking feedback at the bound, escalate to the user and say the loop did not converge. Almost always a loop that runs that long means CodeRabbit and the codebase disagree on a design decision that needs human input — which the same-disagreement-twice rule should have caught far earlier. Escalate when you see it, not at iteration 15.

**Hand the resolver the brief and a disposition per thread.** Invoking
`fx-dev:rabbit-feedback-resolver` with only a PR number makes it re-derive triage
it cannot see, and it will edit for threads you classified immaterial or
deferred. Pass `args="<PR_NUMBER> — <Scope Brief verbatim> — dispositions: <thread
id> blocking, <thread id> immaterial, <thread id> deferred (<exclusion>)"`, per
`fx-dev/skills/dev/references/scope-contract.md` § Resolver dispositions.

**Threads must all be resolved, but resolution is not the same as a fix.** An immaterial thread is resolved by replying with the reason it is not being actioned — the gate is zero *unresolved* threads, not zero observations acted on. Re-pushing for another CodeRabbit pass to chase immaterial items is exactly the churn the materiality bar exists to stop.

## Concurrency With Other Reviewers (Mode 2)

Mode 2 can run **in parallel** with `fx-dev:copilot-review` and any future automated-reviewer skills. The SDLC step that gates merge on automated review should:

- Wait for every configured reviewer (Copilot, CodeRabbit, ...) to settle (terminal + 0 unresolved threads each)
- Loop the entire group: any reviewer that re-runs after a push (CodeRabbit always does) re-triggers its waiter → resolver → possibly more commits → other reviewers' waiters, and so on

**⛔ Pick the right execution mode for your context (see `fx-dev:dev` Step 6.3):**

- **Root session / standalone caller** → spawn one sub-agent per reviewer in a single Agent-tool message (mode A — true parallel).
- **`fx-dev:team` coordinator OR a sub-agent yourself** → sub-agents CANNOT spawn sub-agents. Use mode B: invoke each reviewer's wait+resolve lifecycle sequentially, optionally launching this skill's wait script as a background `Bash` process while another reviewer is handled in the foreground.

Never call the Agent tool from inside a sub-agent context.

## Success Criteria

**Mode 1 (local, primary):**
- ✅ `cr review --agent` reports **no blocking findings** after fixes, **or** the service rate-limited and the pass is recorded as `skipped (rate-limited)`. Remaining immaterial observations do not block — they are carried as one closing note, per the materiality bar
- ✅ All blocking findings received before any limit are resolved and committed
- ✅ No cooldown waits or retries remain when the rate-limit exception applies

**Mode 2 (PR-level, fallback / optional merge gate):**
- ✅ CodeRabbit check is terminal with a passing conclusion and all threads are resolved, **or** CodeRabbit rate-limited and the gate is recorded as `skipped (rate-limited)`
- ✅ Any **blocking** findings already received are fixed and pushed. A correct-but-immaterial observation is resolved by reply, not by an edit — editing it reopens the review loop
- ✅ CodeRabbit throttling alone does not block merge
