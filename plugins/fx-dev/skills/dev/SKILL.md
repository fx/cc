---
name: dev
description: "MUST BE LOADED for any coding task: implementing features, fixing bugs, writing code, refactoring, or making changes. This skill provides the mandatory step-by-step SDLC (Software Development Lifecycle) workflow for orchestrating development using specialized skills and sub-agents. Load this skill when the user asks to 'add', 'create', 'build', 'fix', 'update', 'change', 'implement', or 'refactor' anything."
---

# Dev — SDLC Workflow Skill

This skill defines the **mandatory** workflow for all coding tasks. Follow these steps IN ORDER. Skipping steps is FORBIDDEN.

## CRITICAL RULES

**YOU MUST USE THE AGENT TOOL TO LAUNCH SUB-AGENTS FOR ALL WORK. Each sub-agent loads the appropriate skill via the Skill tool.**

### How to Launch Sub-Agents with Skills

Skills are NOT agent types. Launch a general-purpose sub-agent and instruct it to load the skill:

```
Agent tool:
  prompt: "Load the [skill-name] skill (Skill tool: skill='[skill-name]'), then:
           [task details]"
  description: "[3-5 word summary]"
```

**Do NOT use `subagent_type` for skills.** The `subagent_type` parameter is reserved for built-in agent types (Explore, Plan, etc.). Skills are loaded inside the sub-agent via the Skill tool.

### Coder Task Reporting (Sub-Agent Restriction)

**Sub-agents MUST NEVER send "idle" or "complete" states via `mcp__coder__coder_report_task`.** Only the main agent session (root conversation) is allowed to report "idle" or "complete". Sub-agents spawned via the Agent tool may only report `"state": "working"`. This prevents sub-agents from overwriting the coordinator's dashboard status and falsely signaling task completion.

- ❌ NEVER write code yourself
- ❌ NEVER create files yourself
- ❌ NEVER make commits yourself
- ❌ NEVER skip steps
- ❌ NEVER skip tests (`test.skip`, `it.skip`, `describe.skip` are FORBIDDEN)
- ❌ NEVER use `subagent_type` for skills — use `Skill tool` inside the sub-agent
- ✅ ALWAYS launch sub-agents via the Agent tool
- ✅ ALWAYS instruct sub-agents to load skills via the Skill tool
- ✅ ALWAYS verify each step before proceeding
- ✅ ALWAYS fix, replace, refactor, or remove tests - never skip them

**FAILURE TO USE SUB-AGENTS = WORKFLOW FAILURE**

### Test Policy

**⛔ NEVER skip tests.** If a test cannot pass:
- **Fix it** - Update assertions to match correct behavior
- **Replace it** - Write a new test that properly validates the behavior
- **Refactor it** - Restructure to test what's actually testable
- **Remove it** - Delete entirely if it tests something that no longer exists

If tests require infrastructure (auth, database, external services), SET UP that infrastructure. Do not skip tests because setup is hard.

---

## MANDATORY STEPS (Execute in Order)

### STEP 0: GitHub Authentication

**Execute FIRST before anything else.**

```bash
gh auth status
```

If fails: STOP. Tell user to run `gh auth login`. Do NOT proceed.

---

### STEP 1: Workspace Preparation

**Create clean feature branch BEFORE any implementation.**

#### 1.1 Check for uncommitted changes

```bash
git status
```

If uncommitted changes exist:
- Ask user: "Uncommitted changes found. Stash them or abort?"
- If stash: `git stash push -m "SDLC auto-stash"`
- If abort: STOP

#### 1.2 Sync and create branch

```bash
git fetch origin
git checkout main
git pull origin main
git checkout -b <type>/<short-description>
```

Branch types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

**⛔ DO NOT PROCEED until branch is created**

---

### STEP 2: Requirements Analysis

**MANDATORY: Launch a sub-agent that loads the requirements-analyzer skill.**

```
Agent tool:
  prompt: "Load the requirements-analyzer skill (Skill tool: skill='fx-dev:requirements-analyzer'), then:

           Analyze requirements for: [TASK DESCRIPTION]

           - Analyze task/issue/error to understand requirements
           - Use WebSearch to research technologies
           - Use WebFetch for referenced URLs
           - Use AskUserQuestion for ambiguities
           - Analyze codebase for patterns

           Output: Complete requirements with acceptance criteria"
  description: "Analyze requirements"
```

For GitHub issues, fetch first:
```bash
gh issue view [NUMBER] --json title,body,labels,comments
```

**⛔ DO NOT PROCEED until requirements are complete**

---

### STEP 3: Planning

**MANDATORY: Launch a sub-agent that loads the planner skill.**

```
Agent tool:
  prompt: "Load the planner skill (Skill tool: skill='fx-dev:planner'), then:

           Create implementation plan for:

           [REQUIREMENTS FROM STEP 2]

           - Break into atomic steps
           - Identify files to modify
           - Determine test requirements
           - Flag if multiple PRs needed

           Output: Numbered implementation steps"
  description: "Plan implementation"
```

For GitHub issues, also update issue:
```
Agent tool:
  prompt: "Load the issue-updater skill (Skill tool: skill='fx-dev:issue-updater'), then:

           Update issue #[NUMBER] with plan. Add label: in-progress"
  description: "Update issue"
```

**⛔ DO NOT PROCEED until plan exists**

---

### STEP 4: Implementation

**MANDATORY: Launch a sub-agent that loads the coder skill.**

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

           Implement this plan:

           [PLAN FROM STEP 3]

           Requirements:
           - Atomic commits (format: type(scope): message)
           - Follow existing patterns
           - Run tests
           - Do NOT create PR"
  description: "Implement changes"
```

Verify commits exist:
```bash
git log --oneline -5
git diff main --stat
```

**⛔ DO NOT PROCEED until commits exist on feature branch**

---

### STEP 4.5: Code Cleanup (simplify)

**MANDATORY: Run the simplify skill before creating the PR.**

```
Skill tool: skill="simplify"
```

This reviews all changed code for:
- **Reuse** — duplicated logic that could use existing utilities
- **Quality** — copy-paste patterns, leaky abstractions, unnecessary nesting
- **Efficiency** — redundant computations, missed concurrency, hot-path bloat

Fix any issues found, commit the fixes, then proceed to PR creation.

**⛔ DO NOT PROCEED until simplify has run and any findings are addressed**

---

### STEP 5: Pull Request Creation (as Draft)

**MANDATORY: Launch a sub-agent that loads the pr-preparer skill. ALL PRs MUST be created as drafts.**

**Before creating the PR, identify related spec and change documents:**

```bash
# Find related change documents (check if task was sourced from a change doc)
ls docs/changes/ 2>/dev/null
# Find related specs
ls docs/specs/ 2>/dev/null
cat docs/index.yml 2>/dev/null
```

If the work was driven by a specific change document or spec, note the paths for inclusion in the PR description.

```
Agent tool:
  prompt: "Load the pr-preparer skill (Skill tool: skill='fx-dev:pr-preparer'), then:

           Create DRAFT PR for current branch.
           Task: [ORIGINAL TASK]
           Summary: [WHAT WAS IMPLEMENTED]

           Spec/Change context (include in PR body if applicable):
           - Spec: [SPEC_PATH or 'none']
           - Change: [CHANGE_DOC_PATH or 'none']

           CRITICAL: Use --draft flag. Never create non-draft PRs.
           - Push branch if needed
           - Create PR with: gh pr create --draft
           - Include links to related spec/change docs in the PR body
             (use relative paths from repo root, e.g. docs/specs/auth/ or docs/changes/0003-add-oauth.md)
           - Do NOT put spec/change references in the PR title unless the PR is
             primarily about finalizing lingering tasks in a spec/change doc
           - Reference related issues
           - Return PR number and URL"
  description: "Create draft PR"
```

**Capture the PR number for remaining steps.**

**⛔ DO NOT PROCEED until PR is created**

---

### STEP 5.5: Test Plan Verification (MANDATORY)

**This step is MANDATORY for every PR that has a test plan.** It is NOT limited to web/UI changes. Backend changes, platform integrations, CLI tools, and infrastructure changes all have test plans that must be addressed.

#### 5.5.1 Extract and Classify the Test Plan

Read the PR description and extract the Test Plan section:

```bash
gh pr view [PR_NUMBER] --json body --jq '.body'
```

Parse the `## Test plan` section. Each `- [ ]` item is a verification target.

If the PR has no Test Plan section, construct one from the PR diff — identify what changed and create verification steps. Add them to the PR description before proceeding.

**Classify each test plan item into one of three categories:**

| Category | Description | Action |
|----------|-------------|--------|
| **Browser-verifiable** | Can be tested via Playwright MCP (UI routes, visual changes, interactions) | Run verify-web-change (Step 5.5.2) |
| **Programmatically verifiable** | Can be tested via CLI, API calls, log inspection, or automated scripts | Run verification commands directly (Step 5.5.3) |
| **Manual-only** | Requires external systems, user accounts, or physical interaction (e.g., "send a Discord message", "check email") | Annotate for user and prompt them to verify (Step 5.5.4) |

#### 5.5.2 Browser Verification (for browser-verifiable items)

**Skip this sub-step if no test plan items are browser-verifiable.**

Detect if browser verification is possible:

```bash
WEB_FILES=$(git diff main --name-only | grep -E '\.(tsx|jsx|vue|svelte|html|css|scss|less)$' || true)

HAS_WEB_STACK=false
for cfg in vite.config.ts vite.config.js next.config.js next.config.ts next.config.mjs nuxt.config.ts svelte.config.js angular.json astro.config.mjs; do
    if [[ -f "$cfg" ]]; then
        HAS_WEB_STACK=true
        break
    fi
done
```

If web changes exist and browser-verifiable items are present, launch the verify-web-change sub-agent:

```
Agent tool:
  prompt: "Load the verify-web-change skill (Skill tool: skill='fx-dev:verify-web-change'), then:

           Verify the following Test Plan items for PR #[PR_NUMBER] using browser automation:

           [BROWSER-VERIFIABLE TEST PLAN ITEMS]

           For each item:
           1. Navigate to the relevant page/route
           2. Use Playwright MCP snapshots to verify the element/behavior exists
           3. Test any interactions described in the test plan item
           4. Check for console errors
           5. Report PASS/FAIL per item with evidence (what you observed)

           Output: A list of each test plan item with its result (PASS/FAIL/SKIPPED) and evidence."
  description: "Verify web changes in browser"
```

#### 5.5.3 Programmatic Verification (for programmatically verifiable items)

**Skip this sub-step if no test plan items are programmatically verifiable.**

For items that can be verified via commands (API calls, log inspection, test runs, etc.), run the verification directly:

- Check test output: `bun --bun run test` — confirm relevant tests pass
- Inspect logs: Check dev server output for expected behavior
- Call APIs: Use `curl` or similar to verify endpoint behavior
- Check database state: Verify schema/data changes applied correctly

Record PASS/FAIL per item with evidence.

#### 5.5.4 Manual Verification (for manual-only items)

**⛔ NEVER silently skip manual-only test plan items.**

For items that require manual interaction (external services, physical devices, user accounts), you MUST:

1. **Tell the user** which items require their manual verification
2. **Explain what to test** — be specific about the steps
3. **Ask them to confirm** each item passes or fails
4. **Wait for their response** before proceeding

Example:
```
The following test plan items require manual verification:
- [ ] Send a message to the Discord bot and verify the typing indicator appears immediately
- [ ] Confirm the typing indicator stays active for responses > 10 seconds

Please test these and let me know the results.
```

#### 5.5.5 Update the Test Plan in the PR Description

**MANDATORY: After all verification (automated + manual), update the PR description.**

```bash
BODY=$(gh pr view [PR_NUMBER] --json body --jq '.body')
```

For each Test Plan item:
- **Verified (pass)**: Change `- [ ]` to `- [x]`
- **Verified (fail)**: Leave as `- [ ]` and append: `— FAILED: [reason]`
- **Manual — confirmed by user**: Change `- [ ]` to `- [x]` and append: `(manually verified)`
- **Manual — not yet verified**: Leave as `- [ ]` and append: `— requires manual testing`

Update the PR:

```bash
gh pr edit [PR_NUMBER] --body "$UPDATED_BODY"
```

**⛔ DO NOT PROCEED to Step 6 until every test plan item has been addressed** — either verified (pass/fail), confirmed by user, or explicitly annotated as requiring manual testing.

#### 5.5.6 Handle Failures

If any Test Plan items failed verification:
1. Launch a sub-agent with the coder skill to fix:
   ```
   Agent tool:
     prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

              Fix these verification failures:
              [FAILURE DETAILS]
              Push fixes to the PR branch."
     description: "Fix verification failures"
   ```
2. After fixes are pushed, re-run the relevant verification step (5.5.2 or 5.5.3)
3. **Maximum 2 fix iterations.** If still failing after 2 attempts, proceed to Step 6 and note the unverified items in the PR description.

**⛔ DO NOT PROCEED until verification passes or max iterations reached**

---

### STEP 6: Review & Quality

**MANDATORY: Execute ALL sub-steps.**

#### 6.1 Self-Review

```
Agent tool:
  prompt: "Load the pr-reviewer skill (Skill tool: skill='fx-dev:pr-reviewer'), then:

           Review PR #[NUMBER] for:
           - Code quality
           - Test coverage
           - Security issues
           - Performance

           Output: Issues found (if any)"
  description: "Review PR"
```

#### 6.2 Fix Issues (if any found)

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

           Fix these issues in PR #[NUMBER]:
           [ISSUES FROM REVIEW]"
  description: "Fix review issues"
```

#### 6.3 Copilot Review (Request, Wait, Resolve)

**MANDATORY: Invoke the copilot-review skill.** This handles the full Copilot lifecycle — requesting review, waiting for it (up to 15 min), and resolving all feedback.

```
Skill tool: skill="fx-dev:copilot-review", args="[PR_NUMBER]"
```

**Copilot reviews EVERY PR automatically — it does NOT need to be configured. It is completely independent of CI. NEVER skip this step.**

The skill will:
1. Request Copilot review via the GitHub API
2. Poll until the review is received (15 min timeout)
3. Invoke `fx-dev:resolve-pr-feedback` to categorize and resolve all threads
4. Confirm 0 unresolved threads remain

**⛔ DO NOT PROCEED until the skill confirms all Copilot feedback is resolved**

---

### STEP 7: CI/CD Monitoring

**MANDATORY: Execute ALL sub-steps. Maximum 3 fix iterations.**

#### 7.1 Analyze Workflow Configuration

Examine `.github/workflows/` to determine if CI checks trigger on draft PRs:

```bash
# Read all workflow files and check their trigger configuration
ls .github/workflows/
```

Look for `pull_request` event triggers in each workflow file:
- **Triggers on drafts**: `pull_request:` with no `types:` filter, or `types:` includes `opened` / `synchronize` without special draft exclusion
- **Does NOT trigger on drafts**: Workflow uses `pull_request_target`, or has conditional like `if: github.event.pull_request.draft == false`, or no `pull_request` trigger at all

Output: Whether CI checks will run on a draft PR.

#### 7.2 Ensure CI Checks Are Triggered

**If workflows do NOT trigger on draft PRs:**

```bash
gh pr ready [PR_NUMBER]
```

This marks the PR as ready for review, which triggers CI workflows that only run on non-draft PRs.

**If workflows DO trigger on drafts:** No action needed — checks should already be running or queued.

#### 7.3 Wait for CI Checks to Start and Complete

**Run the bundled CI check script in the FOREGROUND:**

```bash
# CRITICAL: Run in FOREGROUND — do NOT use run_in_background
bash [SKILL_BASE_DIR]/skills/dev/scripts/wait-for-ci-checks.sh [PR_NUMBER]
```

**⚠️ CRITICAL: Run this script in the FOREGROUND with `timeout: 600000` (10 minutes) on the Bash tool call.** Do NOT use `run_in_background`. Running in the background causes output to be lost and prevents the workflow from properly reacting to the results.

Script behavior:
- Phase 1: Waits for checks to appear (some repos have a startup delay)
- Phase 2: Polls every 30s until all checks complete (timeout: 900s / 15 minutes)
- Exit 0: All checks passed → **proceed to Step 8**
- Exit 1: One or more checks failed → **proceed to Step 7.4**
- Exit 2: Timeout waiting for checks → report to user, ask whether to continue waiting or proceed
- Exit 3: Invalid arguments or gh error

#### 7.4 Handle CI Failures (LOOP — max 3 iterations)

**If Step 7.3 exits with code 1 (failures detected):**

```
Skill tool: skill="fx-dev:resolve-ci-failures"
```

Pass the failure details from the script output to the skill. The skill will:
1. Analyze failure logs and identify root causes
2. Delegate fixes to a sub-agent with the coder skill
3. Push the fixes

**After the skill completes and fixes are pushed, GO BACK TO Step 7.3** — re-run the wait script to monitor the new check run. This creates a loop:

```
Step 7.3 (wait) → fail → Step 7.4 (fix) → Step 7.3 (wait) → ...
```

**⚠️ Maximum 3 iterations.** Track the current iteration count. If checks still fail after 3 fix attempts, STOP and report the persistent failures to the user with full details.

**⛔ DO NOT PROCEED until all checks pass or max iterations reached**

---

### STEP 8: Finalization

#### 8.1 Final Verification (MANDATORY MERGE GATES)

**⛔ ALL of the following must be verified before ANY PR can be merged or marked ready. No exceptions.**

```bash
# 1. CI checks — ALL must be green
gh pr checks [NUMBER]

# 2. Copilot review — MUST be received and resolved (if not already done in Step 6.3)
# Use the dedicated skill — NEVER raw gh api commands
```
```
Skill tool: skill="fx-dev:copilot-review", args="[NUMBER]"
```
```bash
# 3. Unresolved review threads — MUST be 0
gh pr view [NUMBER] --json reviewThreads \
  --jq '[.reviewThreads[] | select(.isResolved == false)] | length'

# 4. Codecov — patch and project checks must pass
gh pr checks [NUMBER]  # verify codecov/patch and codecov/project
```

**Merge gate checklist (every item must pass):**
- [ ] PR is open and mergeable
- [ ] ALL CI checks green
- [ ] Copilot review RECEIVED and ALL threads resolved (via `fx-dev:copilot-review` skill — NEVER raw `gh api`)
- [ ] ALL Copilot review comments addressed and threads resolved
- [ ] CodeRabbit review received and addressed (if configured)
- [ ] Codecov coverage passing with 0 missing lines
- [ ] No unresolved review threads from any reviewer

**PR size is NEVER a reason to skip merge gates.** A 1-line fix gets the same verification as a 1000-line feature.

#### 8.1.1 Mark PR Ready for Review

**After confirming all checks pass and all feedback is resolved, mark the PR as ready:**

```bash
gh pr ready [NUMBER]
```

This removes the draft status so the PR is visible for merge.

#### 8.2 Update Task Tracking Docs

**MANDATORY: Mark completed tasks in the relevant change document or tasks file.**

If a change document or task list was referenced in the original request (e.g., a `docs/changes/NNNN-name.md` or `docs/tasks.md`), use it directly. If none was provided, search for the relevant tracking doc:

```bash
# Look for change documents or tasks that reference the work being done
grep -rl "keyword from task" docs/changes/ docs/tasks.md 2>/dev/null || true
```

Once identified, update the doc to mark completed tasks:
- Check off completed items (e.g., `- [ ]` → `- [x]`)
- Add the PR number: `- [x] Task name (PR #N)`
- Only mark items that are **actually addressed by the changes in this PR**
- If ALL tasks in a change document are now complete, update its Status to `complete`
- Commit the doc update to the PR branch

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

           Update task tracking in [DOC_PATH]:
           - Read the doc and identify tasks completed by PR #[NUMBER]
           - Mark those tasks as done: - [x] Task name (PR #N)
           - Do NOT mark tasks that were not addressed
           - If all tasks in a change doc are done, update Status: complete
           - SYNC INDEXES: Update docs/index.yml (status field) and docs/index.md (table row) to match
           - Commit the change with: docs: mark completed tasks in [DOC_NAME]
           - Push to the PR branch"
  description: "Update task tracking"
```

If no relevant tracking doc is found, skip this step.

#### 8.3 Update Issue (if applicable)

```
Agent tool:
  prompt: "Load the issue-updater skill (Skill tool: skill='fx-dev:issue-updater'), then:

           Update issue #[NUMBER]: Link PR, set label ready-for-review"
  description: "Update issue"
```

#### 8.4 Report to User

```
✅ PR #[NUMBER] ready: [URL]

Changes:
- [summary bullets]

Awaiting your approval to merge.
```

**⚠️ NEVER MERGE WITHOUT USER APPROVAL**
**⚠️ NEVER MERGE WITHOUT ALL MERGE GATES PASSING (Step 8.1)**
**⚠️ NEVER MERGE WITHOUT COPILOT REVIEW RECEIVED AND ADDRESSED**

---

## Workflow Variations

### GitHub Issue URL

1. STEP 0: Auth check
2. STEP 1: Branch as `fix/issue-123-description`
3. Fetch issue: `gh issue view [NUMBER] --json title,body,labels,comments`
4. STEP 2-8: Standard (use issue-updater in Steps 3 and 8)

### Quick Fix (fix:, error:, bug: prefix)

1. STEP 0: Auth check
2. STEP 1: Branch as `fix/short-error-desc`
3. STEP 2: Focus on error analysis, root cause
4. STEPS 3-8: Standard

### Multi-PR Tasks

1. Complete STEPS 1-8 for first PR
2. **STOP** - Wait for user approval
3. Only after approval: Start next PR
4. Track with TodoWrite

**NEVER have multiple PRs open simultaneously**

---

## Error Handling

| Error | Action |
|-------|--------|
| Sub-agent fails | Retry once with adjusted params, then STOP and report |
| Git conflict | STOP, report to user, wait for resolution |
| Tests fail | coder sub-agent fixes, rerun until pass |
| Auth fails | STOP, request `gh auth login` |

---

## Sub-Agent Quick Reference

All sub-agents are launched via the Agent tool. Each loads its skill via the Skill tool inside the sub-agent.

| Step | Skill to Load | Skill Name |
|------|---------------|------------|
| 2 | Requirements Analyzer | `fx-dev:requirements-analyzer` |
| 3 | Planner | `fx-dev:planner` |
| 3,8 | Issue Updater | `fx-dev:issue-updater` |
| 4,6.2,8.2 | Coder | `fx-dev:coder` |
| 4.5 | Code Cleanup | `simplify` |
| 5 | PR Preparer | `fx-dev:pr-preparer` |
| 5.5.2 | Browser Verification | `fx-dev:verify-web-change` |
| 6.1 | PR Reviewer | `fx-dev:pr-reviewer` |
| 6.3 | Copilot Review | `fx-dev:copilot-review` |
| 6.3 | PR Feedback Resolver | `fx-dev:resolve-pr-feedback` (called by copilot-review) |
| 7.4 | CI Failure Resolver | `fx-dev:resolve-ci-failures` |

**Pattern for every sub-agent call:**
```
Agent tool:
  prompt: "Load the [skill-name] skill (Skill tool: skill='[full-skill-name]'), then: [task]"
  description: "[summary]"
```

---

## Success Criteria

Workflow complete when ALL true:
- ✅ Feature branch created from main
- ✅ Requirements documented
- ✅ Plan created
- ✅ Code implemented with atomic commits
- ✅ Code reviewed via /simplify (reuse, quality, efficiency)
- ✅ PR created with description (including links to related specs/changes and test plan)
- ✅ ALL test plan items addressed: browser-verified, programmatically verified, or user-confirmed manual verification (NEVER silently skipped)
- ✅ PR test plan items checked off or annotated with verification results in the PR description
- ✅ Self-review done, issues fixed
- ✅ Automated review feedback resolved (Copilot/CodeRabbit)
- ✅ All CI/CD checks pass
- ✅ Task tracking docs updated (completed tasks marked in relevant change doc or tasks.md)
- ✅ User notified, awaiting merge approval
