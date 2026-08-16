---
name: rabbit-feedback-resolver
description: Process and resolve CodeRabbit automated PR review comments. Use when the user says "check rabbit review", "handle coderabbit comments", "resolve rabbit feedback", or mentions CodeRabbit PR comments. Also use after PR creation when CodeRabbit has left automated review comments.
---

# CodeRabbit Feedback Resolver

Process and resolve CodeRabbit's automated PR review comments systematically.

## PR Comments Prohibition (CRITICAL)

**NEVER leave new comments directly on GitHub PRs.** This is strictly forbidden:

- `gh pr review --comment` - FORBIDDEN
- `gh pr comment` - FORBIDDEN
- Any GraphQL mutation that creates new reviews or PR-level comments - FORBIDDEN

**Permitted operations:**
- Reply to EXISTING CodeRabbit threads using `addPullRequestReviewThreadReply`
- Resolve CodeRabbit threads using `resolveReviewThread`

## WHEN TO USE THIS SKILL

**USE THIS SKILL PROACTIVELY** when ANY of the following occur:

- User says "check rabbit review" / "handle coderabbit comments" / "resolve rabbit feedback"
- User mentions "coderabbit" or "rabbit" and "PR" or "comments" in the same context
- After PR creation when CodeRabbit has reviewed the PR
- As part of the PR workflow after `pr-reviewer` skill completes
- When PR checks show CodeRabbit has left review comments

## CodeRabbit Comment Structure

CodeRabbit comments follow a structured markdown format:

```
_🧹 Nitpick_ | _🔵 Trivial_    <- Severity indicator (optional)

[Main feedback text]

<details>
<summary>💡 Optional suggestion</summary>
[Expanded suggestion content]
</details>

<details>
<summary>📝 Committable suggestion</summary>
[Code block with suggested changes]
</details>

<details>
<summary>🤖 Prompt for AI Agents</summary>
[Explicit instructions for AI to follow]
</details>
```

**Key elements to extract.** All three are *inputs* to triage, never verdicts —
the disposition comes from the coordinator, or from the filters you run yourself
(`fx-dev/skills/dev/references/scope-contract.md` § Three filters):
- **Severity**: `_🧹 Nitpick_` or `_🔵 Trivial_` is CodeRabbit's own label. It
  suggests immaterial; it does not establish it. A project-rule, security,
  privacy or correctness defect carrying it is still blocking.
- **Prompt for AI Agents**: explicit instructions. Use them for a **blocking**
  finding, after checking the premise holds.
- **Committable suggestion**: ready-to-apply code. Verify it against the tree
  before applying — a suggestion is a claim, and an applied-on-sight one has
  introduced the bug it claimed to report.

## Prerequisites

**CRITICAL: Load the `fx-dev:github` skill FIRST** before running any GitHub API operations. This skill provides essential patterns and error handling for `gh` CLI commands.

## Core Workflow

### 0. Verify CodeRabbit Configuration (First Run Only)

**Before processing feedback, ensure CodeRabbit is configured to read `REVIEW.md` and `AGENTS.md`.**

`REVIEW.md` (repo root) is the canonical review-conventions file for every automated reviewer; `AGENTS.md` holds project conventions. CodeRabbit's `knowledge_base.code_guidelines` feature reads instruction files to understand both. Its defaults cover `**/AGENTS.md` and `**/CLAUDE.md` — but **not** `**/REVIEW.md`, so the config below is what gets the review conventions to CodeRabbit. See `fx-dev:setup` → `references/instruction-files.md` for the full standard.

#### Check Configuration

```bash
# Canonical files present?
test -f REVIEW.md && echo "REVIEW.md exists" || echo "REVIEW.md MISSING - run fx-dev:setup"

# Check if .coderabbit.yaml exists
if [ -f ".coderabbit.yaml" ]; then
  cat .coderabbit.yaml
else
  echo "No .coderabbit.yaml found - using defaults"
fi
```

If `REVIEW.md` is missing, create it directly — just the file, with a `# PR Review` heading. **Do NOT run `fx-dev:setup` or `fx-dev:upgrade` from here:** setup also scaffolds `docs/`, `AGENTS.md`, `CLAUDE.md`, and `.coderabbit.yaml`, and this skill pushes to an open PR, so that would bury one review rule in a large unrelated diff. Mention that `/fx-dev:setup` will complete the layout later.

#### Configuration States

| State | Action |
|-------|--------|
| No `.coderabbit.yaml` exists | **Create it** with the config below |
| Exists, `knowledge_base.code_guidelines.enabled: false` | **Do not flip it.** Someone disabled code guidelines deliberately, and this skill is mid-PR — silently re-enabling it commits an unrelated behavioural change. Report it, note that CodeRabbit will keep reviewing without the project's conventions, and let the user decide (`/fx-dev:upgrade` handles it with confirmation) |
| Exists, `enabled: true`, no `**/REVIEW.md` in `filePatterns` | **Add** `"**/REVIEW.md"` — including when `filePatterns` is absent entirely, since the defaults do not cover it |
| Exists, `enabled: true`, `**/REVIEW.md` already present | No action needed |

**The only state needing no action is the last one.** `enabled: true` by itself is not sufficient: CodeRabbit's defaults cover `**/AGENTS.md` and `**/CLAUDE.md` but never root `REVIEW.md`, so without the explicit pattern it reviews with no knowledge of the review conventions.

#### Create/Update Configuration

Create or modify `.coderabbit.yaml`:

```yaml
# .coderabbit.yaml
# Ensures CodeRabbit reads review conventions from REVIEW.md.
# AGENTS.md is already covered by CodeRabbit's default patterns.

knowledge_base:
  code_guidelines:
    enabled: true
    # Custom patterns APPEND to the defaults, they do not replace them.
    # REVIEW.md is not in CodeRabbit's defaults, so list it explicitly.
    filePatterns:
      - "**/REVIEW.md"
```

Patterns are **case-sensitive**: `review.md` does not match `**/REVIEW.md`.

#### When to Update REVIEW.md

If CodeRabbit feedback conflicts with project conventions (INCORRECT category), document the correct pattern in `REVIEW.md`. Since every reviewer reads it, one entry stops Copilot, CodeRabbit, Codex, and Claude Code Review from flagging it again.

**Never create or edit `.github/copilot-instructions.md`** — it is obsolete; Copilot reads `REVIEW.md` directly.

### 1. Fetch Unresolved CodeRabbit Threads

Query review threads using GraphQL.

**IMPORTANT:** Use inline values, NOT `$variable` syntax. The `$` character causes shell escaping issues (`Expected VAR_SIGN, actual: UNKNOWN_CHAR`).

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
          path
          line
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

**Filter for:** `isResolved: false` AND author login contains `coderabbitai`

### 2. Categorize Each Comment

For each unresolved CodeRabbit comment:

**Fix the class, not the instance** (`fx-dev/skills/dev/references/scope-contract.md` § Fix the class, not the instance).
CodeRabbit comments on the site it read. Before pushing a fix, find every sibling
of that defect within this change's surface and fix them together — otherwise the
next pass reports them as new findings and the loop never ends. Never push with a
class half-closed.

**If the coordinator supplied per-thread dispositions, they win.** A disposition
from `fx-dev:coderabbit-review` or `fx-dev:resolve-pr-feedback` is set with the
Scope Brief and the finding ledger in hand; this table classifies from comment
text alone. Apply the disposition (`fx-dev/skills/dev/references/scope-contract.md`
§ Resolver dispositions) and use the table only for threads it did not cover. A
thread marked `blocking` is fixed even when CodeRabbit labelled it
`_🧹 Nitpick_`; a thread marked `immaterial` or `deferred` is replied to and
resolved **without editing anything**.

**With no disposition — this skill invoked directly, or a thread the coordinator
did not cover — reconstruct the Scope Brief first**, from the conversation and the
PR description, and say that you did
(`fx-dev/skills/dev/references/scope-contract.md` § Injecting the brief into
reviews). There is no scope filter without one, and filtering by guess reads valid
out-of-scope feedback as an in-scope edit. **Then run the filters yourself** —
scope, then contract, then materiality
(`fx-dev/skills/dev/references/scope-contract.md` § Three filters). CodeRabbit's
own labels are an *input* to that judgment, never a verdict.

| Category | Indicator | Action |
|----------|-----------|--------|
| **Nitpick/Trivial** | Carries `_🧹 Nitpick_` or `_🔵 Trivial_` **and reaches filter 3 and fails it** — in scope, violating no rule, and immaterial. An out-of-scope one exits at filter 1 and is **Deferred**, not this row | Reply with the materiality reasoning and resolve, no edit |
| **Actionable with AI Prompt** | Has `🤖 Prompt for AI Agents` section **and is blocking** per `fx-dev/skills/dev/references/scope-contract.md` § Blocking | Verify the premise, then extract the prompt and delegate to coder |
| **Actionable with Committable** | Has `📝 Committable suggestion` **and is blocking** per `fx-dev/skills/dev/references/scope-contract.md` § Blocking | Verify the suggestion against the code, then apply. Never apply on sight — a committable suggestion is still a claim about the tree |
| **General Feedback** | No special sections | Triage first; delegate to coder only if **blocking**, otherwise reply and resolve with no edit |
| **Deferred** | Valid but out of scope for this PR | Reply citing the exclusion, resolve. **No edit and no commit** — return the follow-up to the coordinator (`fx-dev/skills/dev/references/scope-contract.md` § Resolver dispositions) |
| **Outdated** | Refers to code that no longer exists | Reply with the explanation, resolve. No edit |
| **Incorrect** | Misreads a deliberate project convention | Reply with the explanation, resolve, and record the convention in `REVIEW.md` |

**Only a thread the coordinator left undisposed *with a stated reason* takes
those last two rows** (`fx-dev/skills/dev/references/scope-contract.md`
§ Resolver dispositions): that is a false positive it verified and rejected, and
the reason is what marks it as one. Then it is **Outdated** or **Incorrect**
whatever section markers it carries.

**A thread with no disposition and no reason is untriaged, not rejected.** The
coordinator is allowed to leave a thread uncovered, and this skill also runs
standalone with no coordinator at all — so triage it yourself, as above. **That
includes checking the premise**: if you find the thread describes code that no
longer exists, or misreads a deliberate convention, it is **Outdated** or
**Incorrect** and takes those rows on your own finding, exactly as it would on
the coordinator's. The filters rank a real finding; they do not detect a false
one, so an unchecked premise is how an incorrect thread loses its `REVIEW.md`
entry. Reading a bare omission as a verified rejection resolves a
real blocker with a reply and no fix, which is the one outcome this table exists
to prevent. Either way the thread ends resolved: an unhandled one holds the
zero-unresolved-threads gate open indefinitely.

### 3. Process Each Category

#### Nitpicks/Trivial

The label is CodeRabbit's, not a verdict. **Run the filters first**: a
project-rule, security, privacy or correctness defect carrying it is blocking
and is fixed, and an out-of-scope one is **Deferred** — it exits at filter 1 and keeps the exclusion and the follow-up record that a nitpick has neither of. Only an item that reaches filter 3 and fails it is a nitpick.

- **Reply with the reasoning** — what the observation is and why it is below the
  bar — then resolve. The reply is required
  (`fx-dev/skills/dev/references/scope-contract.md` § Resolver dispositions): a
  silently closed thread leaves no record of why no edit was made
- No edit — an edit reopens the loop for something that changes nothing

#### Actionable with AI Prompt (PREFERRED)

**Only for a thread whose disposition is `blocking`.** The presence of an AI
prompt says nothing about materiality: a formatted comment can still rank
Immaterial, and then it is replied to and resolved with no edit, exactly like any
other immaterial thread. Check the disposition first.

For a blocking one:

1. Parse the comment body to extract content between `<summary>🤖 Prompt for AI Agents</summary>` and the closing `</details>`
2. **Verify the premise before acting.** The prompt asserts something about the
   tree; when that does not hold, do **not** reply-and-resolve on your own
   authority — the coordinator's `blocking` disposition outranks your reading
   (`fx-dev/skills/dev/references/scope-contract.md` § Resolver dispositions).
   Return the thread to the coordinator with the evidence for reclassification,
   and leave it open until it comes back. Only when you assigned the disposition
   yourself may you reverse it here. Either way, never change working code to
   satisfy a misreading
3. Pass the extracted instructions to the coder sub-agent verbatim
4. After the fix is implemented, resolve the thread

Example extraction:
```
In src/lib/view-config.ts around lines 115 to 118, expand the JSDoc above
NUMERIC_OPERATORS to explicitly state that operators in this set expect numeric
values...
```

#### Actionable with Committable Suggestion

**Only for a thread whose disposition is `blocking`** — a committable suggestion
attached to an immaterial observation is still immaterial, and applying it
produces the push that reopens the loop.

1. Extract the code block from the `📝 Committable suggestion` section
2. **Verify it against the code before applying.** Never apply on sight: a
   suggestion is a claim about the tree, and one applied as written has been
   observed to introduce the very bug it claimed to report. If the premise does
   not hold and the `blocking` disposition is the coordinator's, return the
   thread with the evidence for reclassification and leave it open — closing a
   correctness or security blocker on a local reading is the one thing an
   authoritative disposition exists to prevent. If you assigned it yourself,
   reply with the evidence and resolve instead
3. Apply the verified change using the Edit tool
4. Commit with a message referencing the CodeRabbit suggestion
5. Resolve the thread

#### General Feedback

1. Read the feedback carefully
2. Determine if it's valid or conflicts with project conventions
3. If valid **and blocking** (`fx-dev/skills/dev/references/scope-contract.md`
   § Blocking): delegate to coder sub-agent with context
4. If valid but **immaterial** — correct, and yet nothing would break if it
   shipped uncorrected: reply with that reasoning and resolve. **Do not delegate
   and do not edit**; a fix push reopens the review loop for an item that changes
   nothing. Validity is not the gate here, materiality is
5. If it refers to code that no longer exists (OUTDATED):
   - Reply naming the commit that removed or refactored it, and resolve
   - No edit — there is nothing left to fix
6. If conflicts with project conventions (INCORRECT):
   - Reply with explanation and resolve
   - **Update `REVIEW.md`** to document the correct pattern
   - This prevents Copilot, CodeRabbit, Codex, AND Claude Code Review from flagging it again — they all resolve to the same file

#### Deferred (Out of Scope)

**When feedback is valid but out of scope for the current PR:**

1. **Return the follow-up to the coordinator** — the finding ledger or the PR
   description. **Do not edit or commit anything in this PR**, and do not load
   `fx-dev:project-management` to track it here: the canonical `deferred`
   disposition is reply-and-resolve with no edit, and a tracker commit widens the
   change and reopens the review loop. Running standalone with no coordinator,
   propose the entry to the user rather than committing it.
3. **Reply to the thread** explaining the deferral:
   - "Valid suggestion, but out of scope for this PR: <the exclusion that covers it>. Returned as a follow-up rather than tracked here, so this PR is not widened."
4. **Resolve the thread**

**CRITICAL:** Never defer feedback without recording it somewhere durable — but that record must not be a commit on this PR. A bare "acknowledged for follow-up" with no record anywhere is INCOMPLETE WORK; a `PROJECT.md` commit on this branch is a widened change.

### 4. Resolve Threads

Use GraphQL mutation to resolve each processed thread.

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

### 5. Reply to Threads (When Needed)

For feedback that conflicts with conventions or is being declined.

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

## Parsing Helper

To extract the AI prompt from a CodeRabbit comment:

```bash
# Extract content between 🤖 Prompt for AI Agents and </details>
echo "$COMMENT_BODY" | sed -n '/🤖 Prompt for AI Agents/,/<\/details>/p' | sed '1d;$d' | sed 's/^```$//'
```

## Success Criteria

**Task is INCOMPLETE until ALL of these are done:**

1. CodeRabbit config verified/updated to read `REVIEW.md` and `AGENTS.md`
2. All code changes pushed to the PR branch
3. **EVERY addressed thread resolved via GraphQL mutation**
4. **For INCORRECT feedback:** `REVIEW.md` updated to prevent recurrence
5. **For DEFERRED feedback:** the follow-up is recorded outside this PR — returned to the coordinator, or proposed to the user when running standalone. **No `docs/PROJECT.md` commit on this branch**
6. Re-query confirms `isResolved: true` for all processed threads
7. Output summary table

### Required Output: Thread Summary Table

```
| Thread ID | File:Line | Category | Action Taken | Status |
|-----------|-----------|----------|--------------|--------|
| PRRT_xxx  | src/foo.ts:42 | Nitpick | Replied with reasoning, no edit | ✅ Resolved |
| PRRT_yyy  | src/bar.ts:15 | AI Prompt | Applied JSDoc fix | ✅ Resolved |
| PRRT_zzz  | lib/util.js:8 | Committable | Applied suggestion | ✅ Resolved |
| PRRT_aaa  | src/ui.tsx:20 | Deferred | Returned to coordinator, no edit | ✅ Resolved |
| PRRT_bbb  | src/api.ts:88 | Immaterial | Replied, no edit | ✅ Resolved |
| PRRT_ccc  | src/old.ts:31 | Outdated | Code refactored, replied | ✅ Resolved |
```

## Error Handling

- API failures: Retry with proper auth
- Thread ID issues: Use alternative queries
- Parse failures for AI prompt: Fall back to manual analysis
- Partial resolution is better than none
