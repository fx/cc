# FX Claude Code Marketplace

Personal marketplace for Claude Code plugins, skills, and subagents.

## Installation

Add this marketplace to Claude Code:

```
/plugin marketplace add fx/cc
```

## Available Plugins

### fx-test
A combined test plugin for marketplace validation, including both a skill and an agent.

**Install**: `/plugin install fx-test`

**Components**:
- `hello` skill - Auto-invoked greeting for testing
- `test-agent` - Simple test subagent (`@agent-fx-test:test-agent`)

## Usage

After installing plugins:
- Skills are automatically invoked by Claude when relevant
- Agents appear in `/agents` list and can be used via Task tool

## Development

### Adding New Plugins

See [CLAUDE.md](CLAUDE.md) for comprehensive plugin development guidelines, including:
- Naming conventions and namespace best practices
- When to combine vs separate plugins
- Plugin structure and quality standards
- Testing and documentation requirements

**Quick start**:
1. Create plugin directory: `plugins/<plugin-name>/`
2. Add `.claude-plugin/plugin.json` manifest
3. Add plugin files (skills, agents, etc.)
4. Update `.claude-plugin/marketplace.json`
5. Create PR

### Plugin Structure

```
plugins/
  my-plugin/
    .claude-plugin/
      plugin.json
    skill.md
    agent.md
    README.md
```

## Resources

- [Claude Code Plugin Documentation](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces)
- [Marketplace Manifest](.claude-plugin/marketplace.json)
- [GitHub Repository](https://github.com/fx/cc)

## License

MIT