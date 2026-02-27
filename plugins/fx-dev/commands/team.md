# Team Command

Spawn a coordinated agent team to implement a spec or multi-task feature. The main agent (you) acts strictly as coordinator — no code, no commits, only delegation and quality control.

## Usage

```bash
/team docs/specs/0001-my-feature.md
/team Implement user authentication with OAuth and session management
/team https://github.com/owner/repo/issues/42
```

## Action

### STEP 0: Understand the Work

1. **If given a spec file path:** Read it to extract all tasks.
2. **If given an issue URL:** Fetch it with `gh issue view`.
3. **If given a description:** Break it into discrete, parallelizable tasks.

Identify:
- Total tasks and their dependencies
- Which tasks can run in parallel vs. which must be sequential
- A sensible agent-to-task mapping (1 agent can own 1-3 related tasks)

### STEP 1: Create the Team

```
TeamCreate tool:
  team_name: "<short-kebab-name>"  # e.g., "auth-feature", "admin-ui"
  description: "<what the team is building>"
```

### STEP 2: Create and Organize Tasks

Use `TaskCreate` for every task identified in Step 0. Set up dependencies with `TaskUpdate` (`addBlockedBy`/`addBlocks`) so agents work in the correct order.

**Task descriptions MUST include:**
- Exactly what to implement (files, components, endpoints)
- Acceptance criteria
- Which spec task(s) it maps to (if from a spec)
- Explicit instruction: "Use `/fx-dev:sdlc` skill and follow ALL steps in order"

### STEP 3: Spawn Teammate Agents

Spawn agents using the Task tool. Each agent gets a clear name and assignment.

```
Task tool:
  subagent_type: "fx-dev:dev"
  team_name: "<team-name>"
  name: "<descriptive-agent-name>"  # e.g., "schema-agent", "ui-agent"
  prompt: "You are a teammate on the <team-name> team.

           YOUR TASK: <task description from TaskCreate>

           MANDATORY WORKFLOW:
           1. Load the SDLC skill: Skill tool: skill='fx-dev:sdlc'
           2. Follow EVERY step of the SDLC workflow in order — no skipping
           3. Use /fx-dev:project-management skill to mark your spec task(s) as done
           4. Include the task completion change in your PR
           5. Create your PR as a DRAFT
           6. Wait for and resolve Copilot/CodeRabbit review feedback
           7. Wait for and resolve CI check failures
           8. Send a message to the coordinator when your PR is ready

           CRITICAL RULES:
           - You MUST follow full SDLC progression (requirements → plan → implement → PR → review → CI)
           - You MUST NOT skip the review or CI steps
           - You MUST NOT mark your PR as ready-for-review yourself
           - You MUST send a message when done with PR URL and summary"
  description: "<3-5 word summary>"
  mode: "bypassPermissions"
```

**Parallelization rules:**
- Spawn agents for independent tasks simultaneously (multiple Task calls in one message)
- For dependent tasks, wait until the blocking agent completes before spawning the next
- Assign blocked tasks to agents only after their dependencies merge

### STEP 4: Coordinate (Your Main Loop)

**You are the coordinator. Your ONLY actions are:**

1. **Monitor** — Watch for teammate messages reporting PR completion
2. **Inspect** — Review each PR for completeness:
   ```bash
   gh pr view <NUMBER> --json title,body,additions,deletions,files,reviews,statusCheckRollup
   gh pr diff <NUMBER>
   ```
3. **Validate** — Verify before marking ready:
   - [ ] Implementation matches the spec/task requirements
   - [ ] Copilot/CodeRabbit feedback has been received AND resolved
   - [ ] CI checks are passing
   - [ ] Spec task marked complete in PR (via project-management skill)
   - [ ] PR description is clear and accurate
4. **Mark ready** — Only when ALL checks pass:
   ```bash
   gh pr ready <NUMBER>
   ```
5. **Merge** — After PR is marked ready and all checks still green:
   ```bash
   gh pr merge <NUMBER> --squash --delete-branch
   ```
6. **Unblock** — After merging, notify waiting agents or spawn agents for newly-unblocked tasks
7. **Repeat** — Continue until all tasks are complete

### STEP 5: Shutdown

When all tasks are complete and all PRs merged:

1. Verify all spec tasks are marked done (load `/fx-dev:project-management` to check)
2. Send shutdown requests to all teammates
3. Clean up the team with `TeamDelete`
4. Report final summary to user

---

## Coordinator Rules (NON-NEGOTIABLE)

- **NEVER write code yourself** — all implementation goes through `fx-dev:dev` agents
- **NEVER create branches or commits** — agents handle this via SDLC
- **NEVER skip PR inspection** — every PR gets reviewed before marking ready
- **NEVER merge without verifying** CI passes and review feedback is resolved
- **NEVER mark a teammate's PR as ready** until you've inspected it
- **ALWAYS use `/fx-dev:project-management`** to verify task tracking
- **ALWAYS ensure agents follow full SDLC** — if an agent skips steps, send them back

## Handling Agent Issues

If an agent reports problems or skips SDLC steps:

1. **Send a message** telling them exactly what step they missed
2. **Do NOT do the work for them** — they must follow the workflow
3. If an agent is stuck after 2 retries, report to user and ask for guidance
