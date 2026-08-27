#!/usr/bin/env bash
# wait-for-coderabbit-review.sh
# Polls a PR for CodeRabbit review completion via the "CodeRabbit" GitHub check
# context. CodeRabbit auto-runs on every PR (no request needed) and re-runs every
# time the head SHA changes — so this script is also used to wait for re-review
# cycles after pushing fixes.
#
# Usage: ./wait-for-coderabbit-review.sh <PR_NUMBER> [TIMEOUT_SECONDS]
# Default timeout: 900 seconds (15 minutes).
#
# ⛔ RUN THIS IN THE BACKGROUND (`run_in_background: true`), redirecting stdout and
#    stderr to a log file. The Bash tool caps a FOREGROUND `timeout` at 600 000 ms,
#    which is BELOW this script's budget — a foreground call is guaranteed to be
#    killed mid-poll, printing no STATUS and no exit code, which is precisely what
#    made callers re-run it blindly. Backgrounded processes are not subject to that
#    cap.
#
# ─────────────────────────────────────────────────────────────────────────────
# STATUS PROTOCOL (shared by every fx-dev wait script)
#
# The LAST line of stdout is always `STATUS=<state>`, and the exit code mirrors it.
# Read the STATUS line; it is the primary signal. The exit code is a convenience.
#
#   STATUS=TERMINAL_PASS   exit 0  Check settled clean AND no unresolved threads.
#   STATUS=TERMINAL_FAIL   exit 1  Check settled with a failing conclusion, or
#                                  unresolved CodeRabbit threads remain. Settled
#                                  either way — do NOT re-run to "get a better
#                                  answer"; triage what it said.
#   STATUS=PENDING         exit 2  Still in progress when the budget expired. NOT a
#                                  verdict and NOT a failure. Re-running is safe and
#                                  is the correct response if you still need it.
#   STATUS=NOT_CONFIGURED  exit 3  No CodeRabbit check on this PR after a grace
#                                  period — the GitHub App is not installed for this
#                                  repo. TERMINAL. Never retry, never wait: most
#                                  repos do not use CodeRabbit and this is the
#                                  expected, correct outcome for them.
#   STATUS=ERROR           exit 4  Bad arguments, `gh` too old, repo/PR unresolvable.
#                                  The wait never started. A real failure.
#
# The distinction between PENDING and TERMINAL_FAIL is the point of this protocol.
# Conflating them is what previously forced callers into blind re-run loops.
# ─────────────────────────────────────────────────────────────────────────────
#
#
# BUDGET GUARANTEE: every API call is wrapped by `timeout`. Reads taken while
# WAITING are capped by the budget REMAINING, so none can outlive the deadline.
# Reads taken AFTER a verdict is decided (reporting, not waiting) are capped by
# DIAGNOSTIC_BUDGET, so STATUS can land up to that many seconds past TIMEOUT —
# a bounded, deliberate tail rather than an open-ended one.
#
# Additional machine-readable lines emitted before STATUS:
#   CHECK_CONCLUSION=<state>          the CodeRabbit check's terminal state
#   UNRESOLVED_THREADS=<n|unknown>    `unknown` means the GraphQL read FAILED, not
#                                     that there are none — see below.

set -euo pipefail

MIN_GH_VERSION="2.50.0"

# Kept deliberately uniform with the other fx-dev wait scripts. Budgeted against the
# WALL CLOCK (bash `SECONDS`), not accumulated sleep time: each poll also spends a
# network round-trip, so counting only the sleeps understates real elapsed time and
# lets a nominal 900 s budget overrun well past it.
DEFAULT_TIMEOUT=900
POLL_INTERVAL=30

# How long to wait for the check to APPEAR before declaring the App unconfigured.
# CodeRabbit auto-runs but with a short startup delay, so a single immediate check
# would report NOT_CONFIGURED against a repo that simply had not started yet.
NOT_CONFIGURED_GRACE=30

PR_NUMBER="${1:-}"
TIMEOUT="${2:-$DEFAULT_TIMEOUT}"

# Emit the trailing STATUS line and exit with the matching code. Every exit path in
# this script goes through here so the contract can never be partially honoured.
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
# deadline delays STATUS indefinitely, which defeats the whole point of an
# advertised wall-clock bound. So every API call is wrapped by one of two caps:
#
#   wait_cap  — for reads taken while WAITING. Capped by the budget REMAINING, so
#               no read can outlive the deadline.
#   DIAGNOSTIC_BUDGET — for reads taken AFTER a verdict is already decided (that
#               is, reporting, not waiting). STATUS can therefore land up to this
#               many seconds past TIMEOUT; that tail is bounded and deliberate.
#
# ⚠️ `timeout 0 CMD` DISABLES the timeout in coreutils — it does not expire
# immediately. A zero cap must therefore SKIP the call, never pass 0 to `timeout`.
# Callers check `budget_exhausted` before any waiting read.
DIAGNOSTIC_BUDGET=10

wait_cap() {
    local r=$(( TIMEOUT - SECONDS ))
    if (( r < 0 )); then r=0; fi
    printf '%s' "$r"
}

budget_exhausted() {
    (( $(wait_cap) <= 0 ))
}

# One shared post-deadline diagnostic allowance, armed when reporting begins — see
# the copilot waiter for why this is a shared deadline rather than a per-call cap.
DIAGNOSTIC_DEADLINE=0

arm_diagnostic_budget() {
    DIAGNOSTIC_DEADLINE=$(( SECONDS + DIAGNOSTIC_BUDGET ))
}

diag_cap() {
    local r=$(( DIAGNOSTIC_DEADLINE - SECONDS ))
    if (( r < 0 )); then r=0; fi
    printf '%s' "$r"
}


# Verify gh version (--json flag on pr view requires 2.50+)
gh_version=$(gh --version | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
if ! printf '%s\n' "$MIN_GH_VERSION" "$gh_version" | sort -V | head -1 | grep -q "^${MIN_GH_VERSION}$"; then
    echo "Error: gh CLI version $gh_version is too old. Minimum required: $MIN_GH_VERSION" >&2
    echo "Upgrade with: mise use -g gh@latest" >&2
    finish ERROR
fi

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


# Emit the CodeRabbit check's state, or return NON-ZERO if it could not be read.
# RETURN CODES: 0 = read succeeded. 2 = BUDGET EXPIRED (no cap left, or `timeout`
# killed the call — exit 124). 1 = the read genuinely FAILED. Callers must map 2 to
# PENDING and 1 to ERROR: "we ran out of time" and "it broke" are different facts,
# and reporting the first as the second states something false about the setup.

#
# The distinction is the whole point: an empty state means "no CodeRabbit check",
# which drives a TERMINAL NOT_CONFIGURED verdict, so erasing a failed read into an
# empty string would permanently skip a reviewer that is in fact installed.
#
# `gh pr checks` exits NON-ZERO as a matter of course (8 while pending, 1 when
# failing), so its exit status proves nothing. Nor does probing a DIFFERENT endpoint
# — `gh pr view` can succeed while the checks endpoint specifically fails. The only
# sound signals come from this call itself:
#   valid JSON on stdout                      -> read succeeded
#   empty stdout + quiet/known-benign stderr  -> read succeeded, no checks exist
#   empty stdout + any other stderr           -> read FAILED (fails closed)
#
# Returned state is one of:
#   "" (no CodeRabbit check present)
#   "pending" / "queued" / "in_progress"
#   "success" / "failure" / "neutral" / "skipped" / "timed_out" / "cancelled" / "action_required"
# `gh pr checks --json state` returns UPPER_CASE; lowercased here so the case
# statements below match canonical lower-case forms.
check_coderabbit_state() {
    local out err err_text cap rc=0
    # Compute the cap ONCE and reject zero before using it. Checking
    # `budget_exhausted` and then calling `wait_cap` separately is a TOCTOU: the
    # clock can tick between the two, so the guard sees 1s left and `timeout` is
    # then handed 0 — which in coreutils DISABLES the cap entirely.
    cap=$(wait_cap)
    if (( cap <= 0 )); then return 2; fi
    # A failed `mktemp` (unwritable or invalid TMPDIR) leaves $err empty, which makes
    # the redirect fail and every downstream read look like an empty result — i.e. it
    # would report NOT_CONFIGURED for a read that never happened. Treat it as a failed
    # read, which is what it is.
    if ! err=$(mktemp 2>/dev/null) || [[ -z "$err" ]]; then
        echo "Error: could not create a temporary file (check TMPDIR)." >&2
        return 1
    fi
    out=$(timeout "$cap" gh pr checks "$PR_NUMBER" --json name,state 2>"$err") || rc=$?
    if (( rc == 124 )); then rm -f "$err"; return 2; fi

    if printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1; then
        rm -f "$err"
        printf '%s' "$out" \
            | jq -r '.[] | select(.name == "CodeRabbit") | .state | ascii_downcase' \
            | head -1
        return 0
    fi

    if [[ -n "$out" ]]; then
        rm -f "$err"      # non-empty but not a JSON array — malformed, never guess
        return 1
    fi

    err_text=$(cat "$err"); rm -f "$err"
    if [[ -z "${err_text//[[:space:]]/}" ]] || grep -qiE 'no checks reported' <<< "$err_text"; then
        return 0          # genuinely no checks on this PR
    fi
    printf '%s\n' "$err_text" >&2
    return 1
}

# Count unresolved CodeRabbit review threads via GraphQL.
#
# REPORTS HONESTLY. This deliberately carries no `|| echo "0"`: a transient API
# error previously became a literal `0`, which reads as "no unresolved threads" and
# would let a caller pass a gate on a read that never happened. A failed read prints
# `unknown` and returns non-zero; callers must branch on that, never on emptiness.
count_coderabbit_threads() {
    local owner repo
    owner="${REPO_NWO%%/*}"
    repo="${REPO_NWO##*/}"
    local dcap; dcap=$(diag_cap)
    if (( dcap <= 0 )); then return 1; fi
    timeout "$dcap" gh api graphql -f query="
    query {
      repository(owner: \"$owner\", name: \"$repo\") {
        pullRequest(number: $PR_NUMBER) {
          reviewThreads(first: 100) {
            nodes {
              isResolved
              comments(first: 1) { nodes { author { login } } }
            }
          }
        }
      }
    }" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and (.comments.nodes[0].author.login | tostring | contains("coderabbitai")))] | length' 2>/dev/null
}

is_terminal_state() {
    case "$1" in
        success|failure|neutral|skipped|timed_out|cancelled|action_required|error) return 0 ;;
        *) return 1 ;;
    esac
}

# A settled check is only a PASS if its conclusion is clean AND nothing is left open.
# `skipped`/`neutral` count as clean: CodeRabbit declining to review is not a finding.
is_passing_conclusion() {
    case "$1" in
        success|neutral|skipped) return 0 ;;
        *) return 1 ;;
    esac
}

# Report a settled check: emit its conclusion, its unresolved-thread count, and the
# resulting verdict. Threads that cannot be read are reported as `unknown` and do NOT
# silently pass — an unread count is not a zero count.
report_terminal() {
    local conclusion="$1" threads verdict
    # The wait is over; everything below is REPORTING. Arm the one shared tail.
    arm_diagnostic_budget

    if threads=$(count_coderabbit_threads); then
        :
    else
        threads="unknown"
    fi

    echo "CHECK_CONCLUSION=${conclusion}"
    echo "UNRESOLVED_THREADS=${threads}"

    if ! is_passing_conclusion "$conclusion"; then
        verdict=TERMINAL_FAIL
    elif [[ "$threads" == "unknown" ]]; then
        echo "The unresolved-thread read FAILED, so this script cannot confirm the PR is clean."
        echo "Treating as TERMINAL_FAIL: verify the threads yourself before any merge gate."
        verdict=TERMINAL_FAIL
    elif [[ "$threads" -gt 0 ]]; then
        verdict=TERMINAL_FAIL
    else
        verdict=TERMINAL_PASS
    fi

    finish "$verdict"
}

echo "Checking PR #${PR_NUMBER} for CodeRabbit review (budget: ${TIMEOUT}s wall clock)..."


read_rc=0
initial_state=$(check_coderabbit_state) || read_rc=$?
if (( read_rc == 2 )); then
    echo "Budget expired before the check could be read — nothing was observed."
    finish PENDING
fi
if (( read_rc != 0 )); then
    echo "Error: could not read the checks of PR #${PR_NUMBER} — the API read FAILED." >&2
    echo "Whether CodeRabbit is configured is UNKNOWN; refusing to guess." >&2
    finish ERROR
fi

if [[ -z "$initial_state" ]]; then
    # The App auto-runs but with a short startup delay, so one immediate miss is not
    # evidence of anything. Wait out the grace period once, then decide — and decide
    # TERMINALLY. Most repos do not have CodeRabbit installed; burning the full
    # budget to discover that would make the common case the most expensive one.
    # Derive the grace from the budget REMAINING, not from the original TIMEOUT.
    # The initial read above already consumed some of it, so capping against TIMEOUT
    # could sleep past the deadline — after which the next read's own budget guard
    # fails and reports ERROR, when the honest answer is the deadline result.
    grace=$NOT_CONFIGURED_GRACE
    remaining=$(wait_cap)
    if (( grace > remaining )); then
        grace=$remaining
    fi
    if (( grace > 0 )); then
        echo "No CodeRabbit check yet; waiting ${grace}s for it to appear..."
        sleep "$grace"
    fi
    # Only re-read if there is still budget for it. Past the deadline the honest
    # answer is PENDING — we never observed enough to say anything terminal.
    if budget_exhausted; then
        echo ""
        echo "Budget expired before the CodeRabbit check could be observed."
        echo "This is NOT a verdict: nothing was seen either way."
        finish PENDING
    fi
    read_rc=0
    initial_state=$(check_coderabbit_state) || read_rc=$?
    if (( read_rc == 2 )); then
        echo "Budget expired before the check could be read — nothing was observed."
        finish PENDING
    fi
    if (( read_rc != 0 )); then
        echo "Error: could not read the checks of PR #${PR_NUMBER} — the API read FAILED." >&2
        echo "Whether CodeRabbit is configured is UNKNOWN; refusing to guess." >&2
        finish ERROR
    fi
    if [[ -z "$initial_state" ]]; then
        # Reaching here means the read SUCCEEDED and reported no CodeRabbit check —
        # check_coderabbit_state() already separated that from a failed read, so this
        # verdict is safe to make terminal.
        echo "No CodeRabbit check present on PR #${PR_NUMBER} after ${SECONDS}s."
        echo "The CodeRabbit GitHub App is not configured for this repository."
        echo "This is TERMINAL and expected for most repos — do NOT retry or wait."
        finish NOT_CONFIGURED
    fi
fi

if is_terminal_state "$initial_state"; then
    echo "CodeRabbit check already settled: ${initial_state}"
    report_terminal "$initial_state"
fi

echo "CodeRabbit check is ${initial_state}. Polling every ${POLL_INTERVAL}s..."

while (( SECONDS < TIMEOUT )); do
    # Never sleep past the deadline — that is what turns a 900 s budget into 930 s.
    remaining=$(( TIMEOUT - SECONDS ))
    nap=$POLL_INTERVAL
    if (( nap > remaining )); then
        # NB: `(( ... )) && nap=...` would exit under `set -e` whenever the test is
        # false, i.e. on every normal poll. Keep this as an `if`.
        nap=$remaining
    fi
    sleep "$nap"

    # RECHECK THE DEADLINE BEFORE SPENDING ANOTHER API ROUND-TRIP. Without this, a
    # sleep that consumes the last of the budget is still followed by a `gh` call,
    # so a slow request runs past the deadline and can even return TERMINAL_PASS
    # after it — reporting a settled verdict the budget said we would not wait for.
    if (( SECONDS >= TIMEOUT )); then
        break
    fi

    # A failed read is not "still pending" — say so and keep polling rather than
    # counting an unobserved poll as evidence.
    read_rc=0
    state=$(check_coderabbit_state) || read_rc=$?
    if (( read_rc == 2 )); then break; fi   # budget expired -> the loop ends as PENDING
    if (( read_rc != 0 )); then
        echo "  Warning: could not read the checks of PR #${PR_NUMBER} this poll (API read failed)."
        echo "           This poll observed NOTHING; it is not evidence about the check's state."
        continue
    fi

    if is_terminal_state "${state:-}"; then
        echo "CodeRabbit check settled after ${SECONDS}s: ${state}"
        report_terminal "$state"
    fi

    echo "  Waiting... (${SECONDS}s / ${TIMEOUT}s, state=${state:-pending})"
done

echo ""
echo "The CodeRabbit check had not settled within ${TIMEOUT}s (${SECONDS}s wall clock)."
echo "This is NOT a verdict and NOT a failure — the check is still running."
echo "Re-run to keep waiting. Never record this as 'no findings'."
finish PENDING
