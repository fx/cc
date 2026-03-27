# docs/index.yml Template

Use this template when creating or updating `docs/index.yml`. This is a machine-readable index of all specs and changes.

**CRITICAL: The field names and structure below are strict. Use these EXACT field names, nesting, and allowed values. Do NOT rename fields, add extra fields, or change the structure.**

---

```yaml
# Documentation Index
# Auto-updated by /spec-writer and /project-management skills

specs:
  - name: <spec-name>
    path: specs/<spec-name>/
    description: <one-line description>
    status: active

changes:
  - id: "NNNN"
    name: <change-name>
    path: changes/NNNN-<change-name>.md
    description: <one-line description>
    spec: <spec-name>
    status: draft
    depends_on: []
```

---

## Strict Schema Rules

### specs[] Entry

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | MUST | Spec folder name (kebab-case, e.g., `user-authentication`) |
| `path` | string | MUST | Relative path from docs/: `specs/<name>/` |
| `description` | string | MUST | One-line description of the spec's domain |
| `status` | enum | MUST | `active` or `deprecated` (lowercase only) |

### changes[] Entry

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | MUST | Zero-padded number as string: `"0001"` |
| `name` | string | MUST | Change name (kebab-case, e.g., `add-oauth-login`) |
| `path` | string | MUST | Relative path: `changes/NNNN-<name>.md` |
| `description` | string | MUST | One-line description of the change |
| `spec` | string | MUST | Parent spec `name` value |
| `status` | enum | MUST | `draft`, `in-progress`, or `complete` (lowercase only) |
| `depends_on` | list | MUST | List of change `id` strings this depends on, or `[]` if none |

### Status Values (MUST be lowercase)

- Specs: `active`, `deprecated`
- Changes: `draft`, `in-progress`, `complete`
- NEVER use `proposed`, `current`, `Proposed`, `Current`, or any alternative values

### Ordering

- `specs`: alphabetical by `name`
- `changes`: ascending by `id`
