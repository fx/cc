# Spec Index Template

Use this template when creating `docs/specs/<spec-name>/index.md`. This is a **living document** — it MUST be kept in sync with the current implementation at all times.

---

```markdown
# <Spec Name>

## Overview

Brief description of what this system/feature does and why it exists. 2-4 sentences. Use RFC 2119 keywords (MUST, SHOULD, MAY) to indicate requirement levels.

## Background

Context needed to understand this system:
- Current state and history
- Problems it solves
- Related specs (link to `docs/specs/<other-spec>/`)

## Requirements

### <Requirement Name>

Description using RFC 2119 language. State observable behavior, not implementation details.

- The system MUST ...
- The system SHOULD ...
- The system MAY ...

#### Scenario: <Scenario Name>

- **GIVEN** <precondition>
- **WHEN** <action or event>
- **THEN** <expected observable outcome>

#### Scenario: <Another Scenario>

- **GIVEN** ...
- **WHEN** ...
- **THEN** ...

### <Another Requirement>

...

## Design

### Architecture

High-level architecture of the current implementation. Component relationships, data flow, key abstractions.

### Data Models

Current schema definitions, types, and data structures. Include actual code snippets from the codebase.

### API Surface

Current API endpoints, RPC methods, or public interfaces. Include request/response shapes.

### UI Components

Current UI structure, component hierarchy, interaction patterns (if applicable).

### Business Logic

Key algorithms, state machines, validation rules, and processing pipelines.

## Constraints

- Security constraints (auth, permissions, data handling)
- Performance requirements (latency, throughput, resource limits)
- Compatibility requirements (browsers, APIs, protocols)
- Regulatory or compliance requirements

## Open Questions

Unresolved design decisions. Each should state:
- The question
- Options considered
- Current default (if any)

## References

- Links to external resources, standards, RFCs
- Links to related specs: `[Spec Name](../other-spec/)`

## Changelog

| Date | Change | Document |
|------|--------|----------|
| YYYY-MM-DD | Initial spec created | — |
| YYYY-MM-DD | <Description of change> | [NNNN-change-name](../../changes/NNNN-change-name.md) |
```

---

## Notes

- **Living document**: This spec describes the CURRENT state of the system, not a future plan
- **RFC 2119**: Use MUST, MUST NOT, SHALL, SHALL NOT, SHOULD, SHOULD NOT, MAY, and OPTIONAL per RFC 2119
- **GIVEN/WHEN/THEN**: Every requirement SHOULD have at least one testable scenario
- **No task lists**: Specs are knowledge, not plans. Tasks go in `docs/changes/` documents
- **Changelog is mandatory**: Every modification to the spec MUST be logged with a link to the change document that drove it
- **Supplementary files**: The spec folder MAY contain additional `.md` files for large subsections (e.g., `api-reference.md`, `data-models.md`). The `index.md` MUST link to them
