---
title: feat: Learning cockpit for wash graph
type: feature
status: approved
date: 2026-04-23
origin: 2026-04-23 in-session design review and implementation planning
deepened: 2026-04-23
---

# feat: Learning cockpit for wash graph

## Overview

The goal of this change is not to add another left column to the existing graph page, but to change the first-minute narrative of the home page from "viewing the graph" to "start learning".

The existing wash page already has stable graph rendering, search, filtering, Insights, minimap, and the right-side drawer, but by default it still looks more like a "graph viewer":

- Does not proactively tell the user where to start
- Cannot reliably explain "why look at this first"
- Default state still puts the global graph and existing tool capabilities at the center of the home narrative

The goal of this round, while preserving the main structure of "center graph + right-side drawer", is to upgrade it into a **learning cockpit**:

- Home page first shows the recommended starting point and the currently most important community
- The center shows a local learning subgraph by default, rather than the full large graph
- The right-side drawer first answers "what this is / why look at it now / what to look at next"

## Problem Frame

The existing implementation already solves "the graph can be generated, viewed, searched, and expanded", but has not yet solved "user doesn't get lost on first open".

Looking at the existing skeleton:

- `templates/graph-styles/wash/header.html` already has a stable `.app` two-column layout and a mature right-side drawer
- `templates/graph-styles/wash/graph-wash.js` already has complete node selection, highlighting, drawer opening, search, filters, Insights, minimap, and Tweaks
- `scripts/build-graph-data.sh` + `scripts/graph-analysis.js` already precompute communities, edge weights, and insights

So what's really missing this round is not a new rendering engine but a clear **default entry protocol**:

1. What the user should see first after opening the page
2. Which community, node, and view to focus on by default
3. How the right-side drawer translates node clicks into learning actions
4. How to degrade when graph scale, community quality, or path generation is insufficient

## Requirements Trace

- R1. Default first-screen enters the learning entry, no longer using the full graph directly as the default narrative.
- R2. V1 must support explicit mode switching between `path / community / global`.
- R3. Default recommended starting point, current most important community, and degradation rules must go through precomputation, not front-end on-the-fly computation.
- R4. The right-side drawer must reliably display the three learning sections "what this is / why look now / what's next".
- R5. This round cannot split the existing wash graph into a second system; all learning entries must reuse the existing graph runtime main pipeline.
- R6. Existing graph-data, HTML shell, and JS bootstrap regressions must continue to be stable; the home narrative redesign cannot break existing functional regressions.

## Scope Boundaries

- Do not rewrite the graph renderer; do not replace the existing d3/rough/marked/purify tech stack.
- Do not change the page to a new three-column main layout; preserve the `.app` two-column structure.
- Do not recompute communities, paths, or learning recommendation rules on the front end.
- Do not introduce a reducer or new state management framework; first version uses explicit state.
- Do not bundle share / export / screenshot propagation capabilities into the same round.
- Do not do real-time LLM explanation generation; learning explanations use rules and templates first.
- Do not handle follow-up enhancements like search upgrade, dark mode, true responsive reflow in this round.

## Context & Research

### Relevant code and patterns

- `templates/graph-styles/wash/header.html`
  - `:132-149` top-level `.app` is currently a two-column grid of main area + drawer
  - `:1210-1254` `tools` area already has search / filters / fit / refit / tweaks
  - `:1256-1299` `canvas-wrap` already hosts overlays like Insights, minimap, legend, toast, loading
  - `:1312-1334` right-side drawer DOM skeleton is mature

- `templates/graph-styles/wash/graph-wash.js`
  - `:31-52` current state only has graph/runtime base state, no learning mode state
  - `:895-1000` `selectNode()` / `openDetailDrawer()` is the existing "select node + open drawer" main pipeline
  - `:1025-1030` `focusNode()` already unifies "select + open + center" into one entry point
  - `:1032-1116` `renderInsights()` is suitable as the host for the learning entry panel
  - `:1430-1442` boot flow is stable, but currently doesn't auto-select the learning entry by default

- `scripts/build-graph-data.sh`
  - `:304-328` currently outputs `meta / nodes / edges / insights`
  - `:274-295` already has `meta.initial_view`, which can serve as a simplified global view base

- `scripts/graph-analysis.js`
  - `:103-149` already has edge weight calculation
  - `:282-359` already has Louvain community partitioning and label selection
  - `:361-495` already has basic insight generation
  - `:497-547` `analyzeGraph()` is the suitable entry point for adding `learning` precomputation

### Test surface

- `tests/regression.sh:1293-1584`
  - Already covers graph-data golden, graph html assembly, build failure, drawer/search/minimap/insights/a11y/mobile, etc.
- `tests/js/graph-wash-bootstrap.test.js`
  - Already covers bootstrap fault tolerance like missing helpers, localStorage throwing
- `tests/graph-html-insights.regression-1.sh`
  - Currently specifically protects `insights-panel` shell and weighted neighbor hooks

### Institutional learnings

- `docs/solutions/ui-bugs/graph-wash-null-safety-and-label-truncation-fix-2026-04-21.md`
  - When adding optional DOM / collapsed state, add Node runtime assertions, don't rely only on grep to check string existence
- `docs/solutions/developer-experience/graph-style-simplification-to-wash-only-2026-04-20.md`
  - When refactoring graph shell, regressions should be updated to new boundaries, but don't keep protecting old implementation details that no longer matter

## Key Technical Decisions

- Learning metadata must go through precomputation, and a new top-level `learning` contract is added.
  - Reason: Recommended starting point, community strength, mode degradation, and drawer learning explanation order are all default protocols and shouldn't be derived on the front end at runtime.

- Only add to, don't modify existing `meta / nodes / edges / insights`.
  - Reason: Existing graph-data golden and HTML build depend on these fields; adding a top-level `learning` has the smallest blast radius.

- Home learning entry reuses the existing `insights-panel` shell as a priority, rather than opening a third main column.
  - Reason: The current `.app` two-column layout and right-side drawer are stable; what really needs rearranging is the information hierarchy inside `canvas-wrap`, not the whole page skeleton.

- All learning entries must converge into the existing `selectNode()` / `openDetailDrawer()` / `focusNode()` main pipeline.
  - Reason: This avoids making the learning cockpit into a second system, reducing left-right desync and test multiplication issues.

- The first version only adds explicit state expansion, no reducer.
  - Reason: The new state can still be clearly written as explicit fields and small functions; introducing a reducer too early would just tie home narrative refactoring with state architecture upgrade.

- The path view in V1 is fixed as "recommended-starting-point-driven, constrained learning subgraph".
  - Reason: This constrains scope, avoiding inflating path semantics into a mix of shortest path, tutorial chapters, personalized recommendations, etc.

- `path / community / global` must drive **true subgraph mode**, not just weak highlighting on the global graph.
  - Reason: The product goal of this round is to make the home's first glance become "start learning", not to keep having users pressed down by the whole large graph.

- `activeMode` must be the single source of truth for the current front-end mode; panel active state no longer stores a second copy.
  - Reason: The same page shouldn't maintain both `activeMode + panelTab`, otherwise button highlight and actual subgraph can easily drift apart.

- In subgraph mode, search / fit / minimap / footer must share the same visible snapshot.
  - Reason: If only the canvas hides nodes while peripheral capabilities still work against the full graph, page semantics become "looks like a subgraph, actually still the full graph".

- Mode switching by default only updates the visible snapshot and centering, does not restart force-directed simulation.
  - Reason: The learning cockpit is more like a viewpoint switch on the same graph, shouldn't feel like re-laying out a new graph each time a mode button is pressed.

## Open Questions

### Resolved during planning

- Should this round make the learning entry a new left-side main column?
  - Conclusion: No. Preserve the `.app` two-column layout and prioritize rearranging the first-screen narrative inside `canvas-wrap`.

- Should learning metadata be computed on the front end at runtime?
  - Conclusion: No. Community strength, recommended starting point, default mode, and degradation rules all go through precomputation.

- Should the right-side drawer get a new learning drawer?
  - Conclusion: No. Reuse the existing drawer, only upgrade content order.

- Should the first version use a reducer?
  - Conclusion: No. Use explicit state with clear upgrade thresholds first.

### Deferred to implementation

- Whether to add `nodes[].learning` per-node teaching metadata granularity in the first version.
  - Current recommendation: skip for now; first establish the top-level default entry protocol.

- Whether the learning entry panel should keep a small "secondary insight" area, or have Insights fully demoted to a secondary entry.
  - Current recommendation: keep, but no longer occupy the home's main narrative position.

## High-level technical design

### Recommended contract shape

Add `learning` at the top level of `graph-data.json`:

```json
"learning": {
  "version": 1,
  "entry": {
    "recommended_start_node_id": "Transformer",
    "recommended_start_reason": "community_hub",
    "default_mode": "path"
  },
  "views": {
    "path": {
      "enabled": true,
      "start_node_id": "Transformer",
      "node_ids": ["Transformer", "Attention", "Encoder"],
      "degraded": false
    },
    "community": {
      "enabled": true,
      "community_id": "arch",
      "label": "深度学习架构",
      "node_ids": ["Transformer", "Encoder", "Decoder", "arch"],
      "is_weak": false,
      "degraded": false
    },
    "global": {
      "enabled": true,
      "node_ids": ["Attention", "Transformer", "GPT"],
      "degraded": false
    }
  },
  "communities": [
    {
      "id": "arch",
      "label": "深度学习架构",
      "node_count": 4,
      "source_count": 0,
      "internal_edge_weight": 2.8,
      "is_primary": true,
      "is_weak": false,
      "recommended_start_node_id": "Transformer"
    }
  ],
  "drawer": {
    "section_order": [
      "what_this_is",
      "why_now",
      "next_steps",
      "raw_content",
      "neighbors"
    ]
  },
  "degraded": {
    "path_to_community": false,
    "community_to_global": false
  }
}
```

### Minimal front-end state extension

Minimum extension on the existing `state`:

```js
state.learning = {
  data: normalizeLearning(DATA.learning || defaultLearning()),
  activeMode: null,
  activeCommunityId: null,
  recommendedStartNodeId: null,
  pathDegraded: false,
  communityDegraded: false
};

state.visible = {
  nodeIds: new Set(),
  nodes: [],
  links: [],
  searchIndex: []
};

state.ui = {
  bootstrappedEntry: false
};
```

Constraints:

- `state.learning.activeMode` is the single source of truth for the current mode; no separate `panelTab` maintained
- `state.visible` is the shared snapshot in subgraph mode; search / fit / minimap / footer all consume it
- Pure learning logic goes into `graph-wash-helpers.js` first, e.g.: `defaultLearning()`, `normalizeLearning()`, `resolveInitialMode()`, `getVisibleNodeIds()`, `getVisibleLinks()`, `shouldAutoOpenDrawer()`

### Event flow

- After boot, execute `bootstrapLearningEntry()`:
  - path available → enter `path` and focus on recommended starting point
  - path unavailable → `community`
  - community too weak / no available community → `global`
- On path failure, fixed degradation to `community`; no second degradation semantics like `start-only`
- Panel switch mode: updates `activeMode`, visible snapshot, panel active state, and drawer context
- Click node on graph: keep current mode, only refresh `selected` and drawer
- Next step within drawer: continues to reuse `selectNode()` + zoom translate
- Only `path` mode auto-opens the drawer by default; `community / global` don't force open by default

## Implementation units

- [ ] **Unit 1: Precompute learning metadata contract**

**Goal:** Provide stable learning entry input to wash graph, rather than letting the front end derive it at runtime.

**Requirements:** R1, R2, R3, R6

**Dependencies:** None

**Files:**
- Modify: `scripts/graph-analysis.js`
- Modify: `scripts/build-graph-data.sh`
- Modify: `tests/expected/graph-data-sample.json`
- Modify: `tests/expected/graph-data-empty.json`
- Test: `tests/regression.sh`

**Approach:**
- Add `learning` at the top level of `analyzeGraph()` output
- Reuse existing community partitioning, edge weights, `initial_view`, and `insights` as learning generation input
- Fix recommended starting point, current most important community, three mode entries, drawer section order, and degradation flags
- Keep existing fields unchanged; `empty wiki` also outputs a stable empty `learning`

**Verification:**
- sample / empty graph-data golden passes stably after update
- test mode produces exactly the same output twice
- Existing community clustering and confidence type regressions don't regress

- [ ] **Unit 2: Change wash home page to learning-entry-first**

**Goal:** Make the first screen show the learning entry first, rather than using generic insights and the global graph as the default narrative.

**Requirements:** R1, R2, R4, R5

**Dependencies:** Unit 1

**Files:**
- Modify: `templates/graph-styles/wash/header.html`
- Test: `tests/graph-html-insights.regression-1.sh`
- Test: `tests/graph-html-toolbar.regression-1.sh`
- Test: `tests/graph-html-search.regression-1.sh`
- Test: `tests/graph-html-a11y.regression-1.sh`

**Approach:**
- Preserve `.app` two-column layout and existing drawer
- Reuse `insights-panel` as the host for the learning entry panel
- Add explicit `path / community / global` mode switch in the `tools` area
- Change the right-side drawer content order to "what this is / why look now / what's next / raw content / neighbor nodes"

**Verification:**
- graph HTML shell regression passes after update
- Critical DOM hooks still exist, don't rewrite all existing tests from scratch

- [ ] **Unit 3: Wire up learning mode state and default entry pipeline**

**Goal:** Use minimal state expansion to support automatic default entry, three mode switching, and left-center-right linkage.

**Requirements:** R1, R2, R4, R5

**Dependencies:** Unit 1, Unit 2

**Files:**
- Modify: `templates/graph-styles/wash/graph-wash.js`
- Optional: `templates/graph-styles/wash/graph-wash-helpers.js`
- Test: `tests/js/graph-wash-bootstrap.test.js`
- Optional test: new JS test for learning state/fallback logic

**Approach:**
- Add three small blocks of explicit state to the existing state: `learning`, `visible`, and `ui`, but keep `learning.activeMode` as the single source of truth for the current mode
- Pull default mode selection, degradation rules, visible set calculation, and drawer default-open rules into `graph-wash-helpers.js` first
- Add `defaultLearning()`, `normalizeLearning()`, `hydrateLearningState()`, `bootstrapLearningEntry()`, `setLearningMode()`, `renderLearningPanel()`, `renderDrawerLearningSection()`
- All learning entries ultimately reuse `selectNode()` / `openDetailDrawer()` / `focusNode()`
- Don't recompute path/community strength on the front end; only apply precomputed results
- Mode switching by default only updates visible snapshot and centering, doesn't restart simulation; the explicit "relayout" button continues to handle restart

**Verification:**
- No white screen when `DATA.learning` is missing
- Boot enters the recommended starting point by default
- Path failure fixed degrade to `community`; weak community fixed degrade to `global`
- Only `path` mode auto-opens the drawer by default
- Mode switching and node clicks don't mess up panel / graph / drawer
- search / fit / minimap / footer stay consistent with visible snapshot in subgraph mode

- [ ] **Unit 4: Round out learning cockpit regressions and degradation protection**

**Goal:** Close this round of changes from "works" to "won't break the existing wash graph".

**Requirements:** R6

**Dependencies:** Unit 1, Unit 2, Unit 3

**Files:**
- Modify: `tests/regression.sh`
- Modify: `tests/graph-html-insights.regression-1.sh`
- Modify: `tests/js/graph-wash-bootstrap.test.js`
- Add: `tests/js/graph-wash-learning.test.js`
- Add: `tests/graph-html-learning-cockpit.regression-1.sh`
- Optional: add runtime assertion coverage for visible snapshot consumers

**Approach:**
- First lock data contract, then lock HTML shell, then add bootstrap / fallback / visible snapshot unit tests, and finally do runtime regression
- For newly added interactive state, prioritize adding Node `vm` assertions rather than relying only on grep
- Add dedicated learning pure logic unit tests, avoiding stuffing all rules into bootstrap test
- Add learning cockpit dedicated HTML regression, locking learning panel shell, mode switch hooks, and drawer learning section order
- Focus on the initial `drawer-open` / `aria-hidden` / fit / search / minimap / footer behavior after auto-default selection

**Verification:**
- `bash tests/regression.sh` all green
- graph HTML independent regression all green
- `graph-wash-bootstrap` and `graph-wash-learning` unit tests all green
- search / fit / minimap / footer stay consistent with visible snapshot in subgraph mode
- Manually open the generated `wiki/knowledge-graph.html`, verify default entry, mode switching, drawer learning explanation, and degradation paths

## Risks and failure modes

- **Turning into a second system**: panel click, graph click, drawer click each maintain their own state, ultimately causing left-right desync.
- **Recomputing learning rules on the front end**: community strength and default entry are re-derived in the browser, drifting from precomputed results.
- **Top-level layout changes too big**: Changing `.app` to a three-column main layout, causing drawer/mobile/search/a11y regressions to blow up together.
- **Path semantics drift**: Sometimes learning sequence, sometimes shortest path, sometimes recommendation chain, causing implementation and tests to be unclosable.
- **Auto default selection side effects**: Old default state changes from "no selected node" to "default select recommended starting point", easily affecting fit, search, minimap, drawer initial behavior.
- **Contract inflation too fast**: First version stuffs node-level teaching metadata, path copy, personalization logic all into `learning`, causing golden and front/back boundaries to become unstable together.

## Testing strategy

Recommend verifying in the following order:

1. **data contract**
   - Update and pass sample / empty graph-data golden
   - Ensure test mode is stable

2. **HTML shell**
   - Update `graph-html-*` regressions, confirming learning entry shell, toolbar, search, drawer, a11y hooks are still stable

3. **runtime / bootstrap**
   - Add `graph-wash-bootstrap` related JS unit tests
   - Cover missing learning, path/community/global degradation, auto-default entering recommended starting point

4. **manual verification**
   - Run `bash scripts/build-graph-data.sh <wiki_root>`
   - Run `bash scripts/build-graph-html.sh <wiki_root>`
   - Open `wiki/knowledge-graph.html`, verify recommended starting point, mode switching, drawer learning explanation, and degradation paths

## Suggested execution order

Recommend implementing along 3 commit boundaries for easier review:

1. `graph-data contract + golden`
2. `HTML shell + runtime wiring`
3. `tests + fallback hardening`

Implementation constraints:

- Unit 1 first lands the `learning` contract and locks sample / empty golden
- Unit 2 and Unit 3 run sequentially, no parallel worktree split; both rewrite `templates/graph-styles/wash/`
- Unit 3 introduces visible snapshot at the same time; don't do "fake subgraph mode" first and then go back to fix peripheral sync
- Unit 4 finally rounds out dedicated learning tests, learning cockpit HTML regression, and visible snapshot consistency assertions

This separates "what the data layer decides" from "how the UI consumes the data" so they can be reviewed separately, avoiding mixing contract, layout, state, and tests into one un-reviewable large diff.
