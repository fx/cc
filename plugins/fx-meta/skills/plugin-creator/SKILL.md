---
name: plugin-creator
description: Guide for creating effective fx/cc marketplace plugins. This skill should be used when users want to create a new Claude Code plugin (or update an existing plugin) for the fx/cc marketplace that extends Claude's capabilities with specialized agents, skills, commands, or hooks.
---

# Plugin Creator

This skill provides guidance for creating high-quality plugins for the fx/cc Claude Code marketplace.

## About fx/cc Plugins

Plugins are structured packages that extend Claude Code's capabilities by bundling related components:
- **Skills** - Auto-invoked specialized knowledge and workflows
- **Agents** - Autonomous task handlers for complex multi-step operations
- **Commands** - Slash commands for specific operations
- **Hooks** - Event-driven workflow automation

## Default Working Directory

**All plugin development work defaults to:** `~/.claude/plugins/marketplaces/fx-cc/`

This is the local clone of the fx/cc marketplace repository where all plugins reside.

## Plugin Creation Process

### Step 1: Understanding the Plugin with Concrete Examples

To create an effective plugin, gather concrete examples of how it will be used:

**Example questions to ask:**
- "What functionality should this plugin provide?"
- "Can you give examples of tasks users would perform with this plugin?"
- "What would trigger each component (skills, agents, commands)?"
- "Are these components typically used together or separately?"

**Example for `fx-git` plugin:**
- User: "Help me write better commit messages following our conventions"
- User: "Review this PR for code quality issues"
- User: "Resolve these merge conflicts"

Conclude when there's a clear understanding of:
1. Plugin's domain and purpose
2. Required components (skills, agents, commands)
3. Typical usage patterns

### Step 2: Planning Plugin Structure

Analyze examples to determine:

#### 1. Plugin Name
Follow fx/cc naming conventions (see `references/fx-cc-guidelines.md`):
- Use `fx-` prefix
- Kebab-case format
- Concise and descriptive
- Examples: `fx-git`, `fx-aws`, `fx-docs`

#### 2. Component Grouping
Decide whether to:
- **Combine** related components in one plugin (typically used together)
- **Separate** into multiple plugins (different domains or install preferences)

#### 3. Required Components

**Skills** - When to include:
- Auto-invoked specialized knowledge needed
- Procedural workflows for specific tasks
- Domain expertise that should trigger automatically

**Agents** - When to include:
- Complex multi-step autonomous operations
- Tasks requiring coordination of multiple tools
- Long-running workflows with decision-making

**Commands** - When to include:
- Explicit user-triggered operations
- Shortcuts for common workflows
- Integration with external tools/APIs

**Hooks** - When to include:
- Event-driven automation needs
- Pre/post-processing requirements
- Workflow customization

### Step 3: Initialize Plugin Structure

Navigate to the fx/cc marketplace and create plugin directory:

```bash
cd ~/.claude/plugins/marketplaces/fx-cc/plugins

# Create plugin directory structure
mkdir -p fx-plugin-name/.claude-plugin

# Create plugin.json manifest
cat > fx-plugin-name/.claude-plugin/plugin.json <<'EOF'
{
  "name": "fx-plugin-name",
  "version": "0.1.0",
  "description": "Clear description of what this plugin does"
}
EOF

# Create component directories as needed
cd fx-plugin-name
mkdir -p skills agents commands hooks
```

**Directory structure:**
```
~/.claude/plugins/marketplaces/fx-cc/plugins/fx-plugin-name/
├── .claude-plugin/
│   └── plugin.json
├── skills/          (if needed)
├── agents/          (if needed)
├── commands/        (if needed)
├── hooks/           (if needed)
└── README.md
```

### Step 4: Implement Components

#### Skills
Create skill directories with SKILL.md:

```bash
mkdir -p skills/skill-name
cat > skills/skill-name/SKILL.md <<'EOF'
---
name: skill-name
description: When this skill should be used (third-person, specific)
---

# Skill Name

Instructions using imperative/infinitive form.

## Usage

How to use this skill and reference bundled resources.
EOF
```

See skill-creator skill for detailed skill development guidance.

#### Agents
Create agent markdown files:

```bash
cat > agents/agent-name.md <<'EOF'
---
name: agent-name
description: What this agent does and when to use it
model: sonnet  # Optional: sonnet (default), opus, haiku
---

Agent instructions and behavior.

Usage examples showing when to invoke this agent.
EOF
```

Agent reference pattern: `@agent-fx-plugin-name:agent-name`

#### Commands
Create command files (markdown or shell):

```bash
# Markdown command
cat > commands/command-name.md <<'EOF'
---
name: command-name
description: What this command does
---

Command implementation and documentation.
EOF

# Or shell script
cat > commands/command-name.sh <<'EOF'
#!/bin/bash
# Command implementation
EOF
chmod +x commands/command-name.sh
```

#### Hooks
Create hooks configuration:

```bash
cat > hooks/hooks.json <<'EOF'
{
  "PreToolUse": {
    "command": "bash -c 'echo \"Pre-tool hook\"'",
    "timeout": 5000
  }
}
EOF
```

### Step 5: Documentation

Create comprehensive README.md:

```markdown
# Plugin Name

Brief description of plugin purpose.

## Installation

\`/plugin install fx-plugin-name\`

## Components

### Skills (if applicable)
- **skill-name** - Auto-invoked when [trigger condition]

### Agents (if applicable)
- **agent-name** - Use via \`@agent-fx-plugin-name:agent-name\` for [purpose]

### Commands (if applicable)
- \`/command-name\` - [What it does]

## Usage Examples

[Concrete examples of using each component]

## Configuration

[Any settings or environment variables]

## Contributing

[Development and testing instructions]
```

### Step 6: Register Plugin in Marketplace

Update `~/.claude/plugins/marketplaces/fx-cc/.claude-plugin/marketplace.json`:

```bash
cd ~/.claude/plugins/marketplaces/fx-cc

# Edit marketplace.json to add new plugin entry
# Add to "plugins" array:
{
  "name": "fx-plugin-name",
  "source": "./plugins/fx-plugin-name"
}
```

Example using jq:
```bash
jq '.plugins += [{"name": "fx-plugin-name", "source": "./plugins/fx-plugin-name"}]' \
  .claude-plugin/marketplace.json > /tmp/marketplace.json && \
  mv /tmp/marketplace.json .claude-plugin/marketplace.json
```

### Step 7: Validate and Test

**Validate structure:**
```bash
cd ~/.claude/plugins/marketplaces/fx-cc/plugins/fx-plugin-name

# Validate JSON
jq empty .claude-plugin/plugin.json

# Check frontmatter in components
grep -r "^---$" skills/ agents/ commands/ || echo "No frontmatter found"
```

**Test functionality:**
1. Reload Claude Code to pick up changes
2. **Skills**: Ask questions that should trigger auto-invocation
3. **Agents**: Check `/agents` list and invoke via Task tool
4. **Commands**: Execute slash commands
5. **Integration**: Verify components work together

**Git workflow:**
```bash
cd ~/.claude/plugins/marketplaces/fx-cc

# Create feature branch
git checkout -b feat/fx-plugin-name

# Stage changes
git add plugins/fx-plugin-name .claude-plugin/marketplace.json

# Commit with semantic message
git commit -m "feat(fx-plugin-name): add plugin for [purpose]"

# Push for review
git push -u origin feat/fx-plugin-name
```

### Step 8: Iterate

After testing:
1. Gather feedback on usability and effectiveness
2. Identify improvements to components
3. Update documentation with discovered use cases
4. Refine component interactions
5. Add examples from real usage

## Quality Standards

### Code Quality
- Valid JSON in all .json files
- Required frontmatter in all markdown components
- Clear, specific descriptions
- No dead file references

### Documentation Quality
- README.md with installation and usage examples
- Expected behavior for each component
- Troubleshooting common issues
- Component interaction documentation

### Testing Requirements
- Manual test all components
- Verify auto-invocation triggers for skills
- Test agent invocation patterns
- Confirm command execution
- Validate JSON with jq

## Component Guidelines

### Skills
- Use third-person descriptions ("This skill should be used when...")
- Write using imperative/infinitive form
- Keep SKILL.md under 5k words
- Use progressive disclosure (references/ for details)

### Agents
- Provide clear invocation patterns
- Document available tools and capabilities
- Include usage examples in frontmatter
- Specify model if not default sonnet

### Commands
- Clear, action-oriented naming
- Descriptive command descriptions
- Document expected arguments
- Provide usage examples

### Hooks
- Document hook events and purposes
- Set appropriate timeouts
- Handle errors gracefully
- Avoid blocking operations

## Common Patterns

### Domain-Specific Plugins
Pattern: `fx-{domain}`
- Single domain focus (git, aws, docker)
- Related components bundled together
- Clear scope and boundaries

### Utility Plugins
Pattern: `fx-{utility-type}`
- General-purpose tools
- Cross-domain applicability
- Modular, reusable components

### Meta Plugins
Pattern: `fx-{meta-purpose}`
- Tools for building other tools
- Development workflow helpers
- Marketplace management

## Troubleshooting

### Plugin Not Appearing
- Verify marketplace.json syntax and entry
- Check plugin.json exists and is valid
- Reload Claude Code
- Verify plugin name matches exactly

### Components Not Loading
- Check frontmatter exists and is valid
- Verify file naming and locations
- Ensure proper directory structure
- Reload after changes

### Auto-Invocation Not Working
- Review skill description specificity
- Test with explicit trigger phrases
- Check for frontmatter typos
- Verify skill path in plugin

## Working Directory

**Critical**: All operations default to `~/.claude/plugins/marketplaces/fx-cc/`

When creating, editing, or managing plugins, always work from this directory unless explicitly specified otherwise.
