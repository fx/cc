---
name: codex-review
description: Run OpenAI Codex's AI code review LOCALLY via the `codex` CLI BEFORE opening a PR (part of pre-PR self-review). Runs one-shot, reviewing the current branch, prints findings to stdout, and you resolve them before the PR is opened. Pass a Scope Brief as args — the review MUST be scoped to the user's original request, or Codex reports the work you deliberately did not do. Use during pre-PR self-review, alongside fx-dev:coderabbit-review.
---

# Codex Review

This skill runs OpenAI Codex's AI code review **locally, one-shot**, against the
current branch. Run it as part of pre-PR self-review — after `coderabbit-review`,
before opening the PR — fix everything it finds, and only then open the PR.

It complements (does not replace) `coderabbit-review`: CodeRabbit and Codex are
independent reviewers and each catches issues the other misses.

## Project Conventions

Codex reads `AGENTS.md` — it does **not** read `REVIEW.md` or `CLAUDE.md`. Every
other reviewer reaches `REVIEW.md` on its own; Codex is the exception. The bridge
is a `## Code Review Rules` section in `AGENTS.md` pointing at `REVIEW.md`, which
the `fx-dev:setup` skill creates.

Before the first run in a repo, check the pointer exists:

```bash
grep -q "## Code Review Rules" AGENTS.md 2>/dev/null \
  && echo "Codex pointer present" \
  || echo "MISSING - run fx-dev:setup (new repo) or fx-dev:upgrade (legacy layout)"
```

If it is missing, **report it and continue reviewing on defaults** — do NOT run
`fx-dev:setup` or `fx-dev:upgrade` from here. Setup scaffolds `docs/` and touches
CodeRabbit config, and upgrade rewrites instruction files outright; running
either mid-review would pollute the branch with changes unrelated to the PR.
Tell the user to run it separately.

If Codex flags something that `REVIEW.md` explicitly permits, the pointer is not
landing — say so rather than silently applying the finding.

## MANDATORY: Inject the Scope Brief (do this BEFORE running Codex)

**Never run Codex on a bare diff.** A reviewer that does not know what was asked
for reports the work you deliberately did not do — missing implementation for a
docs-only change, missing tests for a spec, absent dependencies a later phase
adds. Every such finding costs a full review cycle to filter by hand.

Build the **Scope Brief** (canonical definition and field rules:
`fx-dev/skills/dev/references/scope-contract.md`) and pass it to Codex as the
review prompt. If a coordinator handed you a brief, use it verbatim. **If you
were invoked without one, reconstruct it from the conversation before reviewing
and say that you did** — never review as if the diff speaks for itself.

The prompt MUST contain, in this order:

1. **Verbatim user request** — the user's own words, quoted, not paraphrased.
2. **What this change is** — deliverable type and what it is meant to accomplish.
3. **OUT OF SCOPE** — an explicit list of what NOT to report, each with the
   reason it is deliberate. "Do not flag missing tests" invites an override;
   "this change is spec-only, implementation is task 2 of change 0007" does not.
4. **IN SCOPE** — the dimensions worth reviewing for this deliverable.
5. **Established facts** — anything already verified experimentally this session,
   so Codex does not relitigate it.

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
- <verified fact>"
```

**This is not optional and not a nicety.** A Codex run without a scope prompt is
an incomplete pass; rerun it with one rather than filtering the output by hand.

**Do not use the brief to silence real findings.** It excludes work deliberately
not done — it does not excuse defects in the work that *was* done. If Codex
flags an "excluded" item and turns out to be right, the exclusion was wrong: fix
the work and correct the brief.

## How to Run (one-shot, branch vs main)

Codex has a dedicated non-interactive review subcommand. From the repo root, on
your working branch, pass the Scope Brief prompt built above **and disable the
user's MCP servers** (see the next section — this is mandatory):

```bash
codex review "${MCP_OFF[@]}" "<scope prompt>"
```

This picks the current branch, diffs it against its base, and prints the review
(highest-risk findings first) to stdout — no interactive session, no edits to
your tree (review is read-only).

### ⛔ ALWAYS disable MCP servers — otherwise the run can hang forever

**A `codex review` that inherits the user's MCP servers can block indefinitely on
its very first action, producing zero output** — not slow, not partial: stalled
at ~0% CPU until something kills it. Observed twice on 0.147.0, each time sitting
16+ minutes having emitted nothing.

The mechanism: a review invoked non-interactively still reaches for MCP tools,
and a tool call that stalls, fails, or wants an answer has **nobody to answer
it** — there is no TTY, and `codex review` has no approval-policy flag of its
own. The call never settles, so the turn never advances. Two things make this the
normal case rather than an edge case:

- A global `~/.codex/AGENTS.md` that tells every session to do something through
  an MCP tool at startup guarantees the first action is an MCP call, before any
  review work happens.
- Codex's **code mode** batches those calls (`tools.mcp__*` inside a
  `Promise.all`), so one unsettled call strands the whole batch.

A code reviewer needs no MCP servers: it reads a diff and reports findings.
Disabling them removes the whole failure class instead of dodging one trigger,
and it starts faster. Do not "try without it first."

#### The override that works — per server, by name

**`-c 'mcp_servers={}'` does NOT work. Do not use it.** Verified on 0.147.0: the
map is merged, not replaced, so every server stays loaded and every tool stays
available. It looks like it worked because a run that happens not to call a tool
shows no MCP output — the servers are still there. Setting `CODEX_HOME` to a
sanitized directory does not work either; servers survive that too.

What works is disabling each server **individually** by name:

```bash
# Build one -c per configured server, then pass "${MCP_OFF[@]}" to codex review.
MCP_OFF=()
while read -r name; do
  [ -n "$name" ] && MCP_OFF+=(-c "mcp_servers.${name}.enabled=false")
done < <(codex mcp list --json 2>/dev/null | jq -r '.[].name')
```

Verified: with those flags, tools from every configured server disappear
completely from the session's registry. Enumerate the names rather than
hard-coding any — every machine's set differs.

**Enumerate with `codex mcp list --json`, never by parsing `config.toml`.** Not
every active server is declared there — servers can also arrive from
project-scoped or managed configuration, and a `config.toml` scrape silently
misses those. It produces a *partial* flag set, which is the worst outcome: the
command looks correct, most servers are disabled, and the one it missed hangs the
run exactly as before. `codex mcp list` is the resolved, authoritative view, and
the `-c mcp_servers.<name>.enabled=false` override works for a server however it
was configured.

Echo the built flags before running. An empty or short `MCP_OFF` against a
machine you know has servers means the enumeration failed — fix that before
starting a long review.

Codex may also expose its own hosted tools that are not declared in
`config.toml`; those survive this and are expected to. Leave them alone — the
hazard is the locally-configured servers, which is exactly what the loop above
covers.

These are per-invocation config overrides. **Never** "fix" this by editing the
user's `~/.codex/config.toml` or their global `~/.codex/AGENTS.md` — those are
theirs, they are machine-wide, and a review has no business rewriting them.

#### Diagnosing a stalled review

If a review produces no output for several minutes, it is stalled, not slow, and
it will never recover. Do not wait it out:

```bash
# 1. Confirm: near-0% CPU with no output is the signature.
ps -o pid,etime,stat,pcpu,wchan:20 -p "$(pgrep -f 'codex review' | head -1)"

# 2. Find its last action — the newest rollout records every step.
ls -t ~/.codex/sessions/*/*/*/rollout-*.jsonl | head -1
```

In that rollout, a `custom_tool_call` with **no matching `custom_tool_call_output`
after it** is the stalled call, and its `input` field names the tool that never
returned. Kill the run, re-invoke with the per-server flags above, and tell the
user what stalled rather than silently retrying.

**⛔ Scope flags and a custom prompt are mutually exclusive.** In current CLI
versions (verified on 0.146.0), `codex review --base main "<prompt>"` and
`codex review --uncommitted "<prompt>"` are both rejected:

```
error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'
```

The usage line prints `codex review --base <BRANCH> [PROMPT]`, which looks like
it should work — it does not. Since the scope prompt is mandatory, **the
prompt-only form is the default invocation**, and it needs the changes committed
on a branch so Codex can derive the diff itself. If the work is still
uncommitted, commit it to a branch first (never review from a bare `main` with a
dirty tree); tell the user you did so and why.

Scope flags remain available only for a **prompt-less** run, which should be a
last resort — you will then filter out-of-scope findings by hand (`-c
"${MCP_OFF[@]}"` still applies):
- `codex review "${MCP_OFF[@]}" --base main` — explicit base branch
- `codex review "${MCP_OFF[@]}" --uncommitted` — staged + unstaged + untracked

Capture output for later reference with shell redirection:
`codex review "${MCP_OFF[@]}" "<scope prompt>" | tee /tmp/codex-review.md`

**Run it in the background and let the completion notification wake you.** A
review of a real branch takes many minutes, and `codex` buffers — the capture
file stays empty until it finishes, so polling it teaches you nothing. Start it
backgrounded, do other work, and read the output when it lands. Do not chain
sleeps waiting on it.

(Run `codex review --help` for the exact flags your CLI version supports — there is no dedicated `--json`/`-o` flag, so use shell redirection to capture output.)

Notes:
- Review scope should match what the PR will contain.
- `codex review` has **no** `--dangerously-bypass-approvals-and-sandbox` or
  approval-policy flag of its own — that is `codex exec`. If a sandbox or
  approval prompt is what is blocking a review, the per-server MCP overrides
  above plus other `-c` config overrides are the lever you have. Verified on
  0.147.0, `codex review` accepts exactly nine options: `--strict-config`,
  `-c/--config`, `--uncommitted`, `--base`, `--enable`, `--commit`, `--disable`,
  `--title`, `-h/--help`. Check `codex review --help` before reaching for a flag
  that subcommand does not accept.
- Requires the `codex` CLI to be installed and already authenticated. The workspace is expected to be authed; if it is not, STOP and report to the user — do NOT run `codex login` (it is interactive).

## Workflow (fix → re-run → converge)

Treat Codex's findings like self-review feedback and loop until the review is clean.

### Step 1: Run the review with the Scope Brief prompt

```bash
codex review "${MCP_OFF[@]}" "<scope prompt>"
```

Build `MCP_OFF` first (see "How to Run") — a review that inherits the user's MCP
servers can stall forever with no output. Background it — reviews take many minutes and the output is buffered until the
end (see "How to Run").

If the `codex` CLI is **unavailable or not authenticated**, report to the user
once and skip this pass — NEVER run `codex login` (it is interactive; the
workspace is expected to be authed already).

If the run produces **no output for several minutes at near-0% CPU**, it is
stalled, not slow — diagnose it with the rollout check in "How to Run" rather
than waiting it out.

### Step 2: Resolve every actionable finding

- **Triage in the contract's order — scope, then contract, then materiality**
  (see `fx-dev/skills/dev/references/scope-contract.md`). Scope first: an
  out-of-scope finding is deferred however material it looks (Step 3.5). Then
  project rules and security/privacy invariants, which block regardless of the
  bar. Only what remains is ranked: material and substantive findings are fixed;
  immaterial ones — wording, formatting, a count nothing keys on, an entry
  missing from a list the artifact declares non-exhaustive — go into one closing
  note and MUST NOT drive another iteration.
- **Fix real issues** in code and tests; make atomic commits for the fixes.
- **Nitpicks** may be applied or consciously skipped — don't churn on style the
  project doesn't care about. There are no PR threads to resolve here (this is
  local); resolution = the code is fixed (or the finding is a deliberate
  non-issue).
- **Verify before fixing.** A reviewer's premise can be wrong. When a finding
  rests on a claim about the tree, check it — and when it does not hold, reject
  the finding with the evidence and put it in the next prompt's do-not-re-report
  list. Fixing a phantom finding is worse than leaving it: it changes working
  artifacts to satisfy a misreading.
- **Incorrect findings** — when Codex flags a pattern that is a deliberate project
  convention, document it in `REVIEW.md` at the repo root, the same as the PR
  feedback resolvers do. One entry stops Codex, Copilot, CodeRabbit, and Claude
  Code Review from raising it again. Never write it into
  the obsolete `.github/copilot-instructions.md`.

### Step 3: Re-run until it converges (REQUIRED)

Run the review again after fixes, **carrying the same Scope Brief prompt plus
anything newly established**. Note the iteration number in the prompt and add
facts verified since the last pass, so Codex does not relitigate settled ground.
**Repeat Steps 1 → 2 until a pass produces no material or substantive findings**
— per the materiality bar in `fx-dev/skills/dev/references/scope-contract.md`.

**Converged does NOT mean zero output.** Codex will keep producing immaterial
observations indefinitely; waiting for silence spends full review cycles on
wording. Stop when what remains would change nothing if it shipped uncorrected,
and list those items once, non-blocking.

**Tell Codex the bar and the settled ground in the prompt**, so it spends the
pass where it pays. Every re-run prompt MUST carry, in addition to the Scope
Brief:

```
CONVERGENCE PASS <N>. Prior passes found <count> issues; all fixed except <the
rejected ones and why>. Do not re-report them.

Report findings that would change behaviour, break a build or test, make the
artifact unimplementable, state something false, or expose a security, privacy,
or data-loss problem — including a leaked credential, internal URL, or private
identifier in documentation or examples. Wording, formatting, and counts nothing
keys on: one closing note, not findings.

Where this artifact declares a list illustrative and a rule authoritative,
assess the RULE. A further missing list entry is not a finding.

Where it records a decision with its rationale — including "unknown, gated on
X" — that is settled. If you believe it is wrong, say so once as an escalation;
do not re-argue it.

If the artifact is internally consistent and matches the tree, say so plainly.
```

- **Cap at 4 iterations.** If Codex keeps flagging the same design decision after
  4 passes, that is a human call, not more edits — escalate it **by name** and
  stop.
- Watch the shape, and count only the tiers that block. Material or substantive
  findings still arriving → keep going. A pass with none → converged, however
  many immaterial observations it produced. The same disagreement twice →
  escalate.
- When you stop, **report the per-pass trend** (`9, 4, 1, 0 material`) and say
  whether the last round's fixes were themselves reviewed.

### Step 3.5: Report out-of-scope findings, never silently apply them

If Codex reports something the Scope Brief excluded, do NOT fix it and do NOT
quietly drop it. Record it as deferred, with the exclusion that covers it. The
one exception: if the finding is *correct* and the exclusion was wrong, fix the
work and correct the brief — then say that the brief was wrong.

A run that produces **zero** out-of-scope findings is the signal the brief was
well built. Persistent out-of-scope noise means the brief is too thin — tighten
it before the next iteration rather than filtering by hand again.

### Step 4: Open the PR only when clean

A clean Codex review (alongside a clean CodeRabbit review) is the gate to PR
creation in the SDLC (`fx-dev:dev` Step 4.5 → Step 5). Do not open the PR with
unresolved actionable Codex findings.

## When to Use This Skill

- **Pre-PR self-review:** run after `coderabbit-review` and before `pr-preparer`.
  Both reviewers must come back clean before the PR is opened.

## Notes

- This skill is self-contained: it does not load other skills, and it never runs
  `fx-dev:setup` or `fx-dev:upgrade` — a missing `AGENTS.md` pointer is reported,
  not fixed here.
- `codex review` reviews local changes and never modifies your working tree.
- Keep findings resolved before opening the PR.
