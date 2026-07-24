---
name: setup
description: "Initialize the docs/ folder structure for spec-driven development and scaffold the standard AI instruction files (AGENTS.md, REVIEW.md, CLAUDE.md pointer, copilot-instructions symlink) so task tracking defers to /project-management. Called automatically by /spec-writer and /project-management. Also use when user says 'setup docs', 'initialize docs', 'create docs structure'."
---

# Setup

This skill scaffolds the `docs/` folder structure required for spec-driven development and establishes the standard AI instruction files (`AGENTS.md`, `REVIEW.md`, plus the `CLAUDE.md` and `.github/copilot-instructions.md` pointers) so that task tracking defers to the `/project-management` skill. It is called automatically by `/spec-writer` and `/project-management` as a prerequisite.

**Read `references/instruction-files.md` before touching any instruction file.** It defines the canonical layout, which tool reads which file, and how to migrate an existing repo. Do not invent alternative file names or locations.

## When to Use

- **Automatically** — Invoked by `/spec-writer` and `/project-management` at the start of every invocation
- **Manually** — When user says "setup docs", "initialize docs", "create docs structure", or "setup project"
- **Fresh projects** — When starting a new project that will use spec-driven development

## Workflow

### Step 1: Check Existing Structure

```bash
ls -la docs/ 2>/dev/null
ls docs/specs/ docs/changes/ 2>/dev/null
test -f docs/tasks.md && echo "tasks.md exists" || echo "tasks.md missing"
test -f docs/index.yml && echo "index.yml exists" || echo "index.yml missing"
test -f docs/index.md && echo "index.md exists" || echo "index.md missing"
```

**If all docs/ files exist**, skip to Step 6 (instruction files check). Do not overwrite existing docs/ files.

**Instruction files are checked on every run**, even when `docs/` is already complete.

**If partially exists**, only create what's missing in Steps 2-5. Never overwrite existing files.

### Step 2: Create Directory Structure

```bash
mkdir -p docs/specs
mkdir -p docs/changes
```

### Step 3: Create `docs/tasks.md`

Only if it doesn't exist. If `docs/PROJECT.md` exists, offer to migrate it.

```markdown
# Tasks

Catch-all task list for work not tracked in a specific [change document](changes/).

## Backlog

## Completed
```

**Migration from PROJECT.md:** If `docs/PROJECT.md` exists, read it and migrate tasks to the new format. Use AskUserQuestion to confirm:

```
AskUserQuestion:
  question: "Found existing docs/PROJECT.md. Migrate tasks to docs/tasks.md?"
  options:
    - label: "Yes, migrate"
      description: "Move tasks to docs/tasks.md and keep PROJECT.md as backup"
    - label: "No, start fresh"
      description: "Create empty docs/tasks.md, leave PROJECT.md untouched"
```

### Step 4: Create `docs/index.yml`

Only if it doesn't exist. **Use this exact structure — field names and format are strict:**

```yaml
# Documentation Index
# Auto-updated by /spec-writer and /project-management skills

specs:
  # - name: <spec-name>
  #   path: specs/<spec-name>/
  #   description: <one-line description>
  #   status: active | deprecated

changes:
  # - id: "NNNN"
  #   name: <change-name>
  #   path: changes/NNNN-<change-name>.md
  #   description: <one-line description>
  #   spec: <spec-name>
  #   status: draft | in-progress | complete
  #   depends_on: []
```

### Step 5: Create `docs/index.md`

Only if it doesn't exist. **Use these exact column names — table schema is strict:**

```markdown
# Documentation

## Specs

| Spec | Description | Status |
|------|-------------|--------|

## Changes

| # | Change | Spec | Status | Depends On |
|---|--------|------|--------|------------|
```

---

### Step 6: Ensure `AGENTS.md` Defers to /project-management

`AGENTS.md` at the repo root is the canonical project-conventions file. Codex, Copilot, and CodeRabbit all read it natively.

#### 6.1 Migrate a legacy `CLAUDE.md` first

```bash
test -f AGENTS.md && echo "AGENTS.md exists" || echo "AGENTS.md missing"
test -L CLAUDE.md && echo "CLAUDE.md is a symlink" || { test -f CLAUDE.md && echo "CLAUDE.md is a regular file" || echo "CLAUDE.md missing"; }
```

Handle these cases in order — **check `test -L CLAUDE.md` before anything else**, because writing "through" a symlink edits its target, not the link:

- **`CLAUDE.md` is a symlink** (a common `ln -s AGENTS.md CLAUDE.md` setup) → it has no content of its own. Delete the link now; Step 7 writes a regular pointer file in its place. Do **not** treat it as content to merge, and never append to it — that would edit `AGENTS.md` and produce an `AGENTS.md` that imports itself.
  ```bash
  test -L CLAUDE.md && rm CLAUDE.md
  ```
  If the symlink pointed somewhere **other** than `AGENTS.md`, read its target first and merge that content into `AGENTS.md` before deleting the link.
- **`AGENTS.md` missing, `CLAUDE.md` is a regular file with real content** → move it, then create the `CLAUDE.md` pointer in Step 7. Use `git mv CLAUDE.md AGENTS.md 2>/dev/null || mv CLAUDE.md AGENTS.md` — the file may be untracked, and `git mv` aborts on untracked paths.
- **Both exist as regular files with content** → merge `CLAUDE.md`'s content into `AGENTS.md`, keeping any genuinely Claude-only rules aside for the pointer file. Never delete convention content — move it.
- **Neither exists** → create `AGENTS.md` with just the block from 6.3.

#### 6.2 Check for CURRENT language

Search `AGENTS.md` for the exact string `/project-management`. This is the only valid marker.

- **If `/project-management` is found** → current. Skip to Step 7.
- **If NOT found** → missing or stale. Proceed to 6.3.

#### 6.3 Handle stale or missing language

**If stale task-tracking language exists** (anything referencing `PROJECT.md`, `docs/specs/` for tasks, `- [x]`, `mark.*done`, or task-tracking rules that don't mention `/project-management`):
- Remove the entire stale section
- Insert the new block in its place

**If no task-tracking language exists at all:**
- Append the new block to the end of `AGENTS.md`

**The EXACT block to insert (do NOT add to, modify, or expand this):**

```markdown

## Task Tracking

**You MUST load the `/project-management` skill before creating, modifying, or completing any task.** It owns all task-tracking rules and knows where tasks belong. Do not manage tasks without it.
```

**⛔ FORBIDDEN: Do NOT add ANY of the following to AGENTS.md:**
- Descriptions of docs/ folder structure
- Rules about `- [x]`, PR numbers, status fields, or task placement
- Explanations of specs vs changes vs tasks.md
- Review rules — those belong in `REVIEW.md` (Step 8)
- Anything beyond the exact block above

The `/project-management` skill contains all the rules. AGENTS.md just says "load it."

---

### Step 7: Ensure the `CLAUDE.md` Pointer Exists

Claude Code does **not** read `AGENTS.md`. A `CLAUDE.md` that imports it keeps the two in sync without duplicating content.

- **If `CLAUDE.md` does not exist** → create it with the block below.
- **If `CLAUDE.md` already contains `@AGENTS.md`** → current, skip to Step 8.
- **If `CLAUDE.md` exists with other content** → it should already have been merged into `AGENTS.md` in 6.1. Prepend `@AGENTS.md` and a blank line, and leave only genuinely Claude-only rules below it.

**The EXACT block for a fresh `CLAUDE.md`:**

```markdown
@AGENTS.md
```

That single line is the whole file. Claude Code expands the import at load time, so project conventions live in exactly one place.

---

### Step 8: Ensure `REVIEW.md` and the Copilot Symlink

`REVIEW.md` at the repo root is the canonical **review-conventions** file. Claude Code Review reads it natively; Copilot reaches it through a symlink; CodeRabbit reaches it via Step 9.

#### 8.1 Migrate a legacy `.github/copilot-instructions.md`

```bash
test -f REVIEW.md && echo "REVIEW.md exists" || echo "REVIEW.md missing"
test -L .github/copilot-instructions.md && echo "already a symlink" || { test -f .github/copilot-instructions.md && echo "regular file" || echo "missing"; }
```

Handle by what the path actually is:

**It is a symlink already** (`test -L`). Resolve the target before touching it — an existing symlink may point at a legacy instruction file, and unlinking it blind would orphan those rules:

```bash
readlink .github/copilot-instructions.md
```

- Target resolves to `REVIEW.md` → already correct, skip to 8.2.
- Target is anything else → read that file, merge its rules into `REVIEW.md`, and only then remove the link and recreate it in 8.3.

**It is a regular file** with review rules and `REVIEW.md` does not exist → move its content. The file may be untracked (first-time setup of a local project), in which case `git mv` fails with "not under version control" — fall back to a plain move:

```bash
mkdir -p .github
git mv .github/copilot-instructions.md REVIEW.md 2>/dev/null \
  || mv .github/copilot-instructions.md REVIEW.md
```

**Both exist as regular files** → merge copilot-instructions content into `REVIEW.md`, then delete the original. Never drop review rules.

#### 8.2 Check for CURRENT language

Search `REVIEW.md` for the exact string `docs/changes/`.

- **If `docs/changes/` is found** → current. Skip to 8.3.
- **If NOT found** → missing or stale. Prepend the block below at the TOP, followed by `---` and a blank line. Remove any stale section that references `PROJECT.md` or `docs/specs/` for tasks.

**If `REVIEW.md` does not exist at all**, create it with exactly this block.

**The EXACT block to insert (do NOT add to, modify, or expand this):**

```markdown
# PR Review

## Task Cross-Reference

Cross-reference every PR against task lists in `docs/changes/` and `docs/tasks.md`. If the PR completes work tracked in those files, the task checkboxes MUST be updated in this same PR. Request changes if missing.
```

**⛔ FORBIDDEN: Do NOT add ANY of the following to REVIEW.md at setup time:**
- Detailed rules about `- [x]` format, PR numbers, or status fields
- Explanations of the spec/change/task system
- Instructions about where tasks should be placed
- Anything beyond the exact block above

Feedback resolvers add convention rules to `REVIEW.md` later — setup only seeds it.

**`REVIEW.md` is pasted verbatim into the reviewer's prompt.** `@` imports are not expanded and referenced files are not read. Never write `See docs/foo.md` in it.

#### 8.3 Create the symlink

Copilot code review does not follow file references, so the path it looks for must *be* `REVIEW.md`:

```bash
mkdir -p .github
rm -f .github/copilot-instructions.md
ln -s ../REVIEW.md .github/copilot-instructions.md
```

Verify the symlink survived **without staging anything** — `git add` would mutate the caller's index and could leave a commit containing only the symlink while `REVIEW.md` and `AGENTS.md` stay untracked, landing a dangling pointer:

```bash
test -L .github/copilot-instructions.md && echo "symlink OK" || echo "NOT a symlink"
git config --get core.symlinks   # empty or "true" is fine; "false" is the problem case
```

If the path is not a symlink, or `core.symlinks` is `false`, fall back to the generated mirror described in `references/instruction-files.md` and tell the user.

**Staging is the caller's job, and it is all-or-nothing.** Setup does not run `git add`. When the caller commits this migration, every file it touched must go in the same commit — `AGENTS.md`, `REVIEW.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` — otherwise the symlink can land pointing at a file that does not exist yet.

#### 8.4 Point Codex at `REVIEW.md`

Codex reads only `AGENTS.md` — never `REVIEW.md`. Its convention is a `## Code Review Rules` section, so `AGENTS.md` needs a pointer.

Search `AGENTS.md` for `## Code Review Rules`. If absent, append **exactly** this:

```markdown

## Code Review Rules

Read `REVIEW.md` at the repository root and apply it in full as the review rules for this repo. It is the canonical review-conventions file.
```

This is the one review-related section allowed in `AGENTS.md`, and it is a pointer only — never copy rules out of `REVIEW.md` into it.

---

### Step 9: Ensure CodeRabbit Reads `REVIEW.md`

CodeRabbit's default `filePatterns` cover `**/AGENTS.md` and `.github/copilot-instructions.md` but **not** `**/REVIEW.md`.

- **No `.coderabbit.yaml`** → defaults apply. The symlink from Step 8.3 already routes CodeRabbit to `REVIEW.md`, so no action is needed.
- **`.coderabbit.yaml` exists with `knowledge_base.code_guidelines.enabled: false`** → set it to `true`.
- **`.coderabbit.yaml` exists with custom `filePatterns`** → add `"**/REVIEW.md"` and `"**/AGENTS.md"`. Custom patterns append to the defaults; they do not replace them.

```yaml
knowledge_base:
  code_guidelines:
    enabled: true
    filePatterns:
      - "**/REVIEW.md"
      - "**/AGENTS.md"
```

Patterns are case-sensitive: `review.md` does not match `**/REVIEW.md`.

---

### Step 10: Report

If any files were created or modified, report what was done:

```
Docs structure ready:
  docs/
  ├── specs/          (living specifications)
  ├── changes/        (change documents with task tracking)
  ├── tasks.md        (catch-all task list)
  ├── index.yml       (machine-readable index)
  └── index.md        (human-readable index)

Instruction files:
  ├── AGENTS.md       (project conventions; defers task tracking to /project-management)
  ├── REVIEW.md       (review conventions; PR review checks)
  ├── CLAUDE.md       -> @AGENTS.md
  └── .github/copilot-instructions.md -> ../REVIEW.md (symlink)
```

If everything was already current, report briefly: "Docs structure and instruction files verified — no changes needed."

## Rules

- **Never overwrite** existing docs/ files — only create what's missing
- **Never delete convention content** during migration — move it into `AGENTS.md` or `REVIEW.md`
- **Offer migration** if PROJECT.md exists
- **Keep it minimal** — bare templates, not example content
- **Idempotent** — safe to run multiple times; repeated runs MUST NOT duplicate content
- **Exact marker checks** — AGENTS.md checks for `/project-management`, REVIEW.md checks for `docs/changes/`, CLAUDE.md checks for `@AGENTS.md`
- **Replace stale language** — if old-style references exist (`PROJECT.md`, `docs/specs/` for tasks), remove and replace them
- **Insert ONLY the exact blocks specified** — do NOT expand, embellish, or add detail to the AGENTS.md, REVIEW.md, or CLAUDE.md content. The blocks above are the complete content. Adding anything extra violates the design
- **Prepend for REVIEW.md** — review rules go at the TOP so they're seen first
- **Append for AGENTS.md** — task tracking section is appended to not disrupt existing structure
- **Two files, two jobs** — how code is *written* goes in `AGENTS.md`; how code is *reviewed* goes in `REVIEW.md`
