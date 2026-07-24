---
name: setup
description: "Initialize the docs/ folder structure for spec-driven development and create the standard AI instruction files (AGENTS.md, REVIEW.md, the CLAUDE.md pointer, and .coderabbit.yaml) if missing, so task tracking defers to /project-management. Creates defaults only — never migrates existing files; that is fx-dev:upgrade. Called automatically by /spec-writer and /project-management. Also use when user says 'setup docs', 'initialize docs', 'create docs structure'."
---

# Setup

This skill scaffolds the `docs/` folder structure required for spec-driven development and creates the standard AI instruction files (`AGENTS.md`, `REVIEW.md`, plus the `CLAUDE.md` pointer and `.coderabbit.yaml`) so that task tracking defers to the `/project-management` skill. It is called automatically by `/spec-writer` and `/project-management` as a prerequisite.

## ⛔ setup creates. It does not migrate.

**setup runs unattended on every `/spec-writer` and `/project-management` invocation.** It must never make a change the user would want to review first.

| setup MAY | setup MUST NOT |
|---|---|
| Create a missing file or directory | Move or rename a file |
| Add a missing key to a config | Change a config value that is already set |
| Append or prepend a missing marker block | Delete or overwrite existing content |
| Report a legacy layout it found | Merge two files together |
| | Resolve or delete a symlink |

When it finds anything needing those — a `CLAUDE.md` full of conventions, an obsolete `.github/copilot-instructions.md`, a symlinked canonical file — it **reports and defers to `fx-dev:upgrade`**. It does not act.

**Read `references/instruction-files.md` before touching any instruction file.** It defines the canonical layout and which tool reads which file. Do not invent alternative file names or locations.

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

**If all docs/ files exist**, skip to Step 5.5 (instruction files). Do not overwrite existing docs/ files.

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

### Step 5.5: Legacy-Layout Detection (DETECT ONLY — never migrate)

**setup creates defaults. It never moves, merges, overwrites, or deletes anything.** It runs automatically on every `/spec-writer` and `/project-management` invocation, so it must never make a change a user would want to review first. Migration is `fx-dev:upgrade`'s job.

```bash
# -e follows symlinks, so a DANGLING link reads as absent. Always pair it with -L.
exists() { [ -e "$1" ] || [ -L "$1" ]; }
# A plain file is safe to inspect or append to; a symlink is not (writing goes to its target).
is_plain() { [ -f "$1" ] && [ ! -L "$1" ]; }

legacy_agents=0   # blocks Step 6 AND Step 8.3 (both write AGENTS.md)
legacy_review=0   # blocks Step 8
legacy_rabbit=0   # blocks Step 9

for p in AGENTS.md CLAUDE.md; do
  [ -L "$p" ] && { echo "LEGACY: $p is a symlink"; legacy_agents=1; }
done
[ -L REVIEW.md ] && { echo "LEGACY: REVIEW.md is a symlink"; legacy_review=1; }
[ -L .coderabbit.yaml ] && { echo "LEGACY: .coderabbit.yaml is a symlink"; legacy_rabbit=1; }

exists .github/copilot-instructions.md && {
  echo "LEGACY: .github/copilot-instructions.md exists (obsolete$( [ -L .github/copilot-instructions.md ] && echo ", symlink" ))"
  legacy_review=1
}

if is_plain CLAUDE.md && ! grep -q '^@AGENTS\.md' CLAUDE.md; then
  echo "LEGACY: CLAUDE.md holds content that belongs in AGENTS.md"; legacy_agents=1
fi

# Scoped to knowledge_base.code_guidelines.enabled ONLY. An unscoped grep for
# "enabled: false" also matches reviews.auto_review.enabled and would wrongly
# skip Step 9 on a config whose code_guidelines are perfectly fine.
if is_plain .coderabbit.yaml; then
  cg_disabled=$(python3 - <<'EOF' 2>/dev/null || echo unknown
import re,sys
txt=open('.coderabbit.yaml').read()
m=re.search(r'(?m)^\s*code_guidelines:\s*$', txt)
if not m: print('no'); sys.exit()
indent=len(re.match(r'\s*', txt[m.start():]).group(0))
for line in txt[m.end():].splitlines():
    if line.strip() and not line.startswith(' '*(indent+1)): break   # left the block
    if re.match(r'\s*enabled:\s*false\b', line): print('yes'); sys.exit()
print('no')
EOF
)
  [ "$cg_disabled" = "yes" ] && { echo "LEGACY: .coderabbit.yaml sets code_guidelines.enabled: false — setup will not flip it"; legacy_rabbit=1; }
  [ "$cg_disabled" = "unknown" ] && { echo "LEGACY: could not parse .coderabbit.yaml — read it yourself before writing"; legacy_rabbit=1; }
fi

echo "flags: agents=$legacy_agents review=$legacy_review rabbit=$legacy_rabbit"
```

Each flag gates the steps that would **write** the affected file:

| Flag | Skip | Why |
|---|---|---|
| `legacy_agents` | **Step 6 and Step 8.3** | Both write `AGENTS.md`. 8.3 appends the Codex pointer — on its own that would create a stub `AGENTS.md` holding only review rules while the real conventions sit in `CLAUDE.md`, which is worse than not creating it at all |
| `legacy_review` | **Step 8** | `REVIEW.md` must absorb the obsolete file's rules first, and that is a merge |
| `legacy_rabbit` | **Step 9** | Writing through a symlink edits its target, possibly outside the repo; and an explicit `enabled: false` is not setup's to reverse |

Steps not listed still run — a legacy `CLAUDE.md` does not stop `docs/` from being scaffolded.

**Never inspect or write a path that is a symlink.** `grep`, `>>`, and `cat >` all follow links, so a `CLAUDE.md -> ~/.claude/CLAUDE.md` would be read or written despite the create-only contract. That is why every content check above is guarded by `is_plain`.

**If any LEGACY line printed**, report:

```
Legacy instruction-file layout detected:
  - <the specific findings>

setup does not migrate — run /fx-dev:upgrade to move this content
into AGENTS.md / REVIEW.md. Skipped: <steps not run>.
```

The dangerous case is `AGENTS.md` missing while `CLAUDE.md` holds real conventions. **Do not seed an `AGENTS.md`** — that splits the project's conventions across two files and the user is left with neither complete. Skip Step 6 entirely and report.

---

### Step 6: Ensure `AGENTS.md` Defers to /project-management

`AGENTS.md` at the repo root is the canonical project-conventions file. Codex, Copilot, and CodeRabbit all read it natively.

#### 6.1 Preconditions

**If `legacy_agents=1`, skip this entire step** and report instead.

- **`AGENTS.md` exists** → go to 6.2.
- **`AGENTS.md` missing, and no `CLAUDE.md` with content** → create it containing only the block from 6.3.
- **`AGENTS.md` missing, but `CLAUDE.md` has content** → **stop.** This needs `/fx-dev:upgrade`. Creating a stub here would split conventions across two files.

#### 6.2 Check for CURRENT language

Search `AGENTS.md` for the exact string `/project-management`. This is the only valid marker.

- **If `/project-management` is found** → current. Skip to Step 7.
- **If NOT found** → missing or stale. Proceed to 6.3.

#### 6.3 Handle stale or missing language

**Append** the block below to the end of `AGENTS.md`. That is the only write setup makes to this file.

**If stale task-tracking language exists** (anything referencing `PROJECT.md`, `docs/specs/` for tasks, `- [x]`, `mark.*done`, or task-tracking rules that don't mention `/project-management`) → **do not remove it.** Append the new block anyway so the current rule is present, and report the stale section so the user can run `/fx-dev:upgrade` to clear it. Deleting a section from someone's file is not setup's call.

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
- **If `CLAUDE.md` exists with other content** → Step 5.5 already flagged this as legacy. **Do not modify it** — run `/fx-dev:upgrade`.

**The EXACT block for a fresh `CLAUDE.md`:**

```markdown
@AGENTS.md
```

That single line is the whole file. Claude Code expands the import at load time, so project conventions live in exactly one place.

---

### Step 8: Ensure `REVIEW.md`

`REVIEW.md` at the repo root is the canonical **review-conventions** file. **Copilot code review and Claude Code Review both read it natively**; Codex reaches it via the pointer in 8.3; CodeRabbit reaches it via Step 9.

#### 8.1 Preconditions

**If `legacy_review=1`, skip 8.1 and 8.2** — `REVIEW.md` needs a merge, which is `/fx-dev:upgrade`'s job. Step 8.3 is gated separately on `legacy_agents`.

`.github/copilot-instructions.md` is obsolete — Copilot reads `REVIEW.md` directly ([changelog, 2026-07-17](https://github.blog/changelog/2026-07-17-copilot-code-review-customization-and-configurability-improvements/)). **Never create one, and never symlink it to `REVIEW.md`.**

If Step 5.5 found one, do not touch it and do not create `REVIEW.md` from it — report and defer to `/fx-dev:upgrade`, which folds its rules into `REVIEW.md`.

```bash
test -f REVIEW.md && echo "REVIEW.md exists" || echo "REVIEW.md missing — will create"
```

#### 8.2 Check for CURRENT language

Search `REVIEW.md` for the exact string `docs/changes/`.

- **If `docs/changes/` is found** → current. Skip to 8.3.
- **If NOT found** → prepend the block below at the TOP, followed by `---` and a blank line. This is additive; **remove nothing.** If a stale section references `PROJECT.md` or `docs/specs/` for tasks, report it for `/fx-dev:upgrade` rather than deleting it.

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

#### 8.3 Point Codex at `REVIEW.md`

**If `legacy_agents=1`, skip this step.** It writes `AGENTS.md`, and appending here when `AGENTS.md` does not yet exist would create a stub holding only review rules while the project's real conventions sit in `CLAUDE.md` — every non-Claude agent would then read that stub as the whole truth. Report it instead; `/fx-dev:upgrade` adds this pointer as M1.4, after the content is moved.

Codex reads only `AGENTS.md` — never `REVIEW.md`. Its convention is a `## Code Review Rules` section, so `AGENTS.md` needs a pointer.

Search `AGENTS.md` for `## Code Review Rules`. If absent, append **exactly** this:

```markdown

## Code Review Rules

Read `REVIEW.md` at the repository root and apply it in full as the review rules for this repo. It is the canonical review-conventions file.
```

This is the one review-related section allowed in `AGENTS.md`, and it is a pointer only — never copy rules out of `REVIEW.md` into it.

---

### Step 9: Ensure CodeRabbit Reads `REVIEW.md`

**If `legacy_rabbit=1`, skip this step** and report — the config is a symlink (writing would edit its target) or has `code_guidelines` explicitly disabled.

CodeRabbit's default `filePatterns` cover `**/AGENTS.md` and `**/CLAUDE.md` but **not** `**/REVIEW.md`. **This step is mandatory** — it is the only thing that gets the review conventions to CodeRabbit.

- **No `.coderabbit.yaml`** → create it with the config below.
- **Exists with `knowledge_base.code_guidelines.enabled: false`** → **do not change it.** Someone disabled this deliberately, and setup runs unattended during unrelated spec and task work — silently opting the project back into CodeRabbit guidelines is exactly the kind of change that needs a human. Report it and defer to `/fx-dev:upgrade`.
- **Exists with `enabled` true or absent** → add `"**/REVIEW.md"` to `filePatterns` if missing. Custom patterns append to the defaults; they do not replace them. This is additive, so it stays within setup's contract.

```yaml
knowledge_base:
  code_guidelines:
    enabled: true
    filePatterns:
      - "**/REVIEW.md"
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
  └── .coderabbit.yaml (points CodeRabbit at REVIEW.md)
```

If everything was already current, report briefly: "Docs structure and instruction files verified — no changes needed."

If Step 5.5 found a legacy layout, always end the report with the specific findings and `Run /fx-dev:upgrade to migrate.` Never report success over a skipped file.

## Rules

- **Never overwrite** existing files — only create what's missing
- **Never migrate** — no moves, merges, deletions, or symlink resolution. Detect and defer to `/fx-dev:upgrade`
- **Never flip an existing config value** — an explicit `enabled: false` is someone's decision. Adding a missing key is creation; changing a set one is not
- **Never delete convention content** — setup deletes nothing, ever
- **Offer migration** if PROJECT.md exists
- **Keep it minimal** — bare templates, not example content
- **Idempotent** — safe to run multiple times; repeated runs MUST NOT duplicate content
- **Exact marker checks** — AGENTS.md checks for `/project-management`, REVIEW.md checks for `docs/changes/`, CLAUDE.md checks for `@AGENTS.md`
- **Report stale language, do not replace it** — if old-style references exist (`PROJECT.md`, `docs/specs/` for tasks), append the current block and report the stale section for `/fx-dev:upgrade`
- **Insert ONLY the exact blocks specified** — do NOT expand, embellish, or add detail to the AGENTS.md, REVIEW.md, or CLAUDE.md content. The blocks above are the complete content. Adding anything extra violates the design
- **Prepend for REVIEW.md** — review rules go at the TOP so they're seen first
- **Append for AGENTS.md** — task tracking section is appended to not disrupt existing structure
- **Two files, two jobs** — how code is *written* goes in `AGENTS.md`; how code is *reviewed* goes in `REVIEW.md`
- **Canonical files are regular files** — never symlink `AGENTS.md` or `REVIEW.md`, and never create `.github/copilot-instructions.md`. Copilot reads `REVIEW.md` directly; a second path to the same rules only causes confusion
