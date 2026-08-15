---
name: copilot-feedback-resolver
description: Process and resolve GitHub Copilot automated PR review comments. Use when the user says "check copilot review", "handle copilot comments", "resolve copilot feedback", "address copilot suggestions", or mentions Copilot PR comments. Also use after PR creation when Copilot has left automated review comments.
---

# Copilot Feedback Resolver

Process and resolve GitHub Copilot's automated PR review comments systematically.

## ⛔ PR Comments Prohibition (CRITICAL)

**NEVER leave comments directly on GitHub PRs.** This is strictly forbidden:

- ❌ `gh pr review --comment` - FORBIDDEN
- ❌ `gh pr comment` - FORBIDDEN
- ❌ Any GraphQL mutation that creates new reviews or PR-level comments - FORBIDDEN
- ❌ Responding to human review comments - FORBIDDEN

**This skill ONLY processes GitHub Copilot threads.** Never interact with threads created by human reviewers.

**Permitted operations:**
- ✅ Reply to EXISTING Copilot threads using `addPullRequestReviewThreadReply`
- ✅ Resolve Copilot threads using `resolveReviewThread`

## ⚠️ CRITICAL REQUIREMENTS ⚠️

### YOU MUST RESOLVE THREADS AFTER ADDRESSING THEM

**After fixing any Copilot feedback, you MUST:**

1. **Push the code changes** (`git push`)
2. **Resolve EACH thread** using the GraphQL mutation (see below)
3. **Verify resolution** by re-querying the PR

**Addressing feedback without resolving the thread is INCOMPLETE WORK.**

The thread resolution is NOT optional - it's the primary deliverable of this skill. Code changes alone are insufficient.

### Thread Resolution Mutation (USE THIS!)

**IMPORTANT:** Use inline values, NOT `$variable` syntax. The `$` character causes shell escaping issues (`Expected VAR_SIGN, actual: UNKNOWN_CHAR`).

```bash
# Replace THREAD_ID with actual thread ID (e.g., PRRT_kwDONZ...)
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "THREAD_ID"}) {
    thread { isResolved }
  }
}'
```

**You MUST call this mutation for EVERY thread you address.**

### YOU MUST UPDATE REVIEW.MD FOR INCORRECT FEEDBACK

**When Copilot feedback is categorized as INCORRECT (conflicts with project conventions/patterns), you MUST:**

1. **Update `REVIEW.md` at the repo root** to document the correct pattern
2. This prevents Copilot from flagging the same or similar things in future PRs
3. The update should be concise and explain why the pattern is intentional

**Failure to update `REVIEW.md` = INCOMPLETE WORK for Incorrect category feedback.**

#### Write to REVIEW.md

`REVIEW.md` at the repo root is the single canonical review-conventions file for **every** automated reviewer. **Copilot reads it directly** ([changelog, 2026-07-17](https://github.blog/changelog/2026-07-17-copilot-code-review-customization-and-configurability-improvements/)), so there is no bridge file to maintain.

One file means suppressing a false positive here also suppresses it for CodeRabbit, Codex, and Claude Code Review.

**If `REVIEW.md` does not exist**, create it directly — just the file, with a `# PR Review` heading and your rule under it. **Do NOT run `fx-dev:setup` or `fx-dev:upgrade` from here.** Setup also scaffolds `docs/specs`, `docs/changes`, the task indexes, `AGENTS.md`, `CLAUDE.md`, and `.coderabbit.yaml` — this skill pushes to someone's open PR, and burying one review rule in a large unrelated scaffold is not an acceptable diff. Mention that `/fx-dev:setup` will complete the layout later. See `fx-dev:setup` → `references/instruction-files.md` for the standard.

**Never create or edit `.github/copilot-instructions.md`.** It is obsolete. If the repo still has one, tell the user to run `/fx-dev:upgrade`, which folds it into `REVIEW.md`.

Copilot reads instructions from the **head branch**, so a rule you add here takes effect on this same PR's next review.

#### CRITICAL: File Structure Requirements

**Copilot only reads roughly the first 4000 characters when reviewing.** `REVIEW.md` is also pasted verbatim into Claude Code Review's prompt, where length dilutes the rules that matter. Therefore:

1. **The most important rules MUST go at the TOP** of the file, in a dedicated section
2. **Use a specific review-targeted first section** like `## PR Review Checklist (CRITICAL)`
3. **Keep that section under 4000 characters** — measure with `head -c 4000 REVIEW.md | wc -c`
4. **If exceeding 4000 chars, COMPRESS the section:**
   - Remove redundant words
   - Use terse bullet points
   - Combine related items
   - Move lower-priority guidance below the 4000 char threshold

Example structure:
```markdown
# PR Review

## PR Review Checklist (CRITICAL)
<!-- KEEP THIS SECTION UNDER 4000 CHARS - Copilot only reads first ~4000 -->

- **Pattern X**: Intentional, do not flag
- **Pattern Y**: Required for Z reason

## Lower-priority conventions
<!-- Less critical sections go below -->
```

**After updating, verify:** `head -c 4000 REVIEW.md | tail -5` should show content from the checklist section, not unrelated sections.

**`REVIEW.md` is pasted verbatim** — `@` imports are not expanded and referenced files are not read. Write the rule out in full; never write `See docs/conventions.md`.

---

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

For each unresolved Copilot comment:

**Fix the class, not the instance** (`fx-dev/skills/dev/references/scope-contract.md` § Fix the class, not the instance).
Copilot comments on the site it read. Before pushing a fix, find every sibling of
that defect within this change's surface and fix them together — otherwise the
next Copilot pass reports them as new findings and the loop spends a full wait
cycle per sibling. Never push with a class half-closed.

**If the coordinator supplied per-thread dispositions, they win.** A disposition
from `fx-dev:resolve-pr-feedback` is set with the Scope Brief and the finding
ledger in hand; this table classifies from the comment text alone. Apply the
disposition (`fx-dev/skills/dev/references/scope-contract.md` § Resolver
dispositions) and use the table only for threads it did not cover. In particular
a thread marked `blocking` is fixed even if it carries a `[nitpick]` prefix, and
a thread marked `deferred` is replied to and resolved without editing anything —
including without committing a tracker update to this PR.

**With no disposition — this skill invoked directly, or a thread the coordinator
did not cover — you need a Scope Brief before you can run the scope filter at
all.** Reconstruct one from the conversation and the PR description, and say that
you did (`fx-dev/skills/dev/references/scope-contract.md` § Injecting the brief
into reviews). Filtering without it is guesswork that reads valid out-of-scope
feedback as an in-scope edit — the exact widening the contract exists to stop.
Then **run the filters yourself: scope, then contract, then materiality**
(`fx-dev/skills/dev/references/scope-contract.md` § Three filters). Copilot's
`[nitpick]` prefix is an *input* to that judgment, never a verdict: it is the
reviewer's own label, and a project-rule, security, privacy or correctness defect
carrying it is still blocking. Never auto-resolve on the prefix alone.

| Category | Indicator | Action |
|----------|-----------|--------|
| **Nitpick** | Contains `[nitpick]` prefix **and clears none of the filters below** | Reply and resolve without editing |
| **Outdated** | Refers to code that no longer exists | Reply with explanation, resolve |
| **Incorrect** | Misunderstands project conventions | Reply with explanation, resolve, update `REVIEW.md` |
| **Valid — blocking** | **Is blocking** per `fx-dev/skills/dev/references/scope-contract.md` § Blocking — which includes a contract blocker, and those never pass through the bar at all. Do not narrow it here | Delegate to coder sub-agent to fix |
| **Valid — immaterial** | Correct, but would change nothing if it shipped uncorrected | Reply with that reasoning, resolve. **Do not edit** — a fix push reopens the review loop for an item that changes nothing |
| **Deferred** | Valid but out of scope for this PR | Reply citing the exclusion, resolve. **No edit and no commit** — return the follow-up to the coordinator (`fx-dev/skills/dev/references/scope-contract.md` § Resolver dispositions) |

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

### 4. Handle Each Category

#### Nitpicks (`[nitpick]` prefix)

The prefix is Copilot's label, not a verdict. **Run the filters first** (scope →
contract → materiality, `fx-dev/skills/dev/references/scope-contract.md`): a
project-rule, security, privacy or correctness defect carrying this prefix is
blocking and is fixed. Only once it clears none of the filters is it a nitpick.

Then:
- Resolve without changes — no edit, because an edit reopens the loop for
  something that changes nothing
- Optional brief acknowledgment reply

#### Outdated/Incorrect Copilot Comments

**CRITICAL: Reply directly to the Copilot review thread, NOT to the PR.**

Use GraphQL to add a reply to the specific Copilot thread.

**IMPORTANT:** Use inline values, NOT `$variable` syntax.

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

**⛔ FORBIDDEN COMMANDS - NEVER USE:**
- `gh pr review <PR_NUMBER> --comment` - adds PR-level comments, not thread replies
- `gh pr comment` - adds PR-level comments
- Any interaction with human reviewer threads

1. Reply to the thread with professional explanation:
   - Outdated: "This comment refers to code refactored in commit abc123. The issue is no longer applicable."
   - Incorrect: "This conflicts with our [convention name] convention. [Brief explanation]. Documented in REVIEW.md so future reviews pick it up."
2. Resolve the thread using the mutation from section 3
3. **Update `REVIEW.md`** to prevent recurrence:
   - Add to the top review checklist section
   - Example: "- Do not suggest removing `.sr-only` classes - required accessibility utilities"
   - **Never create or edit `.github/copilot-instructions.md`** — obsolete; Copilot reads `REVIEW.md` directly

#### Valid — blocking

For any concern that **is blocking** under `fx-dev/skills/dev/references/scope-contract.md`
§ Blocking, which this section does not restate. Note that a contract blocker —
a project rule, or a security or privacy invariant — is blocking without ever
being ranked by the bar, so "did it clear the bar" is the wrong question for one.

1. Delegate to coder sub-agent with:
   - PR number and title
   - File and line number
   - Copilot comment text
   - Thread ID for resolution after fix
2. Ensure coder pushes changes and resolves thread

#### Valid — immaterial

Correct, but would change nothing if it shipped uncorrected: wording, formatting,
a count nothing keys on, an entry missing from a list the artifact declares
non-exhaustive.

1. **Do not delegate and do not edit.** A fix push reopens the review loop for an
   item that changes nothing, and Copilot must then re-review the new head.
2. Reply with the reasoning — what the observation is, and why it is below the
   bar — and resolve the thread. The gate is zero *unresolved* threads, not zero
   observations acted on.

#### Deferred (Out of Scope)

**When feedback is valid but out of scope for the current PR:**

**Do not edit or commit anything in this PR.** The canonical `deferred`
disposition (`fx-dev/skills/dev/references/scope-contract.md` § Resolver
dispositions) is reply-and-resolve with no edit; committing a tracker update
widens the change and reopens the review loop for work this PR deliberately is
not doing.

1. **Return the follow-up to the coordinator** so it is recorded outside this
   PR — in the finding ledger, the PR description, or a tracker updated in a
   separate change. When this skill runs standalone with no coordinator and the
   repo tracks follow-ups in `PROJECT.md`, propose the entry to the user rather
   than committing it here.
3. **Reply to the thread** explaining the deferral:
   - "Valid suggestion, but out of scope for this PR: <the exclusion that covers it>. Returned to the coordinator as a follow-up rather than tracked here, so this PR is not widened."
4. **Resolve the thread**

**CRITICAL:** Never defer feedback without recording it somewhere durable — but that record must not be a commit on this PR. Return it to the coordinator for the finding ledger or the PR description; when this skill runs standalone and the repo tracks follow-ups in `PROJECT.md`, propose the entry to the user instead of committing it. A bare "acknowledged for follow-up" with no record anywhere is INCOMPLETE WORK; a `PROJECT.md` commit in this PR is a widened change.

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
This suggestion conflicts with our [convention name] convention. [Brief explanation of why]. Documented in REVIEW.md so future reviews pick it up.
```

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
| PRRT_xxx  | src/foo.ts:42 | Nitpick | Auto-resolved | ✅ Resolved |
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
