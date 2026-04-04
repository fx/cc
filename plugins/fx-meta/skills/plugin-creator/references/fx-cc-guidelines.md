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
- `test-utils` (missing namespace prefix)
- `fx_test_utilities` (underscores, too verbose)
- `fxTest` (camelCase not kebab-case)

### Component Naming Within Plugins

Skills are automatically namespaced by their plugin: `{plugin-name}:{skill-name}`.

**Avoid redundancy**:
- ❌ Plugin: `test-skill` → Skill: `test-skill:test-skill`
- ✅ Plugin: `fx-test` → Skill: `fx-test:test-helper`

Skill names should be clear, non-redundant, and descriptive of their purpose.

## Grouping Components in Plugins

### Single-Responsibility vs Multi-Component

**Use a single plugin when components are related**:

✅ **Good - Combined Plugin**:
```
fx-test/
├── skills/hello/SKILL.md
└── skills/test-helper/SKILL.md
```
Result: `fx-test:hello`, `fx-test:test-helper` — all scoped under one plugin

❌ **Poor - Separate Plugins**:
```
test-skill/
└── skills/hello/SKILL.md

test-helper/
└── skills/test-helper/SKILL.md
```
Result: Fragmented across multiple plugins for related functionality

### When to Combine

Combine components in one plugin when they:
- Share a common purpose or domain
- Are typically used together
- Form a logical feature set

**Examples**:

**`fx-git` plugin** might include:
- Skills: `commit-message`, `pr-review`, `merge-conflict-resolver`
- Commands: `/git-flow`, `/git-status`

**`fx-docs` plugin** might include:
- Skills: `api-documentation`, `readme-generator`, `doc-writer`
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
├── skills/                   # Optional: Skills
│   ├── skill-1/
│   │   └── SKILL.md
│   └── skill-2/
│       └── SKILL.md
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

## Best Practices

### DRY (Don't Repeat Yourself)

- Group related components in one plugin
- Avoid creating near-duplicate plugins
- Reuse skills across plugins when appropriate

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
