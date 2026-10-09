# fx/cc Marketplace

Claude Code plugins for development workflows, research, and productivity.

## Installation

```bash
/plugin marketplace add fx/cc
```

## Available Plugins

### fx-dev
Complete development workflow including SDLC, pull requests, and GitHub integration.

**Components**:
- 25 skills, invoked explicitly by name:
  - Lifecycle: dev (attended SDLC), team (autonomous wrapper around dev), fix, workflow-runner
  - Planning and docs: requirements-analyzer, planner, spec-writer, project-management, issue-updater, setup, upgrade
  - Pull requests and CI: pr-preparer, pr-check-monitor, resolve-ci-failures, resolve-codecov-feedback, resolve-pr-feedback, github
  - Reviewers: review, copilot-review, coderabbit-review, codex-review
  - Feedback resolvers: copilot-feedback-resolver, rabbit-feedback-resolver
  - Other: verify-web-change, upstream-contrib

### fx-research
Research tools for finding and evaluating technologies and libraries.

**Components**:
- 1 agent: tech-scout

### fx-mcp
MCP server management guidance and best practices.

**Components**:
- 1 skill: managing-mcp-servers

### fx-meta
Meta tools for building Claude Code plugins, skills, and agents.

**Components**:
- 2 skills: skill-creator, plugin-creator

### fx-pa
Personal assistant tools for task extraction and productivity.

**Components**:
- 1 agent: task-extractor

## Usage

After installing plugins:
- Skills are explicit-use only: invoke them by namespaced name or slash command; active workflows may call their named internal skills
- Ordinary semantically similar requests do not auto-start a skill lifecycle
- Agents appear in `/agents` and can be selected explicitly
- Commands are available as slash commands

## Development

See [AGENTS.md](AGENTS.md) for plugin development guidelines, and [REVIEW.md](REVIEW.md) for the review conventions every automated reviewer applies to this repo.

**Quick start**:
1. Create plugin directory: `plugins/<plugin-name>/`
2. Add `.claude-plugin/plugin.json` manifest
3. Add plugin files (skills, agents, etc.)
4. Update `.claude-plugin/marketplace.json`
5. Create PR

## Resources

- [Claude Code Plugin Documentation](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces)
- [Marketplace Manifest](.claude-plugin/marketplace.json)
- [GitHub Repository](https://github.com/fx/cc)

## License

MIT