# fx-pr

Comprehensive pull request management tools for review, preparation, quality assurance, and automated monitoring.

## Overview

The fx-pr plugin provides specialized agents for managing the entire pull request lifecycle, from preparation and review to automated check monitoring and feedback resolution.

## Components

### Agents

- **pr-reviewer** - Reviews pull requests and code changes, identifies issues, provides actionable feedback
- **pr-preparer** - Prepares pull requests for submission, ensures compliance with project standards
- **pr-check-monitor** - Monitors GitHub PR checks and coordinates fixes for failures
- **pr-changeset-minimalist** - Reviews changesets to ensure only minimal necessary changes
- **copilot-feedback-resolver** - Processes and resolves GitHub Copilot automated review comments
- **workflow-runner** - Executes complete workflows from start to finish, ensuring all phases complete

## Usage

### Reviewing a Pull Request

```python
# After code changes are made
Task(
    description="Review PR",
    prompt="Review the changes in this PR",
    subagent_type="pr-reviewer"
)
```

### Preparing a PR for Submission

```python
# Before creating a PR
Task(
    description="Prepare PR",
    prompt="Prepare the PR for submission",
    subagent_type="pr-preparer"
)
```

### Monitoring PR Checks

```python
# After PR is created
Task(
    description="Monitor checks",
    prompt="Monitor PR #123 and fix any failing checks",
    subagent_type="pr-check-monitor"
)
```

### Resolving Copilot Comments

```python
# After Copilot reviews your PR
Task(
    description="Resolve Copilot feedback",
    prompt="Handle Copilot comments on PR #42",
    subagent_type="copilot-feedback-resolver"
)
```

### Ensuring Minimal Changes

```python
# Before submitting PR
Task(
    description="Verify minimal changes",
    prompt="Review changes and ensure only essential modifications are included",
    subagent_type="pr-changeset-minimalist"
)
```

## Workflow

Typical PR workflow managed by this plugin:

```
PR Preparation (pr-preparer)
    ↓
Minimal Change Review (pr-changeset-minimalist)
    ↓
Code Review (pr-reviewer)
    ↓
Copilot Feedback (copilot-feedback-resolver)
    ↓
Check Monitoring (pr-check-monitor)
    ↓
Workflow Completion (workflow-runner)
```

## Agent Descriptions

### pr-reviewer

Reviews pull requests with a pragmatic approach, approving PRs with minor issues rather than blocking on nitpicks. Focuses on bugs, security, and performance issues.

**Key Features:**
- Pragmatic review standards
- Copilot comment detection
- Clear decision output (APPROVE/REQUEST CHANGES)
- Actionable feedback

### pr-preparer

Analyzes branch changes, reviews commit history, and ensures PRs adhere to all project standards before submission.

**Key Features:**
- Commit message validation
- Branch naming verification
- Compliance checking
- PR description crafting

### pr-check-monitor

Monitors GitHub pull request checks and automatically coordinates fixes for failing checks by delegating to appropriate specialized agents.

**Key Features:**
- Continuous check monitoring
- Failure categorization
- Intelligent delegation
- Fix verification

### pr-changeset-minimalist

Reviews pull requests to ensure they contain only the minimal necessary changes without extraneous modifications or artifacts from commit progression.

**Key Features:**
- Scope validation
- Commit progression analysis
- Hidden artifact detection
- Change necessity assessment

### copilot-feedback-resolver

Processes and resolves GitHub Copilot's automated PR review comments. Distinguishes between outdated, incorrect, and valid concerns.

**Key Features:**
- Automated Copilot comment processing
- Intelligent categorization (nitpicks, outdated, valid)
- Professional explanations for outdated/incorrect feedback
- Delegation for valid concerns
- Updates `.github/copilot-instructions.md` to prevent recurring false positives

### workflow-runner

Executes complete workflows from start to finish without stopping, ensuring all phases complete and looping until success criteria are met.

**Key Features:**
- Multi-step workflow execution
- PR iteration loops
- Multi-PR coordination
- Continuous momentum

## Integration with Other Plugins

This plugin works seamlessly with:
- **fx-sdlc** - Provides PR tools for SDLC workflows
- **fx-git** - Git utilities complement PR workflows

## Installation

This plugin is part of the fx/cc marketplace. To install:

```bash
# Install from marketplace
/plugin marketplace add /path/to/fx-cc

# Enable fx-pr plugin when prompted
```

## Examples

### Example 1: Complete PR Workflow

```python
# 1. Prepare the PR
Task(
    description="Prepare PR",
    prompt="Prepare PR for authentication feature",
    subagent_type="pr-preparer"
)

# 2. Review for minimal changes
Task(
    description="Check minimal changes",
    prompt="Ensure only necessary changes are included",
    subagent_type="pr-changeset-minimalist"
)

# 3. Review code quality
Task(
    description="Review PR",
    prompt="Review the authentication implementation",
    subagent_type="pr-reviewer"
)

# 4. Handle Copilot feedback
Task(
    description="Resolve Copilot comments",
    prompt="Process Copilot review comments on PR #42",
    subagent_type="copilot-feedback-resolver"
)

# 5. Monitor checks
Task(
    description="Monitor checks",
    prompt="Monitor PR #42 and fix any failures",
    subagent_type="pr-check-monitor"
)
```

### Example 2: Quick PR Review

```python
# Simple review after implementing a fix
Task(
    description="Review fix",
    prompt="Review the bug fix changes",
    subagent_type="pr-reviewer"
)
```

### Example 3: Automated Check Fixing

```python
# After PR creation, automatically monitor and fix checks
Task(
    description="Auto-fix checks",
    prompt="Monitor PR #123 and automatically fix any failing checks",
    subagent_type="pr-check-monitor"
)
```

## Best Practices

1. **Always prepare PRs** - Use pr-preparer before creating PRs
2. **Review for minimalism** - Run pr-changeset-minimalist to catch extraneous changes
3. **Pragmatic reviews** - pr-reviewer focuses on blocking issues, not perfection
4. **Auto-resolve Copilot nitpicks** - copilot-feedback-resolver handles [nitpick] comments automatically
5. **Monitor checks** - Use pr-check-monitor to catch and fix failures early
6. **Iterate workflows** - workflow-runner ensures completion of multi-step processes

## Configuration

The agents respect:
- `CLAUDE.md` - Project conventions
- `.github/copilot-instructions.md` - Copilot guidelines (updated by copilot-feedback-resolver)
- Git commit and branch naming conventions
- GitHub Actions check configurations

## Troubleshooting

### Review Failures

If pr-reviewer reports issues:
1. Review the specific feedback
2. Use coder agent (from fx-sdlc) to fix issues
3. Re-run pr-reviewer after fixes

### Check Monitor Issues

If pr-check-monitor can't fix checks:
1. Review the check failure logs
2. Manually investigate complex failures
3. Adjust GitHub Actions if configuration issues exist

### Copilot Feedback Issues

If copilot-feedback-resolver struggles:
1. Check `.github/copilot-instructions.md` for existing patterns
2. Manually review Copilot comments
3. Add patterns to copilot-instructions.md to prevent recurrence

## Contributing

To add or modify agents in this plugin:

1. Place agent markdown files in `agents/`
2. Ensure proper frontmatter with name, description, color
3. Update this README
4. Test locally before submitting

## License

Part of the fx/cc Claude Code marketplace.
