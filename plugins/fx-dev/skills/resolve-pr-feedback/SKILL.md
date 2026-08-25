---
name: resolve-pr-feedback
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Coordinates explicitly requested automated PR-feedback resolution across configured reviewers."
---

# Resolve PR Feedback

**⛔ Load `fx-dev:review` first** (Skill tool: `skill="fx-dev:review"`). It is the
canonical review procedure. This skill is the **coordinator adapter**: it finds
every unresolved automated finding on a PR, triages it, and dispatches the right
resolver with the brief and a disposition per thread. Where the two appear to
disagree, `fx-dev:review` wins.

You are the coordinator here, so three of its steps are specifically yours:

- **Step 1** — establish the Scope Brief before dispatching anything. From the
  caller, or reconstructed from the conversation and PR description.
- **Steps 2–3** — you hold the brief and the ledger, so **your** triage is the
  authoritative one; a resolver classifying from comment text alone does not have
  what you have. Verify each premise before assigning anything.
- **Step 6** — when resolvers run in parallel, the `REVIEW.md` writes must be
  serialized through you.

## Supported Reviewers

| Reviewer | Author Pattern | Resolver Skill |
|----------|---------------|----------------|
| GitHub Copilot | `copilot-pull-request-reviewer` (GraphQL thread authors) / `copilot-pull-request-reviewer[bot]` (REST) — **never** the bare `Copilot`, which matches nothing | `fx-dev:copilot-feedback-resolver` |
| CodeRabbit | `coderabbitai[bot]` | `fx-dev:rabbit-feedback-resolver` |
| Codecov | `codecov[bot]` / `codecov-commenter` | `fx-dev:resolve-codecov-feedback` |

## WHEN TO USE THIS SKILL

- User says "resolve PR feedback" / "check PR comments" / "address review comments"
- User wants to handle all automated review feedback on a PR
- After PR creation, to ensure all automated reviewers are addressed
- As part of the SDLC workflow before finalizing a PR

## Parallel resolvers MUST NOT write `REVIEW.md` concurrently

`fx-dev:review` Step 6 states the rule; this is the coordinator's half of it.
Re-reading before writing is **not** locking — two sub-agents can read the same
revision and the second write silently discards the first's rule.

When dispatching resolvers in parallel (Step 4):

1. Instruct each sub-agent to **collect** its proposed `REVIEW.md` rules and
   return them in its final report **instead of editing the file**. Everything
   else — code fixes, thread replies, thread resolution — proceeds in parallel;
   those touch disjoint resources.
2. After **all** parallel resolvers return, apply the collected rules in a single
   serialized edit, then commit and push.
3. Verify by diffing, not by counting the whole file — an established `REVIEW.md`
   already contains unrelated rules, so a total-count check always fails:

   ```bash
   git diff -- REVIEW.md
   ```

   Every proposed rule must appear as an added line, and pre-existing rules must
   be untouched.

When resolvers run **sequentially** (one reviewer only, or Mode B), each edits
`REVIEW.md` directly as its own skill describes — no aggregation needed.

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

**Fetch `path`, `line`, and `body`, not just the author.** Step 4 requires a
disposition per thread, and a disposition cannot be derived from an ID and a
login: the filters need to see what the thread actually says and where. A query
that returns only `id`/`isResolved`/`author` forces the dispatch step to hand out
dispositions it has not reasoned about, or to omit them — which is the bare
invocation Step 4 forbids.

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

**Triage BEFORE dispatching, and pass the result.** A resolver invoked with a bare
skill name has neither the Scope Brief nor your per-finding dispositions, so it
re-derives both — and a correct-but-immaterial thread comes back as an edit,
which is the push that reopens the loop. Every invocation below MUST carry, as
its argument:

1. The **Scope Brief**, verbatim (`fx-dev/skills/dev/references/scope-contract.md` § The Scope Brief).
2. A **disposition for every thread that carries a finding** — `blocking`,
   `immaterial`, or `deferred`, as defined in
   `fx-dev/skills/dev/references/scope-contract.md` § Resolver dispositions.
   Yours is authoritative: it is set with the Scope Brief and the ledger in hand,
   which the resolver does not have. **Verify the premise before disposing of
   it** — a thread describing code that no longer exists, or misreading a
   deliberate convention, is a false positive rather than a finding. List it as
   undisposed with the reason, and let the resolver's outdated/incorrect handler
   take it; forcing a disposition onto one overrides that handler and loses the
   `REVIEW.md` entry that stops the finding recurring.

**If Copilot threads exist:**
```
Skill tool: skill="fx-dev:copilot-feedback-resolver",
            args="<Scope Brief verbatim> — dispositions: <thread id> blocking, <thread id> immaterial, <thread id> deferred (<exclusion>) — false premise (resolver's own handler): <thread id> (<what does not hold>)"
```

**If CodeRabbit threads exist:**
```
Skill tool: skill="fx-dev:rabbit-feedback-resolver",
            args="<Scope Brief verbatim> — dispositions: <thread id> blocking, <thread id> immaterial, <thread id> deferred (<exclusion>) — false premise (resolver's own handler): <thread id> (<what does not hold>)"
```

**If Codecov coverage gaps detected:**
```
Skill tool: skill="fx-dev:resolve-codecov-feedback",
            args="<Scope Brief verbatim> — uncovered lines in scope: <paths>; deliberately uncovered: <paths and why>"
```

**No bare invocation.** A `Skill tool:` line with no `args` is an incomplete call
here, not a shorthand — the resolver then re-derives triage it cannot see and
edits for findings you classified immaterial or deferred.

**List false positives separately, not as a disposition.** Append
`— false premise (resolver's own handler): <thread id> (<what does not hold>)`
for any thread you verified and rejected. That leaves the resolver's
outdated/incorrect path — reply, resolve, and update `REVIEW.md` where a
convention was misread — reachable, which an authoritative disposition would
close off.

**If multiple exist:** Prefer running Copilot and CodeRabbit resolvers **in parallel** by spawning each as a sub-agent in the same message (see `fx-dev:dev` Step 6.3 for the exact pattern). Codecov is sequential after them since coverage fixes typically require code from the other resolvers to be in place first.

### 5. Verify All Resolved AND Loop Until Convergence

After invoking resolver skills, re-query to confirm all threads are resolved AND that no reviewer has posted new feedback in response to the fixes that were pushed.

**Cycle, don't single-shot.** CodeRabbit re-runs after every push and may post new threads on the new commits. Copilot does **not** — it must be asked again. Either way, a single-pass resolver leaves a stale "settled" state behind. Loop:

1. **If the current head SHA has no Copilot review yet — because a fix was pushed, or because none has covered this head at all — nudge Copilot for it** via `fx-dev:copilot-review` (its Step 1). **Copilot does NOT re-review pushed commits on its own.** Where the last cycle only replied and resolved, the head has not moved and a review of it already exists: skip straight to step 3. Nudging and waiting there buys a full cycle to re-read code nobody changed, which is the same churn as editing for an immaterial finding. Skipping this makes the rest of the loop meaningless: you will poll, see nothing, and "converge" on code no reviewer has read. Issue the nudge and discard its response — it is fire-and-forget, never evidence, and having issued it is never a substitute for step 6's received-review check.
2. Wait for all reviewer checks to reach terminal state (use the dedicated waiters: `fx-dev:copilot-review` for Copilot, `fx-dev:coderabbit-review` for CodeRabbit). **Do not hand-roll a `gh api` / GraphQL polling loop in their place** — a hand-rolled loop only observes, never requests, and will happily accept a review of a superseded commit.
3. Re-run **Step 2's full query** — `id`, `path`, `line` and comment bodies — and re-triage every unresolved thread, including the ones the last cycle's push created. The breakdown query below counts threads by reviewer; it cannot feed step 4, which refuses a resolver invocation without a disposition per thread, and a disposition cannot be assigned to a name and a number. Every iteration repeats the fetch and the triage, not just the first.
4. If the breakdown array is non-empty, re-invoke the relevant resolver(s) with the dispositions from step 3.
5. **If fixes were pushed**, restart at step 1 — the push created unreviewed commits. If this cycle produced no push, do not restart: go to step 6 and judge convergence on the review already delivered for this head.
6. Stop when the loop has **converged** per `fx-dev:review` Step 7 — no blocking
   finding left unresolved, ledger-wide — **and** three PR-level conditions hold
   that the ledger test alone does not cover:
   - the state holds on a head SHA that was **actually reviewed** (verify: the
     newest Copilot review's `commit_id` equals `headRefOid`);
   - **every automated thread on that head is resolved**;
   - **the suppressed-comments block for that head is empty or fully triaged**
     (see §3 *Identify Unresolved Feedback by Source*, not this loop's step 3 —
     those findings create no thread, so a zero-thread count says nothing about
     them).

   Immaterial findings resolved by reply satisfy all of this: they produce no
   push, so they are not "new feedback" owing another cycle. The bound and the
   escalation triggers are `fx-dev:review` Step 7 and are not restated here.

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
3. The wait-and-resolve loop has CONVERGED — a Copilot review has been **RECEIVED for the current head SHA**, left **no blocking finding unresolved** — including any carried from an earlier pass and any suppressed item, which creates no thread and so is never discharged by a thread count — and every automated thread on that head is resolved. Immaterial findings resolved by reply do not block this. Do not add "and was requested", which is not a determinable fact (**D1**). A quiet poll on an unreviewed head is not convergence
4. CodeRabbit's check is in a terminal passing state (or absent if not configured)
5. Final verification confirms all threads resolved
6. Summary output provided

## Error Handling

- If no PR found: Ask user for PR number
- If resolver skill fails: Report which reviewer's feedback remains unresolved
- If API errors: Retry with proper auth context
