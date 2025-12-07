# GitHub GraphQL Patterns

Common GraphQL query and mutation patterns for GitHub operations via `gh api graphql`.

## Pull Request Operations

### Get PR Details with Review Threads

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        id
        title
        body
        state
        reviewThreads(first: 100) {
          totalCount
          nodes {
            id
            isResolved
            isOutdated
            comments(first: 10) {
              nodes {
                id
                body
                author {
                  login
                }
              }
            }
          }
        }
      }
    }
  }' -f owner="owner" -f repo="repo" -F pr=13
```

### Get Unresolved Review Threads Only

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) {
              nodes {
                id
                body
                path
                line
              }
            }
          }
        }
      }
    }
  }' -f owner="owner" -f repo="repo" -F pr=13 \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```

## Review Thread Management

### Resolve a Review Thread

```bash
# Get thread ID first
THREAD_ID="RT_kwDOQipvu86RqL7d"

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

### Reply to Review Thread Comment

```bash
# Get the pull request review thread comment ID
COMMENT_ID="PRRC_kwDOQipvu86RqL7e"

# Add a reply to the thread
gh api graphql -f query='
  mutation($body: String!, $inReplyTo: ID!) {
    addPullRequestReviewComment(input: {
      body: $body
      inReplyTo: $inReplyTo
    }) {
      comment {
        id
        body
      }
    }
  }' -f body="Fixed in latest commit" -f inReplyTo="$COMMENT_ID"
```

### Unresolve a Review Thread

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    unresolveReviewThread(input: {threadId: $threadId}) {
      thread {
        id
        isResolved
      }
    }
  }' -f threadId="$THREAD_ID"
```

## Automated Review Workflows

### Count Unresolved Bot Review Threads

```bash
# Filter by bot author (e.g., copilot-pull-request-reviewer, github-copilot[bot])
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 1) {
              nodes {
                author {
                  login
                }
              }
            }
          }
        }
      }
    }
  }' -f owner="owner" -f repo="repo" -F pr=13 \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .comments.nodes[0].author.login == "copilot-pull-request-reviewer")] | length'
```

### Get All Bot Review Comments

```bash
# Filter by bot author (e.g., copilot-pull-request-reviewer, github-copilot[bot])
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            isOutdated
            comments(first: 10) {
              nodes {
                id
                body
                path
                line
                author {
                  login
                }
              }
            }
          }
        }
      }
    }
  }' -f owner="owner" -f repo="repo" -F pr=13 \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.comments.nodes[0].author.login == "copilot-pull-request-reviewer")'
```

## Batch Operations

### Resolve Multiple Threads

```bash
# Get all unresolved thread IDs
THREAD_IDS=$(gh api graphql -f query='...' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .id')

# Resolve each thread
while IFS= read -r thread_id; do
  echo "Resolving $thread_id..."
  gh api graphql -f query='
    mutation($threadId: ID!) {
      resolveReviewThread(input: {threadId: $threadId}) {
        thread { id isResolved }
      }
    }' -f threadId="$thread_id"
done <<< "$THREAD_IDS"
```

## Error Handling

### Check for GraphQL Errors

```bash
RESULT=$(gh api graphql -f query='...')

# Check if errors exist
if echo "$RESULT" | jq -e '.errors' > /dev/null; then
  echo "GraphQL error occurred:"
  echo "$RESULT" | jq '.errors'
  exit 1
fi

# Process successful result
echo "$RESULT" | jq '.data'
```

## Best Practices

1. **Use Variables** - Always use GraphQL variables (`-f` or `-F` flags) instead of string interpolation
2. **Filter with jq** - Use `--jq` to filter results client-side rather than complex GraphQL queries
3. **Batch Wisely** - For >100 items, use pagination with `after` cursor
4. **Check Errors** - Always check for `.errors` in the response before processing `.data`
5. **Node IDs** - PR review thread IDs start with `RT_`, comment IDs start with `PRRC_` or `IC_`

## Pagination Pattern

```bash
# For queries returning >100 items
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!, $after: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100, after: $after) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
          }
        }
      }
    }
  }' -f owner="owner" -f repo="repo" -F pr=13
```
