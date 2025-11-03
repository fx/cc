# GitHub Copilot Instructions

This file contains project-specific instructions for GitHub Copilot to improve code review quality and reduce false positives.

## Code Reviews

### HTML/Web Standards

- Do not flag valid HTML closing tag structures. Standard HTML files should have `</body>` followed by `</html>` at the end of the file.
- HTML files ending with proper closing tags followed by a newline are valid and follow standard formatting conventions.
- Verify actual file content before suggesting structural issues with closing tags.

### GitHub CLI (gh) Capabilities

- The `gh` CLI does NOT have built-in commands like `gh pr review-thread resolve` or `gh pr review-thread list`.
- Do not suggest these non-existent commands as alternatives to the GraphQL API approach.
- The correct method for programmatically resolving PR review threads is using the GitHub GraphQL API via `gh api graphql` with the `resolveReviewThread` mutation.
- Verify command existence before suggesting `gh` CLI alternatives.

## Repository Context

This repository hosts a Claude Code marketplace for personal plugins, skills, and subagents. The `index.html` file serves as the marketplace landing page hosted on GitHub Pages.
