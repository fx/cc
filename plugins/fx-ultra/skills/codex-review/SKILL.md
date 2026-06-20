---
name: codex-review
description: Run OpenAI Codex's AI code review LOCALLY via the `codex` CLI BEFORE opening a PR (part of pre-PR self-review). Runs one-shot, reviewing the current branch against main, prints findings to stdout, and you resolve them before the PR is opened. Use during pre-PR self-review, alongside fx-ultra:coderabbit-review.
---

# Codex Review

This skill runs OpenAI Codex's AI code review **locally, one-shot**, against the
current branch. Run it as part of pre-PR self-review — after `coderabbit-review`,
before opening the PR — fix everything it finds, and only then open the PR.

It complements (does not replace) `coderabbit-review`: CodeRabbit and Codex are
independent reviewers and each catches issues the other misses.

## How to Run (one-shot, branch vs main)

Codex has a dedicated non-interactive review subcommand. From the repo root, on
your working branch:

```bash
codex review --base main
```

This picks the current branch, diffs it against `main`, and prints the review
(highest-risk findings first) to stdout — no interactive session, no edits to
your tree (review is read-only).

Useful variants:
- **Capture to a file** for later reference (redirect stdout): `codex review --base main | tee /tmp/codex-review.md`
- **Custom focus**: append a prompt, e.g. `codex review --base main "Focus on security and data-loss risks"`
- **Uncommitted-only** (staged + unstaged + untracked): `codex review --uncommitted`

(Run `codex review --help` for the exact flags your CLI version supports — there is no dedicated `--json`/`-o` flag, so use shell redirection to capture output.)

Notes:
- Prefer `--base main` so the review scope matches what the PR will contain.
  Use `--uncommitted` only when changes aren't committed yet.
- If the workspace is externally sandboxed and Codex prompts for approvals in a
  non-interactive context, add `--dangerously-bypass-approvals-and-sandbox`
  (review is read-only, so this is safe here). Try without it first.
- Requires the `codex` CLI to be installed and already authenticated. The workspace is expected to be authed; if it is not, STOP and report to the user — do NOT run `codex login` (it is interactive).

## Workflow (fix → re-run → converge)

Treat Codex's findings like self-review feedback and loop until the review is clean.

### Step 1: Run the review

```bash
codex review --base main
```

Use `--uncommitted` instead of `--base main` for not-yet-committed work. If the
`codex` CLI is **unavailable or not authenticated**, report to the user once and
skip this pass — NEVER run `codex login` (it is interactive; the workspace is
expected to be authed already).

### Step 2: Resolve every actionable finding

- **Fix real issues** in code and tests; make atomic commits for the fixes.
- **Nitpicks** may be applied or consciously skipped — don't churn on style the
  project doesn't care about. There are no PR threads to resolve here (this is
  local); resolution = the code is fixed (or the finding is a deliberate
  non-issue).

### Step 3: Re-run until clean (REQUIRED)

Run `codex review --base main` again after fixes. **Repeat Steps 1 → 2 until
the review reports no actionable findings.**

- **Cap at 4 iterations.** If Codex keeps flagging the same design decision after
  4 passes, that is a human call, not more code edits — escalate to the user.

### Step 4: Open the PR only when clean

A clean Codex review (alongside a clean CodeRabbit review) is the gate to PR
creation in the SDLC (`fx-ultra:dev` Step 4.5 → Step 5). Do not open the PR with
unresolved actionable Codex findings.

## When to Use This Skill

- **Pre-PR self-review:** run after `coderabbit-review` and before `pr-preparer`.
  Both reviewers must come back clean before the PR is opened.

## Notes

- This skill is self-contained: it does not load other skills.
- `codex review` reviews local changes and never modifies your working tree.
- Keep findings resolved before opening the PR.
