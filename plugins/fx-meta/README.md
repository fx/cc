# fx-meta

Meta tools for building Claude Code plugins, skills, and agents.

## Overview

The fx-meta plugin provides guidance and tools for creating high-quality Claude Code extensions. It focuses on helping developers build effective skills, plugins, and agents using TypeScript and modern development practices.

## Components

### Skills (1)

- **skill-creator** - Auto-invoked when creating new Claude skills

## Installation

```bash
/plugin install fx-meta
```

## Usage

### Creating a New Skill

The skill-creator skill is automatically invoked when you mention creating skills:

```
"Create a new skill for [purpose]"
"I want to build a skill that [description]"
"Help me make a skill for [domain]"
```

The skill guides you through:
1. Understanding the skill with concrete examples
2. Planning reusable skill contents (scripts, references, assets)
3. Initializing the skill directory structure
4. Editing SKILL.md with proper frontmatter and imperative language
5. Packaging the skill for distribution
6. Iterating based on testing feedback

### Key Differences from Anthropic's skill-creator

- Uses TypeScript/JavaScript instead of Python for scripts
- Manual directory initialization instead of Python init scripts
- Simplified packaging workflow for plugin-based skills
- Focused on fx/cc marketplace conventions

## Skill Structure

Skills created with this guidance follow this structure:

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description)
│   └── Markdown instructions (imperative form)
└── Optional resources:
    ├── scripts/       - TypeScript/JavaScript/Bash scripts
    ├── references/    - Documentation to load as needed
    └── assets/        - Templates, images, fonts for output
```

## Best Practices

### SKILL.md Writing Style

- Use **imperative/infinitive form** throughout
- Write "To accomplish X, do Y" not "You should do X"
- Be objective and instructional
- Keep descriptions specific about when to use the skill

### Resource Organization

- **scripts/** - For deterministic, repeatedly-written code
- **references/** - For schemas, docs, domain knowledge
- **assets/** - For templates, images, boilerplate copied to output

### Progressive Disclosure

Skills load in three levels:
1. Metadata (always loaded, ~100 words)
2. SKILL.md body (when triggered, <5k words)
3. Bundled resources (as needed by Claude)

## Examples

### Creating a Database Query Skill

```
Create a skill for querying our PostgreSQL database with knowledge of our schema
```

Result: Skill with `references/schema.md` documenting tables and relationships

### Creating a Code Template Skill

```
Build a skill for generating TypeScript API endpoints following our conventions
```

Result: Skill with `assets/api-template/` containing boilerplate TypeScript files

## Contributing

To improve fx-meta:

1. Navigate to the plugin directory
2. Edit skills or add new meta tools
3. Test with real skill creation workflows
4. Commit changes to fx/cc repository

## License

Part of the fx/cc Claude Code marketplace.
