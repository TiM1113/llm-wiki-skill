---
title: "feat: learning cockpit left-side community navigation and linkage"
type: feature
status: draft
date: 2026-04-23
origin: TODOS.md learning cockpit completion items A-C
---

# feat: Learning Cockpit Left-Side Community Navigation and Linkage

## Overview

The learning cockpit core skeleton has landed (`feat/learning-cockpit`), with three-mode switching, subgraph rendering, right-side learning explanations, and degradation chains all working. However, when users open the page, there is still no clear navigation entry point for "where to start learning."

What this round does is replace the simplified learning entry in the current `insights-panel` with an independent **left-side community navigation panel**, and wire up left-center-right linkage.

## Scope

- **A. Left-side community navigation panel**: community leaderboard (name, node count, source count) + recommended starting point list
- **B. Community leaderboard showing top 3 communities**: multi-community list, without over-asserting
- **C. Clicking a community triggers left-center-right linkage**: complete linkage for 6 trigger actions

Not in this round:
- Information hierarchy rearrangement (item D, search/filter/Insights default collapsed)
- Recommended starting points with reasons (item E)
- Design Validation (item F, verify after feature is complete)

## Current State

### Layout

`header.html:132-149` `.app` grid:

```
grid-template-areas:
  "brand   drawer"
  "tools   drawer"
  "canvas  drawer"
  "footer  drawer";
grid-template-columns: 1fr 0fr;  /* 1fr var(--drawer-w) when drawer-open */
```

Two columns: left side is brand + tools + canvas + footer, right side is drawer. No left-side navigation area.

### Learning Entry

`graph-wash.js:1104-1182` `renderLearningPanel()` stuffs the learning entry into `insights-panel` (`#learning-body`). It only shows in path/community mode, displaying recommended starting points and brief information about the current community.

### Data

`graph-data.json`'s `learning` contract already stably provides:

- `learning.communities[]`: each community has `id`, `label`, `node_count`, `source_count`, `is_primary`, `is_weak`, `recommended_start_node_id`
- `learning.views.path/community/global`: each mode has `node_ids`, `start_node_id`, `community_id`
- `learning.entry`: `recommended_start_node_id`, `default_mode`

This data is sufficient to support the left-side community navigation panel, no new pre-computed fields needed.

### State

`graph-wash.js:52-68` state already has `learning.activeMode`, `learning.activeCommunityId`, `learning.data`. The infrastructure needed for linkage — mode switching, community switching, visible snapshot — is already in place (`setLearningMode()`, `updateVisibleSnapshot()`, `applySubgraph()`).

## Key Decisions

1. **Layout approach: add a `nav` column to the `.app` grid, changing to a three-column layout.**

   Not placing left-side navigation inside `canvas-wrap`, because:
   - `canvas-wrap` already contains SVG, insights-panel, legend, minimap, toast, loading and other overlays
   - Adding another navigation panel inside the overlay stack would make `canvas-wrap`'s positioning logic more complex
   - The `.app` grid itself is designed for page-level area division; adding a column is its normal usage

2. **Community navigation has fixed width on desktop, switches to overlay on narrow screens, preventing three columns from squeezing the center canvas.**

   Desktop still uses three columns: `nav | main | drawer`. But at `< 1024px`, the left-side navigation no longer occupies a persistent column, instead switching to an overlay that opens/closes via a separate nav toggle. This preserves the desktop learning narrative while not breaking the narrow-screen canvas.

3. **Community switching reuses `setLearningMode("community")` + `focusNode()`, but the community visible set must be derived at runtime from `activeCommunityId`.**

   Clicking a left-side community = switching to that community's community view + focusing on that community's recommended starting point. This is the same effect as clicking the "community" button on the mode-switch, just also switching the activeCommunityId.

   Key addition: cannot continue directly reusing the pre-computed `learning.views.community.node_ids`, because that only stably represents the primary community. When switching to any community, the visible node set for that community must be dynamically derived via a helper based on the current `nodes[].community`.

4. **Left panel rendering logic split into `renderNavPanel()`, original `renderLearningPanel()` renamed to a function that only handles insights title synchronization.**

   The current `renderLearningPanel()` manages both insights-panel title switching and the learning entry list, with unclear responsibilities. After splitting:
   - `renderNavPanel()`: responsible for the left-side community navigation panel
   - `updateInsightsTitle()` (or equivalent naming): only responsible for insights-panel title switching
   - `#learning-body` DOM no longer needed

5. **After community switching, if the currently selected node is not in the new visible snapshot, proactively close the drawer.**

   The current `activeCommunityId` already exists in state but has not been written to. This round makes it the shared state for the left panel and mode switching.

   Key constraint: left-center-right state must be consistent. If the user switches from community A to community B, but the right side still shows community A's old node, state drift will occur. So after switching communities, check whether `selected` is still in the current visible snapshot; if not, close the drawer directly.
## Implementation Units

- [ ] **Unit 1: Change grid layout to three columns + left-side navigation DOM skeleton**

  **Files:**
  - Modify: `templates/graph-styles/wash/header.html` (CSS + DOM)
  - Test: `tests/graph-html-learning-cockpit.regression-1.sh`
  - Test: `tests/graph-html-insights.regression-1.sh`

  **Approach:**

  CSS changes:
  ```css
  .app {
    grid-template-columns: var(--nav-w, 240px) 1fr 0fr;
    grid-template-areas:
      "nav     brand   drawer"
      "nav     tools   drawer"
      "nav     canvas  drawer"
      "nav     footer  drawer";
  }
  .app.drawer-open {
    grid-template-columns: var(--nav-w, 240px) 1fr var(--drawer-w);
  }

  @media (max-width: 1023px) {
    .app,
    .app.drawer-open {
      grid-template-columns: 1fr 0fr; /* nav becomes overlay, no longer takes a column */
    }
  }
  ```

  DOM changes:
  - Add `<aside class="nav-panel" id="nav-panel">` at the very start of `.app`
  - Contains two sections: `nav-communities` (community leaderboard) and `nav-start` (recommended starting points)
  - Add narrow-screen nav toggle to open/close the overlay
  - Remove `#learning-body` div inside `canvas-wrap` (no longer needed)
  - insights-panel only keeps `#insights-body`

  Styles:
  - Reuse wash-style variables (`--paper-cream`, `--paper-ink`, `--font-hand`, etc.)
  - Community items use corresponding `commPalette` color as left border indicator bar
  - Selected community highlighted with bold + background color, referencing `mode-btn[data-on="1"]` style
  - `.brand` left padding reduced from current 100px to about 24px, avoiding large empty space in the brand area after three-column layout

  **Verification:**
  - graph HTML shell regression passes after update
  - Three-column layout doesn't squeeze canvas at 1280px+ width
  - At `<1024px`, nav becomes overlay and no longer squeezes the center graph
  - Left nav shows empty-state hint when there's no community data

- [ ] **Unit 2: Community navigation panel rendering logic**

  **Files:**
  - Modify: `templates/graph-styles/wash/graph-wash.js` (add `renderNavPanel()`)
  - Modify: `templates/graph-styles/wash/graph-wash-helpers.js` (add helper if needed)
  - Test: `tests/js/graph-wash-learning.test.js`

  **Approach:**

  Add `renderNavPanel()`:
  ```
  1. Take learning.communities, sort by is_primary priority then node_count desc
  2. Render top 3 communities as the community leaderboard
     - Each community: color indicator bar + label + "N nodes · M sources"
     - Primary community gets a small marker on the left (e.g. ★ or bold)
     - Click community item → setActiveCommunity(community.id) → setLearningMode("community")
  3. Recommended starting point area
     - Take recommended_start_node_id of the community matching current activeCommunityId
     - Display as clickable entry item
     - Click → focusNode(recommendedStartNodeId)
  4. Re-render highlight when activeCommunityId changes
  5. If currently selected node belongs to a community not shown (not in top 3), show an inline hint inside the left panel, rather than forcing a highlight switch
  ```

  Modify the insights title sync function (original `renderLearningPanel()`, suggest renaming to `updateInsightsTitle()`):
  - Remove operations on `#learning-body`
  - Only handle insights-panel title switching: in non-global modes the title becomes "洞察"; in global mode it's "Insights"
  - `#insights-body` is always visible, no longer hidden

  Add helper:
  - `getCommunityNodeIds(nodes, communityId)`: derive node ids for any community from runtime `nodes[].community`; cannot continue relying solely on `learning.views.community.node_ids`

  Modify `updateVisibleSnapshot()`:
  - If currently in community mode, derive visible node ids from `state.learning.activeCommunityId`
  - If activeCommunityId is empty, take the primary community

  Add `setActiveCommunity(communityId)`:
  - Update `state.learning.activeCommunityId`
  - Call `setLearningMode("community")`
  - `renderNavPanel()` refreshes the highlight
  - Focus on this community's recommended starting point
  - If the currently selected node in the drawer is not in the new visible snapshot, close the drawer

  **Verification:**
  - Community leaderboard shows top 3 communities, primary first
  - Clicking a community item switches to the correct community view, rather than staying on the primary community subgraph
  - Clicking a recommended starting point enters path view and opens the drawer
  - Weak communities (is_weak=true) are still clickable
  - When the selected node leaves the current community's visible set, the drawer closes correctly

- [ ] **Unit 3: Left-center-right linkage**

  **Files:**
  - Modify: `templates/graph-styles/wash/graph-wash.js`
  - Test: `tests/js/graph-wash-learning.test.js`

  **Approach:**

  Implement linkage one-by-one for the 6 trigger actions:

  | Trigger | Left | Center | Right |
  |---|---|---|---|
  | First open | Primary community selected; recommended starting point shown | path (or community/global degradation) | drawer opens in path, otherwise not forced |
  | Click left-side community | Highlight switches to that community | community view | preserved if already open, refreshed to that community's recommended starting point |
  | Click recommended starting point | Keep current community highlight | path view | auto-opens, shows learning explanation |
  | Click node on graph | Left unchanged | Keep current mode | auto-opens and refreshes |
  | Click mode-switch | Left unchanged | Switch mode | preserved if already open |
  | Switch to global | Left keeps community context but no highlight | global graph | keep current node content |

  Key modifications:

  - `bootstrapLearningEntry()`: call `renderNavPanel()` at boot, set `activeCommunityId` to the primary community
  - `selectNode()`: call `renderNavPanel()` to refresh the left side when a node is selected
  - `setLearningMode("global")`: left community has no highlight, but the community list is still shown
  - When a node is clicked and belongs to one of the current top 3 communities and not in global mode, the left-side highlight may switch
  - When a node is clicked and belongs to a community not shown, the left-side highlight doesn't switch, only shows an inline hint in the left panel
  - After community switching, if the current drawer node is not in the new visible snapshot, proactively close the drawer to avoid left-center-right drift

  **Verification:**
  - Behavior for the 6 trigger actions matches the design doc linkage table
  - No state drift across left-center-right (inconsistent highlights)
  - Rapid consecutive clicks on different communities don't cause panel jitter
  - When clicking a node in a non-displayed community, left-side highlight stays stable and an inline hint appears

- [ ] **Unit 4: Regression tests and golden updates**

  **Files:**
  - Modify: `tests/graph-html-learning-cockpit.regression-1.sh`
  - Modify: `tests/js/graph-wash-learning.test.js`
  - Modify: `tests/regression.sh` (if needed)

  **Approach:**

  - Update HTML regression: check that `nav-panel`, `nav-communities`, `nav-start` DOM hooks exist
  - Add a fixture with multi-community learning data; cannot continue relying solely on the current `learning: null` base fixture
  - Add JS unit tests: `renderNavPanel()` community sorting, top-3 truncation, activeCommunityId linkage
  - Add JS unit tests: `getCommunityNodeIds()` pure function boundaries (empty input / nonexistent community / normal community)
  - Add JS unit tests: consistency between mode and visible snapshot after `setActiveCommunity()` switch
  - Add JS unit tests: drawer auto-closes after selected node leaves the visible snapshot
  - Add JS unit tests: after clicking a node in a non-displayed community, left-side highlight stays unchanged and an inline hint appears
  - Add JS unit tests: linkage assertions for the 6 trigger actions
  - Ensure empty wiki's left-side panel shows empty-state hint without errors

  **Verification:**
  - `bash tests/regression.sh` all green
  - `node --test tests/js/graph-wash-learning.test.js` all green
  - graph HTML independent regression all green
  - Multi-community fixture actually covers community switching rather than only testing empty learning

## Suggested execution order

Recommend implementing along 2 commit boundaries:

1. **Unit 1 + Unit 2**: Layout changes + rendering logic (DOM + CSS + JS rendering, modify header.html and graph-wash.js together)
2. **Unit 3 + Unit 4**: Linkage logic + regression tests (JS behavior + test coverage)

## Risks

- **Three-column layout squeezes canvas on narrow screens**: This round has decided that at `< 1024px` the nav-panel becomes an overlay and no longer occupies a column; during implementation focus on verifying toggle, layering, and coexistence with drawer.
- **If community switching still reuses the primary's precomputed view, left highlight changes but center graph doesn't**: Must dynamically derive the community visible set via `activeCommunityId + nodes[].community`.
- **Semantic conflict between community switching and mode-switch**: Clicking a left community = switch to community mode, but user might expect just to highlight that community while keeping path mode. V1 unifies to switching community mode; a "highlight only" mode may be added later.
- **Left-side explanation missing when clicking a node from a non-top-3 community**: This round has decided not to let the left highlight jump around; instead show an inline hint saying "current node belongs to a non-displayed community".
- **Empty community data causes left panel to be blank**: Need an empty-state UI ("No community info available"), cannot show an empty shell.
- **Drawer state drift**: After community switching, if the currently selected node is not in the new visible snapshot, the drawer must be closed proactively, otherwise left-center-right will be inconsistent.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | OPEN | mode: SELECTIVE_EXPANSION, 2 critical gaps |
| Codex Review | `/codex review` | Independent 2nd opinion | 5 | ISSUES_FOUND | outside voice found runtime community-view gap, drawer drift, and fixture gap |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 7 | CLEAR | 9 issues, 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR | score: 4/10 → 9/10, 22 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 1 | OPEN | score: 4/10 → 4/10, TTHW: 15-20min → 5min |

- **CODEX:** pointed out that the primary community's precomputed view cannot be directly reused for switching to arbitrary communities; this point has been incorporated into this plan
- **CROSS-MODEL:** Claude and Codex reached consensus on "visible snapshot must be derived at runtime when switching to any community"; there was disagreement on "three-column grid vs floating card", and per user decision the three-column grid is kept
- **UNRESOLVED:** 0
- **VERDICT:** ENG CLEARED — ready to implement
