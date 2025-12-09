# Dev Command

Unified entry point for all development tasks. Loads the SDLC skill and executes the workflow.

## Usage

```bash
/dev https://github.com/owner/repo/issues/123
/dev Add dark mode toggle
/dev fix: TypeError in auth.js
```

## Action

**MANDATORY: Load the SDLC skill first, then follow its workflow.**

```
Skill tool: skill="fx-dev:sdlc"
```

After the skill loads, execute the SDLC workflow steps in order for the user's task:

**Task:** [USER INPUT]

The SDLC skill provides mandatory step-by-step instructions. Follow them exactly.
