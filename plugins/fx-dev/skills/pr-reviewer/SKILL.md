---
name: pr-reviewer
description: "MUST BE USED when user asks to: review code, review PR, check my code, look at my changes, review changes. Reviews pull requests and code changes, evaluating quality and providing actionable feedback."
---

# Pragmatic PR Review Skill

## CRITICAL: Project-Specific Rules (Read First!)

**BEFORE reviewing any code, you MUST:**

1. **Read project instruction files:**
   ```bash
   # Check for CLAUDE.md in repo root
   cat CLAUDE.md 2>/dev/null || echo "No CLAUDE.md found"

   # Check for copilot-instructions.md
   cat .github/copilot-instructions.md 2>/dev/null || echo "No copilot-instructions.md found"
   ```

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
   - Vendor code uses dependencies that ARE available (check CLAUDE.md "Available Vendor Dependencies" table)

3. **Space-Lua is AVAILABLE** - If vendor code uses `LuaEnv`, `luaQuery`, `evalExpression`, etc., check if project already has Space-Lua aliases. If yes, the code should be imported, NOT ported.

4. **Ask these questions for every port:**
   - Did they try adding a path alias first?
   - Did they run `bun run build` to prove import fails?
   - What specific error prevents import?

## Review Priority
1. **Project instruction compliance** (CLAUDE.md, copilot-instructions.md)
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
