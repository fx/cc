# Manual Testing Guide

This guide explains how to manually test the fx/cc marketplace and plugins.

## Prerequisites

- Claude Code CLI installed and configured
- Repository deployed to GitHub Pages (https://cc.fx.gd)

## Testing Marketplace Structure (Local)

Before pushing changes, validate the structure locally:

```bash
# Validate marketplace.json
jq empty .claude-plugin/marketplace.json

# Check required fields
jq '.name, .owner, .plugins' .claude-plugin/marketplace.json

# Validate all plugin manifests
for plugin in plugins/*/.claude-plugin/plugin.json; do
  echo "Validating $plugin..."
  jq empty "$plugin"
done
```

## Testing Marketplace Installation

### 1. Add the Marketplace

In Claude Code:

```
/plugin marketplace add fx/cc
```

Expected output: Confirmation that marketplace was added successfully.

### 2. List Available Plugins

```
/plugin marketplace list
```

Expected output: Should show the fx/cc marketplace with available plugin (fx-test).

### 3. View Marketplace Details

```
/plugin marketplace info fx/cc
```

Expected output: Marketplace metadata and list of plugins.

## Testing Plugin Installation

### Install fx-test

```
/plugin install fx-test
```

Expected output: Confirmation that fx-test was installed.

### Verify Installation

```
/plugin list
```

Expected output: Should show fx-test in the list of installed plugins.

## Testing Plugin Functionality

### Test the Skill

Skills are automatically invoked by Claude when relevant. There's no `/skill` command. Instead, ask naturally:

```
Test the hello skill from the marketplace
```

Or:

```
Can you confirm the fx/cc marketplace is working?
```

**Expected behavior**: Claude should recognize the context and respond with: "Hello from the fx/cc marketplace! This skill is working correctly. ✓"

### Test the Agent

Check if the agent appears in your available agents:

```
/agents
```

**Expected behavior**: You should see `@agent-fx-test:test-agent` listed with description "A simple test agent for validation".

To invoke it, ask Claude to use it for a task. The agent will be available for Claude to select when appropriate, or you can ask directly:

```
Please use the test-agent subagent
```

## Testing After Updates

When you update plugins in the repository:

### 1. Update the Marketplace

```
/plugin marketplace update fx/cc
```

This fetches the latest marketplace.json from cc.fx.gd.

### 2. Check for Plugin Updates

```
/plugin outdated
```

Shows which installed plugins have updates available.

### 3. Update Plugins

```
/plugin update fx-test
```

Or update all:

```
/plugin update --all
```

## Testing Local Development

To test changes before pushing to the repository:

### 1. Add Local Marketplace

```
/plugin marketplace add /path/to/fx-cc
```

This adds the marketplace from your local repository directory.

### 2. Install from Local

```
/plugin install fx-test
```

Installs the plugin from your local development copy.

### 3. Test Changes

Make changes to your plugin files, then:

```
/plugin update fx-test
```

This should pick up your local changes.

## Troubleshooting

### Marketplace Not Found

If `/plugin marketplace add fx/cc` fails:

1. **Check GitHub Pages is deployed**:
   - Visit https://cc.fx.gd in a browser
   - Verify https://cc.fx.gd/.claude-plugin/marketplace.json exists
   - Check that JSON is valid and properly formatted

2. **Check DNS**:
   ```bash
   dig cc.fx.gd
   ```
   Should resolve to GitHub Pages (fx.github.io)

3. **Try direct URL**:
   ```
   /plugin marketplace add https://cc.fx.gd
   ```

### Plugin Installation Fails

1. **Check plugin.json is valid**:
   ```bash
   jq empty plugins/test-skill/.claude-plugin/plugin.json
   ```

2. **Verify referenced files exist**:
   - Check that skill/agent files listed in plugin.json are present
   - Ensure file paths are relative to plugin directory

3. **Check marketplace references plugin correctly**:
   ```bash
   jq '.plugins[] | select(.name=="fx-test")' .claude-plugin/marketplace.json
   ```

### Plugin Doesn't Work

1. **Verify frontmatter in markdown files**:
   - Skill/agent files should start with `---`
   - Required fields: `name`, `description`
   - End frontmatter with `---`

2. **Check plugin is enabled**:
   ```
   /plugin list
   ```
   Disabled plugins show as `(disabled)`.

3. **Try reinstalling**:
   ```
   /plugin uninstall fx-test
   /plugin install fx-test
   ```

## Reporting Issues

If you find issues during testing:

1. Check CI validation passes: https://github.com/fx/cc/actions
2. Verify marketplace JSON at https://cc.fx.gd/.claude-plugin/marketplace.json
3. Open an issue with:
   - Steps to reproduce
   - Expected vs actual behavior
   - Claude Code version (`claude --version`)
   - Relevant error messages

## Related Documentation

- [Claude Code Plugin Marketplaces](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces)
- [Plugin Development Guide](https://docs.claude.com/en/docs/claude-code/plugins)
- [Issue #7100](https://github.com/anthropics/claude-code/issues/7100) - CI/CD authentication support request
