---
name: coderabbit-review
description: "Run CodeRabbit's optional AI review. PRIMARY path: run it LOCALLY via the `cr` CLI before opening a PR and resolve blocking findings. FALLBACK path: wait for + resolve its automated PR review when available. Pass a Scope Brief as args — findings MUST be triaged against the user's original request. Rate limits degrade gracefully: report once, skip CodeRabbit, and continue the SDLC."
---

# CodeRabbit Review

**⛔ Load `fx-dev:review` first** (Skill tool: `skill="fx-dev:review"`). It is the
canonical review procedure — carrying the Scope Brief, triaging in filter order,
sweeping a class, converging, reporting. This skill is the **CodeRabbit adapter**:
the `cr` CLI, the GitHub App's check and threads, and the rate-limit exception.
Where the two appear to disagree, `fx-dev:review` wins.

CodeRabbit runs two ways, and **local is primary**:

| | How | When |
|---|---|---|
| **Mode 1** | `cr` CLI, on local changes | Pre-PR self-review (`fx-dev:dev` Step 4.5) |
| **Mode 2** | GitHub App's `CodeRabbit` check + review threads | Fallback merge gate, or when `cr` was unavailable |

## Arguments

- **Mode 1** — the Scope Brief. No PR number; it reviews the working tree/branch.
- **Mode 2** — `args='<PR_NUMBER> — <Scope Brief verbatim>'`.

## How the brief reaches CodeRabbit

**Mode 1 can be handed it. Mode 2 cannot.**

`cr review` takes `-c, --config <files...>` — "Additional instructions for
CodeRabbit AI". Write the brief to a file and pass it, so Mode 1 is a
prompt-capable reviewer and the brief reaches it *before* the review rather than
only at triage. This is the external-mirror case in
`fx-dev/skills/dev/references/scope-contract.md` § Blocking, which names `cr`
explicitly: the file crosses a process boundary and cannot follow a link, so it
inlines what it needs and is kept a faithful mirror.

```bash
# The brief, plus the BLOCKING block, as instructions cr reads before reviewing.
cr review --agent -c /tmp/scope-brief.md
```

**Mode 2's GitHub App cannot be addressed at all**, so there the brief is applied
**entirely at triage** (`fx-dev:review` Steps 1–2). Judge a Mode 2 run on triage
coverage, not on how few out-of-scope findings it produced — that signal does not
exist for a reviewer that never saw the brief (`fx-dev:review` Step 8).

CodeRabbit's `🟠 Major` / `🟡 Minor` / `🧹 Nitpick` labels are an **input** to
triage, never a verdict.

## ⛔ CodeRabbit is optional when rate-limited

If the CLI, API, GitHub check, or wait script reports a CodeRabbit quota/rate
limit: report it once and continue without CodeRabbit. Do not sleep, poll, retry
after a cooldown, ask the user to wait, or block PR creation/merge on CodeRabbit
throttling alone. Do not consume convergence iterations waiting for a cooldown.

**Throttling waives only the review passes that never ran — never anything
already delivered.** Before recording the skip:

- fix every blocking finding CodeRabbit already returned, and
- in Mode 2, settle *every* thread it already posted — immaterial and deferred
  ones included — by replying and resolving.

Skipping that leaves an open conversation behind a gate that requires zero
unresolved CodeRabbit threads, so the "degraded" PR is still blocked.

Only then mark the pass `skipped (rate-limited)`. This exception applies to
CodeRabbit alone; it does not relax Copilot, CI, tests, or other merge gates.

---

## Mode 1 (PRIMARY): local pre-PR review via `cr`

### The `cr` CLI

Run `cr --help` / `cr review --help` for the full surface. Key usage:

- **`cr review --agent`** — reviews tracked changes and emits **structured
  findings for agent workflows**. Use this; bare `cr` or `cr review` prints a
  plain-text review.
- **`cr review -c, --config <files...>`** — additional instructions for the AI.
  This is how the Scope Brief reaches Mode 1; see above.
- `cr review --base <branch>` / `--base-commit <commit>` — what to compare against.
- `cr review --committed` / `--uncommitted` / `--include-untracked` — scope by
  change state. There is **no** `--type` flag; verified against `cr review --help`.
- `cr review --dir <path>` — restrict to changes inside one directory.
- `cr review --light` — a lighter review with reduced context work.
- `cr review findings` — reprint the previous run's findings, without reviewing.
- `cr doctor` — check installation / readiness (read-only, safe).

Run `cr review --help` before using a flag this list does not name.

**⛔ NEVER run `cr auth login`** or any interactive `cr auth …`. If `cr` reports
it is not authenticated, STOP and report to the user.

### Running it

Run in the **FOREGROUND**, passing the brief as instructions:

```bash
cr review --agent -c /tmp/scope-brief.md
```

Add `--base main` to scope to the branch's diff. Without `-c` the review is
unscoped and will report the work you deliberately did not do.

- **Not authenticated** → STOP and report; do not work around it.
- **Not installed / unavailable** → skip to Mode 2 (resolve at the PR level after
  opening) and report this to the user once.
- **Rate limit / quota / cooldown** → the exception above.

### Resolving and re-running

`fx-dev:review` Steps 2–7, with one local peculiarity: **there are no threads
here.** Resolution means the code is fixed, or the finding is a recorded
non-issue, and an immaterial observation goes straight into the closing note. A
fix is an atomic commit; re-run `cr review --agent` against it.

### The gate

Open the PR once the local review has **converged** — no blocking finding left
unresolved (`fx-dev/skills/dev/references/scope-contract.md` § Convergence) — **or
is correctly degraded as `skipped (rate-limited)`** with everything already
delivered resolved. Immaterial observations travel as a closing note in the PR
description.

A converged local review does not remove the merge gates, but it usually means
the PR-level review lands with nothing blocking on the first pass.

---

## Mode 2 (FALLBACK): PR-level wait + resolve

Use only when the repo's CodeRabbit GitHub App auto-reviews PRs (it exposes a
`CodeRabbit` check) and you must clear it as a merge gate, or when `cr` was
unavailable locally.

### Facts

- CodeRabbit's PR review is **completely independent of CI**. CI passing has
  nothing to do with CodeRabbit.
- CodeRabbit **re-reviews on every push** that changes the head SHA — unlike
  Copilot, it needs no nudge. After you push, the check goes pending again.
- **NEVER use raw `gh api repos/.../reviews` or `gh pr view --json reviews` to
  make merge decisions about CodeRabbit.** Use this skill's bundled script.

### Step 1: Wait for the check

CodeRabbit auto-runs — there is **no review-request step**. Run the bundled script
in the **FOREGROUND** with `timeout: 1320000` (22 minutes) on the Bash call:

```bash
bash [SKILL_BASE_DIR]/skills/coderabbit-review/scripts/wait-for-coderabbit-review.sh <PR_NUMBER>
```

**⚠️ Do NOT use `run_in_background`** — that loses the script output and breaks
the cycle.

Exit codes:

- **0** — check reached a terminal state; output reports the unresolved-thread
  count → Step 1b.
- **1** — timeout (default 20 min) → STOP. Report "CodeRabbit check did not settle
  within 20 min on PR #N." Do not merge unless the output identifies rate
  limiting, which takes the exception above.
- **2** — no CodeRabbit check after a grace period → the App is not configured.
  Report once and proceed without the PR-level gate.
- **3** — invalid arguments or `gh` error → report. If it identifies a rate/quota
  limit, take the exception.

### Step 1b: Fetch the threads and triage them

**The waiter emits a count, not the threads**, and Step 2 hands the resolver a
disposition per thread — a count cannot be triaged. Fetch the bodies, then run
`fx-dev:review` Steps 2–3 over them.

```bash
# Replace OWNER, REPO, PR_NUMBER with actual values (GraphQL body — no shell expansion here)
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          path
          line
          comments(first: 10) { nodes { author { login } body } }
        }
      }
    }
  }
}' --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and (.comments.nodes[0].author.login | tostring | contains("coderabbitai")))]'
```

Assign one of `blocking`, `immaterial`, or `deferred` to each thread **that
carries a finding**. Yours is authoritative — you hold the Scope Brief; the
resolver does not. A thread whose premise fails gets **no** disposition; list it
with the reason so the resolver's outdated/incorrect handler takes it
(`fx-dev:review` Step 3).

### Step 2: Hand it to the resolver

```
Skill tool: skill="fx-dev:rabbit-feedback-resolver",
            args="<PR_NUMBER> — <Scope Brief verbatim> — dispositions: <thread id> blocking, <thread id> immaterial, <thread id> deferred (<exclusion>) — false premise (resolver's own handler): <thread id> (<what does not hold>)"
```

**Both suffixes are mandatory.** Invoking the resolver with only a PR number makes
it re-derive triage it cannot see, and it will edit for threads you classified
immaterial or deferred. The false-premise suffix is what routes a thread Step 1b
rejected to the outdated/incorrect path instead of a re-triage that loses the
`REVIEW.md` entry.

### Step 3: Loop until settled

CodeRabbit re-reviews after every push, so once Step 2 pushes fixes the check goes
pending again — go back to Step 1. Per `fx-dev:review` Step 7, repeat Steps
1 → 1b → 2 until **all three** hold:

1. The most-recent `CodeRabbit` check is terminal with conclusion `success` (or
   `skipped` / `neutral` if the repo configures it that way).
2. Zero unresolved CodeRabbit threads.
3. **No blocking finding is left unresolved, across every pass** — the ledger test
   (`fx-dev/skills/dev/references/scope-contract.md` § Convergence). Conditions 1
   and 2 describe the latest check; this one describes the ledger. A blocker an
   earlier pass raised and this one did not still blocks, and resolving its thread
   does not discharge it: a thread is closed by a reply, a blocker only by a fix.

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

Two of the three are observable from the API; the third is yours to track, and it
is the one a zero count cannot stand in for.

## Concurrency with other reviewers (Mode 2)

Mode 2 can run **in parallel** with `fx-dev:copilot-review`. The SDLC step gating
merge on automated review should wait for every configured reviewer to settle —
terminal, zero unresolved threads, **and no blocking finding left unresolved**,
for each — and loop the whole group: any reviewer
that re-runs after a push re-triggers its waiter → resolver → possibly more
commits → the other reviewers' waiters.

**⛔ Pick the right execution mode (see `fx-dev:dev` Step 6.3):**

- **Root session / standalone caller** → one sub-agent per reviewer, in a single
  Agent-tool message (mode A, true parallel).
- **`fx-dev:team` coordinator, or you are a sub-agent** → sub-agents cannot spawn
  sub-agents. Mode B: each reviewer's lifecycle sequentially, optionally running
  this skill's wait script as a background `Bash` process while another reviewer
  is handled in the foreground.

Never call the Agent tool from inside a sub-agent context.

## Success criteria

**Mode 1:** no blocking finding left unresolved across all passes — or the
rate-limited path, where everything already delivered is resolved and the pass is
recorded `skipped (rate-limited)`. Remaining immaterial observations travel as one
closing note.

**Mode 2:** all three of Step 3's conditions — the check terminal with a passing
conclusion, zero unresolved CodeRabbit threads, **and no blocking finding left
unresolved across every pass**. The third is not implied by the first two: a
thread is closed by a reply, a blocker only by a fix, so a passing check over a
resolved-but-unfixed blocker is not settlement. Or CodeRabbit rate-limited,
**every thread it had already delivered is settled**, and the gate recorded
`skipped (rate-limited)`. Throttling alone never blocks merge.
