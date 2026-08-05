#!/usr/bin/env bash
# wait-for-copilot-review.sh
# Polls a PR for Copilot review completion with timeout
#
# Usage: ./wait-for-copilot-review.sh <PR_NUMBER> [TIMEOUT_SECONDS]
# Default timeout: 900 seconds (15 minutes)
#
# Exit codes:
#   0 - Copilot review received FOR THE CURRENT HEAD COMMIT
#   1 - Timeout waiting for review
#   2 - No Copilot review requested for the current head commit (caller must
#       request one, then re-run) — this includes the case where a review exists
#       but only for an OLDER commit
#   3 - Invalid arguments or gh error
#
# HEAD-SHA AWARENESS (do not remove):
#   Copilot does NOT re-review automatically when new commits are pushed, unless
#   the repo has a ruleset with "review new pushes" enabled. A version of this
#   script that matched *any* Copilot review on the PR therefore exited 0
#   immediately after a fix was pushed, reporting a review of the PREVIOUS commit
#   as coverage for the new one — which let callers conclude "no new feedback"
#   about code no reviewer had ever seen. Every check below is scoped to the
#   current head SHA for that reason.

set -euo pipefail

MIN_GH_VERSION="2.50.0"

PR_NUMBER="${1:-}"
TIMEOUT="${2:-900}"
POLL_INTERVAL=60

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: $0 <PR_NUMBER> [TIMEOUT_SECONDS]" >&2
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
#   REST requested_reviewers: login="Copilot"
#   REST /reviews:            login="copilot-pull-request-reviewer[bot]"
#   gh pr view --json:        login="copilot-pull-request-reviewer" (no [bot] suffix)
COPILOT_BOT_ID="BOT_kgDOCnlnWA"

# Get repo owner/name for REST API calls
REPO_NWO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
if [[ -z "$REPO_NWO" ]]; then
    echo "Error: Could not determine repository" >&2
    exit 3
fi

echo "Checking PR #${PR_NUMBER} for Copilot review..."

# The commit a review must cover to count. Re-read on every poll, so a push that
# lands mid-wait moves the target instead of being satisfied by a stale review.
current_head_sha() {
    gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid' 2>/dev/null || true
}

# Check if Copilot review was requested (must use REST API — gh pr view returns empty for bots)
check_review_requested() {
    gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}" --jq \
        '.requested_reviewers[] | select(.login == "Copilot" or .node_id == "BOT_kgDOCnlnWA") | .login' 2>/dev/null || true
}

# Copilot reviews of a SPECIFIC commit. REST /reviews rather than
# `gh pr view --json reviews`, because only REST exposes `commit_id` — without it
# there is no way to tell a review of this push from a review of the last one.
check_review_submitted() {
    local sha="$1"
    gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" --jq \
        "[.[] | select(.user.login | startswith(\"copilot-pull-request-reviewer\")) | select(.commit_id == \"${sha}\") | .state] | first // empty" \
        2>/dev/null || true
}

# Copilot reviews of any EARLIER commit, used only to explain an exit 2: "Copilot
# reviewed this PR, but not this code" is a very different situation from "Copilot
# has never looked at this PR", and the caller's next action is the same either
# way (request a review) but the report should not be misleading.
check_stale_review() {
    local sha="$1"
    gh api "/repos/${REPO_NWO}/pulls/${PR_NUMBER}/reviews" --jq \
        "[.[] | select(.user.login | startswith(\"copilot-pull-request-reviewer\")) | select(.commit_id != \"${sha}\") | .commit_id] | last // empty" \
        2>/dev/null || true
}

# Count unresolved Copilot review threads via GraphQL
count_copilot_threads() {
    local owner repo
    owner="${REPO_NWO%%/*}"
    repo="${REPO_NWO##*/}"
    local result
    result=$(gh api graphql -f query="
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
    }" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false and .comments.nodes[0].author.login == "copilot-pull-request-reviewer")] | length' 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "Error querying review threads: $result" >&2
        echo "0"
        return
    fi
    echo "$result"
}

head_sha=$(current_head_sha)
if [[ -z "$head_sha" ]]; then
    echo "Error: Could not determine the head commit of PR #${PR_NUMBER}" >&2
    exit 3
fi
echo "Head commit: ${head_sha:0:7}"

# Initial check - is Copilot review requested?
requested=$(check_review_requested)
submitted=$(check_review_submitted "$head_sha")

# If this commit has already been reviewed, report threads and exit
if [[ -n "$submitted" ]]; then
    echo "Copilot review already present for ${head_sha:0:7} (state: ${submitted})"
    thread_count=$(count_copilot_threads)
    echo "Unresolved Copilot threads: $thread_count"
    exit 0
fi

# If not requested, report and exit. A stale review does NOT satisfy this check.
if [[ -z "$requested" ]]; then
    stale=$(check_stale_review "$head_sha")
    if [[ -n "$stale" ]]; then
        echo "Copilot reviewed ${stale:0:7}, but NOT the current head ${head_sha:0:7}."
        echo "Copilot does not re-review pushed commits on its own — request a new review."
    else
        echo "No Copilot review requested on PR #${PR_NUMBER}"
    fi
    echo "To request via API (recommended): gh api --method POST /repos/{owner}/{repo}/pulls/${PR_NUMBER}/requested_reviewers -f 'reviewers[]=copilot-pull-request-reviewer[bot]'"
    echo "See: https://github.com/cli/cli/issues/10598#issuecomment-2893526162"
    exit 2
fi

echo "Copilot review requested. Polling for completion (timeout: ${TIMEOUT}s)..."

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
    fi

    submitted=$(check_review_submitted "$head_sha")

    if [[ -n "$submitted" ]]; then
        echo "Copilot review received for ${head_sha:0:7} after ${elapsed}s (state: ${submitted})"

        # Show summary of review
        echo ""
        echo "=== Copilot Review Summary ==="
        gh pr view "$PR_NUMBER" --json reviews --jq \
            '.reviews[] | select(.author.login | startswith("copilot-pull-request-reviewer")) | "State: \(.state)\nBody: \(.body)"' || echo "(failed to fetch review summary)"

        # Count unresolved review threads from Copilot via GraphQL
        thread_count=$(count_copilot_threads)
        echo "Unresolved Copilot threads: $thread_count"

        exit 0
    fi

    echo "  Waiting... (${elapsed}s / ${TIMEOUT}s)"
done

echo "Timeout: Copilot review not received within ${TIMEOUT}s"
exit 1
