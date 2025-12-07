---
name: github
description: This skill should be used whenever working with the GitHub CLI (`gh` command). Provides battle-tested patterns for PR operations, review thread management, and GraphQL queries. Self-improves by documenting solutions to newly encountered issues.
---

# GitHub CLI Expert

Comprehensive guidance for working with the GitHub CLI (`gh`) including common pitfalls, GraphQL patterns, and self-improvement workflows.

## Purpose

To provide reliable, tested patterns for GitHub operations and prevent repeating known mistakes with the `gh` CLI. This skill automatically loads when using `gh` commands and continuously improves by documenting solutions to new issues.

## When to Use

This skill triggers automatically when:
- Running any `gh` command (pr, api, issue, repo, etc.)
- Working with pull requests, reviews, or issues
- Encountering `gh` CLI errors or unexpected behavior
- Needing GraphQL queries for GitHub operations

## Prerequisites

### GitHub CLI Version

**CRITICAL**: Many features require a recent `gh` CLI version. Before using this skill:

1. **Check current version:**
   ```bash
   gh --version
   ```

2. **Compare with latest release:**
   - Check https://github.com/cli/cli/releases for the current stable version
   - If your version is >6 months old, upgrade

3. **Upgrade `gh` CLI:**

   **Preferred method (mise):**
   ```bash
   mise use -g gh@latest
   ```

   **Alternative (apt):**
   ```bash
   sudo apt update && sudo apt install -y gh
   ```

   **Why mise is preferred:**
   - Always gets the latest version (apt repos lag behind)
   - No sudo required
   - Consistent across environments

4. **Verify upgrade:**
   ```bash
   gh --version
   # Should show version 2.80+ (as of Dec 2025)
   ```

**Known version issues:**
- `gh < 2.20`: Limited GraphQL mutation support
- `gh < 2.40`: Missing `--body-file` flag on `gh pr edit`
- `gh < 2.50`: Incomplete review thread APIs

## Core Principles

### 1. Verify All Operations

Always verify that `gh` commands produced the expected result:

```bash
# After editing PR description
gh pr edit 13 --body-file /tmp/pr-body.md
gh pr view 13 --json body -q .body | head -20  # Verify it worked

# After resolving threads
gh api graphql -f query='mutation { ... }'
gh api graphql -f query='query { ... }' --jq '.data'  # Verify resolution
```

### 2. Prefer GitHub API for Complex Operations

For multi-step operations or data transformations, use `gh api graphql` directly:

```bash
# More reliable than chaining CLI commands
gh api graphql -f query='...' --jq '.data.repository.pullRequest'
```

### 3. Use Correct Methods for Each Task

Check `references/known-issues.md` before attempting operations that have failed before. Common issues include:

- PR description updates with heredocs
- Review thread resolution vs. PR comments
- Command substitution in heredoc strings

## Common Operations

### Update PR Description

**Recommended approach** (most reliable):

```bash
# Write description to file first
cat > /tmp/pr-body.md <<'EOF'
## Summary
...
EOF

# Update via GitHub API
gh api repos/owner/repo/pulls/13 -X PATCH -F body=@/tmp/pr-body.md
```

See `references/known-issues.md` for failed approaches and why they don't work.

### Resolve Review Threads

Use GraphQL mutations, not `gh pr review --comment`:

```bash
# Get thread ID
THREAD_ID="RT_kwDOQipvu86RqL7d"

# Resolve it
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { id isResolved }
    }
  }' -f threadId="$THREAD_ID"
```

See `references/graphql-patterns.md` for complete patterns.

### Get PR Information

```bash
# Simple PR view
gh pr view 13

# Get specific fields as JSON
gh pr view 13 --json title,body,state,reviewThreads

# Filter with jq
gh pr view 13 --json reviewThreads --jq '.reviewThreads[] | select(.isResolved == false)'
```

## Bundled References

### references/known-issues.md

Documents solutions to issues encountered during development:

- PR description update methods (what works, what doesn't)
- Heredoc escaping problems
- Review thread vs PR comment distinction
- Self-improvement template for new issues

**When to read:** Encountering errors with `gh` commands, before attempting complex operations.

### references/graphql-patterns.md

Common GraphQL query and mutation patterns:

- PR operations (get details, review threads)
- Thread management (resolve, unresolve, reply)
- Copilot review workflows
- Batch operations and pagination
- Error handling patterns

**When to read:** Need to query GitHub data, work with review threads, perform batch operations.

## Self-Improvement Workflow

When encountering a new `gh` CLI issue:

1. **Document the problem**
   - What command was run?
   - What was the error or unexpected behavior?
   - What was the intended outcome?

2. **Find the solution**
   - Try alternative approaches
   - Check GitHub CLI documentation
   - Use GraphQL API directly if needed

3. **Update this skill**
   - Read `references/known-issues.md`
   - Add the new issue using the provided template
   - Include both the failed approach and working solution
   - Explain the root cause

4. **Update SKILL.md if needed**
   - If it's a common pattern, add brief guidance to SKILL.md
   - Link to the detailed documentation in references files

### Self-Improvement Example

**Problem encountered:**
```bash
gh pr edit 13 --body "$(cat <<'EOF'
$(cat /tmp/pr-body.md)
EOF
)"
# Result: Literal string "$(cat /tmp/pr-body.md)" in PR description
```

**Solution found:**
```bash
gh api repos/owner/repo/pulls/13 -X PATCH -F body=@/tmp/pr-body.md
# Result: PR description correctly updated
```

**Documentation added to references/known-issues.md:**
- Failed approach with explanation
- Working approach with example
- Root cause analysis
- Alternative solutions

This ensures the same mistake is never repeated.

## Best Practices

1. **Read references before complex operations** - Check if the pattern is already documented
2. **Verify all changes** - Always confirm `gh` commands had the intended effect
3. **Use GraphQL for data queries** - More powerful than chaining CLI commands
4. **Document new solutions** - Update `references/known-issues.md` when encountering new problems
5. **Prefer `-F` over `-f` for file inputs** - Use `@filename` syntax for reliable file reading

## Integration with Other Skills

- **copilot-feedback-resolver**: For complete Copilot review thread workflows
- **fx-dev:pr-***: For PR creation, review, and management workflows
