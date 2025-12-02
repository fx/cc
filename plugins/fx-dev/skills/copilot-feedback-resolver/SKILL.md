---
name: copilot-feedback-resolver
description: Process and resolve GitHub Copilot automated PR review comments. Use when the user says "check copilot review", "handle copilot comments", "resolve copilot feedback", "address copilot suggestions", or mentions Copilot PR comments. Also use after PR creation when Copilot has left automated review comments.
---

# Copilot Feedback Resolver

Process and resolve GitHub Copilot's automated PR review comments systematically.

## WHEN TO USE THIS SKILL

**USE THIS SKILL PROACTIVELY** when ANY of the following occur:

- User says "check copilot review" / "handle copilot comments" / "resolve copilot feedback"
- User mentions "copilot" and "PR" or "comments" in the same context
- After PR creation when you notice Copilot has reviewed the PR
- User says "address copilot suggestions" / "deal with copilot"
- As part of the PR workflow after `pr-reviewer` agent completes
- When PR checks show Copilot has left review comments

**Invocation:** Use the Skill tool with `skill="fx-dev:copilot-feedback-resolver"`

## CRITICAL RULE

**ONLY process UNRESOLVED comments. NEVER touch, modify, or re-process already resolved comments. Skip them entirely.**

## Core Workflow

### 1. Fetch Unresolved Copilot Threads

Query review threads using GraphQL:

```bash
gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 10) {
            nodes {
              author { login }
              body
            }
          }
        }
      }
    }
  }
}' -f owner="OWNER" -f repo="REPO" -F pr=PR_NUMBER
```

**Filter for:** `isResolved: false` AND author is Copilot (github-actions bot or copilot signature)

### 2. Categorize Each Comment

For each unresolved Copilot comment:

| Category | Indicator | Action |
|----------|-----------|--------|
| **Nitpick** | Contains `[nitpick]` prefix | Auto-resolve immediately |
| **Outdated** | Refers to code that no longer exists | Reply with explanation, resolve |
| **Incorrect** | Misunderstands project conventions | Reply with explanation, resolve, update copilot-instructions.md |
| **Valid** | Current, actionable concern | Delegate to coder agent to fix |

### 3. Resolve Threads

Use GraphQL mutation to resolve:

```bash
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { isResolved }
  }
}' -f threadId="THREAD_ID"
```

### 4. Handle Each Category

#### Nitpicks (`[nitpick]` prefix)
- Resolve immediately without changes
- Optional brief acknowledgment reply

#### Outdated/Incorrect Comments
1. Reply with professional explanation:
   - Outdated: "This comment refers to code refactored in commit abc123. No longer applicable."
   - Incorrect: "This conflicts with our project convention for X. See CLAUDE.md."
2. Resolve the conversation
3. **Update `.github/copilot-instructions.md`** to prevent recurrence:
   - Add to "## Code Reviews" section
   - Example: "- Do not suggest removing `.sr-only` classes - required accessibility utilities"
   - **If symlink:** Follow it and edit target file

#### Valid Concerns
1. Delegate to coder agent with:
   - PR number and title
   - File and line number
   - Copilot comment text
   - Thread ID for resolution after fix
2. Ensure coder pushes changes and resolves thread

### 5. Verify Completion

1. **Push any changes:** `git push`
2. Re-query PR to confirm ALL Copilot threads resolved
3. Report summary of actions taken

## Reply Templates

**For outdated comments:**
```
This comment refers to code that has been refactored in commit [hash]. The issue is no longer applicable.
```

**For incorrect/convention conflicts:**
```
This suggestion conflicts with our [convention name] convention. [Brief explanation of why]. See [reference file] for project guidelines.
```

## Success Criteria

Task complete ONLY when:
- All Copilot conversations show "Resolved" in GitHub UI
- Clear audit trail of what was resolved vs delegated
- Any convention conflicts added to copilot-instructions.md
- All code changes pushed

## Error Handling

- API failures: Retry with proper auth
- Thread ID issues: Use alternative queries
- Delegation failures: Attempt simple fixes directly
- Partial resolution is better than none
