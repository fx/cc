# Instruction Files Standard

The canonical layout for AI instruction files in a project. Every fx-dev skill
that reads or writes project conventions uses this layout — do not invent
alternatives.

## The two canonical files

| File | Owns | Audience |
|------|------|----------|
| `AGENTS.md` (repo root) | **Project conventions** — how the code is built, what patterns are intentional, stack, commands, task tracking | Every coding agent |
| `REVIEW.md` (repo root) | **PR review conventions** — what reviewers should flag, at what severity, what NOT to flag | Every automated reviewer |

Everything else is a **pointer** that exists only because some tool cannot read
the canonical file natively.

```
AGENTS.md                        <- canonical project conventions
REVIEW.md                        <- canonical review conventions
CLAUDE.md                        -> pointer: `@AGENTS.md` + Claude-only extras
.github/copilot-instructions.md  -> symlink to ../REVIEW.md
.coderabbit.yaml                 -> lists **/REVIEW.md in filePatterns
```

## Who reads what (verified 2026-07)

| Tool | Reads natively | Bridge needed |
|------|----------------|---------------|
| **Codex** (CLI + PR review) | `AGENTS.md` | `## Code Review Rules` section in `AGENTS.md` pointing at `REVIEW.md` |
| **Copilot code review** | `.github/copilot-instructions.md`, `.github/instructions/**/*.instructions.md`, `AGENTS.md` | `.github/copilot-instructions.md` is a **symlink** to `../REVIEW.md` |
| **CodeRabbit** | defaults include `**/AGENTS.md`, `**/CLAUDE.md`, `.github/copilot-instructions.md` | add `**/REVIEW.md` to `knowledge_base.code_guidelines.filePatterns` |
| **Claude Code Review** (GitHub App) | `CLAUDE.md` (as nits) + `REVIEW.md` (root, verbatim, highest priority) | none — reads `REVIEW.md` natively |
| **Claude Code** (CLI) | `CLAUDE.md` only | `CLAUDE.md` imports `@AGENTS.md` |

Two constraints drive the design:

1. **Claude Code CLI does not read `AGENTS.md`.** Hence `CLAUDE.md` exists as a
   one-line `@AGENTS.md` import.
2. **Copilot code review does not follow file references** — GitHub's docs say to
   copy content in rather than link to it. A symlink sidesteps this without
   duplicating content: the path Copilot looks for resolves to `REVIEW.md`.

## `REVIEW.md` is pasted verbatim

Claude Code Review injects `REVIEW.md` into the review system prompt as-is.
`@` imports are **not** expanded and referenced files are **not** read. Write the
rules directly in the file — never `See docs/conventions.md`.

Keep it focused. A long `REVIEW.md` dilutes the rules that matter.

## Where feedback resolvers write

When an automated reviewer's feedback is **INCORRECT** (it conflicts with a
deliberate project convention), the fix goes in **`REVIEW.md`** — always, for
every reviewer. One file, so suppressing a false positive suppresses it for
Copilot, CodeRabbit, Codex, and Claude Code Review at once.

Do not write recurrence rules into `.github/copilot-instructions.md`: it is a
symlink, and editing it edits `REVIEW.md` anyway. Address the real path.

`AGENTS.md` is for how the code is *written*. `REVIEW.md` is for how the code is
*reviewed*. When a rule is "this pattern is intentional, don't flag it", it is a
review rule.

## Creating the symlink

Move the content to `REVIEW.md` **first** — `git mv .github/copilot-instructions.md REVIEW.md 2>/dev/null || mv .github/copilot-instructions.md REVIEW.md`, since the file may be untracked — then put the pointer in its place:

```bash
mkdir -p .github
rm -f .github/copilot-instructions.md
ln -s ../REVIEW.md .github/copilot-instructions.md
git add .github/copilot-instructions.md
```

Verify it is stored as a symlink in git (mode `120000`):

```bash
git ls-files -s .github/copilot-instructions.md
# 120000 <sha> 0	.github/copilot-instructions.md
```

### Fallback: generated mirror

If the repo has `core.symlinks=false` (some Windows checkouts), the symlink
becomes a plain text file containing the path and Copilot will read garbage. In
that case fall back to a generated mirror at
`.github/instructions/review.instructions.md`:

```markdown
---
applyTo: "**"
---
<!-- GENERATED from REVIEW.md — DO NOT EDIT. Regenerate after any REVIEW.md change. -->

<verbatim copy of REVIEW.md>
```

**A mirror is a standing obligation, not a one-time copy.** It goes stale the
moment `REVIEW.md` changes, and a stale mirror is worse than none — Copilot keeps
enforcing rules the project has already retracted.

**Anything that writes `REVIEW.md` MUST regenerate the mirror in the same
change.** That includes every feedback resolver and every manual edit:

```bash
# Run this immediately after any write to REVIEW.md
if [ -f .github/instructions/review.instructions.md ] \
   && ! [ -L .github/copilot-instructions.md ]; then
  { printf -- '---\napplyTo: "**"\n---\n'
    printf -- '<!-- GENERATED from REVIEW.md — DO NOT EDIT. Regenerate after any REVIEW.md change. -->\n\n'
    cat REVIEW.md
  } > .github/instructions/review.instructions.md
  echo "Mirror regenerated"
fi
```

Prefer the symlink and use the mirror only when the symlink genuinely cannot be
stored. Tell the user when you fall back, so the sync obligation is visible.

## Migration from a pre-existing repo

| Found | Do |
|-------|-----|
| `CLAUDE.md` with project conventions, no `AGENTS.md` | Move it to `AGENTS.md`, create `CLAUDE.md` containing `@AGENTS.md` |
| `CLAUDE.md` and `AGENTS.md` both with content | Merge into `AGENTS.md`, reduce `CLAUDE.md` to `@AGENTS.md` plus any genuinely Claude-only rules |
| `.github/copilot-instructions.md` with review rules, no `REVIEW.md` | Move its content to `REVIEW.md`, replace the file with the symlink |
| Neither `REVIEW.md` nor `.github/copilot-instructions.md` | Create `REVIEW.md`, then the symlink |

Never delete convention content during migration — move it.
