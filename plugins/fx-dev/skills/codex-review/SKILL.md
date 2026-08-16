---
name: codex-review
description: Run OpenAI Codex's AI code review LOCALLY via the `codex` CLI BEFORE opening a PR (part of pre-PR self-review). Runs one-shot, reviewing the current branch, prints findings to stdout, and you resolve them before the PR is opened. Pass a Scope Brief as args — the review MUST be scoped to the user's original request, or Codex reports the work you deliberately did not do. Use during pre-PR self-review, alongside fx-dev:coderabbit-review.
---

# Codex Review

**⛔ Load `fx-dev:review` first** (Skill tool: `skill="fx-dev:review"`). It is the
canonical review procedure — carrying the Scope Brief, triaging in filter order,
sweeping a class, converging, reporting. This skill is the **Codex adapter**: how
to drive the `codex` CLI, and nothing else. Where the two appear to disagree,
`fx-dev:review` wins.

Codex is a **local, one-shot** reviewer against the current branch. Run it during
pre-PR self-review, after `coderabbit-review` and before `pr-preparer`. It
complements CodeRabbit rather than replacing it — each catches issues the other
misses.

## Project conventions: Codex is the one reviewer that needs a bridge

Codex reads `AGENTS.md`. It does **not** read `REVIEW.md` or `CLAUDE.md`. Every
other reviewer reaches `REVIEW.md` on its own; Codex is the exception. The bridge
is a `## Code Review Rules` section in `AGENTS.md` pointing at `REVIEW.md`, which
`fx-dev:setup` creates.

Before the first run in a repo:

```bash
grep -q "## Code Review Rules" AGENTS.md 2>/dev/null \
  && echo "Codex pointer present" \
  || echo "MISSING - run fx-dev:setup (new repo) or fx-dev:upgrade (legacy layout)"
```

If it is missing, **report it and continue reviewing on defaults** — do NOT run
`fx-dev:setup` or `fx-dev:upgrade` from here (`fx-dev:review` Step 6 explains
why). Tell the user to run it separately.

If Codex flags something `REVIEW.md` explicitly permits, the pointer is not
landing — say so rather than silently applying the finding.

## The prompt IS the Scope Brief

`codex review` takes a prompt, so unlike Copilot or the CodeRabbit App, Codex can
receive the brief directly. Build it per `fx-dev:review` Step 1 and pass it as the
prompt, in this order:

1. **Verbatim user request** — the user's own words, quoted, not paraphrased.
2. **What this change is** — deliverable type, and what it is meant to accomplish.
3. **OUT OF SCOPE** — each deliberate omission *with the reason it is deliberate*.
   "Do not flag missing tests" invites an override; "this change is spec-only,
   implementation is task 2 of change 0007" does not.
4. **IN SCOPE** — the dimensions worth reviewing for this deliverable.
5. **Established facts** — anything verified this session, so Codex does not
   relitigate it.
6. **The BLOCKING block below, verbatim** — on pass 1 as well as every re-run.

```bash
codex review "${MCP_OFF[@]}" "SCOPE — READ CAREFULLY BEFORE REVIEWING.

The user asked: \"<verbatim request>\"

This change is <deliverable type>: <one line on what it does>.

OUT OF SCOPE — do NOT report any of these:
- <deliberate omission, and why it is deliberate>
- Anything about files not modified on this branch.

IN SCOPE — review for:
- <dimension>

Established this session and not to be relitigated:
- <verified fact>

<the BLOCKING block below — verbatim, on pass 1 too>"
```

**A Codex run without the scope prompt is an incomplete pass.** Rerun it with one
rather than filtering the output by hand.

## ⛔ ALWAYS disable MCP servers — otherwise the run can hang forever

**A `codex review` that inherits the user's MCP servers can block indefinitely on
its very first action, producing zero output** — not slow, not partial: stalled at
~0% CPU until something kills it. Observed twice on 0.147.0, each time sitting
16+ minutes having emitted nothing.

The mechanism: a review invoked non-interactively still reaches for MCP tools, and
a tool call that stalls, fails, or wants an answer has **nobody to answer it** —
there is no TTY, and `codex review` has no approval-policy flag of its own. The
call never settles, so the turn never advances. Two things make this the normal
case rather than an edge case:

- A global `~/.codex/AGENTS.md` telling every session to do something through an
  MCP tool at startup guarantees the first action is an MCP call, before any
  review work happens.
- Codex's **code mode** batches those calls (`tools.mcp__*` inside a
  `Promise.all`), so one unsettled call strands the whole batch.

A code reviewer needs no MCP servers. Disabling them removes the whole failure
class instead of dodging one trigger, and it starts faster. Do not "try without it
first."

### The override that works — per server, by name

**`-c 'mcp_servers={}'` does NOT work. Do not use it.** Verified on 0.147.0: the
map is merged, not replaced, so every server stays loaded and every tool stays
available. It looks like it worked because a run that happens not to call a tool
shows no MCP output — the servers are still there. Setting `CODEX_HOME` to a
sanitized directory does not work either.

What works is disabling each server **individually** by name:

```bash
# Build one -c per configured server, then pass "${MCP_OFF[@]}" to codex review.
MCP_OFF=()
while read -r name; do
  [ -n "$name" ] && MCP_OFF+=(-c "mcp_servers.${name}.enabled=false")
done < <(codex mcp list --json 2>/dev/null | jq -r '.[].name')
```

**Enumerate with `codex mcp list --json`, never by parsing `config.toml`.** Not
every active server is declared there — servers can also arrive from
project-scoped or managed configuration, and a `config.toml` scrape silently
misses those. That produces a *partial* flag set, the worst outcome: the command
looks correct, most servers are disabled, and the one it missed hangs the run
exactly as before. `codex mcp list` is the resolved, authoritative view.

Echo the built flags before running. An empty or short `MCP_OFF` against a machine
you know has servers means the enumeration failed — fix that before starting a
long review.

Codex may also expose its own hosted tools not declared in `config.toml`; those
survive this and are expected to. The hazard is the locally-configured servers.

These are per-invocation overrides. **Never** "fix" this by editing the user's
`~/.codex/config.toml` or `~/.codex/AGENTS.md` — those are theirs, machine-wide,
and a review has no business rewriting them.

### Diagnosing a stalled review

No output for several minutes means stalled, not slow, and it will never recover.
Do not wait it out:

```bash
# 1. Confirm: near-0% CPU with no output is the signature.
ps -o pid,etime,stat,pcpu,wchan:20 -p "$(pgrep -f 'codex review' | head -1)"

# 2. Find its last action — the newest rollout records every step.
ls -t ~/.codex/sessions/*/*/*/rollout-*.jsonl | head -1
```

In that rollout, a `custom_tool_call` with **no matching `custom_tool_call_output`
after it** is the stalled call, and its `input` names the tool that never
returned. Kill the run, re-invoke with the per-server flags, and tell the user
what stalled rather than silently retrying.

## Running it

```bash
codex review "${MCP_OFF[@]}" "<scope prompt>" | tee /tmp/codex-review.md
```

This picks the current branch, diffs it against its base, and prints the review
(highest-risk first) to stdout. It never modifies your working tree.

**Run it in the background and let the completion notification wake you.** A
review of a real branch takes many minutes and `codex` buffers, so the capture
file stays empty until it finishes — polling it teaches you nothing. Do not chain
sleeps waiting on it.

### ⛔ Scope flags and a custom prompt are mutually exclusive

Verified on 0.146.0, both of these are rejected:

```
error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'
```

The usage line prints `codex review --base <BRANCH> [PROMPT]`, which looks like it
should work — it does not. **Since the scope prompt is mandatory, the prompt-only
form is the default invocation**, and it needs the changes committed on a branch
so Codex can derive the diff itself. If the work is uncommitted, commit it to a
branch first (never review from a bare `main` with a dirty tree) and say you did.

Scope flags remain available only for a **prompt-less** run, which is a last
resort — you then filter out-of-scope findings by hand:
`codex review "${MCP_OFF[@]}" --base main`, or `--uncommitted` for staged +
unstaged + untracked.

### Flags and availability

- Verified on 0.147.0, `codex review` accepts exactly nine options:
  `--strict-config`, `-c/--config`, `--uncommitted`, `--base`, `--enable`,
  `--commit`, `--disable`, `--title`, `-h/--help`. There is **no** `--json`/`-o`
  and **no** `--dangerously-bypass-approvals-and-sandbox` (that is `codex exec`).
  Check `codex review --help` before reaching for anything else.
- Requires `codex` installed and already authenticated. If it is not, STOP and
  report to the user — never run `codex login`.
- If the CLI is unavailable or unauthenticated, report once and skip this pass.

## The BLOCKING block — carried in every prompt

> **This block is a MIRROR** of `fx-dev/skills/dev/references/scope-contract.md`
> § Blocking, § Reporting a class, and § Three things that are not findings — the
> one case the define-once rule exempts, because `codex review` receives a string
> and cannot follow a link (`fx-dev:review` § The two canonical sources). Keep it a
> faithful restatement, never an independent edit, and update it in the same commit
> that changes the canonical text.

Pass 1 is where a reviewer with no bar produces the largest crop of low-value
findings, so omitting it there costs the most. On re-runs, the CONVERGENCE PASS
preamble is added on top.

```
CONVERGENCE PASS <N>. Prior passes found <count> issues, disposed of as follows
— give each list, not a total, because an item summarised as "fixed" that was not
comes back without its reasoning:
- fixed and pushed: <the blocking ones>
- immaterial, deliberately not actioned: <item, and why it is below the bar>
- deferred as out of scope: <item, and the exclusion that covers it>
- rejected as a false premise: <item, and what did not hold>

Do not re-report any of them **while the reason still holds** —
each was rejected against a specific state of the tree, and later fixes have
changed that tree. If one of those reasons no longer holds, report the finding as
new and say which fix invalidated the rejection. Do not treat a rejection as
permanent.

Classes closed since the last pass — every site of each was swept, not just the
one reported: <class, and the search that proved it closed>. Report a further
instance of one of these only if the sweep actually missed it, and say which
site.

Report every BLOCKING finding. A finding is blocking if it is any of:

1. A violation of a rule this project wrote down — anything in AGENTS.md or
   REVIEW.md, a security or privacy invariant, or any other mandatory
   requirement the project recorded, including a change document or a spec it
   links. Report these whatever their direct behavioural impact; the project
   already decided they matter, so do not weigh them against the bar below.
2. Something that would change behaviour, break a build, a CI check or a test,
   make the artifact unimplementable, or expose a security, privacy, or data-loss problem
   — including a leaked credential, internal URL, or private identifier in
   documentation or examples. A false statement counts when a reader would act
   on it; a wrong number nothing keys on does not.
3. A genuine ambiguity a reader could act on two ways, or a missing step that
   would be discovered late and cost a cycle.

Wording, formatting, and counts nothing keys on are NOT blocking: one closing
note, not findings. The exception is item 1 above — where the project wrote down
a rule about wording or formatting, violating it is blocking on those grounds,
and this sentence does not override that.

When a finding is one instance of a pattern that appears elsewhere, say so and
list every other site you can see. Report it as ONE finding naming the class,
not as one finding per site and not as a single site. A class reported whole is
fixed in one pass; a class reported one instance at a time takes as many passes
as it has members.

Where this artifact marks a list as open — it says "for example", or it declares
the list illustrative and the rule authoritative — assess the RULE. A further
missing list entry is not a finding.

Where the artifact admits a limit and gates it — "verified by X at
implementation time", "open question gated on Y" — that is a disposition, not a
gap. Check the gate is real and sequenced before the thing that depends on it,
and do not report the limit itself as a missing step.

Where it records a decision with its rationale — including "unknown, gated on
X" — and your disagreement is about preference, that is settled: say so once as
an escalation, and do not re-argue it. This does NOT cover a decision that is
itself the defect. If the decision leaks a credential, an internal URL, or a
private identifier, loses data, violates a security or privacy invariant, or
contradicts a contract the project mandates — a spec, a change document, or a
written project rule — report it as a blocking finding however carefully it is
reasoned.

If the artifact is internally consistent and matches the tree, say so plainly.
```

## Codex-specific triage notes

Everything general is in `fx-dev:review` Steps 2–5. Two things are peculiar to a
local run:

- **There are no threads to resolve.** Resolution here means the code is fixed, or
  the finding is a recorded non-issue. An immaterial observation goes straight
  into the closing note rather than into a reply.
- **A fix is a commit, not a push.** Make atomic commits, and re-run Step 7's loop
  against them.

## The gate

A **converged** Codex review — no blocking finding left unresolved
(`fx-dev/skills/dev/references/scope-contract.md` § Convergence) — alongside a
converged CodeRabbit review is the gate to PR creation (`fx-dev:dev` Step 4.5 →
Step 5). Outstanding **immaterial** observations do not hold the PR; carry them
into its description as a closing note.
