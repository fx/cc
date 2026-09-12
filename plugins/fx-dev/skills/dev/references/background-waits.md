# Background waits

**The canonical rules for waiting on an EXTERNAL completion** — a reviewer, a CI
run, a teammate agent, or any long-running one-shot tool that finishes on its own
schedule and tells you so. Every skill in this catalog that waits on one of those
names this file rather than restating it (`fx-dev/skills/review/SKILL.md` § The two
canonical sources applies the same define-once rule to review definitions).

Such a skill still documents its **own** invocation — which script, which
arguments, which log path, and how to branch on the result. What it must not
restate is anything below.

### What this does NOT govern

**A bounded readiness or teardown wait inside a single command is not one of these,
and this file does not forbid it.** A loop that polls a service it just started —
`for i in $(seq 1 30); do curl -sf "$URL" && break; sleep 2; done` — is part of one
command whose next step depends on it, is bounded by its own iteration count, and
has no completion notification to wait for. Backgrounding it would break the
sequence it exists to order. `fx-dev:verify-web-change` uses exactly these for
Docker, Compose health, and dev-server readiness, and they are correct.

The line is **who signals completion**: if something outside your command will tell
you it finished, background it and wait for that signal. If nothing will, and you
are gating the next line of your own script, a bounded in-command poll is right.

## The rule

**⛔ Never `sleep`, poll, or block waiting on one of these.** Every such wait runs
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

**Never add `&`, `nohup`, or `disown` to a launch already backgrounded by
`run_in_background: true`.** That flag is the whole mechanism. The three break it
in three different ways, and only the first is a second backgrounding:

- **`&` returns at once.** It forks the launch into a subshell, so what comes back
  is the *wrapper's* exit status in milliseconds rather than the job's. This is the
  one that has shipped a wrong answer: the instant return was read as completion
  and a truncated log as a finished review.
- **`nohup` buys nothing.** It does not fork and does not return early — it runs
  the command in the foreground and passes its exit status through,
  indistinguishable from no wrapper at all. All it adds is SIGHUP immunity plus a
  `nohup.out` redirect that engages only when stdout or stderr is a *terminal*,
  which the mandatory `> log 2>&1` above already rules out. Writing it implies the
  launch needs a detach it already has.
- **`disown` makes a live job report success.** It backgrounds nothing and needs an
  existing job to act on. What it does is drop that job from the shell's table,
  after which `wait <pid>` returns **immediately with status 0** instead of
  blocking — so a job still running, or one that exited non-zero, is reported as a
  clean finish. Same false completion as `&`, by a different route.

**An instant return is not a completion.** Judge a wait by its log's tail, never by
how fast the call came back: a log with no `STATUS=` line at its tail is a wait
still running or one that died, and reading it then hands you a truncated capture.
That has shipped a wrong answer — the instant return was read as the review having
finished, and a partial log was reported as a finished review. § Never invent your
own wait says what a finished log looks like; § When a wait seems hung is what to
check when the tail never arrives.

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
appears in its own invocation self-matches.

**Do not reach for a "safer" process check — there isn't one.** `pgrep -x <name>`
drops the self-match but cannot tell your run from any other process of the same
name. `pgrep -f <pattern> | grep -v $$` is worse: it filters PID *text* by
substring (so `$$` of `123` also drops `1234`), and it removes only the current
shell, leaving any parent or wrapper whose command line contains the pattern to
keep the check true. Either one can recreate the very wait this section exists to
prevent.

**The output file is the signal** — a finished run is a log that has stopped
growing, with a `STATUS`/summary at its tail. Read it on the completion wake.

## When a wait seems hung

Check the log's **mtime against the clock before assuming the tool is slow.** A log
that stopped growing minutes ago means the tool finished and the *wait* is what
broke. Suspect the wait, not the tool.

## The rule binds delegates too

A delegate left to invent its own wait writes exactly the loop above. **Any prompt
you hand an agent that could wait on a long-running tool MUST carry this rule
explicitly** — no `sleep` polling, and no self-matching process patterns.
