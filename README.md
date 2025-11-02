# Claude Code Marketplace

A curated marketplace of Claude Code agents, skills, and commands.

## Installation

### Using chezmoi

```bash
chezmoi external add cc --type archive --url "https://github.com/fx/cc/archive/refs/heads/main.tar.gz" --stripComponents 1 --include "agents/**" --include "commands/**" --include "skills/**"
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/fx/cc.git

# Symlink the content you want
ln -s "$(pwd)/cc/agents" ~/.claude/agents/cc
ln -s "$(pwd)/cc/commands" ~/.claude/commands/cc
ln -s "$(pwd)/cc/skills" ~/.claude/skills/cc
```

## What's Inside

Browse available plugins at: https://fx.github.io/cc/

This marketplace contains:
- **Agents**: Specialized AI personas for specific tasks
- **Commands**: Reusable command workflows
- **Skills**: Extended capabilities and integrations

## Contributing

Contributions are welcome! Please ensure all plugins:
1. Include proper metadata (author, version, description)
2. Follow semantic versioning
3. Are tested and documented
4. Don't contain sensitive information

## Structure

```
cc/
├── agents/          # AI agent definitions
├── commands/        # Command workflows
├── skills/          # Extended capabilities
└── marketplace.json # Plugin metadata manifest
```

## License

MIT License - See LICENSE file for details