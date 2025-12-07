---
name: copilot-feedback-resolver
description: Process and resolve GitHub Copilot automated PR review comments. Use when the user says "check copilot review", "handle copilot comments", "resolve copilot feedback", "address copilot suggestions", or mentions Copilot PR comments. Also use after PR creation when Copilot has left automated review comments.
---

# Copilot Feedback Resolver

Process and resolve GitHub Copilot's automated PR review comments systematically.

## ⚠️ CRITICAL REQUIREMENTS ⚠️

### YOU MUST RESOLVE THREADS AFTER ADDRESSING THEM

**After fixing any Copilot feedback, you MUST:**

1. **Push the code changes** (`git push`)
2. **Resolve EACH thread** using the GraphQL mutation (see below)
3. **Verify resolution** by re-querying the PR

**Addressing feedback without resolving the thread is INCOMPLETE WORK.**

The thread resolution is NOT optional - it's the primary deliverable of this skill. Code changes alone are insufficient.

### Thread Resolution Mutation (USE THIS!)

```bash
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { isResolved }
  }
}' -f threadId="THREAD_ID"
```

**You MUST call this mutation for EVERY thread you address.**

---

## WHEN TO USE THIS SKILL

**USE THIS SKILL PROACTIVELY** when ANY of the following occur:

- User says "check copilot review" / "handle copilot comments" / "resolve copilot feedback"
- User mentions "copilot" and "PR" or "comments" in the same context
- After PR creation when you notice Copilot has reviewed the PR
- User says "address copilot suggestions" / "deal with copilot"
- As part of the PR workflow after `pr-reviewer` agent completes
- When PR checks show Copilot has left review comments

**Invocation:** Use the Skill tool with `skill="fx-dev:copilot-feedback-resolver"`

## Processing Rules

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

**CRITICAL: Reply directly to the review thread, NOT to the PR.**

Use GraphQL to add a reply comment to the specific thread:

```bash
gh api graphql -f query='
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: $threadId,
    body: $body
  }) {
    comment { id }
  }
}' -f threadId="PRRT_xxx" -f body="Your explanation here"
```

**NEVER use `gh pr review <PR_NUMBER> --comment`** - this adds comments to the PR itself, not to the specific thread!

1. Reply to the thread with professional explanation:
   - Outdated: "This comment refers to code refactored in commit abc123. The issue is no longer applicable."
   - Incorrect: "This conflicts with our [convention name] convention. [Brief explanation]. See [reference file] for project guidelines."
2. Resolve the thread using the mutation from section 3
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

**Task is INCOMPLETE until ALL of these are done:**

1. ✅ All code changes pushed to the PR branch
2. ✅ **EVERY addressed thread resolved via GraphQL mutation** (not just code fixed!)
3. ✅ Re-query confirms `isResolved: true` for all processed threads
4. ✅ Output summary table (see format below)

### Required Output: Thread Summary Table

**You MUST output this table after processing all threads:**

```
| Thread ID | File:Line | Category | Action Taken | Status |
|-----------|-----------|----------|--------------|--------|
| PRRT_xxx  | src/foo.ts:42 | Nitpick | Auto-resolved | ✅ Resolved |
| PRRT_yyy  | src/bar.ts:15 | Valid | Fixed null check | ✅ Resolved |
| PRRT_zzz  | lib/util.js:8 | Outdated | Code refactored | ✅ Resolved |
```

**Column definitions:**
- **Thread ID**: GraphQL thread ID (truncated for readability)
- **File:Line**: Location of the comment
- **Category**: Nitpick, Valid, Outdated, or Incorrect
- **Action Taken**: Brief description of resolution (10 words max)
- **Status**: ✅ Resolved, ❌ Failed, or ⏳ Pending

**Common failure mode:** Fixing code but forgetting to resolve the threads. This leaves the PR with unresolved conversations even though the issues are fixed. ALWAYS run the resolution mutation after pushing code.

## Error Handling

- API failures: Retry with proper auth
- Thread ID issues: Use alternative queries
- Delegation failures: Attempt simple fixes directly
- Partial resolution is better than none
