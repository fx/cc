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

### <Requirement>

Description using RFC 2119 language.

#### Scenario: <Name>

- **GIVEN** <precondition>
- **WHEN** <action or event>
- **THEN** <expected outcome>

### <Another Requirement>

...

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
- **Status tracking**: Update the Status field as work progresses (draft → in-progress → complete). Values MUST be lowercase. NEVER use `Proposed`, `Current`, or other alternative values
- **Depends On**: If this change depends on other changes being completed first, list their IDs. Use `—` if no dependencies. This field MUST match what appears in `docs/index.yml` and `docs/index.md`
