#!/usr/bin/env bash
# wait-for-coderabbit-review.sh
# Polls a PR for CodeRabbit review completion via the "CodeRabbit" GitHub
# check context. CodeRabbit auto-runs on every PR (no request needed) and
# re-runs every time the head SHA changes — so this script is also used to
# wait for re-review cycles after pushing fixes.
#
# Usage: ./wait-for-coderabbit-review.sh <PR_NUMBER> [TIMEOUT_SECONDS]
# Default timeout: 1200 seconds (20 minutes)
#
# Exit codes:
#   0 - CodeRabbit check completed (terminal state). Stdout reports the
#       conclusion (success|failure|skipped) and the unresolved-thread count.
#   1 - Timeout waiting for CodeRabbit check to reach a terminal state
#   2 - No CodeRabbit check found on the PR (CodeRabbit not configured)
#   3 - Invalid arguments or gh error

set -euo pipefail

MIN_GH_VERSION="2.50.0"

PR_NUMBER="${1:-}"
TIMEOUT="${2:-1200}"
POLL_INTERVAL=30

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: $0 <PR_NUMBER> [TIMEOUT_SECONDS]" >&2
    exit 3
fi

# Verify gh version (--json flag on pr view requires 2.50+)
gh_version=$(gh --version | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
if ! printf '%s\n' "$MIN_GH_VERSION" "$gh_version" | sort -V | head -1 | grep -q "^${MIN_GH_VERSION}$"; then
    echo "Error: gh CLI version $gh_version is too old. Minimum required: $MIN_GH_VERSION" >&2
    echo "Upgrade with: mise use -g gh@latest" >&2
    exit 3
fi

REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
if [[ -z "$REPO_NWO" ]]; then
    echo "Error: Could not determine repository" >&2
    exit 3
fi

# Return the CodeRabbit check's state as one of:
#   "" (not present yet)
#   "pending" / "queued" / "in_progress"
#   "success" / "failure" / "neutral" / "skipped" / "timed_out" / "cancelled" / "action_required"
#
# `gh pr checks --json state` returns UPPER_CASE values (SUCCESS, FAILURE,
# PENDING, ...). Lowercase here so the case statement in is_terminal_state
# matches against canonical lower-case forms.
check_coderabbit_state() {
    gh pr checks "$PR_NUMBER" --json name,state 2>/dev/null \
        | jq -r '.[] | select(.name == "CodeRabbit") | .state | ascii_downcase' \
        | head -1
}

# Count unresolved CodeRabbit review threads via GraphQL.
count_coderabbit_threads() {
    local owner repo
    owner="${REPO_NWO%%/*}"
    repo="${REPO_NWO##*/}"
    gh api graphql -f query="
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
    }" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and (.comments.nodes[0].author.login | tostring | contains("coderabbitai")))] | length' 2>/dev/null || echo "0"
}

is_terminal_state() {
    case "$1" in
        success|failure|neutral|skipped|timed_out|cancelled|action_required|error) return 0 ;;
        *) return 1 ;;
    esac
}

echo "Checking PR #${PR_NUMBER} for CodeRabbit review..."

initial_state=$(check_coderabbit_state || true)

if [[ -z "$initial_state" ]]; then
    # CodeRabbit may not have started yet (it auto-runs but with a small delay).
    # Wait once and re-check before declaring it absent.
    sleep "$POLL_INTERVAL"
    initial_state=$(check_coderabbit_state || true)
    if [[ -z "$initial_state" ]]; then
        echo "No CodeRabbit check present on PR #${PR_NUMBER}."
        echo "If CodeRabbit is configured, it should appear automatically; otherwise this is expected."
        exit 2
    fi
fi

if is_terminal_state "$initial_state"; then
    threads=$(count_coderabbit_threads)
    echo "CodeRabbit check already in terminal state: ${initial_state}"
    echo "Unresolved CodeRabbit threads: ${threads}"
    exit 0
fi

echo "CodeRabbit check is ${initial_state}. Polling for completion (timeout: ${TIMEOUT}s)..."

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))

    state=$(check_coderabbit_state || true)

    if is_terminal_state "${state:-}"; then
        threads=$(count_coderabbit_threads)
        echo "CodeRabbit check reached terminal state after ${elapsed}s: ${state}"
        echo "Unresolved CodeRabbit threads: ${threads}"
        exit 0
    fi

    echo "  Waiting... (${elapsed}s / ${TIMEOUT}s, state=${state:-pending})"
done

echo "Timeout: CodeRabbit check did not reach a terminal state within ${TIMEOUT}s"
exit 1
