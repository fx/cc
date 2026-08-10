# Duvet Adoption

**This file is the single owner of the duvet adoption procedure.** `fx-dev:setup`
and `fx-dev:upgrade` each offer adoption and defer here for every detail. Neither
skill restates the steps, and nothing else in fx-dev may describe how to adopt
duvet — a second copy is a second thing to drift.

## What adoption buys, and what it costs

[duvet](https://github.com/awslabs/duvet) traces every normative requirement in
`docs/specs/` to the source that implements it, and fails CI when a requirement
has no trace or when the committed snapshot disagrees with the code. The cost is
one annotation per requirement, forever, plus a red check until it lands.

`.duvet/` at the repository root is the whole switch: its existence is what makes
`fx-dev:spec-writer` write specs in duvet mode. That is why the directory is
created only once duvet is verified runnable, and why a failed adoption must be
reported loudly rather than left in place.

## The gate — identical wording in every caller

```bash
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
test -d "$repo_root/.duvet" && echo "duvet: adopted" || echo "duvet: not adopted"
```

The gate is defined at the **repository root**, so the check MUST resolve the
root explicitly. A bare `test -d .duvet` is cwd-relative and reports "not
adopted" for a duvet repo whenever the session's working directory is a
subdirectory — which would offer adoption to a repo that already has it.

**If `.duvet/` exists, the repo has adopted duvet: do nothing and say nothing.**
Do not re-offer, do not verify, do not nag. An adopted repo is not this
procedure's business.

## The offer

Ask the **adopt-or-not** question once, with `AskUserQuestion`:

```
AskUserQuestion:
  question: "Adopt duvet requirements traceability for this repo? Specs get machine-checked traces to the code implementing them, enforced in CI, at the cost of maintaining one annotation per requirement."
  header: "Duvet"
  options:
    - label: "Adopt duvet"
      description: "Install duvet, confirm which files carry annotations, scaffold .duvet/, bootstrap the snapshot, and wire the CI gate"
    - label: "Not now"
      description: "Change nothing. Specs stay untraced and spec-writer keeps its normal mode"
```

**"Once" scopes the *offer*, not the whole procedure.** On acceptance the steps
below ask further questions where the answer cannot be inferred safely: the
install method when the repo has no mise config (step 1), the `[[source]]`
patterns (step 3b), and keep-or-revert when the repo has no GitHub Actions
workflows (step 6). Each is a decision adoption is not entitled to make for the
user. Callers must therefore describe this as one *or more* questions — a caller
that promises "a single `AskUserQuestion`" is describing a procedure that no
longer exists.

If the user declines, **proceed with the rest of the calling skill normally and
do not raise duvet again during that run.** Nothing is written on a decline —
not a marker file, not a TODO, not a note in `AGENTS.md`.

A caller that runs many times in one session — `fx-dev:setup`, invoked by every
`/spec-writer` and `/project-management` call — must widen "that run" to the
whole session: once declined, skip the offer silently for the rest of it. An
optional tool asked about repeatedly within one session is nagging, and nagging
is how a prompt stops being read.

**Be honest about where that skip ends.** Because a decline writes nothing, it
cannot outlive the session that heard it: the first `/spec-writer` or
`/project-management` call of the *next* session offers adoption again. Do not
tell the user, or imply anywhere, that the question is asked "once, ever" — it is
asked at most once **per session**, indefinitely.

That is a deliberate trade, not an oversight. A decline costs one keystroke and
leaves the repo byte-identical; the alternative — a persisted `.duvet-declined`
marker or an opt-out key in some config — is a new file or a new schema invented
here, in a procedure `fx-dev:setup` runs unattended, and inventing config the
user never asked for is exactly the change its create-only contract exists to
prevent. If per-session recurrence turns out to be too much, the fix is a durable
opt-out designed on purpose. See **Open questions** at the end of this file; do
not improvise one mid-adoption.

Every write below happens only after this approval. That is what keeps adoption
inside `fx-dev:setup`'s create-only contract: the user reviewed the change at the
prompt, so it is not a change made behind their back.

## On acceptance — in this order

**Every duvet command below runs from the repository root.** Resolve it once and
use it throughout:

```bash
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$repo_root"
```

This is not tidiness. duvet resolves `.duvet/config.toml`, every
`[[specification]] source`, and every `[[source]] pattern` **relative to the
current working directory**, and it does not search upwards. Run from a
subdirectory and duvet reports `Loaded 0 specifications`, writes no snapshot, and
**both `duvet report --ci` and `duvet query -c implementation` exit 0** — a
vacuous pass (verified). Adoption would then report success while the user's
first CI run fails with "Could not read report snapshot". If a step's command is
not shown with `cd "$repo_root"` already applied, it is still subject to this
rule.

### 1. Install duvet

**If the repo has a mise config**, pin duvet in its `[tools]` table — merging into
the one that is already there, or adding the table if the config has none.

Check every path mise actually honours, not just the two obvious ones — a repo
using any of these has a mise config, and offering it a competing root
`mise.toml` would create a second config where one already works (all verified
loaded by mise):

```bash
for p in mise.toml mise.local.toml .mise.toml .mise.local.toml \
         mise/config.toml mise/config.local.toml \
         .mise/config.toml .mise/config.local.toml \
         .config/mise.toml .config/mise/config.toml .config/mise/config.local.toml; do
  test -f "$repo_root/$p" && echo "mise config: $p"
done
```

Prefer the non-`.local.toml` file when both are present: `*.local.toml` is
conventionally gitignored and per-developer, so a pin placed there does not reach
CI or other contributors.

These are the two keys to add:

```toml
rust = "1.97.1"
"cargo:duvet" = "0.4.3"
```

**Where they go depends on whether the file already has a `[tools]` table. Check
first, then follow exactly one branch:**

```bash
grep -n '^\[tools\]' "$repo_root/<config>"
```

**Branch A — the file already has a `[tools]` table** (the grep matched). Insert
the two keys as lines *under the header that is already there*. Do **not** write
a second `[tools]` header.

```toml
[tools]
node = "22.14.0"          # already there — untouched
rust = "1.97.1"           # added
"cargo:duvet" = "0.4.3"   # added
```

**Branch B — the file has no `[tools]` table** (the grep matched nothing). **Add
one.** A mise config of only `[env]`, `[tasks]`, and/or `[settings]` is perfectly
legal and common, so this branch is not an edge case. Append the header with the
two keys under it:

```toml
[env]
FOO = "bar"               # already there — untouched

[tools]                   # added, header included
rust = "1.97.1"
"cargo:duvet" = "0.4.3"
```

A file that has only `[tools.<name>]` sub-tables and no bare `[tools]` is also
branch B: adding a `[tools]` header alongside `[tools.node]` is valid TOML and
mise loads both (verified).

**Never write the keys with no `[tools]` header above them.** Both ways of
getting that wrong are verified against mise 2026.7.10, and neither is
recoverable by later steps:

- **Appended at the end of a file whose last table is, say, `[tasks.hello]`,** the
  keys parse as *fields of that table*. mise rejects the entire config —
  ``unknown field `rust`, expected one of `description`, `alias`, …`` — and exits
  1, loading no tools at all.
- **Placed at true top level, above every header,** mise warns `unknown field …:
  rust` and **silently ignores the pin**: `mise ls --current` shows `rust`
  resolved from the global `~/.config/mise/config.toml`, not from the repo. Step 1
  becomes a no-op and adoption then aborts at step 2 with a confusing "duvet does
  not run".

**Never write a second `[tools]` header** when one already exists, either. Two
`[tools]` tables is a TOML parse error — mise reports `TOML parse error at line
N … duplicate key` — after which mise loads **no tools at all** for the repo,
so adoption would break every unrelated tool the project pins. Verified.

- **If `rust` is already pinned, leave it exactly as it is** and add only
  `"cargo:duvet"`. A second `rust` key in the same table is the same
  duplicate-key parse error, and *overwriting* the existing pin is a change to a
  config value that is already set — forbidden by `fx-dev:setup`'s create-only
  contract (see its "setup MAY / MUST NOT" table). Any cargo toolchain builds
  duvet; the repo's own pin is not adoption's to relitigate.
- **If `"cargo:duvet"` is already pinned, leave that pin exactly as it is too and
  continue adoption** — identical rule, identical reasoning. The repo's own duvet
  pin is no more adoption's to relitigate than its `rust` pin, and blocking here
  would mean a repo that already pins and runs duvet can never adopt. If the
  pinned version is old enough to matter, say so in the final report; do not
  change it and do not stop.

Then run `mise install` from `$repo_root`.

- The `cargo:` prefix is **required**. duvet is not in mise's registry, so a
  plain `mise use duvet` does not resolve. `cargo:duvet` goes through mise's
  cargo backend and works (verified installing 0.4.3).
- `rust` is needed because that backend needs a cargo toolchain.
- **Pin both versions explicitly — never `latest`.** `latest` would let one
  contributor regenerate the snapshot with a different duvet than CI verifies it
  with, which is the exact failure the pinning rationale below exists to prevent;
  a floating `rust` reintroduces it one level down. `1.97.1` is a placeholder for
  a current stable — substitute the version the repo actually wants, but
  substitute *a version*.

**If no mise config exists at any of those paths**, do not assume — ask:

```
AskUserQuestion:
  question: "This repo has no mise config. How should duvet be installed?"
  header: "Install"
  options:
    - label: "Create mise.toml"
      description: "Minimal mise.toml pinning rust + cargo:duvet. Reproducible for every contributor, but introduces mise to a repo that does not use it"
    - label: "cargo install"
      description: "cargo install duvet --locked. No new tooling, but the version is pinned nowhere in-repo, so contributors can drift and regenerate the snapshot inconsistently"
    - label: "Abort adoption"
      description: "Change nothing and continue without duvet"
```

### 2. Verify duvet actually runs — before writing anything else

```bash
cd "$repo_root" && duvet help >/dev/null && echo "duvet: runnable"
```

**Do not use `duvet --version` or `duvet -V`.** duvet 0.4.3 has no version flag:
its CLI requires a subcommand (`init|extract|report|query|merge|help`), so both
forms print `error: unexpected argument '--version' found` and **exit 2** on a
perfectly working install (verified). Using either as the gate makes step 2 fail
for every user, and because a failed step 2 aborts adoption, every adoption would
stop here with step 1 already done — including its `[tools]` edit, on the mise
path. `duvet help` exits 0; so does
`duvet report --help` if a subcommand-level check is wanted.

If the binary is not on `PATH`, try `"$HOME/.cargo/bin/duvet" help` (the
`cargo install` path) or `mise exec -- duvet help` (the mise path) — the same
valid invocation, just differently located.

**Whichever form succeeds here is `$duvet` for every later duvet call in this
procedure.** Record it and use it verbatim — step 4's bootstrap, and any re-run or
re-verification you do afterwards:

```bash
duvet="duvet"                          # or "$HOME/.cargo/bin/duvet", or "mise exec -- duvet"
```

No later step may fall back to a bare `duvet`. On the mise path in a
non-interactive shell there is no bare `duvet` on `PATH`, so verification would
pass and step 4 would die with command-not-found — *after* step 3 created
`.duvet/config.toml`, leaving `fx-dev:spec-writer` in duvet mode with no
snapshot. That is precisely the half-adopted state this ordering exists to avoid.

There are exactly two exceptions, and both are text written *for somewhere else* —
neither is this procedure running a command:

1. **The CI workflow** in step 6 deliberately calls a bare `duvet`: the
   `awslabs/duvet` action installs the binary onto the runner's `PATH`, so
   `$duvet` — a path or `mise exec` prefix valid only on this machine — must
   **not** be substituted there.
2. **The regeneration comment** in the `.duvet/config.toml` header written in
   step 3e, for the same reason: it is instructions for every future
   contributor on every machine, so pinning it to this machine's `$duvet` would
   be wrong. Because a bare `duvet` is not universal either, that comment names
   the `mise exec -- duvet` and `~/.cargo/bin/duvet` forms alongside it, so a
   contributor in a non-activated shell is not left with command-not-found from
   the one command the config tells them to run.

**If duvet does not run, ERROR and stop.** Report the command that failed, its
output, and exactly what exists so far. There is **no `.duvet/` at all** at this
point on either path, so `fx-dev:spec-writer` is unaffected. What there is to
revert depends on the install path step 1 took, and the report must name the one
that applies:

- **mise path** — the `[tools]` entries added to `<mise config path>` are the only
  change; reverting means removing them (and the `[tools]` header too, if step 1's
  branch B created it).
- **`cargo install duvet --locked` path** — **nothing in the repo was modified at
  all.** No mise config was touched, so there is nothing to revert; only the
  machine-local binary was installed. Do not tell the user to undo a mise edit
  that does not exist.

Do not continue to step 3 hoping it resolves itself.

### 3. Establish the source patterns, then scaffold `<root>/.duvet/config.toml`

#### 3a. Adoption MUST write at least one `[[source]]` block

**A config with no `[[source]]` stanza can never pass `duvet query -c
implementation`, no matter how correctly anyone annotates.** duvet only scans
files matched by a `[[source]] pattern`; with none, it parses zero annotations, so
every requirement is "Not implemented".

Verified end to end: a repo with a registered `[[specification]]` and a correctly
annotated source file reports `Not implemented: 1 / Overall: ✗ FAIL` (exit 1)
with no `[[source]]`; adding `[[source]] pattern = "src/**/*.rs"` and nothing else
flips the identical repo to `Fully implemented: 1 / Overall: ✓ PASS` (exit 0).

The consequence of shipping without one is delayed, not absent: adoption looks
clean because a spec-less repo passes vacuously, and then the **first spec that
lands turns the CI gate permanently red**, unfixable by annotating. `spec-writer`
does not rescue this — it only *reports* `[[source]]` gaps, it never supplies
them. So establishing the patterns is adoption's job, and adoption is not complete
without it.

#### 3b. Infer candidate patterns, then confirm them with the user

An inferred-but-wrong pattern is as bad as no pattern — it matches nothing, and
the failure looks identical. So infer, then **ask**.

Infer from the languages actually present at `$repo_root` (detect by manifest and
by extension census; do not guess from the repo name):

| Signal at root | Candidate pattern | `comment-style` needed? |
|---|---|---|
| `Cargo.toml` | `src/**/*.rs` | no — `//=`/`//#` are duvet's defaults |
| `go.mod` | `**/*.go` | no — `//` |
| `package.json`, `tsconfig.json` | `src/**/*.ts`, `src/**/*.tsx`, `src/**/*.js` | no — `//` |
| C/C++/Java/Kotlin/Swift/Scala sources | e.g. `src/**/*.java` | no — `//` |
| `pyproject.toml`, `setup.py`, `*.py` | `src/**/*.py` | **yes** — `{ meta = "#=", content = "#%" }` |
| `Gemfile`, `*.rb` | `**/*.rb` | **yes** — `#` |
| Shell scripts, `.github/workflows/*.yml` | `.github/workflows/*.yml` | **yes** — `{ meta = "#=", content = "#%" }` |
| Markdown that *is* the implementation (prompt/skill/policy docs) | e.g. `**/*.md` | **yes** — `{ meta = "duvet=", content = "duvet#" }`, block form only (see 3d) |

Then confirm with `AskUserQuestion`. Offer the inferred patterns as the default
option, an "edit these" option, and an abort — and put the concrete patterns in
the option descriptions so the user is approving strings, not a category:

```
AskUserQuestion:
  question: "Which files will carry duvet annotations? duvet only scans files matching a [[source]] pattern, and a config with none can never pass the CI gate once a spec lands."
  header: "Sources"
  options:
    - label: "Use inferred"
      description: "<list the exact inferred patterns and comment styles, one per line>"
    - label: "Let me specify"
      description: "Ask for the patterns instead of inferring them"
    - label: "Abort adoption"
      description: "Change nothing. Better than a config that cannot pass"
```

**If the user cannot or will not name a pattern, abort adoption.** Nothing under
`.duvet/` exists yet — 3e has not run — so the only thing to revert is step 1's
install edit *if it took the mise path*, and nothing at all if it took
`cargo install`; name whichever applies and stop. Writing `.duvet/` without a `[[source]]` is worse
than not adopting at all: it flips `spec-writer` into duvet mode *and* guarantees
the gate fails later.

**More than one block is normal, and often necessary.** One `[[source]]` per
distinct comment syntax — `comment-style` is per-block, not global, so languages
with different comment characters cannot share one. This repository's own
`.duvet/config.toml` is the worked example: it needs **two** blocks, one for
`.github/workflows/*.yml` with `{ meta = "#=", content = "#%" }` and one for
`plugins/fx-dev/skills/**/SKILL.md` with `{ meta = "duvet=", content = "duvet#" }`.
Verified: a two-block config with those two distinct styles reports
`Fully implemented: 2 / Overall: ✓ PASS`, both commands exit 0.

#### 3c. `type` on a `[[source]]` block

Omit `type` and each annotation declares its own, defaulting to `implementation`.
Set `type = "implication"` on a block only when *every* citation under that
pattern is satisfied-by-construction — a CI assertion that both enforces and
verifies an invariant, or a rule whose only implementation is the prompt sentence
stating it. `duvet query -c implementation` counts `implementation`,
`implication`, and `exception`, so `implication` passes the gate; `type = "test"`
alone does **not**, and would report every requirement as unimplemented.

#### 3d. Markdown sources need the block-comment form

Markdown has no line-comment syntax, so citations live inside HTML comments, and
**the `<!--` and `-->` delimiters MUST sit on their own lines**:

```markdown
<!--
duvet= docs/specs/<spec>/index.md#<section>
duvet# The exact requirement text.
-->
```

duvet reads the whole line following the meta prefix, so a single-line
`<!--= ... -->` folds the closing delimiter into the value and fails to parse.
That is also why the prefixes are `duvet=`/`duvet#` rather than the `//=`/`//#`
defaults: inside an HTML comment a bare `//` is indistinguishable from prose.

#### 3e. Write the config

Create it with exactly this content — a header comment documenting regeneration,
the schema pin, the confirmed `[[source]]` block(s), and the two reports:

```toml
# Regenerating the snapshot
# -------------------------
# `.duvet/snapshot.txt` is committed and `duvet report --ci` fails whenever the
# re-derived report disagrees with it. After editing a spec or any annotation,
# regenerate from the REPOSITORY ROOT with:
#
#     cd "$(git rev-parse --show-toplevel)" && rm -rf .duvet/requirements && duvet report
#
# If `duvet` is not on your PATH, substitute the invocation your install
# provides — `mise exec -- duvet report` when this repo pins cargo:duvet with
# mise and the shell is not activated, or `~/.cargo/bin/duvet report` after a
# `cargo install duvet --locked`.
#
# The `cd` is not decoration. duvet resolves this config, every specification
# source, and every source pattern relative to the current working directory and
# never searches upwards, so the same command run from a subdirectory loads 0
# specifications, writes no snapshot, and still exits 0 — a silent no-op that
# looks like success.
#
# The `rm -rf` is not optional either. `duvet report` writes one TOML file per
# current spec section into `.duvet/requirements/` and never deletes stale ones,
# so renaming or removing a requirement heading leaves an orphan TOML behind.
# That orphan makes duvet fail locally with `missing section "..."` while CI —
# which runs from a fresh checkout, where `.duvet/requirements/` is gitignored —
# passes. Deleting the directory first keeps local and CI results identical.

'$schema' = "https://awslabs.github.io/duvet/config/v0.4.0.json"

# No [[specification]] entries yet: this repo has no traced specs. fx-dev:spec-writer
# reports the stanza to add for each new spec — `source` plus a MANDATORY
# `format = "markdown"`, without which duvet applies its default IETF parser and
# silently extracts zero requirements.

# Files that may carry annotations. At least one block is MANDATORY: duvet parses
# annotations only from matched files, so a config without one reports every
# requirement as "Not implemented" and can never pass `duvet query -c
# implementation`. One block per distinct comment syntax — `comment-style` is
# per-block, so add a block per language, not a pattern per language. Replace the
# example below with the pattern(s) confirmed at adoption time.
[[source]]
pattern = "src/**/*.rs"

[report.snapshot]
enabled = true
path = ".duvet/snapshot.txt"

[report.json]
enabled = true
path = ".duvet/reports/report.json"
```

**Write no `[[specification]]` entries.** The repo has no specs yet, and
`spec-writer` reports one stanza per spec as they are written. `[[source]]` is the
opposite case: it is not per-spec, nothing else supplies it, and its absence is
unrecoverable-by-annotation — which is why it is settled here.

This step is the point of no return for tooling behaviour: the moment `.duvet/`
exists, `spec-writer` switches to duvet mode.

### 4. Bootstrap the snapshot

Use the `$duvet` invocation resolved in step 2, from `$repo_root`:

```bash
cd "$repo_root"
$duvet report        # writes .duvet/snapshot.txt (and .duvet/reports/)
$duvet report --ci   # must exit 0
```

Both parts matter. A bare `duvet` here breaks the mise install path (step 2), and
running from anywhere but `$repo_root` makes both commands exit 0 without writing
a snapshot — so this step would "succeed" while leaving the repo in exactly the
broken state it exists to prevent. Verify `<root>/.duvet/snapshot.txt` actually
exists before moving on.

**Bootstrapping is mandatory, not optional.** On a repo with no snapshot,
`duvet report --ci` exits 1 with "Could not read report snapshot. This is
required to enforce CI checks." — so skipping this step guarantees the user's
first CI run fails.

A bootstrapped **empty** snapshot is valid and expected here: with no
specifications configured, `duvet report` writes a 0-byte `snapshot.txt`, after
which both `duvet report --ci` and `duvet query -c implementation` exit 0.
Adoption on a spec-less repo is clean.

Note that this same emptiness is why step 3a matters: a spec-less repo passes with
*or* without a `[[source]]` block, so this step cannot detect a missing one.

### 5. Gitignore the regenerated artifacts

Append to `<root>/.gitignore` (create it if absent). Root-qualify the path like
every other step here — an unqualified `.gitignore` run from a subdirectory
creates e.g. `docs/.gitignore`, which does not cover `<root>/.duvet/`:

```gitignore
# Duvet generated artifacts. Both are re-derived from the specs on every
# `duvet report`, so committing them would duplicate the spec text and let it
# drift. The snapshot at .duvet/snapshot.txt IS committed — it is what
# `duvet report --ci` verifies against.
.duvet/reports/
.duvet/requirements/
```

**`.duvet/snapshot.txt` MUST be committed.** It is the CI gate's reference; an
ignored snapshot makes `--ci` fail on every fresh checkout.

### 6. Wire CI

**If `<root>/.github/workflows/` exists**, add the job below. Prefer creating a
new `.github/workflows/duvet.yml` over editing an existing workflow — creation
stays inside `fx-dev:setup`'s contract, and a standalone job is easier to name
as a required check. If the repo has one obvious checks workflow and the user
wants the job there instead, adding it there is equally correct, but say in the
report that an existing workflow was modified.

```yaml
name: Requirements traceability

on:
  pull_request:
  push:
    branches: [main]

jobs:
  duvet:
    name: Requirements traceability
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Two independent pins. The action ref must be immutable like every other
      # `uses:`; v0.4.2 is the newest tag awslabs/duvet has — there is no
      # v0.4.3 tag even though crate 0.4.3 exists on crates.io. The action is a
      # thin wrapper that installs the duvet crate at `version:`, so its own ref
      # does not constrain that version. Pin `version:` explicitly: the action's
      # default input is a stale 0.3.0.
      - name: Install duvet
        uses: awslabs/duvet@v0.4.2
        with:
          version: 0.4.3

      # The actual coverage gate. `duvet report --ci` only diffs the committed
      # snapshot — duvet skips its own coverage enforcement whenever a snapshot
      # path is configured — so without this step a requirement with no citing
      # annotation would pass CI unnoticed.
      - name: Verify every requirement is implemented
        run: duvet query -c implementation

      # Re-derives the report and diffs it against the committed snapshot,
      # failing if annotations and .duvet/snapshot.txt disagree.
      - name: Verify requirement coverage snapshot
        run: duvet report --ci
```

- **`main` in the `push` trigger is a placeholder** — substitute the repo's
  actual default branch (`gh repo view --json defaultBranchRef -q
  .defaultBranchRef.name`), the same way step 1's `1.97.1` is substituted. The
  `pull_request:` trigger is branch-agnostic, so the merge gate is correct either
  way; a wrong `push` branch fails silently instead, dropping snapshot-drift
  verification for direct pushes to the default branch on any repo that is not on
  `main`.
- **The `awslabs/duvet` action only installs the binary.** Running duvet is a
  separate step; the action alone gates nothing.
- **Both commands are needed.** `duvet report --ci` does not check coverage when
  a snapshot is configured; `duvet query -c implementation` is the real coverage
  gate.
- **Do not add a `~/.cargo` cache step.** Measured, the whole job takes ~9
  seconds — the action fetches a prebuilt artifact rather than compiling.
- A new job is not a **required** check until branch protection says so. Report
  that, since an unrequired duvet job blocks nothing.
- Both run steps rely on the default working directory being the checkout root.
  If the job is added to a workflow that sets a `working-directory` default, or
  the repo is checked out into a subpath, set `working-directory` on these two
  steps to the repo root explicitly — otherwise they exit 0 having loaded 0
  specifications and the gate enforces nothing.

**If the repo uses other CI, or none**, do not guess at its config — and do not
quietly finish either. This branch ends with `.duvet/` created and
`fx-dev:spec-writer` in duvet mode with **nothing enforcing traces**: the
half-adoption hazard below, reached by design rather than by failure. It is not
adoption's call to leave a user there silently.

Report the two commands — `duvet query -c implementation` and `duvet report --ci`
— say they must run on every pull request from the repository root, and that
`.duvet/snapshot.txt` has to be in the checkout for `--ci` to work. Then get an
explicit decision:

```
AskUserQuestion:
  question: "No GitHub Actions workflows found, so nothing will enforce duvet traces. .duvet/ has been created, which already makes spec-writer require an annotation per requirement — with no CI gate checking them. Keep it?"
  header: "No CI"
  options:
    - label: "Keep, I'll wire CI"
      description: "Leave .duvet/ in place. Specs get stricter now; you add `duvet query -c implementation` and `duvet report --ci` to your CI yourself"
    - label: "Revert adoption"
      description: "Delete .duvet/, undo the .gitignore entries<, and undo the [tools] edits in <mise config path> — include this clause ONLY if step 1 took the mise path>. spec-writer returns to its normal mode"
```

**That description is conditional, like the report lines.** On the `cargo install
duvet --locked` path no mise config was edited, so offering to "undo the mise
edits" names a change that does not exist; drop the clause and revert only
`.duvet/` and the `.gitignore` entries. The installed binary is machine-local and
outside the repo either way — reverting adoption does not require uninstalling it.

Do not report success on the "keep" path without repeating, in the final report,
that no gate exists yet. An acknowledged trade is fine; an unmentioned one is the
worst of both.

### 7. Any failure at any step is an ERROR

Never continue past a failing step, and never report success over one. State
precisely which files were written and which were not, so the user can either
finish or revert with `git status` in hand.

**Do not commit.** Leave every file in the working tree for the user to review,
the same way `fx-dev:upgrade` leaves its migrations.

## The half-adoption hazard — say this out loud

`.duvet/` existing is what flips `fx-dev:spec-writer` into duvet mode. A repo
where `.duvet/` was created but CI was never wired therefore gets **stricter spec
authoring with nothing enforcing it** — the worst of both trades.

So:

- Create `.duvet/` only after step 2 has verified duvet runs.
- If any step after 3 fails, say plainly that `.duvet/` now exists, that
  spec-writer will treat the repo as duvet-mode from now on, and exactly what
  remains (`duvet report` bootstrap, gitignore entries, CI job).
- Offer removing `.duvet/` as the clean revert if the user does not want to
  finish.
- **The no-CI branch of step 6 reaches this state without any step failing.**
  That is the one path where half-adoption is a legitimate outcome rather than a
  bug, and it is exactly why that branch ends in an explicit keep-or-revert
  question instead of a bare informational note. Never take it silently.
- A missing `[[source]]` block is the same hazard on a delay: everything passes
  today and the gate is unfixable the day a spec lands. Step 3a is not optional
  for the same reason this section is not optional.

## Report

On success. **Every line is conditional on what actually happened** — report the
install method that was used, the source patterns that were confirmed, and the CI
line that matches the branch taken in step 6. Do not print a line for a file that
was not written:

```
Duvet adopted:
  <mise config path>  + cargo:duvet 0.4.3 (rust already pinned / + rust <version>)
                        — or: cargo:duvet <version> already pinned, left as-is
                        — or: cargo install duvet --locked, no in-repo pin
  .duvet/config.toml  created (snapshot + JSON report, no specifications yet)
                        [[source]]: <the confirmed patterns, with comment styles>
  .duvet/snapshot.txt bootstrapped (empty — no specs registered yet)
  .gitignore          + .duvet/reports/, .duvet/requirements/
  <CI line — exactly one of:>
    .github/workflows/duvet.yml  created (duvet query -c implementation; duvet report --ci)
    <existing workflow path>     MODIFIED — duvet job added to an existing workflow
    NO CI GATE                   this repo uses other CI or none. .duvet/ exists, so
                                 spec-writer now requires annotations, but nothing
                                 verifies them until you add the two commands yourself

Nothing committed — review with git status.
Next: /fx-dev:spec-writer now writes specs in duvet mode, and reports the
[[specification]] stanza to add to .duvet/config.toml for each new spec.
Make the "Requirements traceability" job a required check for it to gate merges.
```

The CI line is the one most easily got wrong: printing `.github/workflows/duvet.yml
created` unconditionally is false on the modified-existing-workflow path and
actively misleading on the no-CI path, where it claims a gate that does not exist.

On decline: say nothing beyond continuing the calling skill's normal work.

## Open questions

Tracked here deliberately rather than improvised mid-adoption:

- **A durable opt-out for the offer.** A decline currently persists only for the
  session (see "The offer"), so the question recurs once per session forever. A
  fix needs a persisted signal, and every candidate — a `.duvet-declined` marker,
  a key in `.coderabbit.yaml`, a new fx-dev config file — is either a file
  `fx-dev:setup` may not invent unattended or a schema shared with other skills.
  It needs designing across `fx-dev:setup`, `fx-dev:upgrade`, and
  `fx-dev:spec-writer` at once. Until then the honest description above stands.
