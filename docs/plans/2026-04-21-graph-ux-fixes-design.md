# Design: 5 UX fixes for the watercolor graph

Generated on 2026-04-21 · branch main · mode: Builder (polish of existing features)
Status: DRAFT · v3 (incorporated 11 items from /plan-ceo-review + 9 items from /plan-eng-review)

## Problem Statement

The watercolor-style interactive graph (v3.0, introduced in PR #17) exposed 5 UX problems in actual use:

1. **Drawer layout imbalance**: On small screens, the "neighbor nodes" section has no scrolling and no height cap; when there are too many neighbors they squeeze or even fully cover the "knowledge area"
2. **Card text overflow**: Node card width is hard-capped at 180px, but long labels are not truncated and text overflows the card boundary
3. **Minimap always visible**: The top-right minimap is fixed-occupying 180×130 space and cannot be folded away
4. **Tool button functions invisible**: The three icon buttons at the top right (relayout / center / Tweaks) have no visible labels; native `title` tooltips are delayed and ugly, and first-time users don't know what they do
5. **Project link in a hidden location**: The `llm-wiki-skill` GitHub link is tucked into footer-right in 11px tiny text and is hard for users to discover

## Core Principles (from user)

- **Knowledge area primary, neighbor nodes secondary**: The allocation strategy for problem 1 must reflect this — the knowledge area always gets the majority of the space
- **User's-perspective first**: All solutions take first-use experience as the yardstick, not "least effort for code"

## Constraints

- Only modify `templates/graph-styles/wash/header.html` and `templates/graph-styles/wash/graph-wash.js`
- Don't modify graph data structure, build scripts, or node layout algorithms
- Preserve compatibility with watercolor (wash) visual theme and existing Tweaks variants
- Regression tests must all pass (`tests/graph-html-*.regression-*.sh`)

## Premises

1. ✅ All five issues are polish of existing features, not graph architecture changes
2. ✅ Do all five together, not in batches
3. ✅ Each solution's trade-offs use "user's perspective" as the yardstick

## Recommended Solution (item by item)

### Problem 1: Drawer becomes "primary-secondary" dual-area independent scrolling + collapsible neighbor nodes

**Root cause**: `.drawer-inner` uses flexbox but `.drawer-neighbors` has no `max-height` and no independent `overflow`; the `flex: 1` `.drawer-body` has flex-basis=0 and is powerless against the neighbor area expanding per-content.

**Solution (header.html)**:

```css
.drawer-inner {
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.drawer-body {
  flex: 1 1 0;           /* knowledge area primary, eats remaining space */
  overflow-y: auto;
  min-height: 0;         /* allow proper shrinking in flex */
}
.drawer-neighbors {
  flex-shrink: 0;
  max-height: 35vh;       /* cap at ~1/3 screen height, doesn't steal from main area */
  overflow-y: auto;       /* scrolls internally */
  border-top: 1px dashed var(--paper-ink-faint);
}
.drawer-neighbors[data-collapsed="1"] {
  max-height: 40px;       /* after collapse, only title bar remains */
  overflow: hidden;
}
.drawer-neighbors h4 {
  cursor: pointer;        /* click title to toggle collapse */
  user-select: none;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.drawer-neighbors h4::after {
  content: "⌃";           /* collapse indicator arrow */
  font-family: var(--font-hand);
  transition: transform 180ms;
}
.drawer-neighbors[data-collapsed="1"] h4::after {
  transform: rotate(180deg);
}
```

**Solution (graph-wash.js, ~25 new lines)**:

```js
// Note: The drawer's DOM skeleton (.drawer-neighbors > h4 + #nb-list) is static in header.html,
// openDetailDrawer() only clears #nb-list's innerHTML each time, doesn't rebuild h4.
// So the listener here only needs to bind once at init; no leak.

// Title becomes focusable button semantics + aria-expanded state
const h4 = drawerNeighbors.querySelector("h4");
h4.setAttribute("tabindex", "0");
h4.setAttribute("role", "button");

function applyNeighborsCollapsed(collapsed) {
  drawerNeighbors.setAttribute("data-collapsed", collapsed ? "1" : "0");
  h4.setAttribute("aria-expanded", collapsed ? "false" : "true");
}

// Initialize: default expanded (first-time users can directly see neighbor content)
const savedCollapsed = safeLocalStorage.get("wiki-neighbors-collapsed") === "1";
applyNeighborsCollapsed(savedCollapsed);

function toggleNeighbors() {
  const next = drawerNeighbors.getAttribute("data-collapsed") !== "1";
  applyNeighborsCollapsed(next);
  safeLocalStorage.set("wiki-neighbors-collapsed", next ? "1" : "0");
}

h4.addEventListener("click", toggleNeighbors);
h4.addEventListener("keydown", (e) => {
  if (e.key === "Enter" || e.key === " ") {
    e.preventDefault();
    toggleNeighbors();
  }
});
```

**Default state: expanded**. Reason: First-time users need to see the neighbor list to discover the collapse feature; if collapsed by default it becomes a hidden feature, conflicting with the "user's perspective" principle.

**Delivered behavior**:
- Neighbors 0~5: expand per content height, don't waste space
- Neighbors 20+: container takes at most 35vh, internal scrollbar
- User wants to focus on reading: click or Enter/Space key to one-click collapse the "neighbor nodes" title
- Collapse preference persists across sessions (when localStorage is unavailable only affects current session, see "Shared utilities" section)

---

### Problem 2: Card label truncation + SVG native tooltip showing full name

**Root cause**: `cardDims()` uses `Math.min(180, w + pad)` to cap card width, but `.text()` writes the full label directly; SVG text doesn't auto-truncate.

**Solution (graph-wash.js)**:

Add utility function `truncateLabel(label, maxWidth)`:

```js
// Use Intl.Segmenter to iterate graphemes (grapheme clusters), not code points.
// This treats ZWJ-connected emoji (like 👨‍👩‍👧‍👦) as a whole, not splitting mid-emoji.
// Fully supported in modern browsers, zero new dependencies.
const labelSegmenter = new Intl.Segmenter("zh", { granularity: "grapheme" });

function truncateLabel(label, maxWidth) {
  if (!label || typeof label !== "string") {
    console.warn("[wiki] truncateLabel: invalid input", label);
    return { text: "", truncated: false };
  }

  // Character width estimation consistent with cardDims
  const charWidth = g => /[一-鿿]/.test(g) ? 15 : 8.5;
  const pad = 22;
  const ellipsis = "…";
  const ellipsisW = 8;

  const graphemes = Array.from(labelSegmenter.segment(label), s => s.segment);

  let totalW = 0;
  for (const g of graphemes) totalW += charWidth(g);
  if (totalW + pad <= maxWidth) return { text: label, truncated: false };

  let out = "";
  let w = 0;
  for (const g of graphemes) {
    const cw = charWidth(g);
    if (w + cw + ellipsisW + pad > maxWidth) break;
    out += g;
    w += cw;
  }
  return { text: out + ellipsis, truncated: true };
}
```

In the `renderNodes()` card rendering branch:

```js
const { text: displayLabel, truncated } = truncateLabel(d.label || d.id, 180);
gg.append("text").attr("class", "node-label node-label--in")
  .attr("text-anchor", "middle").attr("dy", "0.35em")
  .text(displayLabel);
// SVG native tooltip, browser shows full name on hover
if (truncated) {
  gg.append("title").text(d.label || d.id);
}
```

**Why use SVG `<title>` instead of custom tooltip like in problem 4**:

This seems to contradict problem 4's "criticism of native tooltip delay", but the positioning is different:

- **Problem 4's tool buttons**: Tooltip is the **primary entry point** — users must see the label text to know what the button does; 1-second delay directly hurts first experience, so switch to visible text + custom tooltip.
- **Problem 2's node labels**: `<title>` is only an **auxiliary supplement** — the **primary entry point** for users to see the full name is clicking the node to open the drawer (the drawer always shows the full label). Seeing the full name on hover is just a "can check or not, still usable" convenience; 1-second delay is acceptable.

Additional benefits of this choice: zero dependencies, zero new CSS, native accessibility screen reader compatibility, no interference with problem 4's `data-tip` hover style.

**Known limitations** (see "Known limitations" section): `charWidth` estimates for emoji, full-width punctuation, and Arabic digits aren't precise; extreme cases may over-truncate or under-truncate by 1-2 chars. MVP acceptable, refine later if needed.

**Delivered behavior**:
- Short labels unaffected
- Long labels display first N chars + "…"; ~1 second hover shows browser tooltip with full name
- Drawer always shows full name when node is clicked (unchanged)

---

### Problem 3: Minimap collapsible (with persistence)

**Solution (header.html)**:

Add collapse button and collapsed state styles to minimap container:

```html
<!-- Current header.html:1035 .minimap div has no id; need to add id="minimap" in this change -->
<div class="minimap" id="minimap" data-collapsed="0">
  <div class="minimap__label">Minimap</div>
  <button class="minimap__toggle" id="minimap-toggle"
          aria-label="Collapse minimap" aria-expanded="true"
          data-tip="Collapse / expand minimap">⌄</button>
  <svg id="minimap-svg"></svg>
</div>
```

```css
.minimap {
  /* existing rules unchanged */
  transition: width 220ms, height 220ms;
}
.minimap[data-collapsed="1"] {
  width: 88px;
  height: 22px;
  overflow: hidden;
}
.minimap[data-collapsed="1"] #minimap-svg {
  display: none;
}
.minimap[data-collapsed="1"] .minimap__label {
  top: 2px; left: 6px;
  background: transparent;
}
.minimap__toggle {
  position: absolute;
  top: 2px; right: 4px;
  width: 22px; height: 20px;
  background: transparent;
  border: none;
  color: var(--paper-ink-dim);
  font-size: 14px;
  cursor: pointer;
  z-index: 3;
  transition: transform 180ms;
}
.minimap[data-collapsed="1"] .minimap__toggle {
  transform: rotate(180deg);
  right: 2px;
}
```

**Solution (graph-wash.js)**:

```js
const minimap = document.getElementById("minimap");
const toggleBtn = document.getElementById("minimap-toggle");

function applyMinimapCollapsed(collapsed) {
  minimap.setAttribute("data-collapsed", collapsed ? "1" : "0");
  toggleBtn.setAttribute("aria-expanded", collapsed ? "false" : "true");
  toggleBtn.setAttribute("aria-label", collapsed ? "Expand minimap" : "Collapse minimap");
}

applyMinimapCollapsed(safeLocalStorage.get("wiki-minimap-collapsed") === "1");

toggleBtn.addEventListener("click", (e) => {
  e.stopPropagation();
  const next = minimap.getAttribute("data-collapsed") !== "1";
  applyMinimapCollapsed(next);
  safeLocalStorage.set("wiki-minimap-collapsed", next ? "1" : "0");
});
```

**Delivered behavior**:
- Default expanded (first use directly sees functionality)
- Click small arrow at top-right to collapse into a 88×22 label bar
- Can still see "Minimap" label when collapsed, user knows where it is and how to expand
- Settings persist across sessions

---

### Problem 4: Tool buttons become "icon + text" combination; on narrow screens degrade to icon + custom tooltip

**Root cause**: Native `title` tooltip has ~1 second delay, inconsistent visuals, first-time users have no way to predict function.

**Solution (header.html)**:

Buttons change from pure icon to icon + text (baseline state):

```html
<button class="iconbtn iconbtn--labeled" id="btn-refit" data-tip="Relayout nodes">
  <svg>...</svg>
  <span class="iconbtn__text">Relayout</span>
</button>
<button class="iconbtn iconbtn--labeled" id="btn-fit" data-tip="Fit canvas · center">
  <svg>...</svg>
  <span class="iconbtn__text">Center</span>
</button>
<button class="iconbtn iconbtn--labeled" id="btn-tweaks" data-tip="Visual settings">
  <svg>...</svg>
  <span class="iconbtn__text">Settings</span>
</button>
```

```css
.iconbtn--labeled {
  width: auto;
  padding: 0 12px;
  gap: 6px;
  font-family: var(--font-ui);
  font-size: 13px;
  border-radius: 18px;
}
.iconbtn__text {
  color: var(--paper-ink-dim);
  line-height: 1;
}
.iconbtn--labeled:hover .iconbtn__text { color: var(--paper-ink); }

/* Custom instant tooltip (no delay) */
[data-tip] { position: relative; }
[data-tip]:hover::after,
[data-tip]:focus-visible::after {
  content: attr(data-tip);
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  max-width: min(240px, calc(100vw - 24px));  /* extreme narrow screen fallback: don't exceed viewport */
  white-space: normal;                         /* allow wrapping on narrow screens, no infinite stretching */
  word-break: break-word;
  padding: 5px 10px;
  background: var(--paper-ink);
  color: #fdf7e6;
  font-family: var(--font-ui);
  font-size: 11px;
  border-radius: 4px;
  box-shadow: 1px 2px 0 rgba(43,38,32,0.15);
  z-index: 40;
  pointer-events: none;
  animation: tip-in 140ms ease-out;
}
/* Extreme narrow (<480px): three right-edge buttons stick to the edge, right-aligned tooltip gets clipped: change to right-biased but not overflowing */
@media (max-width: 480px) {
  [data-tip]:hover::after,
  [data-tip]:focus-visible::after {
    right: auto;
    left: 0;
    max-width: calc(100vw - 16px);
  }
}
@keyframes tip-in {
  from { opacity: 0; transform: translateY(-3px); }
  to   { opacity: 1; transform: translateY(0); }
}
@media (prefers-reduced-motion: reduce) {
  [data-tip]:hover::after,
  [data-tip]:focus-visible::after { animation: none; }
}

/* Narrow screen: back to pure icon mode, but keep data-tip for supplementary explanation */
@media (max-width: 900px) {
  .iconbtn--labeled { width: 34px; padding: 0; }
  .iconbtn__text { display: none; }
}
```

**Tweaks panel future extension point**: In the Tweaks panel JS init, add a placeholder comment `// TODO: neighbor-area-max-height slider (35vh default)`, marking where a "neighbor area cap" slider could be added later. Zero implementation cost, leaves an anchor for future iteration.

**Why "icon + text" always-on is the top choice**:
- First-time users have zero learning cost, understand at a glance
- Doesn't force users to hover to discover the function (tooltip is essentially a compromise of hiding visible UI)
- Wide-screen space is plenty (three buttons total < 220px)
- Narrow screen auto-degrades to original pure icon + custom tooltip

**Delivered behavior**:
- ≥900px: buttons show icon + text (Relayout / Center / Settings)
- <900px: degrade to circular icon buttons, hover immediately shows custom tooltip (no delay, unified visuals)
- Remove unnecessary native `title` attributes (avoid double-popping with data-tip)

---

### Problem 5: Promote project link to top-left brand area

**Solution (header.html)**:

Wrap `.brand__mark` ("llm-wiki" small dot logo) as an `<a>` pointing to the repo:

```html
<header class="brand">
  <a class="brand__mark" href="https://github.com/sdyckjq-lab/llm-wiki-skill"
     target="_blank" rel="noopener"
     data-tip="View llm-wiki project · GitHub">
    llm-wiki
  </a>
  <div class="brand__title" id="wiki-title">__WIKI_TITLE__</div>
  <!-- ... -->
</header>
```

```css
.brand__mark {
  /* keep existing rules (including baseline transform: rotate(-0.6deg)) + the following */
  text-decoration: none;
  color: var(--paper-ink);
  transition: transform 200ms;
}
/* Note: baseline already rotate(-0.6deg); hover rotates further to -1.2deg
   so visual effect is "more tilted" rather than "rotated upright". This is the correct direction for "slight jitter hinting clickability". */
.brand__mark:hover,
.brand__mark:focus-visible {
  transform: rotate(-1.2deg) translateY(-1px);
  outline: none;
}
.brand__mark:focus-visible {
  box-shadow: 0 0 0 2px var(--paper-ink-dim);
  border-radius: 4px;
}
.brand__mark:hover::before {
  box-shadow: 2px 3px 0 rgba(0,0,0,0.2);  /* watercolor dot shadow deepens */
}
@media (prefers-reduced-motion: reduce) {
  .brand__mark { transition: none; }
  .brand__mark:hover,
  .brand__mark:focus-visible { transform: rotate(-0.6deg); }  /* keep baseline, don't move */
}
```

**The duplicate "generated by llm-wiki" link in footer**: Keep. Reason:
- Footer is where developers habitually look for attribution links; removing it would be unexpected
- Brand area promotion is "making the entry prominent", not "deleting the original entry"
- Both links point to the same URL, no confusion

**Future path dependency reminder** (NICE-TO-HAVE): Currently "brand → GitHub" has semantics "brand equals project link". In the future if llm-wiki adds an overview/index page (e.g. "all knowledge bases home"), this becomes a semantic conflict — should brand point to project repo or to local overview page? When that happens, recommend: brand points to overview page, project repo goes back to footer; or brand continues pointing to repo and add a "home" button. Don't decide this round; just mark this as a **future UX decision point**.

**Delivered behavior**:
- Top-left "llm-wiki" text clickable, hover / keyboard focus both have clear feedback (slight rotation + deeper shadow + focus ring), matches watercolor hand-drawn style
- `prefers-reduced-motion` users see static feedback, no rotation
- Click opens repo in new tab

---

## Shared utility: safeLocalStorage

Problems 1 and 3 both rely on localStorage for preference persistence. But localStorage has known failure modes: Safari private mode throws exceptions, third-party cookies disabled, storage quota full, enterprise policy restrictions. **Writing `localStorage.getItem/setItem` directly would white-screen these users on entry**.

At the top of `graph-wash.js`'s IIFE (after state declaration, before any localStorage read/write init, within the first ~20 lines), add a module-level helper that all localStorage calls go through:

```js
const safeLocalStorage = {
  get(key) {
    try { return localStorage.getItem(key); }
    catch (err) { console.warn("[wiki] localStorage.get failed:", key, err); return null; }
  },
  set(key, value) {
    try { localStorage.setItem(key, value); }
    catch (err) { console.warn("[wiki] localStorage.set failed:", key, err); /* swallow */ }
  },
};
```

**Failure degradation behavior**: Read fails → returns null → default values (neighbors expanded, minimap expanded); write fails → silent warn, within the session collapse/expand still works, just doesn't persist across sessions. User perceives: all functionality works, just "this time's collapse reverts to default on next refresh". Acceptable.

---

## Accessibility (a11y) requirements

Three required items:

1. **Neighbor collapse title** (problem 1): `<h4>` gets `tabindex="0"` + `role="button"` + `aria-expanded` state + Enter/Space keyboard triggers. Code is in problem 1 solution.
2. **Minimap collapse button** (problem 3): `aria-expanded` reflects current state; `aria-label` switches with state ("Collapse minimap" / "Expand minimap"). Code is in problem 3 solution.
3. **Brand link animation** (problem 5): `@media (prefers-reduced-motion: reduce)` overrides hover rotation to static visual feedback; add `:focus-visible` focus ring for keyboard accessibility. Code is in problem 5 solution.

**Acceptance method**:
- Using only keyboard (Tab / Enter / Space) can complete: open drawer → collapse neighbors → collapse minimap → navigate to brand link
- After enabling "Reduce motion" in macOS system settings, refresh page, brand hover has no rotation, tooltip has no fade-in animation

---

## Known limitations

1. **`truncateLabel` character width estimation imprecise**: `charWidth` uses a simple regex to distinguish CJK and Latin, but the following cases deviate:
   - Emoji (usually double-width, but not in CJK regex range)
   - Full-width punctuation ("，。！？") estimated as CJK width, basically accurate; half-width punctuation estimated as Latin width, also basically accurate; but full-width space, half-width space, and dash have deviations
   - Arabic digits, Thai, Arabic, Hindi all go through Latin 8.5px; actual width may be smaller or larger

   **Impact**: In extreme cases card may over-truncate or under-truncate by 1-2 chars, or "…" tight against edge. MVP acceptable.
   **Mitigation** (not done this round): Use `getComputedTextLength()` to measure width after rendering and then truncate; cost is two layouts. If many non-CJK/Latin labels appear in the future, refine then.

   **Note (fixed in v3)**: Truncation **won't** fall in the middle of a ZWJ-connected emoji (e.g. 👨‍👩‍👧‍👦 won't be split into "👨") — achieved by iterating grapheme clusters via `Intl.Segmenter`, not code points. Width estimation is a separate issue.

2. **`localStorage` cross-session persistence unavailable in some environments** (Safari private mode, third-party cookies disabled, enterprise policy): mitigated via `safeLocalStorage`; within-session functionality is complete, refresh reverts to default.
   **User-perceivable symptom**: In these environments user may wonder "I collapsed neighbors yesterday, why are they expanded again today?". Don't add UI hint this round (avoid disturbing on first use); just mention in README / CHANGELOG: "collapse preference depends on localStorage".

---

## NOT in scope (explicitly deferred)

Things this PR doesn't do, each with a one-line reason:

- **Unify `zoom-ctrl` +/- button tooltips**: Two buttons still use native `title` (1 second delay). Reason: scope only covers the three top-right buttons the user explicitly complained about; zoom button icons are universal symbols (+/−), first-time users can guess, delay tooltip has small impact. Next UX batch will unify.
- **`truncateLabel` width estimation perfection** (precise width for non-CJK/Latin scripts): `getComputedTextLength()` measurement is the standard solution, but cost is two layouts. Currently knowledge base has no mass Arabic/Thai nodes, MVP accepts deviation. Marked as Known Limitation.
- **Introduce JS unit test framework** (bun test / vitest / node:test): Cross-project decision; shouldn't hide in a UX fix PR. Pure functions like `truncateLabel` are covered indirectly via multi-length golden fixtures this round. Recommend adding to TODOS.md as an independent decision.
- **Fixture auto-diff whitelist tooling**: Ideal but out of scope. This round relies on discipline of "each problem in separate commit + only small diff to review each time" as mitigation.
- **Tweaks panel "neighbor area cap (vh)" slider**: Zero-cost placeholder comment added, real implementation deferred.
- **User UI hint on `localStorage` failure**: Popping "Your browser doesn't support preference persistence" on first use is too noisy, deferred.
- **Brand link re-pointing after overview/home route appears**: Long-term decision point, v2 has marked it, not in this round.

---

## Observability

Add a few `console.warn` so users can send browser console logs for us to locate issues:

1. `safeLocalStorage.get/set` catch branches (already in utility function)
2. `truncateLabel` receives empty label or non-string: `console.warn("[wiki] truncateLabel: invalid input", label)`
3. Minimap SVG init failure (defensive): `console.warn("[wiki] minimap render failed:", err)`

No reporting, no telemetry, purely local warns. Zero new dependencies.

---

## Alternatives considered (for future reference)

### Problem 1 alternative B: unified scrolling
Knowledge + neighbor nodes in same scrolling container. Pros: minimal change. Cons: to check neighbors must scroll past entire knowledge. **Rejection reason**: violates "neighbors are secondary" (they occupy the end of the knowledge area, instead becoming a required pass-through).

### Problem 4 alternative A: pure icon + custom tooltip
Only add tooltip without visible text. **Rejection reason**: violates "user's perspective" — first entry still requires hovering three times to figure out; toolbar functions shouldn't be hidden.

### Problem 5 alternative C: delete footer link
Avoid duplication. **Rejection reason**: developers habitually check footer; keeping redundancy has no cost to experience.

---

## Success criteria

1. **Problem 1**: With 30 neighbors, knowledge area still shows at least 65% of screen height's content; after collapse knowledge area fills
2. **Problem 2**: When node label length ≥ 20 chars, card edge has no text overflow; hover reveals full name
3. **Problem 3**: After collapsing minimap, top-right has only a 88×22 label; refresh keeps collapsed
4. **Problem 4**: On wide screens (≥900px) all three buttons' text visible; narrow screen button hover ≤150ms pops custom tooltip
5. **Problem 5**: Top-left llm-wiki text clickable, hover has visual feedback, click navigates to GitHub

---

## Testing and regression checklist

**Test framework choice**: Existing project `tests/graph-html-*.regression-*.sh` are all shell + DOM string assertions + golden fixture diff style. **Do not** introduce JS unit test framework (bun test / vitest) — cross-project decision, shouldn't hide in this UX fix PR. JS pure functions (`truncateLabel` / `safeLocalStorage`) coverage is achieved indirectly via **multi-label-length golden fixtures**. If this layer proves too coarse later, introduce unit test framework in a separate PR (see "NOT in scope").

**Step-by-step fixture update (avoid one-shot large diff)**: After completing each problem's commit, run `scripts/build-graph-html.sh` to generate HTML → `diff tests/expected/graph-interactive-basic.html <(generated HTML)` to see diff → **confirm diff lines match this commit's description** (e.g., problem 5 should only show brand becoming a, new CSS; problem 4 should only show button structure + tooltip CSS) → overwrite fixture. This way each eye only sees 1-2 changes, greatly reducing probability of missing unrelated regressions.

### Verification checklist after change completion:

1. **Run existing regressions** (run after each commit):
   - `tests/graph-html-mobile.regression-1.sh` (small-screen layout — core regression for problem 1)
   - `tests/graph-html-styles.regression-1.sh` (style consistency — problems 4/5 affect this; depends on step-by-step fixture update)
   - `tests/graph-html-search.regression-1.sh` (search — shouldn't be affected)

2. **New regressions (required in this PR)**:
   - `tests/graph-html-drawer-neighbors.regression-1.sh`: fixture with 30+ neighbors, assert knowledge area height ratio ≥ 60%, assert h4 has `aria-expanded` attribute
   - `tests/graph-html-long-label.regression-1.sh`: fixture with various label lengths (5/15/25 char CJK, 5/15/25 char Latin, mixed, with emoji), assert long label DOM has label with `…`, with `<title>` element; short labels don't
   - `tests/graph-html-minimap.regression-1.sh`: assert `#minimap` container has id, `#minimap-toggle` exists and has `aria-expanded`
   - `tests/graph-html-brand-link.regression-1.sh`: assert `.brand__mark` is `<a href="https://github.com/sdyckjq-lab/llm-wiki-skill"` with `rel="noopener"`; assert CSS contains `:focus-visible`
   - `tests/graph-html-a11y.regression-1.sh`: assert CSS contains `@media (prefers-reduced-motion: reduce)` rule; assert h4/minimap-toggle both have correct role + tabindex + aria-* attribute combo

3. **Manual acceptance checklist** (after codex terminal runs ingest → graph):
   - On small screen (<600px width), open drawer; with > 20 neighbors, knowledge still readable
   - Long label node cards visually no overflow; long labels containing ZWJ emoji (like 👨‍👩‍👧‍👦) after truncation don't show half an emoji
   - Collapse minimap → refresh → still collapsed
   - Three tool button texts visible
   - Top-left llm-wiki click navigates correctly
   - Keyboard only: Tab to neighbor title → Enter to collapse → Tab to minimap toggle → Enter to collapse → Tab to brand link → Enter to navigate
   - With system "Reduce motion" on, brand hover doesn't rotate (stays at baseline rotate -0.6deg), tooltip doesn't fade in
   - **Safari private mode** open page, click to collapse neighbors, refresh — confirm no errors; within session can collapse but refresh reverts to default expanded (localStorage quota fails, degrades)

---

## Step-by-step implementation suggestion (optional, leave to implementation phase)

If all at once is too much pressure, recommended order:

0. **First add `safeLocalStorage` helper** (5 lines, pure addition, no visual impact) → problems 1/3 both need it, do first all at once
1. **Problem 5** (minimal change, within 10 lines, low risk) → first trial of process; sync update golden fixture
2. **Problem 2** (pure JS, no global CSS conflict)
3. **Problem 3** (minimap standalone module)
4. **Problem 4** (involves toolbar rearrangement, needs regression style testing)
5. **✋ Manual acceptance gate**: Run `scripts/build-graph-html.sh` to generate HTML, open browser to check top-right three buttons + tooltip + minimap collapse + brand link all normal, then continue. Problems 4 and 1 both heavily change header.html CSS; an acceptance gate between them catches style regression issues earlier, easier than investigating within a mixed large commit.
6. **Problem 1** (most core, involves overall drawer layout, do last to ensure drawer usable during other acceptance)
7. **Wrap up**: update fixture → run all regressions → update CHANGELOG / README

Each step separate commit, in line with project `CLAUDE.md` step-by-step commit rule.

---

## Distribution plan

No new artifact distribution: this skill is directly obtained by users after `install.sh`. Per project `CLAUDE.md` pre-push rules:

- Update `CHANGELOG.md` (add version entry — current v3.0 increments to v3.1)
- Update `README.md` feature list ("drawer collapsible neighbors / node label truncation / collapsible minimap / tool buttons with text / clickable brand area")
- Before push run three-layer test rules (layer 1 Claude Code auto-runs; layer 2/3 codex terminal manually runs workflows)

---

## Open questions

1. In problem 4 button text choose "Relayout / Center / Settings" or longer "Relay out nodes / Fit canvas / Visual settings"? Short version saves space, visually tighter; long version clearer. **Default: short**; if users feedback unclear, adjust.
2. Is problem 1's `max-height: 35vh` appropriate? May need fine-tuning in real usage (30vh / 40vh). First version uses 35vh, leave a "neighbor area cap" slider in Tweaks panel for later iteration. **Default: don't add slider yet**, keep solution minimal.
3. Is problem 5's hover rotation angle (-1.2deg) too much? Watercolor style already has hand-drawn jitter; adding rotation may stack. **Default: conservative -0.4deg**, then tune per visual feedback.

---

## Next step

- User confirms this doc → implementation phase (recommend new branch `fix/graph-ux-batch-2026-04`, commits in "step-by-step implementation suggestion" order)
- Or user first picks priority/solution adjustment → back to this doc for iteration

Recommended implementation entry: just tell me "do it per this plan", I'll open the branch and start. If you want another independent perspective review, call `/plan-eng-review`.

---

## v3 revision record (2026-04-21)

v3 incorporates 9 engineering feedback items from `/plan-eng-review`:

**CRITICAL (4 items)**
1. **Brand hover rotation direction fix**: `.brand__mark` baseline is already `rotate(-0.6deg)`; hover using `-0.4deg` would "rotate upright", contrary to "jitter hinting clickability" intent. Changed to `rotate(-1.2deg) translateY(-1px)` (baseline +0.6deg tilt). Problem 5 solution fixed.
2. **`truncateLabel` grapheme cluster iteration**: `for...of` iterates by code point; ZWJ-connected emoji (like 👨‍👩‍👧‍👦) would be truncated to "half emoji + …". Changed to `Intl.Segmenter` iterating by grapheme clusters, fully supported in modern browsers, zero dependencies. Problem 2 solution fixed.
3. **Test strategy**: Existing project `tests/graph-html-*.regression-*.sh` is all shell + fixture style, no JS unit tests. This PR **does not** introduce unit test framework (cross-project decision); `truncateLabel` / `safeLocalStorage` covered indirectly via multi-length golden fixtures. Explicitly stated in "Testing and regression checklist", added to TODOS candidates.
4. **Fixture step-by-step update**: Original "one-shot update + manual diff" was too fragile; 7 independent changes easy to miss. Changed to "refresh fixture after each problem's independent commit", each time only viewing 1-2 small diffs. Updated in "Testing and regression checklist" section.

**WARNING (4 items)**
5. **`#minimap` container missing id**: Existing `header.html:1035` `.minimap` has no id, plan's JS would get null. Added comment in problem 3 HTML example emphasizing this.
6. **`zoom-ctrl` tooltip explicitly deferred**: Bottom-right +/- buttons still use native `title`, not touched this round. Added to "NOT in scope".
7. **`safeLocalStorage` declaration location explicit**: Specified "top of IIFE, after state declaration, before any localStorage read/write (within first 20 lines)". Updated in "Shared utility" section.
8. **a11y automated regression**: Added `tests/graph-html-a11y.regression-1.sh` + minimap + brand-link three shell scripts, auto-assert role/tabindex/aria-* attributes + `prefers-reduced-motion` CSS rule existence. Added to "Testing and regression checklist".

**NICE-TO-HAVE (1 item)**
9. **h4 persistence comment**: Added one line saying "openDetailDrawer() only clears nb-list, h4 is static, bind listener once suffices", avoiding future misreading. Added comment at top of problem 1 JS code block.

**Related new NOT in scope entries** (from #6, #3, #8, etc.): zoom-ctrl tooltip, unit test framework introduction, fixture auto-diff tool, truncateLabel width perfection, localStorage failure UI hint.

---

## v2 revision record (2026-04-21)

v2 incorporates 11 feedback items from `/plan-ceo-review`:

**CRITICAL (7 required)**
1. Problem 2's SVG `<title>` positioned as "auxiliary tooltip", not contradicting problem 4's "tooltip as primary entry". Explicitly stated in problem 2 section.
2. Problem 5's `brand__mark` changed from `<div>` to `<a>` will invalidate `tests/expected/graph-interactive-basic.html` golden; added sync update step in "Testing and regression checklist".
3. All localStorage calls go through `safeLocalStorage` helper (try/catch degradation); added "Shared utility" section.
4. Problem 1 neighbor collapse default state clarified as **expanded** (first-time users can discover feature); annotated in problem 1 section.
5. Three a11y fixes: neighbor title keyboard-accessible + aria-expanded, minimap toggle aria-expanded, brand link prefers-reduced-motion + focus-visible; added "Accessibility requirements" section and merged into each solution.
6. `data-tip` extreme narrow screen viewport overflow fallback (<480px changes to left alignment + max-width); added to problem 4 CSS.
7. Manual acceptance gate inserted between problem 4 and problem 1 implementation order; updated "Step-by-step implementation suggestion".

**WARNING (1 item)**
8. `truncateLabel` known limitations for emoji / full-width punctuation / non-Latin character width estimation; added "Known limitations" section.

**NICE-TO-HAVE (3 items)**
9. "brand → GitHub" semantic future path dependency (when overview page/home appears); added future decision point reminder in problem 5 section.
10. Tweaks panel "neighbor area cap" slider placeholder comment; explained at end of problem 4 section.
11. `safeLocalStorage` failure, `truncateLabel` abnormal input, minimap render failure `console.warn`; added "Observability" section.
