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
#    The launch shape, and the discipline that governs it — including never
#    backgrounding a launch your host has already backgrounded — are the `dev`
#    skill's `references/background-waits.md`, which is the only place either is
#    written down. What THIS script owes that discipline is the sentinel it is read
#    against, below.
#
# ─────────────────────────────────────────────────────────────────────────────
# COMPLETION CONTRACT
#
# The LAST line of stdout is always `STATUS=<state>`. A log with NO `STATUS=` tail
# is a RUNNING or DEAD run — never a finished one. Branch on that line, not on how
# much output the log happens to hold.
#
# "LAST" is load-bearing and is enforced, not hoped for: before the EXIT trap emits
# anything it terminates and confirms the death of every descendant that inherited the
# log's file descriptor, because `codex review` outlives a signalled runner and would
# otherwise append review prose after the sentinel. See `reap_descendants` below.
#
#   STATUS=COMPLETED  exit = codex's own, WHATEVER IT IS — not a fixed set. This
#                     script passes `PIPESTATUS[0]` through unchanged, so 126, 127
#                     and 137 are as reachable as 0/1/2 and none of them is given a
#                     meaning here. `codex review` ran to completion. Its findings
#                     are on stdout; READ THEM. Accompanied by a mandatory
#                     `CODEX_EXIT=<n>` line, which carries codex's status even when
#                     the exit code cannot — see the next paragraph.
#   STATUS=DRY_RUN    exit 0
#                     CODEX_REVIEW_DRY_RUN=1 — the resolved command was printed and
#                     no review ran.
#   STATUS=ERROR      exit 3 for the documented setup failures below; exit 4 from the
#                     EXIT trap on an internal abort; 128+N when signal N kills the
#                     runner (SIGTERM -> 143, SIGHUP -> 129) before the outcome is
#                     RECORDED — not necessarily before the review finished. Recording
#                     is a separate statement immediately after the pipeline returns
#                     (COMPLETION_EXIT="${pipe_status[0]}" below), so a signal landing
#                     in that single-assignment gap reports ERROR for a review that
#                     had, in fact, already finished. That gap is known and not
#                     closable in bash: trap dispatch happens between commands, and
#                     the only deferral primitive (`trap '' SIG`) discards the signal
#                     instead of queueing it. Outside that gap: the review never
#                     started, or the runner died mid-flight.
#
# A SIGNAL AFTER THE REVIEW FINISHED IS `COMPLETED`, AT 128+N. The two questions the
# two lines answer are different: the exit code says how the RUNNER died, `STATUS=`
# says whether the REVIEW finished. Between the pipeline returning and the sentinel
# being written there is a window — the `tee` WARNING, the `CODEX_EXIT=` line, the
# write itself — in which a signal kills a runner whose review is already complete and
# already in the log. That log gets `CODEX_EXIT=<codex's own>` and `STATUS=COMPLETED`
# at exit 128+N: findings to read, not a review to rerun. So `STATUS=COMPLETED` with
# an exit in 128+N is a normal, well-formed outcome, and it is the ONLY case where the
# exit code is not codex's own — which is why `CODEX_EXIT=` exists and why the caller
# reports that number rather than `$?`. The one exception is the outcome-recording
# statement itself: a signal landing there still reports `STATUS=ERROR` for a review
# that finished — see that row above.
#
# ⛔ THE ERROR EXIT CODE IS NOT A FIXED SET — WHICH IS EXACTLY WHY THE CALLER BRANCHES
# ON THE `STATUS=` LINE AND NOT ON THE NUMBER. The invariant that actually holds, and
# the only one worth depending on, is that `STATUS=ERROR` is emitted on EVERY one of
# those paths.
#
# `exit 4` in the EXIT trap is effective on the `set -e`/`set -u` abort path it exists
# for (verified), but it CANNOT override a signal-derived status: a signalled shell
# runs its EXIT trap — the STATUS line does get out — and still exits 128+N. Verified
# on TERM/HUP/USR1/USR2/PIPE. Do NOT "fix" this with a SIGTERM/SIGINT trap that forces
# 4: exiting 143 is correct Unix behaviour and strictly more informative than 4, the
# forcing would destroy that information, and it would buy nothing because the STATUS
# invariant above already holds. SIGKILL is the one case with no STATUS line at all —
# no trap can run — and that is precisely the "no `STATUS=` tail means running or
# dead" case the contract tells the caller to read.
#
# STATUS AND THE EXIT CODE ARE DECOUPLED ON PURPOSE. On COMPLETED the exit code is
# CODEX'S OWN — bar the signalled-after-completion case above, where the shell's 128+N
# wins and `CODEX_EXIT=` is the only place codex's status survives — and this script
# asserts NOTHING about it: `CODEX_EXIT=<n>` is reported and deliberately NOT
# interpreted, because a non-zero `codex review` exit does not distinguish "the
# reviewer failed" from "the reviewer had opinions" — read the findings to learn
# which. 3 and 4 are this script's own codes and are never codex's.
#
# Exit 3 covers exactly: a usage error, `codex` missing from PATH, an unreadable or
# empty scope prompt, and a failed MCP enumeration. Deliberately not 1 or 2 — those
# are reserved by `codex` itself, and conflating them would make "the reviewer
# failed" look like "the reviewer had opinions".
#
# WHY NOT THE FIVE-STATE PROTOCOL the polling waiters in this catalog use: there is
# no budget here and nothing can time out, so `PENDING` cannot occur; there is no
# configuration question to answer, so `NOT_CONFIGURED` cannot occur; and
# `TERMINAL_PASS`/`TERMINAL_FAIL` MUST NOT exist because this script HAS NO VERDICT
# — `TERMINAL_PASS` would be read as "no findings", which is the exact misread the
# exit-code notes above were written to prevent.
# ─────────────────────────────────────────────────────────────────────────────
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

# Emit the trailing STATUS line and exit with the matching code. Every exit path
# goes through here so the contract can never be partially honoured.
STATUS_EMITTED=0

# The review's outcome becomes a FACT the instant `pipe_status` is captured, but the
# sentinel is still several statements away — the `tee` WARNING block, the
# `CODEX_EXIT=` line, `finish` itself. A signal landing anywhere in that window used
# to make the EXIT trap write `STATUS=ERROR` for a review that HAD completed and
# whose findings were already in the log, telling the caller to rerun a review it
# already holds. That is the same contract inversion the `set -e` guard above the
# pipeline exists to prevent, reached through a different door.
#
# So the outcome is recorded the moment it is known, and the trap reports the record
# instead of guessing. Empty means "no completed review to report"; any other value is
# codex's own exit status. The recording is a bare assignment placed immediately after
# the `PIPESTATUS` capture and BEFORE anything that can block on I/O, because the
# window it closes is exactly the one where writing to a slow log leaves the process
# signallable.
COMPLETION_EXIT=""

# `CODEX_EXIT=` must accompany COMPLETED exactly once. Both the normal path and the
# trap can reach it — a signal landing between this line and `finish` runs the trap
# with the line already written — so route both through one emitter that remembers.
CODEX_EXIT_EMITTED=0

# Write the STATUS line, and report whether it actually got out.
#
# stdout can fail — the redirected log's filesystem fills, or its FD errors. Falling
# back to stderr is worth trying because every documented launch redirects `2>&1`
# into the same log, so the line still reaches the caller. The `&&` short-circuits:
# the stderr write is attempted ONLY if the stdout write failed, so the log can never
# carry a duplicate STATUS line.
emit_status() {
    echo "STATUS=$1" && return 0
    echo "STATUS=$1" >&2 && return 0
    return 1
}

# Write `CODEX_EXIT=<n>` at most once, from whichever path reaches it first. The flag
# is set ONLY after the write succeeded, for the same reason `STATUS_EMITTED` is: a
# failed write must not suppress the trap's second attempt. No stderr fallback — a
# duplicated `CODEX_EXIT=` is worse than a missing one, since the caller reports the
# number, and `STATUS=COMPLETED` alone still carries the contract.
emit_codex_exit() {
    if (( CODEX_EXIT_EMITTED == 0 )); then
        if echo "CODEX_EXIT=$1"; then CODEX_EXIT_EMITTED=1; fi
    fi
    return 0
}

# ⛔ THE SENTINEL MUST NOT BE WRITTEN WHILE A CHILD CAN STILL WRITE TO THE LOG.
#
# `codex review` is a FOREGROUND PIPELINE MEMBER, not a job: when a signal kills this
# shell, that child is neither signalled nor reaped, it keeps the log file descriptor
# it inherited, and it appends AFTER the EXIT trap's `STATUS=` line. The log's last
# line is then review prose, so a caller reading the tail classifies a run that DID
# finish as "running or dead" — the exact misread the whole contract exists to remove,
# reintroduced on the signal path. Observed, not theorised.
#
# So: terminate every descendant, CONFIRM it is gone, and only then emit.
#
# Two shell facts this is built on, both verified here rather than assumed:
#
#   1. `wait` IS USELESS ON THE SIGNAL PATH. In an EXIT trap reached because a signal
#      terminated the shell, bash has already discarded its job table: `wait` with no
#      operands returns 0 immediately with children still running, and `wait <pid>`
#      fails with "pid N is not a child of this shell". Verified — a child that
#      ignores SIGTERM wrote to the log AFTER a trap that had "waited" for it.
#      `kill -0` still answers correctly for those PIDs, so polling it is the only
#      mechanism that actually observes the death.
#   2. ENUMERATION MUST BE BY PID, NEVER BY PATTERN. `pgrep -P <pid>` matches on
#      parent PID and excludes itself; `pgrep -f 'codex review'` matches its own
#      command line and spins forever, which is the defect
#      `dev/references/background-waits.md` forbids outright.
#
# This is the script's one soft dependency: with `pgrep` absent the reap becomes a
# no-op and the late-write hazard returns. Verified that it degrades quietly — the
# STATUS line and the 128+N exit are unaffected, nothing is printed — rather than
# aborting the trap. `pgrep` ships with procps-ng on Linux and in the macOS base
# system, so the degraded path is a fallback, not a case to design around.
#
# Deepest-first so a kill never orphans a grandchild that is still writing: a child
# of `codex` inherits this shell's stderr, which every documented launch redirects
# into the same log.
descendants_deepest_first() {
    local pid="$1" kid
    for kid in $(pgrep -P "$pid" 2>/dev/null || true); do
        descendants_deepest_first "$kid"
        printf '%s\n' "$kid"
    done
}

# Every command here is guarded. `set -e` is still in force inside the EXIT trap, and
# an unguarded failure — `kill` on a PID that already exited is the likely one —
# would abort the trap BEFORE `emit_status`, leaving no STATUS line at all. Bash does
# not re-run an EXIT trap that aborted, so there is no second chance.
reap_descendants() {
    local pids pid alive i
    pids=$(descendants_deepest_first $$ 2>/dev/null || true)
    [[ -n "$pids" ]] || return 0

    for pid in $pids; do kill -TERM "$pid" 2>/dev/null || true; done

    # Bounded: ~4s. An unbounded poll would hang a runner that is already dying,
    # which is strictly worse than the SIGKILL escalation below.
    for ((i = 0; i < 40; i++)); do
        alive=""
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then alive="$alive $pid"; fi
        done
        [[ -n "$alive" ]] || return 0
        sleep 0.1 || true
    done

    # No confirm loop after SIGKILL, deliberately. It cannot be blocked, so the target
    # never executes another instruction — the write hazard is over the moment it is
    # delivered. Polling `kill -0` here would be worse than useless: a killed child we
    # are unable to reap (the job table is gone, see above) lingers as a zombie, and
    # `kill -0` reports a zombie as alive, so the loop would burn its whole bound on a
    # process that is already incapable of writing.
    for pid in $alive; do kill -KILL "$pid" 2>/dev/null || true; done
    return 0
}

# Report whatever was RECORDED, never what is guessed. Called only from the EXIT trap,
# and only after `reap_descendants` — nothing below may run while a child can still
# append to the log.
#
# `emit_status` is left unguarded on both branches, as it has always been: if both the
# stdout and the stderr write fail there is no way to honour the contract anyway, and
# `set -e` aborting the trap there is the existing behaviour, not a new one.
emit_recorded_outcome() {
    if [[ -n "$COMPLETION_EXIT" ]]; then
        # The review completed; only the sentinel was outstanding. Exit with codex's
        # own status to match `finish COMPLETED`. On the signal path that `exit` is
        # overridden by the shell's 128+N, which is correct and deliberate — see the
        # header: the exit code reports how the RUNNER died, the STATUS line reports
        # whether the REVIEW finished, and those are different questions.
        emit_codex_exit "$COMPLETION_EXIT"
        emit_status COMPLETED
        exit "$COMPLETION_EXIT"
    fi
    emit_status ERROR
    exit 4
}

# STRUCTURAL GUARANTEE: never exit without a STATUS line, never emit one a child can
# still write past, and never contradict a completion that already happened. `set -e`
# can abort at any unchecked command, and an abort that printed no STATUS would leave
# the caller with nothing to branch on — the exact failure mode the contract exists to
# remove. This trap turns any such abort into a well-formed sentinel, after silencing
# anything still holding the log.
trap 'if (( STATUS_EMITTED == 0 )); then reap_descendants; emit_recorded_outcome; fi' EXIT

finish() {
    local status="$1"
    # Mark it emitted ONLY after the write succeeded. Setting the flag first would
    # make a failed write look like a delivered STATUS and suppress the trap's
    # fallback — leaving the caller with no status line at all, which is precisely
    # what this contract exists to prevent.
    if emit_status "$status"; then STATUS_EMITTED=1; fi
    # ⛔ NOT a 1:1 status→exit map, unlike the polling waiters in this catalog:
    # COMPLETED PASSES CODEX'S OWN EXIT CODE THROUGH UNCHANGED via `$2`, which is the
    # whole point of the CODEX_EXIT contract in the header. Do not "simplify" this
    # back to a fixed code per status — that silently destroys the pass-through.
    case "$status" in
        COMPLETED) exit "${2:-0}" ;;
        DRY_RUN)   exit 0 ;;
        ERROR)     exit 3 ;;
        *)         exit 4 ;;
    esac
}

if [[ -z "$PROMPT_SRC" ]]; then
    echo "Usage: $0 <SCOPE_PROMPT_FILE>|-" >&2
    echo "" >&2
    echo "The scope prompt is MANDATORY. Build it per fx-dev:review Step 1." >&2
    echo "A Codex run without one is an incomplete pass — rerun it with a prompt" >&2
    echo "rather than filtering its output by hand." >&2
    finish ERROR
fi

if ! command -v codex >/dev/null 2>&1; then
    echo "Error: \`codex\` is not on PATH. The review never started." >&2
    finish ERROR
fi

if [[ "$PROMPT_SRC" == "-" ]]; then
    SCOPE_PROMPT=$(cat)
else
    if [[ ! -r "$PROMPT_SRC" ]]; then
        echo "Error: scope prompt file not readable: $PROMPT_SRC" >&2
        finish ERROR
    fi
    SCOPE_PROMPT=$(cat "$PROMPT_SRC")
fi

if [[ -z "${SCOPE_PROMPT//[[:space:]]/}" ]]; then
    echo "Error: the scope prompt is empty. Refusing to run a promptless review," >&2
    echo "which would report the work this change deliberately did not do." >&2
    finish ERROR
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
    finish ERROR
fi

if ! mcp_names=$(printf '%s' "$mcp_json" | jq -r '.[].name' 2>/dev/null); then
    echo "Error: could not parse \`codex mcp list --json\` output, so the set of MCP" >&2
    echo "servers to disable is UNKNOWN. Refusing to run — see above." >&2
    finish ERROR
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
    finish DRY_RUN
fi

echo ""
echo "Running codex review (one-shot, no timeout — this takes many minutes)..."
echo ""

# ⛔ THE PIPELINE MUST RUN UNDER `set +e`, AND `PIPESTATUS` MUST BE CAPTURED BY THE
# VERY NEXT STATEMENT. Two ways to get this wrong, both observed:
#
#   1. Leaving it under `set -e`. A non-zero `codex review` — which is ordinary, see
#      the header — aborts here, the EXIT trap fires, and the script reports
#      STATUS=ERROR for a review that DID complete. That inverts the contract. The
#      non-zero codex path MUST reach `finish COMPLETED`.
#   2. `... | tee "$OUT" || true` then reading `${PIPESTATUS[0]}`. ANY command after
#      the pipeline — `|| true` included — RESETS the array, so PIPESTATUS[0] is then
#      always 0 and every run looks like codex exited clean. Verified.
#
# Codex's status comes from pipe_status[0], NEVER from `$?`. Under `pipefail` `$?`
# collapses the whole pipeline into ONE number — the rightmost non-zero status — and
# that number carries no record of which command produced it. Verified: a clean
# `codex` plus an unwritable CODEX_REVIEW_OUT gives `$?`=1, and `codex` exiting 1
# through a healthy `tee` ALSO gives `$?`=1. Same number, opposite meanings — "the
# reviewer had opinions" and "the reviewer was clean but the file could not be
# written" are indistinguishable. `PIPESTATUS[0]` is the only way to attribute the
# status to codex specifically.
#
# `STATUS=`/`CODEX_EXIT=` reach stdout ONLY, never CODEX_REVIEW_OUT, because they are
# emitted AFTER the pipeline: `tee` sees only the pipeline's stdin. Keep it that way.
# CODEX_REVIEW_OUT is consumed as review TEXT, where a `STATUS=COMPLETED` line is
# prose pollution a reader or a downstream grep can mistake for a finding; stdout is
# the wait log the caller branches on. Writing the sentinel to both would give two
# tails that can disagree whenever `tee` fails.
if [[ -n "${CODEX_REVIEW_OUT:-}" ]]; then
    set +e
    codex review "${MCP_OFF[@]}" "${MODEL_OPTS[@]}" "$SCOPE_PROMPT" | tee "$CODEX_REVIEW_OUT"
    pipe_status=("${PIPESTATUS[@]}")
    COMPLETION_EXIT="${pipe_status[0]}"   # the outcome is now a fact — see the header
    set -e
    # A failed `tee` no longer masquerades as a codex failure (see above) — but left
    # unreported it would be worse: STATUS=COMPLETED, CODEX_EXIT=0, and an ABSENT
    # review file, so a caller that reads only CODEX_REVIEW_OUT sees an empty review
    # under a clean status. Name the path. The status stays COMPLETED because the
    # review DID complete and its findings are on stdout; calling it ERROR would
    # discard a completed review.
    if (( ${pipe_status[1]:-0} != 0 )); then
        echo "WARNING: could not write the review to CODEX_REVIEW_OUT=${CODEX_REVIEW_OUT}"
        echo "         (tee exited ${pipe_status[1]}). The review itself COMPLETED and its"
        echo "         findings are on stdout above — read them there, not from that file."
    fi
else
    set +e
    codex review "${MCP_OFF[@]}" "${MODEL_OPTS[@]}" "$SCOPE_PROMPT"
    pipe_status=("${PIPESTATUS[@]}")
    COMPLETION_EXIT="${pipe_status[0]}"   # the outcome is now a fact — see the header
    set -e
fi

# `finish` is the LAST statement on every path. Nothing may write to stdout or stderr
# after it, or the `STATUS=` line stops being the log's tail and the contract's one
# guarantee — read the last line — becomes false.
emit_codex_exit "${pipe_status[0]}"
finish COMPLETED "${pipe_status[0]}"
