---
name: team
description: "Spawn a coordinated sub-agent team to implement a spec or multi-task feature in parallel. Use when user says '/team', 'use a team', 'parallel implementation', 'work on multiple tasks', or provides a spec/issue that requires coordinated multi-PR work. The main session acts as coordinator — no code, no commits, only delegation and quality control."
---

# Team (Coordinated Sub-Agent Implementation)

Spawn a coordinated sub-agent team to implement a spec or multi-task feature. The main session (you) acts strictly as coordinator — no code, no commits, only delegation and quality control.

## ⛔ Critical Architecture Rule: Coordinator Owns the SDLC

**Sub-agents CANNOT spawn their own sub-agents.** If you tell a teammate to "run the full SDLC," it will try to do implementation inline (instead of delegating to a coder sub-agent), bloat its context window, and skip later steps like Copilot review. This has been observed in production.

**Therefore: YOU (the coordinator) orchestrate each SDLC step per task.** You spawn focused, single-purpose agents for each step and handle cross-cutting concerns (Copilot review, CI, merge gates) directly.

**Never tell an agent to "load the dev skill and follow all steps." Instead, give each agent ONE focused job.**

---

## STEP 0: Understand the Work

1. **If given a spec file path:** Read it to extract all tasks.
2. **If given an issue URL:** Fetch it with `gh issue view`.
3. **If given a description:** Break it into discrete, parallelizable tasks.

Identify:
- Total tasks and their dependencies
- Which tasks can run in parallel vs. which must be sequential
- A sensible task grouping (1 coder agent can own 1-3 related tasks)

## STEP 1: Create the Team

```
TeamCreate tool:
  team_name: "<short-kebab-name>"  # e.g., "auth-feature", "admin-ui"
  description: "<what the team is building>"
```

## STEP 2: Create and Organize Tasks

Use `TaskCreate` for every task identified in Step 0. Set up dependencies with `TaskUpdate` (`addBlockedBy`/`addBlocks`) so work proceeds in the correct order.

**Task descriptions MUST include:**
- Exactly what to implement (files, components, endpoints)
- Acceptance criteria
- Which spec task(s) it maps to (if from a spec)

## STEP 3: Execute Tasks (Coordinator-Driven SDLC)

**Load the dev skill** (`Skill tool: skill='fx-dev:dev'`) and read its SDLC steps. The dev skill is the single source of truth for the development workflow — do not duplicate its instructions here.

For each task (or group of parallel tasks), walk through the dev skill's SDLC steps yourself. For each step, decide:

1. **Can I handle this step directly?** (e.g., invoking a skill, running a `gh` command) → Do it yourself.
2. **Does this step require writing/modifying code?** → Spawn a focused agent with a single-purpose prompt for just that step.

### Key orchestration principles

**Implementation steps** (planning, coding, testing) → Spawn focused agents. Use `isolation: "worktree"` for coder agents so each works on an isolated copy. Give each agent ONLY its specific job — the change doc path, spec path, plan, and acceptance criteria. Do NOT tell it to follow the full SDLC.

**PR creation** → Either do it yourself via `gh pr create` or spawn a focused PR preparer agent. Load `fx-dev:github` skill first.

**Review and CI steps** (Copilot review, CI monitoring, feedback resolution) → **Handle these DIRECTLY as the coordinator.** These are lightweight skill/command invocations that must not be delegated. Invoke `fx-dev:copilot-review` yourself. Run `gh pr checks --watch` yourself. Invoke `fx-dev:resolve-pr-feedback` yourself.

**Merge gates** → Always handle directly. See MANDATORY MERGE GATE CHECKLIST below.

**Browser verification** → Spawn a dedicated verify agent if the task has UI changes.

### Parallelization

- Spawn multiple coder agents simultaneously for independent tasks (each in its own worktree)
- For dependent tasks, wait until the blocking task's PR is merged before spawning the next coder
- After merging, repeat for newly-unblocked tasks

---

## MANDATORY MERGE GATE CHECKLIST (BLOCKING)

**BEFORE running `gh pr merge` on ANY PR — no matter how small — you MUST verify ALL of the following. This is non-negotiable. A single unmet condition means DO NOT MERGE.**

| # | Gate | How to verify | Blocking? |
|---|------|--------------|-----------|
| 1 | **CI checks ALL green** | `gh pr checks <NUMBER>` — every check must show `pass` | YES |
| 2 | **Copilot review RECEIVED and feedback RESOLVED** | Invoke `fx-dev:copilot-review` skill — confirm 0 unresolved threads | YES |
| 3 | **Implementation matches spec/task** | Read the diff and verify against requirements | YES |
| 4 | **Spec task marked complete** | Check via project-management skill | YES |
| 5 | **PR description is clear** | Read PR body | YES |
| 6 | **Browser verification completed** | Spawn a verify agent if needed (see below) | YES |

### ⛔ Copilot Gate (Gate 2) — CRITICAL

**Copilot reviews EVERY pull request automatically. It does NOT need to be "configured" or "enabled." It is completely independent of CI. NEVER use raw `gh api` commands to check Copilot — use the dedicated skill.**

```
Skill tool: skill="fx-dev:copilot-review", args="<PR_NUMBER>"
```

This skill handles the full lifecycle: request review → wait (up to 15 min) → resolve all feedback. Only proceed to merge after it confirms 0 unresolved threads.

### Browser Verification Gate (Gate 6)

For tasks with UI changes, spawn a dedicated verify agent:

```
Agent tool:
  name: "verify-<pr-number>"
  prompt: "Load the verify-web-change skill (Skill tool: skill='fx-dev:verify-web-change').
           Verify PR #<NUMBER> on branch <branch-name>.
           Check out the branch, start the dev server, and confirm the app loads without errors.
           Report back whether verification passed or failed, with details of any errors."
  description: "Verify PR #<NUMBER> in browser"
  mode: "bypassPermissions"
```

**Why this gate exists:** CI does NOT catch runtime-only errors like circular dependencies, SSR failures, or broken module initialization.

**If a "small" or "follow-up" PR:** Same rules. No exceptions. PR size is NEVER a reason to skip merge gates.

## STEP 4: Shutdown

When all tasks are complete and all PRs merged:

1. Verify all spec tasks are marked done (load `fx-dev:project-management` to check)
2. Send shutdown requests to all active teammates
3. Clean up the team with `TeamDelete`
4. Report final summary to user

---

## Coordinator Rules (NON-NEGOTIABLE)

- **NEVER write code yourself** — all implementation goes through coder agents
- **NEVER create branches or commits** — coder agents handle this
- **NEVER delegate the full SDLC to a single agent** — agents cannot spawn sub-agents, so they will inline everything and skip later steps
- **NEVER skip PR inspection** — every PR gets reviewed before marking ready
- **NEVER merge without completing the MERGE GATE CHECKLIST** — every gate must pass, every time, for every PR
- **NEVER merge without Copilot review** — always invoke `fx-dev:copilot-review` yourself. No exceptions.
- **NEVER mark a teammate's PR as ready** until you've inspected it
- **ALWAYS handle Copilot review and CI monitoring directly** — these are coordinator responsibilities, not sub-agent responsibilities
- **ALWAYS use `fx-dev:project-management`** to verify task tracking
- **ALWAYS run the full merge gate checklist** even for "trivial" or "follow-up" PRs
- **NEVER merge without browser verification** — spawn a verify agent if needed. CI alone does NOT catch runtime errors.

## Handling Agent Issues

If a coder agent reports problems:

1. Read the error details from their message
2. Spawn a new focused agent to fix the specific issue
3. If stuck after 2 retries, report to user and ask for guidance
