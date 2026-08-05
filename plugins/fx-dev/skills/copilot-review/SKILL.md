---
name: copilot-review
description: "Request, wait for, and resolve GitHub Copilot's PR review. Use after creating a PR, and AGAIN after every push to the PR branch — Copilot does NOT re-review new commits on its own. Handles the full lifecycle: request review for the current head commit, poll until received, then resolve all feedback. MUST be used before merging any PR."
---

# Copilot Review

Request, wait for, and resolve GitHub Copilot's PR review on a pull request.

## ⛔ Copilot Is Mandatory — and MUST Be Requested

**A Copilot review must be REQUESTED. Do not assume one will appear.** Some repos have a ruleset that auto-requests a review when a PR opens, which makes the first review look automatic — but that is a per-repo setting you cannot count on, and it is **not** the same as re-reviewing later pushes.

**CRITICAL: Copilot does NOT re-review a PR when you push new commits** (unless the repo's ruleset enables "review new pushes"). After pushing fixes you MUST request a new review — go back to Step 1. Waiting without requesting will observe nothing, forever.

- **A review of an earlier commit is NOT coverage for the current one.** Requesting is per-head-SHA. `wait-for-copilot-review.sh` enforces this: it matches reviews by `commit_id` against the PR head and exits 2 when the newest review is for an older commit.
- **"No new feedback appeared" is NOT evidence that code is clean** unless a review was requested for that exact head SHA and received. Absence of a review you never asked for proves nothing. This is the single most common way this gate gets falsely reported as passed.
- Copilot review is **completely independent of CI**. They are separate systems. CI passing has NOTHING to do with Copilot.
- You MUST NOT merge ANY PR until Copilot has reviewed **the commit you intend to merge** and all feedback is resolved.
- No exceptions — not for "first PRs", not for "small PRs", not because "CI isn't set up yet", not because "nothing is configured yet".
- **NEVER hand-roll `gh api repos/.../reviews` or a GraphQL polling loop to check Copilot status.** Use the script provided by this skill. A hand-rolled loop can only *observe*; it never *requests*, and it will not notice that the review it found belongs to a superseded commit.

## MANDATORY: Triage Against the Scope Brief

Copilot accepts no prompt, so scope cannot be injected into its review — it will
report work that was deliberately not done. Apply the **Scope Brief** (canonical
definition: `fx-dev/skills/dev/references/scope-contract.md`) at **triage**
instead, and establish one from the conversation and PR description if you were
not handed it.

- A finding covered by the brief's out-of-scope list is **resolved as deferred
  with the exclusion that covers it** — recorded, not silently fixed and not
  silently dropped.
- **The brief never suppresses a real finding.** It excludes work deliberately
  not done; it does not excuse defects in the work that *was* done. Security,
  data-loss, and correctness problems inside the change are always actionable and
  always block the merge gate.
- Copilot being unable to see the scope is not a reason to widen the change.
  Implementing its out-of-scope suggestions is scope creep with a reviewer's name
  on it.

## When to Use

- After creating a PR (SDLC Step 6.3)
- **After every push to the PR branch** — including pushes that only fix review feedback. This is not optional and it is the step most often skipped.
- Before merging any PR (team coordinator merge gate), against the head commit being merged
- When user says "check copilot", "wait for copilot", "copilot review"

## Parallel With Other Reviewers

This skill can run **in parallel** with `fx-dev:coderabbit-review` and any future automated-reviewer skills.

**Pick the execution mode based on your context (see `fx-dev:dev` Step 6.3 for the full table):**

- **Root session / standalone caller** → spawn one sub-agent per reviewer in a single message via the Agent tool (mode A). Best wall-clock latency.
- **`fx-dev:team` coordinator OR a sub-agent yourself** → sub-agents CANNOT spawn sub-agents. Run each reviewer's lifecycle sequentially yourself, optionally with the slow waiter (CodeRabbit) launched as a background `Bash` process while you handle Copilot in the foreground (mode B).

Don't serialize reviewers when you don't have to — Copilot is fast (≈30–90 s) and CodeRabbit is slow (2–10+ min and re-runs on every push). But never spawn sub-agents from a sub-agent context.

## Arguments

This skill expects a PR number. Pass it as args: `skill='fx-dev:copilot-review', args='<PR_NUMBER>'`

## Workflow

### Step 1: Request Copilot Review

```bash
# Get repo info
REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

# Request Copilot review using JSON body format (most reliable)
gh api --method POST "/repos/${REPO_NWO}/pulls/<PR_NUMBER>/requested_reviewers" \
  --input - <<'EOF'
{"reviewers":["copilot-pull-request-reviewer[bot]"]}
EOF
```

If the request fails with a 422 (already reviewed or already requested), that's fine — proceed to Step 2.

### Step 2: Wait for Review

Run the bundled script **in the FOREGROUND** with `timeout: 660000` (11 minutes) on the Bash tool call:

```bash
bash [SKILL_BASE_DIR]/skills/copilot-review/scripts/wait-for-copilot-review.sh <PR_NUMBER>
```

**⚠️ CRITICAL: Run in FOREGROUND — do NOT use `run_in_background`.** The output must be directly available to determine the result.

Script exit codes:
- **Exit 0**: Review received **for the current head commit** → proceed to Step 3
- **Exit 1**: Timeout after 15 minutes → STOP. Report to user: "Copilot review timed out on PR #N. Cannot merge without it."
- **Exit 2**: No review requested for the current head commit → go back to Step 1 to request, then re-run this script. **This includes the case where Copilot already reviewed an earlier commit**; the script says which one. Do not read that as "already reviewed".
- **Exit 3**: Invalid arguments or gh error → report error to user

### Step 2b: Read the Review BODY, Not Just the Thread Count

**Copilot hides some findings in a `<details><summary>Suppressed comments</summary>` block in the review body. Those are real findings and they produce NO review thread.** A review can say "generated no new comments", report zero unresolved threads, and still contain substantive bugs in that block — observed: an array-vs-object validation hole and a topological-ordering defect, both genuine, neither visible to a thread query.

So a thread count of 0 is **not** a clean review. Always read the body:

```bash
gh api "/repos/${REPO_NWO}/pulls/<PR_NUMBER>/reviews" \
  --jq '[.[] | select(.user.login | startswith("copilot-pull-request-reviewer"))] | last | .body'
```

Triage suppressed comments exactly like thread comments — fix what is valid, and say in the PR why anything was rejected. They cannot be "resolved" (there is no thread), so the commit message or PR body is the only place that record can live.

### Step 3: Resolve Feedback

After the review is received, invoke the resolve-pr-feedback skill to process all automated review threads (Copilot, CodeRabbit, Codecov):

```
Skill tool: skill="fx-dev:resolve-pr-feedback", args="<PR_NUMBER>"
```

This skill will:
1. Find all unresolved Copilot threads
2. Categorize each (nitpick, valid, incorrect, outdated, deferred)
3. Fix valid concerns, reply to and resolve all threads
4. Report a summary table of actions taken

### Step 4: Confirm Resolution

After resolve-pr-feedback completes, verify zero unresolved threads remain:

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
}" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)] | length'
```

If the count is 0, Copilot gate is PASSED **for the commit that was reviewed**. If > 0, re-invoke resolve-pr-feedback.

### Step 5: If Fixes Were Pushed, Start Over

Resolving feedback usually means pushing commits. Those commits are **unreviewed**, and Copilot will not look at them by itself.

If the head SHA changed since the review in Step 2, go back to **Step 1** — request a review for the new head, wait, resolve. Repeat until a pass produces zero new threads *on a reviewed head*. Cap at 4 iterations and escalate to the user if it has not settled.

```bash
# The gate is only passed when this review covers the current head.
gh pr view <PR_NUMBER> --json headRefOid --jq '.headRefOid'
gh api "/repos/${REPO_NWO}/pulls/<PR_NUMBER>/reviews" \
  --jq '[.[] | select(.user.login | startswith("copilot-pull-request-reviewer")) | .commit_id] | last'
```

## Success Criteria

This skill is complete when ALL of:
- ✅ Copilot review has been received (script exited 0) **for the current head commit** — not for an earlier one
- ✅ All Copilot threads resolved (0 unresolved)
- ✅ Any valid code concerns have been fixed and pushed — **and the resulting head was itself reviewed**

**Never report this gate as passed on the grounds that polling found no new feedback, if no review was requested for the current head.** That is an unasked question, not an answer.
