#!/usr/bin/env bash
# wait-for-ci-checks.sh
# Polls a PR for CI check completion.
#
# Usage: ./wait-for-ci-checks.sh <PR_NUMBER> [TIMEOUT_SECONDS]
# Default timeout: 900 seconds (15 minutes).
#
# ⛔ RUN THIS IN THE BACKGROUND (`run_in_background: true`), redirecting stdout and
#    stderr to a log file. The Bash tool caps a FOREGROUND `timeout` at 600 000 ms,
#    which is BELOW this script's budget — a foreground call is guaranteed to be
#    killed mid-poll, printing no STATUS and no exit code. Backgrounded processes
#    are not subject to that cap.
#
# ─────────────────────────────────────────────────────────────────────────────
# STATUS PROTOCOL (shared by every fx-dev wait script)
#
# The LAST line of stdout is always `STATUS=<state>`, and the exit code mirrors it.
# Read the STATUS line; it is the primary signal.
#
#   STATUS=TERMINAL_PASS   exit 0  Every check completed and none failed.
#   STATUS=TERMINAL_FAIL   exit 1  Every check completed and at least one failed.
#                                  Settled — fix the failures, do not re-run to get
#                                  a different answer.
#   STATUS=PENDING         exit 2  Checks still running when the budget expired. NOT
#                                  a verdict and NOT a failure. Re-running is safe.
#   STATUS=NOT_CONFIGURED  exit 3  No checks appeared within the discovery grace
#                                  period — this PR has no CI configured to run on
#                                  it. TERMINAL; do not wait out the full budget.
#                                  ⚠️ This is NOT a pass. A merge gate requiring
#                                  green CI is NOT satisfied by the absence of CI.
#   STATUS=ERROR           exit 4  Bad arguments, `gh` too old or unauthenticated,
#                                  or the checks API could not be read. The wait
#                                  never started, or its reads cannot be trusted.
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
#   CHECKS_TOTAL=<n>  CHECKS_PASSED=<n>  CHECKS_FAILED=<n>  CHECKS_SKIPPED=<n>
#
# gh pr checks --json fields: bucket, completedAt, description, event,
#   link, name, startedAt, state, workflow
# state values: SUCCESS, FAILURE, PENDING, SKIPPED, STARTUP_FAILURE,
#   STALE, ERROR, EXPECTED, REQUESTED, WAITING, QUEUED, IN_PROGRESS
# bucket values: pass, fail, skipping, pending

set -euo pipefail

MIN_GH_VERSION="2.50.0"

DEFAULT_TIMEOUT=900
POLL_INTERVAL=30

# How long to wait for ANY check to appear before concluding none are configured.
# Checks normally register within seconds; this is deliberately generous so a slow
# webhook is never mistaken for an absent CI setup.
NOT_CONFIGURED_GRACE=90

PR_NUMBER="${1:-}"
TIMEOUT="${2:-$DEFAULT_TIMEOUT}"

# Emit the trailing STATUS line and exit with the matching code. Every exit path
# goes through here so the contract can never be partially honoured.
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
timeout "$preflight_cap" gh auth status &>/dev/null || preflight_rc=$?
if (( preflight_rc == 124 )); then
    echo "Budget expired during the auth check — nothing was observed."
    finish PENDING
fi
if (( preflight_rc != 0 )); then
    echo "Error: gh is not authenticated" >&2
    finish ERROR
fi

# Verify gh version meets minimum requirement (--json flag on pr checks requires 2.50+)
gh_version=$(gh --version | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
if ! printf '%s\n' "$MIN_GH_VERSION" "$gh_version" | sort -V | head -1 | grep -q "^${MIN_GH_VERSION}$"; then
    echo "Error: gh CLI version $gh_version is too old. Minimum required: $MIN_GH_VERSION" >&2
    echo "Upgrade with: mise use -g gh@latest" >&2
    finish ERROR
fi


# Emit the checks array, or return non-zero if it could not be read.
# RETURN CODES: 0 = read succeeded. 2 = BUDGET EXPIRED (no cap left, or `timeout`
# killed the call — exit 124). 1 = the read genuinely FAILED. Callers must map 2 to
# PENDING and 1 to ERROR: "we ran out of time" and "it broke" are different facts,
# and reporting the first as the second states something false about the setup.

#
# `gh pr checks` exits NON-ZERO as a matter of course — 8 while checks are pending,
# 1 when any check failed — so its exit status says nothing about whether the read
# succeeded. Nor can a probe of a DIFFERENT endpoint stand in: `gh pr view` can
# succeed while the checks endpoint specifically fails, and inferring "no checks"
# from that would be the same failed-read-as-empty defect one level removed.
#
# The only sound signals come from this call itself:
#   valid JSON on stdout                      -> the read succeeded
#   empty stdout + quiet/known-benign stderr  -> the read succeeded, no checks exist
#   empty stdout + any other stderr           -> the read FAILED
# The last case fails closed on purpose: an unrecognised message is treated as an
# error rather than as an empty result.
get_checks() {
    local out err cap rc=0
    # Compute the cap ONCE and reject zero before using it. Checking
    # `budget_exhausted` and then calling `wait_cap` separately is a TOCTOU: the
    # clock can tick between the two, so the guard sees 1s left and `timeout` is
    # then handed 0 — which in coreutils DISABLES the cap entirely and lets a hung
    # call run forever. One read of the clock, one decision, one value used.
    cap=$(wait_cap)
    if (( cap <= 0 )); then return 2; fi
    # A failed `mktemp` (unwritable or invalid TMPDIR) leaves $err empty, which makes
    # the redirect fail and every downstream read look like an empty result — i.e. it
    # would report "no checks" for a read that never happened. Treat it as a failed
    # read, which is what it is.
    if ! err=$(mktemp 2>/dev/null) || [[ -z "$err" ]]; then
        echo "Error: could not create a temporary file (check TMPDIR)." >&2
        return 1
    fi
    out=$(timeout "$cap" gh pr checks "$PR_NUMBER" --json name,state,bucket 2>"$err") || rc=$?
    if (( rc == 124 )); then rm -f "$err"; return 2; fi

    if printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1; then
        rm -f "$err"
        printf '%s' "$out"
        return 0
    fi

    if [[ -n "$out" ]]; then
        # Non-empty but not a JSON array — malformed. Never guess.
        rm -f "$err"
        return 1
    fi

    local err_text
    err_text=$(cat "$err"); rm -f "$err"
    if [[ -z "${err_text//[[:space:]]/}" ]] || grep -qiE 'no checks reported' <<< "$err_text"; then
        printf '[]'
        return 0
    fi
    printf '%s\n' "$err_text" >&2
    return 1
}

# Count checks in a bucket (pass, fail, skipping, pending).
count_by_bucket() {
    local json="$1" bucket="$2"
    printf '%s' "$json" | jq -r "[.[] | select(.bucket == \"$bucket\")] | length"
}

echo "Monitoring CI checks for PR #${PR_NUMBER} (budget: ${TIMEOUT}s wall clock)..."


# Sleep for POLL_INTERVAL, or the remaining budget, whichever is smaller. Never sleep
# past the deadline. NB: `(( ... )) && nap=...` would exit under `set -e` whenever the
# test is false, i.e. on every normal poll — keep the `if`.
nap_until_deadline() {
    local deadline="$1" remaining nap
    remaining=$(( deadline - SECONDS ))
    if (( remaining <= 0 )); then return 0; fi
    nap=$POLL_INTERVAL
    if (( nap > remaining )); then
        nap=$remaining
    fi
    sleep "$nap"
}

# --- Phase 1: discovery — do any checks exist at all? ---
#
# Discovery is bounded by the CALLER'S budget as well as the grace: whichever is
# smaller wins. Bounding it by the grace alone would let a caller who passed
# TIMEOUT=5 still spend 90 s here, which breaks the advertised wall-clock contract.
DISCOVERY_DEADLINE=$NOT_CONFIGURED_GRACE
if (( DISCOVERY_DEADLINE > TIMEOUT )); then
    DISCOVERY_DEADLINE=$TIMEOUT
fi
echo "Phase 1: waiting up to ${DISCOVERY_DEADLINE}s for checks to start..."

total=0
while :; do
    read_rc=0
    checks=$(get_checks) || read_rc=$?
    if (( read_rc == 2 )); then
        echo "Budget expired before the checks could be read — nothing was observed."
        finish PENDING
    fi
    if (( read_rc != 0 )); then
        echo "Error: could not read CI checks for PR #${PR_NUMBER}." >&2
        echo "The API read FAILED — this is not the same as 'no checks exist'." >&2
        finish ERROR
    fi
    total=$(printf '%s' "$checks" | jq 'length')

    if (( total > 0 )); then
        echo "Found ${total} check(s) after ${SECONDS}s. Monitoring for completion..."
        break
    fi

    if (( SECONDS >= DISCOVERY_DEADLINE )); then
        break
    fi

    nap_until_deadline "$DISCOVERY_DEADLINE"
    if (( SECONDS < DISCOVERY_DEADLINE )); then
        echo "  No checks yet... (${SECONDS}s / ${DISCOVERY_DEADLINE}s discovery)"
    fi
done

if (( total == 0 )); then
    echo ""
    echo "No CI checks appeared on PR #${PR_NUMBER} within ${DISCOVERY_DEADLINE}s."
    echo "This PR has no CI configured to run on it. TERMINAL — do not keep waiting."
    echo "⚠️  This is NOT a pass. A merge gate that requires green CI is NOT satisfied"
    echo "    by the absence of CI; confirm that against the repo's branch protection."
    finish NOT_CONFIGURED
fi

# --- Phase 2: wait for every check to settle ---
echo ""
echo "Phase 2: waiting for all checks to complete..."

while (( SECONDS < TIMEOUT )); do
    # Branch on the RETURN CODE, exactly as Phase 1 does. `if ! ...` collapses
    # budget-expiry (2) into generic failure and would report a reachable,
    # authenticated setup as broken when the last read is killed at the deadline.
    read_rc=0
    checks=$(get_checks) || read_rc=$?
    if (( read_rc == 2 )); then break; fi   # budget expired -> loop ends as PENDING
    if (( read_rc != 0 )); then
        echo "Error: could not read CI checks for PR #${PR_NUMBER}." >&2
        echo "The API read FAILED — this is not the same as 'no checks exist'." >&2
        finish ERROR
    fi
    total=$(printf '%s' "$checks" | jq 'length')
    pending_count=$(count_by_bucket "$checks" "pending")

    # ⛔ AN EMPTY CHECK SET HERE IS NOT "everything passed".
    # Discovery already proved checks exist on this PR. If they have since vanished,
    # a new commit was almost certainly pushed and its workflows have not registered
    # yet. Falling through would give total=0, pending_count=0, failed_checks=0 and
    # emit TERMINAL_PASS — certifying a head that nothing has tested. Keep waiting
    # instead; the deadline still bounds it.
    if (( total == 0 )); then
        echo "  Checks vanished (likely a new push; workflows not registered yet) — waiting (${SECONDS}s / ${TIMEOUT}s)"
        nap_until_deadline "$TIMEOUT"
        continue
    fi

    echo "  Status: ${pending_count} pending, $((total - pending_count)) completed (${SECONDS}s / ${TIMEOUT}s)"

    if (( pending_count == 0 )); then
        echo ""
        echo "=== CI Check Results ==="

        failed_checks=$(count_by_bucket "$checks" "fail")
        passed_checks=$(count_by_bucket "$checks" "pass")
        skipped_checks=$(count_by_bucket "$checks" "skipping")

        printf '%s' "$checks" | jq -r '.[] | "  \(.state): \(.name)"'

        echo ""
        echo "CHECKS_TOTAL=${total}"
        echo "CHECKS_PASSED=${passed_checks}"
        echo "CHECKS_FAILED=${failed_checks}"
        echo "CHECKS_SKIPPED=${skipped_checks}"

        if (( failed_checks == 0 )); then
            echo ""
            echo "All CI checks passed."
            finish TERMINAL_PASS
        fi

        echo ""
        echo "=== Failed Checks ==="
        printf '%s' "$checks" | jq -r '.[] | select(.bucket == "fail") | "  \(.state): \(.name)"'
        echo ""
        echo "${failed_checks} check(s) failed."
        finish TERMINAL_FAIL
    fi

    nap_until_deadline "$TIMEOUT"
done

echo ""
echo "CI checks had not completed within ${TIMEOUT}s (${SECONDS}s wall clock)."
echo "This is NOT a verdict and NOT a failure — checks are still running."
echo ""
echo "=== Last observed status ==="
# Reported from the LAST POLL, not from a fresh read. An extra API call here would
# be spent after the deadline has already passed, so a slow or stuck request would
# push the run past its advertised budget and delay the STATUS line — the budget has
# to bound every read, including the diagnostic ones.
printf '%s' "$checks" | jq -r '.[] | "  \(.bucket): \(.name) (\(.state))"'
echo ""
echo "Re-run to keep waiting. Never record this as 'CI passed'."
finish PENDING
