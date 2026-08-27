#!/usr/bin/env bash
# run-codex-review.sh
# Runs a scoped, one-shot `codex review` of the current branch with every locally
# configured MCP server disabled.
#
# Usage:
#   ./run-codex-review.sh <SCOPE_PROMPT_FILE>
#   ./run-codex-review.sh -                  # read the scope prompt from stdin
#
# Env:
#   CODEX_REVIEW_OUT=<path>    also tee the review to this file
#   CODEX_REVIEW_DRY_RUN=1     print the resolved command and exit 0 without running
#   CODEX_REVIEW_MODEL=<id>    override the review model     (default below)
#   CODEX_REVIEW_EFFORT=<lvl>  override reasoning effort     (default below)
#
# MODEL AND EFFORT ARE OVERRIDDEN PER INVOCATION, NEVER IN THE USER'S CONFIG.
# `codex review` otherwise inherits `model` and `model_reasoning_effort` from
# ~/.codex/config.toml, and a reasoning-heavy default turns every pass into a 10-15
# minute wait — which makes the convergence loop unaffordable long before the
# iteration bound. Do NOT trade down for speed: a cheaper model reported "no
# blocking defect" on a branch where the default below found a genuine P1, and a
# reviewer that finishes fast by finding nothing is not faster. Raise effort to
# `high` when you want every site of a class enumerated and can afford ~3x the wait.
#
# ⛔ NO TIMEOUT. Codex is one-shot and a real branch review takes many minutes; it
#    also buffers, so the output file stays empty until it finishes. Run this in the
#    BACKGROUND (`run_in_background: true`) and let the completion notification wake
#    you. Do NOT poll the output file and do NOT chain sleeps waiting on it — polling
#    a buffered process teaches you nothing and costs a full context read per poll.
#
# Exit codes:
#   0 - Codex ran to completion. Its findings are on stdout; READ THEM. A zero exit
#       means the review ran, NOT that it found nothing.
#   3 - Usage error, `codex` missing, or the scope prompt was empty. The review
#       never started. (Deliberately not 1 or 2 — those are reserved by `codex`
#       itself, and conflating them would make "the reviewer failed" look like "the
#       reviewer had opinions".)
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS IS A SCRIPT
#
# Two things about `codex review` are easy to get wrong from prose, and both have
# cost real review cycles. The full analysis lives in the skill; the operational
# consequences are encoded here so they cannot be half-remembered.
#
# 1. THE SCOPE PROMPT IS MANDATORY, AND SCOPE FLAGS ARE MUTUALLY EXCLUSIVE WITH IT.
#    `codex review --base <BRANCH> "<PROMPT>"` is REJECTED:
#        error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'
#    The usage line prints that exact combination, which is why it keeps getting
#    tried. Since the brief must reach Codex — it is the only reviewer that can
#    receive it directly — the prompt-only form is the ONLY correct invocation, and
#    the changes must already be committed on a branch so Codex derives the diff
#    itself. A promptless run reports the work the change deliberately did not do.
#
# 2. MCP SERVERS MUST BE DISABLED INDIVIDUALLY, BY NAME.
#    A `codex review` that inherits the user's MCP servers can block indefinitely on
#    its first action, emitting nothing — observed twice on 0.147.0, each time
#    sitting 16+ minutes at ~0% CPU. There is no TTY to answer a stalled tool call
#    and `codex review` has no approval-policy flag, so the turn never advances.
#
#    `-c 'mcp_servers={}'` does NOT work — the map is merged, not replaced, so every
#    server stays loaded. It LOOKS like it worked, because a run that happens not to
#    call a tool shows no MCP output. Setting CODEX_HOME to a sanitized directory
#    does not work either.
#
#    Enumeration uses `codex mcp list --json`, never a `config.toml` scrape: servers
#    also arrive from project-scoped and managed configuration, and a scrape silently
#    misses those. That produces a PARTIAL flag set — the worst outcome, because the
#    command looks correct, most servers are disabled, and the one it missed hangs
#    the run exactly as before.
#
# These are per-invocation overrides. This script NEVER writes to ~/.codex/config.toml
# or ~/.codex/AGENTS.md — those are the user's, machine-wide, and a review has no
# business rewriting them.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# See the header: these are per-invocation overrides of the user's config.
CODEX_REVIEW_MODEL="${CODEX_REVIEW_MODEL:-gpt-5.6-terra}"
CODEX_REVIEW_EFFORT="${CODEX_REVIEW_EFFORT:-medium}"

PROMPT_SRC="${1:-}"

if [[ -z "$PROMPT_SRC" ]]; then
    echo "Usage: $0 <SCOPE_PROMPT_FILE>|-" >&2
    echo "" >&2
    echo "The scope prompt is MANDATORY. Build it per fx-dev:review Step 1." >&2
    echo "A Codex run without one is an incomplete pass — rerun it with a prompt" >&2
    echo "rather than filtering its output by hand." >&2
    exit 3
fi

if ! command -v codex >/dev/null 2>&1; then
    echo "Error: \`codex\` is not on PATH. The review never started." >&2
    exit 3
fi

if [[ "$PROMPT_SRC" == "-" ]]; then
    SCOPE_PROMPT=$(cat)
else
    if [[ ! -r "$PROMPT_SRC" ]]; then
        echo "Error: scope prompt file not readable: $PROMPT_SRC" >&2
        exit 3
    fi
    SCOPE_PROMPT=$(cat "$PROMPT_SRC")
fi

if [[ -z "${SCOPE_PROMPT//[[:space:]]/}" ]]; then
    echo "Error: the scope prompt is empty. Refusing to run a promptless review," >&2
    echo "which would report the work this change deliberately did not do." >&2
    exit 3
fi

# ── Project-conventions bridge ───────────────────────────────────────────────
# Codex reads AGENTS.md. It does NOT read REVIEW.md or CLAUDE.md — it is the one
# reviewer that needs a pointer. Report a missing bridge and continue on defaults;
# do NOT run fx-dev:setup or fx-dev:upgrade from here.
if grep -q "## Code Review Rules" AGENTS.md 2>/dev/null; then
    echo "AGENTS.md -> REVIEW.md pointer: present"
else
    echo "WARNING: no '## Code Review Rules' section in AGENTS.md."
    echo "         Codex cannot see REVIEW.md, so it will review on defaults."
    echo "         Fix separately with fx-dev:setup (new repo) or fx-dev:upgrade"
    echo "         (legacy layout) — not from this review."
    echo "         If Codex flags something REVIEW.md explicitly permits, this is why:"
    echo "         say so rather than silently applying the finding."
fi

# ── Disable every locally configured MCP server, individually, by name ───────
MCP_OFF=()
MCP_NAMES=()

# ENUMERATION FAILURE IS NOT "no servers". If `codex mcp list` or `jq` fails and we
# treat the empty result as an empty server list, the script runs `codex review`
# with NO disable flags — on a machine that has servers configured, that reproduces
# exactly the indefinite hang this script exists to prevent, while printing a
# reassuring "0 servers disabled". Separate the two: a failed enumeration is a setup
# failure and exits 3; a successful enumeration returning nothing is fine.
if ! mcp_json=$(codex mcp list --json 2>/dev/null); then
    echo "Error: \`codex mcp list --json\` FAILED, so the set of MCP servers to disable" >&2
    echo "is UNKNOWN. Refusing to run: with servers configured but not disabled, the" >&2
    echo "review can block indefinitely on its first action, emitting nothing." >&2
    exit 3
fi

if ! mcp_names=$(printf '%s' "$mcp_json" | jq -r '.[].name' 2>/dev/null); then
    echo "Error: could not parse \`codex mcp list --json\` output, so the set of MCP" >&2
    echo "servers to disable is UNKNOWN. Refusing to run — see above." >&2
    exit 3
fi

# A server name is a TOML KEY SEGMENT, and only [A-Za-z0-9_-] may appear bare. A
# name containing a dot — `acme.review` — pasted in raw builds
# `mcp_servers.acme.review.enabled`, which is a NESTED PATH, not that server: the
# server stays enabled and can hang the run this script exists to protect. Quote and
# escape anything that is not a bare key.
#
# The quoted form follows the TOML spec for quoted key segments. It has been checked
# against this function's output but NOT exercised end-to-end against a real server
# whose name needs quoting — none was available. If `codex` ever rejects a `-c` with
# a quoted segment, that is where to look; the bare-name path is unaffected.
toml_key() {
    local k="$1"
    if [[ "$k" =~ ^[A-Za-z0-9_-]+$ ]]; then
        printf '%s' "$k"
    else
        k=${k//\\/\\\\}     # backslashes first
        k=${k//\"/\\\"}     # then quotes
        printf '"%s"' "$k"
    fi
}

if [[ -n "$mcp_names" ]]; then
    while IFS= read -r name; do
        if [[ -n "$name" ]]; then
            MCP_NAMES+=("$name")
            MCP_OFF+=(-c "mcp_servers.$(toml_key "$name").enabled=false")
        fi
    done <<< "$mcp_names"
fi

# Echo the resolved flag set so a PARTIAL one is visible. A partial set is the worst
# outcome — the command looks correct, most servers are disabled, and the one it
# missed hangs the run exactly as before.
echo "MCP servers disabled for this run: ${#MCP_NAMES[@]}"
if (( ${#MCP_NAMES[@]} == 0 )); then
    echo "  (enumeration succeeded and reported no configured servers)"
else
    printf '  disabled: %s\n' "${MCP_NAMES[@]}"
fi

# Codex may also expose its own hosted tools not declared in config.toml; those
# survive this and are expected to. The hazard is the locally-configured servers.

MODEL_OPTS=(-c "model=${CODEX_REVIEW_MODEL}" -c "model_reasoning_effort=${CODEX_REVIEW_EFFORT}")
echo "Model: ${CODEX_REVIEW_MODEL}  Effort: ${CODEX_REVIEW_EFFORT}"

if [[ -n "${CODEX_REVIEW_DRY_RUN:-}" ]]; then
    echo ""
    echo "DRY RUN — resolved command:"
    echo "  codex review ${MCP_OFF[*]} ${MODEL_OPTS[*]} <SCOPE_PROMPT (${#SCOPE_PROMPT} chars)>"
    exit 0
fi

echo ""
echo "Running codex review (one-shot, no timeout — this takes many minutes)..."
echo ""

if [[ -n "${CODEX_REVIEW_OUT:-}" ]]; then
    codex review "${MCP_OFF[@]}" "${MODEL_OPTS[@]}" "$SCOPE_PROMPT" | tee "$CODEX_REVIEW_OUT"
else
    codex review "${MCP_OFF[@]}" "${MODEL_OPTS[@]}" "$SCOPE_PROMPT"
fi
