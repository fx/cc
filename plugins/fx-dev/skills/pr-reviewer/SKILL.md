---
name: pr-reviewer
description: "MUST BE USED when user asks to: review code, review PR, check my code, look at my changes, review changes. Reviews pull requests and code changes, reporting findings by tier — blocking ones individually, deferred ones with the exclusion covering each, and immaterial ones in a single closing note."
---

# Pragmatic PR Review Skill

**⛔ Load `fx-dev:review` first** (Skill tool: `skill="fx-dev:review"`). It is the
canonical review procedure — carrying the Scope Brief, triaging in filter order,
reporting a class, converging, reporting the trend. This skill is the **agent
adapter**: you *are* the reviewer, so there is no CLI or bot to drive. What it
adds is the project-rule pass every fx-dev review starts from, and the output
format. Where the two appear to disagree, `fx-dev:review` wins.

Follow `fx-dev:review` Steps 1–4 in full: establish the brief (reconstruct it from
the conversation and PR description if you were not handed one, and say so),
triage scope → contract → materiality, verify each premise before reporting it,
and report a class as one finding rather than one per site.

Two things this skill is responsible for, on top of that procedure:

- **Read the project instruction files before the diff** — the section below.
- **State the count at each tier.** A review that reports twenty things equally
  has reported nothing.

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
- [Every blocking finding, as defined in
  `fx-dev/skills/dev/references/scope-contract.md` § Blocking — do not restate or
  narrow that definition here. Label each one with its kind: contract blocker,
  Material, or Substantive.]

### Deferred (out of scope, not blocking)
- [Each finding the Scope Brief excludes, with the exclusion that covers it.
  Reported, never silently dropped, and never fixed here.]

### Closing note (non-blocking)
- [One unnumbered paragraph for **immaterial** observations only — wording,
  formatting, naming preference, counts nothing keys on, optional improvements.
  Nothing blocking belongs here: a contract blocker carries no materiality tier
  (`fx-dev/skills/dev/references/scope-contract.md` § Three filters) and is still
  blocking, so "clears neither tier" is not the test. In scope and not
  immaterial means it goes under Blocking.]

### Next
- [Clear actions]
```

Remember: Enable autonomous workflow with clear feedback.
