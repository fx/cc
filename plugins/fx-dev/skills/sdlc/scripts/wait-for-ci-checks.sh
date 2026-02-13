#!/usr/bin/env bash
# wait-for-ci-checks.sh
# Polls a PR for CI check completion with timeout
#
# Usage: ./wait-for-ci-checks.sh <PR_NUMBER> [TIMEOUT_SECONDS]
# Default timeout: 900 seconds (15 minutes)
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed
#   2 - Timeout waiting for checks to complete
#   3 - Invalid arguments or gh error
#
# gh pr checks --json fields: bucket, completedAt, description, event,
#   link, name, startedAt, state, workflow
# state values: SUCCESS, FAILURE, PENDING, SKIPPED, STARTUP_FAILURE,
#   STALE, ERROR, EXPECTED, REQUESTED, WAITING, QUEUED, IN_PROGRESS
# bucket values: pass, fail, skipping, pending

set -euo pipefail

PR_NUMBER="${1:-}"
TIMEOUT="${2:-900}"
POLL_INTERVAL=30

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: $0 <PR_NUMBER> [TIMEOUT_SECONDS]" >&2
    exit 3
fi

# Verify gh is available and authenticated
if ! gh auth status &>/dev/null; then
    echo "Error: gh is not authenticated" >&2
    exit 3
fi

echo "Monitoring CI checks for PR #${PR_NUMBER}..."

# Get check statuses as JSON array
get_checks() {
    gh pr checks "$PR_NUMBER" --json name,state,bucket 2>/dev/null || echo "[]"
}

# Count checks by bucket (pass, fail, skipping, pending)
count_by_bucket() {
    local json="$1"
    local bucket="$2"
    echo "$json" | jq -r "[.[] | select(.bucket == \"$bucket\")] | length" 2>/dev/null || echo "0"
}

# --- Phase 1: Wait for checks to appear ---
echo "Phase 1: Waiting for checks to start..."

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
    checks=$(get_checks)
    total=$(echo "$checks" | jq 'length' 2>/dev/null || echo "0")

    if [[ "$total" -gt 0 ]]; then
        echo "Found $total check(s). Monitoring for completion..."
        break
    fi

    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
    echo "  No checks yet... (${elapsed}s / ${TIMEOUT}s)"
done

if [[ "$total" -eq 0 ]]; then
    echo "Timeout: No CI checks appeared within ${TIMEOUT}s"
    exit 2
fi

# --- Phase 2: Wait for all checks to complete ---
echo ""
echo "Phase 2: Waiting for all checks to complete..."

while [[ $elapsed -lt $TIMEOUT ]]; do
    checks=$(get_checks)
    total=$(echo "$checks" | jq 'length' 2>/dev/null || echo "0")
    pending_count=$(count_by_bucket "$checks" "pending")

    echo "  Status: ${pending_count} pending, $((total - pending_count)) completed (${elapsed}s / ${TIMEOUT}s)"

    if [[ "$pending_count" -eq 0 ]]; then
        # All checks have completed — analyze results
        echo ""
        echo "=== CI Check Results ==="

        failed_checks=$(count_by_bucket "$checks" "fail")
        passed_checks=$(count_by_bucket "$checks" "pass")
        skipped_checks=$(count_by_bucket "$checks" "skipping")

        echo "Total: $total | Passed: $passed_checks | Failed: $failed_checks | Skipped: $skipped_checks"
        echo ""

        # Show each check result
        echo "$checks" | jq -r '.[] | "  \(.state): \(.name)"' 2>/dev/null || true

        if [[ "$failed_checks" -eq 0 ]]; then
            echo ""
            echo "All CI checks passed."
            exit 0
        else
            echo ""
            echo "=== Failed Checks ==="
            echo "$checks" | jq -r '.[] | select(.bucket == "fail") | "  \(.state): \(.name)"' 2>/dev/null || true
            echo ""
            echo "$failed_checks check(s) failed."
            exit 1
        fi
    fi

    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
done

echo "Timeout: CI checks did not complete within ${TIMEOUT}s"
echo ""
echo "=== Current Status ==="
checks=$(get_checks)
echo "$checks" | jq -r '.[] | "  \(.bucket): \(.name) (\(.state))"' 2>/dev/null || true
exit 2
