#!/usr/bin/env bash
# wait-for-copilot-review.sh
# Waits until GitHub Copilot has submitted a review of the PR's CURRENT head commit.
#
# Usage: ./wait-for-copilot-review.sh <PR_NUMBER> [TIMEOUT_SECONDS]
# Default timeout: 900 seconds (15 minutes)
# Env: COPILOT_WAIT_DEBUG=1  echo the raw review-request POST response
#
# Exit codes:
#   0 - SUCCESS. A Copilot review exists whose `commit_id` equals the PR's current
#       head SHA. stdout carries machine-readable
#           REVIEWED_COMMIT_ID=<sha>
#           PR_HEAD_SHA=<sha>
#       so the caller can re-verify the match itself rather than trusting this
#       script's word for it.
#   1 - TIMEOUT. No review covering the current head arrived within TIMEOUT
#       seconds. This is NOT a failure and NOT evidence that anything is wrong:
#       observed delivery times range from 85 s to 12 m 42 s, and the repo ruleset
#       that auto-requests a review fires on some pushes and not others. The
#       correct response is to re-run and keep waiting, or to report the wait as
#       unfinished. It is never grounds to conclude the code is clean.
#   2 - RETIRED. Never returned. It used to mean "no Copilot review requested",
#       derived from `requested_reviewers` — a signal that does not work at all
#       (see D1/D3 below). Callers MUST NOT branch on it, and MUST NOT keep any
#       "request again, then re-run" recovery that was keyed to it.
#   3 - ENVIRONMENT/USAGE ERROR. Bad arguments, `gh` too old, repo or PR head
#       unresolvable. A real failure: the wait never started.
#
# ─────────────────────────────────────────────────────────────────────────────
# KNOWN GITHUB API BEHAVIOUR (empirically confirmed — do not "fix" these back)
#
# D1. The review request is inert as an evidence source.
#     POST /repos/{owner}/{repo}/pulls/{n}/requested_reviewers with the Copilot
#     bot returns 200 with `requested_reviewers: []` — observed 7 times out of 7.
#     A follow-up GET is empty too. The POST is still worth issuing, because the
#     timeline sometimes does record a `review_requested` event and a review
#     arrives minutes later — but its response and `requested_reviewers` are
#     NEVER evidence of anything. Nothing below branches on them.
#
# D2. The GraphQL fallback cannot work. `requestReviews` rejects the bot outright:
#       Could not resolve to User node with the global id of 'BOT_kgDOCnlnWA'
#     `userIds` does not accept Bot nodes. There is no GraphQL path for requesting
#     a Copilot review; do not add one back as a "fallback".
#
# D3. Readiness must NOT be keyed on `requested_reviewers`. A previous version of
#     this script gated the poll on it and therefore returned exit 2 ("no Copilot
#     review requested") against reviews that were genuinely delivered — on one
#     PR it would have done so at every point in a 12 m 42 s window INCLUDING
#     after the review landed. On a repo with no auto-request ruleset the
#     documented recovery ("go request one, then re-run") looped forever, because
#     the request itself is a no-op (D1).
#
#     THE ONLY SOUND READINESS SIGNAL, and the one used below: poll
#     GET /repos/{owner}/{repo}/pulls/{n}/reviews for a review whose `commit_id`
#     equals the PR's current `headRefOid`. Nothing has to be "requested" for that
#     to be true, and nothing being there yet does not mean nothing was requested.
#
# D4. A zero unresolved-thread count is NOT a clean review. Copilot review bodies
#     can say "generated no new comments" while carrying a
#       <details><summary>Suppressed comments (N)</summary>
#     block holding real, valid findings that create NO review thread at all.
#     Confirmed 3 times, each time with a genuine finding — one of which, applied
#     as Copilot suggested, would have introduced the very bug it claimed to
#     report. This script prints the review body and flags that block; the CALLER
#     must read and triage it. "0 unresolved threads" alone never passes the gate.
#
# HEAD-SHA AWARENESS (do not remove):
#     Copilot does NOT re-review automatically when new commits are pushed unless
#     the repo ruleset enables "review new pushes". A version of this script that
#     matched *any* Copilot review on the PR exited 0 immediately after a fix was
#     pushed, reporting a review of the PREVIOUS commit as coverage for the new
#     one. Every check below is scoped to the current head SHA, the head is
#     re-read on every poll, and a match is re-confirmed against a fresh head read
#     before success is declared.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

MIN_GH_VERSION="2.50.0"

PR_NUMBER="${1:-}"
TIMEOUT="${2:-900}"
POLL_INTERVAL=15

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: $0 <PR_NUMBER> [TIMEOUT_SECONDS]" >&2
    exit 3
fi

if [[ ! "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: PR_NUMBER must be a positive integer (got: '$PR_NUMBER')" >&2
    exit 3
fi

if [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]]; then
    echo "Error: TIMEOUT_SECONDS must be a non-negative integer (got: '$TIMEOUT')" >&2
    exit 3
fi

# Verify gh version meets minimum requirement (--json flag on pr view requires 2.50+)
gh_version=$(gh --version | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
if ! printf '%s\n' "$MIN_GH_VERSION" "$gh_version" | sort -V | head -1 | grep -q "^${MIN_GH_VERSION}$"; then
    echo "Error: gh CLI version $gh_version is too old. Minimum required: $MIN_GH_VERSION" >&2
    echo "Upgrade with: mise use -g gh@latest" >&2
    exit 3
fi

# Copilot bot identifiers vary by API:
#   REST /reviews:            user.login = "copilot-pull-request-reviewer[bot]"
#   gh pr view --json:        author.login = "copilot-pull-request-reviewer"
#   REST requested_reviewers: login = "Copilot" — but it is always empty (D1),
#                             so this script never reads it.
COPILOT_LOGIN_PREFIX="copilot-pull-request-reviewer"

# Get repo owner/name for REST API calls
REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
if [[ -z "$REPO_NWO" ]]; then
    echo "Error: Could not determine repository" >&2
    exit 3
fi

echo "Checking PR #${PR_NUMBER} for a Copilot review of its current head..."

# The commit a review must cover to count. Re-read on every poll, so a push that
# lands mid-wait moves the target instead of being satisfied by a stale review.
current_head_sha() {
    gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid' 2>/dev/null || true
}

# THE readiness signal (D3). REST /reviews rather than `gh pr view --json reviews`
# because only REST exposes `commit_id` — without it there is no way to tell a
# review of this push from a review of the last one.
check_review_submitted() {
    local sha="$1"
    gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" --jq \
        "[.[] | select(.user.login | startswith(\"${COPILOT_LOGIN_PREFIX}\")) | select(.commit_id == \"${sha}\") | .state] | last // empty" \
        2>/dev/null || true
}

# The body of the newest Copilot review of a specific commit. Needed because the
# findings that matter most may live only in its Suppressed comments block (D4).
review_body() {
    local sha="$1"
    gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" --jq \
        "[.[] | select(.user.login | startswith(\"${COPILOT_LOGIN_PREFIX}\")) | select(.commit_id == \"${sha}\") | .body] | last // empty" \
        2>/dev/null || true
}

# The commit of the newest Copilot review of ANY commit. Diagnostic only — used to
# explain a timeout ("Copilot reviewed this PR, but not this code" reads very
# differently from "Copilot has never looked at this PR"). Never a success signal.
latest_review_commit() {
    gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" --jq \
        "[.[] | select(.user.login | startswith(\"${COPILOT_LOGIN_PREFIX}\")) | .commit_id] | last // empty" \
        2>/dev/null || true
}

# Best-effort nudge. See D1: the response is discarded on purpose. Issued because
# it sometimes unsticks delivery, never consulted to decide anything.
request_review_nudge() {
    local out=""
    out=$(printf '%s' '{"reviewers":["copilot-pull-request-reviewer[bot]"]}' \
        | gh api --method POST "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/requested_reviewers" \
            --input - 2>&1) || true
    if [[ -n "${COPILOT_WAIT_DEBUG:-}" ]]; then
        echo "  [debug] requested_reviewers POST response: ${out}"
    fi
    echo "  Issued a Copilot review request (its response proves nothing — see D1)."
}

# Count unresolved Copilot review threads via GraphQL. Reported for context only:
# a count of 0 does NOT mean the review was clean (D4).
count_copilot_threads() {
    local owner repo result
    owner="${REPO_NWO%%/*}"
    repo="${REPO_NWO##*/}"
    if ! result=$(gh api graphql -f query="
    query {
      repository(owner: \"$owner\", name: \"$repo\") {
        pullRequest(number: $PR_NUMBER) {
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
    }" --jq "[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .comments.nodes[0].author.login == \"${COPILOT_LOGIN_PREFIX}\")] | length" 2>/dev/null); then
        echo "unknown"
        return
    fi
    if [[ "$result" =~ ^[0-9]+$ ]]; then
        echo "$result"
    else
        echo "unknown"
    fi
}

# Declare success. Emits the reviewed commit_id and the head SHA so the caller can
# verify the match without trusting this script.
report_success() {
    local reviewed_sha="$1" state="$2" head_now="$3"
    local body thread_count

    echo ""
    echo "Copilot review received for ${reviewed_sha:0:7} (state: ${state})"
    echo "REVIEWED_COMMIT_ID=${reviewed_sha}"
    echo "PR_HEAD_SHA=${head_now}"

    echo ""
    echo "=== Copilot Review Body ==="
    body=$(review_body "$reviewed_sha")
    if [[ -n "$body" ]]; then
        printf '%s\n' "$body"
    else
        echo "(review has an empty body)"
    fi

    echo ""
    if printf '%s' "$body" | grep -qi 'Suppressed comments'; then
        echo "!! SUPPRESSED COMMENTS PRESENT in the review body above."
        echo "!! Those are real findings and they create NO review thread. You MUST read"
        echo "!! the <details> block in full and triage every item in it. The gate is NOT"
        echo "!! passed until you have (D4)."
    else
        echo "No 'Suppressed comments' block detected in the review body."
        echo "(Still read the body — thread counts alone never establish a clean review.)"
    fi

    thread_count=$(count_copilot_threads)
    echo ""
    echo "Unresolved Copilot threads: ${thread_count} (context only — 0 is NOT 'clean', see D4)"
}

head_sha=$(current_head_sha)
if [[ -z "$head_sha" ]]; then
    echo "Error: Could not determine the head commit of PR #${PR_NUMBER}" >&2
    exit 3
fi
echo "Head commit: ${head_sha:0:7}"

# Immediate check: this commit may already have been reviewed.
submitted=$(check_review_submitted "$head_sha")
if [[ -n "$submitted" ]]; then
    report_success "$head_sha" "$submitted" "$head_sha"
    exit 0
fi

# Not reviewed yet. Nudge, then wait. Note there is deliberately NO "is it
# requested?" gate here: that question has no answerable form (D1/D3), and
# treating it as answerable is what made this script report false negatives.
request_review_nudge
echo "Polling every ${POLL_INTERVAL}s for a review of ${head_sha:0:7} (timeout: ${TIMEOUT}s)..."
echo "Observed Copilot delivery times range from 85s to 12m42s — a quiet first few minutes is normal."

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))

    # Re-read the head: if someone pushed while we waited, the review we are
    # waiting for is the one covering the NEW commit.
    new_head_sha=$(current_head_sha)
    if [[ -n "$new_head_sha" && "$new_head_sha" != "$head_sha" ]]; then
        echo "  Head moved ${head_sha:0:7} -> ${new_head_sha:0:7}; a review must now cover the new commit"
        head_sha="$new_head_sha"
        request_review_nudge
    fi

    submitted=$(check_review_submitted "$head_sha")
    if [[ -n "$submitted" ]]; then
        # Re-confirm against a fresh head read: if the head moved between the two
        # calls, this review does not cover the current head after all, so keep
        # waiting rather than declaring a pass on unreviewed code.
        confirm_head=$(current_head_sha)
        if [[ -z "$confirm_head" || "$confirm_head" == "$head_sha" ]]; then
            report_success "$head_sha" "$submitted" "${confirm_head:-$head_sha}"
            exit 0
        fi
        echo "  Found a review of ${head_sha:0:7} but head is now ${confirm_head:0:7}; still waiting"
        head_sha="$confirm_head"
        request_review_nudge
        continue
    fi

    echo "  Waiting... (${elapsed}s / ${TIMEOUT}s)"
done

echo ""
echo "TIMEOUT: no Copilot review of ${head_sha:0:7} arrived within ${TIMEOUT}s."
stale=$(latest_review_commit)
if [[ -n "$stale" && "$stale" != "$head_sha" ]]; then
    echo "Newest Copilot review on this PR covers ${stale:0:7}, which is NOT the current head."
    echo "That review is not coverage for ${head_sha:0:7}."
elif [[ -z "$stale" ]]; then
    echo "Copilot has never submitted a review on this PR."
fi
echo "This is a timeout, not a verdict: re-run to keep waiting. Do NOT read it as"
echo "'no findings' — nothing has reviewed ${head_sha:0:7} yet."
exit 1
