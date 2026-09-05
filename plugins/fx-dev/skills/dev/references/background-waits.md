# Background waits

**The canonical rules for waiting on anything slow** — a reviewer, a CI run, a
teammate, any long-running tool. Every skill in this catalog that waits names this
file rather than restating it (`fx-dev/skills/review/SKILL.md` § The two canonical
sources applies the same define-once rule to review definitions).

A skill that waits still documents its **own** invocation — which script, which
arguments, which log path, and how to branch on the result. What it must not
restate is anything below.

## The rule

**⛔ Never `sleep`, poll, or block waiting for anything.** Every wait runs
**backgrounded** (`run_in_background: true`), redirecting stdout and stderr to a
log file, and the completion notification wakes you. That notification is the only
scheduling mechanism there is.

```bash
mkdir -p .claude/team/waits && \
bash <wait-script> <args> > .claude/team/waits/<name>.log 2>&1
```

This works identically in every context — root session, `fx-dev:team`
coordinator, or sub-agent — so there is nothing to select and no "can I spawn
sub-agents?" branch. **Do not spawn sub-agents for waits; they buy nothing.**

**Never background a wait without the redirect.** The caller reacts to what the
script prints; without a log there is nothing to read on the wake.

Launch independent waits in the **same message** so they run concurrently and each
wakes you separately.

## Why not the foreground

The Bash tool caps a foreground `timeout` at 600 000 ms, which is below the 900 s
budget these scripts run to. A foreground call is therefore *guaranteed* to be
killed mid-poll, printing no `STATUS` and no exit code — which is exactly what
used to force blind re-runs. Backgrounded processes are not subject to that cap.

Polling a log yourself is no better: a buffered tool writes nothing until it
finishes, so an early read teaches you nothing and costs a full context read every
time. For a coordinator this is the single most expensive thing you can do — every
wake re-reads the largest context in the team, and it gets more expensive with
every turn added.

## ⛔ Never invent your own wait

Use the host's backgrounding mechanism and nothing else. A hand-rolled wait has
failed in production in a way that is silent and total.

**Never poll with a pattern that can match the watching command itself.** This
loop deadlocked a run for 49 minutes:

```bash
# ⛔ BROKEN — never exits, even after the watched process has finished
until ! pgrep -f 'codex review -c' >/dev/null 2>&1; do sleep 15; done
```

`pgrep -f` matches against **full command lines**, and the watching shell's own
command line contains the literal `codex review -c`. The pattern matches the
watcher, `pgrep` always succeeds, the `until` condition is never true, and the loop
spins long after the real process exited and wrote its output. Nothing errors and
nothing is logged; the wait simply never ends.

The trap is general: **any** `pgrep -f`, `ps | grep`, or `pkill -f` whose pattern
appears in its own invocation self-matches. If a process check is unavoidable:

```bash
pgrep -x codex                        # ✅ matches the executable name only
pgrep -f 'codex review' | grep -v $$  # ✅ excludes the current shell
```

Prefer not to check at all. **The output file is the signal** — a finished run is a
log that has stopped growing, with a `STATUS`/summary at its tail.

## When a wait seems hung

Check the log's **mtime against the clock before assuming the tool is slow.** A log
that stopped growing minutes ago means the tool finished and the *wait* is what
broke. Suspect the wait, not the tool.

## The rule binds delegates too

A delegate left to invent its own wait writes exactly the loop above. **Any prompt
you hand an agent that could wait on a long-running tool MUST carry this rule
explicitly** — no `sleep` polling, and no self-matching process patterns.
