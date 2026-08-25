---
name: fix
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Runs a test-first bug-fix lifecycle and then enters the explicitly requested SDLC workflow."
---

# Fix (Test-First Bug Resolution)

Entry point for bug fixes that **mandates test-first verification**. Before ANY fix is implemented, the bug MUST be reproduced via automated test.

## Critical Rule: Test-First Verification

**NEVER proceed with a fix without first writing a failing test that reproduces the bug.**

This is NON-NEGOTIABLE. The workflow is:

1. **Understand** the bug report/error
2. **Write a failing test** that reproduces the issue (most concise test possible)
3. **Verify** the test fails for the right reason
4. **Then and only then** implement the fix
5. **Verify** the test passes

If you cannot reproduce the bug via automated test:
- Ask the user for more information
- Investigate further to understand the root cause
- DO NOT guess at fixes

## Why Test-First?

- **Confirms understanding**: If you can't write a test, you don't understand the bug
- **Prevents false fixes**: A test proves the fix actually works
- **Prevents regressions**: The test lives on to catch future breaks
- **Most efficient**: Avoids back-and-forth of "try this, did it work?"

## Action

**MANDATORY: Load the SDLC skill, then follow the Fix Workflow variation.**

```
Skill tool: skill="fx-dev:dev"
```

After the skill loads, execute with this modified Step 2 (Requirements Analysis):

### Modified Step 2: Bug Reproduction via Test

Before ANY implementation:

1. **Analyze the bug report** to understand expected vs actual behavior
2. **Write the most concise failing test** that reproduces the bug:
   ```
   Agent tool:
     prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

              Write a FAILING test that reproduces this bug:

              [BUG DESCRIPTION]

              Requirements:
              - Test must be as concise as possible
              - Test must fail with the reported error/behavior
              - Test must pass after the bug is fixed
              - NO implementation yet - only the test
              - Commit the failing test

              Output: Test file path and failure output"
     description: "Write failing bug test"
   ```
3. **Verify the test fails** for the expected reason
4. **Only then** proceed to Step 3 (Planning) and Step 4 (Implementation)

### Modified Step 4: Fix Implementation

When implementing the fix:

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

           Fix this bug. The failing test is at [TEST PATH].

           [PLAN FROM STEP 3]

           [PASTE THE SCOPE BRIEF VERBATIM HERE]

           Requirements:
           - Implement the minimal fix
           - The failing test must now pass
           - All other tests must still pass
           - Commit the fix

           Output: Files changed and test results"
  description: "Implement bug fix"
```

**"Minimal fix" is the scope contract of this skill.** A bug report authorizes fixing that bug, not refactoring the code around it. Carry the Scope Brief (`fx-dev/skills/dev/references/scope-contract.md`) into implementation and into every reviewer call, and if the bug turns out to require a redesign, a migration, or changes to subsystems the report never mentioned, **stop and tell the user** with the cheapest option first — do not deliver a refactor in response to "fix this bug real quick".

The SDLC skill provides the remaining mandatory steps (PR creation, review, CI). Follow them exactly.
