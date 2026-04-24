---
title: Simplifying from three graph styles to wash-only single style
date: 2026-04-20
category: developer-experience
module: interactive-graph
problem_type: developer_experience
component: tooling
severity: medium
applies_when:
  - Users test multiple options and find some visual effects unsatisfactory, requiring quick pruning of implemented features
  - Graph templates or UI styles need to be selected/trimmed based on actual visual results
tags: [graph, knowledge-graph, wash, refactor, template, vis-network, d3, roughjs]
---

# Simplifying from three graph styles to wash-only single style

## Context

The `llm-wiki-skill` interactive knowledge graph went through three visual iteration branches:

1. **`feat/interactive-graph`** (Apr 17): vis-network classic version, PR #15 merged. Automated tests all passed, but when users actually opened it they found node overlap, crossing connections forming "yarn balls", and overlapping labels.
2. **`feat/sketchy-graph-redesign`** (Apr 18-19): Multiple rounds of layout optimization on vis-network (force-directed parameter adaptation, isolated node counting, mobile overlay), but vis-network rendering quality ceiling was obvious; user abandoned.
3. **`feat/graph-html-styles-v3`** (Apr 20): Introduced D3 + Rough.js paper (hand-drawn notebook) and wash (watercolor card) templates, planning three coexisting styles. After end-to-end testing only wash was visually acceptable; trimmed to wash-only.

Key lesson: **Passing automated tests does not equal user acceptability**. Graphs must be visually readable to qualify.

## Guidance

### 1. Delete excess templates and vendor files

Delete 11 files (classic's header/footer/vis-network/license + paper directory + moved marked/purify from templates/):

```bash
git rm templates/graph-template-header.html \
       templates/graph-template-footer.html \
       templates/vis-network.min.js \
       templates/LICENSE-vis-network.txt \
       templates/marked.min.js \
       templates/purify.min.js \
       templates/LICENSE-marked.txt \
       templates/LICENSE-purify.txt
rm -rf templates/graph-styles/paper/
```

`deps/` d3.min.js, rough.min.js, marked.min.js, purify.min.js and LICENSE files remain — wash depends on these.

### 2. Simplify build script

`scripts/build-graph-html.sh` simplified from 275 lines (`--style` parameter + three-branch prepare_style + build_one loop) to ~155 lines:

- Removed `--style classic|paper|wash|all` parameter parsing and `POSITIONAL` array
- Removed `prepare_style()` function
- Hardcoded wash paths: `graph-styles/wash/header.html`, `graph-styles/wash/footer.html`
- Output unified to `wiki/knowledge-graph.html` (not `knowledge-graph-wash.html`)
- `ASSET_SPECS` fixed to wash vendor list
- Retained: `__WIKI_TITLE__` placeholder replacement, `</script>` escaping, vendor copying

```bash
# Before: three style branches
prepare_style() {
  case "$style" in
    classic) HEADER="$TEMPLATES_DIR/graph-template-header.html" ... ;;
    paper)   HEADER="$TEMPLATES_DIR/graph-styles/paper/header.html" ... ;;
    wash)    HEADER="$TEMPLATES_DIR/graph-styles/wash/header.html" ... ;;
  esac
}

# After: hardcoded wash
HEADER="$TEMPLATES_DIR/graph-styles/wash/header.html"
FOOTER="$TEMPLATES_DIR/graph-styles/wash/footer.html"
OUTPUT="$WIKI_ROOT/wiki/knowledge-graph.html"
```

### 3. Rewrite regression tests

Three independent regression test files and four graph test functions in `tests/regression.sh` all changed to wash assertions:

- **styles regression**: Assert `knowledge-graph.html` exists, d3/rough/marked/purify/graph-wash.js exist, HTML contains `<script id="graph-data"`, doesn't contain `cdn.jsdelivr.net`, doesn't contain `vis-network.min.js`
- **mobile regression**: Assert `@media (max-width: 900px)` responsive rules, `.drawer` class, `closeDrawer` in graph-wash.js (not in HTML — loaded via `<script src>`)
- **search regression**: Assert HTML contains `search__input`/`search-dropdown`, graph-wash.js contains `setupSearch`/`getElementById("search")`
- **regression.sh**: Two-argument classic call changed to single-argument wash call, vis-network asset assertions changed to d3/rough asset assertions

Pitfall: mobile test initially failed finding `closeDrawer()` in HTML, because wash's JS logic is in `graph-wash.js` (`<script src>` external link) not inline in HTML. Fix: assertion changed to check `graph-wash.js` file.

## Why This Matters

- **Users only care about results**: Three coexisting styles is elegant engineering, but users only need one graph that works. Trimming is more decisive than patching.
- **install.sh auto-adapts**: It uses `cp -R templates/` and `cp -R deps/`, no changes needed — after deleting files, new installations automatically exclude old files.
- **Branch drafts preserved**: The `feat/sketchy-graph-redesign` branch preserves vis-network's multi-round layout optimization attempts (11 commits), not deleted. Can be recovered if vis-network needs re-evaluation later.

## When to Apply

- When multi-option features fail user testing on some options, trim decisively
- Batch deletion of template/vendor files: `git rm` first, confirm `install.sh`'s `cp -R` is unaffected
- Regression test rewrite: when tests assert implementation details of deleted code (function names, CSS class names), update to new implementation in sync

## Examples

**Delete duplicate README entries** (merge duplicate lines):

```markdown
# Before (duplicate)
- **Interactive knowledge graph**: Generate self-contained HTML...
- **Watercolor card style knowledge graph**: Generate self-contained HTML...

# After (merged)
- **Watercolor card style interactive knowledge graph**: Generate self-contained HTML...
```

**CHANGELOG version jump to v3.0**:

```markdown
## v3.0.0 (2026-04-20)

### Added
- **Watercolor card style interactive knowledge graph**: `build-graph-html.sh` generates `wiki/knowledge-graph.html`...

### Removed
- classic (vis-network) and paper (hand-drawn notebook) graph styles and related templates
- `--style` parameter and two-argument compatibility calling convention
```

## Related

- Session history: `feat/sketchy-graph-redesign` branch preserves vis-network layout optimization attempts (not merged)
- Prior work: `docs/solutions/integration-issues/claude-code-hook-pretooluse-to-sessionstart-2026-04-11.md` (SessionStart hook infrastructure)
- Prior work: `docs/solutions/workflow-issues/cache-update-reliability-2026-04-16.md` (cache reliability mechanism)
- Follow-up fix: `docs/solutions/ui-bugs/graph-wash-null-safety-and-label-truncation-fix-2026-04-21.md` (null reference protection and label truncation unification missed after wash-only simplification)
