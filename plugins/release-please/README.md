# release-please

Tools for managing release-please automated releases.

## Installation

```
/plugin install release-please
```

## Commands

- `/release-please:update-description` - Add human-readable summary sections to release-please PRs

## Skills

- **update-description** - Auto-invoked when updating release PR descriptions

## Usage

Run `/release-please:update-description` to:

1. Find the current release-please PR
2. Analyze included changes holistically
3. Draft concise "What's New" and "What's Changed" sections
4. Prepend summaries to PR body (preserving auto-generated content)
