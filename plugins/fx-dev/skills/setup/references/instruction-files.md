# Instruction Files Standard

The canonical layout for AI instruction files in a project. Every fx-dev skill
that reads or writes project conventions uses this layout — do not invent
alternatives.

## The two canonical files

| File | Owns | Audience |
|------|------|----------|
| `AGENTS.md` (repo root) | **Project conventions** — how the code is built, what patterns are intentional, stack, commands, task tracking | Every coding agent |
| `REVIEW.md` (repo root) | **PR review conventions** — what reviewers should flag, at what severity, what NOT to flag | Every automated reviewer |

Both are **regular files**. Never symlink them, and never generate one from the
other — they are what everything else points at.

Only two pointers exist, one per tool that genuinely cannot read a canonical
file:

```
AGENTS.md    <- canonical project conventions
REVIEW.md    <- canonical review conventions
CLAUDE.md    -> `@AGENTS.md` import (Claude Code does not read AGENTS.md)
.coderabbit.yaml -> lists **/REVIEW.md (not in CodeRabbit's defaults)
```

`AGENTS.md` also carries a `## Code Review Rules` section pointing at
`REVIEW.md`, because Codex reads only `AGENTS.md`.

## Who reads what (verified 2026-07-24)

| Tool | Reads `AGENTS.md` | Reads `REVIEW.md` | Bridge needed |
|------|---|---|---|
| **Copilot code review** | yes | **yes, natively** | none |
| **Codex** (CLI + PR review) | yes | no | `## Code Review Rules` section in `AGENTS.md` |
| **CodeRabbit** | yes (default pattern) | no | add `**/REVIEW.md` to `knowledge_base.code_guidelines.filePatterns` |
| **Claude Code** (CLI) | no | no | `CLAUDE.md` containing `@AGENTS.md` |

**Copilot code review reads `REVIEW.md`, `CLAUDE.md`, and `GEMINI.md` directly**
as of the [2026-07-17 changelog](https://github.blog/changelog/2026-07-17-copilot-code-review-customization-and-configurability-improvements/):
*"Copilot code review now reads `REVIEW.md`, `GEMINI.md`, and `CLAUDE.md` files
from your repository, so your customizations are understood regardless of where
they live."* It also reads instructions from the **head branch**, so instruction
changes are testable in the same PR that makes them.

> **Do not build a `.github/copilot-instructions.md` bridge.** Earlier versions
> of this standard symlinked that path to `../REVIEW.md` because Copilot could
> not follow file references. That is obsolete, and it actively misleads: a
> symlink there is a second path to the same rules that some tooling reports as
> a missing file. If a repo still has one, delete it and move any unique content
> into `REVIEW.md`.

Only one real constraint remains: **Claude Code CLI does not read `AGENTS.md`**,
so `CLAUDE.md` exists as a one-line `@AGENTS.md` import.

## `REVIEW.md` is pasted verbatim

Every reviewer that consumes `REVIEW.md` takes it as-is: `@` imports are **not**
expanded and referenced files are **not** read. Write the rules directly in the
file — never `See docs/conventions.md`.

Keep it focused. A long `REVIEW.md` dilutes the rules that matter. Put the
highest-value rules first: Copilot weights roughly the first 4000 characters
most heavily.

## Where feedback resolvers write

When an automated reviewer's feedback is **INCORRECT** (it conflicts with a
deliberate project convention), the fix goes in **`REVIEW.md`** — always, for
every reviewer. One file, so suppressing a false positive suppresses it for
Codex, Copilot, and CodeRabbit at once.

`AGENTS.md` is for how the code is *written*. `REVIEW.md` is for how the code is
*reviewed*. When a rule is "this pattern is intentional, don't flag it", it is a
review rule.

## CodeRabbit needs explicit configuration

CodeRabbit's default `filePatterns` cover `**/AGENTS.md` and `**/CLAUDE.md` but
**not** `**/REVIEW.md`. Without this config it never sees the review conventions:

```yaml
knowledge_base:
  code_guidelines:
    enabled: true
    # Custom patterns APPEND to the defaults, they do not replace them.
    filePatterns:
      - "**/REVIEW.md"
```

Patterns are **case-sensitive**: `review.md` does not match `**/REVIEW.md`.

## Migration from a pre-existing repo

**`fx-dev:upgrade` performs this migration** — it is intentionally intrusive and asks for confirmation first. `fx-dev:setup` only creates what is missing and will refuse to touch a legacy layout. The table below is what upgrade applies.

| Found | Do |
|-------|-----|
| `CLAUDE.md` with project conventions, no `AGENTS.md` | Move it to `AGENTS.md`, create `CLAUDE.md` containing `@AGENTS.md` |
| `CLAUDE.md` and `AGENTS.md` both with content | Merge into `AGENTS.md`, reduce `CLAUDE.md` to `@AGENTS.md` plus any genuinely Claude-only rules |
| `.github/copilot-instructions.md` with review rules, no `REVIEW.md` | Move its content to `REVIEW.md` and delete the original |
| `.github/copilot-instructions.md` **symlinked** to `REVIEW.md` (old layout) | Delete the symlink; `REVIEW.md` is read directly now |
| Neither `REVIEW.md` nor `.github/copilot-instructions.md` | Create `REVIEW.md` |

Never delete convention content during migration — move it.

Use `git mv <src> <dst> 2>/dev/null || mv <src> <dst>`: the source may be
untracked during first-time setup, and `git mv` aborts on untracked paths.

## Symlinks in legacy repos

The canonical paths must end up as **regular files**. A legacy repo may have
symlinked one of them — most commonly `CLAUDE.md -> AGENTS.md`, and occasionally
`CLAUDE.md -> ~/.claude/CLAUDE.md`. Writing "through" a symlink edits its target,
so classify before writing:

```bash
canonicalize() {
  # Portable: GNU realpath -> GNU readlink -f -> Python (macOS has no readlink -f)
  realpath "$1" 2>/dev/null \
    || readlink -f "$1" 2>/dev/null \
    || python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
for p in AGENTS.md CLAUDE.md REVIEW.md; do
  [ -L "$p" ] || continue
  t=$(canonicalize "$p")
  case "${t:-UNRESOLVED}" in
    "$repo_root"/*) echo "$p: symlink -> in-repo: $t" ;;
    *)              echo "$p: symlink -> ESCAPES REPO: ${t:-unresolvable}" ;;
  esac
done
```

- **In-repo target** → replace the link with a regular file holding the target's
  content, so later writes land in the repo. A `CLAUDE.md -> AGENTS.md` link has
  nothing to merge: just delete it and write the `@AGENTS.md` pointer.
- **Target escapes the repo, or is unresolvable** → **do NOT read or copy the
  contents.** `~/.claude/CLAUDE.md` holds private, machine-wide instructions;
  inlining it into a tracked, possibly public, `AGENTS.md` leaks them. Delete the
  link, seed the file fresh, and report the path so the user can port anything
  they still want. Never inline it for them.

This is a privacy boundary, not a style preference. **When in doubt, do not
copy.**
