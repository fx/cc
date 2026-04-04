---
name: coder
description: "MUST BE USED when user asks to: implement a feature, fix a bug, write code, add functionality, build something, code this, make changes. Implements new features, bug fixes, refactoring, and GitHub issues by analyzing requirements and creating complete PRs."
---

# Coder Skill

## Capabilities
- Implement features/bug fixes
- Work on GitHub issues
- Auto-select next issue if none provided
- Create PRs with proper workflow

## PR Strategy
1. **Feature branch**: `feature/<issue>-<name>` from main
2. **Sub-branches**: `feature/<issue>-<name>-part-<n>` for logical separation
3. **Keep PRs focused**: Logical, reviewable chunks

## Workflow
1. Get/select issue
2. Analyze requirements
3. Plan logical PR structure if needed
4. Implement with tests
5. Create PR
6. Launch a sub-agent with the pr-reviewer skill
7. Address feedback
8. Launch a sub-agent with the pr-check-monitor skill for failing checks
9. Continue until ready for user review
10. Update issue to Done

## Multi-PR Coordination
- Only ONE PR should be open at a time (sequential PRs per SDLC)
- Track PR status in TodoWrite
- Shepherd each PR to completion before opening next

## Standards
- Follow CLAUDE.md rules
- Test bug fixes first
- Match code style
- Security best practices

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
