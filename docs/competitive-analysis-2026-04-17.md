# Competitive Analysis Report: llm-wiki-agent vs llm-wiki-skill

> Focusing on three feature directions: Obsidian integration, knowledge graph visualization, arXiv paper support
> Date: 2026-04-17

## Project Overview

| | **llm-wiki-skill (this project)** | **llm-wiki-agent** |
|---|---|---|
| **URL** | https://github.com/TiM1113/llm-wiki-skill | https://github.com/SamurAIGPT/llm-wiki-agent |
| **Positioning** | Harness-attached Skill, 10 workflow knowledge base | Self-maintained knowledge base Agent, 4 core workflows |
| **Language** | Shell + Markdown | Python + Markdown |
| **Stars** | — | ~1,971 |
| **Data Collection** | **Strong**: source adapters (web/X/YouTube/PDF/notes etc.) | **None**: Requires manual preparation of materials to raw/ |
| **Runtime** | Runs inside Claude Code / Codex / OpenClaw | Independent Python script or Agent-internal |

---

## 1. Obsidian Integration

### Current State

Basic compatibility exists:
- All pages use `[[wikilink]]` bidirectional links (Obsidian native support)
- YAML frontmatter (tags/created/updated etc.)
- Mermaid graphs renderable in Obsidian
- init prompts "Recommend opening with Obsidian"

**Missing**:
- No symlink mounting guide
- No Web Clipper integration instructions
- No Dataview query examples
- No `.obsidian/` workspace configuration

### llm-wiki-agent Approach

Three-tier integration:
1. **Symlink mode**: `ln -sfn ~/llm-wiki-agent/wiki ~/your-obsidian-vault/wiki`, wiki directory mapped to Vault
2. **Web Clipper**: Explicitly recommends Obsidian Web Clipper plugin for clipping web pages, saved to `raw/` for ingest
3. **Graph View optimization**: Suggests excluding `index.md` and `log.md` (`-file:index.md -file:log.md`), preventing them from becoming graph gravity centers
4. **Dataview**: Conceptually mentions using frontmatter `type` and `tags` fields for queries (no concrete examples given)

### Recommendations

**P0 — Add Obsidian usage guide in documentation**:
- Symlink command examples
- Web Clipper configuration instructions (clip to corresponding `raw/` subdirectory)
- Graph View filter suggestions (exclude index.md / log.md)
- Dataview query examples (filter by type/sources)

Implementation cost is minimal (pure documentation), high ROI — the most common user question is "how do I use this with Obsidian."

---

## 2. Knowledge Graph Visualization

### Current State

**graph workflow** (SKILL.md):
- Scans all `[[wikilinks]]`, builds page relationships
- Outputs Mermaid `graph LR` to `wiki/knowledge-graph.md`
- Keeps only top 30 most-referenced nodes when exceeding 50 relationships
- Relationship type vocabulary (implements/depends-on/compares-with/contradicts/derived-from) optionally annotated, AI doesn't auto-label

**Limitations**:
- Only looks at explicit wikilinks, doesn't infer implicit relationships
- Static Mermaid graph, no interaction (search/filter/click-to-expand)
- No community detection (can't see knowledge clusters)
- No graph health report

### llm-wiki-agent Approach

`build_graph.py` (~1244 lines), core design:

**Two-phase edge construction**:
- Pass 1 — Deterministic: regex extraction of `[[wikilink]]`, confidence 1.0
- Pass 2 — Semantic inference: LLM analyzes each page, infers implicit relationships. >= 0.7 is INFERRED, < 0.7 is AMBIGUOUS

**Louvain community detection**: `nx.community.louvain_communities(G, seed=42)`, deterministic seed, auto-discovers knowledge clusters

**Health report**: Isolated nodes, god nodes (degree > mean+2sigma), fragile bridges (only 1 edge between communities), health score

**vis.js interactive HTML**: Search box, edge type checkboxes (EXTRACTED/INFERRED/AMBIGUOUS), confidence slider, right drawer showing Markdown content, built-in Markdown renderer

**Cache + resume**: SHA256 incremental, JSONL records processed pages

### Recommendations

Implement in priority stages:

**P1 — Enhance existing Mermaid graph** (low cost, pure SKILL.md changes):
- Add "implicit relationship inference" step to graph workflow (have AI annotate semantically related node pairs beyond explicit wikilinks)
- Add community clustering annotations to output (use Mermaid subgraph grouping)
- Add graph health summary (isolated node count, largest connected component)

**P2 — Generate vis.js interactive HTML** (medium cost, requires new scripts):
- Reference llm-wiki-agent's vis.js template for self-contained HTML
- Search, filter, click-to-expand
- Requires new `scripts/build-graph-html.sh` or similar

**Not recommended to copy directly**:
- Louvain community detection requires Python + networkx, mismatches this project's Shell/Agent architecture
- Can have AI identify communities "manually" in the graph workflow (higher cost but no new dependencies)

---

## 3. arXiv Paper Support

### Current State

- PDF is already a core built-in source (`local_pdf`, `raw/pdfs/`)
- Agent can directly read PDF content and enter standard ingest
- **No arXiv-specific features**: doesn't recognize arXiv URLs, no auto-download, no paper metadata extraction

### llm-wiki-agent Approach

- Also no built-in arXiv support
- Provides `file_to_markdown.py` (based on Microsoft markitdown) for PDF -> Markdown conversion
- Flow: manually download PDF -> convert -> place in `raw/` -> ingest

### Recommendations

**P0 — Add arXiv source type to source-registry.tsv**:
- Add `arxiv_paper` source, match rule `url_host:arxiv.org`
- During ingest: extract paper ID from URL -> use Harness web capability to download PDF -> save to `raw/pdfs/` -> enter standard PDF ingest
- Metadata extraction (title/author/abstract) can be handled by AI in ingest Step 1

**Cost**: Mainly one configuration line in source-registry.tsv + minor SKILL.md ingest routing logic change, no new scripts needed.

---

## 4. Additional Findings: Other Notable Features

| Feature | llm-wiki-agent Implementation | Value for Us |
|---------|-------------------------------|-------------|
| **heal.py self-repair** | Auto-finds entities referenced 3+ times without pages, uses LLM to generate definition pages | **High** — Can add "auto-fix" step to lint workflow |
| **refresh.py hash detection** | Detects raw/ file changes to auto-trigger re-ingest | **Medium** — Project already has cache.sh, can extend to `status` workflow showing changed files |
| **Domain-specific templates** | Journal/meeting notes etc. specialized templates | **Low** — Current general templates are sufficient, add as needed |
| **Graph-aware lint** | Checks hub stubs / fragile bridges / isolated communities | **Medium** — Naturally follows after P1 graph enhancement |

---

## 5. Summary: Recommended Implementation Priority

| Priority | Feature | Estimated Effort | Type |
|----------|---------|-----------------|------|
| **P0** | Obsidian usage guide (documentation) | 0.5 days | Pure documentation |
| **P0** | arXiv source routing (source-registry + ingest routing) | 0.5 days | Config + minor change |
| **P1** | Graph enhancement (implicit relationship inference + community annotation + health summary) | 1 day | SKILL.md changes |
| **P2** | vis.js interactive graph HTML | 2-3 days | New scripts + templates |
| **P1** | lint self-repair (heal concept) | 0.5 days | SKILL.md changes |
