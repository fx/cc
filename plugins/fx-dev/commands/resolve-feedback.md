# Resolve Feedback Command

Resolve all automated PR review feedback (Copilot, CodeRabbit) on a PR.

## Usage

```bash
/resolve-feedback
/resolve-feedback 107
/resolve-feedback https://github.com/owner/repo/pull/123
```

## Action

**Load the resolve-pr-feedback skill and execute its workflow.**

```
Skill tool: skill="fx-dev:resolve-pr-feedback"
```

The skill will:
1. Detect unresolved Copilot and CodeRabbit threads
2. Invoke appropriate resolver skills
3. Verify all threads resolved

**PR:** [USER INPUT] (defaults to current branch's PR if not specified)
