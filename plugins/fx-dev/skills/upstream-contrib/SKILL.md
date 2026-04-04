---
name: upstream-contrib
description: Contribute local component changes upstream to fx/ui. This skill should be used when the user wants to upstream local UI component changes (variants, new components, fixes) from a consumer repo to the shared @fx/ui library. Triggers include "upstream to fx/ui", "contribute to fx/ui", "add this to fx/ui", "move this to fx/ui", "send PR to fx/ui", or when local UI component changes should be shared across repos.
---

# Upstream Contribution to @fx/ui

Contribute local UI component changes from a consumer repository upstream to the shared `@fx/ui` library (https://github.com/fx/ui). Handles the full lifecycle: clone, branch, implement, test, PR, link-verify, and post-merge cleanup.

## When to Use

- Local component has variants/features not in @fx/ui (e.g., Badge status variants)
- A component fix should be shared across repos
- User says "upstream", "contribute to fx/ui", "add to fx/ui", "move to fx/ui"

## CRITICAL: Source Project Confidentiality

**fx/ui is a PUBLIC repository.** The consumer repo that triggers this workflow is likely PRIVATE. Never leak source project details into fx/ui:

- **NEVER** mention the consumer project's name, GitHub URL, author, org, or repo in any fx/ui commit message, PR title, PR description, code comment, story, test, or documentation
- **NEVER** include language like "needed by X project" or "for use in Y app"
- **ALWAYS** describe changes generically: "Add status variants to Badge" not "Add Badge variants for the co dashboard"
- **ALWAYS** frame motivation in terms of general usefulness: "Status variants enable workflow state indicators" not "Required for Coder workspace status display"

This applies to ALL fx/ui artifacts: commits, PR body, code comments, Storybook story descriptions, test names, and CSS variable comments. Treat the consumer project as if it does not exist when writing anything that touches fx/ui.

## Prerequisites

- `gh auth status` must succeed
- Consumer repo must already depend on `@fx/ui`
- Consumer repo must be on a feature branch (not main)

## Core Workflow

Execute these phases in order. Each phase must complete before the next begins.

---

### Phase 1: Setup fx/ui Working Copy

#### 1.1 Determine consumer repo context

```bash
# Save consumer repo root and current branch
CONSUMER_ROOT=$(git rev-parse --show-toplevel)
CONSUMER_BRANCH=$(git branch --show-current)
```

#### 1.2 Clone or reuse fx/ui

Clone fx/ui alongside the consumer repo. Reuse if already present.

```bash
UI_DIR="$(dirname "$CONSUMER_ROOT")/ui"

if [ -d "$UI_DIR/.git" ]; then
  # Already cloned — fetch and reset to main
  cd "$UI_DIR"
  git fetch origin
  git checkout main
  git pull origin main
else
  gh repo clone fx/ui "$UI_DIR"
  cd "$UI_DIR"
fi
```

#### 1.3 Create feature branch in fx/ui

```bash
cd "$UI_DIR"
git checkout -b feat/<descriptive-name>
```

Use a descriptive branch name matching the change (e.g., `feat/badge-status-variants`).

---

### Phase 2: Implement Changes in fx/ui

#### 2.1 Analyze the local changes

Read the consumer repo's local component to understand what needs to be upstreamed. Identify:
- New variants being added
- New props or behavior
- CSS variables or theme tokens required
- Whether this extends an existing component or adds a new one

#### 2.2 Read fx/ui CLAUDE.md

```bash
cat "$UI_DIR/CLAUDE.md"
```

Follow all conventions documented there. Key rules:
- **Public repo** — no references to private projects, internal orgs, or private registries
- Named function components (not arrow functions)
- `data-slot` attribute on every component
- CVA for variants
- Tests required in `src/components/ui/__tests__/`
- Storybook stories required in `src/components/ui/*.stories.tsx`
- Export from `src/index.ts`
- HSL CSS variables in `src/styles/globals.css` for new theme tokens

#### 2.3 Implement the changes

Launch a sub-agent with the coder skill:

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

           In the fx/ui repo at [UI_DIR], implement [DESCRIPTION].

           CRITICAL: fx/ui is a PUBLIC repo. NEVER reference the source/consumer
           project name, URL, author, or org in any commit message, comment,
           story description, or code. Describe changes generically.

           Follow these conventions:
           - [Include key rules from CLAUDE.md]
           - Add/update the component in src/components/ui/
           - Add tests in src/components/ui/__tests__/
           - Add/update Storybook story
           - Export new items from src/index.ts
           - Add CSS variables to src/styles/globals.css if needed
           - Use conventional commits
           - Run: bun run test && bun run build && bun run lint
           - Do NOT create a PR"
  description: "Implement changes in fx/ui"
```

**CRITICAL:** When upstreaming variants that use custom CSS variables (e.g., `--color-status-working`), add them as neutral/semantic defaults in fx/ui's `globals.css`. Consumer repos override these with their own theme colors. Do NOT copy consumer-specific color values.

#### 2.4 Verify fx/ui builds and tests pass

```bash
cd "$UI_DIR"
bun run test
bun run build
bun run lint
```

Fix any failures before proceeding.

---

### Phase 3: Link and Verify in Consumer Repo

#### 3.1 Link fx/ui locally

```bash
cd "$UI_DIR"
bun link

cd "$CONSUMER_ROOT"
bun link @fx/ui
```

This makes the consumer repo use the local fx/ui build instead of the published version.

#### 3.2 Verify the consumer can use the new fx/ui

Start the consumer dev server or run its tests to confirm the new exports work:

```bash
cd "$CONSUMER_ROOT"
bun --bun run build
bun --bun run test
```

#### 3.3 Update consumer repo to use new fx/ui exports

Now that fx/ui has the upstreamed changes, update the consumer repo to:
- Remove the local implementation (or reduce to a re-export)
- Import from `@fx/ui` instead
- Remove any CSS variables that are now provided by fx/ui's globals.css (if applicable)
- Run tests and build again to confirm

Launch a sub-agent with the coder skill:

```
Agent tool:
  prompt: "Load the coder skill (Skill tool: skill='fx-dev:coder'), then:

           In [CONSUMER_ROOT], update the local component to use the
           new exports from @fx/ui (currently linked locally).

           - Replace the local implementation with a re-export from @fx/ui
             (or remove it entirely if no local extensions remain)
           - Update any imports across the codebase if needed
           - Run tests and build to verify
           - Commit with: refactor(<component>): use upstreamed <component> from @fx/ui
           - Do NOT push yet"
  description: "Update consumer to use new fx/ui exports"
```

#### 3.4 Unlink fx/ui

After verification, restore the published @fx/ui version:

```bash
cd "$CONSUMER_ROOT"
bun install --force
```

The consumer repo now has commits that use the new fx/ui exports, but still depends on the current published version. These commits will work once the fx/ui PR is merged and a new version is published.

---

### Phase 4: Submit fx/ui PR via Dev Workflow

#### 4.1 Run the full dev (SDLC) workflow on fx/ui

Switch working directory to fx/ui and run the dev skill:

```
Skill tool: skill="fx-dev:dev"
```

Execute Steps 5-7 of the SDLC workflow (PR creation, review, CI) within the fx/ui repo. Steps 0-4 are already done (auth, branch, requirements, plan, implementation).

**IMPORTANT:** The PR description must NOT reference the consumer repo by name (fx/ui is a public repo). Describe the changes generically:
- "Add status variants (working, idle, complete, failure, stale) to Badge"
- NOT "Add Badge variants needed by the co dashboard"

#### 4.2 Report fx/ui PR to user

```
fx/ui PR #[NUMBER] ready: [URL]

Changes:
- [summary]

⚠️ Do NOT merge the consumer repo PR until this fx/ui PR is merged
   and a new version is published.
```

---

### Phase 5: Post-Merge — Update Consumer Dependency

**This phase runs ONLY after the fx/ui PR is confirmed merged.**

Do NOT proceed with this phase automatically. Wait for user confirmation that the fx/ui PR has been merged.

#### 5.1 Confirm merge status

```bash
gh pr view [FX_UI_PR_NUMBER] --repo fx/ui --json state -q '.state'
```

Must return `MERGED`. If not, STOP and inform the user.

#### 5.2 Check for preview release

Many upstream projects (including fx/ui) publish **preview releases** automatically on every push to main. These use a commit-SHA-based version like `0.0.0-<short-sha>` and are tagged `preview` in the registry.

**Check for a preview version first** — this avoids waiting for a formal release:

```bash
# Get the merge commit SHA from the merged PR
MERGE_SHA=$(gh pr view [FX_UI_PR_NUMBER] --repo [OWNER/REPO] --json mergeCommit --jq '.mergeCommit.oid' | head -c 7)

# Check if a preview version exists for this commit
NODE_AUTH_TOKEN=$(gh auth token) npm view @fx/ui versions --json --registry https://npm.pkg.github.com 2>/dev/null | jq -r '.[] | select(contains("'$MERGE_SHA'"))'
```

If a matching preview version is found (e.g., `0.0.0-44c2d7d`), use it immediately. If not, wait 1-2 minutes for the preview workflow to complete, then check again.

If no preview version appears after retrying, check the upstream project's CI workflows to understand its release strategy. Some projects may only publish on formal releases — in that case, inform the user:

> No preview release found. A release PR may need to be merged manually.

**⛔ NEVER merge release PRs (release-please, semantic-release, changeset, etc.).** These control versioning and must be merged manually by the user.

#### 5.3 Update consumer dependency

Install the specific preview version (or released version if available):

```bash
cd "$CONSUMER_ROOT"
NODE_AUTH_TOKEN=$(gh auth token) bun add @fx/ui@[VERSION]
```

#### 5.4 Verify and commit

```bash
bun --bun run test
bun --bun run build
```

If passing, commit the dependency update:

```bash
git add package.json bun.lock
git commit -m "chore: update @fx/ui to [VERSION]"
git push
```

---

## Error Handling

| Error | Action |
|-------|--------|
| fx/ui clone fails | Check `gh auth status`, retry |
| fx/ui tests fail | Fix in fx/ui before proceeding |
| Link verification fails | Check export names match, rebuild fx/ui |
| Consumer tests fail after update | Debug import paths, check for missing exports |
| fx/ui PR CI fails | Use `fx-dev:resolve-ci-failures` skill in fx/ui context |

## Success Criteria

- fx/ui PR created with tests, stories, and proper exports
- Consumer repo updated to use new fx/ui exports (local implementation removed)
- Consumer repo tests pass with linked fx/ui
- Consumer dependency NOT updated until fx/ui PR is merged
- Consumer dependency updated to new version post-merge
