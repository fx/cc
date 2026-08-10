# Marketplace Structure

## Overview

This repository is a Claude Code plugin marketplace: a root manifest at `.claude-plugin/marketplace.json` that names a set of plugins, plus one directory per plugin under `plugins/`. Claude Code reads those manifests directly when a user adds or refreshes the marketplace, so a structurally broken manifest is not a build failure — it is a runtime failure in every client that has the marketplace installed.

This spec states the structural invariants of that layout as observable, checkable requirements. Each one is already enforced today by the `validate` job in `.github/workflows/test.yml`, which runs on every pull request targeting `main` and on every push to `main`.

## Background

The marketplace grew organically and its rules lived only as bash assertions inside a CI workflow. That made the rules real but not addressable: nothing could cite them, and nothing could report which of them were covered.

This spec is the first step of a requirements-traceability spike. It restates the existing CI assertions as numbered, quotable requirements so that a traceability tool can map each one to the code that enforces it. It deliberately describes only what CI enforces **today** — no aspirational invariants, no proposed checks.

Scope boundaries:

- **In scope:** the structural contract between `marketplace.json`, the `plugins/` tree, and the per-plugin manifests.
- **Out of scope:** the version-bump policy enforced by `.githooks/pre-commit`, the behavior of any individual plugin or skill, the SDLC workflows those plugins implement, and the GitHub Pages deployment in `.github/workflows/pages.yml`.

Repository conventions for naming, grouping, and documenting plugins live in `AGENTS.md` and are not restated here.

## Requirements

### Marketplace Manifest Is Parseable

The marketplace manifest is the entry point Claude Code fetches first; if it does not parse, nothing else about the repository can be discovered.

The repository MUST contain a `.claude-plugin/marketplace.json` file that parses as valid JSON.

#### Scenario: Manifest contains a syntax error

- **GIVEN** `.claude-plugin/marketplace.json` has a trailing comma in the `plugins` array
- **WHEN** the structural validation runs
- **THEN** validation fails and reports the manifest as unparseable

### Marketplace Manifest Declares Its Identity

Claude Code keys an installed marketplace by these fields, and renders the owner to the user before install.

`.claude-plugin/marketplace.json` MUST declare the top-level fields `name`, `owner`, and `plugins`.

#### Scenario: Manifest omits owner

- **GIVEN** `.claude-plugin/marketplace.json` parses as valid JSON but has no `owner` key
- **WHEN** the structural validation runs
- **THEN** validation fails and names the missing field

### Every Plugin Directory Carries a Manifest

`plugins/` is enumerated by directory, not by manifest presence, so a directory without a manifest is an unusable half-plugin rather than an ignored one.

Every directory directly under `plugins/` MUST contain a `.claude-plugin/plugin.json` file.

#### Scenario: A plugin directory is added without a manifest

- **GIVEN** a new directory `plugins/fx-example/` containing only `README.md`
- **WHEN** the structural validation runs
- **THEN** validation fails and names the directory that lacks a manifest

### Plugin Manifests Are Parseable

Every `plugins/*/.claude-plugin/plugin.json` file MUST parse as valid JSON.

### Plugin Manifests Declare Name and Version

`name` identifies the plugin to Claude Code and namespaces its skills; `version` is the signal the plugin cache uses to decide whether to refresh.

Every `plugins/*/.claude-plugin/plugin.json` file MUST declare the top-level fields `name` and `version`.

#### Scenario: A manifest omits version

- **GIVEN** `plugins/fx-example/.claude-plugin/plugin.json` declares `name` but no `version`
- **WHEN** the structural validation runs
- **THEN** validation fails and names both the missing field and the manifest it belongs to

### Declared Component Paths Resolve

A plugin manifest may list its skills and agents explicitly. Any such path is a promise about the contents of the repository, and a broken one surfaces to the user as a component that appears in listings but cannot be loaded.

Every path listed in a plugin manifest's `skills` or `agents` array MUST resolve to an existing file, interpreted relative to that plugin's own directory.

#### Scenario: A manifest references a deleted skill

- **GIVEN** `plugins/fx-example/.claude-plugin/plugin.json` lists `skills/gone/SKILL.md`
- **AND** no file exists at `plugins/fx-example/skills/gone/SKILL.md`
- **WHEN** the structural validation runs
- **THEN** validation fails and names the missing path

#### Scenario: A manifest declares no components

- **GIVEN** a plugin manifest with neither a `skills` nor an `agents` key
- **WHEN** the structural validation runs
- **THEN** the path check is skipped for that plugin and validation continues

### Marketplace Entries Resolve to Plugin Directories

Each entry in the `plugins` array points at a plugin by `source`. A relative source is a path into this repository, and it is the link that makes a plugin installable rather than merely present on disk.

Every entry in `.claude-plugin/marketplace.json` whose `source` begins with `./` MUST resolve to an existing directory that contains a `.claude-plugin/plugin.json` file.

#### Scenario: A marketplace entry points at a renamed directory

- **GIVEN** `marketplace.json` lists a plugin with `source` of `./plugins/fx-old`
- **AND** the directory has been renamed to `plugins/fx-new`
- **WHEN** the structural validation runs
- **THEN** validation fails and names the unresolved directory

### Plugin Markdown Carries Frontmatter

Claude Code reads a skill's or agent's frontmatter to decide when to surface it, so a markdown file without frontmatter is usually a component that will never trigger. This is a strong recommendation rather than an absolute rule: the repository contains markdown that is prose documentation rather than a component definition, and the current check cannot tell the two apart.

Every markdown file under `plugins/` other than a file named `README.md` SHOULD begin with a `---` frontmatter delimiter on its first line.

#### Scenario: A skill file loses its frontmatter

- **GIVEN** `plugins/fx-example/skills/demo/SKILL.md` whose first line is a heading
- **WHEN** the structural validation runs
- **THEN** a warning naming the file is emitted and the validation job still succeeds

## Design

### Enforcement Point

All of the above is enforced by the `validate` job in `.github/workflows/test.yml`, which triggers on `pull_request` against `main` and on `push` to `main`. The job checks out the repository and runs a sequence of `jq`- and shell-based assertion steps; the steps run under `bash -e`, so any failing assertion aborts its step and fails the job.

The steps map to the requirements above as follows:

| Workflow step | Requirements enforced |
|---|---|
| Validate marketplace.json | Marketplace Manifest Is Parseable; Marketplace Manifest Declares Its Identity |
| Validate plugin manifests | Plugin Manifests Are Parseable; Plugin Manifests Declare Name and Version |
| Verify plugin files exist | Every Plugin Directory Carries a Manifest; Declared Component Paths Resolve |
| Validate markdown frontmatter | Plugin Markdown Carries Frontmatter (advisory only) |
| Verify marketplace references plugins correctly | Marketplace Entries Resolve to Plugin Directories |

### Blocking Versus Advisory Checks

The distinction matters for traceability, because an advisory check does not gate anything.

Every check except the frontmatter check aborts the workflow on failure. The frontmatter check emits `Warning:` to the step log and always exits zero — it is diagnostic output, never a gate. Treating it as blocking in future tooling would be a behavior change, not a bug fix.

### Current Repository State

At the time of writing the marketplace declares six plugins — `fx-dev`, `fx-research`, `fx-mcp`, `fx-meta`, `release-please`, and `steam` — each with a `./plugins/<name>` source and a matching directory.

No plugin manifest currently declares a `skills` or `agents` array; skills are discovered by convention from `plugins/<name>/skills/*/SKILL.md`. The "Declared Component Paths Resolve" requirement therefore holds vacuously today. It is specified because the manifest format permits those arrays and the check is live the moment one is added.

### Known Gaps in the Current Enforcement

These are properties of the existing implementation, recorded so the spec is not read as claiming stronger guarantees than CI delivers:

- A `source` that does not begin with `./` is skipped entirely by the resolution check. No non-relative sources exist today.
- The manifest-driven loops iterate over unquoted command substitution, so a plugin name or component path containing whitespace would be word-split rather than checked as a single value.
- Nothing verifies that a plugin manifest's `name` matches its directory name, or that it matches the `name` used for that plugin in `marketplace.json`.

## Constraints

- Validation runs on `ubuntu-latest` GitHub-hosted runners using only preinstalled tooling (`jq`, `curl`, coreutils). No package installation step exists, so any future check has to work within that toolset or add its own setup.
- The requirements describe repository structure only. They say nothing about the runtime behavior of any plugin, and passing validation is not evidence that a plugin works.

## Open Questions

- **Should marketplace reachability be a requirement?** The workflow has a final step that runs only on `main`, sleeps 30 seconds, and `curl`s the published marketplace manifest. It logs a warning for any non-200 response and never fails the job, so it is currently a smoke signal rather than an invariant. Options: promote it to a blocking post-deploy check with a retry loop, move it out of the validation job entirely, or leave it as-is. Current default: leave it as-is, and deliberately specify no requirement for it.
- **Should plugin `name` be required to match its directory and its marketplace entry?** Nothing enforces this today and nothing violates it either. Adding the requirement would be a new check, which is out of scope for this spike.

## References

- [Claude Code Plugin Documentation](https://docs.claude.com/en/docs/claude-code/plugins)
- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) — requirement level keywords
- `AGENTS.md` — repository conventions for plugin naming, grouping, and documentation
- `.github/workflows/test.yml` — the enforcing workflow

## Changelog

| Date | Change | Document |
|------|--------|----------|
| 2026-08-09 | Initial spec created — structural invariants transcribed from the existing `validate` CI job | — |
