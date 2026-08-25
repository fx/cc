---
name: spec-writer
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Writes and maintains living specs and proposed change documents within an explicitly requested documentation lifecycle."
---

# Spec Writer

This skill manages the complete specification lifecycle: creating living spec documents in `docs/specs/<name>/`, updating them to reflect current implementation, identifying gaps between spec and code, and proposing change documents in `docs/changes/` to close those gaps.

## Scope Discipline (MANDATORY)

Record the **Scope Brief** before writing anything, and carry it into every review of the resulting documents. Full definition: `fx-dev/skills/dev/references/scope-contract.md`.

Quote the user's request **verbatim** — "spec out X, it must do Y and only that" carries a constraint that no paraphrase preserves. Capture the deliverable type (spec-only, spec plus change docs), the explicit out-of-scope list, and the size signal.

Two scope failures are specific to this skill:

- **Spec sprawl.** A spec is an invitation to document adjacent behavior nobody asked to change. Specify what the request covers; note the rest as open questions.
- **Reviews with no context.** Specs and change documents get reviewed like code, and a reviewer that does not know this is a docs-only change reports missing implementation, missing tests, and absent dependencies. **Any review of the output — `fx-dev:codex-review`, `fx-dev:coderabbit-review`, `/code-review`, a reviewing sub-agent — MUST receive a Scope Brief stating that this change is documentation only, that the described work is planned rather than implemented, and which divergences from current code are deliberate.**

**Stop and tell the user** when specifying reveals the work needs materially more than the request implies — a subsystem they never named, several change documents where one was implied, or an architectural decision they have not made. Write the spec for what IS in scope, then state the boundary problem. Never quietly widen the spec.

## Scope — Documentation Only

<!--
duvet= docs/specs/fx-dev-authority/index.md#spec-writer-touches-only-the-docs-tree
duvet= type=implication
duvet# The `fx-dev:spec-writer` skill MUST NOT create or modify any file outside the `docs/` tree.
-->

**CRITICAL: This skill writes ONLY specs and change documents. It MUST NOT write, modify, or generate any implementation code.**

- Do NOT edit source files (`.ts`, `.tsx`, `.js`, `.py`, etc.)
- Do NOT create or run database migrations
- Do NOT modify tests, configs, or any non-documentation file
- Do NOT install packages or run build commands
- The ONLY files this skill creates or modifies are in `docs/` (specs, changes, indexes)

If the user asks to "write a spec AND implement it", write the spec/changes first, then stop and tell the user to use `/dev` for implementation.

## Core Principles

1. **Specs are living knowledge** — They describe the CURRENT state of the system, not a future plan. They MUST be kept in sync with implementation.
2. **One spec per major feature** — Never create a single monolithic spec for an entire application. Each major feature area (e.g., authentication, file storage, upload system, password protection) gets its own spec. A general "architecture" or "setup" spec is appropriate for project-level concerns (tech stack, directory structure, deployment topology), but feature behavior belongs in feature-specific specs. This keeps specs focused, readable in one sitting, and independently maintainable.
3. **Changes are plans** — Planning, task tracking, and implementation details go in `docs/changes/NNNN-name.md`, never in specs.
4. **RFC 2119 everywhere** — All specs and changes MUST use RFC 2119 keywords (MUST, MUST NOT, SHALL, SHALL NOT, SHOULD, SHOULD NOT, MAY, OPTIONAL) for requirement precision. **In duvet mode this principle is narrowed, not contradicted:** keywords still express every requirement, but they are confined to requirement sections — see "Keywords belong ONLY in requirement sections" under "Duvet Mode — Requirements Traceability".
5. **Behavioral scenarios** — Every requirement SHOULD have GIVEN/WHEN/THEN scenarios that map directly to test cases. Scenarios live in the document that OWNS the requirement — never copied into a second document that references it.
6. **Exhaustive exploration** — Research the codebase deeply before writing anything. Every claim in a spec must be verified against actual code.
7. **Clarify before writing** — Use AskUserQuestion for scope decisions and design choices.
8. **Single-owner contracts** — Every behavioral rule has exactly ONE owning document. Other documents LINK to it; they MUST NOT restate it. See "Single-Owner Contracts" below.
9. **Observable behavior, not mechanism** — Specs describe what a user or consumer can observe, not the implementation that produces it. See "Specification Altitude" below.

---

## Single-Owner Contracts

**CRITICAL: Never write the same behavioral rule in two documents.**

The most common failure mode of a spec corpus is duplication. A contract written in the spec, restated in the change document's requirements, restated again in a scenario, and again in a task line is four copies and four chances to drift. Every later edit that touches one copy leaves the other three stale — and reviewers then report each stale copy as a separate defect, indefinitely. The duplication IS the defect, not the drift it eventually produces.

**The ownership rule:**

| Content | Owner |
|---------|-------|
| Behavior, requirements, defaults, state matrices, scenarios | The **spec** |
| Sequencing, dependencies, migrations, PR breakdown, per-change design decisions, out-of-scope boundaries, testing requirements | The **change document** |

**When writing a change document, reference the spec instead of restating it:**

```markdown
<!-- ❌ WRONG — restates the spec, will drift -->
### Functional requirements

- The widget MUST toggle on tap, MUST show a spinner while the call is in
  flight, MUST render `unavailable` state as inert, and MUST NOT fire when
  the entity is in a transitional state...

<!-- ✅ RIGHT — references the spec, states only what this change owns -->
### Functional requirements

The [widget spec](../specs/widgets/index.md) owns the option keys, defaults,
state matrix, and its scenarios — this change's acceptance criteria, not
restated here. What implementing them requires of this change:

- Options are stored under `item.config` and edited via the existing config form.
- **Legacy migration:** the loader rewrites `enableFoo` to `showFoo`; the legacy
  key is never written back.
```

**Rules:**

- A change document's requirements section MUST open by naming the spec section that owns the behavior, then list ONLY what the change itself owns.
- If a change document needs a GIVEN/WHEN/THEN scenario, first ask whether the behavior belongs in the spec. Change documents get scenarios ONLY for things they introduce that no spec owns (e.g. a migration, a bugfix in a service mapping, a build gate).
- If a behavior has no owning spec section yet, ADD it to the spec — do not let the change document become its de facto home.
- When you catch yourself writing "per the spec" followed by a restatement of that spec, delete the restatement and keep the link.

## Specification Altitude

**Specs describe observable behavior. They MUST NOT prescribe the implementation that produces it.**

Naming a library's components, methods, or built-in behaviors inside a normative requirement converts a third-party API into a checkable claim — reviewers will then verify it against that library forever, and it goes stale on every upgrade. It is review surface the spec never needed.

```markdown
<!-- ❌ WRONG — names a library API in a normative rule -->
- Cancelling (button, ESC, outside tap) MUST fire nothing — Radix
  `AlertDialog.Content` blocks interact-outside dismissal.

<!-- ✅ RIGHT — states the observable rule -->
- Cancelling MUST fire nothing and leave no pending state. Dismissal MUST
  require an explicit choice.
```

**Rules:**

- Do NOT write component names, method names, library-specific props/events, hook names, class names, or file layout into spec requirements. Those are implementation-time decisions.
- **Exception:** genuine cross-cutting commitments that other documents depend on — a design-token contract, a stable selector contract, cascade ordering, a named dispatch path, a public API surface — are architecture, not mechanism, and belong in the spec.
- Implementation guidance that IS useful goes in the change document's Design Decisions, where it is explicitly a decision for that change rather than a standing contract.
- **`MUST` density is a smell.** Each `MUST` is an assertion someone must verify against every other one. If a requirement does not describe something observable or a contract another document depends on, write it as prose or a design decision instead.

## Specify Authority, Not Procedure

**A requirement that describes a procedure will be broken by the next process improvement.**

Requirements outlive the workflow that satisfies them. Step order, which tool runs when, timeouts, retry bounds and iteration caps get tuned continuously — and every tuning breaks a requirement that named them, forcing a spec edit that changes nothing about the system's actual contract. That churn is pure cost, and it teaches everyone to treat a failing requirement check as noise.

| Specify (stable) | Never specify (churns) |
|---|---|
| Who may perform an irreversible action, and what approval it needs | Order or naming of workflow steps |
| What must be true before an action is permitted | Which sub-agent, tool, or skill runs at which point |
| Who may write to what, and who must delegate | Prompt wording, field lists, message formats |
| Observable guarantees a consumer depends on | Timeouts, retry counts, iteration caps, polling intervals |

**Test:** if a requirement would become false because someone reordered or renamed a step *without changing what the system guarantees*, it is procedure. Write it as Design prose, or omit it.

## Duvet Mode — Requirements Traceability

**Gate: if a `.duvet/` directory exists at the repository root, duvet mode is MANDATORY. If it does not exist, ignore this section entirely — do not mention duvet, do not create `.duvet/`, do not suggest adopting it.**

`.duvet/` means the project traces every normative requirement to the code implementing it, enforced in CI. Each RFC 2119 keyword becomes a permanent obligation someone must maintain, so the discipline below is not optional.

### Requirement IDs

Every **newly created** requirement section heading MUST take the form:

```markdown
### REQ-NNN: Descriptive Title
```

`NNN` is zero-padded to three digits. Allocate the next number by scanning **the whole `docs/specs/` tree** for the highest existing `REQ-`, not just the spec being edited — IDs are globally unique across the corpus.

The ID lands in duvet's section anchor (`#req-001-descriptive-title`), so every annotation target carries it. That is what makes a later migration to a UID-based tool a mechanical transform rather than a re-derivation.

#### NEVER retrofit an ID onto an existing requirement

**IDs are assigned ONLY to requirements you are creating in this run. An existing requirement heading is left exactly as it is — byte for byte — even when it has no ID.**

This holds even when the rest of the spec is being updated, even when the un-ID'd headings look inconsistent beside the new ones, and even when adding the IDs would take one pass. A spec carrying both styles is the correct outcome, not a mess to tidy up.

The reason is the same one that makes renames breaking (see "Renaming a requirement heading is a breaking change" below), only worse in bulk: the heading is the address. Retrofitting IDs rewrites every address at once, so every annotation citing an old anchor breaks simultaneously — and those annotations live in source files this skill MUST NOT touch. The remedy is outside this skill's boundary, so the skill would be guaranteed to break CI with no way to repair it.

If a project wants IDs backfilled, that is a **deliberate migration** — spec edits and annotation re-pointing planned together in a change document and landed together. It is never something a spec update does incidentally along the way.

### Structural rules

- **Exactly one normative statement per requirement section** — gives a 1:1 requirement→anchor mapping and makes each requirement individually citable. This is a rule about requirement sections only; it sets no count for any other `###` section, because those must contain zero normative statements — see "Keywords belong ONLY in requirement sections" below.
- **Each normative statement MUST be a single self-contained sentence.** An annotation quotes it byte-for-byte, so a requirement spread across bullets, or one whose subject depends on the previous sentence, cannot be cited.
- **The `MUST`-density smell is worse here.** Duvet mode is an argument for writing FEWER normative statements, not more. Every keyword you write becomes an annotation someone must add to a source file and keep true forever, plus a red CI check until they do. Default to prose; promote a sentence to a normative requirement only when the thing it states genuinely needs to be traced.

### Keywords belong ONLY in requirement sections

**In duvet mode, RFC 2119 keywords MUST appear only inside requirement sections — nowhere else in the spec.** A requirement section is a `###` section whose sole purpose is to state a single normative requirement, whether or not its heading carries a REQ ID: newly created ones are headed `### REQ-NNN: Title`, while pre-existing plain-titled ones are requirement sections too and keep their headings untouched (see "NEVER retrofit an ID onto an existing requirement").

duvet extracts keywords from **every** section of a registered markdown file, not only the ones you intended as requirements. A `MUST` in Overview, Background, Design, or Constraints becomes an extracted requirement with no REQ ID and no sensible place to annotate, and it then fails `duvet query -c implementation` permanently — nobody can cite a design paragraph.

- **Overview / Background / Design / Constraints:** plain prose. Write "the loader rewrites the legacy key", not "the loader MUST rewrite the legacy key".
- **`#### Scenario:` blocks:** plain phrasing. Write "**THEN** the job fails", not "**THEN** the job MUST fail". A scenario is evidence for the requirement above it, not a second copy of it — and a keyword there splits one requirement into two extracted ones, the second of which is uncitable.
- **Open Questions / References / Changelog:** plain prose, no keywords.

This **narrows Core Principle 4 ("RFC 2119 everywhere")** for duvet-mode projects, and the two do not conflict. Principle 4 governs how requirements are stated; duvet mode confines where they may be stated, because in a traced corpus every keyword outside a requirement section is an obligation nobody can discharge. Outside duvet mode, Principle 4 applies unchanged.

### Renaming a requirement heading is a breaking change

The heading is the address. Renaming `### REQ-007: Foo` breaks every annotation citing `#req-007-foo`. It fails loudly — CI goes red — rather than drifting silently, but say so in your report when you rename one, and prefer keeping a title stable once assigned.

### Report the registration a new spec needs — do NOT apply it

`.duvet/config.toml` sits outside `docs/`, so this skill MUST NOT edit it (see "Scope — Documentation Only"). The stance is the same one taken on annotations: **you report what is needed; whoever has write authority there applies it.**

For every new spec, emit the exact stanza in your report, filled in and ready to paste:

```toml
[[specification]]
source = "docs/specs/<spec-name>/index.md"
format = "markdown"
```

**`format = "markdown"` is mandatory and its absence is silent.** duvet's default format is IETF; pointed at a markdown spec it extracts **zero** requirements and exits **0**, which looks exactly like success. Say this in the report too — whoever pastes the stanza needs to know that line is load-bearing rather than decorative.

Until the stanza is applied, the spec is invisible to duvet: its requirements are neither extracted nor counted.

### Verify the extraction yourself

Extraction is read-only and takes no config, so you can and MUST run it on the spec you just wrote — no registration needed first:

```bash
duvet extract -f markdown -o /tmp/duvet-check docs/specs/<spec-name>/index.md
```

If the reported requirement count does not match the normative statements you wrote, the spec is malformed — fix it before finishing. A count **lower** than expected means a requirement is not a `###` heading or carries no keyword; a count **higher** means keywords leaked out of your requirement sections. The extracted TOMLs are also the authoritative quote text for whoever writes the annotations; rendered markdown is not.

### This skill still does NOT annotate

Establishing traces means editing source files, which is outside this skill's boundary (see "Scope — Documentation Only"). Instead, **report every requirement that now needs a trace, by REQ ID**, so an implementing skill can establish them. A requirement with no annotation fails `duvet query -c implementation` — that is the intended signal, not a defect in your spec.

**But say out loud what that signal costs.** Where duvet runs as a required check, a red check blocks merge — so a duvet-mode spec PR is **unmergeable by construction** until the implementing traces land. That is expected behavior, not a bug, but it is something to sequence deliberately rather than discover at merge time. Your report MUST state that the spec PR will have a red duvet check, and name the sequencing options:

- Run the implementing skill immediately and land the spec together with its annotations in one PR.
- Keep the spec PR open and stack the implementing PR on it, merging the stack once traces exist.
- Land the spec knowing the check stays red, only if the project accepts that and the requirements are registered but not yet traced.

Pick a recommendation rather than listing all three neutrally — the first is right unless the user has said otherwise.

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
- `AGENTS.md` task-tracking instructions (+ the `CLAUDE.md` → `@AGENTS.md` pointer)
- `REVIEW.md` PR review instructions (+ `.coderabbit.yaml` pointing CodeRabbit at it)

Wait for setup to complete before proceeding.

#### 0.1 Detect duvet mode

```bash
test -d "$(git rev-parse --show-toplevel)/.duvet" && echo "duvet mode: ON" || echo "duvet mode: off"
```

The gate is defined at the **repository root**, so the check MUST resolve the root explicitly. A bare `test -d .duvet` is cwd-relative and reports "off" for a duvet repo whenever the session's working directory is a subdirectory — silently skipping every rule below.

If `.duvet/` exists, **every rule in "Duvet Mode — Requirements Traceability" above applies for the rest of this run** — REQ IDs for newly created requirements only, one self-contained statement per requirement section, RFC 2119 keywords confined to requirement sections, the extraction check, and the registration and snapshot items you REPORT rather than apply. Record this in your working notes so it is not forgotten by Phase 6.

If it does not exist, proceed normally and do not raise duvet at all. Adopting duvet is `fx-dev:setup`'s and `fx-dev:upgrade`'s decision to offer — both entry points do — not this skill's.

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
- **In duvet mode:** head every requirement `### REQ-NNN: Title`, write one self-contained normative sentence per requirement section, and keep RFC 2119 keywords out of every other section — Overview, Background, Design, Constraints, and Scenario blocks are plain prose. Then run the `duvet extract` check before moving on. See "Duvet Mode — Requirements Traceability".

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

**In duvet mode, categories 3 and 4 produce new requirements and category 2 does not.** Only the genuinely new ones get IDs; an outdated requirement is edited in place with its heading untouched. Never let "the spec is being updated anyway" turn into retrofitting IDs onto the headings that were already there.

#### 4.3 Update the Spec

Edit `docs/specs/<spec-name>/index.md` to reflect the current truth:
- Add missing requirements discovered during audit
- Update requirements that have changed
- Remove requirements for deprecated behavior
- Update code snippets to match current implementation
- Add new GIVEN/WHEN/THEN scenarios for undocumented behavior
- **In duvet mode:** requirements you ADD get the next `### REQ-NNN: Title` ID, one self-contained normative sentence, keywords confined to the requirement section (scenarios stay plain). Requirements that ALREADY exist keep their headings byte for byte — **never retrofit an ID onto one**, and treat any heading rename as the breaking change it is. See "NEVER retrofit an ID onto an existing requirement" and "Renaming a requirement heading is a breaking change". Re-run the `duvet extract` check after editing, then report the registration and snapshot items from Phase 6.3.

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
- **MUST NOT restate behavior the spec already owns** — open the requirements section by naming the owning spec section, then list only what the change itself owns (sequencing, migrations, registration, dispatch-path moves, bugfixes). See "Single-Owner Contracts" above. This is the single most important rule for keeping a corpus reviewable.
- Use RFC 2119 language for the requirements the change genuinely owns
- Include GIVEN/WHEN/THEN scenarios ONLY for behavior this change introduces that no spec owns — never copy a spec's scenarios
- Include a detailed `## Tasks` section with checkbox items
- Every capability the requirements mandate MUST appear in a task; a change that requires infrastructure later changes depend on cannot be markable complete without a task for it
- Each top-level task SHOULD map to one PR
- Include design decisions with rationale
- Be specific about files to modify, APIs to change, tests to write
- **NEVER duplicate change document tasks into `docs/tasks.md`** — tasks belong in the change document that defines them. `docs/tasks.md` is ONLY for work not tied to any change document.
- **MANDATORY `### Testing Requirements` subsection** — Every change document's `## Requirements` section MUST open with a `### Testing Requirements` subsection that restates the project's standing, merge-blocking testing rules in tight bullet form. See 5.3.1 below.

#### 5.3.1 Project-Specific Testing Requirements (mandatory)

Every change document MUST include a `### Testing Requirements` subsection as the **first** item under `## Requirements`. This is not optional and applies to every change, no matter how small. Skipping this subsection is a defect in the change document.

**Source the rules from the target project, not from this skill.** Before writing the subsection:

1. **Look for the project's testing conventions.** Common locations, in order of preference:
   - The architecture spec's Testing / Development Conventions section (e.g., `docs/specs/architecture/index.md#testing`)
   - A dedicated `docs/specs/<testing-or-quality-spec>/`
   - `CONTRIBUTING.md` or `docs/contributing.md`
   - `AGENTS.md` or `REVIEW.md` at the repo root
2. **Extract the actual project rules.** These will differ per project. Examples of the kinds of rules you might find:
   - Coverage thresholds (total, per-diff, or none)
   - Required frameworks (e.g., `pytest`, `go test`, `vitest`)
   - Isolation rules (e.g., "integration tests MUST use real Postgres via containers", or conversely "unit tests MUST mock all I/O")
   - Race/concurrency flags (e.g., `-race` in Go, `asyncio` strict-mode in Python)
   - Allowed suppression pragmas and their justification rules
   - E2E / contract / snapshot policies
3. **Phrase the subsection to reference the source.** The first sentence MUST link to the exact section in the project documentation where the rules live. This makes the change doc self-healing when rules evolve.
4. **Use tight bullets.** Each rule is one line. RFC 2119 language where appropriate.
5. **State the consequence.** Close with a one-line reminder that weakening any rule to land the PR is a defect in the PR, not in the rule.

**Never invent rules or copy rules from a different project.** If a project has no documented testing conventions:
- State this explicitly in the change doc's Testing Requirements as a known gap.
- Propose a minimal defensible baseline (e.g., "new behavior MUST have tests; CI MUST execute the suite; failing tests MUST block merge").
- Add an Open Question recommending the project codify a conventions document.

**Minimal shape (language-agnostic):**

```markdown
### Testing Requirements

This change MUST satisfy the project's standing testing rules (see [<Section Name>](<link>)). CI enforces these as merge gates:

- <rule 1 from the project>
- <rule 2 from the project>
- <rule 3 from the project>

Skipping or weakening any of these rules to land the PR MUST be treated as a bug in the PR, not in the rule.
```

**Examples — do NOT reuse verbatim across projects.** Each is specific to its project's conventions:

- *Go service with strict coverage*: "100% diff-scoped coverage", "integration tests MUST use testcontainers-go — mocking Postgres is forbidden", "`go test ./... -race` MUST pass", "`//nolint` MUST carry a rule name and justification"
- *TypeScript library*: "Every exported function MUST have a unit test", "`vitest run --coverage` MUST pass with coverage at or above the project's configured threshold", "no `.only` or `.skip` in committed tests"
- *Python data pipeline*: "`pytest` MUST pass on the full suite", "new SQL transformations MUST ship with a dbt test", "type check (`mypy --strict`) MUST pass"

The rules you write MUST come from the project you're operating in, discovered via step 1 above. If you didn't read the project's conventions, you aren't ready to write the Testing Requirements subsection.

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

#### 6.3 Report the duvet wiring (duvet mode only)

Skip entirely if `.duvet/` does not exist.

**This step produces a report, not edits.** `.duvet/` is outside `docs/`, so this skill MUST NOT write to it: no `config.toml` edit, no snapshot regeneration, no annotation. Report all three so someone with write authority there can act in one pass.

**1. The `[[specification]]` stanza for every new spec.** Emit it filled in and ready to paste, and repeat the `format = "markdown"` warning verbatim — see "Report the registration a new spec needs" above.

**2. The snapshot needs regenerating.** `.duvet/snapshot.txt` is committed and CI runs `duvet report --ci`, which fails whenever the re-derived report disagrees with the committed snapshot. Adding, renaming, or removing **any** requirement turns that job red. Report the exact command:

```bash
cd "$(git rev-parse --show-toplevel)" && rm -rf .duvet/requirements && duvet report
```

The `cd` is not optional. duvet resolves the config, every specification source, and every source pattern relative to the current working directory and never searches upwards, so the same command run from a subdirectory loads 0 specifications, writes no snapshot, and still exits 0 — a silent no-op that looks like success.

The `rm -rf` is not optional. `duvet report` writes one TOML per current spec section into `.duvet/requirements/` and never prunes stale ones, so a renamed or removed heading leaves an orphan behind — which fails locally with `missing section "..."` while CI, running from a fresh checkout, passes. Deleting the directory first keeps local and CI results identical. **You do not run this**: it writes outside `docs/`.

**3. Whether the implementation can be traced at all.** duvet attributes annotations only from files matching a `[[source]]` pattern in `.duvet/config.toml`. Read those patterns and check them against where the new spec's implementation will plausibly live. If it falls outside every pattern, the requirements can never be satisfied no matter how carefully someone annotates — report that gap and the pattern that would close it.

**Verify what you can from inside `docs/`.** Extraction is read-only, so run it:

```bash
duvet extract -f markdown -o /tmp/duvet-check docs/specs/<spec-name>/index.md
```

The reported requirement count MUST equal the number of normative statements you wrote. A count of **0** means the spec itself is malformed — requirements are not `###` headings, or carry no keyword. A count **higher** than expected means RFC 2119 keywords leaked outside your requirement sections; find them and rewrite them as prose. (A correct count here but zero requirements in CI means the applied config stanza is missing `format = "markdown"` — duvet's IETF default fails silently and exits 0.)

Registration is what makes the requirements **visible** to CI. It is not sufficient to make them pass: they also need `[[source]]` coverage and actual annotations, neither of which this skill can supply.

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
5. **Requirements needing traces** (duvet mode only) — list every requirement you created or renamed **by REQ ID and heading**, so an implementing skill can establish the annotations. Call out renamed headings separately: those break existing annotations and need them re-pointed, not newly written.
6. **duvet wiring to apply** (duvet mode only) — everything from Phase 6.3 that you reported instead of applying, because it lives outside `docs/`:
   - the `[[specification]]` stanza for each new spec, with its `format = "markdown"` warning
   - the snapshot regeneration command, `cd "$(git rev-parse --show-toplevel)" && rm -rf .duvet/requirements && duvet report` — root-qualified, because duvet is cwd-relative and the un-`cd`'d form is a silent no-op from a subdirectory
   - any `[[source]]` pattern gap that would leave the new requirements untraceable
   - the warning that the spec PR's duvet check stays red until traces land, plus your recommended sequencing
7. **Suggested next steps**:
   - "Changes ready for implementation via `/dev` or `/team`"
   - "Spec has open questions that need resolution first"
   - "Spec updated to match current implementation — no changes needed"
