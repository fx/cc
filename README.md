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
- 10 agents: sdlc, coder, planner, requirements-analyzer, issue-updater, pr-reviewer, pr-preparer, pr-check-monitor, pr-changeset-minimalist, workflow-runner
- 1 skill: copilot-feedback-resolver
- 2 commands: /dev, /gitingest

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
- Skills are automatically invoked by Claude when relevant
- Agents appear in `/agents` list and can be used via Task tool
- Commands are available as slash commands

## Development

See [CLAUDE.md](CLAUDE.md) for plugin development guidelines.

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