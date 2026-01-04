---
name: learn
description: Update fx-cc plugin agents, skills, or commands based on conversation learnings. Use when the user says "use /learn to...", "learn to...", "remember to...", "don't do X again", or when an agent/skill misbehaved and needs correction. This skill modifies plugin source files but does NOT commit changes - they require manual review before committing.
---

# Learn

This skill updates fx-cc marketplace plugins based on learnings from the current conversation. It modifies agent, skill, or command definitions to prevent future mistakes or improve behavior.

## Prerequisites

Before making any changes, verify the fx-cc marketplace is accessible:

```bash
cd ~/.claude/plugins/marketplaces/fx-cc && git remote -v && git status
```

The remote must be `git@github.com:fx/cc.git`. If not accessible, inform the user and abort.

## Workflow

### Step 1: Analyze the Learning Request

Examine the current conversation to understand:

1. **What went wrong** - Identify the specific behavior that needs correction
2. **Root cause** - Determine which agent, skill, or command caused the issue
3. **Desired behavior** - Understand what should happen instead

Common scenarios:

- **Skill not loaded when it should have been** → Update skill description to be clearer about trigger conditions
- **Agent did something it shouldn't** → Add explicit prohibition to agent instructions
- **Agent missed a step** → Add the step to the agent's workflow
- **Instruction was ambiguous** → Clarify the wording

### Step 2: Locate Relevant Files

Search the fx-cc marketplace for relevant files:

```bash
# Find all plugin definitions
find ~/.claude/plugins/marketplaces/fx-cc/plugins -name "*.md" -type f

# Search for specific content
grep -r "keyword" ~/.claude/plugins/marketplaces/fx-cc/plugins/
```

Key locations:
- **Agents**: `plugins/<plugin>/agents/<agent>.md`
- **Skills**: `plugins/<plugin>/skills/<skill>/SKILL.md`
- **Commands**: `plugins/<plugin>/commands/<command>.md`

### Step 3: Make Targeted Modifications

Edit the relevant files to address the learning. Follow these principles:

1. **Be specific** - Add concrete instructions, not vague guidance
2. **Use imperative form** - Write "Do X" or "Never do Y", not "You should..."
3. **Add context** - Explain why the rule exists if non-obvious
4. **Preserve structure** - Maintain existing formatting and organization

For prohibitions, use clear language:
```markdown
**CRITICAL:** Never do X because Y.
```

For required actions:
```markdown
**IMPORTANT:** Always do X before Y.
```

### Step 4: Sync to Plugin Cache

**CRITICAL:** Claude Code caches plugins separately from the marketplace source. After modifying files in the marketplace, sync changes to the cache so they take effect immediately.

Cache mapping:
- **Source**: `~/.claude/plugins/marketplaces/fx-cc/plugins/<plugin>/`
- **Cache**: `~/.claude/plugins/cache/fx-cc/<plugin>/<version>/`

To sync a modified plugin:

```bash
# Get the plugin version from its manifest
PLUGIN=fx-dev  # or fx-meta, fx-research, etc.
VERSION=$(cat ~/.claude/plugins/marketplaces/fx-cc/plugins/$PLUGIN/.claude-plugin/plugin.json | grep '"version"' | sed 's/.*: *"\([^"]*\)".*/\1/')

# Sync marketplace source to cache
rsync -av --delete \
  ~/.claude/plugins/marketplaces/fx-cc/plugins/$PLUGIN/ \
  ~/.claude/plugins/cache/fx-cc/$PLUGIN/$VERSION/
```

Sync every plugin that was modified. This ensures Claude loads the updated definitions immediately without requiring a restart.

### Step 5: Verify Changes

After editing and syncing, show the diff to the user:

```bash
cd ~/.claude/plugins/marketplaces/fx-cc && git diff
```

### Step 6: Leave for Manual Review

**CRITICAL:** Do NOT commit the changes. Inform the user:

> Changes have been made to the following files:
> - `path/to/file1.md`
> - `path/to/file2.md`
>
> Review the changes with `git diff` in `~/.claude/plugins/marketplaces/fx-cc`.
> Commit manually when satisfied.

## Examples

### Example 1: Agent Skipped a Step

User says: "use /learn to update our sdlc agents - they should update PROJECT.md when creating PRs"

1. Locate `plugins/fx-dev/agents/pr-preparer.md`
2. Add instruction to check PROJECT.md and update completed tasks
3. Sync fx-dev plugin to cache
4. Show diff, leave uncommitted

### Example 2: Skill Not Triggered

User says: "the github skill didn't load when I ran gh commands"

1. Locate `plugins/fx-dev/skills/github/SKILL.md`
2. Update description to include more trigger phrases (e.g., "gh CLI", "GitHub API")
3. Sync fx-dev plugin to cache
4. Show diff, leave uncommitted

### Example 3: Explicit Prohibition

User says: "/learn to never leave comments on PRs"

1. Locate relevant agents (pr-preparer, pr-reviewer, etc.)
2. Add explicit prohibition with rationale
3. Sync all modified plugins to cache
4. Show diff, leave uncommitted
