# GitHub Copilot Instructions

This file contains project-specific instructions for GitHub Copilot to improve code review quality and reduce false positives.

## Code Reviews

### HTML/Web Standards

- Do not flag valid HTML closing tag structures. Standard HTML files should have `</body>` followed by `</html>` at the end of the file.
- HTML files ending with proper closing tags followed by a newline are valid and follow standard formatting conventions.
- Verify actual file content before suggesting structural issues with closing tags.

## Repository Context

This repository hosts a Claude Code marketplace for personal plugins, skills, and subagents. The `index.html` file serves as the marketplace landing page hosted on GitHub Pages.
