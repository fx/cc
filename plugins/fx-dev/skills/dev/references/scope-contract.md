# The Scope Contract

Canonical definition of the **Scope Brief**, the **materiality bar**, and the **sprawl stop rule**. All three are mandatory across fx-dev workflow and review skills.

Three failures motivate this document:

1. **Reviewers flagging work nobody asked for.** A reviewer handed a bare diff has no idea what was requested. It reports missing implementation for a docs-only change, missing tests for a spec, or absent dependencies that a later phase adds. Every one of those is noise the operator must hand-filter, and each round of noise costs a full review cycle.
2. **Reviewers never finishing.** A review loop that treats every observation as a finding does not converge: each pass fixes what the last one raised and surfaces a fresh crop of smaller ones. The findings get less important, the passes keep costing the same, and the loop ends only when someone gives up. Scope answers *what to review*; materiality answers *what is worth reporting and when to stop*.
3. **Work quietly outgrowing the request.** A user says "just fix the typo real quick" and gets a refactor. The user's own phrasing is the scope signal, and it is routinely discarded the moment the first sub-agent is launched.

The first and third have the same root cause: the user's original words stop travelling. The Scope Brief makes them travel. The second needs its own rule, below.

## The Scope Brief

Build it **once**, as early as possible — the first skill to act on a user request owns its construction — and thread it verbatim through every downstream sub-agent, skill invocation, and reviewer call.

```markdown
### Scope Brief

- **Verbatim request:** "<the user's own words, quoted exactly>"
- **Interpreted scope:** <what that concretely means: files, subsystems, deliverable>
- **Deliverable type:** <docs | code | spec | research | config | mixed>
- **Explicitly out of scope:** <what must NOT be touched, changed, or flagged>
- **Size signal:** <narrow | normal | open-ended>
- **Known-and-accepted:** <deliberate states a reviewer would otherwise flag>
```

### Field rules

**Verbatim request** — quote, never paraphrase. "just do X real quick" and "implement X" are different instructions and must not collapse into the same summary. If the request spans several messages, quote each. If the user restated or narrowed it mid-run, the narrowed version wins and the earlier one is noted.

**Interpreted scope** — the inference you are acting on, stated plainly so the user can catch a wrong reading in your first report rather than in the final diff.

**Explicitly out of scope** — the highest-value field for reviewers. Anything deliberately not done: phases deferred to later work, files intentionally left stale, dependencies a later change adds, implementation a spec-only change does not include. Without this list a reviewer will rediscover each one as a finding.

**Size signal** — derive from the user's own language:

| Signal | Phrases |
|--------|---------|
| `narrow` | "just", "real quick", "only", "small", "quick fix", "one-liner", "don't overthink", "minimal" |
| `open-ended` | "thoroughly", "comprehensive", "audit", "deep dive", "properly", "refactor", "whatever it takes" |
| `normal` | anything else |

**Known-and-accepted** — deliberate states that look like defects out of context: a failing test tracked elsewhere, a TODO the user asked to leave, an old API kept for compatibility.

## Injecting the brief into reviews

**Every review invocation MUST carry the Scope Brief.** This applies to `fx-dev:codex-review`, `fx-dev:coderabbit-review`, `fx-dev:pr-reviewer`, `/code-review`, `/simplify`, and any sub-agent asked to evaluate work.

- **Skills that accept arguments** — pass the brief as the argument.
- **CLI reviewers that accept a prompt** — pass an OUT OF SCOPE / IN SCOPE prompt built from the brief.
- **Reviewers that accept nothing** (Copilot, CodeRabbit's GitHub App) — the brief cannot reach them. Apply it when **triaging** their findings: an out-of-scope finding is recorded and dismissed with a reason, not fixed.

Translate the brief into reviewer-facing sections:

```
OUT OF SCOPE — do NOT report any of these:
- <each "explicitly out of scope" item, with the reason it is deliberate>
- <each "known-and-accepted" item>
- Anything about files not in this change.

IN SCOPE — review for:
- <what the change is actually meant to accomplish>
- <the quality dimensions that matter for this deliverable type>
```

State the **reason** each exclusion is deliberate. "Do not flag missing tests" invites the reviewer to override you. "This change is spec-only; implementation and its tests are task 2 of change 0007" does not.

**A reviewer invoked without a brief MUST reconstruct one** from the conversation before reviewing, and say that it did. Reviewing a diff with no idea what was asked for is the failure mode this contract exists to prevent — never proceed as if the diff speaks for itself.

**Never use the brief to suppress real findings.** It excludes work that was deliberately not done. It does not excuse defects in the work that *was* done. Security, data-loss, and correctness problems inside the change are always in scope, whatever the brief says. If a reviewer flags something excluded and is *right* — the exclusion was wrong — fix the work and correct the brief.

## The materiality bar

**Of the findings a reviewer originates from its own judgment — that is, what survives the scope and contract filters below — one is worth reporting when acting on it would change what the artifact does, or change how a competent reader acts on it. Everything else is an observation, not a finding.**

This is not a licence to ignore problems. It is a ranking rule: report what clears the bar, and put what does not in one closing note rather than in the blocking list.

### Three filters, in this order

Materiality is the **last** of three, and applying it out of order produces the wrong verdict:

1. **Scope** — is this finding ours at all? An out-of-scope finding is deferred with the exclusion that covers it, **however material it looks in isolation**. A valid improvement to work this change deliberately did not do is still out of scope. Materiality never promotes something back into scope.
2. **Contract** — is it a violation of a project rule, security or privacy invariant, or another mandatory requirement the project wrote down? Those are **blocking by virtue of being rules**, and the bar does not filter them. The project already decided they matter; that decision is not a reviewer's to re-make per finding.
3. **Materiality** — for everything left, which is findings a reviewer originates from its own judgment: does acting on it change anything?

A finding that fails filter 1 is deferred. One that passes filter 2 is blocking. Only what reaches filter 3 is ranked by the bar below.

### The bar

| Tier | Examples | Treatment |
|---|---|---|
| **Material** | Wrong behaviour, data loss, security, a build/CI/test that will fail, a contradiction that makes the artifact unimplementable, a stated fact that is false | Report individually. Blocks convergence. |
| **Substantive** | A genuine ambiguity a reader could act on two ways; a missing step that would be discovered late and cost a cycle | Report individually. Blocks convergence. |
| **Immaterial** | Wording that is merely improvable; a count off by one where nothing keys on the count; a list entry missing from a list nothing enumerates exhaustively; formatting; a synonym that reads better | **One closing note, unnumbered, non-blocking.** Never a separate finding, never a reason for another pass. |

When unsure which tier something is, ask: *if this shipped uncorrected, what breaks?* If the honest answer is "nothing, it is just not as good as it could be", it is immaterial.

### Three things that are not findings

**A missing entry in a list the artifact declares non-exhaustive.** If a document says "for example" or "this list is illustrative; the rule is authoritative", then supplying entry N+1 does not improve it — the rule already covers N+1. Assess whether the *rule* is correct and sufficient. Reporting further missing entries against a declared-open list is the single most common way a review loop fails to terminate, because the supply of such entries never runs out.

**A decision already made, recorded, and reasoned — where the disagreement is about preference.** Once an artifact states a decision with its rationale, including a rationale that says "we do not know, and here is how we will find out", re-arguing it is not a review finding. Say so once as a single escalation; do not re-raise it on the next pass in different words. A preference re-litigated across passes needs a person, not another round.

**But a recorded rationale does not make a decision safe.** If the decision *itself* is the defect — it leaks a credential, loses data, violates a security or privacy invariant, or contradicts a contract the project mandates — it is a **Material finding and stays blocking until resolved**, however carefully it is reasoned. Writing down why you did an unsafe thing does not make it safe. The distinction is whether you disagree with the choice or the choice is wrong: the first is an escalation, the second is a finding.

**An artifact that admits a limit.** "This is verified by X at implementation time", "this is an open question gated on Y" — those are dispositions, not gaps. Check the gate is real and sequenced before the thing that depends on it; do not report the limit itself.

### Convergence

**A review has converged when a pass produces no material or substantive findings — not when it produces zero output.** Zero is usually unreachable and waiting for it burns cycles on immaterial churn.

Track findings per pass and watch the shape, not just the count:

- **Material or substantive findings still arriving, in new categories** — keep going. The review is still working.
- **No material or substantive findings this pass** — converged, whatever the immaterial count did. Stop, and say so: report the trend and what remains below the bar. A pass that falls from five immaterial observations to three *different* immaterial observations has converged; the drop is churn, not progress.
- **The same disagreement in successive passes** — stop. That is a human decision, not a review outcome. Escalate it by name.

Report the trend when you stop, so the operator can see the shape rather than take "clean" on trust: *"Findings per pass: 9, 4, 1, 0 material. Stopping — three immaterial wording items remain, listed below."*

**State honestly what the last pass did not cover.** If you stop after applying fixes that were never themselves reviewed, say so.

## The sprawl stop rule

**When work outgrows the request, stop and tell the user.** Do not silently deliver more than was asked.

### When to stop

Stop when, mid-task, you find the request needs materially more than its own framing implies:

- Subsystems the user never named must change
- A migration, dependency, or breaking change is required
- The work needs several PRs where one was implied
- An architectural decision the user has not made is now unavoidable
- A `narrow` request turns out to need `open-ended` work

### How to stop

Report in two or three sentences: what you found, why it exceeds the request, and the cheapest path forward. Offer the narrow option first. Then wait.

> The typo is in generated output — fixing it properly means regenerating six files and updating the generator's snapshot tests. I can patch just the one visible string instead. Which do you want?

Do **not** stop with nothing done. Deliver everything that is unambiguously in scope, then raise the boundary question about the remainder.

### Calibration — do NOT stop for these

Over-triggering is its own failure. The rule covers work **outside** the request's natural boundary, not work **inside** it:

- Tests for code you just wrote — always in scope
- Docs the change invalidates — in scope
- Fixing a build or test you broke — in scope
- Following an approved spec or change document to completion — in scope, however long it takes
- Reviewer findings classified `required-by-contract` or `regression-caused-by-change` — in scope
- Ordinary multi-step work that a `normal` request plainly implies

**Autonomous long-running skills** (`fx-dev:team`, `fx-dev:workflow-runner`, `fx-dev:yolo`) exist to run unattended for extended periods. For them the trigger is **only** work outside the approved spec, change document, or task list — never mere duration, task count, or effort. A coordinator working through an approved backlog does not stop to ask permission for the next approved task; it stops when a task requires something the contract does not cover.

### Size signal changes the threshold, not the rule

| Size signal | Stop when |
|-------------|-----------|
| `narrow` | The work exceeds the request's literal framing at all. "Just do X real quick" means X, not X and its neighbours. Bias strongly toward stopping. |
| `normal` | The work needs a decision the user has not made, or reaches beyond the named subsystem. |
| `open-ended` | Only for genuine architectural forks or irreversible actions. The user has already authorized depth. |

A `narrow` request carries real weight. "Real quick" is not filler — it is a budget. Honour it, and when you cannot, say so instead of spending it anyway.
