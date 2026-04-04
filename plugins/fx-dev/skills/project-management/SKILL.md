---
name: project-management
description: "MUST BE LOADED BEFORE modifying docs/tasks.md, docs/changes/, or task lists. Also load when user mentions tasks.md, changes/, 'the task file', specs, or discusses tasks/tracking. Triggers include: 'add a task', 'update tasks', 'mark as done', 'mark complete', 'track this', 'next task', 'what's next', 'work on next', create tickets/issues, 'add a feature', 'improve X to allow Y', plan features, break down tasks, or ANY project/task management discussion. This skill handles all task tracking through docs/tasks.md, docs/changes/ task lists, or external tools (GitHub Issues, Jira)."
---

# Project Management

This skill manages project tasks and documentation for AI-driven development. Work is tracked in:
- **`docs/changes/NNNN-name.md`** — Feature-level task lists tied to specific change documents
- **`docs/tasks.md`** — Catch-all task list for work not tied to a specific change
- **External tools** — GitHub Issues or Jira when configured in the project's CLAUDE.md

## Core Principles

1. **Changes are primary** — Most feature work SHOULD be tracked in `docs/changes/` documents, not in `docs/tasks.md`. Change documents are what `/team` and `/dev` consume.
2. **NEVER duplicate tasks** — Tasks that exist in a `docs/changes/` document MUST NOT be copied, summarized, or mirrored into `docs/tasks.md`. Each task lives in exactly one place. `docs/tasks.md` is ONLY for orphan work not tied to any change document.
3. **One task = one PR** — Every top-level task represents work that results in a single pull request.
4. **Smaller PRs are better** — Prefer many focused PRs over few large ones.
5. **Clarify before acting** — Use AskUserQuestion to resolve ambiguity.
6. **Research first** — Understand requirements before planning.

## When This Skill Triggers

**CRITICAL:** Load this skill BEFORE reading, modifying, or editing `docs/tasks.md` or task lists in `docs/changes/`. Do not use Read/Edit tools on these files without loading this skill first.

**Load this skill IMMEDIATELY when:**
- About to modify `docs/tasks.md` or `## Tasks` in `docs/changes/` files
- Mentions tasks.md, changes/, "the task file", "task list"
- Says: "add a task", "new task", "track this"
- Says: "mark as done", "mark complete", "check off", "finished this"
- Says: "next task", "what's next", "work on next"
- Discusses tasks, features, or project tracking
- Asks to create tickets, issues, or feature documentation
- Says "add a feature that does X" or "improve X to allow Y"
- Asks to plan, break down, or organize work

## Task Source Priority

When looking for tasks, adding tasks, or marking completion, follow this strict priority:

1. **Check `docs/changes/`** FIRST — Scan change documents for uncompleted `- [ ]` tasks. These are the primary work items. If work relates to an existing spec or change document, tasks MUST go here.
2. **Check `docs/tasks.md`** ONLY for orphan work — Tasks that do not relate to any spec or change document. Before adding a task here, verify no relevant change document exists. If a relevant spec exists, create a change document for the work instead.
3. **Check external tools** — If CLAUDE.md specifies GitHub Issues or Jira preference.

**Strong default to change documents:** When the user asks to add or track work that relates to any existing spec in `docs/specs/`, ALWAYS create or find a change document for it. NEVER put spec-related work in `docs/tasks.md`. If no change document exists yet, propose creating one.

## External Task Tracking

Projects MAY define a preference for external task tracking in their CLAUDE.md. Look for patterns like:
- `task-tracking: github-issues`
- `task-tracking: jira`
- "Use GitHub Issues for task tracking"
- "Track tasks in Jira project X"

**When external tracking is configured:**
1. Load the GitHub skill (`Skill tool: skill="fx-dev:github"`) if using GitHub
2. Create issues/tickets in the external tool
3. Keep `docs/tasks.md` as a lightweight reference linking to external items
4. Mark completion in BOTH the external tool and `docs/tasks.md` or change documents

**When no external tracking is configured:**
Default to `docs/tasks.md` and `docs/changes/` task lists.

## Available Skills (for Sub-Agents)

### Research Skills
- **`fx-research:tech-scout`** — Research libraries, technologies, solutions
- **`Explore`** — Explore codebase structure, patterns, implementations (built-in subagent type)
- **`Plan`** — Design implementation plans (built-in subagent type)

### Development Skills
- **`fx-dev:coder`** — Implement features, fix bugs
- **`fx-dev:planner`** — Create detailed implementation plans
- **`fx-dev:pr-preparer`** — Prepare and create pull requests
- **`fx-dev:sdlc`** — Orchestrate complete development lifecycle

## Workflows

### Workflow 1: Feature Requests

When user says "add a feature that does X" or "improve X to allow Y":

1. **Analyze deeply** using Explore and tech-scout sub-agents
2. **Check if a relevant spec exists** in `docs/specs/`
3. **Determine scope** — Single PR? Multiple PRs? Needs a change document?
4. **If multi-PR**: Invoke `/spec-writer` to create or update the spec and propose change documents
5. **If single PR**: Add to `docs/tasks.md` and proceed to implementation
6. **Get approval** then begin work

### Workflow 2: "Work on Next"

When user says "work on next", "next task", "what's next":

1. **Scan `docs/changes/`** for change documents with status `in-progress` or `draft` that have uncompleted tasks
2. **Scan `docs/tasks.md`** for uncompleted items (top = highest priority)
3. **Check external tools** if configured
4. **Select next uncompleted task** — prioritize in-progress changes over new work
5. **Announce the task** to user
6. **Execute using development sub-agents**
7. **Mark task complete** with PR number in the file where it lives
8. **Ensure PR includes the task-list update**

### Workflow 3: Break Down Tasks for a Change Document

When instructed to break down tasks for a change document or spec:

1. **Read the document** to understand scope and design
2. **Explore the codebase** to understand what needs to change
3. **Write tasks** as nested markdown checkboxes in the `## Tasks` section:
   ```markdown
   ## Tasks

   - [ ] Task one — brief description
     - [ ] Subtask if needed
   - [ ] Task two — brief description
   ```
4. **Scope each top-level task to one PR**
5. **Be specific** — include file paths, function names, test requirements
6. **Do not duplicate** — if another change document already tracks related work, reference it

### Workflow 4: Initial Setup

When `docs/tasks.md` doesn't exist:

1. **Invoke the setup skill:**
   ```
   Skill tool: skill="fx-dev:setup"
   ```
2. **Ask about tracking preferences** via AskUserQuestion:
   - "Use docs/tasks.md + docs/changes/ (default)"
   - "Use GitHub Issues + docs/changes/"
   - "Other (Jira, Linear, etc.)"
3. **Migrate existing tracking** (PROJECT.md, TODO.md, STATUS.md) if present

### Workflow 5: Update Indexes

After any task modification (creation, completion, status change), update the documentation indexes:

1. **Update `docs/index.yml`** — Update the status field for any affected change documents
2. **Update `docs/index.md`** — Update the status in the table

---

## Pre-Flight: Run Setup

**Every time this skill is invoked**, run the setup skill first to ensure docs structure and instruction files are in place:

```
Skill tool: skill="fx-dev:setup"
```

This is fast and idempotent — it checks what exists and only creates/modifies what's missing. It handles:
- `docs/` folder structure (specs/, changes/, tasks.md, index.yml, index.md)
- `CLAUDE.md` task-tracking instructions
- `.github/copilot-instructions.md` PR review instructions

---

## Critical Requirements

### Every Task Completion MUST:

1. Mark task complete in the file where the task lives: `- [x] Task (PR #N)`
2. Task lists may be in `docs/tasks.md` OR in `docs/changes/*.md` files
3. Include the task-list update in the PR

### Before Creating Tasks:

1. Verify task is atomic (single PR scope)
2. Ensure description is clear and actionable
3. Prefer placing tasks in change documents over `docs/tasks.md`
4. **Check if a change document already tracks this work** — if so, add the task there, NEVER in `docs/tasks.md`

### When Ambiguity Exists:

1. ALWAYS use AskUserQuestion to clarify
2. Present concrete options
3. Wait for user decision before proceeding
