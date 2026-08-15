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

**Never use the brief to suppress real findings.** It excludes work that was deliberately not done. It does not excuse defects in the work that *was* done. Security, **privacy**, data-loss, and correctness problems inside the change are always in scope, whatever the brief says — a brief cannot exclude them, because filter 2 would make them blocking anyway and filter 1 must not get the chance to defer them first. If a reviewer flags something excluded and the exclusion turns out to be invalid — see § Three filters, filter 1, for the only two things that re-open scope — fix the work and correct the brief. Being *correct* is not one of them: a true observation about work the change deliberately did not do stays deferred.

## The materiality bar

**This bar applies to findings a reviewer originates from its own judgment — what survives the scope and contract filters below. Such a finding is worth reporting when acting on it would change what the artifact does, or change how a competent reader acts on it. Everything else is an observation, not a finding.**

This is not a licence to ignore problems. It is a ranking rule: report what clears the bar, and put what does not in one closing note rather than in the blocking list.

### Three filters, in this order

Materiality is the **last** of three, and applying it out of order produces the wrong verdict:

1. **Scope** — is this finding ours at all? An out-of-scope finding is deferred with the exclusion that covers it, **however material it looks in isolation**. A valid improvement to work this change deliberately did not do is still out of scope. Materiality never promotes something back into scope.

   **"The reviewer was right" does not by itself re-open scope.** An excluded observation can be perfectly true — for a docs-only change, "the implementation is absent" is *correct* and still out of scope, because its absence is the exclusion. Only two things pull an item back in: it is a defect in work this change **actually did**, or the exclusion itself was invalid (it excluded something a brief may not exclude, such as a security, privacy, data-loss or correctness problem inside the change). Anything else is deferred with the exclusion cited, no matter how accurate.
2. **Contract** — is it a violation of a project rule, security or privacy invariant, or another mandatory requirement the project wrote down? Those are **blocking by virtue of being rules**, and the bar does not filter them. The project already decided they matter; that decision is not a reviewer's to re-make per finding.
3. **Materiality** — for everything left, which is findings a reviewer originates from its own judgment: does acting on it change anything?

A finding that fails filter 1 is deferred. One that passes filter 2 is a **contract blocker** — blocking on its own terms, and never ranked by the bar. Only what reaches filter 3 is ranked below.

### Blocking — the one term everything else uses

**A finding is BLOCKING if it is any of these three:**

1. **A contract blocker** — it passed filter 2. Unranked by the bar, blocking by virtue of being a rule.
2. **Material** — see the tier table below.
3. **Substantive** — see the tier table below.

**An immaterial finding is never blocking.** That is the whole vocabulary: *blocking* or *immaterial*.

Every downstream rule is written in terms of **blocking**, deliberately. Fix blocking findings; push for blocking findings; keep going while blocking findings arrive; converge when none is left unresolved.

**This generalises, and it is the rule that keeps this document workable: every normative rule here is defined once and referenced, never restated.** That covers the blocking definition, the convergence test, the iteration bound, the two conditions that re-open scope, and the resolver dispositions below. A skill that paraphrases one of them creates a copy that goes stale the moment the original changes — and a stale copy is always the *narrower* one, so it under-blocks, under-converges, or re-opens scope it should not. Name the rule and link the section. If a skill genuinely needs different behaviour, change it here, for everyone.

**One exception, and only one: text sent verbatim to an external tool.** A prompt handed to `codex review`, `cr`, or any reviewer outside this repo cannot follow a link, so it MUST inline the rule. Such a block is a **mirror**: mark it as one, keep it a faithful restatement of the canonical section rather than an independent edit, and update it in the same commit that changes the canonical text. Nothing an agent reads directly qualifies — only strings crossing a process boundary.

### Resolver dispositions

Every finding handed to a resolver carries exactly one, and they are defined here so no resolver invents a fourth:

- **`blocking`** — fix it and push. See § Blocking.
- **`immaterial`** — reply with the reasoning and resolve. **No edit**: a fix push reopens the review loop for something that changes nothing.
- **`deferred`** — reply citing the exclusion that covers it and resolve. **No edit**, and never widen the change to satisfy it.

**A disposition assigned by the coordinator is authoritative and overrides a resolver's own categorisation.** The coordinator holds the Scope Brief and the ledger; a resolver classifying from the comment text alone does not, and its local heuristics — a `[nitpick]` prefix, a tracker-update path — must not override a disposition set with that context.

### The bar

| Tier | Examples | Treatment |
|---|---|---|
| **Material** | Wrong behaviour, data loss, security, a build/CI/test that will fail, a contradiction that makes the artifact unimplementable, a stated fact that is false **and that a reader would act on** | Report individually. **Blocking.** |
| **Substantive** | A genuine ambiguity a reader could act on two ways; a missing step that would be discovered late and cost a cycle | Report individually. **Blocking.** |
| **Immaterial** | Wording that is merely improvable; a count off by one where nothing keys on the count; a list entry missing from a list nothing enumerates exhaustively; formatting; a synonym that reads better | **One closing note, unnumbered, non-blocking.** Never a separate finding, never a reason for another pass. |

When unsure which tier something is, ask: *if this shipped uncorrected, what breaks?* If the honest answer is "nothing, it is just not as good as it could be", it is immaterial.

**When two rows both seem to fit, that question decides it — reader impact, not the category label.** A document that says "four steps" above five steps is both a false stated fact and a count nothing keys on; it is **immaterial**, because no reader acts on the number. The same document saying a command takes `--base` when it rejects `--base` is **material**, because a reader will run it and it will fail. The falsehood is not what makes a finding material; acting on the falsehood is.

### Three things that are not findings

**A missing entry in a list the artifact declares non-exhaustive.** If a document says "for example" or "this list is illustrative; the rule is authoritative", then supplying entry N+1 does not improve it — the rule already covers N+1. Assess whether the *rule* is correct and sufficient. Reporting further missing entries against a declared-open list is the single most common way a review loop fails to terminate, because the supply of such entries never runs out.

**A decision already made, recorded, and reasoned — where the disagreement is about preference.** Once an artifact states a decision with its rationale, including a rationale that says "we do not know, and here is how we will find out", re-arguing it is not a review finding. Say so once as a single escalation; do not re-raise it on the next pass in different words. A preference re-litigated across passes needs a person, not another round.

**But a recorded rationale does not make a decision safe.** If the decision *itself* is the defect — it leaks a credential, loses data, violates a security or privacy invariant, or contradicts a contract the project mandates — it is **blocking and stays blocking until resolved**, however carefully it is reasoned. Which kind of blocking follows the filters, and you do not need to decide it to act: where it violates a rule the project wrote down it is a contract blocker at filter 2; where it is your own reading of a defect it is Material at filter 3. Both block, so the disposition is identical. Writing down why you did an unsafe thing does not make it safe. The distinction is whether you disagree with the choice or the choice is wrong: the first is an escalation, the second is a finding.

**An artifact that admits a limit.** "This is verified by X at implementation time", "this is an open question gated on Y" — those are dispositions, not gaps. Check the gate is real and sequenced before the thing that depends on it; do not report the limit itself.

### Convergence

**A review has converged when a pass produces no unresolved blocking findings — not when it produces zero output.** Zero is usually unreachable and waiting for it burns cycles on immaterial churn.

Track findings per pass and watch the shape, not just the count:

- **Blocking findings still arriving, in new categories** — keep going. The review is still working.
- **No blocking finding left unresolved** — converged, whatever the immaterial count did. Note the test is *unresolved*, not *new*: a blocker carried from an earlier pass still blocks even if this pass did not repeat it, and a finding that produces no thread (a suppressed Copilot item) is never discharged by a thread count. Track them and clear the list. Stop, and say so: report the trend and what remains below the bar. A pass that falls from five immaterial observations to three *different* immaterial observations has converged; the drop is churn, not progress.
- **The same disagreement in successive passes** — stop. That is a human decision, not a review outcome. Escalate it by name.

Report the trend when you stop, so the operator can see the shape rather than take "clean" on trust: *"Findings per pass: 9, 4, 1, 0 blocking. Stopping — three immaterial wording items remain, listed below."*

**A rising count is a divergence signal, not progress.** If a pass produces more blocking findings than the one before it and they are all the same class, the last round's fix is generating them. Stop and address the cause rather than the instances — and if the cause is a design choice with two defensible answers, that is an escalation to the user, not another pass.

**State honestly what the last pass did not cover.** If you stop after applying fixes that were never themselves reviewed, say so. A loop that stops at the bound below has *not* converged, and reporting it as clean is a false result.

### The iteration bound

**Convergence is the goal. The bound is a runaway backstop, not a target, and reaching it is a failure to converge — never a stopping condition you are entitled to treat as success.**

**Every review-convergence loop caps at 15 iterations.** That is the single number; skills MUST NOT set their own. It is deliberately far above what a healthy loop needs — a review that is working converges in single digits — so that hitting it means something is wrong rather than that the work was merely large.

A loop should almost always end on one of the three signals above, all of which fire long before 15:

- **Converged** — no blocking finding left unresolved, per § Convergence above. The only successful exit. Note that is the *ledger* test, not a property of the latest pass: a quiet pass with a carried blocker still open is not convergence.
- **The same disagreement twice** — escalate by name. Do not spend the remaining iterations re-arguing it.
- **A rising count of one class** — the last fix is generating them. Fix the cause, or escalate the design choice.

Those exits are what keep the loop short; the bound only catches a loop none of them caught. **Do not treat the headroom as licence to keep going** — an iteration that fixes only immaterial items is churn whether it is the 3rd or the 13th, and the convergence rule already forbids it.

When you stop at the bound, say so explicitly, report the per-pass trend, name what is still unresolved, and hand it to the user. "Reached 15 iterations" is an escalation, not a pass.

**Cost is real and worth stating.** A single reviewer pass on a substantial branch can take ten minutes or more, so an unattended loop that actually runs to 15 can consume hours. That is the intended trade — correctness over speed — but it is a reason to fix causes rather than instances, not a budget to spend.

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
