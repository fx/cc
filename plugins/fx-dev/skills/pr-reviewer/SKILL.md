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
  data-loss, and correctness problems inside the change are always blocking,
  whatever the brief says. If an excluded finding turns out to be correct, the
  exclusion was wrong — say so plainly.
- Judge the change against **what was asked for**, not against what you would
  have built. "This should also handle X" is out of scope unless the request,
  the spec, or a genuine regression demands it.

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
- APPROVE minor issues
- BLOCK: security, bugs, **vendor reuse violations**
- Ship good code, not perfect

## Output Format
```
**Decision**: APPROVE/REQUEST CHANGES
**Size**: X lines [OK/EXCEEDS]
**Automated Reviews**: NONE/DETECTED (Copilot/CodeRabbit)
**Ready**: YES/NO

### Blocking
- [Critical issues only]

### Suggestions
- [Nice improvements]

### Next
- [Clear actions]
```

Remember: Enable autonomous workflow with clear feedback.
