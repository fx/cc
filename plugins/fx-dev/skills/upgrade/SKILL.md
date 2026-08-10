---
name: upgrade
description: "Migrate a repo's AI INSTRUCTION FILES to current fx-dev conventions — moving CLAUDE.md content into AGENTS.md, folding .github/copilot-instructions.md into REVIEW.md, resolving instruction-file symlinks. Also offers duvet requirements-traceability adoption (opt-in, prompted, declinable) on every run. Intentionally intrusive; rewrites and deletes those files. Use ONLY for instruction-file/convention migration: 'migrate conventions', 'update instruction files', 'upgrade fx-dev conventions', 'migrate to AGENTS.md', 'adopt duvet', or when fx-dev:setup reports a legacy layout. NOT for upgrading dependencies, packages, frameworks, language versions, or databases — those are ordinary code work, use fx-dev:dev."
---

# Upgrade

Migrates a repository to the **current** fx-dev conventions. Unlike `fx-dev:setup`,
this skill is **intentionally intrusive**: it moves content between files,
rewrites files in place, resolves symlinks, and deletes obsolete paths.

## Relationship to `fx-dev:setup`

The two skills split along one line: **who is allowed to destroy something.**

| | `fx-dev:setup` | `fx-dev:upgrade` |
|---|---|---|
| Invocation | **Automatic**, on every `/spec-writer` and `/project-management` call | **Explicit only** — a human or a skill asks for it by name |
| May create missing files | yes | yes (via setup) |
| May append a missing marker block | yes | yes |
| May move, merge, overwrite, or delete | **never** | yes, that is the point |
| On finding a legacy layout | reports it and stops | migrates it |

`setup` runs unattended dozens of times a day, so it must never make a change a
user would want to review. `upgrade` runs when asked, once, and every change it
makes is reviewable in `git diff`.

**Never invoke `upgrade` automatically from another skill.** If a skill detects
a legacy layout, it reports and recommends — it does not migrate.

## When to Use

**This skill migrates instruction files only.** A bare "upgrade" is ambiguous — "upgrade React", "upgrade the database", "upgrade to Node 24" are ordinary code work and belong to `fx-dev:dev`. If the request does not clearly concern AI instruction files or fx-dev conventions, **ask before assuming**; this skill rewrites files.

- User says "migrate conventions", "update instruction files", "upgrade fx-dev conventions", "migrate to AGENTS.md"
- `fx-dev:setup` reported a legacy layout and told the user to run this
- After pulling a new fx-dev version that changed a convention
- User says "adopt duvet" or asks for requirements traceability — Step 6 offers it, and it runs even when there is nothing to migrate, so this skill is a valid entry point for adoption alone

## Migration Registry

Each migration is independent, self-detecting, and idempotent — running
`upgrade` on an already-current repo finds no migration to apply and changes
nothing here. Add new migrations here as conventions change.

The duvet offer (Step 6) is **not** a migration and is not in this registry: it
runs on every invocation regardless of what this table detects, and on acceptance
it writes files even on an otherwise no-op run.

| ID | Migration | Detect (any one is enough) |
|----|-----------|--------|
| **M1** | Instruction files → `AGENTS.md` / `REVIEW.md` | `AGENTS.md` or `REVIEW.md` missing; `CLAUDE.md` has non-pointer content; `.github/copilot-instructions.md` exists; any canonical path is a symlink; `AGENTS.md` lacks the Codex pointer; `AGENTS.md` still holds stale task-tracking language (M1.6); `.coderabbit.yaml` lacks `**/REVIEW.md` or has `code_guidelines.enabled: false` |

## Workflow

### Step 1: Detect

Run every migration's detector. Collect the ones that apply.

**Never read through a symlink during detection.** A `CLAUDE.md -> ~/.claude/CLAUDE.md` link means a bare `grep CLAUDE.md` reads the user's private, machine-wide instructions — before the user has approved anything. Classify a path first; only content-inspect it once it is known to be a regular in-repo file.

```bash
canonicalize() {
  # Portable: GNU realpath -> GNU readlink -f -> Python (macOS has no readlink -f)
  realpath "$1" 2>/dev/null \
    || readlink -f "$1" 2>/dev/null \
    || python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null
}
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# is_plain <path> -> true only for a regular file that is NOT a symlink
is_plain() { [ -f "$1" ] && [ ! -L "$1" ]; }

echo "--- canonical paths ---"
for p in AGENTS.md CLAUDE.md REVIEW.md; do
  if [ -L "$p" ]; then
    t=$(canonicalize "$p")
    case "${t:-UNRESOLVED}" in
      "$repo_root"/*) echo "$p: SYMLINK -> in-repo: $t  [MIGRATE]" ;;
      *)              echo "$p: SYMLINK -> ESCAPES REPO: ${t:-unresolvable}  [MIGRATE, do not read]" ;;
    esac
  elif [ -f "$p" ]; then
    echo "$p: regular file ($(wc -l < "$p") lines)"
  else
    echo "$p: MISSING  [MIGRATE]"
  fi
done

echo "--- legacy paths ---"
ls -l .github/copilot-instructions.md 2>/dev/null && echo "  [MIGRATE]" || echo "copilot-instructions: absent"

echo "--- pointers (only inspected when the path is a plain in-repo file) ---"
if is_plain CLAUDE.md; then
  grep -q '^@AGENTS\.md' CLAUDE.md && echo "CLAUDE.md: pointer present" || echo "CLAUDE.md: NOT a pointer  [MIGRATE]"
else
  echo "CLAUDE.md: skipped (symlink or missing — already classified above)"
fi
if is_plain AGENTS.md; then
  grep -q '## Code Review Rules' AGENTS.md && echo "AGENTS.md: Codex pointer present" || echo "AGENTS.md: Codex pointer MISSING  [MIGRATE]"
else
  echo "AGENTS.md: skipped (symlink or missing — already classified above)"
fi

echo "--- stale task language (M1.6) ---"
if is_plain AGENTS.md; then
  grep -nEi 'PROJECT\.md|- \[x\]|mark.*(done|complete)|tasks?.*(in|under|go).*docs/specs' AGENTS.md \
    && echo "  ^ review these: obsolete task rules may survive alongside the current marker  [MIGRATE]" \
    || echo "AGENTS.md: no stale task language"
else
  echo "AGENTS.md: skipped (symlink or missing)"
fi

echo "--- coderabbit config ---"
if is_plain .coderabbit.yaml; then
  cat .coderabbit.yaml
else
  echo ".coderabbit.yaml: absent or a symlink  [MIGRATE]"
fi
```

`.coderabbit.yaml` is printed rather than grepped because both halves matter and a filename match proves neither. **M1.5 applies unless both are true:** `knowledge_base.code_guidelines.enabled` is `true` (or absent, which defaults to enabled) **and** `**/REVIEW.md` appears in `filePatterns`. A config that lists the pattern under `enabled: false` still needs migrating.

**If no migration applies**, note "Already current — nothing to migrate" and skip straight to **Step 6** — the duvet offer runs whether or not a migration applied — then still run **Step 7**, so the report and its `git status` cover anything adoption wrote. Do not proceed to Step 2.

### Step 2: Build the plan

For each applicable migration, work out the exact per-file actions. Be concrete —
name real files and real line counts, not categories.

Classify every symlink **before** planning to copy anything:

| Classification | Plan |
|---|---|
| `SYMLINK -> in-repo` | Replace the link with a regular file holding the target's content. A `CLAUDE.md -> AGENTS.md` link has no content of its own — plan a delete, not a merge |
| `SYMLINK -> ESCAPES REPO` or unresolvable | **Plan to delete the link and seed the path fresh. Do NOT plan to copy the contents, and do not read them.** `~/.claude/CLAUDE.md` holds private, machine-wide instructions; inlining them into a tracked, possibly public, `AGENTS.md` leaks them. Report the path so the user can port what they want, themselves |

This is a privacy boundary, not a style preference. **When in doubt, do not copy.**

### Step 3: Confirm before touching anything

**Present the plan and get explicit approval.** Nothing is written before this.

Use AskUserQuestion with the concrete plan as the question body:

```
AskUserQuestion:
  question: "Upgrade will rewrite these files. Proceed?"
  header: "Upgrade"
  options:
    - label: "Proceed"
      description: "Apply all planned migrations"
      preview: |
        M1: Instruction files

        CLAUDE.md    -> move 412 lines into AGENTS.md,
                        replace with `@AGENTS.md`
        .github/copilot-instructions.md
                     -> merge 38 lines into REVIEW.md, delete
        AGENTS.md    -> append `## Code Review Rules` pointer
        .coderabbit.yaml -> create with **/REVIEW.md
    - label: "Cancel"
      description: "Change nothing"
```

List **every** file that will be modified, moved, or deleted, with the size of
what moves. A user who cannot tell from the plan what their repo will look like
afterwards has not been given a real choice.

If the user cancels, stop immediately and change nothing.

### Step 4: Apply

Work migration by migration. Prefer `git mv` so history follows the content, and
fall back to plain `mv` — the file may be untracked, and `git mv` aborts on
untracked paths:

```bash
git mv <src> <dst> 2>/dev/null || mv <src> <dst>
```

**Never delete convention content.** Every rule in a legacy file must land in
`AGENTS.md` or `REVIEW.md`, or be reported as deliberately dropped. "I rewrote
the file and the old rules are gone" is a failed upgrade.

Do not `git add` or commit. Leave everything in the working tree so the user
reviews it with `git diff` and commits it themselves.

### Step 5: Seed missing instruction files — instruction files only

Create whatever the migration left absent, **limited to the instruction-file
layout**: `AGENTS.md`, `REVIEW.md`, the `CLAUDE.md` pointer, the `## Code Review
Rules` section, `.coderabbit.yaml`. Use the exact seed blocks from
`fx-dev:setup` Steps 6.3, 7, 8.2, 8.3 and 9.

**Do NOT invoke `fx-dev:setup` here.** It also scaffolds `docs/specs`,
`docs/changes`, `tasks.md`, and the index files. This skill migrates instruction
files; **silently** adding a documentation system the user never asked for is a
different change, and it would land in the same diff.

The operative word is *silently*. Step 6 adds something larger — a CI job and a
Rust toolchain dependency — and that is allowed precisely because it goes through
an explicit prompt the user can decline. Nothing here may add anything the user
did not ask for and was not asked about.

If the repo has no `docs/` structure and looks like it wants one, say so in the
Step 7 report and let the user run `/fx-dev:setup` themselves.

### Step 6: Offer duvet adoption (only if not already adopted)

**This runs BEFORE the Step 7 report, and that ordering is load-bearing.**
Adoption writes up to five files (a mise config edit, `.duvet/config.toml`,
`.duvet/snapshot.txt`, a `.gitignore` edit, a CI workflow). Reporting first and
adopting after would print "Nothing has been committed / review with `git diff`"
and *then* create files that appear in no report at all — and the Step 7
`git status` verification would run before the writes it is meant to verify.

Runs on every invocation, including when Step 1 found nothing to migrate — an
already-current repo can still be missing requirements traceability. On the Step 1
early-exit path ("Already current — nothing to migrate"), come here, then still
run Step 7 so `git status` covers whatever adoption wrote.

```bash
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
test -d "$repo_root/.duvet" && echo "duvet: adopted" || echo "duvet: not adopted"
```

The gate is the **repository root**, so resolve it explicitly — a bare
`test -d .duvet` is cwd-relative and would offer adoption to a duvet repo
whenever upgrade runs from a subdirectory.

- **`duvet: adopted`** → do nothing and say nothing. Never re-offer, never nag.
- **`duvet: not adopted`** → offer adoption once, and on acceptance follow
  **`fx-dev:setup` → `references/duvet-adoption.md`**. That file is the canonical
  procedure, shared with setup: read it before offering, and do not restate or
  reinvent any of its steps here.

Adoption is **not** part of M1 and not an instruction-file migration, so it never
appears in the Step 3 plan and never blocks it. It carries its own approval: the
adopt-or-not question, plus — on acceptance — one or more follow-ups the procedure
cannot infer safely (install method, `[[source]]` patterns, keep-or-revert with no
GitHub Actions). A decline changes nothing. If the user declines, finish the run
normally and do not raise duvet again during it.

**Why adding a CI job here is legitimate when scaffolding `docs/` in Step 5 is
not.** The distinction is not size — adoption is the larger change of the two: a
CI job, a Rust toolchain dependency, and a mode switch in `fx-dev:spec-writer`.
The distinction is **consent**. Step 5 refuses `docs/` because nothing in the
user's request or the plan they approved mentioned a documentation system; it
would arrive silently, inside a diff labelled "instruction-file migration".
Adoption arrives only through an explicit, named prompt describing what it
installs and what it costs, with a decline that writes nothing. Opt-in behind a
prompt is a different act from silent addition, and that — not scope — is the line
this skill draws. If adoption ever became automatic, Step 5's rule would forbid it
too.

Like everything else this skill does, nothing is committed — adoption leaves its
files in the working tree for review. Any failure part-way through is an ERROR:
report it, name what was written, and do not report a clean upgrade over it.

### Step 7: Verify and report

Runs last, after Step 6, so `git status` sees everything — migrations and adoption
both.

```bash
git status --short
git diff --stat
```

Report what moved, and confirm the end state:

```
Upgraded to current fx-dev conventions.

M1: Instruction files
  CLAUDE.md    412 lines -> AGENTS.md, now a 1-line @AGENTS.md pointer
  .github/copilot-instructions.md  38 lines -> REVIEW.md, deleted
  AGENTS.md    + ## Code Review Rules pointer
  .coderabbit.yaml  created

<if Step 6 adopted duvet, include the reference's report block here — it is
 part of this diff and must not be omitted>

Review with: git diff HEAD
Nothing has been committed.
```

**The report must cover Step 6.** If duvet was adopted, its files are in this same
working tree and this is the only report the user gets — reproduce the report block
from `references/duvet-adoption.md`, including its conditional CI line. On the
Step 1 early-exit path, report adoption alone rather than skipping the report:
"Already current — nothing to migrate" is false once adoption has written files.

If anything could not be migrated automatically, say so explicitly and name the
file — never report a clean upgrade over a partial one.

---

## M1: Instruction files → `AGENTS.md` / `REVIEW.md`

The canonical layout is defined in `fx-dev:setup` → `references/instruction-files.md`.
Read it before applying this migration.

Target state:

```
AGENTS.md         <- project conventions (regular file)
REVIEW.md         <- review conventions (regular file)
CLAUDE.md         -> a single `@AGENTS.md` line
.coderabbit.yaml  -> lists **/REVIEW.md
```

### M1.0 Missing canonical files

If `AGENTS.md` or `REVIEW.md` is simply absent — no legacy file to migrate from — there is nothing to move, but the repo is still not current. Do not report "already current": let the migration apply so **Step 5 seeds the missing file** from the seed blocks. Step 5 does this directly and must not invoke `fx-dev:setup`, which would also scaffold `docs/`.

### M1.1 `CLAUDE.md` → `AGENTS.md`

| Found | Apply |
|-------|-------|
| `AGENTS.md` missing, `CLAUDE.md` is a regular file with content | Move it: `git mv CLAUDE.md AGENTS.md 2>/dev/null \|\| mv CLAUDE.md AGENTS.md`, then write the pointer (M1.2) |
| Both are regular files with content | Merge `CLAUDE.md` into `AGENTS.md`, then write the pointer |
| `CLAUDE.md` is a symlink to `AGENTS.md` | Delete the link — it has no content of its own |
| `CLAUDE.md` is a symlink elsewhere in-repo | Replace with a regular file holding the target's content, then treat as the rows above |
| `CLAUDE.md` symlink escapes the repo | Delete the link. **Do not read or copy the target.** Report the path |
| `CLAUDE.md` already contains `@AGENTS.md` | Nothing to do |

**Split out genuinely Claude-only rules.** A wholesale move publishes rules
written for Claude Code alone to Codex, Copilot, and CodeRabbit. Rules naming
Claude Code mechanics — `/`-commands, skills, plan mode, `@`-imports, thinking
budgets, hooks, MCP servers — belong under the `@AGENTS.md` line in `CLAUDE.md`.
When it is ambiguous, leave it in `AGENTS.md`; cross-agent conventions are the
common case.

### M1.2 The `CLAUDE.md` pointer

After the move, `CLAUDE.md` is exactly this, and usually nothing else:

```markdown
@AGENTS.md
```

Claude-only rules, if any, go **below** that line with a blank line between.

Claude Code does not read `AGENTS.md`, which is the only reason this file exists.

### M1.3 `.github/copilot-instructions.md` → `REVIEW.md`

Obsolete: Copilot code review reads `REVIEW.md` directly
([changelog, 2026-07-17](https://github.blog/changelog/2026-07-17-copilot-code-review-customization-and-configurability-improvements/)).

| Found | Apply |
|-------|-------|
| Regular file, `REVIEW.md` missing | Move it to `REVIEW.md` |
| Regular file, `REVIEW.md` exists | Merge its rules into `REVIEW.md`, then delete it |
| Symlink to `REVIEW.md` (old fx-dev layout) | Delete the link — the content is already in `REVIEW.md` |
| Symlink elsewhere in-repo | Merge the target's content into `REVIEW.md`, then delete the link |
| Symlink escaping the repo | Delete the link. **Do not read or copy the target.** Report the path |
| Absent | Nothing to do |

End state: the path does not exist. Never recreate it, and never symlink it.

### M1.4 The Codex pointer in `AGENTS.md`

Codex reads only `AGENTS.md`. If `## Code Review Rules` is absent, append
**exactly**:

```markdown

## Code Review Rules

Read `REVIEW.md` at the repository root and apply it in full as the review rules for this repo. It is the canonical review-conventions file.
```

Pointer only — never copy rules out of `REVIEW.md` into `AGENTS.md`.

### M1.5 `.coderabbit.yaml`

CodeRabbit's defaults cover `**/AGENTS.md` and `**/CLAUDE.md` but **not**
`**/REVIEW.md`, so this is the only thing that gets review conventions to it.

| Found | Apply |
|-------|-------|
| No `.coderabbit.yaml` | Create it with the block below |
| Exists, `code_guidelines.enabled: false` | Set `enabled: true` and add the pattern — but **call this out explicitly in the Step 3 plan**. Someone disabled it deliberately, and flipping it back changes review behaviour beyond instruction-file plumbing. If the user declines this one, leave the file alone and report that CodeRabbit will not see `REVIEW.md` |
| Exists, `**/REVIEW.md` not in `filePatterns` | Add it — including when `filePatterns` is absent, since the defaults do not cover it |
| Exists, `enabled` true/absent **and** `**/REVIEW.md` present | Nothing to do |

```yaml
knowledge_base:
  code_guidelines:
    enabled: true
    # Custom patterns APPEND to the defaults, they do not replace them.
    filePatterns:
      - "**/REVIEW.md"
```

Patterns are case-sensitive: `review.md` does not match `**/REVIEW.md`.

### M1.6 Stale task-tracking language

Legacy instruction files often carry task rules that predate `/project-management`.

**Remove the obsolete task-tracking clauses, never the enclosing section.** A heading like `## Conventions` may hold a `- [x]` task rule *alongside* security, testing, and deployment rules that are still perfectly valid. Deleting the section to get at the task rule destroys all of them.

| Remove | Keep |
|---|---|
| Sentences and bullets describing how to mark tasks done (`- [x]`, "mark complete", PR-number conventions) | Every rule in the same section that is not about task tracking |
| References to `PROJECT.md` or `docs/specs/` **as the place tasks live** | References to `docs/specs/` as the place specs live |
| A heading whose body is *entirely* obsolete task rules | A heading with any surviving content |

If a section is mixed, edit the lines and leave the heading. If you cannot tell whether a rule is task-tracking, **keep it** and mention it in the Step 7 report — a stale rule is recoverable, a deleted one is not.

Then let Step 5 insert the current `/project-management` block.

Section deletion is the reason this lives here and not in setup: removing anything from a user's file must be reviewed.

## Rules

- **Explicit invocation only** — never auto-invoked, never called from a skill's pre-flight
- **Plan, confirm, then write** — nothing is modified before the user approves
- **Never delete convention content** — move it, or report it as dropped
- **Never copy from a symlink that escapes the repo** — privacy boundary, no exceptions
- **Never commit** — leave changes in the working tree for review
- **Duvet is offered, never assumed** — if `.duvet/` is absent, ask (Step 6); if it exists, stay silent. The procedure lives only in `fx-dev:setup` → `references/duvet-adoption.md`
- **Migrations are idempotent** — a second run on a migrated repo finds no migration to apply and changes nothing under M1. **This does not extend to Step 6:** the duvet offer runs on every invocation, so a rerun on a repo that has no `.duvet/` will offer adoption again and, if accepted, write files. That is not a broken invariant, it is a different one — M1 is idempotent, the duvet *offer* is unconditional, and acceptance is a new decision each time. Once `.duvet/` exists the offer goes silent and the whole run is a no-op again. Never describe a rerun as "changes nothing" without checking whether Step 6 wrote anything
- **Partial is reported** — if a migration could not complete, name the file and say so
