---
name: spec-writer
description: "Write, update, and maintain living specification documents and propose change documents. Use when user says 'write a spec', 'create a spec', 'spec out', 'update spec', 'spec this', 'design a feature', 'write a feature spec', or needs to create/modify specs in docs/specs/ or propose changes in docs/changes/. Handles the complete spec lifecycle: creation, updates, gap analysis, and change proposals."
---

# Spec Writer

This skill manages the complete specification lifecycle: creating living spec documents in `docs/specs/<name>/`, updating them to reflect current implementation, identifying gaps between spec and code, and proposing change documents in `docs/changes/` to close those gaps.

## Scope — Documentation Only

**CRITICAL: This skill writes ONLY specs and change documents. It MUST NOT write, modify, or generate any implementation code.**

- Do NOT edit source files (`.ts`, `.tsx`, `.js`, `.py`, etc.)
- Do NOT create or run database migrations
- Do NOT modify tests, configs, or any non-documentation file
- Do NOT install packages or run build commands
- The ONLY files this skill creates or modifies are in `docs/` (specs, changes, indexes)

If the user asks to "write a spec AND implement it", write the spec/changes first, then stop and tell the user to use `/dev` or `/sdlc` for implementation.

## Core Principles

1. **Specs are living knowledge** — They describe the CURRENT state of the system, not a future plan. They MUST be kept in sync with implementation.
2. **One spec per major feature** — Never create a single monolithic spec for an entire application. Each major feature area (e.g., authentication, file storage, upload system, password protection) gets its own spec. A general "architecture" or "setup" spec is appropriate for project-level concerns (tech stack, directory structure, deployment topology), but feature behavior belongs in feature-specific specs. This keeps specs focused, readable in one sitting, and independently maintainable.
3. **Changes are plans** — Planning, task tracking, and implementation details go in `docs/changes/NNNN-name.md`, never in specs.
4. **RFC 2119 everywhere** — All specs and changes MUST use RFC 2119 keywords (MUST, MUST NOT, SHALL, SHALL NOT, SHOULD, SHOULD NOT, MAY, OPTIONAL) for requirement precision.
5. **Behavioral scenarios** — Every requirement SHOULD have GIVEN/WHEN/THEN scenarios that map directly to test cases.
6. **Exhaustive exploration** — Research the codebase deeply before writing anything. Every claim in a spec must be verified against actual code.
7. **Clarify before writing** — Use AskUserQuestion for scope decisions and design choices.

## RFC 2119 Reference

Per RFC 2119, these keywords indicate requirement levels:
- **MUST / SHALL / REQUIRED** — Absolute requirement
- **MUST NOT / SHALL NOT** — Absolute prohibition
- **SHOULD / RECOMMENDED** — Strong recommendation; exceptions need justification
- **SHOULD NOT / NOT RECOMMENDED** — Strong discouragement; exceptions need justification
- **MAY / OPTIONAL** — Truly optional; interoperability must work with or without

---

## Workflow

### Phase 0: Setup

**Every time this skill is invoked**, run the setup skill first to ensure docs structure and instruction files are in place:

```
Skill tool: skill="fx-dev:setup"
```

This is fast and idempotent — it checks what exists and only creates/modifies what's missing. It handles:
- `docs/` folder structure (specs/, changes/, tasks.md, index.yml, index.md)
- `CLAUDE.md` task-tracking instructions
- `.github/copilot-instructions.md` PR review instructions

Wait for setup to complete before proceeding.

---

### Phase 1: Deep Research

This phase MUST be thorough. Insufficient research leads to inaccurate specs.

#### 1.1 Local Codebase Exploration

Launch `Explore` sub-agents (subagent_type: `Explore`) to deeply understand the relevant parts of the codebase:

- Map all files, modules, and data models the feature touches
- Identify existing patterns, abstractions, and conventions
- Find related features or systems already implemented
- Note constraints (auth patterns, API conventions, DB schema patterns, component libraries)
- Read test files to understand expected behaviors
- Check git history for recent changes in relevant areas

Launch **multiple Explore sub-agents in parallel** if the feature spans distinct areas (e.g., frontend + backend + database + tests).

#### 1.2 Technology and Pattern Research

Launch a sub-agent that loads the tech-scout skill (Skill tool: skill='fx-research:tech-scout') to:

- Discover how similar features are commonly implemented
- Identify relevant libraries, APIs, or standards
- Find best practices and anti-patterns

Skip only when the feature is purely internal with no new technology.

#### 1.3 Web Discovery

Use `WebSearch` to find:

- How other products implement similar features
- Relevant RFCs, standards, or specifications
- Community discussions about tradeoffs

#### 1.4 Existing Specs and Changes

Read all existing specs and changes to understand the current documentation landscape:

```bash
ls docs/specs/ docs/changes/ 2>/dev/null
cat docs/index.yml 2>/dev/null
```

Check if a spec already exists for this area. If so, this is an **update**, not a creation.

#### 1.5 Synthesize Research

Before proceeding, compile a mental model of:
- What exists in the codebase today (actual behavior, not aspirational)
- What patterns and conventions must be followed
- What external patterns and best practices apply
- What the key design decisions and tradeoffs are
- What existing specs cover and what gaps remain

---

### Phase 2: Mode Selection

Determine what work is needed:

**A) New Spec** — No spec exists for this system/feature area. Go to Phase 3.

**B) Update Existing Spec** — A spec exists but is outdated or incomplete. Go to Phase 4.

**C) Spec + Changes** — User wants to define desired behavior (spec) AND plan implementation work (changes) to get there. Go to Phase 3 or 4, then Phase 5.

When the mode is ambiguous, use `AskUserQuestion`:

```
AskUserQuestion:
  question: "A spec already exists at docs/specs/<name>/. What would you like to do?"
  options:
    - label: "Update the spec to match current implementation"
      description: "Audit the code and update the spec to reflect reality"
    - label: "Update the spec AND propose changes"
      description: "Update the spec to the desired state, then create change documents for unimplemented parts"
    - label: "Only propose changes"
      description: "Keep the spec as-is and create change documents for new work"
```

---

### Phase 3: Create New Spec

#### 3.1 Create Spec Directory

```bash
mkdir -p docs/specs/<spec-name>
```

Where `<spec-name>` is a brief, descriptive kebab-case name (e.g., `user-authentication`, `payment-processing`, `notification-system`).

#### 3.2 Write the Spec

Read the template at `references/spec-index-template.md` and write `docs/specs/<spec-name>/index.md`.

**Critical rules:**
- Describe the system **as it currently exists in the codebase**. If the feature doesn't exist yet, describe the desired behavior and note it as unimplemented.
- Use RFC 2119 language for all requirements.
- Include GIVEN/WHEN/THEN scenarios for every requirement.
- Include actual code snippets from the codebase where they clarify the design.
- Verify every claim against the actual code — do not guess or assume.
- NO task lists in specs. Tasks belong in change documents.
- Initialize the Changelog with a creation entry.

#### 3.3 Scope Analysis

**CRITICAL: Do NOT create a single spec for an entire application.** Break the work into multiple specs by major feature area.

A single spec MUST:
- Cover **one** cohesive feature or domain (e.g., "authentication", "file-upload", "password-protection")
- Be readable in one sitting
- Have clear boundaries that don't overlap with other specs

**Spec organization for a new project:**

1. **Architecture/setup spec** (optional) — Covers project-level concerns: tech stack, directory structure, deployment topology, dev workflow. Does NOT contain feature requirements.
2. **Feature specs** (one per major feature) — Each covers a distinct capability of the system. Change documents reference the feature spec they implement.

**Example:** For a file hosting app, create separate specs:
- `architecture` — Tech stack, project structure, deployment
- `file-serving` — HTTP serving, Content-Type, directory indexes
- `authentication` — IAP verification, user identity
- `file-upload` — Upload API, zip extraction, ownership
- `password-protection` — Password middleware, cookie auth, prompt page
- `management-ui` — React SPA, file browser, upload UX

NOT one giant spec covering the entire application.

When the user asks to "write a spec for X" where X is a whole application, decompose it into feature specs. Use `AskUserQuestion` to confirm the breakdown if unsure.

Bootstrapping change documents (project scaffolding, initial setup) are appropriate and SHOULD reference the architecture spec.

#### 3.4 Supplementary Documents

For complex specs, create additional files in the spec folder:
- `api-reference.md` — Detailed API documentation
- `data-models.md` — Schema definitions and type hierarchies
- `architecture.md` — Detailed architecture diagrams and explanations

The `index.md` MUST link to all supplementary documents.

---

### Phase 4: Update Existing Spec

#### 4.1 Deep Implementation Audit

This is the most critical step. Explore the codebase **exhaustively** to find every divergence between the spec and the actual implementation:

Launch multiple `Explore` sub-agents in parallel targeting:
- Every file referenced in the current spec
- Every module, API endpoint, data model mentioned
- Test files that verify the behaviors described
- Recent git commits that may have changed behavior

#### 4.2 Gap Analysis

Categorize findings:

1. **Spec is accurate** — Implementation matches spec. No action needed.
2. **Spec is outdated** — Implementation changed but spec wasn't updated. Update the spec.
3. **Spec is aspirational** — Spec describes behavior that doesn't exist yet. Either:
   - Remove from spec (if no longer desired)
   - Keep in spec and create a change document to implement it
4. **Undocumented behavior** — Implementation has behavior not in the spec. Add to spec.

#### 4.3 Update the Spec

Edit `docs/specs/<spec-name>/index.md` to reflect the current truth:
- Add missing requirements discovered during audit
- Update requirements that have changed
- Remove requirements for deprecated behavior
- Update code snippets to match current implementation
- Add new GIVEN/WHEN/THEN scenarios for undocumented behavior

#### 4.4 Update Changelog

Add an entry to the spec's Changelog for every update:

```markdown
| YYYY-MM-DD | <Description of what changed> | [NNNN-change-name](../../changes/NNNN-change-name.md) |
```

If updating to match existing implementation (no change document), use `—` for the document link.

---

### Phase 5: Propose Change Documents

For every gap between the spec (desired state) and the implementation (current state), create change documents in `docs/changes/`.

#### 5.1 Determine Change Numbering

```bash
ls docs/changes/ 2>/dev/null | sort -n | tail -1
```

Start at `0001` if none exist. Increment from the highest existing number. Zero-pad to 4 digits.

#### 5.2 Scope Each Change Document

Each change document SHOULD be:
- **Focused** — One coherent set of related modifications
- **Small** — Implementable in 1-3 PRs (aim for smaller, more focused PRs)
- **Independent** — Minimally dependent on other changes (note dependencies when they exist)

Split large efforts into multiple change documents. It is BETTER to have many small, focused changes than few large ones.

#### 5.3 Write Change Documents

Read the template at `references/change-template.md` and write each change to `docs/changes/NNNN-<name>.md`.

**Critical rules:**
- Every change MUST reference the spec it relates to
- Use RFC 2119 language for requirements
- Include GIVEN/WHEN/THEN scenarios
- Include a detailed `## Tasks` section with checkbox items
- Each top-level task SHOULD map to one PR
- Include design decisions with rationale
- Be specific about files to modify, APIs to change, tests to write
- **NEVER duplicate change document tasks into `docs/tasks.md`** — tasks belong in the change document that defines them. `docs/tasks.md` is ONLY for work not tied to any change document.

#### 5.4 Exhaustive Coverage

**This is where thoroughness matters most.** For each change document:

1. **Explore deeply** — Launch Explore sub-agents to understand every file that will be touched
2. **Detail every task** — Include specific file paths, function names, test scenarios
3. **Consider edge cases** — What happens on error? Under load? With invalid input?
4. **Include test tasks** — Every behavioral change MUST have corresponding test tasks
5. **Note dependencies** — If this change depends on another, note it explicitly

---

### Phase 6: Update Indexes

After creating or modifying specs and changes, update both index files. **Index files MUST strictly follow their templates — no ad-hoc columns, renamed fields, or alternative status values.**

#### 6.1 Update `docs/index.yml`

Read the template at `references/docs-index-yml-template.md`. The template defines the **exact field names, types, and allowed values**. Add/update entries for every new or modified spec and change.

**Strict rules:**
- Use field names EXACTLY as defined: `name`, `path`, `description`, `status` for specs; `id`, `name`, `path`, `description`, `spec`, `status`, `depends_on` for changes
- ALL fields are REQUIRED — never omit `description`, `name`, or `depends_on`
- Status values MUST be lowercase: `active`/`deprecated` for specs, `draft`/`in-progress`/`complete` for changes
- NEVER use alternative status values like `proposed`, `current`, `Proposed`, `Current`

#### 6.2 Update `docs/index.md`

Read the template at `references/docs-index-md-template.md`. The template defines the **exact table columns and order**. Add/update the tables to include every new or modified spec and change.

**Strict rules:**
- Specs table columns MUST be: `Spec | Description | Status` — no renaming to "ID", "Name", etc.
- Changes table columns MUST be: `# | Change | Spec | Status | Depends On` — no renaming, no extra columns
- Status values MUST be lowercase: `active`/`deprecated` for specs, `draft`/`in-progress`/`complete` for changes
- The `Spec` column in both tables MUST be a markdown link, not plain text
- The `Description` column MUST be filled — never leave it empty or omit it

---

### Phase 7: Verification

After writing each spec and change document, verify against the codebase:

1. **Code references** — Confirm that any files, functions, types, or modules mentioned actually exist
2. **API patterns** — Verify that proposed or documented APIs follow existing conventions
3. **Schema accuracy** — Confirm database tables, columns, and types match reality
4. **Component patterns** — Verify UI components exist and follow project conventions
5. **Import accuracy** — Confirm libraries and modules referenced are available
6. **Scenario testability** — Every GIVEN/WHEN/THEN scenario should be directly implementable as a test

For each discrepancy:
- Fix the spec/change directly if the correction is clear
- Add an Open Question if the right approach is ambiguous

---

## Output

After completing all phases, report:

1. **Specs created or updated** (with paths)
2. **Change documents created** (with paths and one-line summaries)
3. **Key findings** from the implementation audit (if updating)
4. **Open questions** that need user input
5. **Suggested next steps**:
   - "Changes ready for implementation via `/dev` or `/team`"
   - "Spec has open questions that need resolution first"
   - "Spec updated to match current implementation — no changes needed"
