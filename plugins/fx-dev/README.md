# fx-dev

Complete development workflow including SDLC, pull requests, git utilities, and GitHub integration.

## Overview

The fx-dev plugin provides a comprehensive suite of skills for the entire software development lifecycle. From requirements analysis through implementation, code review, PR management, to deployment - everything developers need in one integrated plugin.

## Components

### Skills (23)

#### SDLC Skills
- **dev** - Orchestrates the complete SDLC workflow including planning, implementation, review, and finalization
- **fix** - Test-first bug fix workflow (write failing test, then fix, then verify)
- **team** - Coordinated multi-sub-agent implementation for specs and multi-task features
- **coder** - Implements features, bug fixes, and refactorings; when used within the SDLC workflow, PR creation is handled by **pr-preparer**
- **requirements-analyzer** - Fetches and analyzes GitHub issues, extracts requirements, gathers context
- **planner** - Creates comprehensive implementation plans based on requirements
- **issue-updater** - Updates GitHub issues with planning information and status changes

#### PR Management Skills
- **pr-reviewer** - Reviews pull requests, identifies issues, provides actionable feedback
- **pr-preparer** - Prepares PRs for submission, ensures compliance with project standards
- **pr-check-monitor** - Monitors GitHub PR checks and coordinates fixes for failures
- **pr-changeset-minimalist** - Reviews changesets to ensure only minimal necessary changes
- **workflow-runner** - Executes complete workflows from start to finish, ensuring all phases complete

#### Review & CI Skills
- **copilot-feedback-resolver** - Processes and resolves GitHub Copilot automated PR review comments
- **rabbit-feedback-resolver** - Processes and resolves CodeRabbit automated PR review comments
- **resolve-pr-feedback** - Meta-skill that checks for all unresolved automated review feedback
- **resolve-ci-failures** - Analyzes and fixes CI check failures on PRs
- **resolve-codecov-feedback** - Processes Codecov coverage reports and adds missing tests

#### Other Skills
- **github** - Comprehensive guidance for GitHub CLI operations, PRs, and API usage
- **project-management** - Manages project tasks through docs/tasks.md and docs/changes/
- **spec-writer** - Creates and maintains living specification documents
- **setup** - Initializes docs/ folder structure for spec-driven development
- **upstream-contrib** - Contributes local UI component changes upstream to @fx/ui
- **verify-web-change** - Verifies web application changes work in a real browser

## Quick Start

### Implement a GitHub Issue

Just describe the work — the `dev` skill auto-triggers:

```
Implement https://github.com/owner/repo/issues/123
```

### Quick Bug Fix

```
Fix the TypeError in auth.js:42 - Cannot read property 'id' of undefined
```

### Implement a Feature

```
Add dark mode toggle to settings page
```

### Parallel Team Implementation

```
Use the team skill to implement docs/specs/auth/
```

## Complete Workflow

The fx-dev plugin manages the entire development workflow:

```
Requirements Analysis (requirements-analyzer skill)
    ↓
Planning (planner skill)
    ↓
Issue Update (issue-updater skill)
    ↓
Implementation (coder skill)
    ↓
PR Preparation (pr-preparer skill)
    ↓
Changeset Review (pr-changeset-minimalist skill)
    ↓
Code Review (pr-reviewer skill)
    ↓
Automated Feedback (copilot-feedback-resolver, rabbit-feedback-resolver skills)
    ↓
Check Monitoring (pr-check-monitor skill)
    ↓
Issue Done (issue-updater skill)
```

## Skill Descriptions

### SDLC Skills

#### dev
Orchestrates the complete software development lifecycle by coordinating sub-agents through planning, implementation, review, and finalization phases.

#### coder
Implements new features, fixes bugs, refactors code, or makes any code changes to the project.

#### fix
Test-first bug fix workflow. Mandates writing a failing test that reproduces the bug before implementing any fix.

#### team
Spawns coordinated sub-agent teams for parallel implementation of specs or multi-task features. The main session acts as coordinator.

#### requirements-analyzer
Fetches and analyzes GitHub issues, extracts requirements, gathers context from referenced URLs.

#### planner
Creates comprehensive implementation plans based on requirements analysis.

#### issue-updater
Updates GitHub issues with planning information, status changes, and implementation progress.

### PR Management Skills

#### pr-reviewer
Reviews pull requests with a pragmatic approach. Focuses on bugs, security, and performance.

#### pr-preparer
Analyzes branch changes, reviews commit history, and ensures PRs adhere to project standards.

#### pr-check-monitor
Monitors GitHub pull request checks and coordinates fixes for failing checks via sub-agents.

#### pr-changeset-minimalist
Reviews changesets to ensure only minimal necessary changes without extraneous modifications.

#### workflow-runner
Executes complete workflows from start to finish, looping until success criteria are met.

### Review & CI Skills

#### copilot-feedback-resolver
Processes and resolves GitHub Copilot's automated PR review comments.

#### resolve-pr-feedback
Meta-skill that detects all unresolved automated feedback (Copilot, CodeRabbit, Codecov) and invokes appropriate resolvers.

## Best Practices

### Development Workflow

1. **Describe what you want** - Skills auto-trigger based on your request
2. **GitHub issues** - Provide issue URLs for tracked work
3. **Bug fixes** - Describe the bug; the fix skill enforces test-first
4. **Multi-PR work** - Use the team skill for parallel implementation
5. **Let the dev skill coordinate** - It handles orchestration via sub-agents

### Pull Request Management

1. **Always prepare PRs** - pr-preparer runs before creating PRs
2. **Review for minimalism** - pr-changeset-minimalist catches extraneous changes
3. **Pragmatic reviews** - pr-reviewer focuses on blocking issues, not perfection
4. **Auto-resolve feedback** - copilot-feedback-resolver and rabbit-feedback-resolver handle automated comments
5. **Monitor checks** - pr-check-monitor catches and fixes CI failures

## Configuration

The skills respect project conventions from:
- `CLAUDE.md` - Project-specific guidelines
- `.github/copilot-instructions.md` - AI coding guidelines
- Git commit and branch conventions
- GitHub Actions check configurations

## Troubleshooting

### GitHub Authentication

```bash
gh auth status
gh auth login  # if not authenticated
```

### Sub-Agent Failures

1. Check the error message
2. Verify GitHub CLI authentication
3. Ensure proper permissions on the repository
4. Try running the sub-agent again with adjusted parameters

## Installation

This plugin is part of the fx/cc marketplace.

## Contributing

To add or modify skills in this plugin:

1. Place skill directories in `skills/`
2. Ensure proper SKILL.md frontmatter with name and description
3. Update this README
4. Test locally before submitting

## License

Part of the fx/cc Claude Code marketplace.
