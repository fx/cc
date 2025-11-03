# Coder Command

Implements coding tasks using specialized agents for planning, implementation, and review.

## Usage
```
/coder <task-description>
```

- Accepts any coding task description
- Coordinates agents for planning and implementation
- Ensures code quality through review
- No GitHub issue required

## Execution

Orchestrates coding tasks by coordinating specialized agents.

## Workflow Phases

### Phase 1: Planning
- Use Plan subagent (or planner if Plan unavailable) to break down task into implementation steps
- Validate approach and dependencies

### Phase 2: Implementation
- Use coder subagent to implement code changes
- Break large changes into logical commits
- **CRITICAL**: When using feature branches, get user approval for each PR before starting next
- Ensure code follows project conventions

### Phase 3: Review & Testing
- Use pr-reviewer subagent to review code quality
- Use coder subagent to fix any issues found
- Run tests and ensure all pass

### Phase 4: Finalization
- Create clean commits with proper messages
- Prepare code for integration
- Document changes if needed

## Key Rules

- **Use agents exclusively** - Never implement directly
- **Sequential PRs** - Only ONE PR open at a time when breaking features
- **Follow conventions** - Match existing code style
- **Test thoroughly** - Ensure changes don't break existing code
- **Clean commits** - Atomic, well-described changes

## Agent Dependencies

Required agents:
- `Plan` (preferred) or `planner` (fallback) - Creates implementation plans
- `coder` - Implements code changes
- `pr-reviewer` - Reviews code quality
- `general-purpose` - Research and analysis

## Task Examples

```
/coder Add dark mode toggle to settings page
/coder Refactor auth module to use async/await
/coder Fix memory leak in data processing pipeline
/coder Implement caching layer for API responses
```

## Error Handling

- **Agent failure**: Retry with adjusted parameters
- **Ambiguous requirements**: Use agents to research codebase
- **Complex tasks**: Break into smaller subtasks

## Common Patterns

### Feature Implementation
- Use Plan subagent (or planner if unavailable) to break down feature
- Use coder subagent to implement incrementally
- Create PR, get user approval for feature branch before next PR
- Use pr-reviewer subagent to review and refine
- Test thoroughly

### Bug Fixes
- Use general-purpose subagent to research root cause
- Write failing test first
- Use coder subagent to implement fix
- Verify test passes

### Refactoring
- Use general-purpose subagent to understand current implementation
- Use Plan subagent (or planner if unavailable) to plan refactor approach
- Use coder subagent to implement changes incrementally
- Ensure tests still pass