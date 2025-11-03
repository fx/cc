# Coder Command

Implements GitHub issues through a complete SDLC workflow.

## Usage
```
/coder [<github-issue-url>]
```

- Accepts GitHub issue URLs or finds next logical issue automatically
- Manages entire SDLC workflow from requirements to PR creation
- Creates focused, reviewable PRs
- Continues until issue is marked Done

## Execution

Orchestrates the complete software development lifecycle by coordinating specialized agents.

## Workflow Phases

### Phase 1: Requirements & Planning
- Use requirements-analyzer subagent to fetch issue and extract requirements
- Check for 'planned' label on issue (skip planning if exists)
- Use planner subagent to create implementation plan
- Use issue-updater subagent to add plan as comment and set status

### Phase 2: Implementation  
- Use coder subagent to implement all code changes
- Use coder subagent to break large changes into logical chunks if needed
- **CRITICAL**: Only ONE PR open at a time - get user approval before starting next

### Phase 3: Pull Request
- Use pr-preparer subagent to create PR with proper description
- Use pr-reviewer subagent to review PR
- Use copilot-feedback-resolver subagent to handle Copilot comments
- Use coder subagent to fix any review issues
- Use pr-reviewer subagent to re-review after changes
- **MUST GET USER APPROVAL** for current PR before opening next one

### Phase 4: Monitoring & Completion
- Use pr-check-monitor subagent to watch and fix PR check failures
- Get user approval for sub-PRs to feature branch sequentially (one at a time)
- Only after ALL sub-PRs approved by user: create final PR to main
- Use issue-updater subagent to update status to Done after user merges

## Key Rules

- **MUST complete ALL phases** - Don't stop until issue is Done
- **PR Focus**: Keep PRs logical and reviewable
- **Feature Branches**: All work in feature branches
- **Sequential PRs**: Only ONE PR open at a time - get user approval before opening next
- **Complete Workflow**: Continues until PR is approved by user and issue is Done
- **Iterate on Feedback**: Fixes all review comments and check failures

## Agent Dependencies

Required agents:
- `requirements-analyzer` - Fetches and analyzes issues
- `planner` - Creates implementation plans
- `issue-updater` - Updates GitHub issues
- `coder` - Implements code changes
- `pr-preparer` - Prepares pull requests
- `pr-reviewer` - Reviews PRs
- `pr-check-monitor` - Monitors and fixes check failures
- `copilot-feedback-resolver` - Handles Copilot comments

## Error Handling

- **Agent failure**: Capture error, retry with adjusted params or report blocker
- **Never leave incomplete**: Always finish or clearly report blockers

## Common Mistakes to Avoid

❌ Stopping after one task completes
❌ Skipping review or monitoring phases
❌ Creating unfocused, hard-to-review PRs

✅ Complete entire workflow from requirements to Done
✅ Iterate on all feedback until resolved
✅ Break large changes into multiple PRs