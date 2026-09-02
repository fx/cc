---
name: coder
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Implements code changes while following the supplied scope and project conventions; PR creation remains a separate lifecycle stage."
---

# Coder Skill

## SDLC vs Direct Invocation

When invoked by the SDLC workflow (as a sub-agent), the coder is **implementation-only**: write code, run tests, commit. Do NOT create PRs — the SDLC orchestrator delegates that to pr-preparer. When invoked directly by the user (not via SDLC), the coder owns the full lifecycle including PR creation.

## Scope Discipline (MANDATORY)

You implement **what was asked for**, not what you would have built.

If a coordinator handed you a **Scope Brief**, it is binding — stay inside it, and carry it verbatim into any reviewer you invoke. If you were invoked directly, reconstruct one from the user's own words before writing code. Full definition and calibration: `fx-dev/skills/dev/references/scope-contract.md`.

Pay attention to the user's framing. "Just fix the login bug real quick" is a budget, not filler; "refactor the auth module properly" authorizes depth. Treat "just", "only", "real quick", "small", and "minimal" as a `narrow` signal.

**Stop and tell the user** when the work turns out to need materially more than its framing implies — subsystems they never named, a migration or breaking change, several PRs where one was implied, or an architectural decision they have not made. Report what you found, why it exceeds the request, and the cheapest path forward; offer the narrow option first. Deliver everything unambiguously in scope first — never stop with nothing done.

**Do NOT stop for work inside the request's natural boundary:** tests for code you just wrote, docs the change invalidates, fixing a build you broke, or following an approved plan or change document to completion. Over-triggering wastes the user's attention as surely as sprawl wastes their time.

## Capabilities
- Implement features/bug fixes
- Work on GitHub issues
- Auto-select next issue if none provided
- Run tests and commit changes

## PR Strategy (direct invocation only)
1. **Feature branch**: `feature/<issue>-<name>` from main
2. **Sub-branches**: `feature/<issue>-<name>-part-<n>` for logical separation
3. **Keep PRs focused**: Logical, reviewable chunks

## Workflow (direct invocation)
1. Get/select issue
2. Analyze requirements
3. Plan logical PR structure if needed
4. Implement with tests
5. Run the local Codex review (`fx-dev:codex-review`) and converge it **before** opening the PR — it is the only local reviewer, and it is mandatory here exactly as in `fx-dev:dev` Step 4.5
6. Create PR
7. Settle the automated reviewers with `fx-dev:copilot-review` and, where its GitHub App is installed, `fx-dev:coderabbit-review`
8. Address feedback
9. Launch a sub-agent with the pr-check-monitor skill for failing checks
10. Continue until ready for user review
11. Update issue to Done

**When invoked from SDLC:** Stop after step 4 (implement with tests + commit). Do NOT create PRs or launch reviewers — the SDLC owns steps 5 onward.

## Multi-PR Coordination
- Only ONE PR should be open at a time (sequential PRs per SDLC)
- Track PR status in TodoWrite
- Shepherd each PR to completion before opening next

## Standards
- Follow AGENTS.md rules
- Test bug fixes first
- Match code style
- Security best practices
- **Commit subjects: no `#<number>`, no waves/phases.** A commit subject auto-links `#N` to PR/issue #N, and it propagates into the PR title (GitHub pre-fills the title from a single commit's subject) and the squash-merge commit subject — so the PR-title rule applies here too: never put `#<number>` (`#4`, `(#4)`, `#123`) in a commit subject unless N is a real PR/issue ref on this repo, and never use a wave/phase/step/change-doc number there. See the `fx-dev:github` skill's "`#<number>` PR-Title Rule".

## Test Policy

**NEVER skip tests.** Using `test.skip`, `it.skip`, `describe.skip` is FORBIDDEN.

If a test cannot pass:
- **Fix it** - Update assertions to match correct behavior
- **Replace it** - Write a new test that validates the behavior
- **Refactor it** - Restructure to test what's actually testable
- **Remove it** - Delete entirely if testing something obsolete

If tests require infrastructure (auth, database, APIs):
- **Set it up** - Create test fixtures, auth helpers, mocks as needed
- Do NOT skip tests because infrastructure setup is "hard"

Remember: Ship working code in small PRs. You own the entire lifecycle - implement, review, fix, and prepare for user approval.
