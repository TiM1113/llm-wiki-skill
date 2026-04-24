# Changelog

## v3.5.0 (2026-04-24)

### Added

- `.wiki-schema.md` adds an "Alias Glossary" section: users maintain synonym groups (e.g., `LLM = Large Language Model`), query and digest searches auto-expand
- query workflow reads alias glossary before searching, expanding all synonyms for user query keywords, then searches with all keywords
- digest workflow also supports alias-expanded search
- After ingest, if new synonym relationships are discovered, proactively suggests user add them to the alias glossary

## v3.4.0 (2026-04-24)

### Added

- source template adds `image_paths` frontmatter field, tracking list of image paths downloaded to `raw/assets/`
- ingest flow (full + simplified) records image count and paths; users can manually or via lint complete them after downloading images
- `lint-runner.sh` adds image asset consistency check: reports missing files when source page declares `image_paths` but files don't exist

## v3.3.1 (2026-04-24)

### Added

- Both full and simplified ingest processing now detect image references (`![`, `<img`, image URLs) after saving source material, reminding users to download to `raw/assets/` to prevent link rot
- source template adds `images` frontmatter field, recording the number of images in the source material

## v3.3.0 (2026-04-24)

### Added

- query/digest/ingest workflows add single-page length limit rules (2000/3000 characters); overly long pages only read frontmatter + key sections, avoiding token waste
- query search results sorted by relevance: filename exact match > index entry match > body keyword match
- Step 1 JSON contract adds `evidence` field: EXTRACTED should include source text excerpts, INFERRED should include reasoning basis; validation script warns on missing
- Added `docs/obsidian.md` Obsidian integration guide: Web Clipper config, Graph View filtering, Dataview query examples, image localization workflow
- Added `scripts/lint-fix.sh` low-risk auto-fix script: adds uncatalogued pages to index.md by section, supports `--dry-run`

## v3.2.1 (2026-04-24)

### Fixed

- `validate-step1.sh` strengthens sub-field validation: entity must have name/type/confidence, topic must have name, connection must have from/to/confidence; missing fields trigger fallback
- `lint-runner.sh` orphan page detection expanded from only `entities/` to `entities/`, `topics/`, `sources/` directories
- `lint-runner.sh` adds reverse index consistency check: file exists but not catalogued in index.md (skips derived pages)
- `cache.sh` self-healing logic tightened: after stem match, also verifies source page frontmatter's `source_path` points to the current raw file; returns `MISS:repaired_needs_verify` instead of `HIT(repaired)` when mismatched

### Tests

- Updated lint regression golden files, added source fixture covering orphan page and reverse index checks
- Updated cache regression test fixtures, source pages now include frontmatter to match self-healing verification logic
- Updated validate-step1 regression tests, entity JSON now includes `type` field to match new validation

## v3.2.0 (2026-04-23)

### Added

- Learning cockpit left-side community navigation panel: desktop uses independent three-column layout (nav | canvas | drawer), narrow screens (<1024px) auto-switch to overlay
- Community leaderboard shows top 3 communities (sorted by is_primary + node_count), each showing name, node count, and source count; primary community has TOP badge
- Clicking a community switches to that community's view; clicking recommended starting point enters path view and auto-opens drawer
- Left-center-right linkage: complete state consistency across six trigger actions — first open, click community, click starting point, click node, switch mode, switch to global
- After community switch, if currently selected node is not in the new visible set, auto-closes drawer (drawer drift fix)
- Non-top-3 community node clicks show inline hint; left panel highlight doesn't jump
- `graph-wash-helpers.js` adds `getCommunityNodeIds()` runtime derivation function; any community's visible node set no longer depends on primary pre-computation
- Added `tests/fixtures/graph-interactive-multicomm/` multi-community test fixture (4 communities, 20 nodes, 30 edges)

### Improved

- `graph-wash.js` community view now derives visible nodes via `activeCommunityId` at runtime, no longer reuses `learning.views.community.node_ids`
- Old `renderLearningPanel()` split into `renderNavPanel()` (left nav) and `updateInsightsTitle()` (title sync), separating responsibilities
- Insights panel no longer hidden/replaced; `#insights-body` always visible
- `focusNode()` adds `openDrawer` parameter; community switch can maintain drawer state

### Tests

- Added 3 unit tests for `getCommunityNodeIds()` (normal match, non-existent community, empty community id)
- Updated HTML regression scripts: added nav-panel related DOM hook assertions, removed old learning-body assertions
- `focusNode` signature change synced in both regression scripts

## v3.1.0 (2026-04-23)

### Added

- Knowledge graph adds "Learning Cockpit": on first open, auto-shows recommended-starting-point-driven learning path instead of default global view
- Added path/community/global three learning mode switches; path mode focuses on recommended starting point and direct neighbors, community mode focuses on largest community
- Side drawer adds learning explanation section: what is this, why look at it now, what to look at next — guiding users through progressive exploration
- Insights panel switches to learning entry in learning mode, showing recommended starting points and community overview
- Search, minimap, and footer bar all adapt to subgraph mode, only searching/showing/counting currently visible nodes
- `graph-analysis.js` adds `buildLearning()` pre-computation function, generating complete learning metadata at build time (degradation waterfall, community stats, recommended starting points)
- `graph-wash-helpers.js` adds 6 learning helper functions (defaultLearning, normalizeLearning, resolveInitialMode, getVisibleNodeIds, getVisibleLinks, shouldAutoOpenDrawer)

### Tests

- Added `tests/js/graph-wash-learning.test.js`, 20 unit tests covering all learning helper functions
- Added `tests/graph-html-learning-cockpit.regression-1.sh`, 5 regression tests covering HTML shell, runtime hooks, and existing feature compatibility
- Updated `tests/expected/graph-data-sample.json` and `graph-data-empty.json` golden files, reflecting new learning fields

## v3.0.7 (2026-04-22)

### Fixed

- `graph-wash-helpers.js` now merges ZWJ emoji, combining diacritical marks, and skin tone modifiers back into the same segment when `Intl.Segmenter` is unavailable; long label truncation in legacy runtimes no longer breaks apart family emoji
- `graph-wash-helpers.js` now exports to both browser globals and CommonJS, preventing desktop shells or mixed runtimes from failing to load helpers and causing the entire page to not initialize
- `build-graph-html.sh` now copies all graph assets first, then replaces the final `knowledge-graph.html`; when helpers are missing, the old working HTML is no longer overwritten with a broken artifact

### Tests

- Added `tests/js/graph-wash-bootstrap.test.js`, covering helper missing and CommonJS + browser dual-export scenarios
- `tests/js/graph-wash-helpers.test.js` adds family emoji boundary assertions under `Intl.Segmenter` fallback
- `tests/graph-build-failures.regression-1.sh` adds helper asset missing regression for preserving old HTML on failure path; `tests/regression.sh` also integrates bootstrap unit tests

## v3.0.6 (2026-04-22)

### Added

- Added `templates/graph-styles/wash/graph-wash-helpers.js`, encapsulating long label truncation, width estimation, and safe storage as reusable helpers shared between browser runtime and Node unit tests
- Added `tests/js/graph-wash-helpers.test.js`, using `node:test` to cover grapheme segmentation, width calculation, label truncation, card dimensions, and safe storage boundary behavior

### Improved

- `graph-wash.js` now reads `truncateLabel`, `cardDims`, and `createSafeStorage` from shared helpers, reducing duplicate logic in the frontend runtime
- `graph-wash.js` now explicitly errors and stops initialization when `graph-wash-helpers.js` is missing or fails to load, instead of throwing hard-to-locate exceptions from top-level destructuring
- `build-graph-html.sh` and wash footer now copy and load `graph-wash-helpers.js` first; long label regression no longer depends on extracting functions from browser scripts via `vm`
- `tests/regression.sh` integrates `graph-html-styles`, `graph-html-search`, `graph-html-mobile` — three previously missed regressions, preventing full regression from skipping graph scenarios

### Tests

- Added `graph-wash-helpers` JS unit tests, integrated into `tests/regression.sh`
- `graph-wash-helpers` unit tests add `Intl.Segmenter` unavailable fallback branch and browser global export branch coverage
- Updated `graph-html-long-label.regression-1.sh` and `graph-html-styles.regression-1.sh`, verifying helpers artifact copy, script load order, and long label behavior

## v3.0.5 (2026-04-22)

### Added

- Added `scripts/lib/source-signal-eligibility.js` shared module, unifying source-signal eligibility logic for 6 page types
- Added `scripts/source-signal-coverage.js` batch scan script, outputting JSON coverage summary
- lint report adds "Check 4: source-signal coverage", listing non-participating pages grouped by reason
- status workflow adds coverage data reporting step, report template adds "Graph source signal coverage" summary

### Improved

- Extracted ~115 lines of duplicate frontmatter parsing and source resolution functions from `graph-analysis.js` to shared module; all graph regression tests pass
- README prerequisites updated: source-signal coverage check requires `node`

### Tests

- Added 31 JS unit/integration tests (`source-signal-eligibility.test.js` 25 + `source-signal-coverage.test.js` 6), covering all 5 eligibility reasons
- Added `tests/lint-output.regression-1.sh` lint output golden diff regression
- `tests/regression.sh` integrates JS unit tests and lint regression

## v3.0.4 (2026-04-22)

### Added

- Added root `HERMES.md` and `platforms/hermes/README.md`, giving Hermes its own installation entry point instead of accidentally consuming Codex-specific prompts
- `install.sh` and `scripts/runtime-context.sh` add `hermes` platform support, default skill directory is `~/.hermes/skills/llm-wiki`
- `README.md`, `README.en.md`, `SKILL.md` add Hermes platform documentation and metadata, keeping shared core unfragmented

### Tests

- `tests/regression.sh` adds Hermes installation and entry document assertions, continuing to protect the four-platform install matrix
- README structure assertions extended to Hermes installation, upgrade, and root `HERMES.md` prompt

### Acknowledgments

- Thanks to [Zihan Zhao](https://github.com/ZZXX-bit) for contributing Hermes platform support

## v3.0.3 (2026-04-21)

### Added

- Graph 2.0 first stage: `build-graph-data.sh` now generates edge weights, source signal availability, Louvain communities, and rule-based insights, stably writing output to `wiki/graph-data.json`
- wash graph frontend adds strong/weak edge visual layering, neighbor strength indicators, and Insights panel; offline HTML can directly view surprising connections / knowledge gaps / bridge nodes
- Added `scripts/graph-analysis.js` and 3 groups of graph regressions, covering helper algorithms, Node/helper failure paths, and Insights panel wiring

### Improved

- `templates/source-template.md` adds `sources: []` contract, allowing graph weights to use source overlap signal instead of relying on flat connections
- Graph search changed to pre-computed index, avoiding full content re-scan on each input
- Graph base build runtime requirement now explicitly requires `jq` + `node`

## v3.0.2 (2026-04-21)

### Fixed

- Graph page no longer crashes from null references when minimap or neighbor section DOM fragments are missing; collapse state initialization is more stable
- `cardDims()` and `truncateLabel()` now use unified grapheme cluster width calculation; truncation results for long labels and complex emoji are consistent
- `tests/regression.sh` upgrade regression now runs in a repo copy with `.git` removed, preventing install tests from being affected by current workspace state

### Tests

- Long label, minimap, and neighbor collapse regressions upgraded to Node runtime assertions, covering guard, state toggle, and persistence behavior
- Install overall regression adds explicit target directory upgrade and README structure assertions, continuing to protect upgrade paths

## v3.0.1 (2026-04-21)

### Improved

- Graph page brand area now links directly to GitHub; wide-screen toolbar buttons changed to "icon + text", making common actions more discoverable
- Long label nodes use safe truncation while preserving full title tooltip, preventing card text overflow
- Minimap and neighbor section support independent collapse, remembering last expanded state
- Detail drawer changed to content-first, neighbor area with limited height, making long content browsing more stable
- Graph styles add `prefers-reduced-motion`, `aria-expanded`, keyboard Enter/Space triggers, and other accessibility details

### Tests

- Added graph UX shell regressions: brand link, long label truncation, minimap collapse, toolbar labels, neighbor collapse, a11y
- `tests/regression.sh` now serially runs the above graph UX regressions, preventing full regression from missing them

## v3.0.0 (2026-04-20)

### Added

- **Watercolor card style interactive knowledge graph**: `build-graph-html.sh` generates `wiki/knowledge-graph.html`, using d3 + rough.js watercolor card style, offline double-click to view (search, filter, community clustering, node detail drawer)
- `templates/graph-styles/wash/`: wash watercolor card graph template (header / footer / graph-wash.js)
- `deps/d3.min.js`, `deps/rough.min.js`: local vendor, no CDN dependency
- `tests/graph-html-styles.regression-1.sh`: regression tests covering local vendor, template injection, and offline asset copy

### Removed

- classic (vis-network) and paper (hand-drawn notebook) graph styles and related templates, vendor assets
- `--style` parameter and two-argument compatibility calling convention

### Improved

- `scripts/build-graph-html.sh`: Simplified to wash-only single style output, cleaner interface
- Graph runtime: reads embedded `graph-data` JSON, with DOMPurify sanitization for markdown detail panels

## v2.6.0 (2026-04-17)

### Added

- **Interactive knowledge graph HTML**: Double-click `wiki/knowledge-graph.html` to view interactive knowledge graph in browser (search, filter, community clustering, node detail drawer, keyboard shortcuts)
- `scripts/build-graph-data.sh`: Scans wiki directory to generate `graph-data.json` (nodes/edges/community clustering/U2 top-30 algorithm/2MB degradation protection)
- `scripts/build-graph-html.sh`: Concatenates header + graph-data.json + footer to generate self-contained HTML, copies vendor assets
- `templates/graph-template-header.html`: Brand bar + toolbar + three-column skeleton + CSS variables + ARIA
- `templates/graph-template-footer.html`: vis.js initialization + 11 interaction states + keyboard shortcuts
- `templates/vis-network.min.js` + `marked.min.js` + `purify.min.js`: vendor trio with corresponding licenses
- `SKILL.md` workflow 8 adds Step 2b (generate graph-data.json) and Step 2c (generate HTML)
- 14 regression tests covering 13 code paths in build-graph-data.sh and build-graph-html.sh

### Fixed

- `build-graph-data.sh`: bash 3.2 full-width character `$OUTPUT` variable name mis-parsing, changed to `${OUTPUT}` explicit delimiting

## v2.5.0 (2026-04-16)

### Added

- `scripts/create-source-page.sh`: source page write and cache update bound as atomic operation; auto-updates `.wiki-cache.json` after write, auto-rollback on failure
- `scripts/cache.sh check`: MISS reason breakdown (`no_entry` / `hash_changed` / `no_source`), AI can give different prompts based on reason
- `scripts/cache.sh check`: Self-healing cache check; when no cache entry exists but source page does, auto-repair via filename stem exact match (returns `HIT(repaired)`)

### Improved

- `SKILL.md` ingest workflow: source page write now uses `create-source-page.sh`; Step 12 no longer separately calls `cache.sh update`

## v2.4.0 (2026-04-15)

### Added

- `platforms/claude/companions/llm-wiki-upgrade/SKILL.md`: `/llm-wiki-upgrade` included with Claude installation, allowing direct updates from the command entry

### Improved

- `install.sh`: Restored Claude-specific companion command install and upgrade sync; GitHub address install and `/llm-wiki-upgrade` routes now share the same update boundary
- `README.md`, `CLAUDE.md`, `platforms/claude/CLAUDE.md`: Added usage instructions for `/llm-wiki-upgrade`, clarifying that default only updates core mainline

## v2.3.0 (2026-04-15)

### Improved

- `install.sh`: Default install and default upgrade only prepare core wiki mainline; web, X/Twitter, WeChat Official Accounts, YouTube, Zhihu extraction changed to explicit `--with-optional-adapters`
- `README.md`, `AGENTS.md`, `CLAUDE.md`, platform entries: Unified documentation of "core available by default, URL auto-extraction opt-in", clarifying that `--target-dir` needs the final `llm-wiki` directory

### Fixed

- `install.sh`: Fixed `--upgrade --target-dir <...>/llm-wiki` being overridden by default platform directory; custom skill directory now upgrades to the correct location
- `install.sh`: When target directory doesn't exist, upgrade command now explicitly fails instead of falsely reporting "upgrade complete"
- `scripts/adapter-state.sh` + `scripts/runtime-context.sh`: Unified source directory, installed directory, and upgrade target directory determination, preventing status checks from drifting across different run locations
- `tests/regression.sh`, `tests/adapter-state.sh`: Regression matrix changed to protect "core available by default, optional extraction explicitly enabled" boundary

## v2.2.0 (2026-04-14)

### Added

- `scripts/lint-runner.sh`: lint mechanical check script (orphan pages / broken links / index consistency), independent of AI judgment
- `tests/fixtures/lint-sample-wiki/`: lint script regression test fixtures (including `C++` special characters, alias links `[[X|Display]]`, orphan pages, and other edge cases)
- `tests/expected/lint-output.txt`: lint script expected output
- SKILL.md digest multi-format templates: deep report, comparison table, timeline — three output formats and file naming conventions
- SKILL.md digest routing table: added "compare/timeline" trigger words
- `templates/schema-template.md` relationship type vocabulary: optional graph relationship annotation terms (implements/depends-on/compares-with/contradicts/derived-from)
- SKILL.md ingest privacy self-check: mandatory y/n privacy check flow on first ingest entry

### Improved

- SKILL.md lint workflow: split into "Step 0 script mechanical check + AI-level judgment" two stages
- SKILL.md graph workflow: clarified that AI defaults to plain unlabeled arrows; relationship vocabulary is for manual beautification only
- CLAUDE.md: Added "pre-push testing rules" (three-tier verification strategy), removed usage order list duplicated with SKILL.md

### Fixed

- `lint-runner.sh`: `INDEX_FILE` path changed from `$WIKI_DIR/index.md` to `$WIKI_ROOT/index.md` (consistent with schema-defined directory structure)
- Test fixture `lint-sample-wiki`: `index.md` moved from `wiki/` to wiki root directory, matching schema convention

## v2.1.0 (2026-04-13)

### Added

- `scripts/validate-step1.sh`: ingest Step 1 JSON format validation script, checking required fields and confidence value legality
- `templates/synthesis-template.md`: crystallize page template
- SKILL.md confidence assignment rules: clarified EXTRACTED/INFERRED/AMBIGUOUS/UNVERIFIED criteria
- SKILL.md Step 1 validation flow: calls validate-step1.sh after Step 1, auto-fallback on failure
- SKILL.md workflow 10 crystallize: crystallizes conversation content into wiki/synthesis/sessions/ pages
- SKILL.md routing table: added crystallize keyword routing

### Improved

- `scripts/init-wiki.sh`: Creates `wiki/synthesis/sessions/` subdirectory and `.gitignore` (excludes `.wiki-tmp/`)
- `tests/regression.sh`: Added 9 tests covering validate-step1.sh behavior and SKILL.md content locks

## v2.0.0 (2026-04-11)

### Added

- `purpose.md` research direction template: generated directly after initialization, providing clear direction for subsequent organization
- `.wiki-cache.json` local cache: infrastructure for skipping duplicate source materials
- `query` result persistence template: supports writing synthesized answers back to `wiki/queries/`
- delete workflow documentation and helper scripts: supports cascading deletion of source materials with reference scanning
- Claude Code `SessionStart hook` support: can inject wiki context prompts at session start

### Improved

- `SKILL.md`: Refactored `ingest` into two-step flow, added cache check, confidence annotation, and degradation documentation
- `SKILL.md`: `batch-ingest` adds no-change skip statistics; `status` adds `purpose.md` status display
- `SKILL.md`: `query` adds duplicate detection, `derived: true` marking, and self-reference protection
- `SKILL.md`: `lint` adds confidence report and EXTRACTED spot-check documentation
- `wiki-compat.sh`: Reports `purpose.md` and `.wiki-cache.json` status during legacy wiki compatibility
- `install.sh`: Supports registering and removing Claude Code's `SessionStart hook`
