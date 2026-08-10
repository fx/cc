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

## Duvet mode — a different Requirements shape

**This section applies ONLY when `.duvet/` exists at the repository root.** It overrides two parts of the template above: the `## Requirements` shape, replaced wholesale below, and the `## Overview` guidance — the "Use RFC 2119 keywords (MUST, SHOULD, MAY) to indicate requirement levels" instruction there does NOT apply in duvet mode, where the Overview is plain prose like every other non-requirement section. Every remaining section of the template is unchanged. Projects without `.duvet/` use the whole template above exactly as written.

Duvet traces each normative statement to the code implementing it, which constrains how requirements may be written. The shape above — a named requirement holding several `MUST` bullets, with keywords free to appear in scenarios — does not survive that: duvet extracts one requirement per section and quotes it byte for byte, so a section with three bullets is uncitable, and a `MUST` in a `THEN` line splits one requirement into two.

Replace the `## Requirements` block with this shape:

```markdown
## Requirements

### REQ-001: Descriptive Title

The system MUST <a single, self-contained normative sentence>.

#### Scenario: <Scenario Name>

- **GIVEN** <precondition>
- **WHEN** <action or event>
- **THEN** <expected observable outcome, stated plainly — no RFC 2119 keyword>

### REQ-002: Another Descriptive Title

The system SHOULD <a single, self-contained normative sentence>.
```

Rules that differ from the default shape:

- **`### REQ-NNN: Title` headings**, zero-padded to three digits, globally unique across the whole `docs/specs/` tree. Assigned to NEWLY created requirements only — never retrofitted onto a heading that already exists.
- **Exactly one normative sentence per requirement section**, self-contained, not a bullet list. This sets no count for any other `###` section — those carry zero normative sentences, per the next rule.
- **RFC 2119 keywords appear ONLY inside requirement sections** — `###` sections whose sole purpose is to state a single normative requirement, whether or not the heading carries a REQ ID (newly created requirements get one; pre-existing plain-titled requirements keep their headings, so both styles coexist). Overview, Background, Design, Constraints, Open Questions, and scenario bodies are plain prose. A keyword anywhere else becomes an extracted requirement with no ID and no annotatable home, failing `duvet query -c implementation` permanently.
- **Heading text is an address.** Renaming one breaks every annotation citing its anchor.

Full rules, including what the skill reports rather than applies: the "Duvet Mode — Requirements Traceability" section of `SKILL.md`.

---

## Notes

- **Living document**: This spec describes the CURRENT state of the system, not a future plan
- **RFC 2119**: Use MUST, MUST NOT, SHALL, SHALL NOT, SHOULD, SHOULD NOT, MAY, and OPTIONAL per RFC 2119
- **GIVEN/WHEN/THEN**: Every requirement SHOULD have at least one testable scenario
- **No task lists**: Specs are knowledge, not plans. Tasks go in `docs/changes/` documents
- **This spec OWNS its behavior**: Change documents reference these requirements and scenarios rather than restating them. If a change document has started re-specifying behavior, move the behavior here and leave a link there
- **Observable behavior only**: Do NOT name library components, methods, props, hooks, or file layout in requirements — a third-party API written into a normative rule is a claim reviewers must re-verify forever, and it goes stale on every upgrade. Exceptions are cross-cutting contracts other documents depend on (design tokens, stable selectors, public API surfaces), which are architecture rather than mechanism
- **Open Questions are legitimate**: Deferring a decision is this section working as designed. Resolve one only when a change document has actually settled it — then mark it resolved here and state the decision, so the spec stays the single source
- **Changelog is mandatory**: Every modification to the spec MUST be logged with a link to the change document that drove it
- **Supplementary files**: The spec folder MAY contain additional `.md` files for large subsections (e.g., `api-reference.md`, `data-models.md`). The `index.md` MUST link to them
