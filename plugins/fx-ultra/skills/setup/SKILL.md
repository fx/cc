---
name: setup
description: "Initialize the docs/ folder structure for spec-driven development and ensure CLAUDE.md and .github/copilot-instructions.md defer task tracking to /project-management. Called automatically by /spec-writer and /project-management. Also use when user says 'setup docs', 'initialize docs', 'create docs structure'."
---

# Setup

This skill scaffolds the `docs/` folder structure required for spec-driven development and ensures project instruction files (`CLAUDE.md`, `.github/copilot-instructions.md`) properly defer task tracking to the `/project-management` skill. It is called automatically by `/spec-writer` and `/project-management` as a prerequisite.

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

### Step 6: Ensure CLAUDE.md Defers to /project-management

Check the project root `CLAUDE.md`. If it doesn't exist, create it with the block below.

#### 6.1 Check for CURRENT language

Search `CLAUDE.md` for the exact string `/project-management`. This is the only valid marker.

- **If `/project-management` is found** → current. Skip to Step 7.
- **If NOT found** → missing or stale. Proceed to 6.2.

#### 6.2 Handle stale or missing language

**If stale task-tracking language exists** (anything referencing `PROJECT.md`, `docs/specs/` for tasks, `- [x]`, `mark.*done`, or task-tracking rules that don't mention `/project-management`):
- Remove the entire stale section
- Insert the new block in its place

**If no task-tracking language exists at all:**
- Append the new block to the end of `CLAUDE.md`

**The EXACT block to insert (do NOT add to, modify, or expand this):**

```markdown

## Task Tracking

**You MUST load the `/project-management` skill before creating, modifying, or completing any task.** It owns all task-tracking rules and knows where tasks belong. Do not manage tasks without it.
```

**⛔ FORBIDDEN: Do NOT add ANY of the following to CLAUDE.md:**
- Descriptions of docs/ folder structure
- Rules about `- [x]`, PR numbers, status fields, or task placement
- Explanations of specs vs changes vs tasks.md
- Anything beyond the exact block above

The `/project-management` skill contains all the rules. CLAUDE.md just says "load it."

---

### Step 7: Ensure `.github/copilot-instructions.md` Has PR Review Cross-Reference

Check `.github/copilot-instructions.md`. Create `.github/` directory and the file if they don't exist.

Copilot cannot load skills — it only reviews PRs. So this file tells it WHERE to cross-reference, not how to manage tasks.

#### 7.1 Check for CURRENT language

Search `.github/copilot-instructions.md` for the exact string `docs/changes/`.

- **If `docs/changes/` is found** → current. Skip to Step 8.
- **If NOT found** → missing or stale. Proceed to 7.2.

#### 7.2 Handle stale or missing language

**If the file does NOT exist**, create `.github/copilot-instructions.md` with the block below.

**If the file DOES exist but has stale language** (references `PROJECT.md` or `docs/specs/` for tasks):
- Remove the stale section
- Prepend the new block at the TOP, followed by `---` and a blank line

**The EXACT block to insert (do NOT add to, modify, or expand this):**

```markdown
# PR Review

## Task Cross-Reference

Cross-reference every PR against task lists in `docs/changes/` and `docs/tasks.md`. If the PR completes work tracked in those files, the task checkboxes MUST be updated in this same PR. Request changes if missing.
```

**⛔ FORBIDDEN: Do NOT add ANY of the following to copilot-instructions.md:**
- Detailed rules about `- [x]` format, PR numbers, or status fields
- Explanations of the spec/change/task system
- Instructions about where tasks should be placed
- Anything beyond the exact block above

---

### Step 8: Report

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
  ├── CLAUDE.md       (defers task tracking to /project-management)
  └── .github/copilot-instructions.md (PR review checks)
```

If everything was already current, report briefly: "Docs structure and instruction files verified — no changes needed."

## Rules

- **Never overwrite** existing docs/ files — only create what's missing
- **Offer migration** if PROJECT.md exists
- **Keep it minimal** — bare templates, not example content
- **Idempotent** — safe to run multiple times; repeated runs MUST NOT duplicate content
- **Exact marker checks** — CLAUDE.md checks for `/project-management`, copilot-instructions checks for `docs/changes/`
- **Replace stale language** — if old-style references exist (`PROJECT.md`, `docs/specs/` for tasks), remove and replace them
- **Insert ONLY the exact blocks specified** — do NOT expand, embellish, or add detail to the CLAUDE.md or copilot-instructions content. The blocks above are the complete content. Adding anything extra violates the design
- **Prepend for copilot-instructions** — review rules go at the TOP so they're seen first
- **Append for CLAUDE.md** — task tracking section is appended to not disrupt existing structure
