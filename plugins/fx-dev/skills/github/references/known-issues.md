# Known Issues and Workarounds

This document contains solutions to common GitHub CLI (`gh`) issues encountered during development.

## PR Description Updates

### Issue: `gh pr edit --body` with Heredocs

**Problem:** Command substitutions in heredocs are NOT evaluated when passed to `gh pr edit --body`.

**WRONG** (creates literal string `$(cat /tmp/file.md)`):
```bash
gh pr edit 61 --body "$(cat <<'EOF'
$(cat /tmp/pr-body.md)
EOF
)"
```

**CORRECT** solutions:

#### Method 1: Use `--body-file` flag (Recommended)
```bash
gh pr edit 61 --body-file /tmp/pr-body.md
```

#### Method 2: Use `-F` flag with GitHub API (Most Reliable)
```bash
gh api repos/owner/repo/pulls/61 -X PATCH -F body=@/tmp/pr-body.md
```

#### Method 3: Read file into variable first
```bash
BODY=$(cat /tmp/pr-body.md)
gh pr edit 61 --body "$BODY"
```

### Why This Happens

The `gh pr edit --body` command expects a literal string. When you use a heredoc with `<<'EOF'`, bash doesn't expand command substitutions inside the heredoc. The result is a literal string containing `$(cat /tmp/pr-body.md)` rather than the file contents.

## Copilot Review Thread Resolution

### Issue: `gh pr review --comment` Comments on PR, Not Threads

**Problem:** Using `gh pr review --comment` to reply to Copilot comments creates a new PR-level comment instead of replying to the specific review thread.

**Solution:** Use GitHub GraphQL API to resolve threads:

```bash
# Get thread ID from review comment
THREAD_ID=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!, $commentId: ID!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThread(id: $commentId) {
          id
        }
      }
    }
  }' -f owner="owner" -f repo="repo" -F pr=13 -f commentId="$COMMENT_NODE_ID" --jq '.data.repository.pullRequest.reviewThread.id')

# Resolve the thread
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread {
        id
        isResolved
      }
    }
  }' -f threadId="$THREAD_ID"
```

**Reference:** See `copilot-feedback-resolver` skill for complete Copilot review workflow.

## General Best Practices

### Always Verify API Calls

After making changes via `gh` CLI, verify the result:

```bash
# After editing PR description
gh pr view 13 --json body -q .body | head -20

# After resolving threads
gh api graphql -f query='query { ... }' | jq '.data.repository.pullRequest.reviewThreads.totalCount'
```

### Prefer GitHub API for Complex Operations

For operations involving multiple steps or complex data transformations, use `gh api` directly with GraphQL:

```bash
# More reliable than chaining multiple CLI commands
gh api graphql -f query='...' --jq '.data.whatever'
```

## Self-Improvement Instructions

When encountering a new `gh` CLI issue:

1. **Document the problem** - What command failed? What was the error?
2. **Document the solution** - What alternative approach worked?
3. **Add to this file** - Update this references file with the new pattern
4. **Update SKILL.md** - If it's a common pattern, add a brief mention in SKILL.md

### Template for New Issues

```markdown
### Issue: [Brief Description]

**Problem:** [What went wrong]

**WRONG**:
```bash
# Failed command
```

**CORRECT**:
```bash
# Working solution
```

**Why This Happens:** [Root cause explanation]
```
