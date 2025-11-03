# fx/cc Marketplace Development Guidelines

This document outlines principles and conventions for developing plugins in the fx/cc Claude Code marketplace.

## Plugin Naming and Namespacing

### Plugin Names

Plugin names should be:
- **Concise**: Short, memorable identifiers
- **Descriptive**: Indicate purpose without being verbose
- **Namespace-prefixed**: Use `fx-` prefix for consistency (e.g., `fx-test`, `fx-utils`)
- **Kebab-case**: Use hyphens, not underscores or camelCase

**Good examples**:
- `fx-test` (testing utilities)
- `fx-git` (git workflow helpers)
- `fx-docs` (documentation generators)

**Avoid**:
- `test-agent` (missing namespace prefix)
- `fx_test_utilities` (underscores, too verbose)
- `fxTest` (camelCase not kebab-case)

### Component Naming Within Plugins

Agent references follow the pattern: `@agent-{plugin-name}:{agent-name}`

**Avoid redundancy**:
- ❌ Plugin: `test-agent` → Agent: `@agent-test-agent:test-agent`
- ✅ Plugin: `fx-test` → Agent: `@agent-fx-test:test-agent`

Skills are automatically namespaced by their plugin but should still have clear, non-redundant names.

## Grouping Components in Plugins

### Single-Responsibility vs Multi-Component

**Use a single plugin when components are related**:

✅ **Good - Combined Plugin**:
```
fx-test/
├── skills/hello/SKILL.md
└── agents/test-agent.md
```
Result: `@agent-fx-test:test-agent`, skill auto-scoped

❌ **Poor - Separate Plugins**:
```
test-skill/
└── skills/hello/SKILL.md

test-agent/
└── agents/test-agent.md
```
Result: `@agent-test-agent:test-agent` (redundant)

### When to Combine

Combine components in one plugin when they:
- Share a common purpose or domain
- Are typically used together
- Form a logical feature set

**Examples**:

**`fx-git` plugin** might include:
- Skills: `commit-message`, `pr-review`
- Agents: `git-helper`, `merge-conflict-resolver`
- Commands: `/git-flow`, `/git-status`

**`fx-docs` plugin** might include:
- Skills: `api-documentation`, `readme-generator`
- Agents: `doc-writer`
- Commands: `/generate-docs`

### When to Separate

Create separate plugins when components:
- Serve completely different domains
- Have different update/maintenance cycles
- Should be installable independently

**Example**: `fx-git` and `fx-aws` should be separate plugins, not combined.

## Plugin Structure

### Standard Layout

```
fx-plugin-name/
├── .claude-plugin/
│   └── plugin.json          # Required manifest
├── skills/                   # Optional: Agent Skills
│   ├── skill-1/
│   │   └── SKILL.md
│   └── skill-2/
│       └── SKILL.md
├── agents/                   # Optional: Subagents
│   ├── agent-1.md
│   └── agent-2.md
├── commands/                 # Optional: Slash commands
│   ├── command-1.md
│   └── command-2.sh
├── hooks/                    # Optional: Workflow hooks
│   └── hooks.json
├── README.md                 # Required: Documentation
└── CHANGELOG.md             # Recommended: Version history
```

### plugin.json Minimal Format

```json
{
  "name": "fx-plugin-name",
  "version": "1.0.0",
  "description": "Clear, concise description of what this plugin does"
}
```

Only `name` is required. Version and description are highly recommended.

## Development Workflow

### 1. Planning

Before creating a plugin:
1. **Identify the domain**: What problem does it solve?
2. **List components**: What skills, agents, commands are needed?
3. **Check for grouping**: Should these be combined or separate?
4. **Choose name**: Follow naming conventions

### 2. Implementation

1. Create plugin directory structure
2. Add `.claude-plugin/plugin.json`
3. Implement components (skills, agents, etc.)
4. Write comprehensive README.md
5. Test locally using `/plugin marketplace add /path/to/fx-cc`

### 3. Testing

Test each component:
- **Skills**: Ask questions that should trigger them
- **Agents**: Check `/agents` list, invoke via Task tool
- **Commands**: Run slash commands if implemented
- **Structure**: Validate JSON with `jq empty plugin.json`

### 4. Documentation

Every plugin must have:
- **README.md**: Purpose, installation, usage examples
- **plugin.json**: Minimal required metadata
- **Component docs**: Frontmatter in skills/agents

Good documentation includes:
- Clear usage examples
- Expected behavior
- Troubleshooting tips
- Structure diagram

### 5. Marketplace Registration

Update `.claude-plugin/marketplace.json`:

```json
{
  "plugins": [
    {
      "name": "fx-new-plugin",
      "source": "./plugins/fx-new-plugin"
    }
  ]
}
```

## Quality Standards

### Code Quality

- **Validate JSON**: All `.json` files must be valid
- **Frontmatter required**: All skills and agents need proper frontmatter
- **No dead references**: All paths in plugin.json must exist
- **Clear descriptions**: Help Claude and users understand purpose

### Documentation Quality

- **README.md required**: Every plugin needs documentation
- **Usage examples**: Show how to use each component
- **Expected behavior**: Document what users should see
- **Troubleshooting**: Common issues and solutions

### Testing

CI automatically validates:
- JSON structure and validity
- Required fields in manifests
- File existence for referenced components
- Frontmatter presence in markdown files

Manual testing required for:
- Actual plugin functionality
- User experience
- Component interaction

## Best Practices

### DRY (Don't Repeat Yourself)

- Group related components in one plugin
- Avoid creating near-duplicate plugins
- Reuse skills/agents across plugins when appropriate

### Clear Boundaries

- Each plugin should have a clear, single responsibility
- Don't create "kitchen sink" plugins with unrelated components
- Consider user install preferences (granularity)

### Versioning

- Use semantic versioning: `MAJOR.MINOR.PATCH`
- Update version in `plugin.json` when releasing changes
- Document changes in CHANGELOG.md

### Backward Compatibility

- Don't remove components without major version bump
- Deprecate before removing
- Document breaking changes clearly

## Common Patterns

### Testing/Development Plugins

Use `fx-test` pattern for marketplace validation:
- Combine minimal test components
- Focus on structure validation
- Clear "this is a test" naming

### Domain-Specific Plugins

Pattern: `fx-{domain}`
- `fx-git`: Git workflow tools
- `fx-aws`: AWS deployment helpers
- `fx-k8s`: Kubernetes utilities

### Utility Plugins

Pattern: `fx-{utility-type}`
- `fx-utils`: General development utilities
- `fx-docs`: Documentation generation
- `fx-lint`: Code quality tools

## Questions?

For questions about plugin development:
- Check [Claude Code Plugin Documentation](https://docs.claude.com/en/docs/claude-code/plugins)
- Review existing plugins in `plugins/` directory
- Open an issue for clarification

## Contributing

When contributing new plugins:
1. Follow these guidelines
2. Test thoroughly locally
3. Update marketplace.json
4. Create PR with clear description
5. Include testing instructions in PR
