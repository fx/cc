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

### Do NOT pause to confirm scope on clearly-scoped requests (BLOCKING)

When the user's invocation is unambiguous — e.g. `implement all pending changes fully`, `ship all of these`, `do everything in docs/changes/`, a concrete list of PR numbers, or a single spec file — **treat that as the authoritative scope and proceed immediately to Step 1**. Do NOT pause to ask "should I do all 6 now or just wave 1 first to sanity-check?" Do NOT report `failure` to the Coder dashboard asking for scope confirmation when the user already gave it. Words like "all", "fully", "every", "the whole list" are explicit scope — honor them.

**You can still split execution into waves internally.** Wave-based execution (Wave 1: independent tasks in parallel; Wave 2: their dependents once unblocked; etc.) is the correct way to run a multi-PR team, and you should plan it that way. The rule is about **not stopping to ask the user** whether to do waves or which wave to start with — just plan the waves and execute them.

**Reserve confirmation for genuine ambiguity only:**
- Conflicting instructions ("ship 0051 — actually wait, also 0055?")
- Vague scope ("clean up the changes folder" without saying which)
- Destructive operations not implied by the request (deleting branches, force-pushing, dropping data)

If you find yourself drafting a "before I burn that compute, one quick check…" message in response to a clearly-scoped instruction, stop. Delete the draft. Spawn the team.

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

### ⛔ ALL Agent spawns MUST register as team members (BLOCKING)

**Every single `Agent` tool call you make as the team coordinator — coder, verify, fix, anything — MUST pass BOTH `team_name` and `name`.** Spawning an Agent without these parameters in team mode is a bug: the agent runs as an orphan sub-agent instead of a registered teammate, doesn't appear in `~/.claude/teams/<team>/config.json` `members[]`, can't be addressed via `SendMessage` by name, and silently defeats the entire point of `/team`.

```
Agent tool:
  team_name: "<the-team-you-just-created>"   # ← REQUIRED in team mode, NO EXCEPTIONS
  name:      "<short-descriptive-handle>"    # ← REQUIRED in team mode, NO EXCEPTIONS
  subagent_type: "general-purpose"
  isolation: "worktree"                      # for coders
  mode: "bypassPermissions"
  prompt: "..."
  run_in_background: true                    # usually
```

The `name` should be specific and human-readable so it's useful in logs and `SendMessage` (e.g., `coder-0105A`, `verify-pr-371`, `fix-0106-types`). One-shot generic names like `agent1` are bad.

**Self-check before EVERY Agent call in team mode:** "Did I pass `team_name`? Did I pass `name`?" If either is missing, fix the call before sending it. This rule is non-negotiable — it has been violated in production and produced a coordinator session running orphan sub-agents that the team config didn't know about.

### Key orchestration principles

**Implementation steps** (planning, coding, testing) → Spawn focused agents. Use `isolation: "worktree"` for coder agents so each works on an isolated copy. Give each agent ONLY its specific job — the change doc path, spec path, plan, and acceptance criteria. Do NOT tell it to follow the full SDLC. Always pass `team_name` and `name` (see above).

When you spawn the coder for the FINAL piece of a change, your prompt MUST include: "This is the final implementing PR for <change>. In the same commit, flip `**Status:** draft` → `**Status:** complete` in `docs/changes/<NNNN>-*.md` AND flip `status: draft` → `status: complete` for that change's entry in `docs/index.yml`. Sync `docs/index.md` if present." For every NON-final coder on the same change, your prompt MUST include: "Leave the change-doc `**Status:**` field and `docs/index.yml` entry untouched — the final PR flips them." This split prevents rebase-conflict storms across multi-PR changes and ensures the final PR carries the Status flip atomically.

**PR creation** → Either do it yourself via `gh pr create` or spawn a focused PR preparer agent. Load `fx-dev:github` skill first.

**Review and CI steps** (Copilot review, CodeRabbit review, CI monitoring, feedback resolution) → **Handle these DIRECTLY as the coordinator.** These are lightweight skill/command invocations that must not be delegated. Invoke `fx-dev:copilot-review` AND `fx-dev:coderabbit-review` yourself (sequentially, or with the slow CodeRabbit waiter as a background Bash process while you handle Copilot in the foreground — see the Reviewer Gates section below). Run `gh pr checks --watch` yourself. Invoke `fx-dev:resolve-pr-feedback` yourself.

**⛔ NEVER spawn sub-agents to handle reviewer waits.** `fx-dev:dev` Step 6.3's mode A (parallel sub-agents per reviewer) is for the **root-session caller** only. As a team coordinator you ARE the root agent for the team's lifecycle and must use mode B (sequential or background-Bash overlap).

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
| 1 | **CI checks ALL green** | `gh pr checks <NUMBER>` — every check must show `pass` (includes the `CodeRabbit` check) | YES |
| 2 | **Copilot review RECEIVED and feedback RESOLVED** | Invoke `fx-dev:copilot-review` skill — confirm 0 unresolved Copilot threads | YES |
| 2b | **CodeRabbit check terminal-passing AND feedback RESOLVED** | Invoke `fx-dev:coderabbit-review` skill — confirm `CodeRabbit` check is `success` AND 0 unresolved CodeRabbit threads. CodeRabbit re-reviews on every push, so loop until convergence | YES (when configured) |
| 3 | **Implementation matches spec/task** | Read the diff and verify against requirements | YES |
| 4 | **Spec task marked complete** | Check via project-management skill | YES |
| 5 | **PR description is clear** | Read PR body | YES |
| 6 | **Browser verification completed** | Spawn a verify agent if needed (see below) | YES |

### ⛔ Reviewer Gates (Gates 2 + 2b) — CRITICAL

**As coordinator, YOU handle reviewer waits directly. Do NOT spawn sub-agents for reviewer waits — sub-agents in this team context cannot spawn their own sub-agents, and `fx-dev:dev` mode A would fail. You ARE the root agent for the team; invoke each reviewer skill in the foreground sequentially, OR launch the slow waiter (CodeRabbit) as a background `Bash` process while you handle Copilot in the foreground.**

```
# Sequential (simple, always correct):
Skill tool: skill="fx-dev:copilot-review",     args="<PR_NUMBER>"
Skill tool: skill="fx-dev:coderabbit-review",  args="<PR_NUMBER>"

# Or background-overlapped (faster):
# 1. Bash run_in_background:
#      bash <skill>/coderabbit-review/scripts/wait-for-coderabbit-review.sh <PR_NUMBER>
# 2. Foreground: Skill fx-dev:copilot-review
# 3. When Bash task completes: Skill fx-dev:rabbit-feedback-resolver
```

Both reviewers MUST converge: the loop is "wait → resolve → if anyone pushed, wait again". CodeRabbit specifically re-runs on every push and may post new threads on the new SHA. Cap at 4 outer iterations and escalate to user if not converged. Only proceed to merge after BOTH reviewers report terminal-passing checks AND 0 unresolved threads.

If CodeRabbit isn't configured for the repo (no `CodeRabbit` check ever appears, the wait script exits 2), report this to the user once and proceed without that gate. Do not silently skip when it IS configured.

### Browser Verification Gate (Gate 6)

For tasks with UI changes, spawn a dedicated verify agent:

```
Agent tool:
  team_name: "<the-team-you-created>"   # REQUIRED — register as teammate
  name: "verify-<pr-number>"            # REQUIRED — addressable handle
  prompt: "Load the verify-web-change skill (Skill tool: skill='fx-dev:verify-web-change').
           Verify PR #<NUMBER> on branch <branch-name>.
           Check out the branch, start the dev server, and confirm the app loads without errors.
           Report back whether verification passed or failed, with details of any errors."
  description: "Verify PR #<NUMBER> in browser"
  mode: "bypassPermissions"
```

**Why this gate exists:** CI does NOT catch runtime-only errors like circular dependencies, SSR failures, or broken module initialization.

**If a "small" or "follow-up" PR:** Same rules. No exceptions. PR size is NEVER a reason to skip merge gates.

## PRE-MERGE: Change-Doc Status Flip (BLOCKING)

**The FINAL PR for a change document MUST mark the change `complete` IN that PR — NOT in a follow-up.** A change doc still showing `**Status:** draft` after its last implementing PR merges is a bug; the docs lie about state and the index is out of sync with reality on `main`.

There are two places to flip:

1. **Change doc body** — `docs/changes/<NNNN>-<slug>.md` — flip the front-matter line `**Status:** draft` → `**Status:** complete`.
2. **Index** — `docs/index.yml` — flip `status: draft` → `status: complete` on that change's entry. Sync `docs/index.md` if the project keeps both.

### Whose job is it?

**The implementing coder is responsible for the flip** when they are shipping the final piece of a change. That coder's PR description should already note "this completes 0094"; they MUST also include the Status flip in the same PR.

**The coordinator's job, BEFORE merging, is to verify the flip is in the PR's diff.** Add this to your PR-inspection step (Gate 3 — implementation matches spec). If the flip is missing:

1. **Do NOT merge.**
2. Push a tiny commit to the PR branch yourself (or via a focused fix agent) flipping both files. Commit message: `docs(changes): mark <NNNN> complete`.
3. Wait for CI to re-pass on the new commit.
4. Then merge.

This MUST NOT become a follow-up PR. Doing it post-merge means main spent some window in a wrong state, and the user sees a stale `draft` for every change you ship.

### Multi-PR changes

When a change decomposes into multiple PRs (e.g., 0090 split into 0090A and 0090B): only the LAST implementing PR flips Status. Earlier sub-PRs MUST leave Status as `draft`. The coordinator decides which PR is "last" — typically the final task in the change doc's task list. Tell THAT coder explicitly in their spawn prompt to include the Status flip; tell every other coder to leave Status alone (multi-PR rebases against a flipped Status field create spurious conflicts).

If you mis-identified which PR was last and you've already merged a sub-PR with `Status: complete` flipped early, the doc is wrong on main until the remaining PRs land — open a tiny corrective PR flipping it back to `draft` until the real final PR lands.

### Partial implementations

If a single PR is only a partial implementation of its change doc (more PRs to come), the PR MUST leave Status as `draft`. The Status flip rides only with the final piece.

## STEP 4: Shutdown

When all tasks are complete and all PRs merged:

1. Verify all spec tasks are marked done (load `fx-dev:project-management` to check)
2. **Verify every implemented change is `status: complete`** on `main` — check both `docs/changes/<NNNN>-*.md` front-matter AND `docs/index.yml`. If any are still `draft`, you missed the pre-merge gate; open a corrective PR right now (the goal is the gate catches it pre-merge, but if it slipped, fix it before declaring done).
3. Send shutdown requests to all active teammates
4. Clean up the team with `TeamDelete`
5. Report final summary to user

---

## Coordinator Rules (NON-NEGOTIABLE)

- **ALWAYS pass `team_name` AND `name` to EVERY `Agent` call** — coder, verify, fix, anything. Spawning an Agent without these in team mode produces an orphan sub-agent that the team config doesn't know about and defeats the entire point of `/team`. No exceptions.
- **NEVER write code yourself** — all implementation goes through coder agents
- **NEVER create branches or commits** — coder agents handle this
- **NEVER delegate the full SDLC to a single agent** — agents cannot spawn sub-agents, so they will inline everything and skip later steps
- **NEVER skip PR inspection** — every PR gets reviewed before marking ready
- **NEVER merge without completing the MERGE GATE CHECKLIST** — every gate must pass, every time, for every PR
- **NEVER merge without Copilot review** — always invoke `fx-dev:copilot-review` yourself. No exceptions.
- **NEVER merge without CodeRabbit review when CodeRabbit is configured** — always invoke `fx-dev:coderabbit-review` yourself; cycle until its check is `success` and 0 threads. No exceptions.
- **NEVER spawn sub-agents to handle reviewer waits** in the team-coordinator context — sub-agents can't spawn sub-agents. Run reviewer skills in the foreground (or background-Bash for the slow ones).
- **NEVER mark a teammate's PR as ready** until you've inspected it
- **ALWAYS handle Copilot review and CI monitoring directly** — these are coordinator responsibilities, not sub-agent responsibilities
- **ALWAYS use `fx-dev:project-management`** to verify task tracking
- **ALWAYS run the full merge gate checklist** even for "trivial" or "follow-up" PRs
- **NEVER merge without browser verification** — spawn a verify agent if needed. CI alone does NOT catch runtime errors.
- **NEVER merge the FINAL PR of a change doc with `Status: draft` still in the diff.** The flip to `complete` rides in that PR, in both `docs/changes/<NNNN>-*.md` and `docs/index.yml`. If the coder forgot, push a fix commit to their branch and wait for CI before merging. Do NOT defer to a follow-up PR. See PRE-MERGE: Change-Doc Status Flip above.

## Handling Agent Issues

If a coder agent reports problems:

1. Read the error details from their message
2. Spawn a new focused agent to fix the specific issue
3. If stuck after 2 retries, report to user and ask for guidance
