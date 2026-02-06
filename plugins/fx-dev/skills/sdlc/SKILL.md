---
name: sdlc
description: "MUST BE LOADED for any coding task: implementing features, fixing bugs, writing code, refactoring, or making changes. This skill provides the mandatory step-by-step workflow for orchestrating the complete software development lifecycle using specialized agents. Load this skill when the user asks to 'add', 'create', 'build', 'fix', 'update', 'change', 'implement', or 'refactor' anything."
---

# SDLC Workflow Skill

This skill defines the **mandatory** workflow for all coding tasks. Follow these steps IN ORDER. Skipping steps is FORBIDDEN.

## CRITICAL RULES

**YOU MUST USE THE TASK TOOL TO DELEGATE ALL WORK TO SPECIALIZED AGENTS.**

- ❌ NEVER write code yourself
- ❌ NEVER create files yourself
- ❌ NEVER make commits yourself
- ❌ NEVER skip steps
- ❌ NEVER skip tests (`test.skip`, `it.skip`, `describe.skip` are FORBIDDEN)
- ✅ ALWAYS use Task tool with the specified `subagent_type`
- ✅ ALWAYS verify each step before proceeding
- ✅ ALWAYS fix, replace, refactor, or remove tests - never skip them

**FAILURE TO USE AGENTS = WORKFLOW FAILURE**

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

**MANDATORY: Launch requirements-analyzer agent.**

```
Task tool:
  subagent_type: "fx-dev:requirements-analyzer"
  prompt: "Analyze requirements for: [TASK DESCRIPTION]

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

**MANDATORY: Launch planner agent.**

```
Task tool:
  subagent_type: "fx-dev:planner"
  prompt: "Create implementation plan for:

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
Task tool:
  subagent_type: "fx-dev:issue-updater"
  prompt: "Update issue #[NUMBER] with plan. Add label: in-progress"
  description: "Update issue"
```

**⛔ DO NOT PROCEED until plan exists**

---

### STEP 4: Implementation

**MANDATORY: Launch coder agent.**

```
Task tool:
  subagent_type: "fx-dev:coder"
  prompt: "Implement this plan:

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

### STEP 5: Pull Request Creation (as Draft)

**MANDATORY: Launch pr-preparer agent. ALL PRs MUST be created as drafts.**

```
Task tool:
  subagent_type: "fx-dev:pr-preparer"
  prompt: "Create DRAFT PR for current branch.
           Task: [ORIGINAL TASK]
           Summary: [WHAT WAS IMPLEMENTED]

           CRITICAL: Use --draft flag. Never create non-draft PRs.
           - Push branch if needed
           - Create PR with: gh pr create --draft
           - Reference related issues
           - Return PR number and URL
           - Tell user to run 'gh pr ready <NUMBER>' when ready"
  description: "Create draft PR"
```

**Capture the PR number for remaining steps.**

**⛔ DO NOT PROCEED until PR is created**

---

### STEP 6: Review & Quality

**MANDATORY: Execute ALL sub-steps.**

#### 6.1 Self-Review

```
Task tool:
  subagent_type: "fx-dev:pr-reviewer"
  prompt: "Review PR #[NUMBER] for:
           - Code quality
           - Test coverage
           - Security issues
           - Performance

           Output: Issues found (if any)"
  description: "Review PR"
```

#### 6.2 Fix Issues (if any found)

```
Task tool:
  subagent_type: "fx-dev:coder"
  prompt: "Fix these issues in PR #[NUMBER]:
           [ISSUES FROM REVIEW]"
  description: "Fix review issues"
```

#### 6.3 Request and Wait for Copilot Review (10 minute timeout)

**First, request Copilot review via the GitHub API:**

```bash
# Request Copilot review using JSON body format (most reliable)
gh api --method POST /repos/{owner}/{repo}/pulls/[PR_NUMBER]/requested_reviewers \
  --input - <<'EOF'
{"reviewers":["copilot-pull-request-reviewer[bot]"]}
EOF
```

**Then use the bundled script to poll for completion (10 minute timeout):**

```bash
# IMPORTANT: Use the FULL path from the skill's base directory
bash [SKILL_BASE_DIR]/skills/sdlc/scripts/wait-for-copilot-review.sh [PR_NUMBER]
```

**⚠️ CRITICAL: You MUST wait the full 10 minutes.** Do NOT fall back to manual polling with shorter waits. If the script exits with code 2 (review not detected as requested), re-request the review using the JSON body format above and run the script again.

Script behavior:
- Checks if Copilot review was requested
- Polls every 60s until review is received (timeout: 600s / 10 minutes)
- Exit 0: Review received -> **proceed to Step 6.4 immediately**
- Exit 1: Timeout after 10 minutes -> proceed to Step 6.4 anyway (will find no threads)
- Exit 2: Review request not detected -> re-request using JSON body format above, then re-run script

#### 6.4 Handle Automated Review Feedback (Copilot/CodeRabbit)

**ALWAYS invoke this skill after Step 6.3, regardless of whether the Copilot review arrived or timed out.** This skill detects and resolves all unresolved automated review threads.

```
Skill tool: skill="fx-dev:resolve-pr-feedback"
```

**⛔ DO NOT PROCEED until all review issues resolved**

---

### STEP 7: CI/CD Monitoring

**MANDATORY: Launch pr-check-monitor agent.**

```
Task tool:
  subagent_type: "fx-dev:pr-check-monitor"
  prompt: "Monitor PR #[NUMBER] checks.
           - Watch status checks
           - Report failures
           - Identify failure causes

           Output: Check status (pass/fail)"
  description: "Monitor checks"
```

#### Fix Failures (if any)

```
Task tool:
  subagent_type: "fx-dev:coder"
  prompt: "Fix failing checks for PR #[NUMBER]:
           [FAILURE DETAILS]"
  description: "Fix check failures"
```

**Repeat Step 7 until all checks pass.**

**⛔ DO NOT PROCEED until all checks pass**

---

### STEP 8: Finalization

#### 8.1 Final Verification

```bash
gh pr view [NUMBER] --json state,mergeable,reviews,statusCheckRollup
```

Confirm:
- PR is open and mergeable
- All checks pass
- No unresolved comments

#### 8.2 Update Issue (if applicable)

```
Task tool:
  subagent_type: "fx-dev:issue-updater"
  prompt: "Update issue #[NUMBER]: Link PR, set label ready-for-review"
  description: "Update issue"
```

#### 8.3 Report to User

```
✅ PR #[NUMBER] ready: [URL]

Changes:
- [summary bullets]

Awaiting your approval to merge.
```

**⚠️ NEVER MERGE WITHOUT USER APPROVAL**

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
| Agent fails | Retry once with adjusted params, then STOP and report |
| Git conflict | STOP, report to user, wait for resolution |
| Tests fail | coder agent fixes, rerun until pass |
| Auth fails | STOP, request `gh auth login` |

---

## Agent Quick Reference

| Step | Agent | subagent_type |
|------|-------|---------------|
| 2 | Requirements Analyzer | `fx-dev:requirements-analyzer` |
| 3 | Planner | `fx-dev:planner` |
| 3,8 | Issue Updater | `fx-dev:issue-updater` |
| 4,6.2,7 | Coder | `fx-dev:coder` |
| 5 | PR Preparer | `fx-dev:pr-preparer` |
| 6.1 | PR Reviewer | `fx-dev:pr-reviewer` |
| 6.4 | PR Feedback Resolver | Skill: `fx-dev:resolve-pr-feedback` |
| 7 | PR Check Monitor | `fx-dev:pr-check-monitor` |

---

## Success Criteria

Workflow complete when ALL true:
- ✅ Feature branch created from main
- ✅ Requirements documented
- ✅ Plan created
- ✅ Code implemented with atomic commits
- ✅ PR created with description
- ✅ Self-review done, issues fixed
- ✅ Automated review feedback resolved (Copilot/CodeRabbit)
- ✅ All CI/CD checks pass
- ✅ User notified, awaiting merge approval
