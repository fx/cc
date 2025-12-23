---
name: github
description: "MUST BE USED when working with GitHub: updating PRs, editing PR descriptions/titles, creating PRs, merging, review threads, `gh` CLI commands, GitHub API, or any pull request operations. Load this skill BEFORE running gh commands or modifying PRs. (plugin:fx-dev@fx-cc)"
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

## ⛔ PR Comments Prohibition (CRITICAL)

**NEVER leave comments directly on GitHub PRs.** This is strictly forbidden:

- ❌ `gh pr review --comment` - FORBIDDEN
- ❌ `gh pr comment` - FORBIDDEN
- ❌ `gh api` mutations that create new reviews or PR-level comments - FORBIDDEN
- ❌ Responding to human review comments - FORBIDDEN

**The ONLY permitted interaction with review threads:**
- ✅ Reply to EXISTING threads created by **GitHub Copilot only** using `addPullRequestReviewThreadReply`
- ✅ Resolve Copilot threads using `resolveReviewThread`

**Never respond to or interact with human reviewer comments.** Only automated Copilot feedback should be addressed.

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

### 4. Follow Messaging Conventions

**Be Direct and Concise:**
- All PR descriptions, commit messages, and comments must be direct and to the point
- Eliminate unnecessary prose and filler content
- Focus on what changed and why, not how the work was organized

**Use Conventional Formats:**
- **Commit messages**: Follow conventional commit format (`feat:`, `fix:`, `refactor:`, `docs:`, etc.)
- **PR titles**: Use conventional commit format (e.g., `feat: add user authentication`)
- **Branch names**: Use conventional naming (e.g., `feat/user-auth`, `fix/login-bug`)
- **Comments**: Use conventional comment markers where applicable

**Content Rules:**
- Describe the work being done and changes being made
- Include issue/ticket references (e.g., `#123`, `JIRA-456`)
- **Never mention**: implementation phases, steps of a process, project management terminology, or workflow stages
- **Never include**: "Phase 1", "Step 2", "Part 3", "First iteration", "Initial implementation"

**Examples:**

✅ **Good PR Title:**
```
feat: add user authentication with JWT tokens (#123)
```

❌ **Bad PR Title:**
```
feat: add user authentication - Phase 1: Initial Implementation
```

✅ **Good Commit Message:**
```
fix: resolve login timeout issue

- Increase session timeout to 30 minutes
- Add retry logic for failed auth requests

Fixes #456
```

❌ **Bad Commit Message:**
```
fix: resolve login timeout issue - Step 2 of authentication refactor

This is the second phase of our authentication improvements...
```

✅ **Good Branch Name:**
```
feat/jwt-authentication
fix/login-timeout
```

❌ **Bad Branch Name:**
```
feat/authentication-phase-1
fix/login-step-2
```

## Common Operations

### Create Pull Requests

**CRITICAL - Draft PR Requirement:**

ALL pull requests MUST be created as drafts initially. Never create a PR that is immediately ready for review.

**Workflow:**
1. Create PR as draft with `--draft` flag
2. Wait for `fx-dev:pr-reviewer` agent to review the changes
3. Leave it to the USER to mark ready for review (do NOT do this automatically)

**Correct approach:**
```bash
# Always include --draft flag
gh pr create --draft --title "feat: add feature" --body "$(cat <<'EOF'
## Summary
...
EOF
)"
```

**After fx-dev:pr-reviewer completes:**
- Inform user: "PR created as draft. After addressing any review feedback, you can mark it ready with: `gh pr ready <PR_NUMBER>`"
- DO NOT run `gh pr ready` automatically
- Let the user decide when to flag it ready

**Why drafts:**
- Ensures internal review happens before external visibility
- Prevents premature notifications to team members
- Gives opportunity to address issues found by automated reviewers
- User maintains control over when PR is officially ready

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

### Resolve Copilot Review Threads

**ONLY resolve threads created by GitHub Copilot.** Never interact with human review threads.

Use GraphQL mutations to resolve Copilot threads:

```bash
# Get thread ID (must be a Copilot thread)
THREAD_ID="RT_kwDOQipvu86RqL7d"

# Resolve it
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { id isResolved }
    }
  }' -f threadId="$THREAD_ID"
```

**Reminder:** `gh pr review --comment` is FORBIDDEN. See the PR Comments Prohibition section above.

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
