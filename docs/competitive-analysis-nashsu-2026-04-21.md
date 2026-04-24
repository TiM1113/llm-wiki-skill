---
module: competitive-analysis
tags: [competitive-analysis, knowledge-graph, roadmap]
problem_type: strategy
---

# Competitive Analysis Report: llm-wiki-skill vs nashsu/llm_wiki

> Date: 2026-04-21
> Competitor repo: https://github.com/nashsu/llm_wiki (~2000 stars)
> Our repo: https://github.com/TiM1113/llm-wiki-skill (~1000 stars)

## Context

- **Ours**: llm-wiki-skill (~1000 stars), AI agent skill plugin, runs inside Claude Code/Codex/OpenClaw, pure Shell + Markdown architecture, leverages host agent's LLM capabilities
- **Competitor**: nashsu/llm_wiki (~2000 stars), Tauri v2 desktop app (Rust backend + React frontend), self-contained LLM client, full GUI

Both are based on the Karpathy llm-wiki methodology, sharing the same core architecture (three-layer: raw -> wiki -> schema), but with completely different technical routes and product forms. This analysis focuses on feature gaps, knowledge graph comparison, and future iteration direction.

---

## 1. Product Form Comparison

| Dimension | Ours (llm-wiki-skill) | Competitor (nashsu/llm_wiki) |
|-----------|----------------------|------------------------------|
| Form | Agent skill, runs inside host agent | Standalone desktop app (Tauri v2) |
| Tech Stack | Shell + Markdown templates | Rust backend + React 19 + TypeScript + Vite |
| LLM Source | Host agent's LLM | Self-contained LLM client (supports OpenAI/Anthropic/Google/Ollama/Custom) |
| UI | No GUI, pure conversational | Three-column GUI (knowledge tree + chat + preview) |
| Install | `bash install.sh --platform claude` | Download .dmg/.msi/.deb installer |
| Offline Graph | Self-contained HTML, double-click to open (embedded D3 + rough.js) | In-app sigma.js rendering, requires app launch |
| Multi-platform | Claude Code / Codex / OpenClaw | macOS / Windows / Linux desktop |

**Conclusion**: Different product forms, no direct substitution relationship. Our advantage is zero install barrier (just need existing agent); competitor's advantage is complete GUI experience.

---

## 2. Feature-by-Feature Comparison

### 2.1 Ingest (Material Digestion)

| Feature | Ours | Competitor | Gap Assessment |
|---------|------|-----------|----------------|
| Two-step processing | Step 1 structured analysis (JSON) + Step 2 page generation | Step 1 analysis + Step 2 generation (FILE block parsing) | **Comparable** |
| Format validation | `validate-step1.sh` script validates JSON | FILE block regex parsing | **Ours is stricter** |
| Confidence annotation | EXTRACTED / INFERRED / AMBIGUOUS / UNVERIFIED four-level | None | **Our unique feature** |
| Privacy self-check | Self-check list before each ingest | None | **Our unique feature** |
| Content grading | >1000 chars full / <=1000 chars simplified | Uniform processing | **Ours is finer-grained** |
| SHA256 cache | Yes (with self-healing, rollback, atomic write) | Yes (based on file content hash) | **Comparable** |
| Persistent queue | None (depends on host agent) | Yes (serial processing, crash recovery, 3 retries) | **Competitor leads** |
| Folder import | batch-ingest workflow, pauses every 5 | Recursive import preserving directory structure, folder path as classification context | **Competitor has classification advantage** |
| Progress visualization | Plain text feedback | Activity Panel real-time progress bar | **Competitor leads** (but we're limited by no GUI) |
| Auto embedding | None | Auto-generates vector embeddings after ingest | **Competitor leads** |
| Source tracking | source page + cache | Each page frontmatter `sources: []` | **Competitor is finer-grained** |
| Language guard | Global WIKI_LANG switch | Per-file language detection, rejects files in wrong language | **Competitor is safer** |
| Source traceability | Cache links raw -> source page | `sources: []` array in frontmatter | **Competitor is more systematic** |

### 2.2 Knowledge Graph (Key Comparison)

| Feature | Ours | Competitor | Gap Assessment |
|---------|------|-----------|----------------|
| Graph library | D3.js force-directed + rough.js hand-drawn | sigma.js + graphology + ForceAtlas2 | **Different technical routes** |
| Visual style | Watercolor card style (4 variants: wash/paper/vellum/blueprint) | Standard network graph (nodes + edges) | **Our visual is more distinctive** |
| Offline capability | Self-contained HTML, double-click to open | Requires desktop app launch | **Ours is more portable** |
| Community detection | Topic pages -> communities, top-30 by degree | **Louvain algorithm** auto-clustering + cohesion scores | **Competitor's algorithm is more mature** |
| Edge weights | None (uniform `-->` arrows) | **4-signal relevance model** (direct link x3, source overlap x4, Adamic-Adar x1.5, type affinity x1) | **Competitor leads significantly** |
| Edge rendering | Hand-drawn Bezier curves | Thickness/color varies by weight | **Competitor has more information density** |
| Graph insights | None | **Surprising connections + knowledge gaps + bridge nodes** | **Competitor unique, extremely valuable** |
| Surprising connections | None | Cross-community edges, cross-type connections, peripheral-hub coupling, composite surprise score | **Competitor unique** |
| Knowledge gaps | None | Isolated nodes, sparse communities, bridge node detection, one-click deep research trigger | **Competitor unique** |
| Interaction | Search/filter/node drawer/minimap/zoom | Hover neighbor highlight/click to open page/zoom controls/Insight highlight | **Each has strengths** |
| Node details | Drawer panel (Markdown rendering + wikilink navigation) | Click to open preview panel | **Ours is richer** |
| Position cache | None (re-layout every time) | Yes (avoids layout jumps) | **Competitor experience is better** |
| Cohesion | None | Each community calculates actual edges/possible edges ratio, <0.15 marked as warning | **Competitor unique** |

**Competitor graph core implementation details** (in-depth code analysis):

- **Relevance model** (`graph-relevance.ts`, 313 lines): 4-signal weighted calculation, each node maintains `outLinks`, `inLinks`, `sources`; Adamic-Adar uses `1 / Math.log(Math.max(degree, 2))` weighted common neighbor contribution
- **Louvain clustering** (`wiki-graph.ts`, 305 lines): graphology-communities-louvain algorithm, community cohesion = actual internal edges / possible edges
- **Graph insights** (`graph-insights.ts`, 193 lines): Surprising connections (cross-community+3, cross-type+2, peripheral-hub+2, weak connection+1, threshold>=3), Knowledge gaps (isolated nodes degree<=1, sparse communities cohesion<0.15 and >=3 nodes, bridge nodes connecting >=3 communities)
- **Visualization** (`graph-view.tsx`, 883 lines): sigma.js WebGL rendering + ForceAtlas2 layout, 150 iterations, position cache to avoid re-layout, edge thickness 0.5-4 normalized by weight

### 2.3 Search & Query

| Feature | Ours | Competitor | Gap Assessment |
|---------|------|-----------|----------------|
| Basic search | Grep keyword search | Tokenized search (English tokenizer + stopword removal, CJK bigram) | **Competitor is smarter** |
| Vector search | None | LanceDB + any OpenAI-compatible embedding endpoint | **Competitor unique** |
| Graph expansion | None | Top search results -> seed nodes -> 2-hop traversal + decay | **Competitor unique** |
| Context budget | None | Configurable 4K -> 1M tokens (60% wiki / 20% conversation / 5% index / 15% system) | **Competitor unique** |
| Semantic search | None | Cosine similarity ANN retrieval, recall improved from 58.2% to 71.4% | **Competitor unique** |
| Multi-turn conversation | Depends on host agent | Independent multi-session persistence, configurable history depth | **Form difference** |

### 2.4 Deep Research

| Feature | Ours | Competitor |
|---------|------|-----------|
| Web search | None | Tavily API, multi-query parallel |
| LLM synthesis | None | Auto-synthesizes search results into wiki pages |
| Auto ingest | None | Research results auto-ingest to extract entities/concepts |
| Graph linkage | None | One-click trigger from graph insights, LLM generates domain-aware search topics |
| Confirmation flow | None | Editable research topics and search query confirmation dialog |
| Concurrency control | None | 3 concurrent task queue |

**Competitor deep research implementation details** (`deep-research.ts`, 244 lines):

- Multi-query parallel search -> URL dedup merge -> LLM synthesis into wiki page (with `[[wikilink]]` cross-references) -> save to `wiki/queries/research-{slug}-{date}.md` -> auto ingest to extract entities/concepts
- Graph linkage: Click knowledge gap's "Deep Research" button -> LLM reads overview.md + purpose.md to generate domain-aware search topics (`optimize-research-topic.ts`) -> user can edit and confirm -> start research

### 2.5 Review System

| Feature | Ours | Competitor |
|---------|------|-----------|
| Async review | None | LLM flags items needing human judgment during ingest |
| Predefined actions | None | Create Page / Skip (prevents LLM hallucinating arbitrary actions) |
| Search queries | None | Pre-generated optimized web search queries during ingest |
| Auto sweep | None | sweep-reviews: rule-based matching + LLM semantic judgment for auto-resolution |

### 2.6 File Format Support

| Format | Ours | Competitor |
|--------|------|-----------|
| PDF | Yes | Yes (Rust pdf-extract) |
| Markdown/Text | Yes | Yes |
| DOCX | No | Yes (docx-rs) |
| PPTX | No | Yes (ZIP + XML) |
| XLSX/XLS/ODS | No | Yes (calamine) |
| Image preview | No | Yes |
| Video/Audio | No | Yes (built-in player) |
| Web | Yes (baoyu-url-to-markdown) | Yes (Chrome extension Readability.js) |
| X/Twitter | Yes (baoyu) | Yes (Chrome extension) |
| YouTube | Yes (youtube-transcript) | No |
| Xiaohongshu | Manual paste | No |

### 2.7 Other Features

| Feature | Ours | Competitor |
|---------|------|-----------|
| Chrome Extension | No | Yes (Manifest V3, Readability.js + Turndown.js) |
| KaTeX math | No | Yes (remark-math + rehype-katex + Milkdown) |
| Chain-of-thought display | No | Yes (`<thinking>` block collapsible display) |
| Scenario templates | No | Yes (research/reading/personal growth/business/general) |
| Conversation crystallization | Yes (crystallize workflow) | Save to Wiki (similar but more integrated) |
| Cascading delete | Yes (delete workflow + cache invalidation) | Yes (3-method matching + shared page preservation) |
| SessionStart Hook | Yes (auto-detects wiki) | No (depends on app launch) |

---

## 3. Core Gap Summary

### Our Unique Advantages
1. **Confidence annotation system** — Four-level annotation + traceability, competitor has nothing
2. **Watercolor card style graph** — Visual uniqueness, self-contained offline HTML
3. **Privacy self-check** — Sensitive information check before ingest
4. **Multi-language content sources** — Web articles, X/Twitter, YouTube, Xiaohongshu (manual paste)
5. **Zero-barrier install** — One-line install, no desktop app download needed
6. **Multi-agent platform** — Claude Code / Codex / OpenClaw universal
7. **Ingest format validation** — `validate-step1.sh` independent script validation

### Our Core Gaps (by priority)

**P0 — Decisive Gaps (seriously impact product competitiveness)**

1. **Graph relevance model**: Our graph only has wikilink connections, no edge weights, no source overlap analysis, no Adamic-Adar common neighbor computation. The graph is "flat" — all connections look equally important.
   - Competitor approach: 4-signal relevance model (`graph-relevance.ts`), every edge has a weight score
   - Implementation difficulty: Medium. Need to read frontmatter `sources` field for source overlap, implement Adamic-Adar. Can extend in `build-graph-data.sh`.

2. **Graph insights**: No "surprising connections" or "knowledge gaps" detection. Graph is only a visualization tool, not an analysis tool.
   - Competitor approach: `graph-insights.ts` (193 lines), auto-detects cross-community connections, isolated nodes, sparse communities, bridge nodes
   - Implementation difficulty: Medium. Pure algorithms, no GUI dependency. Can implement in `graph-wash.js` or compute in `build-graph-data.sh`.

3. **Deep Research**: No web search + auto-research capability at all.
   - Competitor approach: `deep-research.ts` (244 lines), Tavily API search -> LLM synthesis -> auto ingest
   - Implementation difficulty: High. Requires search API integration, new workflow design. But as agent skill can leverage host agent's search capabilities.

**P1 — Important Gaps (affect daily usage experience)**

4. **Vector semantic search**: Search relies only on keyword matching, no semantic understanding.
   - Competitor approach: LanceDB (Rust embedded vector DB) + any OpenAI-compatible embedding endpoint
   - Implementation difficulty: High. Requires vector database. But as agent skill, host agent's semantic understanding can compensate.

5. **Source traceability system**: Our traceability isn't systematic enough; each wiki page lacks standardized `sources: []` frontmatter field.
   - Competitor approach: Each page frontmatter has `sources: ["file.pdf"]` field
   - Implementation difficulty: Low. Mainly adding `sources` field to templates, writing during ingest. **This is a prerequisite for the relevance model and graph insights.**

6. **Louvain community detection**: Our simple "topic page -> community" strategy is less accurate than graph theory algorithms.
   - Competitor approach: graphology-communities-louvain algorithm + cohesion scoring
   - Implementation difficulty: Medium. Can implement in `build-graph-data.sh` with awk or simple clustering algorithm.

**P2 — Nice to Have**

7. **Persistent ingest queue**: No crash recovery for batch ingest.
8. **Language guard**: No per-file language detection and rejection.
9. **DOCX/PPTX/XLSX support**: Missing Office document format support.
10. **Math rendering**: No KaTeX/LaTeX support.
11. **Review system**: No async review queue.

---

## 4. Future Iteration Direction Recommendations

Based on gap analysis, recommended priority:

### Phase 1: Strengthen Graph Core Competitiveness (Graph 2.0)

Goal: Upgrade graph from visualization tool to knowledge analysis tool.

1. **Source traceability field** (prerequisite)
   - Add `sources: []` frontmatter field to all page templates
   - Auto-populate during ingest workflow
   - Foundation for subsequent relevance model

2. **4-signal relevance model**
   - Direct link (already have wikilinks)
   - Source overlap (based on `sources: []` field)
   - Adamic-Adar common neighbors
   - Type affinity
   - Compute in `build-graph-data.sh`, output to `graph-data.json` `edges[].weight`

3. **Graph insights module**
   - Compute in `build-graph-data.sh` or standalone script:
     - Surprising connections (cross-community edges, cross-type, peripheral-hub coupling)
     - Knowledge gaps (isolated nodes, sparse communities, bridge nodes)
   - Output to `graph-data.json` `insights` field
   - Add Insights panel UI in `graph-wash.js`

4. **Cohesion scoring + Louvain community detection**
   - Upgrade community detection algorithm
   - Compute cohesion for each community
   - Mark low-cohesion communities in graph

### Phase 2: Deep Research Capability

1. **Deep Research workflow**
   - Add SKILL.md workflow definition
   - Leverage host agent search capabilities (Claude Code's WebSearch, Codex's built-in search)
   - Or integrate search APIs (Tavily / Serper / Bing)
   - Research results auto-ingest
   - Link with graph insights (trigger research from knowledge gaps)

2. **Retrieval pipeline optimization**
   - Structured search (weighted tokenized search)
   - Graph-expanded retrieval (seed nodes + 2-hop traversal)
   - Context budget control

### Phase 3: Experience Polish

1. **Review system** — Flag items needing review during ingest, display and process in lint workflow
2. **Office document support** — DOCX extraction (can use pandoc or Python docx), basic PPTX/XLSX support
3. **Math rendering** — KaTeX rendering in graph HTML

### Directions Not Recommended to Pursue

- **Standalone GUI app**: Our positioning is agent skill; building GUI would deviate from core positioning
- **Chrome extension**: Low ROI, baoyu-url-to-markdown already covers web extraction
- **Vector database**: As agent skill, host agent's semantic understanding is sufficient; introducing LanceDB is overcomplicated
- **Multi-conversation persistence**: Host agent already has this capability

---

## 5. Verification Approach

After each phase completes:

1. **Regression tests**: `bash tests/regression.sh` to ensure existing features aren't broken
2. **Graph verification**: Test graph generation with the 3 articles in `raw-input/`
3. **Pre-push checks**: Follow the three-tier testing rules in CLAUDE.md
4. **Competitive comparison**: Compare graph insight quality on the same set of materials
