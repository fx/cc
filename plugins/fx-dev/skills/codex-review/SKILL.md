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
codex review "SCOPE — READ CAREFULLY BEFORE REVIEWING.

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
your working branch, pass the Scope Brief prompt built above:

```bash
codex review "<scope prompt>"
```

This picks the current branch, diffs it against its base, and prints the review
(highest-risk findings first) to stdout — no interactive session, no edits to
your tree (review is read-only).

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
last resort — you will then filter out-of-scope findings by hand:
- `codex review --base main` — explicit base branch
- `codex review --uncommitted` — staged + unstaged + untracked

Capture output for later reference with shell redirection:
`codex review "<scope prompt>" | tee /tmp/codex-review.md`

(Run `codex review --help` for the exact flags your CLI version supports — there is no dedicated `--json`/`-o` flag, so use shell redirection to capture output.)

Notes:
- Review scope should match what the PR will contain.
- If the workspace is externally sandboxed and Codex prompts for approvals in a
  non-interactive context, add `--dangerously-bypass-approvals-and-sandbox`
  (review is read-only, so this is safe here). Try without it first.
- Requires the `codex` CLI to be installed and already authenticated. The workspace is expected to be authed; if it is not, STOP and report to the user — do NOT run `codex login` (it is interactive).

## Workflow (fix → re-run → converge)

Treat Codex's findings like self-review feedback and loop until the review is clean.

### Step 1: Run the review with the Scope Brief prompt

```bash
codex review "<scope prompt>"
```

If the `codex` CLI is **unavailable or not authenticated**, report to the user
once and skip this pass — NEVER run `codex login` (it is interactive; the
workspace is expected to be authed already).

### Step 2: Resolve every actionable finding

- **Fix real issues** in code and tests; make atomic commits for the fixes.
- **Nitpicks** may be applied or consciously skipped — don't churn on style the
  project doesn't care about. There are no PR threads to resolve here (this is
  local); resolution = the code is fixed (or the finding is a deliberate
  non-issue).
- **Incorrect findings** — when Codex flags a pattern that is a deliberate project
  convention, document it in `REVIEW.md` at the repo root, the same as the PR
  feedback resolvers do. One entry stops Codex, Copilot, CodeRabbit, and Claude
  Code Review from raising it again. Never write it into
  the obsolete `.github/copilot-instructions.md`.

### Step 3: Re-run until clean (REQUIRED)

Run the review again after fixes, **carrying the same Scope Brief prompt plus
anything newly established**. Note the iteration number in the prompt and add
facts verified since the last pass, so Codex does not relitigate settled ground.
**Repeat Steps 1 → 2 until the review reports no actionable findings.**

- **Cap at 4 iterations.** If Codex keeps flagging the same design decision after
  4 passes, that is a human call, not more code edits — escalate to the user.
- The cap targets a reviewer stuck on one disagreement. When each pass is instead
  surfacing genuinely new material and the finding count is falling, say so when
  you stop, and tell the user that the last round's fixes went unverified so they
  can ask for one more pass.

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
