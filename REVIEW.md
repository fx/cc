# PR Review

Canonical review conventions for this repository. Every automated reviewer reads
this file: Claude Code Review natively, GitHub Copilot through the
`.github/copilot-instructions.md` symlink, CodeRabbit via its default file
patterns, and Codex via the `## Code Review Rules` pointer in `AGENTS.md`.

Rules here improve review quality and suppress known false positives. This file
is pasted verbatim into reviewer prompts — write rules out in full, never
reference another file.

## PR Review Checklist (CRITICAL)
<!-- KEEP THIS SECTION UNDER 4000 CHARS - Copilot only reads the first ~4000 -->

### Security and Privacy

- **Do not allow private information leaks**: Flag any use of private repository names, internal URLs, API keys, credentials, or company-specific identifiers in code, documentation, or examples.
- **Require generic placeholders**: Examples should use generic placeholders like `owner/repo`, `example.com`, `your-org`, etc.
- **Check all files**: This applies to documentation (README.md, AGENTS.md, REVIEW.md), code examples, skill references, test cases, and commit messages.

### HTML/Web Standards

- Do not flag valid HTML closing tag structures. Standard HTML files should have `</body>` followed by `</html>` at the end of the file.
- HTML files ending with proper closing tags followed by a newline are valid and follow standard formatting conventions.
- Verify actual file content before suggesting structural issues with closing tags.

### Versioning Requirements

- If a PR modifies files inside `plugins/<name>/`, that plugin's `plugins/<name>/.claude-plugin/plugin.json` must have its `version` field bumped compared to main.
- If any plugin version is bumped OR top-level repo files change, `.claude-plugin/marketplace.json` `metadata.version` must also be bumped.
- Semver rules: patch for fixes/typos, minor for new features/skills, major for breaking changes (e.g., renamed or removed skills).
- Flag PRs that change plugin content without corresponding version bumps.

### GitHub CLI (gh) Capabilities

- The `gh` CLI does NOT have built-in commands like `gh pr review-thread resolve` or `gh pr review-thread list`.
- Do not suggest these non-existent commands as alternatives to the GraphQL API approach.
- The correct method for programmatically resolving PR review threads is using the GitHub GraphQL API via `gh api graphql` with the `resolveReviewThread` mutation.
- Verify command existence before suggesting `gh` CLI alternatives.

### Instruction File Layout

- `AGENTS.md` holds project conventions; `REVIEW.md` holds review conventions. Do not suggest moving rules between them or reviving `CLAUDE.md` as a conventions file.
- `CLAUDE.md` is intentionally a one-line `@AGENTS.md` import. Do not flag it as empty or incomplete.
- `.github/copilot-instructions.md` is intentionally a symlink to `../REVIEW.md`. Do not flag it as a broken or duplicated file, and do not suggest replacing it with a copy.

## Repository Context

This repository hosts a Claude Code marketplace for personal plugins, skills, and subagents. The `index.html` file serves as the marketplace landing page hosted on GitHub Pages.
