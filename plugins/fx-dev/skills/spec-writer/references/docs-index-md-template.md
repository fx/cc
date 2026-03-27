# docs/index.md Template

Use this template when creating or updating `docs/index.md`. This is a human-readable index of all specs and changes.

**CRITICAL: The table schemas below are strict. Use these EXACT column names and order. Do NOT rename columns, add extra columns, or change the structure.**

---

```markdown
# Documentation

## Specs

| Spec | Description | Status |
|------|-------------|--------|
| [<Spec Name>](specs/<spec-name>/) | <one-line description> | active |

## Changes

| # | Change | Spec | Status | Depends On |
|---|--------|------|--------|------------|
| NNNN | [<Change Name>](changes/NNNN-<change-name>.md) | [<Spec>](specs/<spec-name>/) | draft | — |
```

---

## Strict Schema Rules

### Specs Table

| Column | Content | Required |
|--------|---------|----------|
| **Spec** | Markdown link: `[Human Name](specs/<id>/)` | MUST |
| **Description** | One-line description of the spec's domain | MUST |
| **Status** | Exactly one of: `active`, `deprecated` (lowercase) | MUST |

### Changes Table

| Column | Content | Required |
|--------|---------|----------|
| **#** | Zero-padded number: `0001`, `0002`, ... | MUST |
| **Change** | Markdown link: `[Human Name](changes/NNNN-name.md)` | MUST |
| **Spec** | Markdown link to parent spec: `[Name](specs/<id>/)` | MUST |
| **Status** | Exactly one of: `draft`, `in-progress`, `complete` (lowercase) | MUST |
| **Depends On** | Comma-separated change numbers, or `—` if none | MUST |

### Ordering

- Specs: alphabetical by name
- Changes: ascending by number

### Status Values (MUST be lowercase)

- `active` / `deprecated` for specs
- `draft` / `in-progress` / `complete` for changes
- NEVER use `Proposed`, `Current`, `Active`, or any other capitalized/alternative values
