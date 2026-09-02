---
name: copilot-review
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Requests, waits for, inspects, and settles a head-scoped GitHub Copilot review."
---

# Copilot Review

**⛔ Load `fx-dev:review` first** (Skill tool: `skill="fx-dev:review"`). It is the
canonical review procedure — carrying the Scope Brief, triaging in filter order,
sweeping a class, converging, reporting. This skill is the **Copilot adapter**:
requesting a review, waiting for one that covers the right commit, and the API
behaviour that makes both harder than they look. Where the two appear to
disagree, `fx-dev:review` wins.

Request, wait for, and resolve GitHub Copilot's PR review on a pull request.

## ⛔ Copilot Is Mandatory — and MUST Be Requested

**A Copilot review must be REQUESTED. Do not assume one will appear.** Some repos have a ruleset that auto-requests a review when a PR opens, which makes the first review look automatic — but that is a per-repo setting you cannot count on, and it is **not** the same as re-reviewing later pushes.

**CRITICAL: Copilot does NOT reliably re-review a PR when you push new commits.** Some repos' rulesets enable "review new pushes" and it fires on some pushes and not others. After pushing fixes you MUST run this skill again for the new head SHA — the waiter re-issues the request and, crucially, re-scopes the wait to the new commit.

- **A review of an earlier commit is NOT coverage for the current one.** Coverage is per-head-SHA. `wait-for-copilot-review.sh` enforces this: it only accepts a review whose `commit_id` equals the PR's current `headRefOid`, and it keeps waiting (then reports `STATUS=PENDING`) when the newest review is for an older commit.
- **"No new feedback appeared" is NOT evidence that code is clean.** Only a *received* review whose `commit_id` equals the head SHA is evidence. Note the converse trap too: because the request API is inert (**D1**), you can never confirm a review "was requested" — so *never* gate your conclusion on that question, and never conclude "not requested, therefore nothing to wait for". Wait for the review itself. This is the single most common way this gate gets falsely reported as passed.
- Copilot review is **completely independent of CI**. They are separate systems. CI passing has NOTHING to do with Copilot.
- You MUST NOT merge ANY PR until Copilot has reviewed **the commit you intend to merge** and all feedback is resolved.
- No exceptions — not for "first PRs", not for "small PRs", not because "CI isn't set up yet", not because "nothing is configured yet".
- **NEVER hand-roll `gh api repos/.../reviews` or a GraphQL polling loop to check Copilot status.** Use the script provided by this skill. Hand-rolled loops reliably get two things wrong: they accept a review belonging to a superseded commit, and they re-derive the broken `requested_reviewers` readiness check (**D1/D3**).

## Reading Copilot's Verdict

Every Copilot review opens with a **verdict headline**. It is the first thing to
read, and it decides whether there is any work to do at all:

| Headline | Meaning for this gate |
|---|---|
| **Approval recommended** | **PASS** — provided there are no non-suppressed comments |
| **Needs a closer look** | **PASS** — provided there are no non-suppressed comments. It is a request for human attention on a large or subtle change, not a finding. Do not treat it as one, do not manufacture work to answer it, and do not loop |
| **Changes recommended** | **Handle normally** — triage its comments per `fx-dev:review`, fix what blocks, reply-and-resolve the rest |

"Non-suppressed comments" means review threads Copilot actually opened. Those are
the findings. A verdict headline on its own is never a finding.

**Suppressed comments are ignored by default.** A review body may carry a
`<details><summary>Suppressed comments (N)</summary>` block. Copilot suppressed
those itself; they open no review thread, and they are overwhelmingly wording,
casing, and comment-phrasing nits whose cost to chase exceeds their value —
every one you act on spends a full re-review cycle (see **Every push re-opens the
gate** below). Do **not** read the block as a matter of routine, do not triage it
item by item, and never treat its presence as blocking.

The one exception is genuinely narrow: if a suppressed item happens to catch your
eye and it is **absolutely dire** — a real defect that would cause data loss, a
security hole, or a plainly wrong result in shipped code — act on it as you would
any blocking finding, and record the outcome in the commit message or PR body
(there is no thread to reply to). "Dire" means the change is wrong without it, not
that the observation is correct. Correctness is not the bar here; suppressed items
are frequently correct and still not worth a cycle. And do not apply a suppressed
suggestion on sight even then: one observed suppressed comment, applied exactly as
written, would have introduced the very bug it claimed to report. Verify against
the code first.

## Known GitHub API Behaviour — Do Not Rediscover This

These are empirically confirmed against real pull requests. They are the reason
the workflow below looks the way it does. Do not "improve" the workflow back into
depending on any of them.

**D1 — the review request is inert as an evidence source.**
`POST /repos/{owner}/{repo}/pulls/{n}/requested_reviewers` with the Copilot bot
returns **200 with `requested_reviewers: []`** — observed 7 times out of 7, plus
again on every later run. A follow-up `GET` is empty too. Sometimes the timeline
*does* record a `review_requested` event and a review arrives minutes later, so
the POST is worth issuing — but **its response and `requested_reviewers` are never
evidence of anything.** An empty `requested_reviewers` does not mean the request
failed, and a 200 does not mean it succeeded.

**D2 — there is no GraphQL fallback.** `requestReviews` rejects the bot outright:

```
Could not resolve to User node with the global id of 'BOT_kgDOCnlnWA'
```

`userIds` does not accept Bot nodes. Do not add a GraphQL "fallback" for
requesting a Copilot review; none exists.

**D3 — readiness must never be keyed on `requested_reviewers`.** An earlier
version of the waiter gated its poll on that field, so it reported
"No Copilot review requested" against reviews that were genuinely delivered — on
one PR it would have said so at every point in a 12 m 42 s window **including
after the review landed**. And because the request itself is a no-op (D1), the
old recovery advice ("go back to Step 1, request, re-run") looped forever on any
repo without an auto-request ruleset.

**The only sound readiness signal:** poll
`GET /repos/{owner}/{repo}/pulls/{n}/reviews` for a review whose `commit_id`
equals the PR's current `headRefOid`. Nothing needs to be "requested" for that to
become true. Observed arrival times range from **85 seconds to 12 m 42 s**, and
the auto-request ruleset fires on some pushes and not others — so waiting quietly
for several minutes is normal, and silence is never a verdict.

**D4 — a suppressed-comments block is informational, not a gate.** Copilot review
bodies can say *"generated no new comments"* while carrying a
`<details><summary>Suppressed comments (N)</summary>` block. Those items create
**no review thread at all**, and Copilot itself judged them not worth raising as
one. The waiter still reports whether a block is present, because knowing is free
— but the flag is context, not a verdict, and it never holds the gate open. See
**Reading Copilot's Verdict** above for the default (ignore) and the narrow
absolutely-dire exception.

**D5 — a failed body fetch is not a clean body.** The waiter's body fetch used to
end in `|| true`, so a transient `gh api` error produced an empty string, the
`Suppressed comments` grep matched nothing, and the script reported
`SUPPRESSED_COMMENTS=0` with *"(review has an empty body)"* — reporting a result
for a check that never ran. It now distinguishes three states: `1` = block
present, `0` = fetch succeeded and no block, `unknown` = fetch failed. The
distinction comes from `gh`'s **exit status**, never from whether the output is
empty, because a Copilot review with a genuinely empty body is legal and observed
— "empty" and "never fetched" are different facts that look identical on stdout.
None of the three blocks the gate; `unknown` simply means the script could not
tell you, which is worth knowing whenever you read output rather than guessing at
it.

## Triage: the brief cannot reach Copilot

Copilot accepts no prompt, so scope cannot be injected into its review — it will
report work that was deliberately not done. Apply the Scope Brief entirely at
**triage** (`fx-dev:review` Steps 1–2), and reconstruct one if you were not handed
it. Copilot's `[nitpick]` prefix is an input to that judgment, never a verdict.

**Two things bite harder here than with any other reviewer:**

**Every push re-opens the gate.** Copilot must then re-review the new head
(Step 5), so editing for an immaterial finding costs a full wait cycle *and*
produces a fresh commit for it to comment on. Push fixes for blocking findings;
reply-and-resolve the rest without a commit. The one exception is the `REVIEW.md`
entry for a misread convention (`fx-dev:review` Step 6) — required work, and its
commit is expected.

**A half-closed class costs a wait cycle per sibling.** The class sweep in
`fx-dev:review` Step 4 pays for itself more here than anywhere else: closing a
class halfway spends a full Copilot wait to be told about the other half.

## When to Use

- After creating a PR (SDLC Step 6.1)
- **After every push to the PR branch** — including pushes that only fix review feedback. This is not optional and it is the step most often skipped.
- Before merging any PR (team coordinator merge gate), against the head commit being merged
- When user says "check copilot", "wait for copilot", "copilot review"

## Parallel With Other Reviewers

This skill can run **in parallel** with `fx-dev:coderabbit-review`, the only other PR-level reviewer fx-dev requests.

**There is no mode selection.** Every waiter is backgrounded, so reviewers run
concurrently in every context — root session, `fx-dev:team` coordinator, or
sub-agent alike. Launch each reviewer's waiter in the same message and handle
whichever completion notification arrives first. No sub-agents are involved, so the
old "can I spawn?" branch no longer applies.

Do not budget for Copilot being quick. Observed delivery ranges from **85 s to
12 m 42 s** (D3), which is why the wait budget is a single 900 s run; CodeRabbit is
2–10+ min and re-runs on every push. Both are slow enough that concurrency pays.

## Arguments

This skill expects a PR number **and the Scope Brief**: `skill='fx-dev:copilot-review', args='<PR_NUMBER> — <Scope Brief verbatim>'`. Copilot cannot be handed the brief itself, but this skill triages its output and dispatches a resolver, and both need it (`fx-dev:review` Step 1). A bare PR number makes the whole chain re-derive the exclusions from the PR description.

## Workflow

### Step 1: Request Copilot Review (fire-and-forget)

The waiter issues this request itself, so you normally do **not** need to run it by
hand. If you do run it standalone:

```bash
# Get repo info
REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

# Nudge Copilot. Per D1 the response is NOT evidence — discard it.
gh api --method POST "/repos/${REPO_NWO}/pulls/<PR_NUMBER>/requested_reviewers" \
  --input - <<'EOF'
{"reviewers":["copilot-pull-request-reviewer[bot]"]}
EOF
```

**Do not interpret the response.** Per **D1** it comes back 200 with
`requested_reviewers: []` regardless, a 422 is equally uninformative, and there is
no GraphQL alternative (**D2**). Issue it, ignore it, move to Step 2. Never treat
an empty `requested_reviewers` as "the request did not land", and never treat a
200 as "a review is now guaranteed".

### Step 2: Wait for a Review of the Current Head

**⛔ Run the waiter in the BACKGROUND** (`run_in_background: true`), redirecting
stdout and stderr to a log file, then read that file when the completion
notification arrives:

```bash
mkdir -p .claude/team/waits && \
bash [SKILL_BASE_DIR]/skills/copilot-review/scripts/wait-for-copilot-review.sh <PR_NUMBER> \
  > .claude/team/waits/copilot-<PR_NUMBER>.log 2>&1
```

**Do NOT run it in the foreground.** The Bash tool caps a foreground `timeout` at
600 000 ms, which is below the script's 900 s budget — a foreground call is
guaranteed to be killed mid-poll, printing no STATUS and no exit code. That kill is
what previously made the re-run protocol unreachable and forced blind retries.
Backgrounded processes are not subject to the cap, which is why the budget can now
cover the worst observed delivery time (12 m 42 s) in **one run**.

### Read the `STATUS=` line

The script's last stdout line is `STATUS=<state>`; the exit code mirrors it. Branch
on STATUS, not on prose.

| STATUS | Exit | What to do |
|---|---|---|
| `TERMINAL_PASS` | 0 | A review covers the current head and no Copilot thread is open → **Step 2b**, then Step 4 to confirm. |
| `TERMINAL_FAIL` | 1 | A review covers the current head and threads remain open (or the count could not be read) → **Step 2b**, then Step 3. Settled — do not re-run for a better answer. |
| `PENDING` | 2 | No review of the current head arrived within 900 s. **Not a failure and not a clean result.** Re-running is safe. If it still has not arrived, STOP and report: "Copilot review has not arrived for PR #N head `<sha>`. Cannot merge without it." **Never** record this as "no findings". |
| `NOT_CONFIGURED` | 3 | **Never returned by this script.** Whether Copilot is "configured" has no answerable form — `requested_reviewers` does not work at all (**D1/D3**). Do not branch on it, and do not reinstate any "request again, then re-run" recovery keyed to it. |
| `ERROR` | 4 | Bad arguments, `gh` too old, PR head unresolvable → report to the user. The wait never started. |

On a settled review the script also prints machine-readable lines; read them rather
than branching on STATUS alone:

- `REVIEWED_COMMIT_ID=<sha>` and `PR_HEAD_SHA=<sha>` — **verify they match yourself**. This is the one line that genuinely gates: a review of a superseded commit is not coverage.
- `UNRESOLVED_THREADS=<n|unknown>` — `unknown` means the read **failed**, not that there are none. The script fails closed on it and reports `TERMINAL_FAIL`; verify the threads yourself.
- `SUPPRESSED_COMMENTS=1|0|unknown` — **informational only** (**D4**). `1` means a block is present, `0` means the fetch succeeded and found none, `unknown` means the fetch failed so the script cannot say. None of the three blocks the gate. Do not open the block as a matter of routine, and do not re-run the waiter merely to turn `unknown` into a number.
- The review body is printed too. **Read its verdict headline** and note whether Copilot opened any threads — that pair is what decides the outcome (see **Reading Copilot's Verdict**). STATUS reflects the mechanical thread gate only.

### Step 2b: Read the Verdict, Not the Suppressed Block

The waiter prints every review body for the reviewed commit. Read the **verdict
headline** and check whether Copilot opened any review threads:

- **Approval recommended** or **Needs a closer look**, with no threads → the gate
  is passed. Go to Step 4 and confirm the thread count is zero. There is nothing
  to fix and nothing to reply to.
- **Changes recommended**, or any headline accompanied by threads → go to Step 3
  and handle the threads normally.

**Do not open the suppressed-comments block as a matter of routine** (**D4**).
`SUPPRESSED_COMMENTS=1` is context, not an instruction; it holds nothing open. Act
only on the absolutely-dire exception described in **Reading Copilot's Verdict**,
and only when such an item has already caught your attention — going looking for
one defeats the purpose of skipping the block.

If you do need the bodies directly — scoped to the reviewed head so you do not
read a stale review's body, and across **every** review of that commit:

```bash
REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
HEAD_SHA=$(gh pr view <PR_NUMBER> --json headRefOid --jq '.headRefOid')

gh api "/repos/${REPO_NWO}/pulls/<PR_NUMBER>/reviews" \
  --jq "[.[] | select(.user.login | startswith(\"copilot-pull-request-reviewer\")) | select(.commit_id == \"${HEAD_SHA}\") | .body] | join(\"\n\n----- (next review of this commit) -----\n\n\")"
```

**Do not narrow that to `| last`.** Two Copilot reviews of a single commit are
routine — the waiter nudges on every head move and this skill re-runs it up to 3
times — and the newest is not necessarily the one carrying the verdict you are
reading. Take all bodies for the commit.

### Step 3: Resolve Feedback

After the review is received, invoke the resolve-pr-feedback skill to process the automated review threads it categorises (Copilot, CodeRabbit, Codecov):

```
Skill tool: skill="fx-dev:resolve-pr-feedback",
            args="<PR_NUMBER> — <Scope Brief verbatim> — dispositions already assigned: <suppressed item or thread id> blocking | immaterial | deferred (<exclusion>) — false premise (resolver's own handler): <item or thread id> (<what does not hold>)"
```

**Never invoke it with only the PR number.** The Scope Brief must travel into
every downstream review call (`fx-dev/skills/dev/references/scope-contract.md`
§ Injecting the brief into reviews), and a resolver handed a bare number
re-derives triage from the PR description — losing the exact exclusions and
known-and-accepted decisions, and editing for threads you classified immaterial
or deferred.

Pass dispositions only for what you have actually triaged — usually nothing at
this point, since this skill never fetches the thread list, and suppressed items
are ignored by default (**D4**). The `dispositions already assigned:` clause is
there for the rare case where an absolutely-dire suppressed item was acted on.
`fx-dev:resolve-pr-feedback` fetches the threads and triages the rest (its
Steps 2 → 4). **Do not invent a disposition for a thread you have not read**; an
absent one is filled in downstream, a wrong one is authoritative and overrides
the resolver's own reading.

This skill will:
1. Find all unresolved Copilot threads
2. Categorize each (nitpick, valid, incorrect, outdated, deferred)
3. Fix **blocking** findings; reply-and-resolve every other thread without editing
4. Report a summary table of actions taken

### Step 4: Confirm Resolution

After resolve-pr-feedback completes, verify zero unresolved **Copilot** threads
remain. The filter on the Copilot login is required, not cosmetic: this gate is
scoped to Copilot, and `fx-dev:github` forbids touching human review threads at all
— so counting every unresolved thread makes one open human comment permanently
unsatisfiable and loops `resolve-pr-feedback` forever:

```bash
OWNER="${REPO_NWO%%/*}"
REPO="${REPO_NWO##*/}"
gh api graphql -f query="
query {
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    pullRequest(number: <PR_NUMBER>) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 1) {
            nodes { author { login } }
          }
        }
      }
    }
  }
}" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .comments.nodes[0].author.login == "copilot-pull-request-reviewer")] | length'
```

The gate is passed when **both** hold:

1. A Copilot review exists whose `commit_id` equals the PR's current `headRefOid`.
2. Zero unresolved Copilot threads remain.

A zero thread count on its own is not enough — condition (1) is what makes it mean
anything, because zero threads on a superseded commit says nothing about the code
being merged. If the count is > 0, re-invoke resolve-pr-feedback. The verdict
headline does not add a third condition: **Needs a closer look** with zero threads
passes exactly as **Approval recommended** with zero threads does.

### Step 5: If Fixes Were Pushed, Start Over

Resolving feedback usually means pushing commits. Those commits are **unreviewed**, and Copilot will not look at them by itself.

**If the head SHA changed** since the review in Step 2, go back to **Step 1** —
nudge, wait (Step 2), read the verdict (Step 2b), resolve. The loop, its bound and
its escalation triggers are `fx-dev:review` Step 7; every iteration here costs a
full Copilot wait cycle, so fix causes rather than instances.

**If it did not change, do not restart.** Resolving an immaterial thread by reply
creates no commit, so the head has not moved and a review of it already exists —
nudging again spends a wait cycle to re-read code nobody changed. **Only a push
restarts this loop**, which is why only blocking findings should produce one.

Convergence here adds one Copilot-specific condition to the ledger test: every
thread resolved **on a reviewed head**. A verdict of **Needs a closer look** does
not extend the loop, and neither does a suppressed block — treating either as
unfinished business is how this gate turns into an endless cycle over wording nits
that Copilot had already declined to raise as threads.

```bash
# The gate is only passed when the newest Copilot review covers the current head.
HEAD_SHA=$(gh pr view <PR_NUMBER> --json headRefOid --jq '.headRefOid')
REVIEWED=$(gh api "/repos/${REPO_NWO}/pulls/<PR_NUMBER>/reviews" \
  --jq '[.[] | select(.user.login | startswith("copilot-pull-request-reviewer")) | .commit_id] | last // empty')
[[ -n "$REVIEWED" && "$REVIEWED" == "$HEAD_SHA" ]] \
  && echo "covered: $HEAD_SHA" \
  || echo "NOT covered — head=$HEAD_SHA reviewed=${REVIEWED:-none}"
```

## Success Criteria

This skill is complete when ALL of:
- ✅ Copilot review has been received (script exited 0) **for the current head commit** — `REVIEWED_COMMIT_ID` equals `PR_HEAD_SHA`, checked by you, not for an earlier commit
- ✅ Its verdict headline was read: **Approval recommended** and **Needs a closer look** both pass with no open threads; **Changes recommended** was worked through
- ✅ All Copilot threads resolved (0 unresolved, **filtered to the Copilot login**)
- ✅ Any **blocking** findings have been fixed and pushed — **and the resulting head was itself reviewed**. Correct-but-immaterial observations are resolved by reply and produce no push, so they owe no further pass

A suppressed-comments block does **not** appear in that list, in any state
(**D4**). It is not a criterion, and neither `SUPPRESSED_COMMENTS=1` nor `unknown`
withholds the gate.

**Never report this gate as passed on the grounds that polling found no new feedback.** Absence of a review is not a clean review, and `STATUS=PENDING` is not a verdict. Silence here is an unasked question, not an answer.

**Never report this gate as passed on a zero thread count alone.** Zero threads on
a commit that is not the head says nothing about the code being merged — the
head-SHA match is what makes the count mean anything.
