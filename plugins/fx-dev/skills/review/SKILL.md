---
name: review
description: "Canonical review procedure shared by every fx-dev reviewer and feedback resolver. Load this FIRST, then load the platform skill for the reviewer you are actually running — fx-dev:codex-review, fx-dev:coderabbit-review, fx-dev:copilot-review, fx-dev:pr-reviewer, fx-dev:resolve-pr-feedback, fx-dev:copilot-feedback-resolver, or fx-dev:rabbit-feedback-resolver. Defines how to carry the Scope Brief, triage findings, sweep a class, converge, and report. Use directly when reviewing code with no particular tool in mind."
---

# Review

**The one procedure every fx-dev reviewer follows.** The platform skills —
`codex-review`, `coderabbit-review`, `copilot-review`, `pr-reviewer`,
`resolve-pr-feedback`, `copilot-feedback-resolver`, `rabbit-feedback-resolver` —
are adapters. They describe how to drive one particular tool: its command, its
flags and quirks, the shape of its output, the threads or checks it exposes.
Everything else — what to review, what to report, what to fix, when to stop —
lives here and is identical for all of them.

**Load order:** this skill first, then the platform skill. A platform skill that
contradicts this one is stale; this one wins, and the contradiction is a bug to
report.

## Why this skill exists

Seven skills once carried their own copy of these rules. A copy drifts the moment
the original changes, and a stale copy is reliably the *narrower* one — so it
under-blocks, under-converges, or re-opens scope it should not. That is not a
hypothetical: the divergence was found and fixed repeatedly before the rules were
brought here.

This skill is the application of `dev/references/scope-contract.md`
§ Blocking's define-once rule to the review skills themselves.

## The two canonical sources

| Source | Holds |
|---|---|
| `fx-dev/skills/dev/references/scope-contract.md` | **Definitions.** The Scope Brief, the materiality bar, what *blocking* means, the three filters, resolver dispositions, convergence, the iteration bound, fix-the-class. |
| **This skill** | **Procedure.** How a reviewer applies those definitions, in order, from first pass to final report. |

Neither restates the other. Where this skill needs a definition it names the
section; where a platform skill needs either, it names them rather than copying.

**One exception, and only one: text sent verbatim to an external tool.** A prompt
handed to `codex review`, `cr`, or any reviewer outside this repo cannot follow a
link, so it MUST inline the rule. Such a block is a **mirror**: mark it as one,
keep it a faithful restatement, and update it in the same commit that changes the
canonical text. Nothing an agent reads directly qualifies — only strings crossing
a process boundary.

---

## Step 1: Carry the Scope Brief

**Never review a bare diff.** A reviewer that does not know what was asked for
reports the work that was deliberately not done — missing implementation for a
docs-only change, missing tests for a spec, dependencies a later phase adds. Each
such finding costs a full review cycle to filter by hand.

Every review invocation MUST carry the **Scope Brief**
(`fx-dev/skills/dev/references/scope-contract.md` § The Scope Brief for the
definition and field rules; § Injecting the brief into reviews for how it reaches
each kind of reviewer).

- **Handed one by a coordinator** — use it verbatim. Do not summarise it.
- **Invoked without one** — reconstruct it from the conversation and the PR
  description before reviewing, **and say in your report that you did**.

**The brief never suppresses a real finding.** It excludes work deliberately not
done; it does not excuse defects in the work that *was* done. Security, privacy,
data-loss and correctness problems inside the change are always in scope, whatever
the brief says. An excluded finding re-enters scope only on the two conditions in
§ Three filters, filter 1 — and being merely correct is not one of them.

## Step 2: Triage in the contract's order

**Scope, then contract, then materiality** — the three filters, in that order
(`fx-dev/skills/dev/references/scope-contract.md` § Three filters). Applying them
out of order produces the wrong verdict:

1. **Scope** — an out-of-scope finding is **deferred** with the exclusion that
   covers it, however material it looks in isolation.
2. **Contract** — a violation of a project rule, or of a security or privacy
   invariant, is **blocking by virtue of being a rule**. It never reaches the bar,
   so "it changes no behaviour" cannot demote it.
3. **Materiality** — everything left is ranked by the bar.

A reviewer's own severity labels — CodeRabbit's `🧹 Nitpick` / `🔵 Trivial`,
Copilot's `[nitpick]` prefix, a `P2` — are an **input** to that judgment, never a
verdict. A label demotes nothing: an item carrying one still goes through all
three filters, so a project-rule, security or privacy violation wearing a
`[nitpick]` prefix is a contract blocker at filter 2 regardless. Nor does the
converse hold — calling something a correctness defect does not carry it past the
bar. A false count nobody acts on reaches filter 3 and ranks immaterial, exactly
as § The bar says.

The outcome is exactly one of: **blocking**, **immaterial**, **deferred**, or —
where you checked the premise and it does not hold — **no disposition at all**
(§ Resolver dispositions). Blocking is defined once, in § Blocking; this skill
does not restate it.

### Three things that are not findings

Per § Three things that are not findings, and not narrowed here:

- **An entry missing from a list the artifact does not present as exhaustive** —
  "for example" counts, not just an explicit declaration. Not reported at all, not
  even in the closing note: the supply never runs out, so a note listing them
  grows without bound. Assess whether the *rule* is right instead.
- **A decision the artifact records with its rationale, where your disagreement is
  about preference** — say so once as an escalation; do not re-argue it next pass.
  This never applies when the decision is itself the defect.
- **A limit the artifact admits and gates** — check the gate is real and sequenced
  before the thing that depends on it, then move on.

## Step 3: Verify the premise before acting

A finding's premise can be wrong. When one rests on a claim about the tree, check
it. Where it does not hold:

- **Reviewing** — reject the finding with the evidence, and put it in the next
  pass's do-not-re-report list.
- **Resolving threads** — the thread is a false positive, not a finding. It gets
  **no disposition**; hand it to the outdated/incorrect handler with the reason.
  If the `blocking` disposition came from a coordinator, do **not** close the
  thread on your own reading — that disposition is authoritative. Return it for
  reclassification and leave it open.

Fixing a phantom finding is worse than leaving it: it changes working artifacts to
satisfy a misreading, and a suggestion applied on sight has been observed to
introduce the very bug it claimed to report.

## Step 4: Fix the class, not the instance

**The single biggest cause of a review loop that will not end.** A reviewer
reports the instance it happened to read; fix exactly that instance and the next
pass finds a sibling and reports it as new. Every pass is productive and the loop
still never terminates.

Follow `fx-dev/skills/dev/references/scope-contract.md` § Fix the class, not the
instance in full — the sibling axes (lexical, altitude, symmetry, enumeration),
the requirement to prove the sweep with a search whose empty result is the
evidence, and the rule that scope still bounds the sweep.

Two practical points that cost real cycles here:

- **Normalise whitespace before searching for anything longer than a few words**,
  and never filter out the file under review. Both have produced an empty result
  that was read as proof while the phrase sat there wrapped across a newline.
- **Do not start the next pass with a class half-closed.** A re-run against a
  partial fix spends a full cycle being told about siblings you already knew
  about, and its findings are indistinguishable from new ones.

When a finding is one instance of a pattern **you can see elsewhere**, report it
as ONE finding naming the class and list every other site — § Reporting a class.

## Step 5: Act on the disposition

| Disposition | Action |
|---|---|
| **blocking** | Fix it, swept as a class, and push (or commit, for a local review). A contract blocker is never discharged by a reply explaining it — the artifact has to change. |
| **immaterial** | **Reply with the reasoning** — what the observation is, why it is below the bar — and resolve. **No edit.** For a local review with no threads, it goes in the closing note instead. |
| **deferred** | Reply citing the exclusion that covers it, and resolve. **No edit, and no commit** — including no tracker commit, which widens the change. Return the follow-up to the coordinator, or propose it to the user when running standalone. |

**A false premise is not a fourth disposition.** There are exactly three
(§ Resolver dispositions), and a thread whose premise does not hold carries
**none** of them — that absence is what routes it to the adapter's
outdated/incorrect handler: reply with the evidence, resolve, and where a
deliberate convention was misread, record it (Step 6). A coordinator hands it over
as an explicitly undisposed item *with the reason*, never as a disposition value,
because an authoritative one would close that route off and lose the `REVIEW.md`
entry with it.

**Never edit for an immaterial finding.** Every push requires another reviewer
pass before the loop can converge, so actioning one manufactures the next round's
input — it is the churn the materiality bar exists to stop. The gate is zero
*unresolved* threads, not zero observations acted on.

**A disposition assigned by the coordinator is authoritative** and overrides a
resolver's own categorisation (§ Resolver dispositions): the coordinator holds the
brief and the ledger, and a resolver classifying from comment text alone does not.

## Step 6: Record incorrect findings in `REVIEW.md`

When a reviewer flags a pattern that is a deliberate project convention, write the
rule into **`REVIEW.md` at the repo root**. One entry stops Codex, Copilot,
CodeRabbit and Claude Code Review from raising it again — they all resolve to that
file.

That entry is **required work, not an edit made for an immaterial finding**: it is
the only thing that stops the false positive recurring, and its commit is expected.

- **Never** create or edit `.github/copilot-instructions.md`. It is obsolete.
- If `REVIEW.md` does not exist, create just that file, with a `# PR Review`
  heading and the rule under it. **Do not run `fx-dev:setup` or `fx-dev:upgrade`
  from a review** — they scaffold `docs/`, `AGENTS.md` and `.coderabbit.yaml`, and
  burying one review rule in a large unrelated diff is not an acceptable change.
  Mention that `/fx-dev:setup` completes the layout later.
- **Keep the top section under 4000 characters.** Copilot reads roughly the first
  4000 when reviewing, and `REVIEW.md` is pasted verbatim into Claude Code
  Review's prompt, where length dilutes the rules that matter. Put the most
  important rules in a `## PR Review Checklist (CRITICAL)` section at the top.
- `REVIEW.md` is pasted verbatim: `@` imports are not expanded and referenced
  files are not read. Write the rule out in full; never write `See docs/…`.

### Parallel resolvers must not write it concurrently

Re-reading before writing is not locking: two sub-agents can read the same
revision and the second write silently discards the first's rule. When resolvers
run in parallel, have each **return** its proposed rules instead of editing, then
apply them all in one serialized edit and verify with `git diff -- REVIEW.md` that
every proposed rule appears as an added line. Counting the whole file always fails
— an established `REVIEW.md` already holds unrelated rules.

## Step 7: Re-run until it converges

**Convergence is the goal.** Repeat Steps 1–6 until **no blocking finding is left
unresolved** — the ledger test in `fx-dev/skills/dev/references/scope-contract.md`
§ Convergence, and the only test.

**Converged does NOT mean zero output.** Waiting for silence spends full cycles on
wording. And do not re-derive the test from materiality: it already settles both
edge cases, so trust it rather than rebuilding it. A deferred finding is
non-blocking however material it looks in isolation; a contract blocker is
blocking however small its behavioural impact.

Note the test is *unresolved*, not *new*: a blocker carried from an earlier pass
still blocks even if this pass did not repeat it, and a finding that produces no
thread — a suppressed Copilot item — is never discharged by a thread count. Track
them and clear the list.

### Carry the settled ground into each re-run

Each pass must know what the last one decided, or it re-derives it. Carry forward,
in the prompt for a CLI reviewer and in your own working notes otherwise:

- the same Scope Brief, plus anything newly established;
- **each prior outcome separately** — fixed, immaterial, deferred, false premise.
  A summary saying "all fixed except the rejected ones" describes neither an
  immaterial item nor a deferred one, so the reviewer is told they disappeared and
  raises them again stripped of their reasoning;
- the classes closed since the last pass, **with the search that proved each
  closed**, so the pass is spent on ground nobody has covered.

A rejection holds only **while its reason still holds**. Each was made against a
particular state of the tree, and later fixes change that tree — if a fix removed
what made a finding a false positive, it is valid now. Report it as new and say
which fix invalidated the rejection.

### The three exits

- **Converged** — no blocking finding left unresolved. The only successful exit.
- **The same disagreement in successive passes** — a human decision, not a review
  outcome. Escalate it **by name** and stop; do not spend the remaining iterations
  re-arguing it.
- **A rising blocking count in one class** — the last fix is generating them. Stop
  fixing instances and fix the cause; escalate only where that cause is a design
  choice with two defensible answers. A count rising across *different* categories
  means the review is still productive, not diverging.

Every loop caps at the bound in § The iteration bound, which counts the initial
pass as iteration 1 and which no skill restates or overrides. **The bound is a
runaway backstop, not a target.** Reaching it is a failure to converge that you
report as an escalation, never as a pass. Each pass on a real branch takes many
minutes, so fix causes, not instances.

## Step 8: Report

State the shape, not a verdict, so the operator can see it rather than take
"clean" on trust:

- **The per-pass trend of blocking findings** — *"Findings per pass: 9, 4, 1, 0
  blocking."*
- **What remains below the bar**, as one closing note, unnumbered and explicitly
  non-blocking. Never a numbered finding, never a reason for another pass.
- **What was deferred**, with the exclusion covering each.
- **Whether the last round's fixes were themselves reviewed.** If you stopped
  after applying fixes nothing has reviewed, say so.
- **Counts per tier.** A review that reports twenty things equally has reported
  nothing.
- **Whether you reconstructed the Scope Brief** rather than being handed one.

A run that produces **zero** out-of-scope findings is the signal the brief was
well built. Persistent out-of-scope noise means it is too thin — tighten it before
the next iteration rather than filtering by hand again.

---

## What a platform skill adds

Only what is true of that tool and nothing else:

- how to invoke it, and the flags, exit codes and failure modes that matter;
- how its output is shaped, and how to extract findings from it;
- the threads, checks or gates it exposes, and how to settle them;
- its authentication and availability rules, and its degradation path.

**A platform skill MUST NOT restate Steps 1–8.** If it needs one, it names the
step. If it genuinely needs different behaviour, change it here, for everyone.

## Shared rules that bite in every platform

- **Never leave new PR-level comments.** `gh pr review --comment` and
  `gh pr comment` are forbidden, as is any GraphQL mutation creating a new review
  or PR-level comment, and any interaction with a human reviewer's threads. The
  only permitted operations are replying to an existing *bot* thread with
  `addPullRequestReviewThreadReply` and resolving it with `resolveReviewThread`.
- **Never run an interactive auth command** — not `codex login`, not
  `cr auth login`, not `gh auth login`. The workspace is expected to be
  authenticated; if it is not, STOP and report it to the user.
- **Absence of feedback is not evidence of quality.** A reviewer that has not run,
  a poll that saw nothing, and a timeout are all *unreviewed*, not clean.
- **Resolution is not the same as a fix.** A thread ends resolved either way; only
  a blocking finding requires the artifact to change.

## When to use this skill directly

Reviewing code with no particular tool in mind — a diff, a branch, a spec. Then
this skill is the whole procedure, and there is no adapter to load.
