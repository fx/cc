# Fix Command

Rapidly creates a new branch and PR to fix a specific error. This command streamlines the error-fixing workflow by analyzing the error, implementing a fix, and preparing a PR.

## Usage
```
/fix <error-description-or-message>
```

## Overview
The fix command coordinates agents to quickly resolve errors:

1. **Error Analysis** - Understand the error context and root cause
2. **Implementation** - Create branch, implement fix, test solution
3. **PR Creation** - Prepare and submit PR with the fix

## Workflow

### Phase 0: GitHub Authentication
```
MANDATORY: Check gh auth status
If fails: STOP and ask user to run: gh auth login
```

### Phase 1: Error Analysis & Fix

1. **Analyze Error**:
   ```
   Use coder agent to:
   - Analyze the provided error message/description
   - Identify root cause and affected files
   - Create new fix branch
   - Implement the fix with atomic commits
   - Run tests to verify fix
   ```

### Phase 2: Pull Request

2. **Prepare PR**:
   ```
   Use pr-preparer agent to:
   - Ensure fix is committed
   - Create PR with clear description
   - Reference the error being fixed
   ```

### Phase 3: Monitoring

3. **Monitor Checks**:
   ```
   Use pr-check-monitor agent to:
   - Watch PR status checks
   - Auto-fix any failures
   - Ensure all checks pass
   ```

## Orchestration

```python
def fix_command(error_description):
    # Phase 0: MANDATORY Auth Check
    if bash("gh auth status").failed:
        print("ERROR: GitHub CLI authentication required")
        print("Please run: gh auth login")
        return  # STOP
    
    # Phase 1: Fix Implementation
    Task(
        description="Fix error",
        prompt=f"Analyze and fix this error: {error_description}. Create a new branch and implement the fix.",
        subagent_type="coder"
    )
    
    # Phase 2: PR Creation
    pr_info = Task(
        description="Prepare fix PR",
        prompt="Prepare PR for the error fix",
        subagent_type="pr-preparer"
    )
    
    # Phase 3: Monitoring
    Task(
        description="Monitor fix PR",
        prompt=f"Monitor PR #{pr_info.pr_number} and fix any failing checks",
        subagent_type="pr-check-monitor"
    )
```

## Key Requirements

- **GitHub CLI Required** - Must verify `gh` auth before any work
- **Quick turnaround** - Focus on rapid error resolution
- **Clean commits** - Keep fix commits atomic and well-described
- **Verified fixes** - Ensure tests pass before creating PR

## Error Handling

**GitHub Authentication** (HIGHEST PRIORITY):
- If `gh` auth fails: STOP immediately
- Request user authentication
- Never proceed without GitHub access

For other failures:
- Capture error details
- Report blockers clearly
- Never leave work incomplete