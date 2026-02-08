---
name: spec-writer
description: "Write feature specification documents for planned work. This skill should be used when the user asks to 'write a spec', 'create a spec', 'spec out', 'design a feature', 'write a feature spec', 'spec this', or needs a detailed feature specification before implementation. Produces numbered spec files in docs/specs/."
---

# Spec Writer

This skill produces feature specification documents by deeply researching the codebase, discovering prior art and patterns via the web, analyzing scope, and writing structured specs to `docs/specs/`.

## Core Principles

1. **Research First** - Thoroughly understand the codebase and prior art before writing anything
2. **Right-Size Specs** - Each spec should be large enough to be useful but small enough to express in a single document
3. **Clarify Before Writing** - Use AskUserQuestion for scope splits and design choices
4. **Verify After Writing** - Cross-check every spec against the actual codebase

## Workflow

Execute these phases in order.

### Phase 1: Research

#### 1.1 Local Codebase Exploration

Use the `Explore` agent (subagent_type: `Explore`) to understand the relevant parts of the codebase:

- Identify existing patterns, abstractions, and conventions
- Find related features or systems already implemented
- Map out the files, modules, and data models that the feature would touch or extend
- Note any constraints (auth patterns, API conventions, DB schema patterns, component libraries)

Launch multiple Explore agents in parallel if the feature spans distinct areas (e.g., frontend + backend + database).

#### 1.2 Technology and Pattern Research

When the feature involves technologies, libraries, or patterns that may benefit from external research, use the `fx-research:tech-scout` agent (subagent_type: `fx-research:tech-scout`) to:

- Discover how similar features are commonly implemented in the ecosystem
- Identify relevant libraries, APIs, or standards
- Find best practices and anti-patterns

Skip this step only when the feature is purely internal (e.g., a UI layout change with no new technology).

#### 1.3 Web Discovery

Use `WebSearch` to find:

- How other products implement similar features (UX patterns, data models, API designs)
- Relevant RFCs, standards, or specifications
- Community discussions about tradeoffs for this type of feature

Focus searches on understanding the problem space, not on finding code to copy.

#### 1.4 Synthesize Research

Before proceeding, compile a mental model of:

- What exists in the codebase today
- What patterns and conventions must be followed
- What external patterns and best practices apply
- What the key design decisions and tradeoffs are

---

### Phase 2: Scope Analysis

Analyze whether the feature fits in a single spec or needs to be split.

**A single spec should:**
- Describe one cohesive feature or system
- Be implementable as 1-3 PRs (not necessarily one, but a tightly related set)
- Be readable in one sitting (~500-2000 lines of markdown)

**Split into multiple specs when:**
- The feature has clearly independent subsystems (e.g., "real-time chat" = transport layer spec + UI spec + persistence spec)
- Different parts have different dependencies or could be built in parallel
- A single document would exceed ~2000 lines

**When scope is ambiguous, use `AskUserQuestion`** to present:
- The proposed split (or unified approach)
- The reasoning for each option
- Any other design choices that affect scope

Example:
```
AskUserQuestion:
  question: "This feature has two distinct parts: the data pipeline and the UI dashboard. Should I write them as one spec or two?"
  options:
    - label: "Single spec"
      description: "One document covering both pipeline and dashboard. Simpler but longer."
    - label: "Two specs (Recommended)"
      description: "Separate specs for pipeline and dashboard. Allows parallel implementation."
```

---

### Phase 3: Write Specs

#### 3.1 Determine File Numbering

Check existing specs to determine the next number:

```bash
ls docs/specs/ 2>/dev/null | sort -n | tail -1
```

If no specs exist, start at `0001`. Otherwise increment from the highest existing number. Numbers are zero-padded to at least 4 digits (0001, 0002, ..., 0010, ..., 0100).

#### 3.2 Create the Spec File(s)

Ensure the directory exists:

```bash
mkdir -p docs/specs
```

Write each spec to `docs/specs/<number>-<name>.md` where `<name>` is a brief descriptive name using only lowercase alphanumerics and dashes.

Examples:
- `docs/specs/0001-real-time-notifications.md`
- `docs/specs/0002-creator-analytics-pipeline.md`
- `docs/specs/0003-creator-analytics-dashboard.md`

#### 3.3 Spec Document Structure

Read the template at `references/spec-template.md` and use it as the base structure for each spec.

Adapt the template as needed - not every section is required for every spec. A small feature may omit "Background" or "Non-Goals". A spec that is purely a data model change may have a minimal "UI" section.

**Important:** Write the full spec body first (Overview through References) but leave the `## Tasks` section empty. Tasks are populated in Phase 4.

---

### Phase 4: Task Breakdown

After the spec body is written, invoke the `/project-management` skill to populate the `## Tasks` section:

```
Skill tool: skill="fx-dev:project-management"
```

Provide the skill with:
- The spec file path
- A summary of the feature and its design decisions
- Instructions to add a nested markdown task list (`- [ ]`) to the `## Tasks` section of the spec

The project-management skill handles breaking the spec down into properly scoped, actionable tasks. Do not attempt to write the task list directly — delegate this to the skill so tasks are consistent with project tracking conventions.

---

### Phase 5: Verification

After writing each spec, verify it against the codebase:

1. **Schema references** - Confirm that any database tables, columns, or types mentioned actually exist (or are clearly marked as new)
2. **API patterns** - Verify that proposed API endpoints or tRPC routers follow existing conventions (naming, auth patterns, input validation)
3. **Component patterns** - Confirm that referenced UI components exist and that proposed new components follow project conventions (shadcn/ui, Tabler icons, Tailwind design tokens)
4. **File paths** - Verify that any referenced file paths are accurate
5. **Import patterns** - Confirm that any libraries or modules referenced are actually available in the project

For each discrepancy found:
- Fix the spec directly if the correction is clear
- Add an "Open Question" if the right approach is ambiguous

Report a summary of any corrections made or questions added during verification.

---

## Output

After completing all phases, report:

1. The spec file(s) created (with paths)
2. A one-line summary of each spec
3. Any open questions that need user input
4. Suggested next steps (e.g., "Ready for implementation via /sdlc" or "Needs design decisions on open questions first")
