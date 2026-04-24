---
title: "feat: learning cockpit global reframe plan"
type: feature
status: reviewed
date: 2026-04-23
origin: User-proposed information architecture rework, 13-inch small-screen optimization, and learning queue requirements, based on the learning cockpit completion process
---

# feat: learning cockpit global reframe plan

## Overview

This round is not about continuing to add scattered features to the current graph page, but about consolidating the existing learning cockpit into a genuinely usable learning workspace.

The current repository already has a batch of reusable foundations:

- `buildLearning()` in `scripts/graph-analysis.js` can already generate `learning.entry`, `learning.views`, `learning.communities`
- `templates/graph-styles/wash/graph-wash-helpers.js` already has `normalizeLearning()`, `resolveInitialMode()`, `getCommunityNodeIds()`, `createSafeStorage()`, `getVisibleLinks()`, `shouldAutoOpenDrawer()`
- `templates/graph-styles/wash/graph-wash.js` already has runtime infrastructure like `setActiveCommunity()`, `setLearningMode()`, `updateVisibleSnapshot()`, `setupSearch()`, `applyMinimapCollapsed()`
- Left navigation skeleton, right drawer, minimap collapsing, and runtime community derivation already have implementation traces

But the current experience still has 5 core problems:

1. The left side looks like a half-finished entry, not a formal functional zone
2. Communities, search, filters, and recommended starting points have not been consolidated into a unified context
3. Insights, legend, and minimap crowd out the canvas, especially uncomfortable on 13-inch screens
4. The three big explanation blocks in the right drawer ("what is this / why look at it now / what to look at next") take up body text space
5. The left-side close button has no real collapse behavior in desktop mode, making users feel "clicked but no response"

Product decisions confirmed in this round:

1. "View all communities" adopts **in-panel expansion on the left**, not a separate overlay
2. The three big explanation sections on the right are **deleted outright**
3. Recommended starting point is **downgraded but retained**, not occupying the main position
4. For the first version of learning notes, **just make it possible to save them**; the left side only shows count or the most recent few

## Goal

Consolidate the page into three layers of main narrative:

- **Left**: learning context — answers "which area am I studying, how do I narrow the scope, what have I saved"
- **Middle**: the visible graph under the current context — answers "what nodes and relationships exist in this area of knowledge"
- **Right**: current node body text and actions — answers "what am I reading now, what can I favorite, what can I note down"

Insights, legend, and minimap on the canvas all step into the background and no longer fight for the homepage narrative.

## Target Information Architecture

### Fixed left-side order

1. **Community categories**
   - Sorted by node count
   - By default only show the Top 3-4 important communities
   - Provide "View all communities" — expands the full list within the left panel, with the left panel scrolling itself
   - When a community is clicked, the middle only shows nodes of that community

2. **Current topic focus**
   - This is a "filter within the current community", not a standalone system
   - First version only has 3 options: `Core nodes only`, `First-hop relations only`, `High confidence only`
   - When no community is selected, it degrades into a global filter

3. **Learning search**
   - Follows the current context by default
   - If a community is selected, search within that community
   - If topic focus is enabled, only search within the currently focused visible nodes
   - A short hint next to the search box indicates the current search scope

4. **Learning queue**
   - First version only has: `Favorites`, `Learning notes`
   - Left side shows count and the most recent few items first; no full notes system

5. **Recommended starting point**
   - Demoted to a bottom auxiliary module
   - Only one recommended starting point under the current context is shown at a time
   - Retained but not occupying the main position

### Right drawer

The right drawer returns to "body-text-first":

- Keep: title, metadata, body, favorite, add to learning notes, adjacent nodes
- Remove: `#dr-learning` and its three big explanation blocks (what is this / why look at it now / what to look at next)
- Adjacent nodes are kept, but collapsed by default

### Canvas secondary information

- **Insights**: retained, but collapsed by default
- **Legend**: no longer always-on screen, changed to collapsed or merged into a help/settings entry
- **Minimap**: collapsed by default, hidden directly at `<1180px`
- **Global return**: retain a clear entry for returning to the global view

## State Model

It is recommended to organize runtime state into 4 layers to avoid continuing to scatter it across various button logics.

### 1. Learning context `state.learning`

Reuse the existing `activeMode` / `activeCommunityId`, and fill in:

- `activeCommunityId`
- `focusMode`, values: `all | core | one_hop | high_confidence`
- `searchQuery`
- `allCommunitiesExpanded`
- `recommendedStartNodeId`

### 2. Visible snapshot `state.visible`

Continue to center on `updateVisibleSnapshot()`, but unify it into a single source of truth:

- `nodeIds`
- `nodes`
- `links`
- `searchIndex`

Recommended computation order:

`Current community scope × current topic focus × search results × edge filtering`

This way, search, minimap, bottom-bar statistics, fit, and drawer sync all look at the same visible snapshot.

### 3. Learning queue `state.queue`

The first version goes directly through browser local persistence:

- `favorites`
- `notes`
- `recentNoteIds`

Persistence reuses `createSafeStorage()`; no new write-back system is introduced.

### 4. Layout state `state.ui`

The existing `navOpen` continues to be retained, and fill in:

- `navCollapsed`
- `drawerOpen`
- `insightsCollapsed`
- `legendCollapsed`
- `minimapCollapsed`

## Key Decisions

1. **Continue to reuse the learning contract, do not redo the upstream data structure.**
   - `buildLearning()` is still the upstream source for recommended starting points, community ranking, and default mode
   - If recommended starting point reasons need to be displayed, prefer to reuse `recommended_start_reason = community_hub` for front-end template mapping

2. **Community switching continues through runtime derivation, do not fall back to primary-only precomputation.**
   - Continue to reuse `getCommunityNodeIds()`
   - Visible node sets for any community are derived at runtime from the current `nodes[].community`

3. **All narrowing logic is unified into the visible snapshot.**
   - Community categories, topic focus, search, and edge filtering must converge into the same `state.visible`
   - Avoid the left side saying community A while search finds community B, or the minimap still showing the full graph

4. **`Path / Community / Global` modes are still retained, but demoted to a secondary entry.**
   - Runtime still retains `activeMode`
   - The entry location no longer competes with the 5-section learning structure on the left for main narrative

5. **Delete the right-side big explanations directly, do not convert them into a second kind of big block.**
   - If learning guidance needs to be supplemented later, only a single-line short hint is allowed; do not restore the three big explanation blocks
   - When deleting, also remove dead drawer contracts, rendering logic, and old tests — do not leave compatibility shells

6. **The desktop-mode close button must have real behavior.**
   - Either the desktop supports collapsing into a narrow rail
   - Or the desktop does not show the close button
   - No longer keep "button is there, but visuals do not change" state

7. **Insights / legend / minimap are merged into a unified secondary entry.**
   - No longer keep three separate always-on blocks that fight for the canvas simultaneously
   - The minimap still retains its own collapse state and `<1180px` hiding rule, but its entry is merged into the same auxiliary information group

8. **localStorage must be isolated by stable wiki namespace.**
   - Can no longer use global keys like `wiki-minimap-collapsed`
   - Namespace needs to be stable and reusable across reloads, avoiding multiple graphs polluting each other

## Phase Roadmap

### Phase 0: Branch and constraints

Before actually modifying code, do two things:

1. Create a new branch from `main`, suggested name `feat/learning-cockpit-reframe`
2. First keep the existing `learning` contract and community runtime derivation route, do not fall back to precomputed primary-only logic

This is a foundational constraint, not a feature batch.

### Phase 1: First consolidate structure, not pile features

**Goal**: Change the page into a "formal learning cockpit" skeleton, while solving the most uncomfortable issues on 13 inches.

**Files:**
- `templates/graph-styles/wash/header.html`
- `templates/graph-styles/wash/graph-wash.js`
- `tests/graph-html-learning-cockpit.regression-1.sh`
- `tests/graph-html-minimap.regression-1.sh`

**Approach:**

1. **Reorganize the left side into a formal functional zone**
   - Within the existing `nav-panel`, reorganize 5 sections:
     - `nav-communities`
     - `nav-focus`
     - `nav-search`
     - `nav-queue`
     - `nav-start`
   - "View all communities" expands within the left panel, no separate overlay

2. **Reduce noise in the top toolbar**
   - Move the main search box from the top toolbar to the left-side learning search
   - The top toolbar only keeps operations directly related to the canvas: return to global, re-layout, center, settings
   - `path/community/global` no longer acts as an equal-level main button fighting for the narrative; internally `activeMode` is still retained

3. **Fix the 13-inch layout**
   - Shrink desktop-mode fixed widths; suggest reducing `--nav-w` from 280 to around 248-260, and `--drawer-w` from 440 to around 360-380
   - No longer rely only on `<1024px` to switch to overlay; add a compact desktop threshold
   - Recommend 3 tiers:
     - `>=1440px` full three-column
     - `1180px-1439px` compact three-column
     - `<1180px` left/right sides switch to overlay

4. **Turn dead buttons into real behaviors**
   - Desktop mode: either the left side supports actually collapsing into a narrow rail, or the close button is not shown
   - Overlay mode: `nav-close` continues as the close button
   - No longer let users see "click with no response" crosses

5. **Demote canvas secondary information**
   - Merge insights, legend, and minimap into a unified secondary entry
   - Collapsed as a whole by default
   - Minimap collapsed by default, and hidden directly at `<1180px`
   - Adjacent nodes collapsed by default

6. **Slim down the right drawer**
   - Delete `#dr-learning`, `#dr-what-body`, `#dr-why-body`, `#dr-next-body`
   - Remove `renderDrawerLearning()` and its call chain
   - Body text, favorite/notes actions, and adjacent nodes remain in the drawer
   - In the same batch, remove the old `drawer.section_order` dependency and corresponding regression assertions

**Verification:**
- First screen finally looks like a formal functional zone
- Body text is readable on 13-inch screens, graph is no longer crushed by floating layers
- Left-side close behavior and responsive logic are unified

### Phase 2: Connect communities, focus, and search

**Goal**: Let the 3 capabilities on the left share the same context, rather than each managing its own.

**Files:**
- `templates/graph-styles/wash/graph-wash.js`
- `templates/graph-styles/wash/graph-wash-helpers.js`
- `tests/js/graph-wash-learning.test.js`
- `tests/js/graph-wash-runtime-state.test.js`

**Approach:**

1. **Community categories continue to reuse runtime derivation**
   - Continue to derive visible node ids for any community via `getCommunityNodeIds()`
   - Do not fall back to the old problem where `learning.views.community.node_ids` only represents primary

2. **Add three filters for "current topic focus"**
   - `Core nodes only`
     - Within the current community, do a lightweight ranking by degree / connection centrality; keep only a few key nodes
   - `First-hop relations only`
     - If there is already a selected node, show "selected node + one-hop neighbors within the community"
     - If no node is selected, fall back to "recommended starting point + one-hop neighbors", reusing existing path logic
   - `High confidence only`
     - Reuse existing edge weights, keep only connections above the threshold and their nodes

3. **Search follows context**
   - Continue to reuse `state.visible.searchIndex` in `setupSearch()`
   - But let the visible snapshot truly contain the final result of "community + focus + search + edge filter"
   - This way, search results, bottom-bar counts, minimap, and fit are all consistent

4. **Keep the "global" entry, but don't let it dominate the narrative**
   - When returning to global, clear the current community highlight
   - Left side still shows the community list and current queue

**Verification:**
- The 3 capabilities on the left become one unified logic
- After the user picks a community, search and focus genuinely "continue narrowing within this area"
- The middle graph, bottom bar, and minimap no longer fight each other

### Phase 3: Learning queue MVP

**Goal**: Turn the learning cockpit from "a tool for viewing the graph" into "a tool that can leave learning traces".

**Files:**
- `templates/graph-styles/wash/header.html`
- `templates/graph-styles/wash/graph-wash.js`
- `templates/graph-styles/wash/graph-wash-helpers.js`
- `tests/js/graph-wash-runtime-state.test.js`

**Approach:**

1. **Favorites**
   - Add a "favorite" action in node details
   - Left-side learning queue shows favorite count and the most recent few nodes

2. **Learning notes**
   - Add an "add to learning notes" action in node details
   - First version only does "can save them"
   - When there is no selected text, by default write node title + summary/body intro into the note
   - When there is selected text, write the selected content into the note
   - Left side only shows count and the most recent few; no full preview editor

3. **Local persistence**
   - All goes through localStorage
   - Key naming isolated by wiki dimension, avoiding multiple graphs polluting each other

**Verification:**
- Users can "save nodes" and "note them down"
- Left-side learning queue becomes a useful module, not decoration

### Phase 4: Downgrade and retain recommended starting point + final verification

**Goal**: Put the recommended starting point in an appropriate position, and do real-sample validation.

**Files:**
- `templates/graph-styles/wash/graph-wash.js`
- `scripts/graph-analysis.js` (only modified if recommendation reasons need enrichment)
- `tests/fixtures/graph-interactive-multicomm/wiki/graph-data.json`
- `CHANGELOG.md`
- `README.md`

**Approach:**

1. **Downgrade and retain recommended starting point**
   - Placed at the bottom of the left side
   - Only show one starting point under the current context at a time
   - If reasons need to be shown, prefer to reuse the existing `recommended_start_reason = community_hub`, do fixed template copy mapping on the front end, do not rush to extend `buildLearning()`

2. **Design Validation**
   - Use 3 real wiki samples to rehearse "first 30 seconds after opening"
   - For each sample, record 4 lines:
     - First community on the left
     - Current recommended starting point
     - Default subgraph in the middle
     - First-screen readability of body text on the right

3. **Documentation and versioning**
   - If the final landing is a functional change, update before push per project rules:
     - `CHANGELOG.md`
     - `README.md` feature list
     - Version number if necessary

## What to Delete vs Collapse vs Keep

### Suggest delete outright
- The three big explanation sections in the right drawer
- The main search box in the top toolbar
- Any residual old learning entry placeholder structures on the left
- `renderDrawerLearning()`, `drawer.section_order` and their old assertions

### Suggest collapsed by default
- The unified secondary entry itself
- Insights inside the unified secondary entry
- Minimap inside the unified secondary entry
- Adjacent nodes
- The full community expansion list (collapsed by default, expands within the left panel on click)

### Suggest keep but demote
- Recommended starting point
- `Path / Community / Global` mode entry
- Insights / legend / minimap inside the unified secondary entry

## Not in Scope

The following are not done this round, to avoid further bloat mid-refactor:

- Do not modify the main structure of the `learning` upstream contract; do not redo a second precomputed schema
- Do not build a full learning notes system; no note editor, rich text, export, cross-device sync
- Do not build new AI-generated recommendation reasons; do not introduce second-stage deep-analysis
- Do not do a real mobile redesign; this round only tightens the layout and overlay behavior from 13 inches to narrow desktop
- Do not migrate to a new graph visual style; continue to keep the existing wash / paper character
- Do not split community, focus, and queue logic into a new state management framework

## What Already Exists

The following already exist in the current repository, and should be directly reused this round, not rebuilt:

- `buildLearning()` in `scripts/graph-analysis.js` can already generate recommended starting points, default mode, and community ranking
- `templates/graph-styles/wash/graph-wash-helpers.js` already has `normalizeLearning()`, `resolveInitialMode()`, `getCommunityNodeIds()`, `getVisibleLinks()`, `createSafeStorage()`, `shouldAutoOpenDrawer()`
- `templates/graph-styles/wash/graph-wash.js` already has infrastructure for learning mode switching, runtime community derivation, `updateVisibleSnapshot()`, search index, minimap collapsing, etc.
- `tests/graph-html-minimap.regression-1.sh` already verifies minimap aria and collapsed state; no need to rewrite as a different test form
- `tests/js/graph-wash-bootstrap.test.js` has already proven that runtime state fragment tests can be done with Node `vm`

## Critical Files

### Must change
- `templates/graph-styles/wash/header.html`
- `templates/graph-styles/wash/graph-wash.js`
- `templates/graph-styles/wash/graph-wash-helpers.js`

### Modify depending on batch
- `scripts/graph-analysis.js`
- `tests/js/graph-wash-learning.test.js`
- `tests/js/graph-wash-runtime-state.test.js`
- `tests/js/graph-wash-bootstrap.test.js`
- `tests/graph-html-learning-cockpit.regression-1.sh`
- `tests/graph-html-minimap.regression-1.sh`
- `tests/regression.sh`

### Samples and golden files
- `tests/fixtures/graph-interactive-multicomm/wiki/graph-data.json`

### Final documentation updates
- `CHANGELOG.md`
- `README.md`
- `TODOS.md`

## Test Review Addendum

The current test situation has one very direct problem: old regressions still treat `dr-learning` as a must-exist structure, and this plan has explicitly decided to delete the whole block. This means tests cannot merely "add new assertions" — they must also clean up old-era expectations.

### Currently covered

- `tests/js/graph-wash-learning.test.js` already covers helper-layer learning defaults, degraded modes, runtime community derivation, visible links filtering
- `tests/js/graph-wash-bootstrap.test.js` already covers bootstrap boundaries when helpers are missing and when `localStorage` getter throws
- `tests/graph-html-minimap.regression-1.sh` already covers minimap static hooks and aria collapsed state

### Current gaps

- No test that `state.visible` truly converges `community × focus × search × edge filter`
- No test for the left-side 5-section structure, full community expansion, or the new DOM shell after demoting mode entries
- No test that the desktop close button actually collapses into a rail, or only appears in overlay mode
- No test for expand/collapse of the unified secondary entry and minimap hiding at `<1180px`
- No test for favorites / learning notes / recent list / persistence across reloads
- No test for localStorage wiki namespace isolation
- The old `graph-html-learning-cockpit.regression-1.sh` still requires `dr-learning`, `dr-what-body`, `dr-why-body`, `dr-next-body` to exist

### Test strategy

1. **Keep helper unit tests, but no longer stuff runtime state interactions into helper tests.**
   - `tests/js/graph-wash-learning.test.js` continues to test pure functions

2. **Add a dedicated runtime state test file.**
   - New file: `tests/js/graph-wash-runtime-state.test.js`
   - Key coverage:
     - Combined narrowing semantics of `updateVisibleSnapshot()`
     - `focusMode` switching
     - Search scope follows the current visible snapshot
     - Queue state write / read
     - Wiki namespace key generation and isolation
     - Desktop nav collapsed state and secondary entry collapsed state

3. **Keep shell regression, but update assertion targets.**
   - `tests/graph-html-learning-cockpit.regression-1.sh` changed to verify:
     - Left-side 5-section formal structure
     - Mode entry still exists but is no longer a top-level main narrative block
     - Old `dr-learning`-related DOM has disappeared
     - New secondary entry shell exists
   - `tests/graph-html-minimap.regression-1.sh` is kept; focus on verifying minimap behavior has not regressed

4. **Hook entry-level verification back into the main regression.**
   - `tests/regression.sh` continues to chain:
     - shell regression
     - helper test
     - bootstrap test
     - the new runtime-state test

### Pass criteria

- After deleting `dr-learning`, all old assertions are synchronously replaced; not allowed to pass tests via a compatibility empty shell
- `state.visible` must have at least one combined test proving community / focus / search / edge filter do not fight each other
- Queue must have at least one persistence test proving favorites / notes do not cross-contaminate between wikis
- Secondary entry and desktop nav collapse must have runtime behavior assertions, not just grep of static HTML

## Performance Review Addendum

The performance focus of this round of rework is not "benchmarks", but not turning an otherwise usable graph page into something that lags every time focus is switched.

### Main pressure points

1. **Once the visible snapshot becomes the single source of truth, computation frequency rises.**
   - Community switching, focus switching, search input, edge filter switching all trigger `updateVisibleSnapshot()`

2. **Search will narrow with the current context.**
   - If every input rescans all nodes + all edges, the first thing to feel slow on a 13-inch device is input feedback, not D3

3. **If the unified secondary entry makes all three panels permanently resident in the DOM and only hides them visually, the benefit shrinks.**
   - What really affects experience is layout occupation and repeated rendering, not changing names

4. **Dual desktop rail / overlay modes amplify layout thrash risk.**
   - If every toggle triggers grid reflow, drawer recompute, and minimap redraw at the same time, the page will jitter

### Control principles

1. **Filter node ids first, then derive nodes / links / searchIndex.**
   - Do not rebuild complete object arrays at every step

2. **Search only matches against the current `state.visible.searchIndex`.**
   - Do not fall back to the full `state.searchIndex` unless the visible snapshot is empty and this is an explicit design

3. **High-confidence filter and one-hop filter continue via lightweight runtime derivation.**
   - First version does not introduce new precomputation; no complex centrality algorithms
   - Core nodes prefer to reuse cheap metrics like existing degree / link count

4. **Secondary entry collapsed by default; do no meaningless rendering when closed.**
   - At minimum, avoid continuously updating minimap and insights DOM while hidden

5. **Treat the 13-inch scenario as the main constraint, not an edge case.**
   - The compact three-column at `1180px-1439px` is the real tier to polish this round
   - At `<1180px` switch directly to overlay; more stable than forcing three columns on narrow desktops

### Performance acceptance points

- During search input, result panel response should not be noticeably slower than the current version
- After community / focus / high-confidence switching, bottom-bar stats, minimap, and canvas visible subgraph keep the same semantics; no "one updates while another does not"
- When the desktop-mode nav collapses / expands, body text first screen and canvas do not flash noticeably
- When the unified secondary entry is closed, it should no longer occupy visible body text width

## Failure Modes

1. **Left side shows "current community" but search results escape the current community.**
   - Cause: search did not go through `state.visible.searchIndex`
   - Control: Converge context into `updateVisibleSnapshot()` first, then generate searchIndex

2. **After deleting the right-side learning explanations, old contract and tests remain.**
   - Cause: Only deleted DOM, did not delete `renderDrawerLearning()`, `drawer.section_order`, old regression assertions
   - Control: In the same batch, delete code, delete contract, update tests

3. **Desktop close button still "clicked with no response".**
   - Cause: Only overlay logic retained, no desktop rail or show/hide strategy
   - Control: Define real `navCollapsed` behavior for desktop mode, or do not show close on desktop

4. **Multiple wikis share one set of localStorage keys, polluting each other's collapse and queue state.**
   - Cause: Continuing to use global keys like `wiki-*`
   - Control: First define a stable namespace, then uniformly encapsulate key generation

5. **The secondary entry is merged in name only; in practice it is still three independent blocks fighting for screen.**
   - Cause: Only moved positions, no unified entry and default-collapsed strategy
   - Control: Unify at the entry level, default to closed, closed state does not occupy main layout width

## Parallel Worktree Lanes

If parallel progress is needed, at most split into 3 lanes in implementation; do not split into a bunch of small branches that fight each other.

1. **Lane A — Structure and layout**
   - `header.html`
   - Parts of `graph-wash.js` related to nav / drawer / secondary entry / rail / overlay

2. **Lane B — Context and state**
   - Parts of `graph-wash.js` related to visible snapshot / focus / search / queue / namespace
   - Necessary lightweight helpers in `graph-wash-helpers.js`

3. **Lane C — Tests and documentation**
   - shell regression
   - `node:test` runtime state tests
   - `TODOS.md`, `README.md`, `CHANGELOG.md`

Constraints:
- Lane A first nails down DOM ids and state names; Lane B then wires state semantics, otherwise tests will be reworked repeatedly
- Lane C must not hard-code the old DOM; wait until the Phase 1 shell is stable before filling in final assertions

## Verification

### Code level
- `node --test tests/js/graph-wash-learning.test.js`
- `node --test tests/js/graph-wash-bootstrap.test.js`
- `node --test tests/js/graph-wash-runtime-state.test.js`
- All affected graph HTML regression scripts pass
- Continue to run `tests/regression.sh`

### Interaction level
- Generate / open the actual graph page, manually verify:
  1. Select a community
  2. Switch "current topic focus"
  3. Search within the current context
  4. Open node details
  5. Favorite
  6. Add to learning notes
  7. Expand / collapse all communities
  8. Collapse / expand the unified secondary entry, minimap, adjacent nodes
  9. Collapse / expand the left-side navigation in desktop mode
- Verify at least 3 width tiers: `>=1440`, around `1280`, `<1180`
- Focus on 13-inch laptop scenarios: do body text first screen, graph canvas, left nav, and right drawer still crowd each other

### Pre-push project rules
Before every actual `git push`, execute per repo rules:
- `bash install.sh --dry-run --platform codex`
- Run affected fixtures / regression
- `grep -r '/Users/kangjiaqi\|康佳琦' scripts/ templates/ tests/ SKILL.md`
- Update `CHANGELOG.md` / `README.md` / version number (if it is a feat/fix)

## Risks

1. **Risk: Continuing to compute "community / focus / search / edge filter" separately**
   - Control: All narrowing logic unified into `updateVisibleSnapshot()`

2. **Risk: Expanding a heavy new precomputation just to do "current topic focus"**
   - Control: First version reuses existing degree, edge weight, community, path logic as much as possible; go with lightweight runtime derivation first

3. **Risk: More information on the left side actually makes it more crowded**
   - Control: Left panel keeps only 5 sections, recommended starting point demoted, all communities collapsed by default, queue does a lightweight version first

4. **Risk: After deleting the right-drawer big explanations, there is no learning guidance at all**
   - Control: Later, if needed, only add a single-line short hint; do not restore the big explanation blocks
