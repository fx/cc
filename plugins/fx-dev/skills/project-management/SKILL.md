---
name: project-management
description: MUST BE LOADED BEFORE modifying docs/PROJECT.md. Also load when user mentions PROJECT.md in ANY form (docs/PROJECT.md, @docs/PROJECT.md, "the project file", etc.) or discusses tasks/tracking. Triggers include: "add a task", "add this task", "update PROJECT.md", "mark as done", "mark complete", "track this", "next task", "what's next", "work on next", create tickets/issues, write feature docs, create PRD, manage TODO.md/STATUS.md, "add a feature", "improve X to allow Y", plan features, break down tasks, or ANY project/task management discussion. This skill handles all project planning, documentation, and work tracking through docs/PROJECT.md or external tools (GitHub Projects, Jira).
---

# Project Management

This skill manages project tasks and documentation for AI-driven development. All work is tracked in `docs/PROJECT.md` (or linked external tools) and results in pull requests.

## Core Principles

1. **Single Source of Truth** - `docs/PROJECT.md` is the central tracking document
2. **One Task = One PR** - Every task represents work that results in a single pull request
3. **Clarify Before Acting** - Use AskUserQuestion to resolve ambiguity
4. **Research First** - Use available agents to understand requirements before planning

## When This Skill Triggers

**CRITICAL:** Load this skill BEFORE reading, modifying, or editing `docs/PROJECT.md`. Do not use Read/Edit tools on PROJECT.md without loading this skill first.

**Load this skill IMMEDIATELY when:**
- **About to modify PROJECT.md** - Before ANY edit to docs/PROJECT.md, load this skill first
- Mentions PROJECT.md in ANY form: `docs/PROJECT.md`, `@docs/PROJECT.md`, "project file", "project tasks"
- Says: "add a task", "add this task", "new task", "track this"
- Says: "mark as done", "mark complete", "check off", "finished this"
- Says: "next task", "what's next", "work on next", "next issue", "next feature"
- Discusses tasks, features, or project tracking in general
- Asks to create tickets, issues, or feature documentation
- Requests PRD, product requirements, or feature specs
- Mentions TODO.md, STATUS.md, or project tracking
- Says "add a feature that does X" or "improve X to allow Y"
- Asks to plan, break down, or organize work

## Available Agents

### Research Agents (Use Liberally)

- **`agent-fx-research:tech-scout`** - Research libraries, technologies, solutions
- **`agent-Explore`** - Explore codebase structure, patterns, implementations
- **`agent-Plan`** - Design implementation plans

### Development Agents

- **`agent-fx-dev:coder`** - Implement features, fix bugs
- **`agent-fx-dev:planner`** - Create detailed implementation plans
- **`agent-fx-dev:pr-preparer`** - Prepare and create pull requests
- **`agent-fx-dev:sdlc`** - Orchestrate complete development lifecycle

### GitHub Integration

When working with GitHub issues or projects:
1. **Load the GitHub skill first**: `Skill` tool with `skill="fx-dev:github"`
2. Use `gh` CLI for all GitHub operations

## docs/PROJECT.md

To create or understand the PROJECT.md format, read the template at:
`references/project-md-template.md`

### Task Format Rules

1. **Flat list** - No categories or groupings. Just tasks in priority order.
2. **Up to 3 levels** - Feature → Task → Subtask (2-space indent per level)
3. **One top-level item = One PR** - Each feature/task results in a single PR
4. **Mark completion**: `- [x] Task name (PR #N)`
5. **Link issues**: `- [ ] Task (#123)` when linked to GitHub issue

## Workflows

### Workflow 1: Feature Requests

When user says "add a feature that does X" or "improve X to allow Y":

1. **Analyze deeply**
   - Use `agent-Explore` to understand current codebase
   - Use `agent-fx-research:tech-scout` if technology decisions needed

2. **Determine scope**
   - Single PR scope? → Proceed to implementation
   - Multi-PR scope? → Propose task breakdown

3. **Clarify ambiguity** via AskUserQuestion:
   - "This could be implemented as [A] or [B]. Which approach?"
   - "I've identified these tasks: [list]. Add to PROJECT.md?"

4. **Update PROJECT.md** with tasks (if breakdown needed)

5. **Get approval** then begin work on first task

### Workflow 2: "Work on Next"

When user says "work on next issue", "next feature", or "what's next":

1. **Read docs/PROJECT.md**

2. **Select next uncompleted task** (top of list = highest priority)

3. **Announce the task** to user

4. **Execute using development agents**

5. **Update PROJECT.md** marking task complete with PR number

6. **Ensure PR includes PROJECT.md update**

### Workflow 3: Creating PRDs

When user requests PRD or feature documentation:

1. **Gather requirements** via AskUserQuestion

2. **Research context** using `agent-Explore` and `agent-fx-research:tech-scout`

3. **Create PRD** in `docs/` folder

4. **Update PROJECT.md** with reference and tasks

5. **Create PR** with documentation

### Workflow 4: External Tool Integration

When GitHub Projects, Jira, or other tools are available:

1. **Load GitHub skill** if using GitHub

2. **Create issues/tickets** in external tool

3. **Update PROJECT.md** to reference external tracking

4. **Link tasks** between PROJECT.md and external tool

### Workflow 5: Initial Setup

When docs/PROJECT.md doesn't exist:

1. **Explore the project** using `agent-Explore`

2. **Ask about tracking preferences** via AskUserQuestion:
   - "Use docs/PROJECT.md only"
   - "Use GitHub Issues + PROJECT.md"
   - "Other (Jira, Linear, etc.)"

3. **Read the template** at `references/project-md-template.md`

4. **Create PROJECT.md** with initial backlog

5. **Migrate existing tracking** (TODO.md, STATUS.md) if present

## Critical Requirements

### Every Task Completion Must:

1. Mark task complete in PROJECT.md: `- [x] Task (PR #N)`
2. Include PROJECT.md update in the PR

### Before Creating Tasks:

1. Verify task is atomic (single PR scope)
2. Ensure description is clear and actionable

### When Ambiguity Exists:

1. ALWAYS use AskUserQuestion to clarify
2. Present concrete options
3. Wait for user decision before proceeding
