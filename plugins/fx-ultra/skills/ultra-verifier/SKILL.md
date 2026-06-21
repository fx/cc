---
name: ultra-verifier
description: "The single, authoritative end-to-end verification skill for fx-ultra. Goes to the ends of the earth to PROVE — not assume — that every change actually works in a real running system. Launches the repo's real local stack and drives it by whatever means the platform demands (web→Playwright MCP, mobile Android→emulator+adb/uiautomator, iOS→simulator+simctl, React Native/Expo→device, CLI→real invocation, API/backend→real curl/grpcurl requests + DB inspection, migrations→real schema round-trip, background workers/queues→real job runs, desktop Electron/Tauri→driver, libraries/SDKs→real consumer harness). Evidence-driven: DOM/accessibility snapshots, console logs, network payloads, API/DB responses, CLI stdout/exit codes, logcat/log lines — NEVER screenshots-as-reasoning, NEVER 'the code looks right', NEVER 'tests pass so it works'. Used by verification sub-agents in the ultra SDLC (fx-ultra:dev STEP 5.5) and fx-ultra:team merge gates; its verdict feeds fx-ultra:ultra-judge. Reconciles and supersedes verify-web-change. MUST be used to verify ANY change before it can pass. Triggers: 'verify the change', 'prove it works', 'test in browser', 'check if it works', 'verify the PR', 'end-to-end verification', 'does this actually run'."
---

# Ultra-Verifier — The One True Verifier

This skill is the **single, stack-agnostic, evidence-driven verification engine** of the ultra workflow. It reconciles and **supersedes** the old `verify-web-change` skill. Its job is one thing, done without compromise:

> **Prove that every change works end-to-end in a real running system, by direct observation — never by assumption, never by "the code looks right", never by unit tests alone.**

It is invoked either directly (`Skill tool: skill="fx-ultra:ultra-verifier"`) or inside a dedicated verification sub-agent spawned by the SDLC. Follow these steps IN ORDER. Skipping a step is FORBIDDEN.

---

## 1. Prime Directive & Non-Negotiables

**⛔ 100% of observable changes MUST be directly verified against a real running system. Evidence or it didn't happen.**

You do not get to decide a change is fine because it reads well. You launch the real stack, you drive it the way a user (or caller, or consumer) would, and you observe the actual result with your own tools. Anything you cannot observe, you explicitly justify as non-observable — you never silently skip it.

**MANDATORY mindset:** go to the ends of the earth. If the stack is hard to launch, launch it anyway. If the modality is unusual, find the driver. If a tool is missing, attempt every alternative before declaring defeat. The cost of a false PASS is a broken change merged into `main` — treat it as unacceptable.

### Forbidden shortcuts (every one of these is an automatic process failure)

| ⛔ Forbidden | Why it's banned |
|--------------|-----------------|
| "The code looks correct, so it works." | Reading code is not observing behavior. The bug is always in the gap between the two. |
| "Unit/integration tests pass, so it works." | Tests prove what they assert, in a harness — not that the running system behaves. Necessary, never sufficient. |
| "CI is green, so it works." | CI is a signal, not a substitute for driving the real stack. Trusting CI alone is forbidden. |
| Reasoning about UI from a **screenshot**. | Screenshots are opaque blobs: they hide state, event flow, runtime errors, and lie across viewports/deployments. **Per global rules: NEVER reason about UI from screenshots.** Use DOM/accessibility snapshots, hard data, and the console. |
| Verifying *presence* instead of *behavior*. | "The button is in the DOM" ≠ "clicking the button does the thing." Drive the real interaction. |
| Partial verification (some ledger items, not all). | One unverified observable surface is a hole big enough to ship a regression through. |
| Marking PASS without captured evidence. | A verdict line with no cited observation is a fabrication. Forbidden. |
| Declaring BLOCKED to avoid effort. | BLOCKED is only legitimate after honest, documented attempts (see §9–§10). |

**✅ The only acceptable outcomes** are PASS (every ledger item backed by observed evidence), FAIL (at least one item demonstrably broken or unprovable), or BLOCKED (the stack genuinely cannot be run after honest attempts, with an exact reason and unblock path).

---

## 2. The Evidence Standard

Every claim you make in the verdict MUST cite a **concrete, observed artifact**. Below is the canonical list of what counts as proof — and what never does.

### ✅ Counts as evidence

| Evidence type | How obtained | Example citation |
|---------------|--------------|------------------|
| **DOM / accessibility snapshot** | `mcp__playwright__browser_snapshot`; `document.querySelector`/`getAttribute`/`dataset`/`getComputedStyle` via `browser_evaluate` | "snapshot shows `button[name='Save']` enabled; after click, `text='Saved'` node present" |
| **Console logs** | `mcp__playwright__browser_console_messages`; emulator logcat; server stdout | "0 console errors after submit; previously threw `TypeError: undefined`" |
| **Network payloads** | `mcp__playwright__browser_network_requests`; proxy logs | "`POST /api/orders` → 201, body `{id:42,status:'placed'}`" |
| **API / RPC responses** | `curl -i`, `grpcurl`, real HTTP/gRPC client | "`GET /health` → `200 {\"db\":\"ok\"}`" |
| **Database state** | real `psql`/`mysql`/`sqlite3`/ORM query after the action | "`SELECT status FROM orders WHERE id=42` → `placed`" |
| **CLI stdout/stderr + exit code** | real binary invocation | "`mytool build` → exit 0, stdout `Built 3 targets`" |
| **Emulator/simulator UI dump** | `adb shell uiautomator dump`; `xcrun simctl`/accessibility inspection | "uiautomator dump contains `Logged in as alice`" |
| **Log lines** | `logcat`, `journalctl`, container/app logs, queue worker logs | "worker log: `job 7 completed in 220ms`" |
| **Filesystem/side effects** | `ls`, file contents, generated artifacts | "`dist/index.js` exists, 12KB, contains the new export" |

### ⛔ Never counts as evidence

- A **screenshot** used to *reason* about UI state (global rule). Snapshots/DOM/console only.
- Your own paraphrase with no command/tool output behind it.
- "It should…", "presumably…", "I expect…", "the diff implies…".
- Test runner output substituting for driving the real system (it's a complement, not the proof of end-to-end behavior).

**Rule:** if you cannot paste the observed artifact (or a faithful excerpt) next to the claim, the claim is unproven and the ledger item is FAIL.

---

## 3. Step 1 — Build the Verification Ledger

The ledger is the contract. You construct it from the actual diff, and you do not finish until every line is resolved.

```bash
# Enumerate everything the change touches.
git diff main --stat
git diff main --name-only
git diff main            # read the actual hunks — you must understand each change
```

From the diff, **enumerate EVERY user-observable behavior or surface the change touches**, and turn each into a concrete, testable assertion paired with an expected observation:

| Ledger ID | Observable surface (from diff) | Assertion (what must be true) | Expected observation (how you'll know) | Modality |
|-----------|--------------------------------|-------------------------------|----------------------------------------|----------|
| L1 | `OrderForm.tsx` submit handler | Submitting a valid order shows confirmation | Snapshot shows `text='Order placed'`; `POST /api/orders`→201 | web |
| L2 | `POST /api/orders` route | Persists order to DB | `SELECT … FROM orders` returns the row | api+db |
| L3 | `0007_add_status.sql` migration | `status` column exists, defaults `pending` | `\d orders` shows column; round-trip insert | migration |

**Rules for the ledger:**

- **Nothing in the diff may be left unverified.** Every changed file maps to at least one ledger item, OR is explicitly recorded as non-observable with justification (e.g. "pure type annotation, no runtime behavior" / "comment-only change" / "test file — exercised by running the suite").
- One observable behavior = one ledger item. Split compound behaviors.
- Each item names the **modality** that will verify it (from §4). A single change may produce items across multiple modalities — that is normal and all must be exercised.
- Include **adjacent behavior at risk of regression** (see §7), not only the new happy path.
- The ledger is the spine of the final verdict (§8) — every item appears there with PASS/FAIL and cited evidence.

**⛔ DO NOT PROCEED until every diff hunk is accounted for in the ledger.**

---

## 4. Step 2 — Detect the Stack(s)

Map repo signals → verification modality. **A repo frequently needs MULTIPLE modalities; verify every modality any ledger item touches.**

| Modality | Repo signals (files / config) | Verification driver |
|----------|-------------------------------|---------------------|
| **Web** | `vite.config.*`, `next.config.*`, `nuxt.config.ts`, `svelte.config.js`, `astro.config.*`, `remix.config.*`, `angular.json`; `.tsx/.jsx/.vue/.svelte/.html/.css` in diff | Real dev server (0.0.0.0) + **Playwright MCP** (§6 Web) |
| **Mobile Android** | `*.gradle(.kts)`, `AndroidManifest.xml`, `gradlew`, `app/src/main` | Gradle build → emulator (`emulator`/AVD) → `adb install` → `adb shell input` + `uiautomator dump` + `logcat` (§6 Android) |
| **Mobile iOS** | `*.xcodeproj`, `*.xcworkspace`, `Podfile`, `*.swift` | `xcodebuild` → `xcrun simctl` boot/install/launch → UI drive + `simctl spawn … log` (§6 iOS) |
| **React Native / Expo** | `metro.config.js`, `app.json` w/ `expo`, `react-native` dep | Metro bundler + emulator/simulator per platform above; Expo: `expo start`/dev client |
| **CLI tool** | `bin` in `package.json`, `cmd/` (Go), `[[bin]]` in `Cargo.toml`, `setup.py`/`pyproject` entry points, shell scripts | Build, then invoke the **real binary** with real args (§6 CLI) |
| **HTTP/gRPC backend & API** | server frameworks (express/fastify/nest/fastapi/flask/gin/actix), `*.proto`, route files, `openapi.*` | Boot the server (0.0.0.0) → real `curl -i`/`grpcurl` → assert status/body/headers (§6 API) |
| **Background worker / queue** | queue libs (bull/bullmq/celery/sidekiq/temporal), `worker`/`consumer` files | Enqueue a real job → watch worker logs → assert side effect/DB (§6 Worker) |
| **Database / migration** | `migrations/`, `prisma/schema.prisma`, `*.sql`, ORM model changes | Apply against a **real DB** → inspect schema → data round-trip (§6 Migration) |
| **Desktop (Electron/Tauri)** | `electron` dep / `electron.*`; `src-tauri/`, `tauri.conf.json` | Launch the app; drive via its automation driver (Playwright-Electron / WebDriver / Tauri driver) + main-process logs |
| **Library / SDK** | `package.json` w/ no app entry, exported modules, `Cargo.toml` `[lib]`, published-package shape | Build, then drive through a **real consumer harness** — a throwaway script that imports and calls the public API (§6 Library) |

```bash
# Quick signal scan (adapt as needed).
ls vite.config.* next.config.* nuxt.config.* svelte.config.js astro.config.* angular.json 2>/dev/null
ls **/build.gradle* AndroidManifest.xml 2>/dev/null
ls *.xcodeproj *.xcworkspace Podfile 2>/dev/null
ls Cargo.toml go.mod pyproject.toml setup.py 2>/dev/null
ls -d migrations prisma 2>/dev/null; ls **/*.proto 2>/dev/null
ls src-tauri tauri.conf.json 2>/dev/null
grep -lE '"electron"|"@tauri-apps' package.json 2>/dev/null
```

Record the detected modalities and tie each ledger item to one. If a touched modality has no driver available in this environment, that item is a candidate for BLOCKED (§9) — but only after the honest-attempt rule in §10.

---

## 5. Step 3 — Launch the REAL Local Stack

You verify against the **real** stack — the same processes the application runs in production-shaped form locally. Not a mock, not a stub, not "what the test harness spins up."

### 5.1 Bring it up (per modality)

```bash
# Web / Node service — the bundled launcher detects pm + compose + port and boots it.
bash "$SKILL_BASE_DIR/skills/ultra-verifier/scripts/launch-app-stack.sh" "$REPO_DIR"
# It: starts docker compose services, copies .env from templates, installs deps with the
# detected manager (bun/pnpm/yarn/npm), starts the dev server, writes PID→/tmp/dev-server.pid
# and logs→/tmp/dev-server.log, and waits for the port to answer.
```

```bash
# Backing services (DB, cache, queue) when a compose file exists:
docker compose -f docker-compose.yml up -d
# Migrations / seeds (use the project's real command):
bun run db:migrate || npx prisma migrate deploy || ./manage.py migrate
bun run db:seed 2>/dev/null || true
```

```bash
# Android: boot an AVD headless, wait for boot, install, ready logcat.
emulator -avd "$AVD" -no-window -no-audio & adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'
./gradlew assembleDebug && adb install -r app/build/outputs/apk/debug/app-debug.apk

# iOS: boot a simulator, build, install, launch.
xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
xcodebuild -scheme App -destination "id=$SIM_UDID" build
xcrun simctl install "$SIM_UDID" "$APP_PATH" && xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
```

### 5.2 Mandatory launch rules

- **Bind dev servers to `0.0.0.0`, never `localhost`/`127.0.0.1`** (global rule). For Vite also set `server.allowedHosts: true`. Fix the dev script/config rather than papering over it.
- **Detect the package manager** from lockfiles (`bun.lock`/`bun.lockb`→bun, `pnpm-lock.yaml`→pnpm, `yarn.lock`→yarn, else npm) — the launcher already does this.
- **Provide env/secrets**: copy `.env.example`→`.env` if no env exists; if the app needs real secrets you don't have, that's a candidate BLOCKED with the exact missing var named.
- **Confirm readiness with hard data**, not a guess: `curl -s -o /dev/null -w '%{http_code}' http://localhost:$PORT` returns 2xx/3xx; the server log shows "ready"; the emulator reports `boot_completed`.

### 5.3 ⛔ "Stack won't start" is a verification FAILURE — root-cause it, do not skip

If the stack does not come up, that is itself a finding. Read the logs (`tail -50 /tmp/dev-server.log`), identify whether it's the change under test or an environment gap, and:

- If the **change** breaks startup → **FAIL** (the change doesn't work — that's the verdict).
- If a genuine **environment** gap (missing emulator image, missing secret, MCP absent) blocks it after honest attempts → **BLOCKED** with the exact gap (§9). Never silently downgrade to "looks fine."

### 5.4 Safe process management (CRITICAL — global rule)

**NEVER blind-pipe `lsof … | xargs kill`.** It can kill unrelated critical processes (including the agent itself). Always: get the PID, inspect it, then kill only that process.

```bash
PID=$(lsof -ti:"$PORT")               # 1. get the PID
ps -p "$PID" -o pid,comm,args         # 2. inspect — confirm it's YOUR dev server
kill "$PID"                           # 3. kill only that specific process
```

---

## 6. Step 4 — Drive & Observe (per-modality playbooks)

Each playbook **drives the real interaction** and ends by **capturing PASS/FAIL evidence per ledger item**. Presence is not behavior — exercise the actual flow.

### Web (Playwright MCP)

Tools per `references/playwright-mcp.md`. **Prefer accessibility snapshots over screenshots** (global rule); read the console first when anything misbehaves.

```
1. mcp__playwright__browser_navigate { url: "http://localhost:<PORT>/<route>" }
2. mcp__playwright__browser_snapshot            # accessibility tree → element refs + current state
3. interact via refs: browser_click / browser_type / browser_fill_form   # drive the REAL flow
4. mcp__playwright__browser_snapshot            # RE-snapshot → prove the state actually changed
5. mcp__playwright__browser_console_messages { level: "error" }   # MUST be clean (or explained)
6. mcp__playwright__browser_network_requests    # assert the request fired + status/payload
```

For values not in the a11y tree, read them directly with `mcp__playwright__browser_evaluate` (`querySelector`, `dataset`, `getComputedStyle`, in-memory store state). **Evidence captured:** before/after snapshots, console (errors = FAIL unless pre-existing & unrelated), network status/body. Verify the *interaction outcome*, not element presence.

### Android (emulator + adb/uiautomator)

```bash
adb shell input tap <x> <y>            # or: input text 'hello' ; keyevent KEYCODE_ENTER
adb shell uiautomator dump /sdcard/v.xml && adb pull /sdcard/v.xml -   # UI state as data
adb logcat -d -t 200 | grep -i -E 'exception|error|<your-tag>'        # runtime signal
```

**Evidence captured:** uiautomator XML showing the expected node/text after the action; clean logcat (no new crashes/exceptions tied to the change).

### iOS (simulator + simctl)

```bash
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
# Drive UI via your harness (XCUITest / accessibility). Read logs as data:
xcrun simctl spawn "$SIM_UDID" log stream --style compact --predicate 'process == "App"' &
```

**Evidence captured:** accessibility/UI assertion after the interaction; log stream free of new errors.

### CLI

```bash
./bin/mytool <real args>; echo "exit=$?"        # invoke the REAL binary, real args
```

**Evidence captured:** stdout/stderr content, **exit code**, and any side effects (files written, rows changed). Assert all of them against the ledger's expected observation. Test the failure path too (bad args → non-zero exit + helpful stderr).

### API / backend (HTTP / gRPC)

```bash
curl -i -X POST http://localhost:<PORT>/api/orders -H 'content-type: application/json' -d '{"item":"x"}'
grpcurl -plaintext -d '{"id":42}' localhost:<PORT> svc.Orders/Get
```

**Evidence captured:** status code, response body, relevant headers — then **inspect DB state after** to prove the side effect actually happened (see Migration/DB). Assert auth failures and validation errors too, not only the 200 path.

### Migrations / data

```bash
<apply migration with the project's real command, against a real DB>
psql "$DATABASE_URL" -c '\d+ orders'                     # schema is what you expect
psql "$DATABASE_URL" -c "INSERT … RETURNING *;"          # round-trip a real row
psql "$DATABASE_URL" -c "SELECT … WHERE …;"              # read it back
```

**Evidence captured:** schema dump showing the new shape; a successful insert→select round-trip. If the migration has a `down`, verify it reverses cleanly.

### Background worker / queue

Enqueue a **real** job, watch the worker consume it, assert the side effect.

```bash
<enqueue via the app's real producer>; <tail worker logs>; <query the resulting state>
```

**Evidence captured:** worker log line showing the job processed + the downstream state change (DB row, file, webhook).

### Desktop (Electron / Tauri) & Library/SDK

- **Desktop:** launch the built app; drive via its automation driver (Playwright-Electron / WebDriver / Tauri driver); capture renderer DOM/console **and** main-process logs.
- **Library/SDK:** write a throwaway **consumer harness** that imports the built package and calls the public API exactly as a real consumer would; run it; assert returned values / thrown errors / emitted output. The harness IS the real stack for a library.

**Each playbook ends the same way:** for every ledger item it covers, record **PASS** (with the cited observation) or **FAIL** (with the observed wrong/absent result).

---

## 7. Step 5 — Adversarial / Edge Verification

Proving the happy path is the *minimum*, not the goal. **Try to BREAK the change.**

| Class | What to do | Why |
|-------|-----------|-----|
| **Error states** | Trigger the failure path (bad input, server 500, network drop). Assert the error is handled and surfaced, not swallowed. | Happy paths hide the bugs users actually hit. |
| **Empty / loading states** | Drive with no data and during in-flight requests. | Empty/loading is where blank screens and spinners-forever live. |
| **Boundary inputs** | Min/max, empty string, very long input, unicode/emoji, zero, negative, null. | Off-by-one and validation gaps surface here. |
| **Concurrency** | Fire concurrent requests/clicks; double-submit. | Races and double-writes. |
| **Adjacent regression** | Exercise the nearest *unchanged* behavior that shares code with the change. | Changes leak into neighbors; prove you didn't break them. |
| **Auth / permission** | Hit the surface unauthenticated / under-privileged where relevant. | Silent authz holes. |

Add any adversarial finding back into the ledger as its own item with PASS/FAIL + evidence. A discovered break is a **FAIL**, not a footnote.

---

## 8. Step 6 — Re-Verify on Uncertainty (run twice; thrice if unsure)

**⛔ MANDATORY: run the full verification at least TWICE.** A behavior that passes once may be a fluke of timing, cache, or order.

- Run pass **#1** and pass **#2** independently (fresh navigation/process where feasible). Both must agree.
- If **any** item is ambiguous, flaky, order-dependent, or you are **less than fully certain**, run a **third** independent pass.
- **Flaky = FAIL until proven stable.** A result that only sometimes holds is not a PASS. Either root-cause it to stable PASS, or report FAIL.
- **Document each pass** in the verdict (`Passes run: N`). Note any item whose result differed between passes — that divergence is itself a FAIL signal.

---

## 9. Step 7 — The Verdict

Emit a STRICT, machine-greppable verdict block. The caller, the `fx-ultra:team` merge gate, and `fx-ultra:ultra-judge` key on this exact shape — do not alter the delimiters.

```
═══ ULTRA-VERIFIER VERDICT: PASS | FAIL | BLOCKED ═══
Stack(s) exercised: <list, e.g. web (vite/5173), api, postgres>
Passes run: <N>   (>=2 required)
Ledger:
  [PASS|FAIL] <observable item> — evidence: <concrete observation>
  [PASS|FAIL] <observable item> — evidence: <concrete observation>
  ...
Unverified items: <none | list each with justification>
═══════════════════════════════════════════════════
```

**Verdict rules (non-negotiable):**

- **ANY `FAIL` ledger item → overall verdict is `FAIL`.** No averaging, no "mostly works."
- **ANY ledger item lacking direct, cited evidence → the verdict CANNOT be `PASS`.** It is FAIL (if observed broken/absent) or BLOCKED (if genuinely un-runnable per §10).
- **`PASS`** requires: every ledger item PASS with cited evidence, ≥2 agreeing passes, adversarial checks done, and `Unverified items: none` (or every listed unverified item carries a sound non-observable justification).
- **`BLOCKED`** is permitted **only** when the stack genuinely cannot be run after honest attempts (missing MCP, no emulator image, secret you cannot obtain). It MUST state **exactly what is missing and how to unblock it**. BLOCKED is **never a silent pass** — the caller treats it as "not verified."

---

## 10. Graceful Degradation & Honesty

When a driver is unavailable, you **attempt alternatives before ever returning BLOCKED**:

- **Playwright MCP missing?** Quick-check with `scripts/check-playwright-mcp.sh`, then confirm by attempting `mcp__playwright__browser_navigate`. If truly absent, try a headless alternative for the specific assertion (e.g. `curl` the rendered route, query the API the UI calls, inspect server-rendered HTML). If the assertion is fundamentally UI-interaction and no driver exists → BLOCKED naming "Playwright MCP not configured" + the unblock (`install/configure the Playwright MCP server`).
- **Emulator/simulator missing?** Verify any non-UI portion (API, DB, build artifact) that you *can* observe, and BLOCK only the UI-interaction items, naming the missing image/runtime.
- **Secrets missing?** Name the exact env var(s) required and where the app reads them.

```bash
bash "$SKILL_BASE_DIR/skills/ultra-verifier/scripts/check-playwright-mcp.sh"
```

**⛔ Absolute prohibitions:**

- **NEVER fabricate evidence.** Do not invent snapshot text, status codes, or log lines.
- **NEVER mark PASS without observation.** "Probably fine" is FAIL or BLOCKED, never PASS.
- **NEVER hide a BLOCKED as a PASS.** Surface exactly what stopped you.

Honesty is the whole point: a truthful FAIL or BLOCKED is infinitely more valuable than a confident, wrong PASS.

---

## 11. Cleanup

Tear down everything you started — safely (see §5.4: PID → inspect → kill the specific process; **never** blind `xargs kill`).

```bash
# Dev server (PID-safe)
if [[ -f /tmp/dev-server.pid ]]; then
  PID=$(cat /tmp/dev-server.pid); ps -p "$PID" -o pid,comm,args && kill "$PID"
fi

# Docker services
docker compose -f docker-compose.yml down 2>/dev/null || true

# Emulators / simulators
adb emu kill 2>/dev/null || true
xcrun simctl shutdown all 2>/dev/null || true
```

Leave the workspace as you found it: no orphaned dev servers, no dangling containers, no booted emulators, no throwaway consumer-harness files committed.

---

## 12. Integration Note

Ultra-verifier is the verification engine the rest of the ultra workflow leans on:

- **`fx-ultra:dev` STEP 5.5 (Test Plan Verification)** invokes it (directly or via a verification sub-agent) to prove every test-plan item against the real running system. It **supersedes** `fx-ultra:verify-web-change` — web verification is now just the Web playbook in §6.
- **`fx-ultra:team` merge gates** call it before a PR can pass; its `═══ VERDICT ═══` block is the gate signal.
- **`fx-ultra:ultra-judge`** consumes the verdict block: `PASS` is required to advance, `FAIL` blocks, `BLOCKED` is treated as "not verified" (never as a pass).

**Division of labor with `fx-ultra:ultra-designer` (companion skill):** ultra-verifier proves the change **WORKS** (behavior, by observation); ultra-designer proves it is **POLISHED** (visual/UX quality). For visual/UX polish, hand off to ultra-designer — do not try to judge aesthetics here. Functional correctness is this skill's mandate, and it does not pass that mandate off to anyone.
