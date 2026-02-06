#!/usr/bin/env bash
# wait-for-copilot-review.sh
# Polls a PR for Copilot review completion with timeout
#
# Usage: ./wait-for-copilot-review.sh <PR_NUMBER> [TIMEOUT_SECONDS]
# Default timeout: 600 seconds (10 minutes)
#
# Exit codes:
#   0 - Copilot review received
#   1 - Timeout waiting for review
#   2 - No Copilot review requested
#   3 - Invalid arguments or gh error

set -euo pipefail

PR_NUMBER="${1:-}"
TIMEOUT="${2:-600}"
POLL_INTERVAL=60

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: $0 <PR_NUMBER> [TIMEOUT_SECONDS]" >&2
    exit 3
fi

# Copilot's bot user ID
COPILOT_BOT_LOGIN="copilot-pull-request-reviewer[bot]"
COPILOT_BOT_ID="BOT_kgDOCnlnWA"

echo "Checking PR #${PR_NUMBER} for Copilot review..."

# Check if Copilot review was requested
check_review_requested() {
    gh pr view "$PR_NUMBER" --json reviewRequests --jq \
        ".reviewRequests[] | select(.login == \"$COPILOT_BOT_LOGIN\" or .name == \"$COPILOT_BOT_LOGIN\") | .login" 2>/dev/null || true
}

# Check if Copilot has submitted a review
check_review_submitted() {
    gh pr view "$PR_NUMBER" --json reviews --jq \
        ".reviews[] | select(.author.login == \"$COPILOT_BOT_LOGIN\") | .state" 2>/dev/null | head -1 || true
}

# Check for Copilot review comments (alternative detection)
check_review_comments() {
    gh pr view "$PR_NUMBER" --json reviewThreads --jq \
        ".reviewThreads[] | select(.comments[0].author.login == \"$COPILOT_BOT_LOGIN\") | .id" 2>/dev/null | head -1 || true
}

# Initial check - is Copilot review requested?
requested=$(check_review_requested)
submitted=$(check_review_submitted)
comments=$(check_review_comments)

# If already reviewed, exit immediately
if [[ -n "$submitted" ]] || [[ -n "$comments" ]]; then
    echo "Copilot review already present (state: ${submitted:-comments})"
    exit 0
fi

# If not requested, report and exit
if [[ -z "$requested" ]]; then
    echo "No Copilot review requested on PR #${PR_NUMBER}"
    echo "To request via API (recommended): gh api --method POST /repos/{owner}/{repo}/pulls/${PR_NUMBER}/requested_reviewers -f 'reviewers[]=copilot-pull-request-reviewer[bot]'"
    echo "See: https://github.com/cli/cli/issues/10598#issuecomment-2893526162"
    exit 2
fi

echo "Copilot review requested. Polling for completion (timeout: ${TIMEOUT}s)..."

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))

    submitted=$(check_review_submitted)
    comments=$(check_review_comments)

    if [[ -n "$submitted" ]] || [[ -n "$comments" ]]; then
        echo "Copilot review received after ${elapsed}s (state: ${submitted:-comments})"

        # Show summary of review
        echo ""
        echo "=== Copilot Review Summary ==="
        gh pr view "$PR_NUMBER" --json reviews --jq \
            ".reviews[] | select(.author.login == \"$COPILOT_BOT_LOGIN\") | \"State: \(.state)\nBody: \(.body)\"" 2>/dev/null || true

        # Count review threads from Copilot
        thread_count=$(gh pr view "$PR_NUMBER" --json reviewThreads --jq \
            "[.reviewThreads[] | select(.comments[0].author.login == \"$COPILOT_BOT_LOGIN\")] | length" 2>/dev/null || echo "0")
        echo "Review threads: $thread_count"

        exit 0
    fi

    echo "  Waiting... (${elapsed}s / ${TIMEOUT}s)"
done

echo "Timeout: Copilot review not received within ${TIMEOUT}s"
exit 1
