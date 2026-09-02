---
name: rabbit-feedback-resolver
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Processes and resolves existing CodeRabbit review threads."
---

# CodeRabbit Feedback Resolver

**⛔ Load `fx-dev:review` first** (Skill tool: `skill="fx-dev:review"`). It is the
canonical review procedure. This skill is the **CodeRabbit thread adapter**: the
shape of a CodeRabbit comment, the `.coderabbit.yaml` configuration it needs, the
GraphQL calls that fetch/reply/resolve, and the category table that maps a comment
onto a disposition. Where the two appear to disagree, `fx-dev:review` wins.

From `fx-dev:review`, and not restated here:

- **Step 1** — the Scope Brief. A coordinator's is binding; invoked directly,
  reconstruct one before you can run the scope filter at all, and say that you did.
- **Steps 2–3** — triage in filter order, and verify the premise before acting.
- **Step 4** — sweep the class before pushing; never push with one half-closed.
- **Step 5** — what each disposition means, and that a coordinator's is
  authoritative.
- **Step 6** — the `REVIEW.md` entry for an incorrect finding.

## PR Comments Prohibition (CRITICAL)

**NEVER leave new comments directly on GitHub PRs.** This is strictly forbidden:

- `gh pr review --comment` - FORBIDDEN
- `gh pr comment` - FORBIDDEN
- Any GraphQL mutation that creates new reviews or PR-level comments - FORBIDDEN

**Permitted operations:**
- Reply to EXISTING CodeRabbit threads using `addPullRequestReviewThreadReply`
- Resolve CodeRabbit threads using `resolveReviewThread`

## INVOCATION BOUNDARY

Use this resolver only when the user explicitly names or invokes it, or when an active explicitly invoked workflow calls `fx-dev:rabbit-feedback-resolver` by name. A standalone mention of CodeRabbit, a PR, comments, review state, or failing checks does not auto-load it.

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

If CodeRabbit feedback conflicts with project conventions (INCORRECT category), document the correct pattern in `REVIEW.md`. Since every reviewer reads it, one entry stops Codex, Copilot, and CodeRabbit from flagging it again.

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

Triage per `fx-dev:review` Steps 2–3. This table is the CodeRabbit-specific
mapping from what a comment looks like onto the disposition triage produces — not
a shortcut around the filters. **A coordinator's disposition wins over it**
(`fx-dev:review` Step 5); use the table for threads it did not cover, and for a
standalone run.

| Category | Indicator | Action |
|----------|-----------|--------|
| **Nitpick/Trivial** | Carries `_🧹 Nitpick_` or `_🔵 Trivial_` **and reaches filter 3 and fails it** — in scope, violating no rule, and immaterial. An out-of-scope one exits at filter 1 and is **Deferred**, not this row | Reply with the materiality reasoning and resolve, no edit |
| **Actionable with AI Prompt** | Has `🤖 Prompt for AI Agents` **and is blocking** per `fx-dev/skills/dev/references/scope-contract.md` § Blocking | Verify the premise, then extract the prompt and delegate to coder |
| **Actionable with Committable** | Has `📝 Committable suggestion` **and is blocking** per the same section | Verify the suggestion against the code, then apply. Never apply on sight |
| **General Feedback** | No special sections | Triage first; delegate to coder only if **blocking**, otherwise reply and resolve with no edit |
| **Deferred** | Valid but out of scope for this PR | Reply citing the exclusion, resolve. **No edit and no commit** — return the follow-up to the coordinator |
| **Outdated** | Refers to code that no longer exists | Reply with the explanation, resolve. No edit |
| **Incorrect** | Misreads a deliberate project convention | Reply with the explanation, resolve, record the convention in `REVIEW.md` |

**The last two rows take a thread whose premise does not hold** — either one the
coordinator left undisposed *with a stated reason*, or one you checked yourself
and rejected (`fx-dev:review` Step 3). A thread with no disposition and no reason
is **untriaged, not rejected**: run the filters over it, including the premise
check, rather than reading a bare omission as a rejection — that closes a real
blocker with a reply and no fix.

The presence of an AI prompt or a committable suggestion says nothing about
materiality: a formatted comment can still rank immaterial, and then it is replied
to and resolved with no edit like any other. Check the disposition first.

### 3. Process Each Category

Every disposition ends with a reply and a resolve; what differs is the reply and
whether anything changed (`fx-dev:review` Step 5). Three handlers have CodeRabbit
mechanics worth spelling out.

#### Actionable with AI Prompt (PREFERRED)

**Only for a thread whose disposition is `blocking`.**

1. Parse the body for the content between `<summary>🤖 Prompt for AI Agents</summary>`
   and the closing `</details>`
2. **Verify the premise before acting.** If it does not hold and the `blocking`
   disposition is the coordinator's, return the thread with the evidence for
   reclassification and leave it open — do not close it on your own reading
   (`fx-dev:review` Step 3). If you assigned the disposition yourself, the thread
   is a false positive: route it through the **Outdated** or **Incorrect** row,
   which is a reply *plus*, where a deliberate convention was misread, the
   `REVIEW.md` entry (`fx-dev:review` Step 6). Replying and resolving without that
   entry loses the only thing that stops the finding coming back
3. Pass the extracted instructions to the coder sub-agent **verbatim**
4. Resolve the thread once the fix is implemented

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
   suggestion applied as written has been observed to introduce the very bug it
   claimed to report. If the premise does not hold, take the same route as above —
   return a coordinator-assigned blocker for reclassification, or route a
   self-assigned one through the **Outdated**/**Incorrect** row, `REVIEW.md` entry
   included where a convention was misread
3. Apply the verified change with the Edit tool
4. Commit referencing the CodeRabbit suggestion, and resolve the thread

#### Deferred (Out of Scope)

**Do not edit or commit anything in this PR**, and do not load
`fx-dev:project-management` to track it here: a tracker commit widens the change
and reopens the review loop for work this PR deliberately is not doing.

1. **Return the follow-up to the coordinator** — the finding ledger or the PR
   description. Running standalone with no coordinator, propose the entry to the
   user rather than committing it
2. **Reply**: "Valid suggestion, but out of scope for this PR: <the exclusion that
   covers it>. Returned as a follow-up rather than tracked here, so this PR is not
   widened."
3. **Resolve the thread**

**CRITICAL:** never defer without recording it somewhere durable — and that record
must not be a commit on this PR. A bare "acknowledged for follow-up" recorded
nowhere is INCOMPLETE WORK; a `PROJECT.md` commit on this branch is a widened
change.

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
