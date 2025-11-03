# fx-dev

Complete development workflow including SDLC, pull requests, git utilities, and GitHub integration.

## Overview

The fx-dev plugin provides a comprehensive suite of tools for the entire software development lifecycle. From requirements analysis through implementation, code review, PR management, to deployment - everything developers need in one integrated plugin.

## Components

### SDLC Agents (5)

- **sdlc** - Orchestrates complete workflows including planning, implementation, review, and finalization
- **coder** - Implements features, bug fixes, and refactorings with PR creation
- **requirements-analyzer** - Fetches and analyzes GitHub issues, extracts requirements, gathers context
- **planner** - Creates comprehensive implementation plans based on requirements
- **issue-updater** - Updates GitHub issues with planning information and status changes

### PR Management Agents (6)

- **pr-reviewer** - Reviews pull requests, identifies issues, provides actionable feedback
- **pr-preparer** - Prepares PRs for submission, ensures compliance with project standards
- **pr-check-monitor** - Monitors GitHub PR checks and coordinates fixes for failures
- **pr-changeset-minimalist** - Reviews changesets to ensure only minimal necessary changes
- **copilot-feedback-resolver** - Processes and resolves GitHub Copilot automated review comments
- **workflow-runner** - Executes complete workflows from start to finish, ensuring all phases complete

### Commands (2)

- **/dev** - Unified command for all development tasks (GitHub issues, quick fixes, ad-hoc coding)
- **/gitingest** - Analyzes public GitHub repositories to understand structure and contents

## Quick Start

### Implement a GitHub Issue

```bash
/dev https://github.com/owner/repo/issues/123
```

Or find the next logical issue:

```bash
/dev
```

### Quick Fix for an Error

```bash
/dev fix: TypeError in auth.js:42 - Cannot read property 'id' of undefined
```

### Implement a Feature

```bash
/dev Add dark mode toggle to settings page
```

### Analyze a Repository

```bash
/gitingest https://github.com/vercel/next.js
```

## Complete Workflow

The fx-dev plugin manages the entire development workflow:

```
Requirements Analysis (requirements-analyzer)
    ↓
Planning (planner)
    ↓
Issue Update (issue-updater)
    ↓
Implementation (coder)
    ↓
PR Preparation (pr-preparer)
    ↓
Changeset Review (pr-changeset-minimalist)
    ↓
Code Review (pr-reviewer)
    ↓
Copilot Feedback (copilot-feedback-resolver)
    ↓
Check Monitoring (pr-check-monitor)
    ↓
Workflow Completion (workflow-runner)
    ↓
Issue Done (issue-updater)
```

## Agent Descriptions

### SDLC Agents

#### sdlc

Orchestrates the complete software development lifecycle by coordinating specialized agents through planning, implementation, review, and finalization phases.

**Use when:** You need end-to-end orchestration of a fresh implementation

**Key Features:**
- Coordinates multiple specialized agents
- Manages sequential PR workflows
- Ensures quality through review cycles
- Handles error recovery

#### coder

Implements new features, fixes bugs, refactors code, or makes any code changes to the project. Works with GitHub issues or standalone tasks.

**Use when:** You need to implement any code changes

**Key Features:**
- GitHub issue integration
- Automatic issue selection
- PR creation and management
- Test coverage

#### requirements-analyzer

Fetches and analyzes GitHub issues, extracts requirements, gathers context from referenced URLs, and compiles comprehensive requirements documentation.

**Use when:** Starting work on a GitHub issue

**Key Features:**
- GitHub issue fetching
- URL context gathering
- Requirement extraction
- Project pattern analysis

#### planner

Creates comprehensive implementation plans based on requirements analysis. Breaks down complex features into actionable steps and identifies dependencies.

**Use when:** You need a detailed implementation plan

**Key Features:**
- Task breakdown
- Dependency identification
- Architecture design
- Testing strategy

#### issue-updater

Updates GitHub issues with planning information, status changes, and implementation progress. Ensures proper tagging and project board synchronization.

**Use when:** You need to update issue status or add plans

**Key Features:**
- Plan documentation
- Status tracking
- Label management
- Project board integration

### PR Management Agents

#### pr-reviewer

Reviews pull requests with a pragmatic approach, approving PRs with minor issues rather than blocking on nitpicks. Focuses on bugs, security, and performance.

**Use when:** After code changes are complete

**Key Features:**
- Pragmatic review standards
- Copilot comment detection
- Clear decision output (APPROVE/REQUEST CHANGES)
- Actionable feedback

#### pr-preparer

Analyzes branch changes, reviews commit history, and ensures PRs adhere to all project standards before submission.

**Use when:** Before creating a PR

**Key Features:**
- Commit message validation
- Branch naming verification
- Compliance checking
- PR description crafting

#### pr-check-monitor

Monitors GitHub pull request checks and automatically coordinates fixes for failing checks by delegating to appropriate specialized agents.

**Use when:** After PR creation to monitor checks

**Key Features:**
- Continuous check monitoring
- Failure categorization
- Intelligent delegation
- Fix verification

#### pr-changeset-minimalist

Reviews pull requests to ensure they contain only the minimal necessary changes without extraneous modifications or artifacts from commit progression.

**Use when:** Before submitting PR to validate change scope

**Key Features:**
- Scope validation
- Commit progression analysis
- Hidden artifact detection
- Change necessity assessment

#### copilot-feedback-resolver

Processes and resolves GitHub Copilot's automated PR review comments. Distinguishes between outdated, incorrect, and valid concerns.

**Use when:** After Copilot reviews your PR

**Key Features:**
- Automated Copilot comment processing
- Intelligent categorization (nitpicks, outdated, valid)
- Professional explanations for outdated/incorrect feedback
- Updates `.github/copilot-instructions.md` to prevent recurring false positives

#### workflow-runner

Executes complete workflows from start to finish without stopping, ensuring all phases complete and looping until success criteria are met.

**Use when:** You need multi-step workflow execution

**Key Features:**
- Multi-step workflow execution
- PR iteration loops
- Multi-PR coordination
- Continuous momentum

## Command Details

### /dev

Unified development command that intelligently routes to the appropriate workflow based on input.

**Usage:**
```bash
# GitHub issue workflow
/dev https://github.com/owner/repo/issues/123
/dev  # Auto-selects next logical issue

# Quick fix workflow
/dev fix: TypeError in auth.js:42
/dev error: Cannot read property 'id'

# Ad-hoc coding workflow
/dev Add dark mode toggle to settings page
/dev Refactor auth module to use async/await
```

**Intelligent Routing:**
- GitHub issue URL or empty → Full SDLC with issue tracking
- Prefix `fix:`, `error:`, `bug:` → Quick fix workflow
- Other descriptions → Ad-hoc coding workflow

**See:** `commands/dev.md` for complete workflow documentation

### /gitingest

Analyzes public GitHub repositories to understand structure and contents. Useful for learning project organization before contributing.

**Usage:**
```bash
/gitingest <github-url>
```

## Examples

### Example 1: Complete Feature Implementation

```bash
# Implement a feature from a GitHub issue
/dev https://github.com/myorg/myapp/issues/456
```

This automatically:
- Fetches and analyzes the issue
- Creates an implementation plan
- Implements all code changes
- Creates a PR with proper description
- Reviews and iterates until ready
- Monitors checks and fixes failures
- Updates issue status to Done

### Example 2: Quick Bug Fix

```bash
# Fix a specific error quickly
/dev fix: ReferenceError: user is not defined in api/auth.js:42
```

### Example 3: Research Before Contributing

```bash
# Understand a repository structure
/gitingest https://github.com/facebook/react

# Then implement your contribution
/dev Add custom hook for handling form validation
```

### Example 4: Manual PR Workflow

```python
# Prepare PR
Task(
    description="Prepare PR",
    prompt="Prepare PR for authentication feature",
    subagent_type="pr-preparer"
)

# Review for minimal changes
Task(
    description="Check minimal changes",
    prompt="Ensure only necessary changes are included",
    subagent_type="pr-changeset-minimalist"
)

# Review code quality
Task(
    description="Review PR",
    prompt="Review the authentication implementation",
    subagent_type="pr-reviewer"
)

# Handle Copilot feedback
Task(
    description="Resolve Copilot comments",
    prompt="Process Copilot review comments on PR #42",
    subagent_type="copilot-feedback-resolver"
)

# Monitor checks
Task(
    description="Monitor checks",
    prompt="Monitor PR #42 and fix any failures",
    subagent_type="pr-check-monitor"
)
```

## Best Practices

### Development Workflow

1. **Use /dev for all tasks** - Unified command with intelligent routing
2. **GitHub issues** - Use issue URLs for tracked work
3. **Quick fixes** - Use `fix:` prefix for rapid error resolution
4. **Ad-hoc tasks** - Just describe what you want to build
5. **Let agents coordinate** - The SDLC agent handles orchestration

### Pull Request Management

1. **Always prepare PRs** - Use pr-preparer before creating PRs
2. **Review for minimalism** - Run pr-changeset-minimalist to catch extraneous changes
3. **Pragmatic reviews** - pr-reviewer focuses on blocking issues, not perfection
4. **Auto-resolve Copilot nitpicks** - copilot-feedback-resolver handles [nitpick] comments automatically
5. **Monitor checks** - Use pr-check-monitor to catch and fix failures early

### Git Utilities

1. **Research before contributing** - Use /gitingest to understand project structure
2. **Keep fixes focused** - One error per /dev fix command
3. **Verify GitHub auth** - Ensure `gh auth status` succeeds

## Configuration

The agents respect project conventions from:
- `CLAUDE.md` - Project-specific guidelines
- `.github/copilot-instructions.md` - AI coding guidelines (updated by copilot-feedback-resolver)
- Git commit and branch conventions
- GitHub Actions check configurations

## Troubleshooting

### GitHub Authentication

```bash
# Check authentication status
gh auth status

# If not authenticated
gh auth login
```

### Agent Failures

If an agent fails:
1. Check the error message
2. Verify GitHub CLI authentication
3. Ensure proper permissions on the repository
4. Try running the agent again with adjusted parameters

### PR Check Failures

If pr-check-monitor can't fix checks:
1. Review the check failure logs
2. Manually investigate complex failures
3. Adjust GitHub Actions if configuration issues exist

### Review Issues

If pr-reviewer reports issues:
1. Review the specific feedback
2. Use coder agent to fix issues
3. Re-run pr-reviewer after fixes

## Installation

This plugin is part of the fx/cc marketplace. To install:

```bash
# Install from marketplace
/plugin marketplace add /path/to/fx-cc

# Enable fx-dev plugin when prompted
```

## Contributing

To add or modify agents/commands in this plugin:

1. Place agent markdown files in `agents/`
2. Place command markdown files in `commands/`
3. Ensure proper frontmatter with name, description, color
4. Update this README
5. Test locally before submitting

## License

Part of the fx/cc Claude Code marketplace.
