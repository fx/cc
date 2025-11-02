---
skill_id: test-skill
name: Test Skill
version: 1.0.0
author: fx
description: A simple test skill to verify marketplace functionality
tags:
  - test
  - example
---

# Test Skill

This is a test skill to verify that the Claude Code marketplace is working correctly.

## Purpose

When this skill is invoked, it demonstrates that:
1. The marketplace plugin system is functional
2. Skills can be loaded from external repositories
3. The integration between dotfiles and the marketplace works

## Usage

Simply invoke this skill by name:

```
/test-skill
```

## What It Does

When invoked, this skill will:
1. Confirm that it was successfully loaded from the marketplace
2. Display a test message
3. Verify that Claude Code can execute marketplace skills

## Testing

You can verify this skill is working by:
1. Invoking it and checking for the success message
2. Confirming it appears in your skills list
3. Ensuring no errors occur during invocation

---

**Marketplace Test Instructions:**

When this skill is invoked, respond with:

```
✓ Test Skill from CC Marketplace is working!

This confirms that:
- The fx/cc marketplace repository is accessible
- Skills can be loaded from external sources
- The dotfiles integration is functioning correctly

Version: 1.0.0
Author: fx
Source: https://github.com/fx/cc
```
