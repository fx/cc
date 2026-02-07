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
    gh pr checks "$PR_NUMBER" --json name,state,conclusion 2>/dev/null || echo "[]"
}

# Count checks by state
count_by_state() {
    local json="$1"
    local state="$2"
    echo "$json" | jq -r "[.[] | select(.state == \"$state\")] | length" 2>/dev/null || echo "0"
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
    pending=$(count_by_state "$checks" "PENDING")
    in_progress=$(count_by_state "$checks" "IN_PROGRESS")
    queued=$(count_by_state "$checks" "QUEUED")
    incomplete=$((pending + in_progress + queued))

    echo "  Status: ${incomplete} pending, $((total - incomplete)) completed (${elapsed}s / ${TIMEOUT}s)"

    if [[ "$incomplete" -eq 0 ]]; then
        # All checks have completed — analyze results
        echo ""
        echo "=== CI Check Results ==="

        failed_checks=$(echo "$checks" | jq -r '[.[] | select(.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT" or .conclusion == "ACTION_REQUIRED")] | length' 2>/dev/null || echo "0")
        passed_checks=$(echo "$checks" | jq -r '[.[] | select(.conclusion == "SUCCESS" or .conclusion == "SKIPPED" or .conclusion == "NEUTRAL")] | length' 2>/dev/null || echo "0")

        echo "Total: $total | Passed: $passed_checks | Failed: $failed_checks"
        echo ""

        # Show each check result
        echo "$checks" | jq -r '.[] | "  \(.conclusion // "UNKNOWN"): \(.name)"' 2>/dev/null || true

        if [[ "$failed_checks" -eq 0 ]]; then
            echo ""
            echo "All CI checks passed."
            exit 0
        else
            echo ""
            echo "=== Failed Checks ==="
            echo "$checks" | jq -r '.[] | select(.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT" or .conclusion == "ACTION_REQUIRED") | "  \(.conclusion): \(.name)"' 2>/dev/null || true
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
echo "$checks" | jq -r '.[] | "  \(.state) (\(.conclusion // "pending")): \(.name)"' 2>/dev/null || true
exit 2
