# fx-git

Git workflow utilities including repository analysis and rapid fix workflows.

## Overview

The fx-git plugin provides specialized commands for git-related workflows, including analyzing public GitHub repositories and rapidly creating fix PRs.

## Components

### Commands

- **/fix** - Rapidly creates a branch and PR to fix a specific error
- **/gitingest** - Analyzes public GitHub repositories to understand structure and contents

## Usage

### Quick Error Fix Workflow

```bash
/fix TypeError in user authentication: Cannot read property 'id' of undefined
```

This command will:
1. Analyze the error
2. Create a fix branch
3. Implement the fix
4. Create a PR
5. Monitor checks

### Analyze a GitHub Repository

```bash
/gitingest https://github.com/user/repo
```

This command will:
1. Fetch repository structure
2. Generate file tree
3. Create content digest
4. Provide repository summary

## Command Descriptions

### /fix

Rapidly creates a new branch and PR to fix a specific error. Streamlines the error-fixing workflow by analyzing errors, implementing fixes, and preparing PRs.

**Workflow:**

```
Error Analysis
    ↓
Branch Creation
    ↓
Fix Implementation
    ↓
Test Verification
    ↓
PR Creation
    ↓
Check Monitoring
```

**Requirements:**
- GitHub CLI authentication (`gh auth status`)
- Clean working directory recommended
- Project with test suite recommended

**Agent Coordination:**
- Uses `coder` agent (fx-sdlc) for implementation
- Uses `pr-preparer` agent (fx-pr) for PR creation
- Uses `pr-check-monitor` agent (fx-pr) for monitoring

### /gitingest

Analyzes public GitHub repositories using the gitingest CLI tool. Provides comprehensive repository summaries including structure, file contents, and overall context.

**Features:**
- Repository tree structure
- File contents digest
- Quick repository understanding
- No local cloning required

**Requirements:**
- Public GitHub repositories only
- Python pip for installing gitingest CLI
- Internet connection

**Output:**
- Complete repository structure tree
- Digest of important files
- Repository metadata and summary

## Examples

### Example 1: Quick Bug Fix

```bash
# Fix a specific error quickly
/fix ReferenceError: user is not defined in api/auth.js:42
```

This will:
1. Create branch `fix/reference-error-auth`
2. Analyze the error context
3. Implement the fix
4. Add tests if needed
5. Create PR with clear description
6. Monitor until all checks pass

### Example 2: Fix Build Error

```bash
# Fix a build/compilation error
/fix TypeScript compilation error: Property 'name' does not exist on type 'User'
```

### Example 3: Analyze a Repository

```bash
# Understand a public repository structure
/gitingest https://github.com/vercel/next.js
```

Output includes:
- Repository file tree
- Key file contents
- Package structure
- Documentation files

### Example 4: Research Before Contributing

```bash
# Before contributing to an open source project
/gitingest https://github.com/facebook/react
```

Use this to quickly understand:
- Project structure
- Coding conventions
- Architecture patterns
- Test organization

## Integration with Other Plugins

Works seamlessly with:
- **fx-sdlc** - Uses coder agent for implementations
- **fx-pr** - Uses PR agents for review and monitoring

## Best Practices

### Using /fix

1. **Be specific with error descriptions** - Include error message, file, and line number
2. **Ensure clean working directory** - Commit or stash changes first
3. **Verify GitHub auth** - Run `gh auth status` before using
4. **Review generated PRs** - Always review the fix before merging
5. **Keep fixes focused** - One error per /fix command

### Using /gitingest

1. **Use for public repos only** - Private repos are not supported
2. **Research before contributing** - Understand project structure first
3. **Learn patterns** - Study how successful projects are organized
4. **Quick onboarding** - Get up to speed on new codebases fast
5. **Not a replacement for docs** - Still read official documentation

## Configuration

### /fix Configuration

Respects:
- `CLAUDE.md` - Project conventions
- Git branch naming conventions
- Commit message format
- GitHub Actions check requirements

### /gitingest Configuration

Uses:
- gitingest CLI (auto-installed via pip)
- GitHub public API
- No authentication required for public repos

## Troubleshooting

### /fix Issues

**GitHub Authentication Fails:**
```bash
# Solution: Authenticate with GitHub CLI
gh auth login
```

**Fix Branch Already Exists:**
```bash
# Solution: Delete old branch or use different error description
git branch -D fix/old-branch
```

**Tests Fail After Fix:**
- Review the implemented fix
- The fix agent will iterate to resolve test failures
- Check if tests need updating

### /gitingest Issues

**gitingest Not Installed:**
- Will auto-install on first use via pip
- Ensure Python and pip are available

**Private Repository Error:**
- Only public GitHub repositories are supported
- Use `git clone` for private repos instead

**Large Repository Timeout:**
- Some very large repositories may timeout
- Try analyzing specific subdirectories if possible

## Common Workflows

### Workflow 1: CI Failure Fix

```bash
# 1. CI reports error
# 2. Copy error message from logs
/fix "Test failed: expected 200 but got 404 in tests/api.test.js:128"

# 3. Review and merge the generated PR
```

### Workflow 2: Production Hotfix

```bash
# 1. Production error reported
# 2. Create hotfix immediately
/fix "Production error: Cannot connect to database - timeout after 30s"

# 3. PR created and tested automatically
# 4. Review and deploy
```

### Workflow 3: Repository Research

```bash
# 1. Find interesting open source project
# 2. Analyze structure
/gitingest https://github.com/org/project

# 3. Study the output to understand:
#    - Project organization
#    - Key components
#    - Testing approach
#    - Documentation structure
```

## Advanced Usage

### Chaining with Other Commands

```bash
# 1. Research a similar project
/gitingest https://github.com/example/similar-project

# 2. Implement feature using learned patterns
/coder Implement authentication similar to the example project

# 3. Fix any issues that arise
/fix "Auth test failing: missing token validation"
```

## Contributing

To enhance this plugin:

1. Add new git-related commands to `commands/`
2. Ensure commands are executable (for .sh files)
3. Add proper descriptions and usage examples
4. Update this README
5. Test commands locally

## License

Part of the fx/cc Claude Code marketplace.
