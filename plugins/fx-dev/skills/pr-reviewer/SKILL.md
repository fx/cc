---
name: pr-reviewer
description: "MUST BE USED when user asks to: review code, review PR, check my code, look at my changes, review changes. Reviews pull requests and code changes, evaluating quality and providing actionable feedback."
---

# Pragmatic PR Review Skill

## MANDATORY: Establish the Scope Brief (Step 0)

**Never review a bare diff.** A reviewer that does not know what was asked for
reports the work that was deliberately not done — missing implementation for a
docs-only change, missing tests for a spec, absent dependencies a later phase
adds. Those findings are noise, and each round costs a full review cycle.

Before reading a single line of the diff, establish the **Scope Brief**
(canonical definition and field rules:
`fx-dev/skills/dev/references/scope-contract.md`):

- **Verbatim request** — the user's own words, quoted, never paraphrased.
  "just fix the typo real quick" and "fix the typo" are different instructions.
- **Interpreted scope** — files, subsystems, deliverable type.
- **Explicitly out of scope** — what was deliberately not done, and why.
- **Known-and-accepted** — deliberate states that look like defects out of context.

If a coordinator handed you a brief, use it verbatim. **If you were invoked
without one, reconstruct it from the conversation and PR description before
reviewing, and state in your report that you did.**

Then review within it:

- A finding covered by the out-of-scope list is **reported as deferred, with the
  exclusion that covers it** — never raised as blocking, never silently dropped.
- **The brief never suppresses a real finding.** It excludes work deliberately
  not done; it does not excuse defects in the work that *was* done. Security,
  **privacy**, data-loss, and correctness problems inside the change are always blocking,
  whatever the brief says. An excluded finding re-enters scope only on the two
  conditions in `fx-dev/skills/dev/references/scope-contract.md` § Three filters,
  filter 1 — being merely correct is not one of them. When one of them holds, say
  so plainly.
- Judge the change against **what was asked for**, not against what you would
  have built. "This should also handle X" is out of scope unless the request,
  the spec, or a genuine regression demands it.

## Rank by materiality, and say where the bar fell

Scope decides whether a finding is the author's problem. **Materiality decides
whether it is worth their time** — see the materiality bar in the same reference.

- **Report every blocking finding individually.** Wrong behaviour,
  data loss, security, a build or test that will fail, a contradiction that makes
  the change unimplementable, a stated fact that is false and that a reader would
  act on, or a genuine ambiguity
  a reader could act on two ways.
- **Collect everything else into one closing note**, unnumbered and explicitly
  non-blocking. Wording, formatting, naming preference, a count nothing keys on.
- When unsure of the tier, ask: *if this shipped uncorrected, what breaks?* If
  the honest answer is "nothing, it is just not as good as it could be", it
  belongs in the closing note.

Three things are **not findings**, and raising them is how a review becomes
noise the author learns to skim:

- a missing entry in a list the change itself declares illustrative — assess the
  rule instead, since the supply of such entries never runs out;
- a decision the change records with its rationale, **where your disagreement is
  about preference** — say so once as an escalation rather than re-arguing it.
  This never applies when the decision is itself the defect: a recorded rationale
  for leaking a credential or private identifier, losing data, or violating a
  security or privacy invariant is a blocking finding, however well reasoned;
- a limit the change admits and gates ("verified at implementation time",
  "open question gated on X") — check the gate is real and sequenced, and move on.

**A review that reports twenty things equally has reported nothing.** State the
count at each tier so the author knows what to act on first.

## CRITICAL: Project-Specific Rules (Read First!)

**BEFORE reviewing any code, you MUST:**

1. **Read the project instruction files:**
   ```bash
   # Project conventions (canonical)
   cat AGENTS.md 2>/dev/null || echo "No AGENTS.md found"

   # Review conventions (canonical) — highest priority for review decisions
   cat REVIEW.md 2>/dev/null || echo "No REVIEW.md found"

   # Claude-only additions, if any beyond the @AGENTS.md import
   cat CLAUDE.md 2>/dev/null || echo "No CLAUDE.md found"
   ```

   `AGENTS.md` is how the code should be **written**; `REVIEW.md` is how it should be **reviewed**. When they conflict on a review decision, `REVIEW.md` wins.

   Legacy repos may still keep conventions in `CLAUDE.md` or the obsolete `.github/copilot-instructions.md`. Read those only if the canonical files are missing, and suggest running `fx-dev:upgrade` to migrate.

2. **Apply project rules as BLOCKING issues.** These files define project-specific requirements that override general best practices. Violations are BLOCKING, not suggestions.

   **Precedence with the materiality bar:** a project-rule violation is blocking **by virtue of being a project rule** — the bar does not filter it out. The project has already decided the rule matters; that decision is not yours to re-make per finding. The bar governs findings you originate from your own judgment, not rules the project wrote down. If a project rule genuinely produces noise, say so once as feedback on the rule, and still report the violation.

### Vendor Code Reuse Check (BLOCKING)

For projects with vendor submodules (e.g., `vendor/` directory):

1. **Check every new file** against vendor for duplicates:
   ```bash
   # For each new file in src/lib/, check vendor
   find vendor -name "filename.ts" -type f
   ```

2. **Flag as BLOCKING** if:
   - New file matches a vendor filename that could be imported
   - Code has "Ported from vendor" comment but vendor file has no Deno/Preact APIs
   - Vendor code uses dependencies that ARE available (check the AGENTS.md "Available Vendor Dependencies" table)

3. **Space-Lua is AVAILABLE** - If vendor code uses `LuaEnv`, `luaQuery`, `evalExpression`, etc., check if project already has Space-Lua aliases. If yes, the code should be imported, NOT ported.

4. **Ask these questions for every port:**
   - Did they try adding a path alias first?
   - Did they run `bun run build` to prove import fails?
   - What specific error prevents import?

## Review Priority
1. **Project instruction compliance** (AGENTS.md, REVIEW.md)
   - Vendor reuse violations are BLOCKING
2. **Automated review check** (Copilot/CodeRabbit)
   - If found: use the `fx-dev:resolve-pr-feedback` skill to handle all automated feedback
3. **Code review**: bugs, security, performance

## Standards
- BLOCK: every **blocking** finding, as defined in `fx-dev/skills/dev/references/scope-contract.md` § Blocking. Do not restate or narrow that definition here — **vendor reuse violations** are a project rule and therefore blocking under it.
- APPROVE despite immaterial observations — they belong in the closing note, never in the decision
- Ship good code, not perfect

## Output Format
```
**Decision**: APPROVE/REQUEST CHANGES
**Size**: X lines [OK/EXCEEDS]
**Automated Reviews**: NONE/DETECTED (Copilot/CodeRabbit)
**Ready**: YES/NO

### Blocking
- [Contract blockers: a project, security, or privacy rule violation — blocking
  by virtue of being a rule, never ranked by the bar]
- [Material findings: wrong behaviour, data loss, security, a build or test that
  will fail, a stated fact that is false AND that a reader would act on]
- [Substantive findings: a genuine ambiguity a reader could act on two ways, a
  missing step that would be discovered late]

### Closing note (non-blocking)
- [One unnumbered paragraph for everything that clears neither tier — wording,
  formatting, naming preference, counts nothing keys on, optional improvements.
  There is no middle tier: if it is in scope and does not block, it belongs
  here, collapsed into prose and never itemized as findings.]

### Next
- [Clear actions]
```

Remember: Enable autonomous workflow with clear feedback.
