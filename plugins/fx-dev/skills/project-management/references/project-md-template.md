# PROJECT.md Template

Use this template when creating a new docs/PROJECT.md file.

---

```markdown
# [Project Name]

[One-line description of the project.]

## Tasks

[Flat prioritized list. Top = highest priority.]

- [ ] Simple standalone task
- [ ] Feature: User authentication
  - [ ] Add login endpoint
    - [ ] Create route handler
    - [ ] Add input validation
    - [ ] Write tests
  - [ ] Implement JWT tokens
  - [ ] Add password reset flow
    - [ ] Email service integration
    - [ ] Reset token generation
- [ ] Feature: Dashboard improvements
  - [ ] Add real-time updates
  - [ ] Improve mobile layout
- [ ] Fix memory leak in polling (#42)

## Completed

- [x] Feature: Initial project setup (PR #1)
  - [x] Initialize repository
  - [x] Add CI/CD pipeline
    - [x] Configure GitHub Actions
    - [x] Add test workflow
- [x] Fix typo in README (PR #2)

## References

- [README](../README.md)
```

---

## Notes

- Keep it flat. No categories, groupings, or phases.
- Up to 3 levels: Feature → Task → Subtask (2-space indent per level)
- One top-level item = one PR
- Mark completion with PR number: `- [x] Feature: Auth (PR #5)`
- Link GitHub issues inline: `- [ ] Fix bug (#42)`
- Move completed items to Completed section for reference
