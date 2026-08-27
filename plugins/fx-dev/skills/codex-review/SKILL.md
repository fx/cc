---
name: codex-review
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Runs a scoped one-shot Codex CLI branch review as an external review adapter."
---

# Codex Review

**⛔ Load `fx-dev:review` first** (Skill tool: `skill="fx-dev:review"`). It is the
canonical review procedure — carrying the Scope Brief, triaging in filter order,
sweeping a class, converging, reporting. This skill is the **Codex adapter**: how
to drive the `codex` CLI, and nothing else. Where the two appear to disagree,
`fx-dev:review` wins.

Codex is a **local, one-shot** reviewer against the current branch, and it is the
**only** local reviewer in this SDLC. Run it during pre-PR self-review, after
`/simplify` and `/code-review` and before `pr-preparer` (`fx-dev:dev` Step 4.5).

> There is no local CodeRabbit pass — the `cr` CLI is not used anywhere. CodeRabbit
> applies only at the PR level, and only when the repo's GitHub App is installed.

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
6. **`fx-dev:review` § The external-reviewer block, verbatim** — Part 2 (the bar)
   on pass 1 as well as every re-run; Part 1 (the convergence prefix) on top of
   it from pass 2 only.

```bash
# Write the brief to a file, then hand the FILE to the script. Never invoke
# `codex review` directly — see "Running it" below.
cat > /tmp/scope-prompt.md <<'PROMPT'
SCOPE — READ CAREFULLY BEFORE REVIEWING.

The user asked: "<verbatim request>"

This change is <deliverable type>: <one line on what it does>.

OUT OF SCOPE — do NOT report any of these:
- <deliberate omission, and why it is deliberate>
- Anything about files not modified on this branch.

IN SCOPE — review for:
- <dimension>

Established this session and not to be relitigated:
- <verified fact>

<fx-dev:review § The external-reviewer block, Part 2 — verbatim, on pass 1 too.
 On a re-run, Part 1 goes above this.>
PROMPT
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

What works is disabling each server **individually** by name.

**`scripts/run-codex-review.sh` does exactly this**, emitting one
`-c mcp_servers.<name>.enabled=false` per server enumerated from
`codex mcp list --json`. Do not hand-roll it: the script also treats an
enumeration *failure* as a setup failure and refuses to run, whereas a hand-rolled
loop silently yields an empty flag set and reproduces the hang. This paragraph
documents the mechanism; the script is the only supported way to apply it.

**Enumerate with `codex mcp list --json`, never by parsing `config.toml`.** Not
every active server is declared there — servers can also arrive from
project-scoped or managed configuration, and a `config.toml` scrape silently
misses those. That produces a *partial* flag set, the worst outcome: the command
looks correct, most servers are disabled, and the one it missed hangs the run
exactly as before. `codex mcp list` is the resolved, authoritative view.

The script echoes the resolved server list before running, so a PARTIAL set is
visible. A short list on a machine you know has more servers means the enumeration
returned less than it should — stop and fix that before starting a long review.

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
returned. Kill the run, re-invoke via the script, and tell the user what stalled
rather than silently retrying.

## Running it

**Use the bundled script.** It encodes the MCP enumeration, the prompt-only
invocation, and the `AGENTS.md` pointer check, so none of them can be
half-remembered:

```bash
mkdir -p .claude/team/waits && \
bash [SKILL_BASE_DIR]/skills/codex-review/scripts/run-codex-review.sh /tmp/scope-prompt.md \
  > .claude/team/waits/codex-review.log 2>&1
```

Write the scope prompt (built as below) to a file and pass its path, or pass `-`
to read it from stdin. The script applies the model and effort defaults below
per invocation (`CODEX_REVIEW_MODEL` / `CODEX_REVIEW_EFFORT` override them); it
never edits the user's `~/.codex/config.toml`. `CODEX_REVIEW_OUT=<path>` also tees the review to a file;
`CODEX_REVIEW_DRY_RUN=1` prints the resolved command without running it, which is
the fastest way to confirm the MCP flag set is complete.

The script picks the current branch, diffs it against its base, and prints the
review (highest-risk first) to stdout. It never modifies your working tree.

**⛔ Run it in the BACKGROUND (`run_in_background: true`) and let the completion
notification wake you.** A review of a real branch takes many minutes and `codex`
buffers, so the capture file stays empty until it finishes — polling it teaches you
nothing and costs a full context read every time. Do not chain sleeps waiting on it.

The script has **no timeout**: Codex is one-shot and its runtime is its own. It
exits 3 on a usage error (missing or empty scope prompt, `codex` not on PATH) —
deliberately not 1 or 2, which `codex` itself uses, so "the reviewer failed" never
looks like "the reviewer had opinions".

### ⛔ Scope flags and a custom prompt are mutually exclusive

Verified on 0.146.0, both of these are rejected:

```
error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'
```

The usage line prints `codex review --base <BRANCH> [PROMPT]`, which looks like it
should work — it does not. **Since the scope prompt is mandatory, the prompt-only
form is the ONLY correct invocation**, and it needs the changes committed on a
branch so Codex can derive the diff itself. If the work is uncommitted, commit it
to a branch first (never review from a bare `main` with a dirty tree) and say you
did.

**⛔ There is no prompt-less fallback.** `--base` and `--uncommitted` exist, but
reaching for either means abandoning the Scope Brief, and a run without the brief
is an incomplete pass by definition — it reports the work the change deliberately
did not do, and you then filter its output by hand, which is the cost the brief
exists to avoid. If the work is uncommitted, **commit it to a branch** and run the
script with a prompt; that is always available, so the fallback never has a case.
Route every invocation through `scripts/run-codex-review.sh`, which refuses to
start without a non-empty prompt.

### Pick the model and effort — the default is far too slow

`codex review` inherits `model` and `model_reasoning_effort` from the user's
`~/.codex/config.toml`, and a reasoning-heavy default turns every pass into a
10–15 minute wait. Override them **per invocation** with `-c`; never edit the
user's config (see the MCP section — same reasoning).

The script applies these defaults itself. Override per run via env:

```bash
CODEX_REVIEW_MODEL=gpt-5.6-terra CODEX_REVIEW_EFFORT=high \
  bash [SKILL_BASE_DIR]/skills/codex-review/scripts/run-codex-review.sh /tmp/scope-prompt.md
```

**Default to `gpt-5.6-terra` at `medium`** — roughly a tenth of the wall clock of
a `sol`/`xhigh` default, and still substantive. Do not trade down to `luna` for
the extra speed: it reported "no blocking defect" on a branch where `terra` at
`medium` found a genuine P1, and a reviewer that finishes fast by finding nothing
is not faster. Reach for `terra`/`high` when you want every site of a class
enumerated and can afford roughly triple the wait. Effort above `high` is not
worth it for review — it found nothing more, and a 15-minute pass makes the
convergence loop unaffordable long before the iteration bound.

The measurements behind this choice are in the commit that made it
(`git log -S gpt-5.6-terra -- plugins/fx-dev/skills/codex-review/SKILL.md`), not
here: they are one branch on one machine at one point in time, and they date the
moment the models change.

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

Send **`fx-dev:review` § The external-reviewer block, verbatim**, as the last part
of every prompt — the first pass as well as every re-run. That block is the single
mirror both external reviewers use; this skill does not keep its own copy, and
must not paraphrase it.

That section is in two parts, sent on different schedules: **Part 2 (the bar) goes
in every prompt, pass 1 included; Part 1 (the convergence prefix) goes on top of it
from pass 2 only.** On pass 1 send Part 2 alone — Part 1 has nothing to carry and
asks the reviewer to honour a list of prior findings that does not exist.


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
(`fx-dev/skills/dev/references/scope-contract.md` § Convergence) — is the local gate
to PR creation (`fx-dev:dev` Step 4.5 → Step 5). It is the only local gate; there is
no local CodeRabbit review to converge alongside it. Outstanding **immaterial** observations do not hold the PR; carry them
into its description as a closing note.
