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

## Recognizing Repository References

When users refer to repositories, recognize the `owner/repo` shorthand format and expand it appropriately.

### Shorthand Format

The pattern `owner/repo` (e.g., `fx/dotfiles`, `anthropics/claude-code`) refers to a GitHub repository. Always expand this to a full URL.

### Examples

| User says | Interpretation |
|-----------|----------------|
| "clone fx/dotfiles" | Clone `git@github.com:fx/dotfiles.git` |
| "look at anthropics/claude-code" | Repository at `github.com/anthropics/claude-code` |
| "fork vercel/next.js" | Fork from `github.com/vercel/next.js` |

### Clone Priority

When cloning, **always try SSH first**, then fall back to `gh` CLI:

```bash
# User: "clone fx/dotfiles"

# 1. Try SSH first (preferred)
git clone git@github.com:fx/dotfiles.git

# 2. If SSH fails, use gh CLI (handles auth automatically)
gh repo clone fx/dotfiles
```

### URL Expansion Rules

| Shorthand | SSH URL | HTTPS URL |
|-----------|---------|-----------|
| `owner/repo` | `git@github.com:owner/repo.git` | `https://github.com/owner/repo.git` |
| `fx/dotfiles` | `git@github.com:fx/dotfiles.git` | `https://github.com/fx/dotfiles.git` |

**IMPORTANT:** Never prompt the user to clarify `owner/repo` references - assume GitHub and proceed with cloning.

## Git Operations via `gh` CLI

When SSH keys aren't configured or `GIT_SSH_COMMAND` proxying fails, use `gh` CLI for git operations. The `gh` CLI handles authentication automatically when logged in.

### Check Authentication Status

Before using `gh` for git operations, verify authentication:

```bash
gh auth status
```

If authenticated, `gh` can handle cloning, pushing, and other git operations without SSH keys.

### Clone Repositories

**Preferred approach when SSH works:**
```bash
git clone git@github.com:owner/repo.git
```

**Alternative via `gh` (no SSH required):**
```bash
gh repo clone owner/repo
```

This uses HTTPS with automatic token authentication - no SSH key needed.

### Configure Git to Use `gh` for Authentication

Set up git to use `gh` as a credential helper for HTTPS:

```bash
gh auth setup-git
```

This configures git to use `gh` for HTTPS authentication, allowing standard git commands to work:

```bash
git clone https://github.com/owner/repo.git
git push origin main
```

### When to Use `gh` vs SSH

| Scenario | Use |
|----------|-----|
| SSH key configured and working | `git clone git@github.com:...` |
| No SSH key, but `gh auth status` shows logged in | `gh repo clone ...` or HTTPS with `gh auth setup-git` |
| Coder workspace with broken `GIT_SSH_COMMAND` | `gh repo clone ...` |
| CI/CD with `GITHUB_TOKEN` | HTTPS with token auth |

### Common `gh` Git Operations

```bash
# Clone
gh repo clone owner/repo
gh repo clone owner/repo -- --depth 1  # Shallow clone

# Fork and clone
gh repo fork owner/repo --clone

# View repo info
gh repo view owner/repo

# Create repo
gh repo create my-repo --private --clone
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

## Copilot Review Management

GitHub Copilot can automatically review pull requests. This section covers how to check review status and manage Copilot reviews.

### Key Facts

- **Copilot username**: `copilot-pull-request-reviewer` (GraphQL) or `copilot-pull-request-reviewer[bot]` (REST API)
- **Review state**: Copilot only leaves `COMMENTED` state reviews, never `APPROVED` or `CHANGES_REQUESTED`
- **API limitation**: No direct API endpoint to request Copilot reviews; must use UI or automatic triggers

### Request Copilot to Review a PR

There is no API endpoint to programmatically request a Copilot review. Reviews are triggered by:

1. **Automatic reviews via repository rulesets** (recommended)
   - Configure in repo Settings → Rules → Rulesets
   - Enable "Automatically request Copilot code review"
   - Optionally enable "Review new pushes" for re-reviews on each commit

2. **GitHub UI**
   - Open PR → Reviewers menu → Select "Copilot"
   - To re-request: Click the re-request button (🔄) next to Copilot's name

3. **Push new commits** (if "Review new pushes" ruleset is enabled)
   - Simply push to the PR branch to trigger a new review

### Check if Copilot Review is Pending

Query review requests for Bot reviewers:

```bash
# Replace OWNER, REPO, PR_NUMBER with actual values
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewRequests(first: 10) {
        nodes {
          requestedReviewer {
            ... on Bot { login }
          }
        }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewRequests.nodes[] | select(.requestedReviewer.login == "copilot-pull-request-reviewer")'
```

If output is non-empty, Copilot review is pending (in progress).

### Check if Copilot Has Finished Reviewing

Query completed reviews via REST API:

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews \
  --jq '.[] | select(.user.login == "copilot-pull-request-reviewer[bot]") | {state, submitted_at}'
```

Or via GraphQL:

```bash
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviews(first: 20) {
        nodes {
          author { login }
          state
          submittedAt
        }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviews.nodes[] | select(.author.login == "copilot-pull-request-reviewer")'
```

### Full Copilot Review Status Summary

Query all Copilot-related information in one call:

```bash
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewRequests(first: 10) {
        nodes {
          requestedReviewer {
            ... on Bot { login }
          }
        }
      }
      reviews(first: 20) {
        nodes {
          author { login }
          state
          submittedAt
        }
      }
      reviewThreads(first: 100) {
        totalCount
        nodes {
          id
          isResolved
          comments(first: 1) {
            nodes {
              author { login }
            }
          }
        }
      }
    }
  }
}'
```

Then filter for Copilot status:

```bash
# Pending review request
jq '.data.repository.pullRequest.reviewRequests.nodes[] | select(.requestedReviewer.login == "copilot-pull-request-reviewer")'

# Completed reviews
jq '.data.repository.pullRequest.reviews.nodes[] | select(.author.login == "copilot-pull-request-reviewer")'

# Unresolved Copilot threads
jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .comments.nodes[0].author.login == "copilot-pull-request-reviewer")] | length'
```

### Status Interpretation

| Condition | Meaning |
|-----------|---------|
| Review request exists for `copilot-pull-request-reviewer` | Review in progress |
| Review with `submittedAt` exists, no pending request | Review completed |
| Unresolved threads with Copilot author | Feedback needs attention |
| No request, no reviews | Copilot not configured or not triggered |

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
