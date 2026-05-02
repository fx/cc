---
name: research-project
description: "MUST BE USED when user asks to research a project, validate a product idea, scope a new application, evaluate market viability, or lay out the foundational approach for building a full application. Triggers: 'research a project', 'research project', 'should we build X', 'is X viable', 'lay out the approach for X', 'scope out X', 'validate this idea', 'competitive analysis', 'market analysis', 'how should we build X'. Performs the most thorough possible end-to-end project research: competitive landscape discovery, deep competitor analysis, market viability assessment, constraint validation, and at least two fully-reasoned solution proposals — followed by adversarial self-validation via a dedicated red-team sub-agent."
---

# Research Project

Act as the most thorough project researcher possible. Lay out the foundational approach for a full application by combining competitive landscape discovery, deep market analysis, constraint validation, multi-solution proposal, and adversarial self-validation.

This skill produces a comprehensive research dossier — not a quick recommendation. Depth, rigor, and reasoned trade-offs are non-negotiable. A shallow output is a failed execution of this skill.

## Operating Principles

- **No shortcuts**: every section must be substantively reasoned, not stubbed. If a section feels short, it is incomplete.
- **Cite everything**: every competitor, statistic, claim, or constraint must reference a source (URL, repo, commit, doc, user-supplied input). Unsourced claims are forbidden.
- **Distrust your first answer**: the deliverable is not done until a separate adversarial sub-agent has audited it (Phase 5).
- **Surface uncertainty explicitly**: when data is missing, ambiguous, or contradictory, say so in the dossier rather than papering over it.
- **Reason in writing**: prefer expanded prose with clearly labeled trade-offs over terse bullet lists. Bullets are acceptable for enumeration; reasoning belongs in prose.
- **Use parallel tool calls**: when running independent searches (web, GitHub, awesome-lists), batch them in a single message to maximize throughput.

## Inputs to Establish Before Starting

Before research begins, extract from the user's request (and ask only if truly missing):

1. **Project concept**: what is being built, in 1–3 sentences
2. **Target users**: who it is for
3. **Core problem**: what pain it solves
4. **Hard constraints**: budget, timeline, team size, tech stack lock-ins, compliance, deployment model (self-hosted vs SaaS), licensing requirements
5. **Soft preferences**: language, framework, infra, design philosophy
6. **Success criteria**: how the user will judge whether the proposal is good

If the user supplies a brief or spec document, treat it as authoritative and quote from it directly in the validation phase.

Do not ask more than 3 clarifying questions before starting. Missing information is itself a finding — record it in the dossier under "Open Questions / Missing Inputs."

## Phase 1: Competitive & Adjacent Landscape Discovery

Goal: find every product, project, library, or initiative that even remotely resembles the proposed concept. Cast the net wide; pruning happens in Phase 2.

Run these workstreams in parallel (single message, multiple tool calls):

### 1.1 Commercial / Closed-Source Competitors
- WebSearch for direct competitors using multiple query phrasings (problem-based, persona-based, category-based, "alternative to X", "vs X")
- WebSearch for review aggregators: G2, Capterra, Product Hunt, AlternativeTo, Trustpilot, Gartner Peer Insights
- WebSearch for industry analyst commentary: Gartner, Forrester, IDC, a16z/Bessemer/Sequoia portfolio posts
- WebSearch Hacker News, Lobsters, Reddit (r/SaaS, r/selfhosted, domain-specific subs) for "Show HN", "Ask HN", and discussion threads

### 1.2 Open Source Projects
- `gh api search/repositories` with multiple keyword combinations (problem, domain, technology). Sort by stars and by recently-updated.
- `gh api search/repositories -q "awesome {topic} in:name,description"` to discover curated awesome-lists; mine the lists themselves for projects.
- For each promising repo, capture: stars, forks, last commit date, open/closed issue ratio, primary language, license, contributor count.
- Search GitLab, Codeberg, and SourceHut for projects that may not be on GitHub.

### 1.3 Adjacent / Tangential Projects
Things that solve a sibling problem, a superset, or a subset. Adjacent prior art often reveals failure modes and pivots that shaped the category.

### 1.4 Failed / Abandoned Attempts
WebSearch for post-mortems, "we shut down", "lessons learned", abandoned repos (no commits in 2+ years that once had traction). Failed attempts encode hard-won negative knowledge — do not skip.

### 1.5 Academic & Research Prior Art
WebSearch arxiv.org, Google Scholar, ACM Digital Library for relevant papers if the domain has research overlap (ML, distributed systems, security, HCI, etc.).

**Output of Phase 1**: a raw inventory of at minimum **15 entities** (combined commercial + OSS + adjacent + failed + academic). If the domain genuinely has fewer, document why and enumerate what you searched.

## Phase 2: Deep Competitor Analysis & Market Viability

Goal: turn the inventory into structured intelligence. For each meaningful entity from Phase 1, produce a profile. Then synthesize across profiles into a market-viability assessment.

### 2.1 Per-Competitor Profile

For the top 5–10 most relevant entities, capture:

- **Identity**: name, URL, repo, license, founding/launch date
- **Positioning**: one-sentence pitch, target persona, primary use case
- **Feature surface**: top 5–10 features, and explicitly the features they *don't* have
- **Tech stack** (if discoverable): languages, frameworks, infra, notable dependencies
- **Business model**: pricing, free tier, OSS-core split, hosted vs self-hosted, enterprise tier
- **Traction signals**: stars/forks/contributors, MRR/funding/customer logos if public, GitHub activity trend (growing/flat/declining), employee count (LinkedIn), social proof
- **Strengths**: what they do measurably better than the rest
- **Weaknesses**: complaints from reviews, GitHub issues, HN/Reddit threads — quote real users
- **Strategic posture**: are they a defensible incumbent, a fast-follower, a stagnant incumbent ripe for disruption, or a niche specialist?

For entities that are clearly tangential, a 2–3 line note is sufficient — but the note must exist.

### 2.2 Cross-Cutting Synthesis

After the per-competitor work, synthesize:

- **Category maturity**: emerging / growing / mature / declining. Justify with evidence (funding flows, repo growth curves, search-trend signals if available).
- **Common feature floor**: what every credible entrant ships. This is table stakes — failing to ship these is fatal.
- **Common gaps**: what credible users complain about across multiple products. This is where opportunity lives.
- **Pricing & monetization patterns**: what users pay, what they refuse to pay for, what's bundled vs unbundled.
- **Distribution & GTM patterns**: how competitors acquire users (SEO, OSS funnel, sales-led, dev-tool viral, marketplace).
- **Technical patterns**: architectural choices that recur across leaders (e.g., everyone ships a CLI + web UI, everyone uses Postgres + a worker queue, everyone exposes a plugin system).

### 2.3 Market Viability Verdict

State a clear verdict: **viable / viable-with-caveats / non-viable / unclear-pending-data**. Justify with at least:

- **TAM / SAM signal**: even a rough order-of-magnitude estimate, sourced. If it cannot be estimated, say why.
- **Competitive intensity**: red-ocean vs blue-ocean assessment.
- **Defensibility**: is there a moat available to a new entrant (data, network effects, switching costs, regulatory, distribution)?
- **Timing**: why now? Or why not now? What's changed in the last 12–24 months that opens or closes this window?
- **Risk register**: top 5 risks ordered by severity × likelihood.

## Phase 3: Approach Validation Against Inputs

Goal: pressure-test the user's stated approach (if any) against the constraints they gave and the market reality from Phase 2.

For each user-supplied constraint, preference, or assumption, render an explicit verdict:

- **Constraint**: quote the user verbatim
- **Reality check**: what Phase 1–2 evidence supports or contradicts it
- **Verdict**: confirmed / partially-confirmed / contradicted / untestable
- **Implication**: what this means for the proposal

Specifically interrogate:

- **Stated tech stack**: is it appropriate for the workload, team skill, and competitive parity? Cite competitors using or avoiding it.
- **Stated timeline / scope**: is a credible MVP shippable in the window? Compare to how long competitors took to reach equivalent surface.
- **Stated business model**: does it match what the market has already shown willingness to pay for?
- **Stated differentiation**: is the differentiator real, or has a competitor already shipped it?
- **Stated target users**: are these users actually reachable, and do they actually pay (or contribute) for solutions in this space?

If the user supplied no explicit constraints, derive the implicit ones from the request and validate those. Record this derivation transparently.

## Phase 4: Solution Proposals (Minimum Two)

Goal: propose **at least two genuinely different** solution approaches. Two slight variations of the same idea is a failed Phase 4 — the proposals must reflect meaningfully distinct strategic bets.

For each proposal, produce a section with:

### 4.1 One-Line Thesis
What this solution *is*, in one sentence.

### 4.2 Strategic Bet
What assumption about the market, users, or technology has to be true for this to win. State it explicitly and as a falsifiable claim.

### 4.3 Architecture Sketch
- Component diagram (described in prose if no diagram tool)
- Data model summary
- Key external dependencies and integrations
- Deployment topology (self-hosted, SaaS, hybrid, edge, on-device)
- Synchronous vs async boundaries; storage choices; auth model

### 4.4 Tech Stack Recommendation
For each layer (frontend, backend, datastore, infra, build, observability, auth, payments if relevant): the recommended choice and the realistic alternative, with the trade-off in one line each.

### 4.5 MVP Scope
The smallest shippable surface that lets a real user solve the core problem end-to-end. Be ruthless about cuts — every feature beyond the floor needs justification.

### 4.6 Phased Roadmap
Phase 0 (prototype / spike), Phase 1 (MVP), Phase 2 (paid/scaled), Phase 3 (defensibility). Order tasks by dependency, not by enthusiasm.

### 4.7 GTM & Distribution
How the first 100, then first 1000 users find this. Tie back to the distribution patterns from Phase 2.

### 4.8 Cost Model
Order-of-magnitude monthly run-cost at MVP scale, with the dominant cost line items called out (compute, model inference, storage, egress, paid SaaS dependencies).

### 4.9 Risks Specific to This Proposal
Not the generic risks from Phase 2 — the ones that matter *if you take this specific bet*.

### 4.10 Falsification Test
The cheapest experiment that would disprove the strategic bet from 4.2. If you can't design one, the bet is too vague.

### 4.11 Comparison Matrix
After all proposals, a side-by-side table comparing them on: time-to-MVP, $ cost, technical risk, market risk, defensibility, optionality, fit-to-stated-constraints. Recommend one with reasoning, but do not collapse into a single answer prematurely — preserve the alternatives so the user can override.

## Phase 5: Adversarial Self-Validation (REQUIRED)

After the dossier is written but before delivering it, launch a dedicated sub-agent to attack it. This phase is not optional. Skipping it is a failed execution of this skill.

### 5.1 Spawn the Red-Team Sub-Agent

Use the `Agent` tool with `subagent_type: "general-purpose"` (or `Explore` if read-only research suffices). The red-team agent must run with a self-contained adversarial brief and have no prior conversational context — its independence is the point.

Invoke the agent with a prompt structured as follows:

```
You are a red-team auditor. Your sole job is to poke holes in the attached
project-research dossier. Be ruthless, specific, and evidence-based.
Do not reassure, do not soften, do not summarize what the dossier got right.
Your value is in finding what is wrong, missing, or unjustified.

For each section of the dossier (Phase 1 inventory, Phase 2 competitor
analysis, Phase 2 market viability, Phase 3 constraint validation, Phase 4
proposals), produce findings of these types:

1. FACTUAL ERRORS — claims that are wrong. Cite the dossier line and the
   correct source.
2. MISSING COMPETITORS — credible products/projects the inventory missed.
   Show how you found them.
3. UNJUSTIFIED LEAPS — conclusions not supported by the cited evidence.
4. HIDDEN ASSUMPTIONS — load-bearing assumptions presented as facts.
5. SURVIVORSHIP / SELECTION BIAS — which failure modes were filtered out.
6. WEAK FALSIFICATION TESTS — proposed experiments that wouldn't actually
   disprove the stated bet.
7. SCOPE / TIMELINE OPTIMISM — places where the MVP or roadmap is
   under-scoped relative to the competitor parity floor.
8. COST UNDERESTIMATES — line items missing or off by an order of magnitude.
9. ALTERNATIVE PROPOSALS NOT CONSIDERED — strategically distinct approaches
   the dossier didn't enumerate.
10. RISKS NOT REGISTERED — concrete failure modes absent from the risk
    register.

For each finding: cite the exact section/sentence, state the problem,
state why it matters, and cite the source (URL, repo, doc) backing your
counter-claim. If you cannot find a source, label the finding as
"speculative" and explain what would be needed to confirm it.

Conclude with a SEVERITY-RANKED LIST (critical / major / minor) and a
single-line verdict: SHIP / REVISE / REWRITE.

The dossier follows below this line.
---
[paste full dossier]
```

The dossier must be passed in full — the red-team agent has no prior context.

### 5.2 Integrate Red-Team Findings

Read the red-team report. For each finding:

- **Critical / Major findings**: revise the dossier. Do not hand-wave them away. If a critical finding cannot be resolved (e.g., requires data the user must supply), surface it explicitly in the final "Open Questions" section.
- **Minor findings**: either fix or acknowledge with reasoning for non-fix.

After integration, append a final section to the dossier:

- **Adversarial Audit Summary**: list each finding, the action taken (revised / acknowledged / disputed-with-reasoning), and the verdict the red-team gave.

This audit trail makes the rigor visible and lets the user verify nothing was quietly dismissed.

### 5.3 Optional Second Pass

If the red-team verdict was REWRITE, or if more than 3 critical findings landed, run Phase 5 a second time on the revised dossier. Stop after the second pass regardless — diminishing returns kick in fast.

## Final Deliverable Structure

The dossier delivered to the user follows this exact outline:

```markdown
# Project Research Dossier: [Project Name]

## 0. Executive Summary
[8–15 lines. Verdict, top recommended proposal, top risks, top open questions.]

## 1. Inputs & Constraints
[What was given, what was inferred, what is missing.]

## 2. Competitive & Adjacent Landscape
### 2.1 Inventory
[Full Phase 1 inventory with sources.]
### 2.2 Per-Competitor Profiles
[Top 5–10 deep profiles.]
### 2.3 Cross-Cutting Synthesis
[Maturity, feature floor, gaps, pricing, GTM, technical patterns.]

## 3. Market Viability
[Verdict + TAM/competition/defensibility/timing/risks.]

## 4. Constraint & Approach Validation
[Per-constraint verdicts.]

## 5. Solution Proposals
### 5.1 Proposal A: [Name]
[Full sections 4.1–4.10.]
### 5.2 Proposal B: [Name]
[Full sections 4.1–4.10.]
### 5.3 (Optional) Proposal C: [Name]
### 5.4 Comparison Matrix & Recommendation

## 6. Adversarial Audit Summary
[Red-team findings + actions taken + verdict.]

## 7. Open Questions / Missing Inputs
[What the user must supply to firm up the dossier.]

## 8. Sources
[Numbered list of every URL, repo, paper, and doc cited.]
```

## Quality Bar (Self-Check Before Delivery)

Before delivering, confirm every line is true:

- [ ] At least 15 entities surveyed in Phase 1
- [ ] At least 5 deep competitor profiles in Phase 2
- [ ] Each competitor profile cites at least 2 sources
- [ ] Market viability verdict is explicit and justified
- [ ] Every user constraint received an explicit verdict in Phase 3
- [ ] At least 2 strategically distinct proposals in Phase 4
- [ ] Each proposal includes a falsification test
- [ ] Comparison matrix exists and recommends one proposal with reasoning
- [ ] Phase 5 red-team sub-agent was launched and its report integrated
- [ ] Adversarial Audit Summary section is populated
- [ ] Sources section enumerates every cited URL/repo/doc
- [ ] Nothing in the dossier is unsourced speculation presented as fact

If any box is unchecked, the dossier is not ready. Continue working.

## Anti-Patterns to Avoid

- **Single-source-of-truth syndrome**: relying on one analyst article or one HN thread. Every claim needs ≥2 independent sources where feasible.
- **OSS-only blindness**: surveying GitHub but ignoring closed-source incumbents that dominate the market.
- **SaaS-only blindness**: surveying commercial tools but ignoring the OSS substrate that may be a faster path.
- **Feature-list theater**: producing a feature comparison without identifying which features actually drive purchase decisions.
- **Two-proposals-that-are-the-same**: e.g., "React + Postgres" vs "Next.js + Postgres" — these are not strategically distinct. Distinct proposals differ on the *bet*, not the framework.
- **Skipping the red-team**: Phase 5 is mandatory. The dossier is not done without it.
- **Hedging without verdicts**: "it depends" is not an output. State a verdict; preserve alternatives via the comparison matrix.
- **Hallucinated competitors / stats**: never invent a product, fork count, funding round, or pricing tier. If a fact can't be sourced, omit it or label it as needing confirmation.
