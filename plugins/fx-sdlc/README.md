# fx-sdlc

Complete Software Development Lifecycle (SDLC) workflow tools for implementing features end-to-end.

## Overview

The fx-sdlc plugin provides a comprehensive set of agents and commands for managing the complete software development lifecycle, from requirements analysis through implementation to completion.

## Components

### Agents

- **sdlc** - Orchestrates complete SDLC workflows including planning, implementation, review, and finalization
- **coder** - Implements features, bug fixes, and refactorings with PR creation
- **requirements-analyzer** - Fetches and analyzes GitHub issues, extracts requirements, gathers context
- **planner** - Creates comprehensive implementation plans based on requirements
- **issue-updater** - Updates GitHub issues with planning information and status changes

### Commands

- **/issue** - Implements GitHub issues through complete SDLC workflow (requirements → planning → implementation → PR → done)
- **/coder** - Implements coding tasks using specialized agents for planning, implementation, and review (no GitHub issue required)

## Usage

### Implementing a GitHub Issue

```bash
/issue https://github.com/owner/repo/issues/123
```

Or let it find the next logical issue:

```bash
/issue
```

The `/issue` command will:
1. Fetch and analyze requirements
2. Create implementation plan
3. Implement code changes
4. Create and review PR
5. Monitor checks and fix failures
6. Update issue status to Done

### Implementing Without an Issue

```bash
/coder Add dark mode toggle to settings page
```

The `/coder` command provides the same workflow without requiring a GitHub issue.

### Using Agents Directly

Agents can be invoked programmatically via the Task tool:

```python
# Analyze requirements
Task(
    description="Analyze requirements",
    prompt="Analyze requirements for issue #123",
    subagent_type="requirements-analyzer"
)

# Create implementation plan
Task(
    description="Create plan",
    prompt="Create implementation plan for user authentication",
    subagent_type="planner"
)

# Implement code
Task(
    description="Implement feature",
    prompt="Implement the authentication feature",
    subagent_type="coder"
)
```

## Workflow

The typical SDLC workflow managed by this plugin:

```
Requirements Analysis (requirements-analyzer)
    ↓
Planning (planner)
    ↓
Issue Update (issue-updater)
    ↓
Implementation (coder)
    ↓
PR Review (pr-reviewer from fx-pr)
    ↓
Monitoring (pr-check-monitor from fx-pr)
    ↓
Completion (issue-updater)
```

## Agent Descriptions

### sdlc

Orchestrates the complete software development lifecycle by coordinating specialized agents through planning, implementation, review, and finalization phases. Use this agent when you need end-to-end orchestration of a fresh implementation.

**Key Features:**
- Coordinates multiple specialized agents
- Manages sequential PR workflows
- Ensures quality through review cycles
- Handles error recovery

### coder

Implements new features, fixes bugs, refactors code, or makes any code changes to the project. This agent can work with GitHub issues or standalone tasks, creating complete implementations with PRs.

**Key Features:**
- GitHub issue integration
- Automatic issue selection
- PR creation and management
- Test coverage

### requirements-analyzer

Fetches and analyzes GitHub issues, extracts requirements, gathers context from referenced URLs, and compiles comprehensive requirements documentation.

**Key Features:**
- GitHub issue fetching
- URL context gathering
- Requirement extraction
- Project pattern analysis

### planner

Creates comprehensive implementation plans based on requirements analysis. Breaks down complex features into actionable steps and identifies dependencies.

**Key Features:**
- Task breakdown
- Dependency identification
- Architecture design
- Testing strategy

### issue-updater

Updates GitHub issues with planning information, status changes, and implementation progress. Ensures proper tagging and project board synchronization.

**Key Features:**
- Plan documentation
- Status tracking
- Label management
- Project board integration

## Dependencies

This plugin works best when combined with:
- **fx-pr** - For PR review, preparation, and check monitoring
- **fx-git** - For git-related utilities

## Installation

This plugin is part of the fx/cc marketplace. To install:

```bash
# Install from marketplace
/plugin marketplace add /path/to/fx-cc

# Enable fx-sdlc plugin
# (You'll be prompted when the plugin is needed)
```

## Examples

### Example 1: Full Issue Implementation

```bash
# Implement a complete feature from a GitHub issue
/issue https://github.com/myorg/myapp/issues/456
```

This will:
- Fetch and analyze the issue
- Create an implementation plan
- Implement all code changes
- Create a PR with proper description
- Review and iterate until ready
- Update issue status

### Example 2: Quick Coding Task

```bash
# Implement a feature without a GitHub issue
/coder Refactor authentication module to use async/await
```

### Example 3: Multi-Step Workflow

```bash
# For complex features requiring manual oversight
/issue https://github.com/myorg/myapp/issues/789

# The workflow will pause for approval between PRs if the feature
# is broken into multiple parts
```

## Best Practices

1. **Use /issue for GitHub-tracked work** - Ensures proper documentation and tracking
2. **Use /coder for quick tasks** - When you don't need full issue tracking
3. **Let agents coordinate** - The SDLC agent handles orchestration
4. **Review PRs before merging** - Always review generated PRs before merging
5. **Keep PRs focused** - The agents will break large changes into logical chunks

## Configuration

The agents respect project conventions from:
- `CLAUDE.md` - Project-specific guidelines
- `.github/copilot-instructions.md` - AI coding guidelines
- Git commit and branch conventions

## Troubleshooting

### Agent Failures

If an agent fails:
1. Check the error message
2. Verify GitHub CLI authentication: `gh auth status`
3. Ensure proper permissions on the repository
4. Try running the agent again with adjusted parameters

### PR Issues

For PR-related problems:
1. Ensure the fx-pr plugin is enabled
2. Check that all required checks are configured
3. Verify branch protection rules
4. Review commit message formatting

## Contributing

To add or modify agents/commands in this plugin:

1. Place agent markdown files in `agents/`
2. Place command markdown files in `commands/`
3. Ensure frontmatter is properly formatted
4. Update this README with new components
5. Test the plugin locally before submitting

## License

Part of the fx/cc Claude Code marketplace.
