# fx-test Plugin

A combined test plugin for validating the fx/cc marketplace functionality. Includes both a skill and an agent.

## Components

### hello Skill
A simple skill that confirms marketplace installation.

**Usage**: Ask naturally:
```
Test the hello skill from the marketplace
```

**Expected response**: "Hello from the fx/cc marketplace! This skill is working correctly. ✓"

### test-agent Subagent
A simple subagent for validation.

**Check availability**:
```
/agents
```

You should see `@agent-fx-test:test-agent` in the list.

**Usage**: Claude can invoke it when appropriate, or ask directly:
```
Please use the test-agent subagent
```

## Why Combined?

This plugin demonstrates the recommended pattern of grouping related components:
- Plugin name: `fx-test` (short, clear namespace)
- Agent reference: `@agent-fx-test:test-agent` (avoids redundancy)
- Skill reference: Automatically scoped by plugin

Rather than creating separate `test-skill` and `test-agent` plugins (which would create `@agent-test-agent:test-agent`), we combine related test components under one logical plugin.

## Structure

```
fx-test/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── hello/
│       └── SKILL.md
├── agents/
│   └── test-agent.md
└── README.md
```

## Installation

```
/plugin install fx-test
```
