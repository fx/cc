# docs/tasks.md Template

Use this template when creating `docs/tasks.md`. This is the catch-all task tracker, replacing the previous `docs/PROJECT.md`.

---

```markdown
# Tasks

Catch-all task list for work not tracked in a specific [change document](changes/).

## Backlog

- [ ] Task description
- [ ] Task description (#123)
  - [ ] Subtask
  - [ ] Subtask

## Completed

- [x] Task description (PR #N)
```

---

## Notes

- **Catch-all ONLY**: Tasks here MUST NOT be tied to a specific change document. Feature work MUST be tracked in `docs/changes/NNNN-name.md`. NEVER duplicate, summarize, or mirror change document tasks here
- **Flat list**: No categories or groupings. Priority order (top = highest)
- **Up to 3 levels**: Task → Subtask → Sub-subtask (2-space indent per level)
- **One top-level item = one PR**: Each top-level task SHOULD result in a single PR
- **Mark completion**: `- [x] Task name (PR #N)` — always include the PR number
- **Link issues**: `- [ ] Task (#123)` when linked to GitHub issue
- **Move completed items** to `## Completed` section for reference
- **External tracking**: Projects MAY define in CLAUDE.md a preference for GitHub Issues or Jira instead of this file. When configured, the project-management skill will use those mechanisms and this file becomes a lightweight reference
