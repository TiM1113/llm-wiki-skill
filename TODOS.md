# TODOs

## Learning Cockpit (Core Skeleton)

**Completed:** v3.1.0 (2026-04-23)

1. **Pre-compute learning metadata contract** — DONE
2. **Change wash homepage to learning-entry-first** — DONE
3. **Wire up runtime learning state and right-side learning explanation** — DONE
4. **Add learning cockpit regression tests** — DONE

> Design doc: `~/.gstack/projects/sdyckjq-lab-llm-wiki-skill/kangjiaqi-main-design-20260423-084646.md`
> Implementation plan: `docs/plans/2026-04-23-learning-cockpit-implementation-plan.md`
> Branch: `feat/learning-cockpit` (first 4 items merged, not yet pushed/PR'd)

## Learning Cockpit Completion (A-C Done)

**Completed:** v3.2.0 (2026-04-23)
**Branch:** `feat/learning-cockpit-left-nav`

1. **Left-side community navigation panel** — DONE
2. **Community leaderboard showing top 3 communities** — DONE
3. **Click community triggers left-center-right linkage** — DONE

4. **Information hierarchy re-arrangement**
   - Search/filter/Insights/minimap retained but collapsed by default
   - These secondary capabilities no longer compete for homepage learning narrative

5. **Recommended starting points with rationale**
   - Each recommended starting point includes a fixed template rationale (e.g., "The entry node with the most connections within the community")

6. **Design Validation**
   - Find 3 real wiki samples, evaluate under "a first-time visitor only looks for 30 seconds" criteria
   - For each sample write 4 lines: left-side first community / recommended starting point / center default subgraph / right-side recommendation rationale
   - Execute after feature completion, before push

## After Multi-Platform Adaptation

- Fix Chinese character garbling on Windows / PowerShell (#16); at minimum clarify support boundaries for PowerShell 5.1 / 7, and add installation and usage guidance.
- Plan the internalization order for source extraction capabilities; evaluate web, PDF, local files, YouTube first, then evaluate high-volatility sources like X.
- Evaluate whether OpenClaw needs workspace-skill fallback instead of only supporting shared skill paths.
- Evaluate whether the installer should be split into more formal `doctor` / `migrate` / `uninstall` subcommands.
- Evaluate an adapter layer template for the fourth platform integration, ensuring it doesn't regress to "copying a full set of core logic."

## Phase B - Core Mainline and Adapter Separation (Completed)

- Froze unified source entry and single source registry
- Clarified adapter failure states and unified fallback paths
- Locked down legacy wiki compatibility and migration rules
- Aligned installation, status, documentation, and regression tests

## Introducing JS Unit Test Framework (Completed)

- **Completed:** v3.0.6 (2026-04-22)
- **Decision**: Use `node:test`, zero additional dependencies, directly reuse the project's existing Node runtime.
- **Delivered**: Added `templates/graph-styles/wash/graph-wash-helpers.js` and `tests/js/graph-wash-helpers.test.js`, covering `truncateLabel`, `createSafeStorage`, `cardDims`, and underlying grapheme cluster/width helpers.
- **Result**: Pure function boundary behavior no longer relies solely on shell + HTML regression for indirect coverage; `tests/regression.sh` now also includes this JS unit test.

## Phase 1b - Interactive Graph Advanced Features (Evaluate after Phase 1 lands)

- **What** (3 items originally listed from Phase 1 eng review): Add AI implicit relationship inference, graph health summary (isolated nodes / largest connected component / fragile bridges), and edge confidence-level coloring to the landed interactive graph.
- **What (5 items added from 2026-04-17 design review)**:
  1. Search upgrade: fuzzy matching + cross-language Chinese-English aliases (Phase 1 only did prefix + case-insensitive)
  2. Dark mode: `prefers-color-scheme` auto-switch; node palette and edge opacity need re-tuning
  3. Design system extraction: Extract Pass 4 CSS variable block from graph-template to `templates/design-tokens.css`, write formal `DESIGN.md` at repo root
  4. True responsiveness: Replace Phase 1's MOBILE opt-out overlay with `< 768px` single-column stack + touch gesture pan/zoom
  5. Graph evolution metrics (5-year view): Compare node degree changes, new communities, new isolated nodes vs last graph; write to `wiki/graph-history/{date}.json`
- **Why**: Phase 1 MVP first validates whether anyone uses the local HTML graph, avoiding swallowing all token costs and maintenance burden at once. All 8 items above are "one tier up from screenshot-worthy."
- **Pros**: Makes the graph closer to llm-wiki-agent's capability coverage; health summary provides quantifiable quality signals; search and responsiveness cover more use cases; evolution metrics let users see "how my knowledge shape changes."
- **Cons**: AI inference reads all entity pages per graph run, noticeable token consumption at 100+ nodes; dark mode requires dual CSS; evolution metrics require history data directories and comparison logic.
- **Context**: Phase 1 (2026-04-17 design doc approved, including Eng Review Addenda + Design Review Addenda) only reuses confidence data from existing ingest, does not re-invoke AI.
- **Depends on / blocked by**: Phase 1 (interactive graph MVP) lands and has at least one real user feedback.

## Graph 2.0 deferred follow-ups

- **What**: Add a second-stage deep-analysis to the graph workflow, reading candidate edges then performing LLM semantic analysis, stably writing results to `insights.llm_surprises`.
- **Why**: Current stage can only use formulas and rules to view graphs, unable to surface "looks unrelated but semantically worth exploring" insights.
- **Pros**: Truly leverages the agent skill advantage, forming the most differentiated capability vs competitors.
- **Cons**: Requires prompt design, failure paths, result merging, and cost control; cannot be mixed into the current main implementation.
- **Context**: This `/plan-eng-review` explicitly removed deep-analysis from graph 2.0 first-stage delivery, preventing the most unstable model orchestration from being tied into the main implementation; safer to enter second stage after completing source contracts, weights, Louvain, and Insights mainline.
- **Depends on / blocked by**: Complete the current round's source contracts, weights, Louvain, Insights mainline, and verify `graph-data.json`'s new structure is stable.

- ~~**What**: Add "pages missing `sources` prompt" in lint / status workflows, identifying which legacy pages currently don't participate in source signal computation.~~
- **Completed:** v3.0.5 (2026-04-22) — `feat/source-signal-coverage` branch landed

## Review follow-ups

### Edge-level same-source summary

**What:** Add a separate status/lint follow-up that reports how many graph edges actually used the same-source overlap signal, rather than only which pages were eligible.

**Why:** Page eligibility answers "which pages can participate," but it does not answer whether the edge-level source overlap signal is doing useful work in real graph output.

**Context:** The 2026-04-22 `/plan-eng-review` reduced Batch 1 to page-level eligibility coverage only. Outside voice review flagged that "coverage summary" and "same-source signal summary" are different questions. This follow-up should stay separate from the first batch so the current change stays honest and small.

**Effort:** M
**Priority:** P2
**Depends on:** Shared eligibility/coverage landing first

### Document source-signal applicable page types

**What:** Write down the canonical rule for which page types are applicable vs not_applicable for source-signal, including exclusions like query pages and any synthesis subdirectories that should never count.

**Why:** Without an explicit project-level rule, future work can silently drift and re-include derived pages, which would pollute the evidence-quality meaning of source overlap.

**Context:** The 2026-04-22 `/plan-eng-review` changed `query` from applicable to not_applicable after outside voice review pointed out that query pages are derived content (`derived: true`) and are treated as secondary sources in `SKILL.md`. The same review also flagged that recursive synthesis scanning needs a clearly documented boundary.

**Effort:** S
**Priority:** P1
**Depends on:** Final first-batch implementation rules being settled

### Deconflict graph node IDs across page types

**What:** Define and implement a strategy so graph node IDs cannot silently collide when different page types share the same filename.

**Why:** Today the graph uses basename-derived IDs, so `entities/Foo.md` and `topics/Foo.md` would collide and make both graph output and any eligibility coverage misleading.

**Context:** The 2026-04-22 outside voice review flagged this as an existing structural risk in `build-graph-data.sh` and `graph-analysis.js`. It is not part of the first batch because that batch is intentionally limited to source-signal eligibility coverage and lint/status explanation.

**Effort:** M
**Priority:** P2
**Depends on:** None
