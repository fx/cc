# Dev Command

Unified development command that handles GitHub issues, quick fixes, and ad-hoc coding tasks through intelligent workflow routing.

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

## How It Works

The `/dev` command automatically detects the appropriate workflow based on your input:

1. **GitHub Issue Workflow** - If input contains a GitHub issue URL or is empty (auto-selects issue)
2. **Quick Fix Workflow** - If input starts with `fix:`, `error:`, `bug:`, or contains error patterns
3. **Ad-Hoc Coding Workflow** - For all other task descriptions

## Workflows

### 1. GitHub Issue Workflow

**Triggered by:**
- GitHub issue URLs: `https://github.com/owner/repo/issues/123`
- Empty input (auto-selects next logical issue)

**Process:**
1. **Requirements & Planning**
   - Use `requirements-analyzer` to fetch and analyze issue
   - Check for 'planned' label (skip planning if exists)
   - Use `planner` to create implementation plan
   - Use `issue-updater` to add plan and set status

2. **Implementation**
   - Use `coder` to implement all code changes
   - Break large changes into logical chunks
   - Only ONE PR open at a time - get user approval before next

3. **Pull Request**
   - Use `pr-preparer` to create PR with proper description
   - Use `pr-reviewer` to review PR
   - Use `copilot-feedback-resolver` to handle Copilot comments
   - Use `coder` to fix any review issues
   - Re-review after changes

4. **Monitoring & Completion**
   - Use `pr-check-monitor` to watch and fix PR check failures
   - Get user approval for sub-PRs sequentially
   - Use `issue-updater` to update status to Done after merge

**Required Agents:** requirements-analyzer, planner, issue-updater, coder, pr-preparer, pr-reviewer, copilot-feedback-resolver, pr-check-monitor

### 2. Quick Fix Workflow

**Triggered by:**
- Prefix: `fix:`, `error:`, `bug:`
- Error patterns in description

**Process:**
1. **GitHub Authentication Check**
   - Verify `gh auth status`
   - Stop if not authenticated

2. **Error Analysis & Fix**
   - Use `coder` to analyze error and identify root cause
   - Create new fix branch
   - Implement fix with atomic commits
   - Run tests to verify fix

3. **Pull Request**
   - Use `pr-preparer` to create PR with clear description
   - Reference the error being fixed

4. **Monitoring**
   - Use `pr-check-monitor` to watch PR status checks
   - Auto-fix any failures

**Required Agents:** coder, pr-preparer, pr-check-monitor

### 3. Ad-Hoc Coding Workflow

**Triggered by:**
- Any other task description

**Process:**
1. **Planning**
   - Use `planner` to break down task into implementation steps
   - Validate approach and dependencies

2. **Implementation**
   - Use `coder` to implement code changes
   - Break large changes into logical commits
   - Get user approval for each PR when using feature branches

3. **Review & Testing**
   - Use `pr-reviewer` to review code quality
   - Use `coder` to fix any issues found
   - Run tests and ensure all pass

4. **Finalization**
   - Create clean commits with proper messages
   - Prepare code for integration
   - Document changes if needed

**Required Agents:** planner, coder, pr-reviewer

## Examples

### GitHub Issue Examples

```bash
# Implement specific issue
/dev https://github.com/myorg/myapp/issues/456

# Auto-select next logical issue from project board
/dev
```

### Quick Fix Examples

```bash
# Fix a TypeError
/dev fix: TypeError in api/auth.js:42 - Cannot read property 'id' of undefined

# Fix a build error
/dev error: TypeScript compilation error in User model

# Fix a bug
/dev bug: Shopping cart total not updating when items removed
```

### Ad-Hoc Coding Examples

```bash
# Add a new feature
/dev Add dark mode toggle to settings page

# Refactor code
/dev Refactor authentication module to use async/await

# Implement enhancement
/dev Implement caching layer for API responses with Redis
```

## Key Principles

### All Workflows
- **Use agents exclusively** - Never implement directly
- **Follow conventions** - Match existing code style
- **Test thoroughly** - Ensure changes don't break existing code
- **Clean commits** - Atomic, well-described changes

### GitHub Issue Workflow
- **Complete SDLC** - Don't stop until issue is Done
- **Sequential PRs** - Only ONE PR open at a time
- **Iterate on feedback** - Fix all review comments and check failures

### Quick Fix Workflow
- **GitHub CLI required** - Must verify auth before work
- **Quick turnaround** - Focus on rapid error resolution
- **Verified fixes** - Ensure tests pass before creating PR

### Ad-Hoc Coding Workflow
- **Plan first** - Break down complex tasks
- **Incremental PRs** - Create reviewable chunks
- **Quality over speed** - Ensure code quality through review

## Agent Coordination

The command intelligently coordinates these agents based on workflow:

**SDLC Agents:**
- `sdlc` - Overall workflow orchestration
- `requirements-analyzer` - GitHub issue analysis
- `planner` - Implementation planning
- `issue-updater` - GitHub issue status updates

**Implementation Agents:**
- `coder` - Code implementation and fixes

**PR Management Agents:**
- `pr-preparer` - PR preparation and creation
- `pr-reviewer` - Code quality review
- `pr-check-monitor` - CI/CD check monitoring
- `copilot-feedback-resolver` - Copilot comment handling

## Error Handling

**GitHub Authentication (Quick Fix Only):**
- If `gh auth status` fails: STOP immediately
- Request user to run: `gh auth login`
- Never proceed without GitHub access

**Agent Failures:**
- Capture error details
- Retry with adjusted parameters
- Report blockers clearly
- Never leave work incomplete

**Ambiguous Requirements:**
- Use agents to research codebase
- Ask user for clarification
- Break into smaller subtasks if needed

## Migration from Old Commands

This unified command replaces three separate commands:

| Old Command | New Command | Notes |
|-------------|-------------|-------|
| `/issue [url]` | `/dev [url]` | Same behavior for GitHub issues |
| `/coder <task>` | `/dev <task>` | Same behavior for ad-hoc tasks |
| `/fix <error>` | `/dev fix: <error>` | Add `fix:` prefix for clarity |

**Why consolidate?**
- Significant overlap in agent usage
- Single entry point is more intuitive
- Intelligent routing based on input
- Easier to maintain and extend

## Tips

1. **Be specific** - Clear descriptions get better results
2. **Use prefixes** - `fix:`, `error:`, `bug:` for quick fixes
3. **GitHub URLs** - Full issue URL for tracked work
4. **Trust routing** - The command detects the right workflow
5. **Review PRs** - Always review generated PRs before merging
