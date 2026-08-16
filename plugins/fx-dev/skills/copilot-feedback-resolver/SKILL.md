---
name: copilot-feedback-resolver
description: Process and resolve GitHub Copilot automated PR review comments. Use when the user says "check copilot review", "handle copilot comments", "resolve copilot feedback", "address copilot suggestions", or mentions Copilot PR comments. Also use after PR creation when Copilot has left automated review comments.
---

# Copilot Feedback Resolver

**⛔ Load `fx-dev:review` first** (Skill tool: `skill="fx-dev:review"`). It is the
canonical review procedure. This skill is the **Copilot thread adapter**: the
GraphQL calls that fetch, reply to and resolve Copilot's review threads, and the
category table that maps a Copilot comment onto a disposition. Where the two
appear to disagree, `fx-dev:review` wins.

From `fx-dev:review`, and not restated here:

- **Step 1** — the Scope Brief. If a coordinator handed you one, it is binding. If
  this skill was invoked directly, reconstruct one before you can run the scope
  filter at all, and say that you did.
- **Steps 2–3** — triage in filter order, and verify the premise before acting.
- **Step 4** — sweep the class before pushing. Copilot comments on the site it
  read, and every push costs a full Copilot wait cycle, so a half-closed class
  spends one of those per sibling.
- **Step 5** — what each disposition means, and that a coordinator's disposition
  is authoritative.
- **Step 6** — the `REVIEW.md` entry for an incorrect finding, its 4000-character
  constraint, and the rule against writing `.github/copilot-instructions.md` or
  running `fx-dev:setup` from here.

## ⛔ PR Comments Prohibition (CRITICAL)

**NEVER leave new comments directly on GitHub PRs.** Forbidden: `gh pr review
--comment`, `gh pr comment`, any GraphQL mutation creating a new review or
PR-level comment, and **any response to a human reviewer's thread**.

**This skill ONLY processes GitHub Copilot threads.** Permitted operations are
exactly two: reply to an existing Copilot thread with
`addPullRequestReviewThreadReply`, and resolve it with `resolveReviewThread`.

## ⚠️ Resolving the thread IS the deliverable

**Addressing feedback without resolving the thread is INCOMPLETE WORK.** After
handling any Copilot feedback you MUST push the code changes (where the
disposition called for a change), resolve **each** thread via the mutation below,
and verify by re-querying the PR. Code changes alone are insufficient.

Copilot reads `REVIEW.md` from the **head branch**, so a rule you add there takes
effect on this same PR's next review.

## Prerequisites

**CRITICAL: Load the `fx-dev:github` skill FIRST** before running any GitHub API operations. This skill provides essential patterns and error handling for `gh` CLI commands.

## WHEN TO USE THIS SKILL

**USE THIS SKILL PROACTIVELY** when ANY of the following occur:

- User says "check copilot review" / "handle copilot comments" / "resolve copilot feedback"
- User mentions "copilot" and "PR" or "comments" in the same context
- After PR creation when you notice Copilot has reviewed the PR
- User says "address copilot suggestions" / "deal with copilot"
- As part of the PR workflow after `pr-reviewer` skill completes
- When PR checks show Copilot has left review comments

**Invocation:** Use the Skill tool with `skill="fx-dev:copilot-feedback-resolver"`

## Processing Rules

**ONLY process UNRESOLVED comments. NEVER touch, modify, or re-process already resolved comments. Skip them entirely.**

## Core Workflow

### 1. Fetch Unresolved Copilot Threads

Query review threads using GraphQL.

**IMPORTANT:** Use inline values, NOT `$variable` syntax. The `$` character causes shell escaping issues.

```bash
# Replace OWNER, REPO, PR_NUMBER with actual values
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
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
}'
```

**Filter for:** `isResolved: false` AND author is Copilot (github-actions bot or copilot signature)

### 2. Categorize Each Comment

Triage per `fx-dev:review` Steps 2–3. This table is the Copilot-specific mapping
from what a comment looks like onto the disposition that triage produces — it is
not a shortcut around the filters.

**A coordinator's disposition wins over this table**, which classifies from
comment text alone (`fx-dev:review` Step 5). Use the table only for threads it did
not cover, and for a standalone run.

| Category | Indicator | Action |
|----------|-----------|--------|
| **Nitpick** | Contains `[nitpick]` prefix **and reaches filter 3 and fails it** — in scope, violating no rule, and immaterial. An out-of-scope one exits at filter 1 and is **Deferred**, not this row | Reply with the materiality reasoning and resolve, without editing |
| **Outdated** | Refers to code that no longer exists | Reply with the explanation, resolve |
| **Incorrect** | Misreads a deliberate project convention | Reply with the explanation, resolve, record it in `REVIEW.md` |
| **Valid — blocking** | **Is blocking** per `fx-dev/skills/dev/references/scope-contract.md` § Blocking — which includes a contract blocker, and those never pass through the bar at all. Do not narrow it here | Delegate to coder sub-agent to fix |
| **Valid — immaterial** | Correct, but would change nothing if it shipped uncorrected | Reply with that reasoning, resolve. **Do not edit** |
| **Deferred** | Valid but out of scope for this PR | Reply citing the exclusion, resolve. **No edit and no commit** — return the follow-up to the coordinator |

The `[nitpick]` prefix is Copilot's own label, never a verdict: a project-rule,
security, privacy or correctness defect carrying it is still blocking. Never
auto-resolve on the prefix alone.

### 3. Resolve Threads

Use GraphQL mutation to resolve.

**IMPORTANT:** Use inline values, NOT `$variable` syntax.

```bash
# Replace THREAD_ID with actual thread ID (e.g., PRRT_kwDONZ...)
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "THREAD_ID"}) {
    thread { isResolved }
  }
}'
```

### 4. Reply to a Thread

**CRITICAL: reply to the Copilot review thread, NOT to the PR.** Use inline
values, NOT `$variable` syntax.

```bash
# Replace THREAD_ID and message with actual values
gh api graphql -f query='
mutation {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: "PRRT_xxx",
    body: "Your explanation here"
  }) {
    comment { id }
  }
}'
```

**⛔ FORBIDDEN — never use:** `gh pr review <PR_NUMBER> --comment`,
`gh pr comment`, or any interaction with a human reviewer's thread.

Every disposition ends with a reply and a resolve; what differs is only the reply
and whether anything was changed (`fx-dev:review` Step 5). Phrasing that works:

- **Nitpick / immaterial** — what the observation is, and why it is below the bar.
  The reply is required, not an optional acknowledgment: a silently closed thread
  leaves no record of why no edit was made.
- **Outdated** — "This comment refers to code refactored in commit abc123. The
  issue is no longer applicable."
- **Incorrect** — "This conflicts with our [convention name] convention. [Brief
  explanation]. Documented in REVIEW.md so future reviews pick it up." The
  `REVIEW.md` entry is required work (`fx-dev:review` Step 6), and Copilot reads
  that file from the head branch, so it takes effect on this PR's next review.
- **Blocking** — delegate to a coder sub-agent with the PR number and title, the
  file and line, the comment text, and the thread ID for resolution after the fix.
  Ensure it pushes and then resolves.
- **Deferred** — "Valid suggestion, but out of scope for this PR: <the exclusion
  that covers it>. Returned to the coordinator as a follow-up rather than tracked
  here, so this PR is not widened."

**Never defer without recording it somewhere durable — and that record must not be
a commit on this PR.** Return it to the coordinator for the finding ledger or the
PR description; running standalone in a repo that tracks follow-ups in
`PROJECT.md`, propose the entry to the user instead of committing it. A bare
"acknowledged for follow-up" recorded nowhere is INCOMPLETE WORK; a `PROJECT.md`
commit here is a widened change.

### 5. Verify Completion

1. **Push any changes:** `git push`
2. Re-query PR to confirm ALL Copilot threads resolved
3. Report summary of actions taken

## Success Criteria

**Task is INCOMPLETE until ALL of these are done:**

1. ✅ All code changes pushed to the PR branch
2. ✅ **EVERY addressed thread resolved via GraphQL mutation** (not just code fixed!)
3. ✅ **For INCORRECT feedback: `REVIEW.md` updated** to prevent recurrence
4. ✅ **For DEFERRED feedback: the follow-up is recorded outside this PR** — returned to the coordinator, or proposed to the user when running standalone. **No `PROJECT.md` commit on this branch**
5. ✅ Re-query confirms `isResolved: true` for all processed threads
6. ✅ Output summary table (see format below)

### Required Output: Thread Summary Table

**You MUST output this table after processing all threads:**

```
| Thread ID | File:Line | Category | Action Taken | Status |
|-----------|-----------|----------|--------------|--------|
| PRRT_xxx  | src/foo.ts:42 | Nitpick | Replied with reasoning, no edit | ✅ Resolved |
| PRRT_yyy  | src/bar.ts:15 | Valid | Fixed null check | ✅ Resolved |
| PRRT_zzz  | lib/util.js:8 | Outdated | Code refactored | ✅ Resolved |
| PRRT_aaa  | src/ui.tsx:20 | Deferred | Returned to coordinator, no edit | ✅ Resolved |
```

**Column definitions:**
- **Thread ID**: GraphQL thread ID (truncated for readability)
- **File:Line**: Location of the comment
- **Category**: Nitpick, Valid, Outdated, Incorrect, or Deferred
- **Action Taken**: Brief description of resolution (10 words max)
- **Status**: ✅ Resolved, ❌ Failed, or ⏳ Pending

**Common failure mode:** Fixing code but forgetting to resolve the threads. This leaves the PR with unresolved conversations even though the issues are fixed. ALWAYS run the resolution mutation after pushing code.

## Error Handling

- API failures: Retry with proper auth
- Thread ID issues: Use alternative queries
- Delegation failures: Attempt simple fixes directly
- Partial resolution is better than none
