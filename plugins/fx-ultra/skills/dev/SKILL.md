---
name: dev
description: "MUST BE LOADED for any coding task: implementing features, fixing bugs, writing code, refactoring, or making changes. This is the fx-ultra SDLC source of truth — the ultra-rigorous variant of the development lifecycle: every change is implemented, exhaustively verified end-to-end (ultra-verifier), polished with extreme prejudice when visual (ultra-designer), forced to 100% test/integration coverage, and finally judged with halt authority (ultra-judge). Load this skill when the user asks to 'add', 'create', 'build', 'fix', 'update', 'change', 'implement', or 'refactor' anything."
---

# Dev — Ultra SDLC Workflow Skill (fx-ultra source of truth)

This skill defines the **mandatory, ultra-rigorous** workflow for all coding tasks. Follow these steps IN ORDER. Skipping steps is FORBIDDEN. This is the single SDLC source of truth shared by `fx-ultra:dev` (solo) and `fx-ultra:team` (coordinated). Both run THESE steps and THESE gates.

## ⛔⛔ THE ULTRA MANDATES (read before anything else)

The entire point of fx-ultra is to **exceed** the minimum that any spec, issue, or instruction asks for. You do not stop at "matches the requirement." You stop only when the change is **proven** to work, **proven** to be polished, **proven** to be exhaustively tested, and **independently judged** to have been done with extreme rigor. These four mandates are non-negotiable and override any narrower instruction in a task, spec, or change doc:

1. **PROVE, NEVER ASSUME (Ultra-Verification).** Every change MUST be verified end-to-end against the **real running stack** by direct observation — see STEP 5.5 (`fx-ultra:ultra-verifier`). "The code looks right", "unit tests pass", and "CI is green" are NOT verification. Verification runs at least **twice**, and a **third** time whenever anything is ambiguous, flaky, or less than fully certain.
2. **100% COVERAGE, ALWAYS (regardless of what the spec says).** Every line and branch of changed/added code MUST be covered by real, meaningful tests — unit AND integration/e2e where the change warrants — see STEP 4.6. A spec that asks for less does not lower this bar. Skipped/quarantined/trivially-passing tests are FORBIDDEN. If something seems untestable, build the harness/infrastructure to test it.
3. **POLISH WITH EXTREME PREJUDICE (Ultra-Design).** Any change with a visual/UI surface MUST pass `fx-ultra:ultra-designer` (STEP 5.6): every interactivity state handled, motion where warranted, responsive, accessible, measured against explicit design principles — not vibes.
4. **THE JUDGE IS BINDING (Ultra-Judge).** `fx-ultra:ultra-judge` runs LAST (STEP 9) and audits the whole progression against the ultra bar. Its verdict is binding: **APPROVE** is required to complete/merge; **REMEDIATE** loops you back; **HALT** stops everything and escalates to the user. Proceeding past a HALT is the single worst failure of this workflow.

> If you ever feel pressure to skip a verification, lower coverage, or wave through polish "to save time" — that is exactly the situation these mandates exist for. Do the rigorous thing. ultra-judge will catch the shortcut anyway, and a HALT costs far more than doing it right the first time.

## CRITICAL RULES

**YOU MUST USE THE AGENT TOOL TO LAUNCH SUB-AGENTS FOR ALL WORK. Each sub-agent loads the appropriate skill via the Skill tool.**

### How to Launch Sub-Agents with Skills

Skills are NOT agent types. Launch a general-purpose sub-agent and instruct it to load the skill:

```
Agent tool:
  prompt: "Load the [skill-name] skill (Skill tool: skill='[skill-name]'), then:
           [task details]"
  description: "[3-5 word summary]"
```

**Do NOT use `subagent_type` for skills.** The `subagent_type` parameter is reserved for built-in agent types (Explore, Plan, etc.). Skills are loaded inside the sub-agent via the Skill tool.

### Coder Task Reporting (Sub-Agent Restriction)

**Sub-agents MUST NEVER send "idle" or "complete" states via `mcp__coder__coder_report_task`.** Only the main agent session (root conversation) is allowed to report "idle" or "complete". Sub-agents spawned via the Agent tool may only report `"state": "working"`. This prevents sub-agents from overwriting the coordinator's dashboard status and falsely signaling task completion.

- ❌ NEVER write code yourself
- ❌ NEVER create files yourself
- ❌ NEVER make commits yourself
- ❌ NEVER skip steps
- ❌ NEVER skip tests (`test.skip`, `it.skip`, `describe.skip` are FORBIDDEN)
- ❌ NEVER use `subagent_type` for skills — use `Skill tool` inside the sub-agent
- ✅ ALWAYS launch sub-agents via the Agent tool
- ✅ ALWAYS instruct sub-agents to load skills via the Skill tool
- ✅ ALWAYS verify each step before proceeding
- ✅ ALWAYS fix, replace, refactor, or remove tests - never skip them

**FAILURE TO USE SUB-AGENTS = WORKFLOW FAILURE**

### Test Policy

**⛔ NEVER skip tests.** If a test cannot pass:
- **Fix it** - Update assertions to match correct behavior
- **Replace it** - Write a new test that properly validates the behavior
- **Refactor it** - Restructure to test what's actually testable
- **Remove it** - Delete entirely if it tests something that no longer exists

If tests require infrastructure (auth, database, external services), SET UP that infrastructure. Do not skip tests because setup is hard.

### Coverage Policy (Ultra Mandate #2)

**⛔ 100% line AND branch coverage of changed/added code is MANDATORY — regardless of what the spec, issue, or task says.** This is enforced as a hard gate in STEP 4.6 and re-audited by `fx-ultra:ultra-judge` in STEP 9. "The ticket only asked for X" is NOT a reason to leave new code untested. Build whatever harness, fixtures, or integration scaffolding is required to reach 100% on the diff. The only acceptable exception is code that is genuinely impossible to execute in a test (and even then it must be explicitly justified to the user, not silently skipped).

---

## MANDATORY STEPS (Execute in Order)

### STEP 0: GitHub Authentication

**Execute FIRST before anything else.**

```bash
gh auth status
```

If fails: STOP. Tell user to run `gh auth login`. Do NOT proceed.

---

### STEP 1: Workspace Preparation

**Create clean feature branch BEFORE any implementation.**

#### 1.1 Check for uncommitted changes

```bash
git status
```

If uncommitted changes exist:
- Ask user: "Uncommitted changes found. Stash them or abort?"
- If stash: `git stash push -m "SDLC auto-stash"`
- If abort: STOP

#### 1.2 Sync and create branch

```bash
git fetch origin
git checkout main
git pull origin main
git checkout -b <type>/<short-description>
```

Branch types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

**⛔ DO NOT PROCEED until branch is created**

---

### STEP 2: Requirements Analysis

**MANDATORY: Launch a sub-agent that loads the requirements-analyzer skill.**

```
Agent tool:
  prompt: "Load the requirements-analyzer skill (Skill tool: skill='fx-ultra:requirements-analyzer'), then:

           Analyze requirements for: [TASK DESCRIPTION]

           - Analyze task/issue/error to understand requirements
           - Use WebSearch to research technologies
           - Use WebFetch for referenced URLs
           - Use AskUserQuestion for ambiguities
           - Analyze codebase for patterns

           Output: Complete requirements with acceptance criteria"
  description: "Analyze requirements"
```

For GitHub issues, fetch first:
```bash
gh issue view [NUMBER] --json title,body,labels,comments
```

**⛔ DO NOT PROCEED until requirements are complete**

---

### STEP 3: Planning

**MANDATORY: Launch a sub-agent that loads the planner skill.**

```
Agent tool:
  prompt: "Load the planner skill (Skill tool: skill='fx-ultra:planner'), then:

           Create implementation plan for:

           [REQUIREMENTS FROM STEP 2]

           - Break into atomic steps
           - Identify files to modify
           - Determine test requirements
           - Flag if multiple PRs needed

           Output: Numbered implementation steps"
  description: "Plan implementation"
```

For GitHub issues, also update issue:
```
Agent tool:
  prompt: "Load the issue-updater skill (Skill tool: skill='fx-ultra:issue-updater'), then:

           Update issue #[NUMBER] with plan. Add label: in-progress"
  description: "Update issue"
```

**⛔ DO NOT PROCEED until plan exists**

---

### STEP 4: Implementation

**MANDATORY: Launch a sub-agent that loads the coder skill.**

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-ultra:coder'), then:

           Implement this plan:

           [PLAN FROM STEP 3]

           Requirements:
           - Atomic commits (format: type(scope): message)
           - Follow existing patterns
           - Run tests
           - Do NOT create PR"
  description: "Implement changes"
```

Verify commits exist:
```bash
git log --oneline -5
git diff main --stat
```

**⛔ DO NOT PROCEED until commits exist on feature branch**

---

### STEP 4.5: Pre-PR Self-Review (simplify → review → CodeRabbit → Codex)

**MANDATORY: Self-review the changes locally BEFORE creating the PR. The PR is opened only once all four passes are clean against the final diff at the same time.** Run them in order, fixing and committing findings after each; because a later pass's fixes invalidate earlier passes, loop the whole sequence until a full pass yields no new commits (see "Re-run after fixes" below).

**1. `/simplify`** — reuse, quality, efficiency cleanup:

```
Skill tool: skill="simplify"
```

Reviews all changed code for **reuse** (duplicated logic), **quality** (copy-paste, leaky abstractions, nesting), and **efficiency** (redundant computation, missed concurrency).

**2. `/code-review`** — correctness bugs in the diff:

```
Skill tool: skill="code-review"
```

**3. CodeRabbit (local, via `cr`)** — run CodeRabbit's AI review on the local changes BEFORE the PR exists, so its feedback is resolved up front instead of churning the PR:

```
Skill tool: skill="fx-ultra:coderabbit-review"
```

The skill runs `cr review --agent` against the working tree (Mode 1), resolves every actionable finding, and re-runs until clean. If `cr` is **unavailable**, fall back to the PR-level CodeRabbit gate in Step 6.3. If `cr` reports it is **not authenticated**, STOP and report to the user — NEVER run `cr auth login` (it is interactive; the workspace should already be authed).

**4. Codex (local, via `codex`)** — run OpenAI Codex's AI review one-shot on the branch BEFORE the PR exists. Codex and CodeRabbit are independent reviewers; each catches issues the other misses:

```
Skill tool: skill="fx-ultra:codex-review"
```

The skill runs `codex review --base main` (read-only, one-shot, branch vs `main`), prints findings to stdout, and you resolve every actionable one before opening the PR. If the `codex` CLI is **unavailable or not authenticated**, report to the user once and proceed without this pass — NEVER run `codex login` (it is interactive; the workspace should already be authed).

Fix any issues found in each pass and commit the fixes. **Whenever a later pass commits a change, the earlier passes' clean results no longer cover the final diff — re-run the whole sequence (simplify → review → CodeRabbit → Codex) from the top.** Only proceed to PR creation once a complete pass through all four reviewers produces **no new commits** (every available reviewer is clean against the final diff at once).

**⛔ DO NOT PROCEED to Step 5 until simplify and review have run and all findings are addressed, AND each local AI reviewer has been resolved or correctly degraded:**

- **CodeRabbit** clean, OR — if `cr` is **not installed** — fall back to the PR-level gate in Step 6.3. If `cr` is installed but **not authenticated**, STOP and report to the user; do NOT treat an auth failure as a skip.
- **Codex** clean, OR — if the `codex` CLI is **unavailable or not authenticated** — report once and skip this pass.

Opening the PR with unresolved findings from an *available, working* local reviewer is FORBIDDEN — the whole point is to open clean. A genuinely missing CLI degrades to the documented fallback above; it does NOT block PR creation.

---

### STEP 4.6: 100% Coverage Gate (ULTRA MANDATE — BLOCKING)

**MANDATORY: Before the PR is opened, the changed/added code MUST have 100% line AND branch coverage from real, meaningful tests.** This gate is independent of and stricter than any coverage requirement in the spec. It applies to EVERY change — features, fixes, refactors, "trivial" one-liners.

#### 4.6.1 Measure coverage on the diff

Detect the project's coverage tool and run it scoped to the changed files:

```bash
# Identify changed source files (exclude tests/generated/config)
git diff main --name-only

# Run the project's coverage command. Examples — use the repo's real one:
#   bun test --coverage            (bun)
#   pnpm vitest run --coverage     (vitest)
#   npx jest --coverage            (jest)
#   pytest --cov --cov-branch      (python)
#   go test -coverprofile ./...    (go)
#   cargo llvm-cov                 (rust)
```

Read the **actual coverage report** (not a summary claim) and map it back to every changed line and branch. Identify EXACTLY which added/modified lines and branches are uncovered.

#### 4.6.2 Drive coverage to 100% on changed code

For every uncovered line/branch, launch a sub-agent with the coder skill to add tests until the diff is fully covered:

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-ultra:coder'), then:

           Achieve 100% line AND branch coverage on these changed files:
           [FILES + the specific uncovered lines/branches]

           Requirements:
           - Add REAL, meaningful tests that assert actual behavior — never trivial
             tests written only to touch a line. No test.skip/it.only/xfail.
           - Add integration/e2e tests where the change spans modules or I/O, not
             just isolated unit tests.
           - If code is hard to reach, build the fixtures/harness/infrastructure
             needed — do NOT lower thresholds or exclude files.
           - Re-run coverage and confirm 100% on the diff.
           - Commit the tests."
  description: "Cover diff to 100%"
```

#### 4.6.3 Verify and lock

- Re-run coverage; confirm **100% of changed lines and branches** are covered.
- ⛔ NEVER reach the number by lowering thresholds, adding `istanbul ignore` / `pragma: no cover` / coverage `exclude` globs over the changed files, or deleting assertions. `fx-ultra:ultra-judge` specifically hunts for these in STEP 9 and will HALT on them.
- The ONLY permissible sub-100% case is code that genuinely cannot be executed under test. It MUST be explicitly called out to the user with justification — never silently skipped.

**⛔ DO NOT PROCEED to Step 5 until changed code is at 100% line+branch coverage (or a genuine, user-acknowledged exception is documented).**

---

### STEP 5: Pull Request Creation

**MANDATORY: Launch a sub-agent that loads the pr-preparer skill. ALL PRs MUST be created READY FOR REVIEW — never as drafts.**

**⛔ NEVER use the `--draft` flag. NEVER create draft PRs.** Draft PRs have repeatedly been used as an excuse to skip downstream steps (reviewer waits, CI monitoring, CodeRabbit/Copilot resolution). The SDLC ALWAYS executes the full review/CI cycle from PR creation onward — opening as draft defeats this. If the work isn't ready for review, don't open the PR yet.

**Before creating the PR, identify related spec and change documents:**

```bash
# Find related change documents (check if task was sourced from a change doc)
ls docs/changes/ 2>/dev/null
# Find related specs
ls docs/specs/ 2>/dev/null
cat docs/index.yml 2>/dev/null
```

If the work was driven by a specific change document or spec, note the paths for inclusion in the PR description.

```
Agent tool:
  prompt: "Load the pr-preparer skill (Skill tool: skill='fx-ultra:pr-preparer'), then:

           Create PR (ready for review, NOT draft) for current branch.
           Task: [ORIGINAL TASK]
           Summary: [WHAT WAS IMPLEMENTED]

           Spec/Change context (include in PR body if applicable):
           - Spec: [SPEC_PATH or 'none']
           - Change: [CHANGE_DOC_PATH or 'none']

           CRITICAL: Do NOT pass --draft. The PR must be opened ready for review so
           CI, Copilot, and CodeRabbit run from the start.
           - Push branch if needed
           - Create PR with: gh pr create  (NO --draft flag)
           - Include links to related spec/change docs in the PR body
             (use relative paths from repo root, e.g. docs/specs/auth/ or docs/changes/0003-add-oauth.md)
           - Do NOT put spec/change references in the PR title — not as a number,
             slug, or path, even when the PR finalizes a change doc. Describe the
             work itself in the title; reference the doc by path in the body only.
           - ⛔ NEVER put '#<number>' in the PR title ('#4', '(#4)', '#123')
             unless N is a REAL existing PR/issue on the target repo that this PR
             references. On squash-merge the title becomes the commit subject,
             where '#N' auto-links to PR/issue #N. NEVER use '#N' for an
             implementation wave, phase, step, or change-doc number, and NEVER
             pre-add a '(#N)' suffix (GitHub appends the real PR number at squash
             merge). No waves/phases/steps in the title at all — those go in the
             body. See the fx-ultra:github skill's '#<number> PR-Title Rule'.
           - Reference related issues
           - Do NOT include any 'this is a draft' / 'draft for review' language
             anywhere in the title or body
           - Return PR number and URL"
  description: "Create PR"
```

**Capture the PR number for remaining steps.**

**⛔ DO NOT PROCEED until PR is created (as ready for review)**

---

### STEP 5.5: Ultra-Verification (END-TO-END, PROVE IT WORKS — ULTRA MANDATE #1)

**MANDATORY for EVERY PR — not just web/UI.** Backend, CLI, mobile, infra, libraries: all of it must be **proven** to work end-to-end against the **real running stack** by direct observation. This step supersedes the old "test plan verification" — `fx-ultra:ultra-verifier` is the single, stack-agnostic verifier that launches whatever stack the repo needs and drives it to the ends of the earth. (It reconciles/replaces the old `verify-web-change` skill.)

#### 5.5.1 Build the verification ledger from the diff + test plan

```bash
gh pr view [PR_NUMBER] --json body --jq '.body'   # extract the ## Test plan, if any
git diff main --name-only
```

From the diff AND the PR's Test Plan, enumerate **every user-observable behavior/surface** the change touches. Each becomes a concrete assertion with an expected observation. A PR with no Test Plan still gets a full ledger derived from the diff. Nothing observable in the diff may go unverified.

#### 5.5.2 Run ultra-verifier (at least TWICE; a THIRD time if anything is uncertain)

Launch a dedicated verification sub-agent that loads `fx-ultra:ultra-verifier`. It detects the stack(s), launches the real local stack, drives it by the right modality (web→Playwright MCP, mobile→emulator/simulator, CLI→real invocation, API/backend→real requests + DB inspection, desktop→driver), and exercises happy paths, error/empty/loading states, and adjacent regressions.

```
Agent tool:
  prompt: "Load the ultra-verifier skill (Skill tool: skill='fx-ultra:ultra-verifier'), then:

           Verify PR #[PR_NUMBER] (branch [BRANCH]) end-to-end against the REAL running stack.

           Verification ledger (every item MUST get direct-observation evidence):
           [LEDGER ITEMS FROM 5.5.1 + the PR Test Plan items]

           Requirements:
           - Detect and launch the repo's actual local stack (see the skill).
           - Drive each ledger item by the correct modality and capture concrete
             evidence (DOM/a11y snapshots, console, network, API/DB responses,
             CLI stdout/exit codes, emulator dumps) — NEVER screenshots, NEVER
             'the code looks right'.
           - Run the FULL verification at least twice; if any item is ambiguous or
             flaky, run a third independent pass. Flaky = FAIL.
           - Emit the strict ULTRA-VERIFIER VERDICT block (PASS/FAIL/BLOCKED) with
             per-item evidence.

           Output: the verdict block verbatim."
  description: "Ultra-verify end-to-end"
```

**Interpreting the verdict:**
- **PASS** (≥2 passes, every ledger item has direct evidence) → proceed.
- **FAIL** → go to 5.5.4 (fix loop).
- **BLOCKED** → the stack genuinely cannot be run (missing MCP/emulator/secrets). This is NOT a pass. Report the exact blocker to the user, and for any item that cannot be machine-verified, fall back to **manual verification** (5.5.3). Never let BLOCKED silently substitute for PASS — `fx-ultra:ultra-judge` will HALT on that.

#### 5.5.3 Manual-only items (external systems, accounts, physical devices)

**⛔ NEVER silently skip manual-only items.** For anything the verifier genuinely cannot exercise (e.g., "send a real Discord message", "charge a real card"), tell the user exactly what to test, ask them to confirm pass/fail, and **wait** for their answer before proceeding.

#### 5.5.4 Fix loop on FAIL

If ultra-verifier returns FAIL:

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-ultra:coder'), then:
           Fix these end-to-end verification failures:
           [FAILING LEDGER ITEMS + evidence from the verdict]
           Push fixes to the PR branch."
  description: "Fix verification failures"
```

After fixes are pushed, **re-run ultra-verifier from scratch (5.5.2)** — fixes can regress other items, so a partial re-check is forbidden. **Max 3 fix iterations**, then STOP and report persistent failures to the user. Never paper over a FAIL by editing the ledger or the test plan.

#### 5.5.5 Record results in the PR description

Update the PR's Test Plan to reflect what ultra-verifier proved:
- Verified pass → `- [x]`
- Verified fail → leave `- [ ]` + `— FAILED: [reason]`
- Manual, user-confirmed → `- [x]` + `(manually verified)`
- Manual, pending → `- [ ]` + `— requires manual testing`

```bash
gh pr edit [PR_NUMBER] --body "$UPDATED_BODY"
```

**⛔ DO NOT PROCEED to Step 5.6 until ultra-verifier returns PASS (or every residual item is an explicit, user-acknowledged BLOCKED/manual case).**

---

### STEP 5.6: Ultra-Design Review (VISUAL/UX POLISH — ULTRA MANDATE #3)

**MANDATORY whenever the change has ANY visual/UI surface.** If the diff touches components, templates, styles, or anything a user sees, it MUST pass `fx-ultra:ultra-designer` before proceeding. Skip this step ONLY when the change has zero visual surface (pure backend/CLI/lib) — and state that you're skipping it and why.

Detect a visual surface:

```bash
git diff main --name-only | grep -E '\.(tsx|jsx|vue|svelte|astro|html|css|scss|sass|less|styl)$|stories\.' || echo "no obvious visual surface"
```

The verifier already launched the real stack in 5.5; ultra-designer inspects that running app's **live DOM and computed styles** (never screenshots).

```
Agent tool:
  prompt: "Load the ultra-designer skill (Skill tool: skill='fx-ultra:ultra-designer'), then:

           Review the visual/UX surfaces changed in PR #[PR_NUMBER] (branch [BRANCH])
           with extreme prejudice against the skill's design principles.

           Cover, with observed evidence (computed styles / a11y-tree facts via
           Playwright MCP — NEVER screenshots):
           - Design-principle rubric (hierarchy, spacing scale, type, color/contrast, alignment)
           - The FULL interactivity-state matrix (default/hover/focus-visible/active/
             disabled/loading/selected/error/empty) for every interactive element
           - Motion/transitions where warranted + prefers-reduced-motion honored
           - Responsive sweep across viewports + no overflow/layout-shift
           - Accessibility (keyboard, focus order, roles/labels, hit areas)

           Emit the strict ULTRA-DESIGNER VERDICT block (PASS/FAIL/BLOCKED) with
           per-finding observed evidence.

           Output: the verdict block verbatim."
  description: "Ultra-design polish review"
```

On **FAIL**, loop through the coder skill to fix the findings, then **re-run ultra-designer from scratch** (max 3 iterations; then escalate). Do NOT merge un-polished UI.

**⛔ DO NOT PROCEED to Step 6 until ultra-designer returns PASS (or the change genuinely has no visual surface).**

---

### STEP 6: Review & Quality

**MANDATORY: Execute ALL sub-steps.**

#### 6.1 Self-Review

```
Agent tool:
  prompt: "Load the pr-reviewer skill (Skill tool: skill='fx-ultra:pr-reviewer'), then:

           Review PR #[NUMBER] for:
           - Code quality
           - Test coverage
           - Security issues
           - Performance

           Output: Issues found (if any)"
  description: "Review PR"
```

#### 6.2 Fix Issues (if any found)

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-ultra:coder'), then:

           Fix these issues in PR #[NUMBER]:
           [ISSUES FROM REVIEW]"
  description: "Fix review issues"
```

#### 6.3 Automated Reviewer Wait (Copilot + CodeRabbit + future)

**MANDATORY: Wait for and resolve EVERY automated reviewer configured on the repo.** Copilot and CodeRabbit are the two we know about today; future integrations slot in here. Reviewers are **independent feedback channels** with different latencies (Copilot ≈30–90 s; CodeRabbit 2–10+ min and re-runs after every push).

> **CodeRabbit was already run LOCALLY in Step 4.5** (`cr review --agent`), so the PR should open clean. The CodeRabbit handling here is a **fallback merge gate** for repos whose CodeRabbit GitHub App also auto-reviews PRs: clear its `CodeRabbit` check and any threads it posts. If a clean local `cr` review ran and the App is not configured (no `CodeRabbit` check appears), this gate is already satisfied — don't block on it.

##### Reviewer-by-reviewer skills

| Reviewer | Skill | Notes |
|----------|-------|-------|
| GitHub Copilot | `fx-ultra:copilot-review` | Auto-reviews; we explicitly request via API as a defensive belt. Does NOT re-review on push by default. |
| CodeRabbit | `fx-ultra:coderabbit-review` | Already run **locally** in Step 4.5 (`cr`). Here = fallback PR-level gate when the GitHub App auto-reviews PRs: **re-reviews after every push**, exposes state via the `CodeRabbit` check; cycle until terminal AND 0 threads. Skip if not configured. |

##### Pick the right execution mode for your context

**⛔ CRITICAL:** the right mode depends on whether YOU can spawn sub-agents right now.

- **You ARE the root session / a standalone caller of `fx-ultra:dev`** → use **mode A (parallel sub-agents)**.
- **You are a `fx-ultra:team` coordinator OR a sub-agent yourself** → sub-agents CANNOT spawn sub-agents. Use **mode B (sequential, with background wait scripts)**. Do NOT call the Agent tool here.

If unsure: assume mode B. It's strictly slower but always correct; mode A is an optimisation that requires you to be a top-level agent.

###### Mode A: parallel sub-agents (root session only)

In a single message, spawn one sub-agent per reviewer using the Agent tool. Both wait scripts run concurrently and each resolves its own reviewer.

```
Agent tool (spawn ALL reviewer sub-agents in the same message — parallel):

Agent 1:
  prompt: "Load the copilot-review skill (Skill tool: skill='fx-ultra:copilot-review'),
           then run it for PR #[PR_NUMBER]. Loop until 0 unresolved Copilot threads.
           Report when done."
  description: "Wait/resolve Copilot review"

Agent 2:
  prompt: "Load the coderabbit-review skill (Skill tool: skill='fx-ultra:coderabbit-review'),
           then run it for PR #[PR_NUMBER]. Loop until the CodeRabbit check is terminal
           AND 0 unresolved CodeRabbit threads. Report when done."
  description: "Wait/resolve CodeRabbit review"
```

Wait for **all** sub-agents to report completion before proceeding.

###### Mode B: sequential, with background wait scripts (team-coordinator / sub-agent)

You can't spawn sub-agents, so handle each reviewer's wait+resolve lifecycle yourself, sequentially. To recover some parallelism, kick off the slow waiter (CodeRabbit) in the background while you handle the fast one (Copilot) in the foreground. When Copilot is done, switch to CodeRabbit.

Concrete recipe:

1. Start the CodeRabbit waiter as a background bash process — its output streams to a file you can poll later:
   ```bash
   bash [SKILL_BASE_DIR]/skills/coderabbit-review/scripts/wait-for-coderabbit-review.sh [PR_NUMBER] \
        > /tmp/coderabbit-wait-[PR_NUMBER].log 2>&1
   ```
   Use `Bash` with `run_in_background: true`. Capture the task ID.
2. In the foreground, run the Copilot wait+resolve cycle by invoking the skill directly:
   ```
   Skill tool: skill="fx-ultra:copilot-review", args="[PR_NUMBER]"
   ```
   That skill polls Copilot, then calls `fx-ultra:resolve-pr-feedback` to fix and resolve threads. When it returns, Copilot is settled (for this pass).
3. Wait for the background CodeRabbit waiter to finish (you'll receive a completion notification) or check its log; when its check is terminal, invoke the resolver directly:
   ```
   Skill tool: skill="fx-ultra:rabbit-feedback-resolver", args="[PR_NUMBER]"
   ```
4. If either resolver pushed commits in steps 2–3, **CodeRabbit will re-run** on the new SHA. Restart at step 1 (relaunch the background waiter; it observes the now-pending check). Copilot does not re-review on push, but check for new threads anyway:
   ```bash
   gh api graphql -f query='...' --jq '[.threads ... copilot ...] | length'
   ```
   If 0, skip step 2. Otherwise re-run it.
5. **Stop when two consecutive passes produce zero new feedback from any reviewer** (and CodeRabbit's check is `success`).

If `Bash` `run_in_background` isn't available in your context, fall back to fully-serial: Copilot first, then CodeRabbit. Slower but correct.

##### Cycle until convergence (both modes)

Either reviewer's resolver may push commits to fix feedback. Pushed commits restart CodeRabbit's review automatically (its check goes back to pending), and may produce new Copilot feedback. Repeat the wait+resolve loop until two consecutive passes produce zero new feedback from either reviewer.

**Cap at 4 outer iterations.** If reviewers keep producing new feedback after 4 cycles, escalate to the user — this usually indicates a design disagreement, not more code edits.

##### Skip rules (use sparingly)

- If a reviewer is **not configured** for the repo (e.g. `wait-for-coderabbit-review.sh` exits 2 because no `CodeRabbit` check ever appears), report this to the user once and proceed without that reviewer.
- Never silently skip a reviewer that IS configured. If it's slow or stuck, prefer raising the timeout to skipping it.

**⛔ DO NOT PROCEED until every configured reviewer has a terminal-passing check AND 0 unresolved threads.**

---

### STEP 7: CI/CD Monitoring

**MANDATORY: Execute ALL sub-steps. Maximum 3 fix iterations.**

Because Step 5 opens the PR ready for review (NOT draft), CI workflows that
trigger on `pull_request` start immediately. There is no draft → ready
transition to manage in this workflow.

#### 7.1 Wait for CI Checks to Start and Complete

**Run the bundled CI check script in the FOREGROUND:**

```bash
# CRITICAL: Run in FOREGROUND — do NOT use run_in_background
bash [SKILL_BASE_DIR]/skills/dev/scripts/wait-for-ci-checks.sh [PR_NUMBER]
```

**⚠️ CRITICAL: Run this script in the FOREGROUND with `timeout: 600000` (10 minutes) on the Bash tool call.** Do NOT use `run_in_background`. Running in the background causes output to be lost and prevents the workflow from properly reacting to the results.

Script behavior:
- Phase 1: Waits for checks to appear (some repos have a startup delay)
- Phase 2: Polls every 30s until all checks complete (timeout: 900s / 15 minutes)
- Exit 0: All checks passed → **proceed to Step 8**
- Exit 1: One or more checks failed → **proceed to Step 7.2**
- Exit 2: Timeout waiting for checks → report to user, ask whether to continue waiting or proceed
- Exit 3: Invalid arguments or gh error

#### 7.2 Handle CI Failures (LOOP — max 3 iterations)

**If Step 7.1 exits with code 1 (failures detected):**

```
Skill tool: skill="fx-ultra:resolve-ci-failures"
```

Pass the failure details from the script output to the skill. The skill will:
1. Analyze failure logs and identify root causes
2. Delegate fixes to a sub-agent with the coder skill
3. Push the fixes

**After the skill completes and fixes are pushed, GO BACK TO Step 7.1** — re-run the wait script to monitor the new check run. This creates a loop:

```
Step 7.1 (wait) → fail → Step 7.2 (fix) → Step 7.1 (wait) → ...
```

**⚠️ Maximum 3 iterations.** Track the current iteration count. If checks still fail after 3 fix attempts, STOP and report the persistent failures to the user with full details.

**⛔ DO NOT PROCEED until all checks pass or max iterations reached**

---

### STEP 8: Finalization

#### 8.1 Final Verification (MANDATORY MERGE GATES)

**⛔ ALL of the following must be verified before ANY PR can be merged. No exceptions.**

```bash
# 1. CI checks — ALL must be green (includes the CodeRabbit check)
gh pr checks [NUMBER]

# 2. Automated reviewers — MUST be settled and resolved (if not already done in Step 6.3)
# Use the dedicated skills — NEVER raw gh api commands.
# Run them in parallel via Agent sub-agents (see Step 6.3 pattern), or
# sequentially if you only need to spot-check.
```
```
Skill tool: skill="fx-ultra:copilot-review",     args="[NUMBER]"
Skill tool: skill="fx-ultra:coderabbit-review",  args="[NUMBER]"
```
```bash
# 3. Unresolved review threads — MUST be 0 (across ALL reviewers)
gh pr view [NUMBER] --json reviewThreads \
  --jq '[.reviewThreads[] | select(.isResolved == false)] | length'

# 4. Codecov — patch and project checks must pass
gh pr checks [NUMBER]  # verify codecov/patch and codecov/project
```

**Merge gate checklist (every item must pass):**
- [ ] PR is open and mergeable
- [ ] **PR title is a conventional-commit subject** (`type(scope): description`) — verify `gh pr view [NUMBER] --json title -q .title | grep -Eq '^(feat|fix|docs|refactor|chore|test|perf|build|ci|style|revert)(\(.+\))?!?: .+'`; a plain prose title FAILS — rename with `gh pr edit [NUMBER] --title "type(scope): …"` BEFORE merging (squash bakes the title into `main`). Also no stray `#<number>`/wave/phase wording.
- [ ] ALL CI checks green
- [ ] Copilot review RECEIVED and ALL threads resolved (via `fx-ultra:copilot-review` skill — NEVER raw `gh api`)
- [ ] CodeRabbit check is in a terminal passing state AND ALL CodeRabbit threads resolved (via `fx-ultra:coderabbit-review` skill). If CodeRabbit is not configured for the repo, this gate is satisfied by an exit-code-2 from `wait-for-coderabbit-review.sh` — confirm with the user.
- [ ] No reviewer has posted new feedback since the last fix push (the wait-and-resolve loop has converged)
- [ ] Codecov coverage passing with 0 missing lines
- [ ] No unresolved review threads from any reviewer (Copilot, CodeRabbit, human, or future automated reviewer)
- [ ] **100% line+branch coverage on changed code** (STEP 4.6) — not lowered, not excluded, not faked
- [ ] **`fx-ultra:ultra-verifier` returned PASS** (STEP 5.5) — ≥2 passes, every observable item has direct-observation evidence; no BLOCKED standing in for PASS
- [ ] **`fx-ultra:ultra-designer` returned PASS** (STEP 5.6) — full interactivity-state matrix + responsive + a11y, OR the change genuinely has no visual surface
- [ ] **`fx-ultra:ultra-judge` will be run in STEP 9 and must return APPROVE** before the work is declared complete / the PR is merged

**PR size is NEVER a reason to skip merge gates.** A 1-line fix gets the same verification as a 1000-line feature.

The PR was opened ready-for-review in Step 5, so there is no draft → ready
transition to perform here. Do NOT run `gh pr ready` — it is unnecessary and
will fail on a non-draft PR.

#### 8.2 Update Task Tracking Docs

**MANDATORY: Mark completed tasks in the relevant change document or tasks file.**

If a change document or task list was referenced in the original request (e.g., a `docs/changes/NNNN-name.md` or `docs/tasks.md`), use it directly. If none was provided, search for the relevant tracking doc:

```bash
# Look for change documents or tasks that reference the work being done
grep -rl "keyword from task" docs/changes/ docs/tasks.md 2>/dev/null || true
```

Once identified, update the doc to mark completed tasks:
- Check off completed items (e.g., `- [ ]` → `- [x]`)
- Add the PR number: `- [x] Task name (PR #N)`
- Only mark items that are **actually addressed by the changes in this PR**
- If ALL tasks in a change document are now complete, update its Status to `complete`
- Commit the doc update to the PR branch

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-ultra:coder'), then:

           Update task tracking in [DOC_PATH]:
           - Read the doc and identify tasks completed by PR #[NUMBER]
           - Mark those tasks as done: - [x] Task name (PR #N)
           - Do NOT mark tasks that were not addressed
           - If all tasks in a change doc are done, update Status: complete
           - SYNC INDEXES: Update docs/index.yml (status field) and docs/index.md (table row) to match
           - Commit the change with: docs: mark completed tasks in [DOC_NAME]
           - Push to the PR branch"
  description: "Update task tracking"
```

If no relevant tracking doc is found, skip this step.

#### 8.3 Update Issue (if applicable)

```
Agent tool:
  prompt: "Load the issue-updater skill (Skill tool: skill='fx-ultra:issue-updater'), then:

           Update issue #[NUMBER]: Link PR, set label ready-for-review"
  description: "Update issue"
```

#### 8.4 Report to User

```
✅ PR #[NUMBER] ready: [URL]

Changes:
- [summary bullets]

Awaiting your approval to merge.
```

**⚠️ NEVER MERGE WITHOUT USER APPROVAL**
**⚠️ NEVER MERGE WITHOUT ALL MERGE GATES PASSING (Step 8.1)**
**⚠️ NEVER MERGE WITHOUT COPILOT REVIEW RECEIVED AND ADDRESSED**
**⚠️ NEVER DECLARE COMPLETE / MERGE WITHOUT AN `APPROVE` FROM ULTRA-JUDGE (Step 9)**

> Note: 8.4 reports the PR as ready, but the work is NOT actually complete until STEP 9 (ultra-judge) returns APPROVE. Run STEP 9 before telling the user the task is done or merging.

---

### STEP 9: Ultra-Judge Final Verdict (TERMINAL GATE — BINDING)

**MANDATORY, ALWAYS, LAST.** After STEP 8 claims everything is done, `fx-ultra:ultra-judge` independently audits the WHOLE progression against the ultra bar — with suspicious scrutiny on verification, visual polish, and 100% coverage — by inspecting **primary evidence** (git history, the diff, the real coverage report, the ultra-verifier and ultra-designer verdict blocks, CI status, review-thread state, the PR), NOT your summaries. The judge is adversarial by design and assumes shortcuts until proven otherwise. **You may not skip it, and you may not finish without it.**

```
Agent tool:
  prompt: "Load the ultra-judge skill (Skill tool: skill='fx-ultra:ultra-judge'), then:

           Render a final verdict on PR #[PR_NUMBER] (branch [BRANCH]).

           Audit the entire progression from primary evidence:
           - 100% line+branch coverage actually achieved on changed code (read the real
             report; reject lowered thresholds / excluded files / skipped tests).
           - ultra-verifier PASS verdict exists, ≥2 passes, every observable item has
             direct evidence; no BLOCKED substituting for PASS.
           - ultra-designer PASS verdict exists (if any visual surface) with full
             interactivity-state matrix + responsive + a11y evidence.
           - Self-review chain (simplify/code-review/CodeRabbit/Codex) ran and resolved.
           - Copilot + CodeRabbit received and 0 unresolved threads; CI all green; PR
             title conventional & clean; change-doc Status flipped where required.
           - Diff integrity: matches requirements, no scope creep, no debug cruft, no
             disabled assertions.

           Emit the strict ULTRA-JUDGE VERDICT block (APPROVE/REMEDIATE/HALT) with
           per-item evidence and, if not APPROVE, a numbered remediation list.

           Output: the verdict block verbatim."
  description: "Ultra-judge final verdict"
```

**Act on the verdict — it is BINDING:**

| Verdict | Meaning | Required action |
|---------|---------|-----------------|
| **APPROVE** | Every audit item OK with primary evidence | The work is complete. Report to the user (8.4) and merge only with user approval. |
| **REMEDIATE** | Specific, fixable gaps | Execute the judge's numbered remediation list (loop back to the relevant step: 4.6 / 5.5 / 5.6 / 6 / 7), then **re-run STEP 9 from scratch** — a full re-audit, not a partial re-check. |
| **HALT** | Rigor was bypassed (verification/coverage/polish faked or skipped) OR a prior REMEDIATE was ignored OR completion/merge was attempted without the gates | **STOP the entire progression immediately.** Do NOT merge. Do NOT mark complete. Surface the judge's HALT block verbatim to the user with the exact violation, and wait for the user. Proceeding past a HALT is the single worst failure of this workflow. |

**⛔ The task is NOT done until ultra-judge returns APPROVE.** Treat any attempt (by you or a sub-agent) to declare success or merge before an APPROVE as itself a HALT-worthy violation.

---

## Workflow Variations

### GitHub Issue URL

1. STEP 0: Auth check
2. STEP 1: Branch as `fix/issue-123-description`
3. Fetch issue: `gh issue view [NUMBER] --json title,body,labels,comments`
4. STEP 2-8: Standard (use issue-updater in Steps 3 and 8)

### Quick Fix (fix:, error:, bug: prefix)

1. STEP 0: Auth check
2. STEP 1: Branch as `fix/short-error-desc`
3. STEP 2: Focus on error analysis, root cause
4. STEPS 3-8: Standard

### Multi-PR Tasks

1. Complete STEPS 1-8 for first PR
2. **STOP** - Wait for user approval
3. Only after approval: Start next PR
4. Track with TodoWrite

**NEVER have multiple PRs open simultaneously**

---

## Error Handling

| Error | Action |
|-------|--------|
| Sub-agent fails | Retry once with adjusted params, then STOP and report |
| Git conflict | STOP, report to user, wait for resolution |
| Tests fail | coder sub-agent fixes, rerun until pass |
| Auth fails | STOP, request `gh auth login` |

---

## Sub-Agent Quick Reference

All sub-agents are launched via the Agent tool. Each loads its skill via the Skill tool inside the sub-agent.

| Step | Skill to Load | Skill Name |
|------|---------------|------------|
| 2 | Requirements Analyzer | `fx-ultra:requirements-analyzer` |
| 3 | Planner | `fx-ultra:planner` |
| 3,8 | Issue Updater | `fx-ultra:issue-updater` |
| 4,6.2,8.2 | Coder | `fx-ultra:coder` |
| 4.5 | Pre-PR Self-Review | `simplify`, then `code-review`, then `fx-ultra:coderabbit-review` (local `cr`), then `fx-ultra:codex-review` (local `codex`) — all must be clean before opening the PR |
| 4.6 | 100% Coverage Gate | `fx-ultra:coder` (add tests until changed code is fully covered) |
| 5 | PR Preparer | `fx-ultra:pr-preparer` |
| 5.5 | Ultra-Verification (end-to-end) | `fx-ultra:ultra-verifier` — run ≥2×, 3× if uncertain; PASS required |
| 5.6 | Ultra-Design Review (any UI) | `fx-ultra:ultra-designer` — PASS required for visual surfaces |
| 6.1 | PR Reviewer | `fx-ultra:pr-reviewer` |
| 6.3 | Copilot Review | `fx-ultra:copilot-review` (run in parallel with coderabbit-review) |
| 6.3 | CodeRabbit Review | `fx-ultra:coderabbit-review` (run in parallel with copilot-review; cycles on its check until terminal + 0 threads) |
| 6.3 | PR Feedback Resolver | `fx-ultra:resolve-pr-feedback` (meta — called by reviewer skills) |
| 7.2 | CI Failure Resolver | `fx-ultra:resolve-ci-failures` |
| 9 | Ultra-Judge (terminal gate) | `fx-ultra:ultra-judge` — APPROVE required to complete/merge; can HALT |

**Pattern for every sub-agent call:**
```
Agent tool:
  prompt: "Load the [skill-name] skill (Skill tool: skill='[full-skill-name]'), then: [task]"
  description: "[summary]"
```

---

## Success Criteria

Workflow complete when ALL true:
- ✅ Feature branch created from main
- ✅ Requirements documented
- ✅ Plan created
- ✅ Code implemented with atomic commits
- ✅ Pre-PR self-review clean: /simplify (reuse, quality, efficiency), /review (correctness), a local CodeRabbit `cr` review, AND a local Codex `codex` review — all findings resolved BEFORE the PR was opened
- ✅ **100% line+branch coverage on changed code (STEP 4.6)** — real, meaningful tests; thresholds not lowered, files not excluded, no skips
- ✅ PR created with description (including links to related specs/changes and test plan)
- ✅ **Ultra-verified end-to-end (STEP 5.5): `fx-ultra:ultra-verifier` returned PASS** — ran ≥2×, every observable item proven against the real running stack with direct evidence; manual-only items user-confirmed; nothing silently skipped or left BLOCKED-as-PASS
- ✅ **Ultra-design PASS (STEP 5.6) for any visual surface**: `fx-ultra:ultra-designer` confirmed full interactivity-state matrix, motion, responsiveness, and a11y — or the change has no visual surface
- ✅ PR test plan items checked off or annotated with verification results in the PR description
- ✅ Self-review done, issues fixed
- ✅ Automated review feedback resolved (Copilot AND CodeRabbit, run in parallel; cycle until both converge with zero new feedback)
- ✅ All CI/CD checks pass
- ✅ Task tracking docs updated (completed tasks marked in relevant change doc or tasks.md)
- ✅ **`fx-ultra:ultra-judge` returned APPROVE (STEP 9)** — the whole progression independently judged rigorous; no HALT outstanding
- ✅ User notified, awaiting merge approval
