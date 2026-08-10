# fx-dev Agent Authority

## Overview

Three `fx-dev` skills act on a repository with materially different powers. `fx-dev:dev` drives a single change to a merge-ready pull request but does not merge it without the user's approval. `fx-dev:team` runs unattended across a backlog the user approved up front and merges its own pull requests within that approved scope. `fx-dev:spec-writer` writes documentation and nothing else.

This spec states the **authority boundaries** of those three skills: who may merge a pull request without asking, what must be true before anyone merges at all, and who may write files and commit. It describes behavior the skills already define today.

## Background

The three skills are prompt documents under `plugins/fx-dev/skills/`, and they are edited continuously — `fx-meta:learn` exists specifically to tune their wording, ordering, and step composition in response to observed misbehavior. A spec that pinned down *how* they work would be falsified by routine maintenance, and every such falsification would force a spec edit that adds no information.

So this spec deliberately specifies only the properties that must survive any rewrite of the workflows: **what an agent is and is not permitted to do to the user's repository.** Those are the properties a user actually relies on when choosing between `/dev` and `/team`, and they are the ones whose silent loss would be a real incident.

Scope boundaries:

- **In scope:** merge authority and write authority for `fx-dev:dev`, `fx-dev:team`, and `fx-dev:spec-writer`.
- **Out of scope, deliberately:** the order, names, numbering, or composition of workflow steps; which sub-agent or skill is invoked when; iteration caps, timeouts, retry bounds, and polling intervals; prompt wording and the field list of the Scope Brief; worktree mechanics; every other skill in `fx-dev` and every other plugin.

Nothing here restates the structural rules of the marketplace itself; those live in [Marketplace Structure](../marketplace-structure/).

## Requirements

### Dev Runs Require User Approval Before Merge

`fx-dev:dev` is the attended workflow. It exists to bring one change to the point of decision and hand that decision back, so the user remains the one who chooses to move `main`.

A `fx-dev:dev` run MUST obtain explicit approval from the user before merging any pull request it produced.

#### Scenario: Every gate passes on an unattended dev run

- **GIVEN** a `fx-dev:dev` run whose pull request has every merge gate satisfied
- **AND** the user has not approved a merge in this conversation
- **WHEN** the run reaches its finalization step
- **THEN** the run reports the pull request as ready and stops without merging

#### Scenario: The user approves the merge

- **GIVEN** the same pull request
- **WHEN** the user states that it should be merged
- **THEN** the run may proceed to merge it, subject to the gate requirements below

### Team Runs May Merge Within Approved Scope

`fx-dev:team` is the unattended workflow. The user approves a body of work up front — a spec, a change document, a task list, an explicit set of pull requests — and the run's value is that it executes all of it without further check-ins. Autonomous merge is therefore a permission, not an obligation: a run that stops for a genuine out-of-contract question is behaving correctly.

A `fx-dev:team` run MAY merge a pull request it produced without seeking further user approval, provided that pull request's work falls within the scope the user already approved.

#### Scenario: A backlog item completes mid-run

- **GIVEN** a `fx-dev:team` run started from a user instruction covering several changes
- **AND** one of its pull requests has every merge gate satisfied
- **WHEN** the run reaches that pull request's merge decision
- **THEN** it merges without pausing to ask the user

#### Scenario: A task reaches beyond the approved scope

- **GIVEN** a `fx-dev:team` run whose next task requires work no approved document covers
- **WHEN** the run reaches that task
- **THEN** it completes the tasks that are covered and reports the uncovered one as blocked rather than deciding for the user

### Required Checks Gate Every Merge

Autonomy is bounded by verification, not replaced by it. A run that may merge without asking is precisely the run that must not merge on an unverified branch.

A pull request MUST NOT be merged while any required check on it is failing or has not completed.

#### Scenario: A check is still running

- **GIVEN** a pull request whose required checks include one still in progress
- **WHEN** the merge decision is reached
- **THEN** the merge does not happen at that point

### Unresolved Reviewer Threads Gate Every Merge

Automated review is a merge gate rather than advice: the run requests it, waits for it, and settles what comes back. A thread may be settled by fixing the finding or by recording it as out of scope, but it may not be left open under a merge.

A pull request MUST NOT be merged while any review thread on it from a configured automated reviewer remains unresolved.

#### Scenario: A reviewer leaves a comment the run considers out of scope

- **GIVEN** a pull request with one open automated-reviewer thread raising an issue outside the approved scope
- **WHEN** the merge decision is reached
- **THEN** the thread is settled with its disposition recorded before any merge, and the change is not widened to satisfy it

### Merge Gates Apply Regardless of Change Size

The gates exist because a change's risk is not proportional to its diff, and "it is only a one-line follow-up" is the reasoning that has historically preceded skipped verification.

The size, triviality, or follow-up status of a pull request MUST NOT be treated as grounds for waiving any merge gate.

#### Scenario: A one-line follow-up pull request

- **GIVEN** a pull request changing a single line, opened to correct an earlier merged change
- **WHEN** its merge decision is reached
- **THEN** it is held to the same gates as any other pull request

### The Dev Coordinator Delegates All Writes

The `fx-dev:dev` session is an orchestrator. Keeping its own hands off the working tree is what makes the delegated work reviewable, keeps the coordinator's context small enough to reach the end of the workflow, and prevents changes that no sub-agent's output accounts for.

The `fx-dev:dev` coordinator MUST NOT write code, create files, or make commits itself, and MUST delegate that work to sub-agents.

#### Scenario: A trivial edit remains after review

- **GIVEN** a `fx-dev:dev` coordinator that has identified a one-character fix in a reviewed file
- **WHEN** it acts on that finding
- **THEN** the edit and its commit are produced by a delegated sub-agent rather than by the coordinator

### The Team Coordinator Delegates All Implementation

A `fx-dev:team` coordinator retains merge authority precisely because it did not write the code it is merging. The separation is what makes its own quality control meaningful rather than self-assessment.

The `fx-dev:team` coordinator MUST NOT implement a task's code itself and MUST route all implementation work through agents it spawns.

#### Scenario: A teammate reports a failure

- **GIVEN** a teammate that reports it could not complete its task
- **WHEN** the coordinator responds
- **THEN** it spawns an agent to carry out the fix rather than implementing the fix itself

### Spec Writer Touches Only the Docs Tree

`fx-dev:spec-writer` produces the documents that later authorize implementation. If it could also implement, the approval step between the two would be doing nothing.

The `fx-dev:spec-writer` skill MUST NOT create or modify any file outside the `docs/` tree.

#### Scenario: A single request asks for a spec and its implementation

- **GIVEN** a user request to write a spec and then build what it describes
- **WHEN** the skill finishes the spec and any change documents
- **THEN** it stops and directs the user to an implementation workflow, having modified nothing outside `docs/`

#### Scenario: A spec turns out to be wrong about the code

- **GIVEN** a spec whose claim about existing behavior is contradicted by the source
- **WHEN** the skill discovers the contradiction
- **THEN** it corrects the document or records an open question, and does not change the source to match

## Design

### Two Authority Models, One Gate Set

`fx-dev:dev` and `fx-dev:team` differ on **who decides to merge** and agree on **what must be true to merge**. The user's approval is per-pull-request in `dev` and up-front-and-once in `team`; the verification a pull request must pass is identical in both.

This is why the gate requirements above are written without naming a skill. They are properties of the merge, not of the workflow that reaches it, and a fourth workflow added tomorrow inherits them by default.

`fx-dev:spec-writer` sits outside both models. It never opens or merges a pull request; its output is a document that a later `dev` or `team` run implements. Its only authority boundary that needs stating is the write boundary.

### What the Gate Requirements Deliberately Understate

Two details of the current skills are stronger than what is specified above, and are recorded here rather than as requirements because they are the parts most likely to move:

- `fx-dev:dev` checks for zero unresolved review threads from **any** reviewer, human included, not only automated ones. The specified rule is the floor both skills meet.
- Both skills enumerate a concrete gate list that also covers coverage reporting and a conventional-commit pull request title. Those are real gates today; they are enumerated in the skills and left out of this spec because the list of configured checks is repository configuration, not an authority boundary.

An automated reviewer that reports a rate limit or is not configured produces no threads, so a documented degradation of that kind satisfies the thread requirement without a special case.

### Enforcement

Nothing in this spec is enforced mechanically. These are instructions in prompt documents, honored by the agent that loads them; there is no hook, CI job, or runtime guard that prevents a merge or a coordinator-authored commit. The requirements are therefore observable in transcripts and pull request history rather than testable in CI, which is a real limitation and the reason the boundaries are kept few and blunt.

### Why Procedure Is Absent

The skills contain a great deal of ordering: numbered SDLC steps, a review matrix, wave-based execution, worktree setup, bounded remediation rounds. None of it appears above. Those are the mechanisms by which the gates are reached, and they are rewritten routinely; specifying them would convert every tuning pass into a spec violation. If a rule here would become false because someone renamed or reordered a workflow step, it does not belong in this spec.

## Constraints

- The requirements bind the skills as loaded. A user who acts directly, or an agent operating without these skills, is outside their reach.
- `fx-dev:team`'s autonomy is inherited from an up-front user instruction. It is authority delegated by the user for a bounded body of work, not standing authority over the repository.
- The write-authority requirements constrain the **coordinator** session, not the run as a whole. A `fx-dev:dev` or `fx-dev:team` run absolutely does write code and commit; the requirement is about which agent does it.

## Open Questions

- **May the `team` coordinator commit at all?** The skill's coordinator rules say it must never create branches or commits, while its pre-merge instructions tell it to push a small corrective commit to a teammate's branch itself when a required documentation update is missing from the diff. The requirement above covers only implementation work, which both statements agree on. Options: forbid coordinator commits outright and always route the correction through a spawned agent, or permit a narrow documentation-only exception and say so explicitly. Current default: leave the requirement at implementation work and resolve the skill's internal inconsistency separately.
- **Does `dev`'s approval requirement bind once or per pull request?** The skill requires approval before merging and, for multi-pull-request work, stops after each one. Whether a user's blanket "merge them as they go" converts a `dev` run into a `team`-style run is not stated anywhere. Current default: unspecified; a run that treats blanket approval as covering later pull requests is not violating the requirement as written.
- **Should the human-thread gate be uniform?** `dev` blocks on unresolved human review threads and `team`'s checklist names only automated reviewers. Making it uniform would be a behavior change to `team`, not a documentation fix.

## References

- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) — requirement level keywords
- [Marketplace Structure](../marketplace-structure/) — structural invariants of this repository
- `plugins/fx-dev/skills/dev/SKILL.md` — the attended SDLC workflow
- `plugins/fx-dev/skills/team/SKILL.md` — the unattended coordinator workflow
- `plugins/fx-dev/skills/spec-writer/SKILL.md` — the documentation-only spec lifecycle
- `AGENTS.md` — repository conventions for plugin development

## Changelog

| Date | Change | Document |
|------|--------|----------|
| 2026-08-09 | Initial spec created — merge and write authority for `dev`, `team`, and `spec-writer`, transcribed from the current skill documents | — |
