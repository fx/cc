#!/usr/bin/env bash
# wait-for-copilot-review.sh
# Waits until GitHub Copilot has submitted a review of the PR's CURRENT head commit.
#
# Usage: ./wait-for-copilot-review.sh <PR_NUMBER> [TIMEOUT_SECONDS]
# Default timeout: 480 seconds (8 minutes).
#     Deliberately below the Claude Code Bash tool's 600 000 ms (600 s) hard cap,
#     with headroom, so the script can always reach its own timeout path and
#     return exit 1 instead of being killed mid-poll. A killed script prints no
#     diagnostics and no exit code, which is what made the "re-run on exit 1"
#     protocol unreachable. Callers that want to wait longer re-run the script;
#     they do NOT raise this past the cap.
# Env: COPILOT_WAIT_DEBUG=1  echo the raw review-request POST response
#
# The timeout is measured against the WALL CLOCK (bash `SECONDS`), not against
# accumulated `sleep` time. Each poll also spends 2+ network round-trips, so
# counting only sleeps understated real elapsed time by 40-110 s over a full run
# and pushed the script past the caller's Bash-tool timeout.
#
# Exit codes:
#   0 - SUCCESS. A Copilot review exists whose `commit_id` equals the PR's current
#       head SHA. stdout carries machine-readable
#           REVIEWED_COMMIT_ID=<sha>
#           PR_HEAD_SHA=<sha>
#           SUPPRESSED_COMMENTS=1|0
#       so the caller can re-verify the match itself rather than trusting this
#       script's word for it. `SUPPRESSED_COMMENTS=1` means at least one review of
#       that commit carries a `Suppressed comments` block whose findings create NO
#       review thread (D4): exit 0 is then NOT a clean result, and the caller MUST
#       read and triage the printed body before treating the gate as passed.
#       Exit 0 alone never establishes a clean review.
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
#     report. This script prints the review body, flags that block, AND emits
#     `SUPPRESSED_COMMENTS=1|0` so a caller that only branches on the exit code
#     still has a checkable signal; the CALLER must read and triage it.
#     "0 unresolved threads" alone never passes the gate.
#
#     The check spans EVERY review of the target commit, not just the newest one.
#     Two reviews of one commit are routine (this script nudges on every head
#     move, and the skill re-runs it up to 3 times), so a later "generated no new
#     comments" review would otherwise mask an earlier one's suppressed block.
#
# HEAD-SHA AWARENESS (do not remove):
#     Copilot does NOT re-review automatically when new commits are pushed unless
#     the repo ruleset enables "review new pushes". A version of this script that
#     matched *any* Copilot review on the PR exited 0 immediately after a fix was
#     pushed, reporting a review of the PREVIOUS commit as coverage for the new
#     one. Every check below is scoped to the current head SHA, the head is
#     re-read on every poll, and a match is re-confirmed against a fresh head read
#     before success is declared.
#
#     That re-confirmation FAILS CLOSED. `current_head_sha` swallows errors and
#     returns empty on a failed API read, so empty means "unknown", never
#     "unchanged". An earlier version treated empty as confirmation and could
#     print a superseded SHA as both REVIEWED_COMMIT_ID and PR_HEAD_SHA — making
#     the caller's mandated equality check pass on a stale review. A SHA pair is
#     now emitted ONLY from a head read that actually succeeded.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

MIN_GH_VERSION="2.50.0"

# Default kept under the Bash tool's 600 s hard cap with headroom (see header): the
# skill pairs this 480 s budget with `timeout: 540000` on the tool call, leaving 60 s
# for the closing diagnostics. Raise the NUMBER OF RUNS to wait longer, never this.
DEFAULT_TIMEOUT=480

PR_NUMBER="${1:-}"
TIMEOUT="${2:-$DEFAULT_TIMEOUT}"
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
# An EMPTY result means the read FAILED, not "the head is unchanged". Every caller
# must treat empty as unknown and must never derive a confirmation from it.
current_head_sha() {
    gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid' 2>/dev/null || true
}

# THE readiness signal (D3). REST /reviews rather than `gh pr view --json reviews`
# because only REST exposes `commit_id` — without it there is no way to tell a
# review of this push from a review of the last one.
#
# Considers EVERY review of the commit, not just the newest: presence is what
# matters, and two reviews of one commit are routine.
check_review_submitted() {
    local sha="$1"
    gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" --jq \
        "[.[] | select(.user.login | startswith(\"${COPILOT_LOGIN_PREFIX}\")) | select(.commit_id == \"${sha}\") | (.state // \"UNKNOWN\")] | unique | join(\", \")" \
        2>/dev/null || true
}

# The bodies of ALL Copilot reviews of a specific commit, concatenated. Needed
# because the findings that matter most may live only in a Suppressed comments
# block (D4) — and taking only the newest review hid that block whenever a later
# review of the same commit reported "generated no new comments".
review_bodies() {
    local sha="$1"
    gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" --jq \
        "[.[] | select(.user.login | startswith(\"${COPILOT_LOGIN_PREFIX}\")) | select(.commit_id == \"${sha}\") | .body] | join(\"\n\n----- (next Copilot review of this same commit) -----\n\n\")" \
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

# Declare success. Emits the reviewed commit_id, the head SHA, and the
# suppressed-comments flag so the caller can verify the gate without trusting this
# script — and cannot record "gate passed" off the exit code alone (D4).
#
# `head_now` MUST come from a head read that succeeded. Never pass a fallback value
# here: emitting a SHA pair this script is not certain of is exactly the failure
# the caller's equality check exists to catch.
report_success() {
    local reviewed_sha="$1" state="$2" head_now="$3"
    local bodies thread_count suppressed=0

    if [[ -z "$head_now" ]]; then
        echo "Internal error: refusing to emit a SHA pair from an unconfirmed head read" >&2
        exit 3
    fi

    bodies=$(review_bodies "$reviewed_sha")
    if printf '%s' "$bodies" | grep -qi 'Suppressed comments'; then
        suppressed=1
    fi

    echo ""
    echo "Copilot review received for ${reviewed_sha:0:7} (state: ${state})"
    echo "REVIEWED_COMMIT_ID=${reviewed_sha}"
    echo "PR_HEAD_SHA=${head_now}"
    echo "SUPPRESSED_COMMENTS=${suppressed}"

    echo ""
    echo "=== Copilot Review Body (every review of ${reviewed_sha:0:7}) ==="
    if [[ -n "$bodies" ]]; then
        printf '%s\n' "$bodies"
    else
        echo "(review has an empty body)"
    fi

    echo ""
    if [[ "$suppressed" -eq 1 ]]; then
        echo "!! SUPPRESSED_COMMENTS=1 — a 'Suppressed comments' block is PRESENT above."
        echo "!! Those are real findings and they create NO review thread. You MUST read"
        echo "!! the <details> block in full and triage every item in it. The gate is NOT"
        echo "!! passed until you have (D4). Exit 0 does not mean clean."
    else
        echo "SUPPRESSED_COMMENTS=0 — no 'Suppressed comments' block in any review of this commit."
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

# Immediate check: this commit may already have been reviewed. Passing head_sha as
# the head is sound here — it came from the read above, which was verified non-empty.
submitted=$(check_review_submitted "$head_sha")
if [[ -n "$submitted" ]]; then
    report_success "$head_sha" "$submitted" "$head_sha"
    exit 0
fi

# Not reviewed yet. Nudge, then wait. Note there is deliberately NO "is it
# requested?" gate here: that question has no answerable form (D1/D3), and
# treating it as answerable is what made this script report false negatives.
request_review_nudge
echo "Polling every ${POLL_INTERVAL}s for a review of ${head_sha:0:7} (budget: ${TIMEOUT}s wall clock)..."
echo "Observed Copilot delivery times range from 85s to 12m42s — a quiet first few minutes is normal."

# Budget against the WALL CLOCK, not against accumulated sleep time: each poll also
# spends 2+ network round-trips, and counting only the sleeps let real elapsed time
# overrun the caller's Bash-tool timeout so the script was killed before it could
# report exit 1. `SECONDS` is a bash builtin counting seconds since it was reset.
SECONDS=0
while (( SECONDS < TIMEOUT )); do
    # Never sleep past the deadline — that is what turns a 480 s budget into 500 s.
    remaining=$(( TIMEOUT - SECONDS ))
    nap=$POLL_INTERVAL
    if (( nap > remaining )); then
        # NB: `(( ... )) && nap=...` would exit under `set -e` whenever the test is
        # false, i.e. on every normal poll. Keep this as an `if`.
        nap=$remaining
    fi
    sleep "$nap"

    # Re-read the head: if someone pushed while we waited, the review we are
    # waiting for is the one covering the NEW commit.
    new_head_sha=$(current_head_sha)
    if [[ -z "$new_head_sha" ]]; then
        # Empty means the API read FAILED (see current_head_sha). Say so: silently
        # retaining the old value is how a superseded SHA gets treated as current.
        echo "  Warning: could not re-read the head of PR #${PR_NUMBER} this poll (API read failed)."
        echo "           Still targeting ${head_sha:0:7}, which may already be superseded; retrying."
    elif [[ "$new_head_sha" != "$head_sha" ]]; then
        echo "  Head moved ${head_sha:0:7} -> ${new_head_sha:0:7}; a review must now cover the new commit"
        head_sha="$new_head_sha"
        request_review_nudge
    fi

    submitted=$(check_review_submitted "$head_sha")
    if [[ -n "$submitted" ]]; then
        # Re-confirm against a fresh head read. This FAILS CLOSED: an empty read is
        # a failed read, not a confirmation, so it keeps waiting instead of emitting
        # a SHA pair we are not certain of.
        confirm_head=$(current_head_sha)
        if [[ -z "$confirm_head" ]]; then
            echo "  Found a review of ${head_sha:0:7} but the head re-read FAILED, so the match is"
            echo "  unconfirmed. Not declaring success on an unverifiable head; still waiting."
            continue
        fi
        if [[ "$confirm_head" == "$head_sha" ]]; then
            report_success "$head_sha" "$submitted" "$confirm_head"
            exit 0
        fi
        echo "  Found a review of ${head_sha:0:7} but head is now ${confirm_head:0:7}; still waiting"
        head_sha="$confirm_head"
        request_review_nudge
        continue
    fi

    echo "  Waiting... (${SECONDS}s / ${TIMEOUT}s wall clock)"
done

echo ""
echo "TIMEOUT: no Copilot review of ${head_sha:0:7} arrived within ${TIMEOUT}s (${SECONDS}s wall clock elapsed)."
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
