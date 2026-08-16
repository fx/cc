---
name: dev
description: "MUST BE LOADED for any coding task: implementing features, fixing bugs, writing code, refactoring, or making changes. This skill provides the mandatory step-by-step SDLC (Software Development Lifecycle) workflow for orchestrating development using specialized skills and sub-agents. Load this skill when the user asks to 'add', 'create', 'build', 'fix', 'update', 'change', 'implement', or 'refactor' anything."
---

# Dev — SDLC Workflow Skill

This skill defines the **mandatory** workflow for all coding tasks. Follow these steps IN ORDER. Skipping steps is FORBIDDEN.

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

<!--
duvet= docs/specs/fx-dev-authority/index.md#the-dev-coordinator-delegates-all-writes
duvet= type=implication
duvet# The `fx-dev:dev` coordinator MUST NOT write code, create files, or make commits itself, and MUST delegate that work to sub-agents.
-->

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
- ✅ ALWAYS carry the Scope Brief (Step 2.5) verbatim into every sub-agent prompt and every reviewer call

**FAILURE TO USE SUB-AGENTS = WORKFLOW FAILURE**

### Scope Discipline (STOP rule)

**When the work outgrows the request, stop and tell the user.** Do not silently
deliver more than was asked. Full rule and calibration:
`references/scope-contract.md`.

Stop when you discover the task needs materially more than its own framing
implies: subsystems the user never named, a migration or breaking change, several
PRs where one was implied, or an architectural decision the user has not made.
Report in two or three sentences — what you found, why it exceeds the request,
the cheapest path forward — offer the narrow option first, and wait. Deliver
everything unambiguously in scope first; never stop with nothing done.

The threshold moves with the Scope Brief's size signal: a `narrow` request stops
at any overrun, `normal` stops at an unmade decision or a reach beyond the named
subsystem, `open-ended` stops only at architectural forks or irreversible actions.

**Do NOT stop for work inside the request's natural boundary:** tests for code you
just wrote, docs the change invalidates, fixing a build you broke, following an
approved change document to completion, or resolving findings classified
`required-by-contract` / `regression-caused-by-change`. Over-triggering is its own
failure mode.

### Test Policy

**⛔ NEVER skip tests.** If a test cannot pass:
- **Fix it** - Update assertions to match correct behavior
- **Replace it** - Write a new test that properly validates the behavior
- **Refactor it** - Restructure to test what's actually testable
- **Remove it** - Delete entirely if it tests something that no longer exists

If tests require infrastructure (auth, database, external services), SET UP that infrastructure. Do not skip tests because setup is hard.

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
  prompt: "Load the requirements-analyzer skill (Skill tool: skill='fx-dev:requirements-analyzer'), then:

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

### STEP 2.5: Freeze the Scope Brief and Implementation Contract, and Open the Finding Ledger

**First, build the Scope Brief.** It is the user's own framing, and it must
survive every sub-agent hop and every reviewer call. Full definition and field
rules: `references/scope-contract.md` (beside this skill).

```markdown
### Scope Brief
- **Verbatim request:** "<the user's exact words, quoted, never paraphrased>"
- **Interpreted scope:** <files, subsystems, deliverable>
- **Deliverable type:** <docs | code | spec | research | config | mixed>
- **Explicitly out of scope:** <what must NOT be touched or flagged, with reasons>
- **Size signal:** <narrow | normal | open-ended>
- **Known-and-accepted:** <deliberate states a reviewer would otherwise flag>
```

Derive **size signal** from the user's own language: "just", "real quick",
"only", "small", "minimal" → `narrow`; "thoroughly", "comprehensive", "audit",
"properly" → `open-ended`; otherwise `normal`. A `narrow` request is a budget,
not filler — honour it.

**The Scope Brief MUST be included verbatim in every downstream sub-agent prompt
and every reviewer invocation in Steps 3, 4, 4.5, 6, and 8.** A reviewer without
it reports the work you deliberately did not do, and every such finding costs a
full review cycle to filter by hand.

**Then freeze the implementation contract.** If the task is sourced from, names, or discovers a relevant `docs/changes/*.md` file, read it and the spec sections it links. Confirm implementation approval from the conversation or the change's recorded workflow state; if approval is unclear, STOP and ask the user. Record the contract path and approval evidence in the working brief. The change document, its linked specs, and all mandatory project rules form the implementation contract: the plan and coder prompt MUST map work to that contract and MUST NOT infer adjacent product or architecture work.

The coordinator owns one in-memory finding ledger for the run; reviewer sub-agents return findings to the coordinator and MUST NOT mutate the ledger concurrently. Give every finding a stable fingerprint (`category + file + line/range + normalized claim`) and record its source, first-seen revision, classification, materiality tier, disposition, and verification evidence. Classification and materiality are independent fields — see Step 4.5 for how the tier is assigned. The tier is `n/a` for a contract blocker: filter 2 stops before the bar, so a rule violation is never ranked, and inventing a tier for one is the mistake that lets it be argued down. Classify each finding exactly once as:

- **required-by-contract** — Necessary to satisfy the change document, its linked specs, or any mandatory project, security, privacy, test, or merge rule.
- **regression-caused-by-change** — A demonstrable correctness, security, privacy, or data-loss regression caused by this branch anywhere within its behavioral impact, including downstream consumers or integrations.
- **follow-up/out-of-scope** — A pre-existing issue, hardening, cleanup, product addition, architecture expansion, or improvement not required by either category above.

Fix the first two classes, and any entry that is blocking by tier — a reviewer-originated Material or Substantive finding blocks even where no written rule names it (`references/scope-contract.md` § Blocking). Deduplicate repeated or reworded findings by fingerprint and update the existing ledger entry. Record every **non-blocking** entry for the PR or later tracking without implementing it — `follow-up/out-of-scope` at tier `n/a` or `immaterial`. An entry of that class that blocks by tier is fixed like any other blocker; the class name never decides remediation. When reviewer resolvers are invoked by `/dev`, their deferred-feedback paths MUST return follow-ups to the coordinator instead of modifying task trackers in the implementation PR. To implement out-of-scope product or architecture work, first amend the change document and obtain user approval.

---

### STEP 3: Planning

**MANDATORY: Launch a sub-agent that loads the planner skill.**

```
Agent tool:
  prompt: "Load the planner skill (Skill tool: skill='fx-dev:planner'), then:

           [PASTE THE STEP 2.5 SCOPE BRIEF VERBATIM HERE]

           Create implementation plan for:

           [REQUIREMENTS FROM STEP 2]

           - Keep the plan inside the Scope Brief; if the work cannot be done
             within it, stop and report that rather than planning around it
           - Break into atomic steps
           - Identify files to modify
           - Determine test requirements
           - Flag if multiple PRs needed
           - Treat the approved change document as the implementation contract
           - Do not include non-blocking follow-up/out-of-scope work, or expand product/architecture, without an approved amendment

           Output: Numbered implementation steps"
  description: "Plan implementation"
```

For GitHub issues, also update issue:
```
Agent tool:
  prompt: "Load the issue-updater skill (Skill tool: skill='fx-dev:issue-updater'), then:

           Update issue #[NUMBER] with plan. Add label: in-progress"
  description: "Update issue"
```

**⛔ DO NOT PROCEED until plan exists**

---

### STEP 4: Implementation

**MANDATORY: Launch a sub-agent that loads the coder skill.**

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

           [PASTE THE STEP 2.5 SCOPE BRIEF VERBATIM HERE]

           Implement this plan:

           [PLAN FROM STEP 3]

           Requirements:
           - Stay inside the Scope Brief; if implementation cannot be completed
             within it, stop and report rather than widening the change
           - Atomic commits (format: type(scope): message)
           - Follow existing patterns
           - Run tests
           - Treat the approved change document as the implementation contract
           - Do not implement non-blocking findings, or expand product/architecture, without an approved amendment (an entry blocking by tier is fixed whatever its class)
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

**MANDATORY: Run one complete local review matrix before creating the PR.** Run each available pass once in order against the current `HEAD`, record the revision that each channel reviewed, and classify its findings before accepting fixes. If `/simplify` edits directly, retain only changes that satisfy the contract classification and record the resulting revision before starting the next pass.

**⛔ EVERY pass below MUST receive the Step 2.5 Scope Brief verbatim.** A reviewer handed a bare diff reports the work you deliberately did not do — missing implementation for a docs-only change, missing tests for a spec, dependencies a later phase adds — and each such finding costs a full cycle to filter by hand. A pass run without the brief is incomplete: rerun it with the brief rather than filtering its output. Findings the brief excludes are recorded as deferred with the covering exclusion, never silently fixed and never silently dropped — unless one of the two conditions in `references/scope-contract.md` § Three filters, filter 1 re-opens scope, in which case fix the work and correct the brief. A finding being merely correct is not one of them.

**1. `/simplify`** — reuse, quality, efficiency cleanup:

```
Skill tool: skill="simplify", args="<Scope Brief>"
```

Reviews changed code for **reuse** (duplicated logic), **quality** (copy-paste, leaky abstractions, nesting), and **efficiency** (redundant computation, missed concurrency).

**2. `/code-review`** — correctness bugs in the diff:

```
Skill tool: skill="code-review", args="<Scope Brief>"
```

**3. CodeRabbit (local, via `cr`)** — independent local review:

```
Skill tool: skill="fx-dev:coderabbit-review", args="<Scope Brief>"
```

If `cr` is **unavailable**, fall back to the PR-level CodeRabbit review in Step 6.3. If `cr` is installed but **not authenticated**, STOP and report to the user — NEVER run `cr auth login`. If CodeRabbit reports a rate/quota limit or cooldown, report it once, classify findings already received and resolve the blocking ones, mark the pass `skipped (rate-limited)`, and continue immediately. Throttling waives the unrun remainder of the review, never a finding already delivered. Never wait or retry solely for a CodeRabbit cooldown.

**4. Codex (local, via `codex`)** — independent one-shot branch review:

```
Skill tool: skill="fx-dev:codex-review", args="<Scope Brief>"
```

The Codex CLI takes the scope as its review prompt, so this pass is the one where a missing brief is most expensive — it will confidently report every deliberate omission. If the `codex` CLI is unavailable or not authenticated, report it once and proceed without this pass. NEVER run `codex login`.

#### Remediation and Delta Verification

**Record each finding's class, not just its location** (`references/scope-contract.md` § Fix the class, not the instance). A reviewer reports the instance it read; the ledger entry names the defect pattern and every site in the change's surface that exhibits it, so a fix closes the class rather than buying the next cycle its input. A ledger entry is not resolved while a sibling of its class is open, and a reviewer MUST NOT be re-run with a class half-closed.

Fix every **blocking** ledger entry (`references/scope-contract.md` § Blocking): everything classified `required-by-contract` or `regression-caused-by-change`, plus any entry blocking by tier — a reviewer-originated Material or Substantive finding blocks even where no written rule names it. After a fix commit:

1. Rerun the reviewer or check that originated the blocking finding.
2. Rerun tests affected by the delta.
3. Rerun another reviewer only when the delta touches the risk area that reviewer covered or invalidates its recorded evidence.

Do not restart the full matrix merely because `HEAD` changed. Deduplicate repeated or reworded findings against the ledger; they do not start a new cycle. When `/dev` invokes reviewer subskills, this contract classification and bounded stopping policy takes precedence over generic instructions to resolve every actionable finding or rerun until clean.

**The materiality bar applies to judgment-originated findings only** — things a reviewer raised on its own reading, rather than violations of a rule the project wrote down (`references/scope-contract.md`). One of those must clear the bar before it can be treated as blocking. Materiality is a **separate ledger field**, not a fourth classification — every entry still carries exactly one of the three classifications above, plus a materiality tier. An observation that would change nothing if it shipped uncorrected is recorded as `follow-up/out-of-scope` with materiality `immaterial`, and never triggers a rerun.

**Rule violations are blocking regardless of materiality.** Anything Step 2.5 defines as `required-by-contract` — project, security, privacy, test and merge rules the project wrote down — is blocking by virtue of being a rule, whatever its direct behavioural impact. The contract filter runs before the bar, exactly as `references/scope-contract.md` § Three filters specifies, so the coordinator can never demote a violation the reviewer correctly marked blocking. Two shapes in particular are non-findings and MUST NOT enter the ledger as blocking: a missing entry in a list the artifact does not present as exhaustive, whether it says "for example" or declares the list illustrative, and a decision the artifact records with its rationale **where the disagreement is about preference**. The second, raised again in the very next pass, is an escalation to the user rather than a third cycle (`references/scope-contract.md` § Convergence defines that trigger) — but a recorded rationale never makes a decision safe. The full carve-out is in `references/scope-contract.md` § Three things that are not findings and is not narrowed here: if the decision itself leaks a credential or private identifier, loses data, violates a security or privacy invariant, **or contradicts a contract the project mandates**, it is `required-by-contract` and stays blocking.

#### PR-Ready Stopping Condition

Proceed to Step 5 when all of the following are true:

1. Every **blocking** ledger entry is resolved with evidence. Blocking is defined once, in `references/scope-contract.md` § Blocking; this gate does not restate it.

   **A finding excluded at filter 1 can never carry a Material or Substantive tier.** The two fields are assigned by different filters and cannot disagree, so that one pair is illegal. Note the rule is about the *filter*, not the class name: `follow-up/out-of-scope` holds entries of two different origins, and all three tiers can be legal for it — a finding excluded at filter 1 never reaches the bar, so its tier is `n/a`; an in-scope observation that reached filter 3 and failed it is tier `immaterial`. A finding that reaches the bar and ranks Material or Substantive is in scope by construction and is a defect in work this change actually did. Where a written rule obliges the fix it is `required-by-contract`, and where the branch caused a regression it is `regression-caused-by-change` — but a reviewer-originated Material or Substantive finding that is neither, such as a two-way ambiguity in something this change wrote, is still legal in this class and **still blocks, by tier**. The classification answers what obliges the fix; the tier answers whether it blocks, exactly as the stopping condition below states. What is illegal is that tier pair on a finding excluded at filter 1, which never reached the bar. **The filter outcome decides the resolver disposition — not the class name, and not the tier** (§ Resolver dispositions). Tier `n/a` is carried by two unrelated outcomes and so cannot pick one: a contract blocker is `n/a` because filter 2 stopped before the bar, and it is **blocking** — fixed and pushed; a finding excluded at filter 1 is `n/a` because it never reached the bar, and it is **deferred**, replied to with the exclusion. Tier `immaterial` settles as `immaterial`, replying with the materiality reasoning. Read the outcome, never the tier alone. Citing an exclusion for an in-scope observation invents one that does not exist. If you are about to record that pair, one of the two filters was misapplied — re-run them rather than writing an entry the gate can neither clear nor waive. Materiality never promotes an out-of-scope finding back into scope (`references/scope-contract.md` § Three filters); this rule is that principle applied to the ledger.
2. Contract-required tests and tests affected by the latest delta pass.
3. Every available review channel completed its initial pass or has a documented permitted degradation.
4. The review has **converged** as `references/scope-contract.md` § Convergence defines it — no blocking finding left unresolved, ledger-wide, not merely none new in the latest pass. As an additional gate, that state is confirmed by one verification pass over the latest affected delta.

`follow-up/out-of-scope` entries with tier `n/a` — the class and the tier together, which is what identifies a filter-1 exclusion — and immaterial observations, do not block PR creation. Tier `n/a` alone does not qualify: a `required-by-contract` entry carries it too, and blocks. Nothing else is waivable here: a reviewer-originated Material or Substantive finding blocks even though no written requirement names it, exactly as item 1 above and `references/scope-contract.md` § Blocking say. Each review channel caps at **15 reviewer invocations in total, counting its initial pass** — the single bound defined in `references/scope-contract.md` § The iteration bound, which no skill overrides. The initial pass is iteration 1, leaving 14 remediation/delta-verification rounds; counting the bound from *after* the initial pass would make it 16. **Convergence is the goal, and the bound is a runaway backstop, not a target.** Reaching it means the loop failed to converge; report it that way. Reaching the bound is a failure to converge and does not authorize Step 5. STOP, report the per-pass trend and everything still open, and let the user decide whether to create the PR — including when every remaining entry is `follow-up/out-of-scope` with tier `n/a`. A blocking entry at the bound is always an escalation; the bound never waives one. A contract amendment may change product scope, but it cannot waive mandatory correctness, security, privacy, testing, or merge rules.

**Do not spend the headroom.** The bound is far above what a healthy channel needs; the signals that should actually end a loop — converged, and the same disagreement in successive passes (`references/scope-contract.md` § Convergence) — fire in single digits, as does a rising blocking count of one class, which is a cause to fix rather than an exit: address the cause and continue, and escalate only where the cause is a design choice with two defensible answers (`references/scope-contract.md` § The iteration bound). A round that resolves only immaterial items is churn at any iteration number, and the convergence rule already forbids it.

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
  prompt: "Load the pr-preparer skill (Skill tool: skill='fx-dev:pr-preparer'), then:

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
             body. See the fx-dev:github skill's '#<number> PR-Title Rule'.
           - Reference related issues
           - Do NOT include any 'this is a draft' / 'draft for review' language
             anywhere in the title or body
           - Return PR number and URL"
  description: "Create PR"
```

**Capture the PR number for remaining steps.**

**⛔ DO NOT PROCEED until PR is created (as ready for review)**

---

### STEP 5.5: Test Plan Verification (MANDATORY)

**This step is MANDATORY for every PR that has a test plan.** It is NOT limited to web/UI changes. Backend changes, platform integrations, CLI tools, and infrastructure changes all have test plans that must be addressed.

#### 5.5.1 Extract and Classify the Test Plan

Read the PR description and extract the Test Plan section:

```bash
gh pr view [PR_NUMBER] --json body --jq '.body'
```

Parse the `## Test plan` section. Each `- [ ]` item is a verification target.

If the PR has no Test Plan section, construct one from the PR diff — identify what changed and create verification steps. Add them to the PR description before proceeding.

**Classify each test plan item into one of three categories:**

| Category | Description | Action |
|----------|-------------|--------|
| **Browser-verifiable** | Can be tested via Playwright MCP (UI routes, visual changes, interactions) | Run verify-web-change (Step 5.5.2) |
| **Programmatically verifiable** | Can be tested via CLI, API calls, log inspection, or automated scripts | Run verification commands directly (Step 5.5.3) |
| **Manual-only** | Requires external systems, user accounts, or physical interaction (e.g., "send a Discord message", "check email") | Annotate for user and prompt them to verify (Step 5.5.4) |

#### 5.5.2 Browser Verification (for browser-verifiable items)

**Skip this sub-step if no test plan items are browser-verifiable.**

Detect if browser verification is possible:

```bash
WEB_FILES=$(git diff main --name-only | grep -E '\.(tsx|jsx|vue|svelte|html|css|scss|less)$' || true)

HAS_WEB_STACK=false
for cfg in vite.config.ts vite.config.js next.config.js next.config.ts next.config.mjs nuxt.config.ts svelte.config.js angular.json astro.config.mjs; do
    if [[ -f "$cfg" ]]; then
        HAS_WEB_STACK=true
        break
    fi
done
```

If web changes exist and browser-verifiable items are present, launch the verify-web-change sub-agent:

```
Agent tool:
  prompt: "Load the verify-web-change skill (Skill tool: skill='fx-dev:verify-web-change'), then:

           Verify the following Test Plan items for PR #[PR_NUMBER] using browser automation:

           [BROWSER-VERIFIABLE TEST PLAN ITEMS]

           For each item:
           1. Navigate to the relevant page/route
           2. Use Playwright MCP snapshots to verify the element/behavior exists
           3. Test any interactions described in the test plan item
           4. Check for console errors
           5. Report PASS/FAIL per item with evidence (what you observed)

           Output: A list of each test plan item with its result (PASS/FAIL/SKIPPED) and evidence."
  description: "Verify web changes in browser"
```

#### 5.5.3 Programmatic Verification (for programmatically verifiable items)

**Skip this sub-step if no test plan items are programmatically verifiable.**

For items that can be verified via commands (API calls, log inspection, test runs, etc.), run the verification directly:

- Check test output: `bun --bun run test` — confirm relevant tests pass
- Inspect logs: Check dev server output for expected behavior
- Call APIs: Use `curl` or similar to verify endpoint behavior
- Check database state: Verify schema/data changes applied correctly

Record PASS/FAIL per item with evidence.

#### 5.5.4 Manual Verification (for manual-only items)

**⛔ NEVER silently skip manual-only test plan items.**

For items that require manual interaction (external services, physical devices, user accounts), you MUST:

1. **Tell the user** which items require their manual verification
2. **Explain what to test** — be specific about the steps
3. **Ask them to confirm** each item passes or fails
4. **Wait for their response** before proceeding

Example:
```
The following test plan items require manual verification:
- [ ] Send a message to the Discord bot and verify the typing indicator appears immediately
- [ ] Confirm the typing indicator stays active for responses > 10 seconds

Please test these and let me know the results.
```

#### 5.5.5 Update the Test Plan in the PR Description

**MANDATORY: After all verification (automated + manual), update the PR description.**

```bash
BODY=$(gh pr view [PR_NUMBER] --json body --jq '.body')
```

For each Test Plan item:
- **Verified (pass)**: Change `- [ ]` to `- [x]`
- **Verified (fail)**: Leave as `- [ ]` and append: `— FAILED: [reason]`
- **Manual — confirmed by user**: Change `- [ ]` to `- [x]` and append: `(manually verified)`
- **Manual — not yet verified**: Leave as `- [ ]` and append: `— requires manual testing`

Update the PR:

```bash
gh pr edit [PR_NUMBER] --body "$UPDATED_BODY"
```

**⛔ DO NOT PROCEED to Step 6 until every test plan item has been addressed** — either verified (pass/fail), confirmed by user, or explicitly annotated as requiring manual testing.

#### 5.5.6 Handle Failures

If any Test Plan items failed verification:
1. Launch a sub-agent with the coder skill to fix:
   ```
   Agent tool:
     prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

              Fix these verification failures:
              [FAILURE DETAILS]
              Push fixes to the PR branch."
     description: "Fix verification failures"
   ```
2. After fixes are pushed, re-run the relevant verification step (5.5.2 or 5.5.3)
3. **Maximum 2 fix iterations.** If still failing after 2 attempts, proceed to Step 6 and note the unverified items in the PR description.

**⛔ DO NOT PROCEED until verification passes or max iterations reached**

---

### STEP 6: Review & Quality

**MANDATORY: Execute ALL sub-steps.**

#### 6.1 Self-Review

```
Agent tool:
  prompt: "Load the pr-reviewer skill (Skill tool: skill='fx-dev:pr-reviewer'), then:

           [PASTE THE STEP 2.5 SCOPE BRIEF VERBATIM HERE — the reviewer must
            know what was asked for before it reads the diff, and must report
            out-of-scope findings as deferred rather than blocking]

           Review PR #[NUMBER] for:
           - Code quality
           - Test coverage
           - Security issues
           - Performance

           Output: Issues found (if any), each marked in-scope or deferred"
  description: "Review PR"
```

The coordinator MUST classify and deduplicate these findings in the Step 2.5 ledger before invoking a coder. Pass every **blocking** entry to implementation and nothing else (`references/scope-contract.md` § Blocking) — which includes a `follow-up/out-of-scope` entry blocking by tier, and excludes an entry that is not blocking. Select on blocking, never on the tier: `n/a` marks a contract blocker (filter 2 stopped before the bar) just as it marks a filter-1 exclusion, so dropping every `n/a` entry drops every mandatory rule violation.

#### 6.2 Fix Blocking Issues (if any found)

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

           Fix only these blocking issues in PR #[NUMBER]:
           [EVERY BLOCKING LEDGER ENTRY — REQUIRED-BY-CONTRACT,
            REGRESSION-CAUSED-BY-CHANGE, AND ANY ENTRY BLOCKING BY TIER]

           Do not implement ledger entries that are not blocking. Judge that by
           the blocking flag, not the tier: a required-by-contract entry also
           carries tier n/a, and it MUST be fixed."
  description: "Fix review issues"
```

#### 6.3 Automated Reviewer Wait (Copilot + CodeRabbit + future)

**MANDATORY: Wait for and resolve EVERY automated reviewer configured on the repo.** Copilot and CodeRabbit are the two we know about today; future integrations slot in here. Reviewers are **independent feedback channels** with different latencies (Copilot 85 s to 12 m 42 s observed — do not budget for it being quick; CodeRabbit 2–10+ min and re-runs after every push).

> **CodeRabbit was attempted LOCALLY in Step 4.5** (`cr review --agent`). The PR-level handling here is a fallback for repos whose GitHub App auto-reviews PRs. Prefer a passing check and resolve received feedback; if either local or PR-level CodeRabbit rate-limits, resolve what it already delivered — blocking findings fixed, every posted thread settled — then record `skipped (rate-limited)` and continue without blocking.

##### Reviewer-by-reviewer skills

| Reviewer | Skill | Notes |
|----------|-------|-------|
| GitHub Copilot | `fx-dev:copilot-review` | Auto-reviews; we explicitly request via API as a defensive belt. Does NOT re-review on push by default. |
| CodeRabbit | `fx-dev:coderabbit-review` | Already run **locally** in Step 4.5 (`cr`). Here = fallback PR-level gate when the GitHub App auto-reviews PRs: re-reviews after pushes and exposes state via the `CodeRabbit` check. Classify new feedback in the shared ledger and settle its threads within the bounds below. Skip if not configured. |

##### Pick the right execution mode for your context

**⛔ CRITICAL:** the right mode depends on whether YOU can spawn sub-agents right now.

- **You ARE the root session / a standalone caller of `fx-dev:dev`** → use **mode A (parallel sub-agents)**.
- **You are a `fx-dev:team` coordinator OR a sub-agent yourself** → sub-agents CANNOT spawn sub-agents. Use **mode B (sequential, with background wait scripts)**. Do NOT call the Agent tool here.

If unsure: assume mode B. It's strictly slower but always correct; mode A is an optimisation that requires you to be a top-level agent.

###### Mode A: parallel sub-agents (root session only)

In a single message, spawn one sub-agent per reviewer using the Agent tool. Both wait scripts run concurrently and each resolves its own reviewer.

Neither Copilot nor the CodeRabbit GitHub App accepts a scope prompt, so the brief cannot reach them — it MUST still go to the sub-agents, which apply it when triaging what comes back.

```
Agent tool (spawn ALL reviewer sub-agents in the same message — parallel):

Agent 1:
  prompt: "Load the copilot-review skill (Skill tool: skill='fx-dev:copilot-review'),
           then wait for and inspect currently unresolved feedback for PR #[PR_NUMBER] at its
           current head SHA.

           [PASTE THE STEP 2.5 SCOPE BRIEF VERBATIM HERE — mark each finding
            in-scope or out-of-scope against it; never widen the change to
            satisfy an out-of-scope suggestion]

           Return findings and evidence only; do not edit, push, resolve threads,
           or modify task trackers. Report the reviewed SHA."
  description: "Inspect Copilot review"

Agent 2:
  prompt: "Load the coderabbit-review skill (Skill tool: skill='fx-dev:coderabbit-review'),
           then wait for and inspect currently unresolved feedback for PR #[PR_NUMBER] at its
           current head SHA.

           [PASTE THE STEP 2.5 SCOPE BRIEF VERBATIM HERE — same triage rule]

           Return findings and evidence only; do not edit, push, resolve threads,
           or modify task trackers. Report the reviewed SHA."
  description: "Inspect CodeRabbit review"
```

Wait for **all** sub-agents to report completion. The coordinator then deduplicates and classifies their findings, dispatches blocking remediation serially, and settles all reviewer threads. Never let parallel reviewer agents push fixes before coordinator classification.

###### Mode B: sequential, with background wait scripts (team-coordinator / sub-agent)

You can't spawn sub-agents, so handle each reviewer's wait+resolve lifecycle yourself, sequentially. To recover some parallelism, kick off the slow waiter (CodeRabbit) in the background while you handle the fast one (Copilot) in the foreground. When Copilot is done, switch to CodeRabbit.

Concrete recipe:

1. Start the CodeRabbit waiter as a background bash process — its output streams to a file you can poll later:
   ```bash
   bash [SKILL_BASE_DIR]/skills/coderabbit-review/scripts/wait-for-coderabbit-review.sh [PR_NUMBER] \
        > /tmp/coderabbit-wait-[PR_NUMBER].log 2>&1
   ```
   Use `Bash` with `run_in_background: true`. Capture the task ID.
2. In the foreground, wait for Copilot using the bundled `copilot-review` waiter, then read its unresolved threads without invoking a resolver. Classify and deduplicate them in the coordinator-owned ledger.
3. Wait for the background CodeRabbit waiter to finish, then read its unresolved threads and classify them before invoking a resolver. Invoke each reviewer resolver only after classification, passing the blocking findings and a disposition for every thread that carries a finding — `blocking`, `immaterial`, or `deferred` (`references/scope-contract.md` § Resolver dispositions) — so it settles both no-edit dispositions without code or task-tracker changes. A thread whose premise you verified and rejected is listed as undisposed with the reason, not forced into one of the three.
4. After a resolver pushes, record the new SHA and inspect only feedback added or changed since the previous reviewed SHA. Classify and deduplicate it in the shared ledger. Rerun only the reviewer whose state or evidence the delta invalidated; do not restart every reviewer merely because `HEAD` changed.
5. Stop when the channel has **converged** per `references/scope-contract.md` § Convergence — no blocking finding left unresolved, ledger-wide — confirmed by one latest-delta pass, and every required reviewer thread is settled.

If `Bash` `run_in_background` isn't available in your context, fall back to fully-serial: Copilot first, then CodeRabbit. Slower but correct.

##### Bounded delta review (both modes)

Fix every **blocking** finding and only those (`references/scope-contract.md` § Blocking), whatever its ledger class. Record the non-blocking remainder without implementing it, and settle its thread with the disposition that actually fits (`references/scope-contract.md` § Resolver dispositions): `deferred` — citing the exclusion — for a finding excluded by scope, and `immaterial` — replying with the materiality reasoning — for an in-scope observation that fails the bar. Both are no-edit, and they are not interchangeable: citing a scope exclusion for an in-scope observation invents an exclusion that does not exist. Each reviewer channel caps at the canonical bound in `references/scope-contract.md` § The iteration bound, which counts the initial pass as iteration 1 and which no local instruction restates or overrides. Convergence, not the bound, is what should end it: the early signals (converged, and the same disagreement in successive passes, both per `references/scope-contract.md` § Convergence) fire in single digits, as does a rising blocking count of one class — which is a cause to fix and continue, not an exit, and an escalation only where that cause is a design choice. Reaching the bound is a failure to converge, not an exit you may take: STOP, report the per-pass trend and what remains, and hand the decision to the user. Do not advance to the next workflow step on the strength of having hit it, even when only follow-up/out-of-scope entries remain. Do not seek zero suggestions or restart unrelated review channels.

##### Skip rules

- If a reviewer is **not configured** for the repo (e.g. `wait-for-coderabbit-review.sh` exits 2 because no `CodeRabbit` check ever appears), report this once and proceed without that reviewer.
- If **CodeRabbit reports a rate/quota limit or cooldown**, report it once, mark CodeRabbit `skipped (rate-limited)`, and proceed immediately. Do not raise timeouts, sleep, poll, or retry for CodeRabbit throttling. **The degradation waives only the review passes that never ran** (`fx-dev:coderabbit-review`, rate-limit rule): anything CodeRabbit already delivered still counts — fix its blocking findings and settle every thread it already posted before recording the skip, or the PR carries an open thread past a gate that requires none.
- Do not apply this exception to Copilot or other reviewers. A merely slow CodeRabbit check with no rate-limit signal still follows the normal timeout behavior.

**⛔ DO NOT PROCEED until every required reviewer has settled. CodeRabbit is satisfied by a passing result, or by an explicit `skipped (rate-limited)` degradation once everything it already delivered is resolved.**

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
Skill tool: skill="fx-dev:resolve-ci-failures"
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
# Reuse Step 6.3 evidence when it covers the current head SHA. Invoke a dedicated
# reviewer skill only when its check, threads, or reviewed SHA changed; do not restart
# a settled review loop solely because finalization was reached.
# Use the dedicated skills — NEVER raw gh api commands.
```
```
Skill tool: skill="fx-dev:copilot-review",     args="[NUMBER]"
Skill tool: skill="fx-dev:coderabbit-review",  args="[NUMBER]"
```
```bash
# 3. Unresolved review threads — MUST be 0 (across ALL reviewers)
gh pr view [NUMBER] --json reviewThreads \
  --jq '[.reviewThreads[] | select(.isResolved == false)] | length'

# 4. Codecov — patch and project checks must pass
gh pr checks [NUMBER]  # verify codecov/patch and codecov/project
```

<!--
duvet= docs/specs/fx-dev-authority/index.md#required-checks-gate-every-merge
duvet= type=implication
duvet# A pull request MUST NOT be merged while any required check on it is failing or has not completed.
-->

<!--
duvet= docs/specs/fx-dev-authority/index.md#unresolved-reviewer-threads-gate-every-merge
duvet= type=implication
duvet# A pull request MUST NOT be merged while any review thread on it from a configured automated reviewer remains unresolved.
-->

**Merge gate checklist (every item must pass):**
- [ ] PR is open and mergeable
- [ ] **PR title is a conventional-commit subject** (`type(scope): description`) — verify `gh pr view [NUMBER] --json title -q .title | grep -Eq '^(feat|fix|docs|refactor|chore|test|perf|build|ci|style|revert)(\(.+\))?!?: .+'`; a plain prose title FAILS — rename with `gh pr edit [NUMBER] --title "type(scope): …"` BEFORE merging (squash bakes the title into `main`). Also no stray `#<number>`/wave/phase wording.
- [ ] ALL CI checks green
- [ ] Copilot review RECEIVED and ALL threads resolved (via `fx-dev:copilot-review` skill — NEVER raw `gh api`)
- [ ] CodeRabbit is passing with all received threads resolved, not configured, or explicitly recorded as `skipped (rate-limited)`. CodeRabbit throttling is optional and never blocks merge.
- [ ] Zero unresolved **blocking** ledger entries (`references/scope-contract.md` § Blocking) — `required-by-contract`, `regression-caused-by-change`, and any entry blocking by tier; the latest affected delta is verified within the stopping bounds
- [ ] Codecov coverage passing with 0 missing lines
- [ ] No unresolved review threads from any reviewer (Copilot, CodeRabbit, human, or future automated reviewer); follow-up/out-of-scope threads are settled without expanding implementation

<!--
duvet= docs/specs/fx-dev-authority/index.md#merge-gates-apply-regardless-of-change-size
duvet= type=implication
duvet# The size, triviality, or follow-up status of a pull request MUST NOT be treated as grounds for waiving any merge gate.
-->

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
  prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

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
  prompt: "Load the issue-updater skill (Skill tool: skill='fx-dev:issue-updater'), then:

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

<!--
duvet= docs/specs/fx-dev-authority/index.md#dev-runs-require-user-approval-before-merge
duvet= type=implication
duvet# A `fx-dev:dev` run MUST obtain explicit approval from the user before merging any pull request it produced.
-->

**⚠️ NEVER MERGE WITHOUT USER APPROVAL**
**⚠️ NEVER MERGE WITHOUT ALL MERGE GATES PASSING (Step 8.1)**
**⚠️ NEVER MERGE WITHOUT COPILOT REVIEW RECEIVED AND ADDRESSED**

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
| 2 | Requirements Analyzer | `fx-dev:requirements-analyzer` |
| 3 | Planner | `fx-dev:planner` |
| 3,8 | Issue Updater | `fx-dev:issue-updater` |
| 4,6.2,8.2 | Coder | `fx-dev:coder` |
| 4.5 | Pre-PR Self-Review | `simplify`, then `code-review`, then `fx-dev:coderabbit-review` (local `cr`), then `fx-dev:codex-review` (local `codex`) — initial passes complete, blocking findings resolved, latest affected delta verified |
| 5 | PR Preparer | `fx-dev:pr-preparer` |
| 5.5.2 | Browser Verification | `fx-dev:verify-web-change` |
| 6.1 | PR Reviewer | `fx-dev:pr-reviewer` |
| 6.3 | Copilot Review | `fx-dev:copilot-review` (run in parallel with coderabbit-review) |
| 6.3 | CodeRabbit Review | `fx-dev:coderabbit-review` (run in parallel with copilot-review; classify/deduplicate feedback and verify only affected deltas within bounds) |
| 6.3 | PR Feedback Resolver | `fx-dev:resolve-pr-feedback` (meta — called by reviewer skills) |
| 7.2 | CI Failure Resolver | `fx-dev:resolve-ci-failures` |

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
- ✅ Pre-PR review matrix completed (or permitted degradation documented), findings classified in the shared ledger, blocking findings resolved, and the latest affected delta verified within the stopping bounds
- ✅ PR created with description (including links to related specs/changes and test plan)
- ✅ ALL test plan items addressed: browser-verified, programmatically verified, or user-confirmed manual verification (NEVER silently skipped)
- ✅ PR test plan items checked off or annotated with verification results in the PR description
- ✅ Self-review done, issues fixed
- ✅ Automated review feedback classified and settled; blocking findings resolved and the latest affected delta verified without unrelated review restarts
- ✅ All CI/CD checks pass
- ✅ Task tracking docs updated (completed tasks marked in relevant change doc or tasks.md)
- ✅ User notified, awaiting merge approval
