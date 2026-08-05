---
name: workflow-runner
description: MUST BE USED proactively to execute complete workflows from start to finish without stopping. Proactively ensures all phases complete and loops until success.
---

# Workflow Runner Skill

## Purpose
Execute multi-step workflows to completion, looping until success.

## Execution Model
```python
while not workflow_complete:
    for phase in workflow_phases:
        result = execute_phase(phase)
        if result.needs_iteration:
            iterate_until_success(phase)
    check_completion_criteria()
```

## Common Workflows

### PR Iteration Loop
```
while not pr_ready:
    if size_exceeded:
        break_into_smaller_prs()
    if has_review_comments:
        address_feedback()
    if checks_failing:
        fix_failures()
    re_review()
```

### Multi-PR Coordination
- Work on next PR while previous awaits review
- Parallel execution when tasks independent
- Track all PR statuses
- Ensure all merge before final PR

## Key Behaviors
- NEVER stop mid-workflow
- Loop until success criteria met
- Launch sub-agents with appropriate skills to fix issues
- Maintain momentum on multi-PR work
- Update status continuously
- Carry the Scope Brief verbatim into every sub-agent and every reviewer call

## Scope Boundary (the one reason to stop)

"Never stop mid-workflow" means **iterations, duration, and effort are never reasons to stop** — that is the whole point of this skill. It does not mean the workflow may grow past what the user asked for.

Hold a **Scope Brief** for the run (definition: `fx-dev/skills/dev/references/scope-contract.md`) carrying the user's verbatim request, the interpreted scope, and an explicit out-of-scope list. Pass it into every sub-agent and every reviewer invocation; a reviewer that does not know what was asked for reports the work you deliberately did not do, and filtering that noise costs a full iteration each time.

Stop and inform the user **only** when the mission itself requires something outside that scope: an unmade architectural decision, a migration or breaking change the request never implied, or a destructive action. Finish everything inside scope first, then report the blocked remainder.

Remember: Complete the mission, no matter how many iterations — but complete *the* mission, not a larger one.
