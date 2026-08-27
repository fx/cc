#!/usr/bin/env bash
# wait-for-copilot-review.sh
# Waits until GitHub Copilot has submitted a review of the PR's CURRENT head commit.
#
# Usage: ./wait-for-copilot-review.sh <PR_NUMBER> [TIMEOUT_SECONDS]
# Default timeout: 900 seconds (15 minutes), uniform across the fx-dev wait scripts.
#     Sized to cover the worst observed Copilot delivery time (12 m 42 s) in ONE run,
#     which is what retires the old "re-run up to 3 times" protocol.
# Env: COPILOT_WAIT_DEBUG=1  echo the raw review-request POST response
#
# ⛔ RUN THIS IN THE BACKGROUND (`run_in_background: true`), redirecting stdout and
#    stderr to a log file. The Bash tool caps a FOREGROUND `timeout` at 600 000 ms,
#    which is BELOW this script's budget — a foreground call is guaranteed to be
#    killed mid-poll, printing no STATUS and no exit code. That kill is exactly what
#    made the old re-run protocol unreachable. Backgrounded processes are not
#    subject to that cap, which is why the budget can now exceed it.
#
# The timeout is measured against the WALL CLOCK (bash `SECONDS`), not against
# accumulated `sleep` time. Each poll also spends 2+ network round-trips, so
# counting only sleeps understated real elapsed time by 40-110 s over a full run.
#
# ─────────────────────────────────────────────────────────────────────────────
# STATUS PROTOCOL (shared by every fx-dev wait script)
#
# The LAST line of stdout is always `STATUS=<state>`, and the exit code mirrors it.
# Read the STATUS line; it is the primary signal.
#
#   STATUS=TERMINAL_PASS   exit 0  A review covers the current head AND no Copilot
#                                  thread is unresolved.
#   STATUS=TERMINAL_FAIL   exit 1  A review covers the current head and Copilot
#                                  threads remain open (or the thread count could
#                                  not be read, which is not a zero). Settled —
#                                  triage the threads; do not re-run for a better
#                                  answer.
#   STATUS=PENDING         exit 2  No review of the current head arrived within the
#                                  budget. NOT a failure and NOT evidence anything
#                                  is wrong: observed delivery ranges from 85 s to
#                                  12 m 42 s, and the ruleset that auto-requests a
#                                  review fires on some pushes and not others.
#                                  Re-running is safe and is the correct response.
#                                  NEVER grounds to conclude the code is clean.
#   STATUS=NOT_CONFIGURED  exit 3  NEVER RETURNED by this script. Whether Copilot is
#                                  "configured" has no answerable form — the only
#                                  signal that would express it, `requested_reviewers`,
#                                  does not work at all (D1/D3). Callers MUST NOT
#                                  branch on it here, and MUST NOT reinstate any
#                                  "request again, then re-run" recovery keyed to it.
#   STATUS=ERROR           exit 4  Bad arguments, `gh` too old, repo or PR head
#                                  unresolvable. The wait never started.
#
# On a settled review, stdout also carries machine-readable
#     REVIEWED_COMMIT_ID=<sha>
#     PR_HEAD_SHA=<sha>
#     SUPPRESSED_COMMENTS=1|0|unknown
#     UNRESOLVED_THREADS=<n|unknown>
# so the caller can re-verify the match itself rather than trusting this script's
# word for it. The SHA pair is the line that gates: a review of a superseded commit
# is not coverage. `SUPPRESSED_COMMENTS` is INFORMATIONAL ONLY (D4): `1` means a
# `Suppressed comments` block is present, `0` means the fetch succeeded and found
# none, `unknown` means the fetch FAILED so this script cannot say (D5). None of the
# three withholds the gate, and a caller should not re-run merely to turn `unknown`
# into a number.
#
#
# BUDGET GUARANTEE: every API call is wrapped by `timeout`. Reads taken while
# WAITING are capped by the budget REMAINING, so none can outlive the deadline.
# Reads taken AFTER a verdict is decided (reporting, not waiting) are capped by
# DIAGNOSTIC_BUDGET, so STATUS can land up to that many seconds past TIMEOUT —
# a bounded, deliberate tail rather than an open-ended one.
#
# STATUS reflects the MECHANICAL thread gate only. The review's VERDICT HEADLINE is
# still what drives triage, and it is printed in full below — read it.
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
#     this script gated the poll on it and therefore reported "no Copilot review
#     requested" against reviews that were genuinely delivered — on one
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
# D4. A suppressed-comments block is INFORMATIONAL, not a gate. Copilot review
#     bodies can say "generated no new comments" while carrying a
#       <details><summary>Suppressed comments (N)</summary>
#     block. Those items open NO review thread — Copilot itself judged them not
#     worth raising as one — and they are overwhelmingly wording, casing, and
#     comment-phrasing nits. Acting on them is expensive, because every push
#     re-opens the review gate and costs another full wait cycle. The default is
#     to IGNORE them; a caller acts only on something absolutely dire. This script
#     still flags the block and emits `SUPPRESSED_COMMENTS=1|0|unknown`, because
#     knowing is free — but the flag never withholds the gate.
#
#     The check spans EVERY review of the target commit, not just the newest one.
#     Two reviews of one commit are routine (this script nudges on every head
#     move, and the skill re-runs it up to 3 times), so reading only the newest
#     body would report on a different review than the one being judged.
#
#     What DOES decide the outcome is the review's VERDICT HEADLINE:
#       "Approval recommended" / "Needs a closer look" -> pass, if no threads open
#       "Changes recommended"                          -> triage and resolve
#
# D5. The suppressed-comments check has THREE outcomes, and a failed fetch is not 0.
#     `review_bodies` used to end in `|| true`, so a transient `gh api` error
#     produced an empty string, the `Suppressed comments` grep matched nothing, and
#     the script printed SUPPRESSED_COMMENTS=0 plus "(review has an empty body)" —
#     reporting a result for a check that never ran. Keep the three states honest:
#     1 = block present, 0 = fetch succeeded and no block, `unknown` = fetch
#     FAILED. Distinguish the last two by `gh`'s EXIT STATUS, never by empty
#     output — a Copilot review with a genuinely empty body is legal and observed,
#     so "empty" and "unfetched" are different facts that look identical on stdout.
#     None of the three blocks the gate (D4); the distinction exists so the output
#     says what it knows rather than guessing.
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

# Uniform across the fx-dev wait scripts, and sized to cover the worst observed
# delivery time (12 m 42 s) in a single run. This EXCEEDS the Bash tool's 600 s
# foreground cap on purpose — the script must be backgrounded (see header).
DEFAULT_TIMEOUT=900

# Hard cap on the ONE diagnostic read taken after the deadline (see
# latest_review_commit). STATUS may therefore be emitted up to this many seconds
# after TIMEOUT — bounded and documented, rather than open-ended.
DIAGNOSTIC_BUDGET=10

PR_NUMBER="${1:-}"
TIMEOUT="${2:-$DEFAULT_TIMEOUT}"
POLL_INTERVAL=15

# Emit the trailing STATUS line and exit with the matching code. Every exit path in
# this script goes through here so the contract can never be partially honoured.
# NOT_CONFIGURED is intentionally unreachable here — see the header (D1/D3).
STATUS_EMITTED=0

# Write the STATUS line, and report whether it actually got out.
#
# stdout can fail — the redirected log's filesystem fills, or its FD errors. Falling
# back to stderr is worth trying because every documented launch redirects `2>&1`
# into the same log, so the line still reaches the caller. Exactly one of the two
# writes can succeed, so the log never carries a duplicate STATUS line.
emit_status() {
    echo "STATUS=$1" && return 0
    echo "STATUS=$1" >&2 && return 0
    return 1
}

# STRUCTURAL GUARANTEE: never exit without a STATUS line. `set -e` can abort at any
# unchecked command, and an abort that printed no STATUS would leave the caller with
# nothing to branch on — the exact failure mode the protocol exists to remove. This
# trap turns any such abort into a well-formed ERROR.
trap 'if (( STATUS_EMITTED == 0 )); then emit_status ERROR; exit 4; fi' EXIT

finish() {
    local status="$1"
    # Mark it emitted ONLY after the write succeeded. Setting the flag first would
    # make a failed write look like a delivered STATUS and suppress the trap's
    # fallback — leaving the caller with no status line at all, which is precisely
    # what this protocol exists to prevent.
    if emit_status "$status"; then STATUS_EMITTED=1; fi
    case "$status" in
        TERMINAL_PASS)   exit 0 ;;
        TERMINAL_FAIL)   exit 1 ;;
        PENDING)         exit 2 ;;
        NOT_CONFIGURED)  exit 3 ;;
        *)               exit 4 ;;
    esac
}

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: $0 <PR_NUMBER> [TIMEOUT_SECONDS]" >&2
    finish ERROR
fi

if [[ ! "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: PR_NUMBER must be a positive integer (got: '$PR_NUMBER')" >&2
    finish ERROR
fi

if [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]]; then
    echo "Error: TIMEOUT_SECONDS must be a non-negative integer (got: '$TIMEOUT')" >&2
    finish ERROR
fi

# A zero (or already-exhausted) budget is NOT a failure — the caller asked for no
# wait, so nothing could be observed. Report that honestly as PENDING rather than
# ERROR, which claims something went wrong. Doing this before any API call is also
# what keeps the "no read outlives the budget" guarantee true at TIMEOUT=0.
if (( TIMEOUT == 0 )); then
    echo "Budget is 0s — no wait performed and nothing observed."
    echo "This is NOT a verdict. Re-run with a budget to actually wait."
    finish PENDING
fi

# ─── START THE WALL CLOCK ────────────────────────────────────────────────────
# Started HERE, before ANY API call — preflight included. `SECONDS` counts from
# shell start, so a reset placed later left the preflight calls outside the budget
# entirely: with a short caller timeout the script could spend longer on preflight
# than the whole budget allowed before it even began waiting. One clock, started
# before the first network byte, bounds the entire run.
SECONDS=0

# ─── Budget enforcement for API calls ────────────────────────────────────────
# Deadline CHECKS only stop the next poll from STARTING; they do nothing about a
# request already in flight. A hung `gh` call started one second before the
# deadline delays STATUS indefinitely, defeating the advertised wall-clock bound.
# Every API call is therefore wrapped by one of two caps:
#
#   wait_cap  — reads taken while WAITING. Capped by the budget REMAINING, so no
#               read can outlive the deadline.
#   DIAGNOSTIC_BUDGET — reads taken AFTER a verdict is decided (reporting, not
#               waiting). STATUS can land up to this many seconds past TIMEOUT;
#               that tail is bounded and deliberate.
#
# ⚠️ `timeout 0 CMD` DISABLES the timeout in coreutils — it does not expire
# immediately. A zero cap must SKIP the call, never be passed to `timeout`.
wait_cap() {
    local r=$(( TIMEOUT - SECONDS ))
    if (( r < 0 )); then r=0; fi
    printf '%s' "$r"
}

budget_exhausted() {
    (( $(wait_cap) <= 0 ))
}

# The post-deadline diagnostic tail is ONE allowance shared by every reporting read,
# not a fresh allowance per call. `report_terminal` makes two API calls; giving each
# its own DIAGNOSTIC_BUDGET would let the tail reach 2x the documented figure, which
# is a wall-clock guarantee the header states and would not keep. Arm the deadline
# once via `arm_diagnostic_budget`, then cap each read by what is left of it.
DIAGNOSTIC_DEADLINE=0

arm_diagnostic_budget() {
    DIAGNOSTIC_DEADLINE=$(( SECONDS + DIAGNOSTIC_BUDGET ))
}

diag_cap() {
    local r=$(( DIAGNOSTIC_DEADLINE - SECONDS ))
    if (( r < 0 )); then r=0; fi
    printf '%s' "$r"
}


# Verify gh version meets minimum requirement (--json flag on pr view requires 2.50+)
gh_version=$(gh --version | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
if ! printf '%s\n' "$MIN_GH_VERSION" "$gh_version" | sort -V | head -1 | grep -q "^${MIN_GH_VERSION}$"; then
    echo "Error: gh CLI version $gh_version is too old. Minimum required: $MIN_GH_VERSION" >&2
    echo "Upgrade with: mise use -g gh@latest" >&2
    finish ERROR
fi

# Copilot bot identifiers vary by API:
#   REST /reviews:            user.login = "copilot-pull-request-reviewer[bot]"
#   gh pr view --json:        author.login = "copilot-pull-request-reviewer"
#   REST requested_reviewers: login = "Copilot" — but it is always empty (D1),
#                             so this script never reads it.
COPILOT_LOGIN_PREFIX="copilot-pull-request-reviewer"


# Get repo owner/name for REST API calls
# `timeout` exits 124 when it KILLS the command. That is a budget expiry, not a
# substantive failure — reporting it as ERROR would state "gh is not authenticated"
# or "could not determine repository" about a working setup, which is a false claim
# a reader would act on. Budget expiry is PENDING: we observed nothing either way.
preflight_cap=$(wait_cap)
if (( preflight_cap <= 0 )); then
    echo "Budget expired during preflight — nothing was observed."
    finish PENDING
fi
preflight_rc=0
REPO_NWO=$(timeout "$preflight_cap" gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) || preflight_rc=$?
if (( preflight_rc == 124 )); then
    echo "Budget expired while resolving the repository — nothing was observed."
    finish PENDING
fi
if [[ -z "$REPO_NWO" ]]; then
    echo "Error: Could not determine repository" >&2
    finish ERROR
fi

echo "Checking PR #${PR_NUMBER} for a Copilot review of its current head..."

# The commit a review must cover to count. Re-read on every poll, so a push that
# lands mid-wait moves the target instead of being satisfied by a stale review.
#
# RETURN CODES follow the shared helper contract: 0 = read succeeded (stdout is the
# SHA), 2 = BUDGET EXPIRED, 1 = the read genuinely FAILED. An EMPTY stdout on a 0
# return still means unknown — never "the head is unchanged" — so callers must keep
# failing closed on it. Collapsing all three into "empty" is what let a budget
# expiry be reported as a broken setup.
current_head_sha() {
    # Cap computed ONCE and zero rejected before use — see the budget block above.
    local cap rc=0 out; cap=$(wait_cap)
    if (( cap <= 0 )); then return 2; fi
    out=$(timeout "$cap" gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid' 2>/dev/null) || rc=$?
    if (( rc == 124 )); then return 2; fi
    if (( rc != 0 )); then return 1; fi
    printf '%s' "$out"
}

# THE readiness signal (D3). REST /reviews rather than `gh pr view --json reviews`
# because only REST exposes `commit_id` — without it there is no way to tell a
# review of this push from a review of the last one.
#
# Considers EVERY review of the commit, not just the newest: presence is what
# matters, and two reviews of one commit are routine.
#
# RETURNS NON-ZERO WHEN THE READ FAILED, and empty-with-zero when the read
# succeeded and found nothing. Those are different facts that look identical on
# stdout: without the distinction, an API error is indistinguishable from "no
# review yet", so a run whose every poll failed would report PENDING as though it
# had genuinely watched for a review. Callers MUST branch on the status.
check_review_submitted() {
    local sha="$1" cap rc=0 out
    cap=$(wait_cap)
    if (( cap <= 0 )); then return 2; fi
    out=$(timeout "$cap" gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" --jq \
        "[.[] | select(.user.login | startswith(\"${COPILOT_LOGIN_PREFIX}\")) | select(.commit_id == \"${sha}\") | (.state // \"UNKNOWN\")] | unique | join(\", \")" \
        2>/dev/null) || rc=$?
    if (( rc == 124 )); then return 2; fi
    if (( rc != 0 )); then return 1; fi
    printf '%s' "$out"
}

# The bodies of ALL Copilot reviews of a specific commit, concatenated. The caller
# reads the VERDICT HEADLINE out of these, so taking only the newest review would
# report on a different review than the one being judged whenever a commit has two.
#
# REPORTS HONESTLY (D5). Deliberately carries NO `|| true` and NO `2>/dev/null`:
#   * the EXIT STATUS is the only sound signal of whether the fetch happened, and
#     `|| true` destroyed it — a transient API error became an empty string and
#     the script printed SUPPRESSED_COMMENTS=0 for a check that never ran;
#   * stderr is left attached so the failure is visible in the caller's output.
# Callers MUST branch on the exit status (`if bodies=$(review_bodies ...)`), never
# on whether the output is empty: an empty body is a LEGAL, observed Copilot
# result, so emptiness cannot distinguish "no findings" from "never fetched".
review_bodies() {
    local sha="$1" cap
    cap=$(diag_cap)
    if (( cap <= 0 )); then return 1; fi   # tail spent; `timeout 0` would uncap
    timeout "$cap" gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" --jq \
        "[.[] | select(.user.login | startswith(\"${COPILOT_LOGIN_PREFIX}\")) | select(.commit_id == \"${sha}\") | .body] | join(\"\n\n----- (next Copilot review of this same commit) -----\n\n\")"
}

# The commit of the newest Copilot review of ANY commit. Diagnostic only — used to
# explain a timeout ("Copilot reviewed this PR, but not this code" reads very
# differently from "Copilot has never looked at this PR"). Never a success signal.
#
# Also carries no `|| true` (D5): with one, a failed read returned empty and the
# timeout path below stated "Copilot has never submitted a review on this PR" as
# fact — an assertion about the PR derived from an API error. Empty output now means
# "the read succeeded and there are no Copilot reviews"; a non-zero status means
# "unknown", and the caller says so instead of guessing.
#
# HARD-BOUNDED by DIAGNOSTIC_BUDGET, because its only caller runs after the wait
# deadline has already passed. An unbounded read there would let a stuck request
# push the run arbitrarily past its advertised budget and delay the STATUS line.
# `timeout` exiting non-zero lands in the caller's "read failed" branch, which
# already says the answer is UNKNOWN — the correct thing to say.
latest_review_commit() {
    local cap; cap=$(diag_cap)
    if (( cap <= 0 )); then return 1; fi
    timeout "$cap" gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" --jq \
        "[.[] | select(.user.login | startswith(\"${COPILOT_LOGIN_PREFIX}\")) | .commit_id] | last // empty"
}

# Best-effort nudge. See D1: the response is discarded on purpose. Issued because
# it sometimes unsticks delivery, never consulted to decide anything.
request_review_nudge() {
    local out=""
    local cap; cap=$(wait_cap)
    if (( cap <= 0 )); then return 0; fi   # nudging is pointless past the deadline
    out=$(printf '%s' '{"reviewers":["copilot-pull-request-reviewer[bot]"]}' \
        | timeout "$cap" gh api --method POST "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/requested_reviewers" \
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
    local dcap; dcap=$(diag_cap)
    if (( dcap <= 0 )); then echo "unknown"; return; fi
    if ! result=$(timeout "$dcap" gh api graphql -f query="
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

# Report a settled review and exit via finish(). Emits the reviewed commit_id, the
# head SHA, and the suppressed-comments flag so the caller can verify the gate
# without trusting this script — and cannot record "gate passed" off the exit code
# alone (D4).
#
# `head_now` MUST come from a head read that succeeded. Never pass a fallback value
# here: emitting a SHA pair this script is not certain of is exactly the failure
# the caller's equality check exists to catch.
report_terminal() {
    local reviewed_sha="$1" state="$2" head_now="$3"
    # The wait is over; everything below is REPORTING. Arm the one shared tail.
    arm_diagnostic_budget
    local bodies thread_count suppressed fetch_ok=1

    if [[ -z "$head_now" ]]; then
        echo "Internal error: refusing to emit a SHA pair from an unconfirmed head read" >&2
        finish ERROR
    fi

    # THREE states, not two (D5). `gh`'s exit status — never the emptiness of its
    # output — decides whether the suppressed-comments check actually ran:
    #   fetch OK + block present -> 1
    #   fetch OK + no block      -> 0
    #   fetch FAILED             -> unknown   (never 0: that reads as "clean")
    # A genuinely empty review body is legal and observed, so inferring failure from
    # empty output would false-alarm on clean reviews and inferring success from it
    # would certify a review nobody fetched. Only the status separates the two.
    if bodies=$(review_bodies "$reviewed_sha"); then
        if printf '%s' "$bodies" | grep -qi 'Suppressed comments'; then
            suppressed=1
        else
            suppressed=0
        fi
    else
        fetch_ok=0
        bodies=""
        suppressed="unknown"
    fi

    echo ""
    echo "Copilot review received for ${reviewed_sha:0:7} (state: ${state})"
    echo "REVIEWED_COMMIT_ID=${reviewed_sha}"
    echo "PR_HEAD_SHA=${head_now}"
    echo "SUPPRESSED_COMMENTS=${suppressed}"

    echo ""
    echo "=== Copilot Review Body (every review of ${reviewed_sha:0:7}) ==="
    if (( fetch_ok == 0 )); then
        echo "(COULD NOT BE FETCHED — the API read FAILED; see the gh error above)"
    elif [[ -n "$bodies" ]]; then
        printf '%s\n' "$bodies"
    else
        echo "(the fetch SUCCEEDED and every review of this commit has an empty body)"
    fi

    echo ""
    if (( fetch_ok == 0 )); then
        echo "SUPPRESSED_COMMENTS=unknown — fetching the review bodies FAILED, so this"
        echo "script cannot say whether a 'Suppressed comments' block exists. Informational"
        echo "only: suppressed comments do not gate this review (D4/D5). Read the verdict"
        echo "headline and the thread count instead."
    elif [[ "$suppressed" == "1" ]]; then
        echo "SUPPRESSED_COMMENTS=1 — a 'Suppressed comments' block is present above."
        echo "Ignore it by default: those items open no review thread and Copilot itself"
        echo "declined to raise them as one (D4). Act only on something absolutely dire."
    else
        echo "SUPPRESSED_COMMENTS=0 — no 'Suppressed comments' block in any review of this commit."
    fi

    echo ""
    echo "Read the VERDICT HEADLINE at the top of the body above:"
    echo "  'Approval recommended' / 'Needs a closer look' -> PASS if no threads are open"
    echo "  'Changes recommended'                          -> triage and resolve its threads"

    thread_count=$(count_copilot_threads)
    echo ""
    echo "UNRESOLVED_THREADS=${thread_count}"

    # STATUS reflects the MECHANICAL thread gate only; the verdict headline printed
    # above is what drives triage. `unknown` is NOT zero — an unread count cannot
    # certify a clean PR, so this fails closed exactly as the head re-confirmation
    # does. A caller that wants the distinction has it on the UNRESOLVED_THREADS line.
    if [[ "$thread_count" == "unknown" ]]; then
        echo ""
        echo "The unresolved-thread read FAILED, so this script cannot confirm the PR is clean."
        echo "Failing closed: verify the threads yourself before any merge gate."
        finish TERMINAL_FAIL
    elif (( thread_count > 0 )); then
        finish TERMINAL_FAIL
    else
        finish TERMINAL_PASS
    fi
}


head_rc=0
head_sha=$(current_head_sha) || head_rc=$?
if (( head_rc == 2 )); then
    echo "Budget expired before the head commit could be read — nothing was observed."
    finish PENDING
fi
if (( head_rc != 0 )) || [[ -z "$head_sha" ]]; then
    echo "Error: Could not determine the head commit of PR #${PR_NUMBER}" >&2
    finish ERROR
fi
echo "Head commit: ${head_sha:0:7}"

# Immediate check: this commit may already have been reviewed. Passing head_sha as
# the head is sound here — it came from the read above, which was verified non-empty.
read_rc=0
submitted=$(check_review_submitted "$head_sha") || read_rc=$?
if (( read_rc == 2 )); then
    echo "Budget expired before the reviews could be read — nothing was observed."
    finish PENDING
fi
if (( read_rc != 0 )); then
    echo "Error: could not read the reviews of PR #${PR_NUMBER} — the API read FAILED." >&2
    echo "Whether a review of ${head_sha:0:7} exists is UNKNOWN; refusing to guess." >&2
    finish ERROR
fi
if [[ -n "$submitted" ]]; then
    report_terminal "$head_sha" "$submitted" "$head_sha"
fi

# Not reviewed yet. Nudge, then wait. Note there is deliberately NO "is it
# requested?" gate here: that question has no answerable form (D1/D3), and
# treating it as answerable is what made this script report false negatives.
request_review_nudge
echo "Polling every ${POLL_INTERVAL}s for a review of ${head_sha:0:7} (budget: ${TIMEOUT}s wall clock)..."
echo "Observed Copilot delivery times range from 85s to 12m42s — a quiet first few minutes is normal."

# The budget is measured against the WALL CLOCK and was started ABOVE, before the
# initial reads — deliberately NOT reset here. Resetting would hand the poll loop a
# fresh full budget on top of whatever the setup reads already spent. Counting only
# accumulated `sleep` time is also wrong: each poll spends 2+ network round-trips.
while (( SECONDS < TIMEOUT )); do
    # Never sleep past the deadline — that is what turns a 900 s budget into 915 s.
    remaining=$(( TIMEOUT - SECONDS ))
    nap=$POLL_INTERVAL
    if (( nap > remaining )); then
        # NB: `(( ... )) && nap=...` would exit under `set -e` whenever the test is
        # false, i.e. on every normal poll. Keep this as an `if`.
        nap=$remaining
    fi
    sleep "$nap"

    # RECHECK THE DEADLINE BEFORE SPENDING ANOTHER API ROUND-TRIP. Without this, a
    # sleep that consumes the last of the budget is still followed by two or more
    # `gh` calls, so a slow request runs past the deadline and can even declare
    # success after it — reporting a verdict the budget said we would not wait for.
    if (( SECONDS >= TIMEOUT )); then
        break
    fi

    # Re-read the head: if someone pushed while we waited, the review we are
    # waiting for is the one covering the NEW commit.
    head_rc=0
    new_head_sha=$(current_head_sha) || head_rc=$?
    if (( head_rc == 2 )); then break; fi   # budget expired -> loop ends as PENDING
    if (( head_rc != 0 )) || [[ -z "$new_head_sha" ]]; then
        # Empty means the API read FAILED (see current_head_sha). Say so: silently
        # retaining the old value is how a superseded SHA gets treated as current.
        echo "  Warning: could not re-read the head of PR #${PR_NUMBER} this poll (API read failed)."
        echo "           Still targeting ${head_sha:0:7}, which may already be superseded; retrying."
    elif [[ "$new_head_sha" != "$head_sha" ]]; then
        echo "  Head moved ${head_sha:0:7} -> ${new_head_sha:0:7}; a review must now cover the new commit"
        head_sha="$new_head_sha"
        request_review_nudge
    fi

    # A FAILED read is not "no review yet". Warn and keep polling rather than
    # silently counting it as evidence of absence — a run whose every poll failed
    # would otherwise report PENDING as though it had genuinely watched.
    read_rc=0
    submitted=$(check_review_submitted "$head_sha") || read_rc=$?
    if (( read_rc == 2 )); then break; fi   # budget expired -> the loop ends as PENDING
    if (( read_rc != 0 )); then
        echo "  Warning: could not read the reviews of PR #${PR_NUMBER} this poll (API read failed)."
        echo "           This poll observed NOTHING; it is not evidence that no review exists."
        continue
    fi
    if [[ -n "$submitted" ]]; then
        # Re-confirm against a fresh head read. This FAILS CLOSED: an empty read is
        # a failed read, not a confirmation, so it keeps waiting instead of emitting
        # a SHA pair we are not certain of.
        confirm_rc=0
        confirm_head=$(current_head_sha) || confirm_rc=$?
        if (( confirm_rc == 2 )); then break; fi   # budget expired -> PENDING
        if (( confirm_rc != 0 )) || [[ -z "$confirm_head" ]]; then
            echo "  Found a review of ${head_sha:0:7} but the head re-read FAILED, so the match is"
            echo "  unconfirmed. Not declaring success on an unverifiable head; still waiting."
            continue
        fi
        if [[ "$confirm_head" == "$head_sha" ]]; then
            report_terminal "$head_sha" "$submitted" "$confirm_head"
        fi
        echo "  Found a review of ${head_sha:0:7} but head is now ${confirm_head:0:7}; still waiting"
        head_sha="$confirm_head"
        request_review_nudge
        continue
    fi

    echo "  Waiting... (${SECONDS}s / ${TIMEOUT}s wall clock)"
done

echo ""
echo "No Copilot review of ${head_sha:0:7} arrived within ${TIMEOUT}s (${SECONDS}s wall clock elapsed)."
arm_diagnostic_budget
# This diagnostic distinguishes "Copilot reviewed this PR, but not this code" from
# "Copilot has never looked at this PR" — a distinction worth a read, because the two
# call for different responses. It runs AFTER the deadline, so it is HARD-BOUNDED
# inside latest_review_commit(): an unbounded read here would let a stuck request
# push the run arbitrarily past its advertised budget and delay the STATUS line.
if stale=$(latest_review_commit); then
    if [[ -n "$stale" && "$stale" != "$head_sha" ]]; then
        echo "Newest Copilot review on this PR covers ${stale:0:7}, which is NOT the current head."
        echo "That review is not coverage for ${head_sha:0:7}."
    elif [[ -z "$stale" ]]; then
        echo "Copilot has never submitted a review on this PR."
    fi
else
    echo "Could not read this PR's reviews, so whether Copilot has ever reviewed it is"
    echo "UNKNOWN — that API read failed. Do not read this as 'never reviewed'."
fi
echo "This is PENDING, not a verdict: re-run to keep waiting. Do NOT read it as"
echo "'no findings' — nothing has reviewed ${head_sha:0:7} yet."
finish PENDING
