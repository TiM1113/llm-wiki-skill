---
title: wash graph null reference protection and label truncation unification
date: 2026-04-21
category: ui-bugs
module: interactive-graph
problem_type: ui_bug
component: tooling
symptoms:
  - drawerNeighbors throws TypeError on querySelector("h4") when DOM element doesn't exist, causing full white screen
  - cardDims() and truncateLabel() use different width constants, text overflows card after truncation
  - graph regression tests only do string grep, don't verify click/collapse/persistence runtime behavior
  - install regression tests run directly in current repo, uncommitted changes pollute test results
root_cause: logic_error
resolution_type: code_fix
severity: high
tags: [graph, wash, null-reference, label-truncation, regression-testing, safe-localstorage, grapheme, intl-segmenter]
---

# wash graph null reference protection and label truncation unification

## Problem

After v3.0 UX polish, the wash watercolor style interactive graph exposed three issues: optional DOM fragments lacking null protection, card width and label truncation using different width rules, and regression tests only checking static strings. The most severe one (null reference) would cause the graph page to completely white-screen.

## Symptoms

- Opening graph page shows `TypeError: Cannot read properties of null (reading 'querySelector')` in browser console, page white-screens
- Long label node text overflows card right boundary, or truncation point mismatches card width
- Minimap or neighbor section collapse preference lost after refresh (`localStorage` silently fails when unavailable)
- `tests/regression.sh` runs install tests in a repo with uncommitted changes, making assertion results unreliable

## What Didn't Work

- **Direct chained DOM calls**: `drawerNeighbors.querySelector("h4")` crashes when `drawerNeighbors` is null, no null check first (session history: similar DOM assumption failures occurred in the vis-network era)

- **Scattered width rules**: `cardDims()` inlines `if (/[一-鿿]/.test(ch)) w += 15; else w += 8.5`, `truncateLabel()` inlines `const charWidth = g => /[一-鿿]/.test(g) ? 15 : 8.5`, regex ranges and constant values maintained independently, prone to drift

- **Pure string grep tests**: Early regressions only checked if HTML contains `aria-expanded="true"`, didn't verify if the attribute actually changes to `"false"` after click, nor verify `localStorage` persistence

- **Running install tests at repo root**: `tests/regression.sh`'s `test_upgrade_refreshes_claude_companion_skill` and similar cases directly run `bash "$REPO_ROOT/install.sh"`; if workspace has uncommitted changes, install.sh reads files inconsistent with remote main branch

- **Edit tool failed replacing cardDims**: Because the CJK character in the file was escaped differently in JSON parameters, causing multiple "String to replace not found". Ultimately resolved using a `python3` regex replacement script

## Solution

### 1. DOM optional fragment null protection

```javascript
// graph-wash.js:14-15
const drawerNeighbors = document.getElementById("dr-neighbors");
const drawerNeighborsHeading = drawerNeighbors ? drawerNeighbors.querySelector("h4") : null;
```

All subsequent accesses to `drawerNeighborsHeading` (`applyNeighborsCollapsed`, `toggleNeighbors`, event binding) now have `if (!drawerNeighborsHeading) return` or `if (drawerNeighborsHeading) { ... }` wrapping.

Same treatment for `minimapEl` / `minimapToggle`: `renderMinimap()` and `applyMinimapCollapsed()` both have null checks added upfront.

### 2. Unified width constants and helpers

```javascript
// graph-wash.js:185-213
const LABEL_CJK_WIDTH = 15;
const LABEL_LATIN_WIDTH = 8.5;
const LABEL_PADDING = 22;
const LABEL_MIN_WIDTH = 72;
const LABEL_MAX_WIDTH = 180;
const LABEL_ELLIPSIS = "…";
const LABEL_ELLIPSIS_WIDTH = 8;

function splitLabelGraphemes(label) {
  return Array.from(labelSegmenter.segment(label), ({ segment }) => segment);
}
function labelCharWidth(grapheme) {
  return /[一-鿿]/.test(grapheme) ? LABEL_CJK_WIDTH : LABEL_LATIN_WIDTH;
}
function measureLabelWidth(graphemes) {
  let width = 0;
  for (const grapheme of graphemes) width += labelCharWidth(grapheme);
  return width;
}
```

`cardDims()` and `truncateLabel()` both reference `LABEL_*` constants and `measureLabelWidth()` / `splitLabelGraphemes()`, eliminating rule drift.

### 3. cardDims() switched to new helper

```javascript
// graph-wash.js:175-183
function cardDims(n) {
  const label = n.label || n.id;
  const widthByLabel = measureLabelWidth(splitLabelGraphemes(label));
  let width = Math.max(LABEL_MIN_WIDTH, Math.min(LABEL_MAX_WIDTH, widthByLabel + LABEL_PADDING));
  let height = 36;
  if (n.type === "topic") { height = 40; width += 6; }
  if (n.type === "source") { height = 32; }
  return { w: width, h: height };
}
```

### 4. Regression tests upgraded to Node runtime assertions

Three regression scripts (`long-label`, `minimap`, `drawer-neighbors`) upgraded from pure `assert_file_contains` to two-stage:

1. **Static hook check**: grep confirms HTML contains correct `id`, `aria-*`, `data-collapsed` attributes
2. **Runtime behavior verification**: Uses `node - <<'NODE' file.js` + `vm.createContext()` to extract functions, fake DOM element to simulate `setAttribute` / `getAttribute`, verifying:
   - null guard doesn't throw
   - State toggle (collapsed/expanded) correctly updates `data-collapsed` and `aria-expanded`
   - `safeLocalStorage.set()` is correctly called with expected key/value
   - `truncateLabel()` behaves correctly for empty string, short labels, long labels, complex emoji (ZWJ connected)
   - `cardDims()` respects min/max boundaries

### 5. Install test isolation

```bash
# tests/regression.sh:95-100
make_repo_copy_without_git() {
    local dest="$1"
    cp -R "$REPO_ROOT" "$dest"
    rm -rf "$dest/.git"
}
```

Upgrade-related tests changed to `bash "$repo_copy/install.sh"`, no longer using `$REPO_ROOT` directly.

## Why This Works

1. **Null reference root cause**: `document.getElementById()` returns null when element doesn't exist. Calling `.querySelector()` on null throws TypeError. Ternary operator handles the null case at assignment time; subsequent code only needs to check if variable is null.

2. **Width drift root cause**: `cardDims()` and `truncateLabel()` each inline their own width rules, regex ranges and magic numbers maintained independently. After unifying to shared constants and helpers, changing one place auto-syncs.

3. **Test brittleness root cause**: String grep can only verify "code snippet exists", not "behavior is correct". Node `vm` module can execute extracted pure functions without a browser, using fake elements to verify state changes.

4. **Test isolation root cause**: Presence of `.git` directory affects install.sh's path judgment. After copying to temp directory and removing `.git`, install.sh's behavior matches what users get after cloning from GitHub.

## Prevention

- **Optional DOM fragment pattern**: Elements obtained via `getElementById()` must be null-checked before subsequent `.querySelector()` calls. Use ternary `el ? el.querySelector(...) : null` or optional chaining `el?.querySelector(...)`

- **Shared constants**: Magic numbers for dimension/width calculations should be declared as module-level constants; all related functions reference the same set of constants

- **Test layering**: String assertions for checking static content (HTML structure, CSS rules); runtime tests using Node `vm` module or mock DOM to verify interaction logic. The two complement, not replace each other

- **Install test isolation**: Build/install tests execute in a repo copy in a temp directory, using `rm -rf "$dest/.git"` to remove version control info

- **Grapheme-safe truncation**: When truncating user-visible text, use `Intl.Segmenter` to iterate by grapheme cluster rather than code point, avoiding splitting ZWJ emoji (like `👨‍👩‍👧‍👦`) into half an emoji

- **Regression assertion precision**: When checking emoji truncation, don't use `text.includes('\ud83d')` style checks (legitimate emoji also contain these surrogates); use isolated surrogate detection instead: `/\uD800(?![\uDC00-\uDFFF])|(?:^|[^\uD800-\uDBFF])[\uDC00-\uDFFF]/.test(text)`

## Related Issues

- PR: https://github.com/sdyckjq-lab/llm-wiki-skill/pull/21
- Prior decision: [Simplifying from three styles to wash-only single style](../developer-experience/graph-style-simplification-to-wash-only-2026-04-20.md)
- Design doc: `docs/plans/2026-04-21-graph-ux-fixes-design.md`
