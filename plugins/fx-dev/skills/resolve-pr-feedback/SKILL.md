---
name: resolve-pr-feedback
description: Check a PR for unresolved automated review feedback (Copilot, CodeRabbit, Codecov) and invoke the appropriate resolver skills. Use when the user says "resolve PR feedback", "check PR comments", "address review comments", "fix coverage", or wants to handle all automated review feedback on a PR.
---

# Resolve PR Feedback

Meta-skill that checks a PR for unresolved automated review feedback and invokes the appropriate resolver skills.

## MANDATORY: Triage against the Scope Brief

Automated reviewers accept no scope prompt, so they will report work that was deliberately not done. Establish the **Scope Brief** — from the coordinator, or reconstructed from the conversation and PR description — before dispatching any resolver. Definition: `fx-dev/skills/dev/references/scope-contract.md`.

Pass it into every resolver you invoke, and classify each finding before acting:

- **In scope** → resolve it.
- **Covered by the brief's out-of-scope list** → resolve the thread as deferred, citing the exclusion. Never silently fix it, never silently drop it, and never widen the PR to satisfy it.
- **Excluded but correct** → the exclusion was wrong. Fix the work and say the brief was wrong.

Security, data-loss, and correctness problems **inside** the change are always in scope, whatever the brief says. Resolving out-of-scope suggestions is scope creep with a reviewer's name on it.

## WHEN TO USE THIS SKILL

**USE THIS SKILL** when ANY of the following occur:

- User says "resolve PR feedback" / "check PR comments" / "address review comments"
- User wants to handle all automated review feedback on a PR
- After PR creation to ensure all automated reviewers are addressed
- As part of the SDLC workflow before finalizing a PR

## Supported Reviewers

| Reviewer | Author Pattern | Resolver Skill |
|----------|---------------|----------------|
| GitHub Copilot | `copilot-pull-request-reviewer` (GraphQL thread authors) / `copilot-pull-request-reviewer[bot]` (REST) — **never** the bare `Copilot`, which matches nothing | `fx-dev:copilot-feedback-resolver` |
| CodeRabbit | `coderabbitai[bot]` | `fx-dev:rabbit-feedback-resolver` |
| Codecov | `codecov[bot]` / `codecov-commenter` | `fx-dev:resolve-codecov-feedback` |

## Shared Convention: All Resolvers Write to `REVIEW.md`

Every resolver invoked here follows the same rule: when a reviewer's feedback is **INCORRECT** — it conflicts with a deliberate project convention — the recurrence-prevention rule goes in **`REVIEW.md`** at the repo root — never in a reviewer-specific file, and never in the obsolete `.github/copilot-instructions.md`.

`REVIEW.md` is read natively by Copilot and Claude Code Review, by CodeRabbit via `.coderabbit.yaml`, and by Codex via a `## Code Review Rules` pointer in `AGENTS.md`. One entry suppresses the false positive everywhere.

If `REVIEW.md` does not exist, create it directly — just the file, with a `# PR Review` heading and the rule under it. **Do not run `fx-dev:setup` or `fx-dev:upgrade` from here:** both add unrelated files (`docs/`, `AGENTS.md`, `.coderabbit.yaml`), and this runs mid-PR, so they would land in the same diff as the review fix. Note in the summary that `/fx-dev:setup` completes the layout later. The full standard is in `fx-dev:setup` → `references/instruction-files.md`.

### Parallel runs MUST NOT write `REVIEW.md` concurrently

When the Copilot and CodeRabbit resolvers run as concurrent sub-agents (Step 4), both can produce INCORRECT findings targeting the same file. Re-reading before writing is **not** locking — two agents can read the same revision and the second write silently discards the first agent's rule.

**Therefore, when dispatching resolvers in parallel:**

1. Instruct each sub-agent to **collect** its proposed `REVIEW.md` rules and return them in its final report **instead of editing the file**. Everything else (code fixes, thread replies, thread resolution) proceeds normally in parallel — those touch disjoint resources.
2. After **all** parallel resolvers have returned, the root session applies the collected rules to `REVIEW.md` in a single serialized edit, then commits and pushes.
3. Verify no rule was dropped by diffing, not by counting the whole file — an established `REVIEW.md` already contains unrelated rules, so a total-count check always fails:

   ```bash
   git diff -- REVIEW.md
   ```

   Every rule proposed by a sub-agent must appear as an added line. Pre-existing rules must be untouched.

When resolvers run **sequentially** (one reviewer only, or Mode B), the resolver edits `REVIEW.md` directly as its own skill describes — no aggregation needed.

## Prerequisites

**CRITICAL: Load the `fx-dev:github` skill FIRST** before running any GitHub API operations.

## Core Workflow

### 1. Determine PR Number

If not provided, get from current branch:

```bash
gh pr view --json number -q '.number'
```

### 2. Query All Unresolved Review Threads

**IMPORTANT — this applies to the GraphQL query bodies only:** substitute inline
values, NOT `$variable` syntax. `-f query='...'` is single-quoted so the shell never
expands anything inside it, and `$` is GraphQL's own variable sigil, so a `$name`
there is a GraphQL variable you have not declared rather than a value.

**Plain `gh api` / `gh pr view` snippets are the opposite:** they use real shell
variables (`PR_NUMBER`, `REPO_NWO`, `HEAD_SHA`), assigned at the top of each snippet
so it is copy-pasteable as-is. Never mix the two styles inside one snippet — a bare
`PR_NUMBER` sitting next to a real `${HEAD_SHA}` reads as though it were defined, and
silently builds a request against a repo path containing the literal text.

```bash
# Replace OWNER, REPO, PR_NUMBER with actual values (GraphQL body — no shell expansion here)
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 100) {
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

### 3. Identify Unresolved Feedback by Source

Parse the response and categorize unresolved threads by author:

- **Copilot threads**: author login is `copilot-pull-request-reviewer` (GraphQL). Match with `startswith("copilot-pull-request-reviewer")` so the REST `copilot-pull-request-reviewer[bot]` form matches too.
  - **⛔ It is NOT the bare string `Copilot`.** That value appears only in `requested_reviewers`, which is always empty and which this skill never reads. Matching on `Copilot` categorizes **zero** Copilot threads on every PR — so the resolver is never invoked, real threads are silently left unresolved, and this skill reports "nothing to do" while the merge gate is unsatisfiable.
- **CodeRabbit threads**: author login contains `coderabbitai`

**⛔ Threads are not the whole review.** Copilot puts some findings in a `<details><summary>Suppressed comments</summary>` block in the **review body**, where they create no thread at all. A review that reports "generated no new comments" with zero unresolved threads can still contain real bugs there. Read the bodies of the Copilot reviews **of the current head commit** — scoping by `commit_id` is required, or after a push you grep the PREVIOUS commit's body and record this check as satisfied for code that review never covered:

```bash
PR_NUMBER=$(gh pr view --json number --jq '.number')          # or set it explicitly: PR_NUMBER=123
REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
HEAD_SHA=$(gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid')

gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" \
  --jq "[.[] | select(.user.login | startswith(\"copilot-pull-request-reviewer\")) | select(.commit_id == \"${HEAD_SHA}\") | .body] | join(\"\n\n----- (next review of this commit) -----\n\n\")"
```

Empty output means **no Copilot review covers the current head** — that is an unreviewed head, not a clean one. Note this reads *every* review of that commit, not `| last`: two reviews of one commit are routine, and if the newer says "generated no new comments" while the older carried the suppressed block, `last` reads the clean body and finds nothing.

`fx-dev:copilot-review`'s waiter does this for you and emits
`SUPPRESSED_COMMENTS=1|0|unknown`; prefer it over this snippet. Only a definite `0`
is clean — `unknown` means the fetch failed and the check never ran (its **D5**). If
you run the snippet above by hand, apply the same rule: confirm the command
succeeded, because empty output from a failed fetch looks exactly like empty output
from a review with no findings.

Triage those the same way as thread comments. They cannot be resolved (no thread exists), so record the outcome in the commit message or PR body instead.

### 3b. Check for Codecov Coverage Feedback

Codecov uses PR comments and commit statuses, NOT review threads. Query separately:

```bash
PR_NUMBER=$(gh pr view --json number --jq '.number')          # or set it explicitly: PR_NUMBER=123
REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
HEAD_SHA=$(gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid')

# Check for Codecov commit statuses
gh api "/repos/${REPO_NWO}/commits/${HEAD_SHA}/statuses" \
  --jq '[.[] | select(.context | startswith("codecov/"))] | {count: length, statuses: [.[] | {context, state, description}]}'

# Check for Codecov PR comments
gh api "/repos/${REPO_NWO}/issues/${PR_NUMBER}/comments" \
  --jq '[.[] | select(.user.login == "codecov[bot]" or .user.login == "codecov-commenter")] | length'
```

Codecov feedback exists if:
- Any `codecov/*` commit status has state `failure` or `error`
- OR Codecov PR comment indicates patch coverage below threshold

### 4. Invoke Appropriate Resolver Skills

**If Copilot threads exist:**
```
Skill tool: skill="fx-dev:copilot-feedback-resolver"
```

**If CodeRabbit threads exist:**
```
Skill tool: skill="fx-dev:rabbit-feedback-resolver"
```

**If Codecov coverage gaps detected:**
```
Skill tool: skill="fx-dev:resolve-codecov-feedback"
```

**If multiple exist:** Prefer running Copilot and CodeRabbit resolvers **in parallel** by spawning each as a sub-agent in the same message (see `fx-dev:dev` Step 6.3 for the exact pattern). Codecov is sequential after them since coverage fixes typically require code from the other resolvers to be in place first.

### 5. Verify All Resolved AND Loop Until Convergence

After invoking resolver skills, re-query to confirm all threads are resolved AND that no reviewer has posted new feedback in response to the fixes that were pushed.

**Cycle, don't single-shot.** CodeRabbit re-runs after every push and may post new threads on the new commits. Copilot does **not** — it must be asked again. Either way, a single-pass resolver leaves a stale "settled" state behind. Loop:

1. **Nudge Copilot for the current head SHA** via `fx-dev:copilot-review` (its Step 1). **Copilot does NOT re-review pushed commits on its own.** Skipping this makes the rest of the loop meaningless: you will poll, see nothing, and "converge" on code no reviewer has read. Issue the nudge and discard its response — it is fire-and-forget, never evidence, and having issued it is never a substitute for step 6's received-review check.
2. Wait for all reviewer checks to reach terminal state (use the dedicated waiters: `fx-dev:copilot-review` for Copilot, `fx-dev:coderabbit-review` for CodeRabbit). **Do not hand-roll a `gh api` / GraphQL polling loop in their place** — a hand-rolled loop only observes, never requests, and will happily accept a review of a superseded commit.
3. Re-query unresolved threads (per below).
4. If the breakdown array is non-empty, re-invoke the relevant resolver(s).
5. After fixes are pushed, restart at step 1 — the push created unreviewed commits.
6. Stop when a pass produces zero new feedback **on a head SHA that was actually reviewed** (verify: the newest Copilot review's `commit_id` equals `headRefOid`). Cap at 4 outer iterations and escalate to the user if not converged.

**⛔ Zero new threads is not convergence unless a Copilot review has been RECEIVED for the current head SHA.** "Received for the current head" is the *only* condition — do **not** phrase it as "was requested", and do not try to verify that a request happened: `requested_reviewers` is empirically always empty, so whether a review was requested is not a determinable fact (see `fx-dev:copilot-review` **D1**/**D3**). Issue the nudge because it sometimes helps, then judge convergence solely on the delivered review. Absence of feedback is not evidence of quality.

Verify before declaring the loop converged:

```bash
PR_NUMBER=$(gh pr view --json number --jq '.number')          # or set it explicitly: PR_NUMBER=123
REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

HEAD_SHA=$(gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid')
REVIEWED=$(gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" \
  --jq '[.[] | select(.user.login | startswith("copilot-pull-request-reviewer")) | .commit_id] | last // empty')
[[ -n "$REVIEWED" && "$REVIEWED" == "$HEAD_SHA" ]] \
  && echo "covered: $HEAD_SHA" \
  || echo "NOT covered — head=$HEAD_SHA reviewed=${REVIEWED:-none}"
```

The `// empty` is load-bearing: without it, a PR with no Copilot reviews prints the literal string `null`, which then gets compared against a SHA under a "these MUST match" instruction — an unreviewed head presented as a concrete-looking value instead of an obvious absence.

Re-query remaining unresolved threads **from automated reviewers only**. The query
below returns a per-reviewer breakdown array, not a single number.
This skill resolves automated feedback and `fx-dev:github` forbids touching human
review threads at all, so an unfiltered query makes one open human comment
permanently unsatisfiable and loops this skill against work it must not do:

```bash
# Replace OWNER, REPO, PR_NUMBER with actual values (GraphQL body — no shell expansion here)
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 100) {
        nodes {
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
}' | jq '[.data.repository.pullRequest.reviewThreads.nodes[]
          | select(.isResolved == false)
          | .comments.nodes[0].author.login]
         | group_by(.) | map({reviewer: .[0], unresolved: length})
         | map(select(.reviewer
               | startswith("copilot-pull-request-reviewer")
                 or contains("coderabbitai")
                 or startswith("codecov")))'
```

That reports a per-reviewer breakdown, so "unresolved threads remain" comes with the
reviewer name attached. An empty array means no automated reviewer has open feedback;
any human threads it excluded are deliberately not your concern.

If unresolved threads remain, report which reviewers still have open feedback.

## Output Format

```
## PR #123 Feedback Summary

### Detection
- Copilot: 2 unresolved threads found
- CodeRabbit: 3 unresolved threads found
- Codecov: patch coverage 65% (below threshold)

### Resolution
- Invoked fx-dev:copilot-feedback-resolver
- Invoked fx-dev:rabbit-feedback-resolver
- Invoked fx-dev:resolve-codecov-feedback

### Final Status
- All automated review threads resolved
- Coverage improved to 85%
```

## Success Criteria

1. All unresolved automated review threads identified — matched on the `copilot-pull-request-reviewer` login, **not** the bare `Copilot` — **plus** any findings in the "Suppressed comments" block of every Copilot review **of the current head commit**, which produce no threads
2. Appropriate resolver skill(s) invoked (Copilot + CodeRabbit in parallel where applicable)
3. The wait-and-resolve loop has CONVERGED — a Copilot review has been **RECEIVED for the current head SHA** and produced zero new findings. That is the whole condition: do not add "and was requested", which is not a determinable fact (**D1**). A quiet poll on an unreviewed head is not convergence
4. CodeRabbit's check is in a terminal passing state (or absent if not configured)
5. Final verification confirms all threads resolved
6. Summary output provided

## Error Handling

- If no PR found: Ask user for PR number
- If resolver skill fails: Report which reviewer's feedback remains unresolved
- If API errors: Retry with proper auth context
