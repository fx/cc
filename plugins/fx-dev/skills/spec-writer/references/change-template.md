# Change Document Template

Use this template when creating `docs/changes/NNNN-<name>.md`. Change documents are **planning and tracking artifacts** — they describe what needs to change and track implementation progress.

---

```markdown
# NNNN: <Change Title>

## Summary

1-3 sentences describing what this change accomplishes and why. Reference the spec(s) it relates to.

**Spec:** [<Spec Name>](../specs/<spec-name>/)
**Status:** draft
**Depends On:** — (or comma-separated change IDs, e.g., 0001, 0002)

## Motivation

Why this change is needed:
- What problem does it solve?
- What gap exists between the spec and current implementation?
- What user need or business requirement drives it?

## Requirements

### Testing Requirements

This change MUST satisfy the project's standing testing rules (see [<link to the project's testing conventions — usually the architecture spec's Testing section>]). CI enforces these as merge gates:

- <Project-specific rule 1 — e.g., coverage threshold, framework, isolation requirements>
- <Project-specific rule 2>
- <Project-specific rule 3>
- <Project-specific rule 4 — e.g., justified suppression pragmas only>

Skipping or weakening any of these rules to land the PR MUST be treated as a bug in the PR, not in the rule.

### Functional requirements

The [<Spec Name>](../specs/<spec-name>/) owns <the behavior this change implements — option keys, defaults, state matrices, and its scenarios>. Those scenarios are this change's acceptance criteria and are NOT restated here. What implementing them requires of this change:

- <Something the CHANGE owns — a migration, a registration, a dispatch-path move, a bugfix, a constraint the implementation must respect>
- <Another change-owned item>

#### Scenario: <Name — only for behavior THIS change introduces that no spec owns>

- **GIVEN** <precondition>
- **WHEN** <action or event>
- **THEN** <expected outcome>

## Design

### Approach

Technical approach for implementing this change. Include:
- Components affected
- Data model changes
- API changes
- UI changes

### Decisions

Key technical decisions with rationale:
- **Decision**: <what was decided>
  - **Why**: <rationale>
  - **Alternatives considered**: <what else was evaluated>

### Non-Goals

What this change explicitly does NOT address (to prevent scope creep).

## Tasks

- [ ] Task one — brief description
  - [ ] Subtask if needed
  - [ ] Subtask if needed
- [ ] Task two — brief description
- [ ] Task three — brief description

## Open Questions

- [ ] <Question> — <options or context>

## References

- Spec: [<Spec Name>](../specs/<spec-name>/)
- Related changes: [NNNN-other-change](./NNNN-other-change.md)
- External: <links to relevant resources>
```

---

## Notes

- **Sequentially numbered**: Files are named `NNNN-<kebab-case-name>.md`, zero-padded to 4 digits (0001, 0002, ...)
- **One change = focused scope**: Each change document SHOULD be implementable in 1-3 PRs. Split larger efforts into multiple change documents
- **Tasks are mandatory**: The `## Tasks` section is the primary task tracking mechanism, consumed by `/team` and `/dev`
- **One top-level task = one PR**: Each top-level checkbox item SHOULD result in a single pull request
- **Mark completion**: `- [x] Task name (PR #N)` — always include the PR number
- **RFC 2119**: Use MUST, SHOULD, MAY throughout requirements
- **Link to spec**: Every change document MUST reference the spec it modifies
- **Never restate the spec**: The spec owns behavior; this document owns sequencing, migrations, registration, PR breakdown, design decisions, and out-of-scope boundaries. Reference the spec section rather than copying its rules — duplicated contracts drift, and every stale copy becomes a review finding. If behavior has no owning spec section yet, add it to the spec instead of housing it here
- **Scenarios only for what this change introduces**: Copying a spec's GIVEN/WHEN/THEN into a change document creates a second copy that will drift. Scenarios here cover migrations, bugfixes, and build gates the spec does not own
- **No library APIs in requirements**: Component names, method names, and library-specific props belong in Design Decisions, not in normative requirements — a named third-party API is a claim reviewers must re-verify forever
- **Status tracking**: Update the Status field as work progresses (draft → in-progress → complete). Values MUST be lowercase. NEVER use `Proposed`, `Current`, or other alternative values
- **Depends On**: If this change depends on other changes being completed first, list their IDs. Use `—` if no dependencies. This field MUST match what appears in `docs/index.yml` and `docs/index.md`
- **Testing Requirements is mandatory and project-specific**: Every change document MUST lead its Requirements section with `### Testing Requirements`. Populate it from the target project's actual testing conventions — usually the architecture spec's Testing section, or an equivalent standing-conventions document. Do NOT copy rules from another project. If the project has no documented testing conventions yet, flag that as an Open Question and state a minimal defensible baseline (e.g., "tests MUST exist for changed behavior; CI MUST run them") until the project codifies its rules. The link in the stanza MUST point at the real section; leaving a placeholder link is not acceptable.
