# Dev Command

Unified development command that handles GitHub issues, quick fixes, and ad-hoc coding tasks through a single core workflow.

## CRITICAL: Agent-Only Implementation

**YOU MUST USE THE TASK TOOL TO DELEGATE ALL WORK TO AGENTS. NEVER IMPLEMENT CODE DIRECTLY.**

- NEVER write code, create files, or make commits yourself - agents do ALL implementation
- Use the Task tool with the appropriate `subagent_type` for each step

## Agent Reference

| Agent | subagent_type | Purpose |
|-------|---------------|---------|
| Requirements Analyzer | `fx-dev:requirements-analyzer` | **First step** - Researches, clarifies, and documents complete requirements |
| Planner | `fx-dev:planner` | Creates implementation plans from requirements analysis |
| Coder | `fx-dev:coder` | Implements code changes, fixes bugs, creates PRs |
| PR Preparer | `fx-dev:pr-preparer` | Prepares and creates pull requests |
| PR Reviewer | `fx-dev:pr-reviewer` | Reviews code quality |
| PR Check Monitor | `fx-dev:pr-check-monitor` | Monitors CI/CD checks |
| Issue Updater | `fx-dev:issue-updater` | Updates GitHub issue status |

### Skills

| Skill | Invocation | Purpose |
|-------|------------|---------|
| Copilot Feedback Resolver | Use Skill tool with `"fx-dev:copilot-feedback-resolver"` | Resolves Copilot review comments |

## Usage

```bash
# GitHub issue workflow
/dev https://github.com/owner/repo/issues/123
/dev  # Auto-selects next logical issue

# Quick fix workflow
/dev fix: TypeError in auth.js:42
/dev error: Cannot read property 'id' of undefined

# Ad-hoc coding workflow
/dev Add dark mode toggle to settings page
/dev Refactor auth module to use async/await
```

## Workflow Detection

The `/dev` command detects the workflow type based on input:

| Input Pattern | Workflow Type |
|---------------|---------------|
| GitHub issue URL or empty | GitHub Issue |
| Starts with `fix:`, `error:`, `bug:` | Quick Fix |
| Any other task description | Ad-Hoc |

---

## Core Workflow (ALL TYPES)

**Every workflow follows these same core steps. ALL workflows result in a Pull Request.**

### Step 1: Requirements Analysis (ALWAYS FIRST)

```
Task tool: subagent_type="fx-dev:requirements-analyzer"
→ Analyze the task/issue/error to understand requirements
→ Use WebSearch to research technologies and best practices
→ Use WebFetch to retrieve content from referenced URLs
→ Use AskUserQuestion to clarify ambiguous requirements
→ Analyze existing codebase for relevant patterns
→ Output: Complete requirements document for planner
```

### Step 2: Planning

```
Task tool: subagent_type="fx-dev:planner"
→ Receive requirements from requirements-analyzer
→ Create implementation plan with specific steps
→ Break down into logical, atomic changes
```

### Step 3: Implementation

```
Task tool: subagent_type="fx-dev:coder"
→ Implement all code changes
→ Create atomic commits with clear messages
→ Run tests to verify changes work
```

### Step 4: Pull Request Creation

```
Task tool: subagent_type="fx-dev:pr-preparer"
→ Create PR with proper description
→ Reference the task/issue being addressed
```

### Step 5: Review & Fix

```
Task tool: subagent_type="fx-dev:pr-reviewer"
→ Review the PR for code quality
```
```
Skill tool: skill="fx-dev:copilot-feedback-resolver"
→ Handle any Copilot review comments (this is a skill, not an agent)
```
```
Task tool: subagent_type="fx-dev:coder"
→ Fix any issues found in review
```

### Step 6: CI/CD Monitoring

```
Task tool: subagent_type="fx-dev:pr-check-monitor"
→ Watch PR status checks
→ Fix any check failures
```

---

## Workflow-Specific Additions

### GitHub Issue Workflow

**Additional steps beyond core workflow:**

**Before Step 1** - Fetch the GitHub issue:
```
Use gh CLI or WebFetch to retrieve issue details
→ Extract requirements, acceptance criteria, referenced URLs
→ Pass all context to requirements-analyzer
```

**After Step 2** - Update the issue with the plan:
```
Task tool: subagent_type="fx-dev:issue-updater"
→ Add implementation plan to issue
→ Set appropriate status/labels
```

**After Step 6** - Update issue on completion:
```
Task tool: subagent_type="fx-dev:issue-updater"
→ Update status to Done after PR merge
→ Add any relevant notes
```

### Quick Fix Workflow

**Additional steps beyond core workflow:**

**Before Step 1** - Verify GitHub authentication:
```bash
gh auth status
# STOP if not authenticated - request user to run: gh auth login
```

**Step 1 adjustment** - Requirements analyzer focuses on:
- Error analysis and root cause identification
- Reproducing the issue
- Identifying affected files and code paths

### Ad-Hoc Coding Workflow

**No additional steps** - follows core workflow exactly.

---

## Example Task Tool Invocations

### Requirements Analyzer (Step 1)
```
Task tool call:
  subagent_type: "fx-dev:requirements-analyzer"
  prompt: "Analyze the requirements for: [TASK DESCRIPTION]
           Research relevant technologies, fetch any referenced URLs,
           clarify ambiguous requirements with the user, and analyze
           the existing codebase for patterns. Output complete
           requirements documentation for the planner."
  description: "Analyze requirements"
```

### Planner (Step 2)
```
Task tool call:
  subagent_type: "fx-dev:planner"
  prompt: "Create implementation plan based on these requirements:
           [REQUIREMENTS FROM STEP 1]
           Break down into specific implementation steps."
  description: "Plan implementation"
```

### Coder (Step 3)
```
Task tool call:
  subagent_type: "fx-dev:coder"
  prompt: "Implement the following based on this plan:
           [PLAN FROM STEP 2]
           Follow existing patterns and create atomic commits."
  description: "Implement changes"
```

### PR Preparer (Step 4)
```
Task tool call:
  subagent_type: "fx-dev:pr-preparer"
  prompt: "Create a pull request for the current branch.
           Reference: [TASK/ISSUE DESCRIPTION]"
  description: "Create PR"
```

---

## Key Principles

### MANDATORY: Agent-Only Implementation
- **NEVER write code directly** - Always use `fx-dev:coder`
- **NEVER create files directly** - Always use `fx-dev:coder`
- **NEVER make git commits directly** - Always use agents
- **Use Task tool for ALL implementation work**

### All Workflows
- **Always start with requirements-analyzer** - No exceptions
- **Always end with a PR** - Every workflow produces a pull request
- **Use agents exclusively** - This is NOT optional
- **Follow conventions** - Match existing code style
- **Test thoroughly** - Ensure changes don't break existing code
- **Clean commits** - Atomic, well-described changes

### GitHub Issue Workflow Specifics
- **Fetch issue first** - Get all context before requirements analysis
- **Update issue throughout** - Keep the issue updated with progress
- **Sequential PRs** - Only ONE PR open at a time for an issue

## Error Handling

**GitHub Authentication:**
- If `gh auth status` fails: STOP immediately
- Request user to run: `gh auth login`
- Never proceed without GitHub access for issue workflows

**Agent Failures:**
- Capture error details
- Retry with adjusted parameters
- Report blockers clearly
- Never leave work incomplete

**Ambiguous Requirements:**
- requirements-analyzer should use AskUserQuestion
- Break into smaller subtasks if needed

## Tips

1. **Be specific** - Clear descriptions get better results
2. **Use prefixes** - `fix:`, `error:`, `bug:` for quick fixes
3. **GitHub URLs** - Full issue URL for tracked work
4. **Trust the workflow** - Every type follows the same core steps
5. **Review PRs** - Always review generated PRs before merging
