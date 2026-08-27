# Agent Token Consumption in Multi-Agent Runs

*Research note — 2026-08-27. Analysis of two `fx-dev:team` runs that consumed
extreme token volumes, the diagnosis, and the agreed remediation plan.*

## Overview

Two multi-agent `fx-dev:team` runs were profiled from local session transcripts
after they consumed unexpectedly large token volumes. This note records what was
measured, what the measurements actually mean, which hypotheses survived scrutiny
and which did not, and the remediation decisions that followed.

The headline conclusion: **turn count is very nearly the only lever.** Context in
a long agentic loop is dominated by the agent's own accumulated reasoning and
tool-call blocks, not by the size of the data it reads. Every proposed fix should
therefore be scored by how many model turns it removes, not by how many bytes it
trims.

Scope boundaries:

- **In scope:** token accounting methodology, the cost model of an agentic loop,
  the measured behaviour of the two runs, root-cause ranking, and the remediation
  decisions.
- **Out of scope:** the implementation of those remediations (each will land as
  its own change), and the quality or correctness of the code the runs produced.

All project-identifying detail — repository names, task names, and source file
paths — has been genericised. Agents are referred to as Coder 1..N.

## Background

The operator is on a **subscription plan**, not per-token API billing. This
matters for how the numbers should be read: consumption drives usage-limit
exhaustion, so the optimisation target is **total tokens processed**, not dollars.
An earlier framing of these findings converted everything to API dollars and
concluded the problem was ~10x smaller than it looked; that conversion is
retained below as reference, but it is **not** the operative metric here.

## Accounting methodology and caveats

### Deduplication

Naïvely summing every assistant record in the session transcripts yields ~1.1B
tokens for Run A. Streamed responses repeat under the same message ID, so usage
must be counted once per message ID. The deduplicated figure is ~684.4M, and that
is the defensible call-level total. **The gap is ~38%**, which is large enough
that the method deserves independent validation.

> **Open item.** Every figure in this note derives from local transcripts and has
> not been reconciled against the provider's own usage reporting. Before any
> figure here is used as a baseline to measure improvement against, it should be
> checked against ground truth. A 15% method error would reorder some of the
> per-session rankings.

### The "associated tokens" metric

Several tables below attribute tokens to a category of tool call (tests, polling,
git inspection). This means *the context size carried by model turns issuing that
kind of call* — not the cost of the shell command itself.

**These categories are not additive and not independently removable.** They sum
to the run total because they are the same accumulated context re-sliced. So
"eliminating polling saves 142M" is not a valid reading.

The metric errs in the useful direction, though: removing a turn saves its own
context *and* shrinks every later turn's context by that turn's output. Turns
occurring early in a run compound hardest. The true saving from removing a class
of turn is therefore **larger** than its attributed figure, not smaller.

### Cross-provider blind spot

External reviewers (Codex, CodeRabbit) run their own models. Their consumption
appears nowhere in these totals. Actual cross-provider consumption is higher than
anything recorded here.

## The cost model

Cost in an agentic loop is Σ(context size) over calls. Nothing else. With `c₀` as
the starting context and `g` as average growth per turn:

```
total ≈ Σᵢ (c₀ + g·i) = N·c₀ + g·N²/2
```

Three consequences drive everything below:

1. **It is quadratic in turn count.** Halving `g` halves the quadratic term;
   halving `N` quarters it. Turn count is the stronger lever.
2. **A hard context cap converts quadratic to linear.** With cap `C`, total ≤
   `N·C`. This is the real argument for context handoffs — not the raw saving, but
   the change in growth class.
3. **High cache-read share is arithmetic, not pathology.** A 95–97% cache-read
   share is what Σ(context) looks like. Under API billing it represents the
   *savings* from caching, not the problem. Under a subscription it is simply the
   metric.

## Measured data

### Run A — single feature implementation, 10 sessions

~684.4M deduplicated tokens. 665.0M (97.2%) cache reads; 1.27M output.

| Session | Tokens | Share |
|---|---|---|
| Coordinator | 228.8M | 33.4% |
| Coder 1 | 203.1M | 29.7% |
| Coder 2 | 138.8M | 20.3% |
| Coder 3 | 64.8M | 9.5% |
| Remaining six agents | 48.9M | 7.1% |

- Coordinator lived ~18.5 hours; context grew 62k → 714k.
- Coder 1 hit 200k within seven minutes, finished at 717k. Of 463 API calls, 431
  exceeded 200k and 103 exceeded 600k.
- Coordinator made 421 Bash calls, 37 edits, 22 reads.
- The session was reused across three distinct phases: implementation, then
  production debugging, then a separate spec/docs task. The docs phase alone cost
  29.5M because each of its 43 calls carried an average 686k context.

### Run B — broad "implement all pending changes and specs" request

19 sessions, 4,609 model calls, ~1.842B tokens. Average context 399k.

| Session | Tokens | Avg context | Max |
|---|---|---|---|
| Coder 1 | 337.9M | 555k | 966k |
| Coder 2 | 334.2M | 565k | 939k |
| Coder 3 | 320.3M | 529k | 969k |
| Coordinator | 181.6M | 369k | 672k |
| Coder 4 | 135.4M | 413k | 627k |
| Coder 5 | 113.2M | 370k | 612k |
| Coder 6 | 108.4M | 358k | 580k |

The top three coders alone: 992.3M. Each reached 200k within 7–16 minutes, then
continued for hundreds of calls (608 / 591 / 605 calls; 275 / 285 / 254 of them
above 600k context).

Across the surrounding two-day window: ~2.241B deduplicated tokens total — 2.147B
cache reads (95.8%), 89.0M cache writes, 5.0M output, 12.7k fresh input.

### Tool-call inventory (Run B)

4,854 unique tool calls:

| Tool | Calls |
|---|---|
| Bash | 3,312 |
| Edit | 552 |
| Read | 363 |
| Status updates | 211 |
| SendMessage | 155 |
| Write | 133 |
| ToolSearch | 70 |
| Skill | 35 |
| Agent creation | 18 |

Bash calls by purpose:

| Purpose | Calls | Associated tokens |
|---|---|---|
| Tests and validation | 1,051 | 522.9M |
| File/code inspection | 775 | 307.2M |
| Review convergence | 398 | 163.8M |
| Git/PR inspection | 365 | 141.9M |
| Git/PR mutations | 327 | 132.7M |
| Waiting and polling | 326 | 142.2M |
| Setup/runtime | 69 | 25.5M |

Observation-to-mutation ratio: ~1,829 pure-observation calls (inspection + git
inspection + polling + Read) against ~1,012 productive calls (Edit + Write + git
mutations). **The run spent 1.8 turns looking for every turn doing.**

## The decisive measurement

**Tool results totalled ~6.9M characters across 4,854 calls — about 1,400
characters per call.** That is roughly 1.9M tokens of tool output in a 1.842B
token run. Reads contributed a further 3.0M characters (~750k tokens).

Tool output is therefore *not* what fills these context windows.

Working out what does: 5.0M output tokens / 4,609 turns ≈ **1,085 tokens of model
output per turn**. For a coder at 608 turns that is ~660k of its own accumulated
output and reasoning, against a 966k observed maximum. Adaptive thinking is on by
default on the model in use, and thinking blocks must be echoed back unchanged
when continuing on the same model — so they sit in the resent prefix and are
billed on every subsequent turn.

**Roughly 60–70% of a mature coder's context is its own prior output.**

This reframes the entire remediation set. Trimming reads, batching edits, and
shortening command output all target the small term. Only removing turns — and
reducing how much each turn generates — touches the large one.

## Root causes, ranked

### 1. Sleep-based polling (strongest finding)

326 waiting/polling commands, of which 232 explicitly invoked `sleep`, requesting
**17.34 aggregate hours** of sleep across parallel agents.

The coordinator alone: 179 wait/poll calls, 144 git/PR inspection calls, 37 direct
review calls, and only 15 validation and 15 file-inspection calls. Most of its
activity was waking, re-reading a large context, checking state, and sleeping
again. Each poll turn pays full context and adds to it — a poll loop is
quadratically self-defeating.

**This is not a discipline problem.** The coordinator has N concurrent workers and
M open PRs and no primitive that blocks on "any of these changed". Sleep-check-
sleep was the only thing available to it. A rule forbidding polling, without a
replacement primitive, would be ignored exactly as the convergence rules were
(see below).

### 2. Reviewer passes were unbounded in practice

136 Codex launches, 96 CodeRabbit launches, 81 Copilot wait-script calls, 181
commands described as convergence passes, and hundreds more reading reviewer
output — across 32 PRs. That is **~10 reviewer invocations per PR**.

Critically, **the rules to prevent this already exist and were ignored**:

- `plugins/fx-dev/skills/dev/SKILL.md:326-330` — rerun a reviewer only when the
  delta touches its risk area; "Do not restart the full matrix merely because
  `HEAD` changed."
- `plugins/fx-dev/skills/dev/SKILL.md:322` — fix the class, not the instance.
- `plugins/fx-dev/skills/review/SKILL.md:264` — the iteration bound is "a runaway
  backstop, not a target."

Adding a further prose rule will produce the same outcome. The bound has to be
something an agent cannot exceed.

Reviewer rounds also carry a large multiplier: each drags validation runs, a
commit, a push, and often a rebase behind it. Round reduction is worth roughly
3–4x its direct turn count.

### 3. Validation frequency (not redundancy)

1,110 validation calls across 32 PRs — **~35 per PR**: 423 umbrella `check` runs,
439 test-run commands, 248 typechecks, 64 lint/format, 34 build/package.

A targeted measurement was run to test the "massively repeated validation"
hypothesis. Of the 423 umbrella runs:

| Outcome | Count |
|---|---|
| Confidently green | 270 |
| Visibly failed | 40 |
| Ambiguous (exit status masked by `grep`/`head`/`tail`) | 113 |
| **Redundant confirmed-green rerun** (green again, no file change since last green) | **109** |

Sensitivity band: 31 if git operations (rebase/merge/checkout/reset) also
invalidate a prior green result; 165 if only direct `Edit`/`Write` counts as a
change. 109 is the defensible midpoint and is conservative — none of the 113
ambiguous runs were counted.

**109 turns ≈ 56.8M tokens ≈ 2.4% of turns and 3.1% of the run.** The
"massively repeated validation" framing was *overstated*; by its own strictest
test it is a moderate contributor.

The real problems the redundancy test could not see:

- **270 confirmed-green umbrella runs / 32 PRs = 8.4 per PR.** A green check after
  a rebase, a comment fix, or a nit in an unrelated file also tells you nothing —
  it just doesn't trip a "no file change at all" test. Target is 2–3 per PR, so
  ~170–200 are removable, not 109.
- **248 typechecks alongside 423 umbrella runs.** If the umbrella script includes
  the typecheck — it does — most of those are the same work in a separate turn.
  Each individual run looks justified; the waste is running three commands to
  answer one question. ~200 turns.

Revised estimate: ~450–500 removable validation turns, from *frequency and
decomposition*, not from the strict-redundancy case.

### 4. Unreadable validation results (correctness bug)

**113 of 423 umbrella runs (27%) had their exit status masked** by piping through
`grep`/`head`/`tail`. The agents could not tell whether their own validation
passed.

This is the one finding with a consequence beyond tokens. It is also plausibly
*causing* reruns, since the cheapest response to an unreadable result is to run it
again.

> **Cheap follow-up measurement:** count how often an ambiguous run is followed by
> another run of the same command with no intervening edit. If that is a
> meaningful share of the 109, ambiguity is manufacturing the redundancy and
> fixing the pipe habit fixes both.

### 5. PR granularity and git churn

212 commits, 127 pushes, 101 rebases, 32 PR creations, 33 merge commands, 407
diff/show inspections, 457 status/log inspections, 140 PR/check views.

**3+ rebases per PR.** An instruction to keep PRs "as small as possible" produced
many parallel dependent branches; every merge forced additional rebases, checks,
review passes, and force-pushes.

### 6. Self-inflicted reporting overhead

**211 status updates and 155 SendMessages = 366 turns**, ~8% of the run, at ~400k
context each. These exist because the operator's global instructions mandate
*granular* per-step status reporting. Reporting on phase transitions instead
removes ~150 turns for no loss of signal. This cost originates in operator
configuration, not in the team skill.

### 7. Fragmented reads and edits (smallest term)

552 Edit calls, 133 Write calls, 775 shell inspection calls, 363 Reads (~3.0M
characters). Files re-read whole across agents and worktrees; the heaviest was
read 13 times.

At ~750k tokens total for all reads combined, **eliminating reads entirely is
noise against 1.842B.** The only version that matters is cross-agent duplicate
exploration — several agents independently rediscovering the same files.

## Findings that did not hold up

Recorded so they are not re-derived later.

**"The coordinator violated the skill's lightweight-coordinator rule."** False.
`fx-dev:team` says the coordinator must not *implement*; it does not say
"lightweight". It explicitly **requires** the coordinator to personally run
Copilot review, CodeRabbit, feedback resolution, `gh pr checks --watch`, PR diff
inspection, worktree creation, and merge gates (`team/SKILL.md:208, 210, 256,
363-365`), and **forbids** delegating reviewer waits because teammates cannot
spawn teammates. The 421 Bash calls are the design working as written. This cannot
be fixed by a behavioural instruction; the coordinator's context is structurally
O(tasks × SDLC steps) with no delegation escape hatch.

**"Clipping every call to 200k would have saved ~1.0B tokens."** This is a ceiling,
not an estimate. Context cannot be clipped without changing what work gets done; a
cap forces handoffs, and each handoff re-reads files, re-derives state, and adds
turns.

That said, **the cap itself is sound and the break-even is overwhelming**: a
handoff costs ~40k of re-context once, while an uncapped agent pays its bloat on
every remaining turn. Spending 40k to avoid 200 later turns averaging 700k instead
of 350k saves ~70M.

**"Opus-tier accounted for 94.6% of the run."** Near-vacuous — it is the default
model. The actionable claim is per-role model and effort assignment.

**"Validation was massively repeated" (as the leading finding).** Measured at
2.4% of turns. Real but moderate; see §3.

## Remediation decisions

Agreed 2026-08-27. Ordering is by turns removed, weighted by how much each depends
on agent compliance (less dependence is better — the convergence rules prove that
prose rules get ignored).

**Shipped in fx-dev 4.0.0:** D1 (background waits, uniform 900 s wall-clock budgets,
four-state `STATUS=` protocol across all three waiters), D2 as role-based model
sizing, and a Codex review script. Local CodeRabbit (`cr`) was removed entirely in
the same change — Codex is now the only local reviewer, and CodeRabbit is PR-level
and optional, reporting `NOT_CONFIGURED` terminally in ~30 s where its App is absent.
The waiter-delegation layer was evaluated and rejected; see below. **D3–D8 remain
open.**

Two defects were found and fixed while implementing D1, neither of which appears in
the analysis above:

- **Two of the three waiters could never reach their own timeouts.** The CodeRabbit
  waiter budgeted 1200 s and the CI waiter 900 s, but both were invoked in the
  foreground where the Bash tool caps `timeout` at 600 s. They were killed mid-poll
  with no exit code and no output, and callers then re-ran them blindly. This is a
  direct mechanical cause of the 96 CodeRabbit launches — not agent behaviour.
- **Both also counted elapsed time by summing `sleep` intervals rather than wall
  clock**, the same defect the Copilot waiter documents having fixed for itself
  (it understated real elapsed time by 40–110 s per run, because each poll also
  spends network round-trips).

### D1 — Replace all waiting with background-and-notify *(accepted; highest priority)*

The notify mechanism postdates the original wait scripts, which is why they were
written as blocking foreground waits.

- `run_in_background: true` on Bash re-invokes the agent when the process exits.
  **All CI/reviewer wait scripts move to background.**
- **Every wait script gets a hard internal `timeout`** with a distinguishable
  timed-out exit code. A script that always terminates cannot wedge. This is the
  primary defence — better than coordinator-side detection because it fixes the
  problem at the source.
- **Reconcile-on-wake, not on a timer.** Any arriving notification triggers *one
  batched state check across all tracked work* — all PRs, all workers, one pass.
  While anything is in flight, stall detection costs zero dedicated turns.
- **One backstop for total silence.** The only case reconcile-on-wake misses is
  everything going quiet at once. Use `ScheduleWakeup` rather than a sleeping Bash
  call, at a long interval. This should be the only time-based construct in the
  run.
- **A ledger file on disk** tracking every worker and PR and its last known state,
  so reconciliation is a cheap diff rather than a re-derivation.

Expected: ~326 polling turns → ~30. Stall recovery becomes *better* than today,
where a wedged script inside a foreground wait blocks the coordinator indefinitely
with no detection at all.

This subsumes the separate concern about the run stalling when subagents fail to
report in.

### D2 — Model and effort tiering per role *(accepted, replacing "context editing")*

The original proposal was API-level context editing (`clear_thinking_20251015`,
`clear_tool_uses_20250919`) to strip stale reasoning from history. **No Claude Code
setting exposes this** — the harness offers compaction, not context-editing knobs.
Treat as unavailable unless proven otherwise.

The available lever does the same job upstream. `effortLevel` in `settings.json`
(currently `high` in the observed environment) controls **how much reasoning is
generated in the first place** — which is precisely the material that then gets
resent on every subsequent turn. Lowering effort on a mechanical agent flattens
the growth curve for the rest of that agent's life; it attacks the quadratic term,
not just the per-turn cost.

Per-agent `model` **and** reasoning effort come from agent-definition frontmatter
(`.claude/agents/*.md`); the Agent tool also takes a `model` override directly. So
define explicit agent types per role rather than spawning generic teammates that
inherit the session's defaults.

Two cautions:

- **Tier by task *shape*, not importance.** Mechanical, verifiable work — running
  checks, git operations, applying a specified patch, reading and summarising —
  goes cheap. Judgment work — design, review triage, debugging — stays high. A
  weaker model on a hard task adds turns, and turns are the cost driver, so bad
  tiering backfires and looks like a saving until it doesn't.
- **Tiering lowers the growth rate; it does not bound the total.** Keep a context
  cap as a backstop (it can be looser than 200k if growth is genuinely slower).
  Note that a 200k-context model enforces the cap for free on read-heavy roles.

### D3 — Converge reviews faster; do NOT cap reviewer rounds *(decision reversed)*

**Rejected:** capping reviewer convergence at two rounds. Convergence is the goal.
A PR that cannot reasonably be believed good should not merge because someone
wanted to save tokens — and on a subscription there is no per-PR price to defend.

**Accepted instead:** reduce *rounds to convergence*.

- **Delta-scoped reruns, state-checked rather than stated.** Record what each
  reviewer covered and what the delta touched; refuse a launch when they do not
  intersect. The prose rule already exists and was ignored.
- **Fix the class, not the instance.** Already in the skill. Every round that
  fixes one instance and leaves a sibling open buys the next round its input —
  this is the single biggest driver of round count.
- **Raise the materiality bar again** so more nitpicks and smaller non-critical
  findings pass. This is the cheapest available change and directly shortens the
  fix→rerun cycle.

Converging in 3 rounds instead of 7 beats any cap and is strictly better for merge
quality.

### D4 — Tighten validation *(accepted)*

- One validation command per validation event. Never umbrella-check + typecheck +
  tests as three turns answering one question.
- Full check at initial push and at the merge gate. Targeted tests everywhere
  else.
- Never revalidate because a reviewer poll returned nothing new.
- **Capture exit codes explicitly; never pipe a validation command through
  `head`/`grep`.** Fixes the 27% unreadable-status bug (§4).

### D5 — Context cap as backstop, not primary control *(accepted, demoted)*

Retained as the floor under whatever D1–D4 miss, but no longer the headline fix.
Under D2 the cap may be set looser. Enforce mechanically — agents are poor at
self-monitoring context.

### D6 — PR waves; stacked PRs as an optional spike *(accepted, with expectations set)*

Replace "keep PRs as small as possible" with: **keep PRs independently reviewable,
generally grouping 1–3 closely related tasks; process dependent PRs in waves and
rebase once at the merge gate.**

On GitHub stacked PRs: `gh-stack` exists as an official extension
(`gh extension install github/gh-stack`) — an extension, not native GitHub, and
not currently installed. **It fixes the wrong half.** Stacks reduce rebase churn
(~200 turns) but each stack member still gets its own CI run and its own reviewer
passes, and that is where the multiplier lives. Cutting PR count directly cuts CI,
review, *and* rebase together. Treat stacks as a small optional experiment
afterwards if rebase pain is still binding — not as a foundation.

### D7 — Status-report cadence *(accepted)*

Report on phase transitions, not per step. ~150 turns. Requires an operator
configuration change, not a skill change.

### D8 — Reads and edits: leave mostly alone *(accepted as stated)*

More `rg` and bounded ranges is fine hygiene but does not deserve design effort at
750k tokens total. The one part worth building is an **explorer's-map artifact**
passed into implementing agents so several agents do not independently rediscover
the same files. The same artifact is required for D5's handoff, so it is built
once and used twice.

## Expected effect

| Item | Est. turns removed | Compliance-dependent? |
|---|---|---|
| D1 polling | ~300 | No — new primitive |
| D4 validation | ~450 | Partly |
| D3 reviewer rounds | ~200 direct, 3–4x secondary | Partly — needs state enforcement |
| D6 PR waves | ~200 | Partly |
| D7 status cadence | ~150 | No — config |
| D8 duplicate exploration | ~150 | Partly |
| D2 effort tiering | Reduces `g`, not `N` | No — config |
| D5 context cap | Bounds worst case | No — if mechanical |

If ~40% of turns are removed, tokens should fall by roughly 60%, because average
context scales with turn count too. That exceeds the ~55% that a 200k cap alone
was projected to deliver, and the two compose.

## Open questions

1. **Reconcile the transcript-derived totals against provider usage reporting**
   before treating any figure here as a baseline. The 38% dedup gap warrants it.
2. **How does the subscription plan weight cache reads against the usage limit?**
   Every figure here assumes 1:1. If cache reads are discounted against the limit
   the way they are against API price, the priority ordering shifts.
3. **Does the harness expose context editing** (`clear_thinking_*` /
   `clear_tool_uses_*`) anywhere? If it appears, it likely outranks D2 — it targets
   the dominant fill directly with no agent cooperation required.
4. **Ambiguity-driven reruns:** measure whether masked-exit-status runs are
   followed by immediate re-runs (§4).
5. **What did the run produce?** No efficiency denominator was ever computed. 19
   sessions and 1.842B tokens across N merged PRs may or may not be reasonable;
   without N it is a gross number, not a verdict.

## Reference

### Metric definitions

| Term | Meaning |
|---|---|
| Reported / deduplicated tokens | Σ over calls of (input + cache read + cache write + output), counted once per message ID |
| Cache read | Prompt prefix served from cache. In an agentic loop this is the resent conversation, so it approximates Σ(context size) |
| Associated tokens | Context size carried by turns issuing a given tool type. **Not additive across categories**; understates the value of removing turns |
| Context (avg / max) | Total prompt size on a single call |

### API price reference (not the operative metric here)

Retained because these findings will be reread by someone who may be on API
billing. Opus-tier at the time of analysis: $5/MTok input, $25/MTok output, 1M
context **at standard pricing with no long-context premium**. Cache reads ~0.1x
base input; cache writes 1.25x (5-minute TTL) or 2x (1-hour TTL).

Under that model Run A is ~$365+ and the two-day window ~$1,755 — of which cache
writes are ~32% of cost from ~4% of tokens, a line item no analysis examined. The
2.24B window would have cost ~$11k uncached, so caching was working as intended;
the high cache-read share is the saving, not the defect.

**On a subscription this reframe does not apply.** Tokens are the metric and the
original totals are the right ones to optimise.
