# fx-ultra

The **ultra-rigorous** edition of the fx-dev development workflow. Same SDLC backbone — taken to the extreme. fx-ultra exists to autonomously implement work to a far higher bar than any spec asks for, and to apply harsh judgement and extreme polish along the way.

> fx-ultra is a fork of `fx-dev`. It keeps the entire SDLC, PR, review, and GitHub toolchain, and layers four non-negotiable **ultra mandates** on top. Everything is namespaced `fx-ultra:` and self-contained.

## The Four Ultra Mandates

1. **PROVE, NEVER ASSUME — `ultra-verifier`.** Every change is verified end-to-end against the **real running stack** by direct observation (web→Playwright MCP, mobile→emulator/simulator, CLI→real invocation, API/backend→real requests + DB inspection, desktop→driver, libraries→consumer harness). Runs at least twice — three times when anything is uncertain. "Looks right" / "tests pass" / "CI is green" are **not** verification. This skill reconciles and supersedes the old `verify-web-change`.
2. **100% COVERAGE, ALWAYS — regardless of the spec.** Every line and branch of changed code must be covered by real, meaningful unit **and** integration/e2e tests. Lowering thresholds, excluding files, or skipping tests is forbidden.
3. **POLISH WITH EXTREME PREJUDICE — `ultra-designer`.** Any visual surface is inspected against explicit design principles via the live DOM and computed styles (never screenshots): full interactivity-state matrix (hover/focus/active/disabled/loading/empty/error), motion where warranted, responsiveness, and accessibility.
4. **THE JUDGE IS BINDING — `ultra-judge`.** Runs last, audits the whole progression from primary evidence, and renders **APPROVE / REMEDIATE / HALT**. APPROVE is required to complete or merge. **HALT stops the entire run/team** and escalates to the user — and proceeding past a HALT is the single worst failure of the workflow.

## The Ultra Skills

| Skill | Role |
|-------|------|
| **ultra-verifier** | The one true end-to-end verifier. Launches the repo's real local stack and drives it by whatever means the platform demands. Emits a strict `ULTRA-VERIFIER VERDICT` (PASS/FAIL/BLOCKED) with per-item, directly-observed evidence. |
| **ultra-designer** | The visual/UX quality enforcer. Inspects every visual element with extreme prejudice against design principles, the full interactivity-state matrix, motion, responsiveness, and a11y — by querying the live DOM/CSSOM, never screenshots. Emits `ULTRA-DESIGNER VERDICT`. |
| **ultra-judge** | The terminal, adversarial gate. Audits the whole progression from primary evidence, distrusts every claim until proven, and can **HALT** the team/progress when rigor was bypassed. Emits `ULTRA-JUDGE VERDICT` (APPROVE/REMEDIATE/HALT). |

## Source of Truth: the `dev` skill

`dev` (`fx-ultra:dev`) is the single ultra SDLC source of truth. Both solo runs and `team` (coordinated multi-agent) runs execute the same steps and the same gates:

```
0  Auth → 1 Branch → 2 Requirements → 3 Plan → 4 Implement
4.5 Pre-PR self-review (simplify → code-review → CodeRabbit → Codex)
4.6 100% COVERAGE GATE        <- ultra mandate #2
5   Open PR (ready, never draft)
5.5 ULTRA-VERIFICATION (>=2x) <- ultra mandate #1  (fx-ultra:ultra-verifier)
5.6 ULTRA-DESIGN (any UI)     <- ultra mandate #3  (fx-ultra:ultra-designer)
6   Review (Copilot + CodeRabbit) -> 7 CI -> 8 Merge gates
9   ULTRA-JUDGE final verdict <- ultra mandate #4, BINDING  (fx-ultra:ultra-judge)
```

`team` (`fx-ultra:team`) is the parallel coordinator. It enforces the same four ultra mandates as **merge gates** on every PR (gates 6–9), with the ultra-judge HALT freezing any PR that bypassed rigor.

## Quick Start

```
Implement https://github.com/owner/repo/issues/123     # dev auto-triggers, ultra rigor applied
Fix the TypeError in auth.js:42                          # test-first fix, fully verified
Add a dark mode toggle to settings                       # implemented, ultra-verified, ultra-polished
Use the team skill to implement docs/specs/auth/         # parallel team under the ultra gates
```

## Relationship to fx-dev

fx-ultra is a superset of fx-dev's workflow. Use **fx-dev** for the standard lifecycle; reach for **fx-ultra** when you want autonomous implementation held to the maximum bar — exhaustive end-to-end proof, 100% coverage, uncompromising visual polish, and a final judge with the authority to stop the line.

## Installation

Part of the fx/cc marketplace. Enable with `/plugin` (select `fx-ultra@fx-cc`).

## License

Part of the fx/cc Claude Code marketplace.
