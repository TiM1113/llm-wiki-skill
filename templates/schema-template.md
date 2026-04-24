# Wiki Schema (Knowledge Base Configuration)

> This file tells the AI how to maintain your knowledge base. You and the AI can adjust it together.

## Knowledge Base Information

- Topic: {{TOPIC}}
- Created: {{DATE}}
- Language: {{LANGUAGE}}
- Version: 1.1

## Directory Structure

```
{{WIKI_ROOT}}/
├── raw/                    # Raw source materials (read-only for AI)
│   ├── articles/           # Web articles
│   ├── tweets/             # X/Twitter content
│   ├── xiaohongshu/        # Xiaohongshu content
│   ├── pdfs/               # PDF files
│   ├── notes/              # Handwritten notes
│   └── assets/             # Images and attachments
├── wiki/                   # Wiki body (AI writes, you read)
│   ├── entities/           # Entity pages (people, organizations, concepts)
│   ├── topics/             # Topic pages (research topics, knowledge domains)
│   ├── sources/            # Source summary pages (one summary per source)
│   ├── comparisons/        # Comparison analysis pages
│   └── synthesis/          # Synthesis analysis pages
├── index.md                # Content index (table of contents)
├── log.md                  # Operation log (timeline)
└── .wiki-schema.md         # This file (configuration)
```

## Page Naming Conventions

- Entity pages: `wiki/entities/{name}.md`
  - Example: `wiki/entities/Knowledge-Building.md`, `wiki/entities/Transformer.md`
- Topic pages: `wiki/topics/{topic-name}.md`
  - Example: `wiki/topics/AI-Coding-Tools.md`, `wiki/topics/Large-Language-Models.md`
- Source summaries: `wiki/sources/{date}-{short-title}.md`
  - Example: `wiki/sources/2026-04-05-karpathy-llm-wiki.md`
- Comparison analysis: `wiki/comparisons/{comparison-topic}.md`
  - Example: `wiki/comparisons/Tool-Selection.md`
- Synthesis analysis: `wiki/synthesis/{analysis-topic}.md`
  - Example: `wiki/synthesis/AI-Tool-Selection-Guide.md`

## Cross-Reference Conventions

- Use `[[Page Name]]` syntax between pages (Obsidian-compatible bidirectional links)
- Source citation format: `[Source: Source Title](../sources/xxx.md)`
- Maintain a "Related Pages" list at the bottom of each page

## Page Format Conventions

Each wiki page should contain:

```markdown
---
tags: [tag1, tag2]
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: [list of related sources]
---

# Page Title

> One-sentence summary

## Body Content

...

## Related Pages

- [[Another page]]
- [[Yet another page]]
```

## Ingest (Source Digestion) Rules

### Tiered Processing

Sources are automatically tiered based on length and information density:

**Full processing** (source > 1000 words):
1. Each new source **must** generate a summary page (under `wiki/sources/`)
2. Extract 3-5 key concepts from the source
3. Check whether new entity pages need to be created (`wiki/entities/`)
4. Check whether topic pages need to be created or updated (`wiki/topics/`)
5. Update `index.md` (add new entries)
6. Update `log.md` (record the operation)
7. Update `overview.md` (if the overall knowledge landscape has changed)

**Simplified processing** (source < 1000 words, e.g., short tweets, Xiaohongshu posts):
1. Generate a summary page (under `wiki/sources/`)
2. Extract 1-3 key concepts
3. If key concepts already have entity pages, append information; if not, mark `[to be created]` in the summary page
4. Update `index.md` and `log.md`
5. Skip topic pages and overview updates

### Source Boundaries

These boundaries are consistent with installation output, status descriptions, and regression tests.

| Category | Current Sources | Processing Principle |
|----------|----------------|---------------------|
| Core pipeline | `PDF / Local PDF`, `Markdown/Text/HTML`, `Plain text paste` | No plugins needed; enters main pipeline directly |
| Optional adapters | `Web articles`, `X/Twitter`, `YouTube` | Auto-extract first; fall back to manual entry on failure |
| Manual entry | `Xiaohongshu` | Only accepts user-pasted content |

### Source Type Routing

| Source | Raw Directory | Extraction Method |
|--------|--------------|-------------------|
| Web articles | `raw/articles/` | baoyu-url-to-markdown skill |
| X/Twitter | `raw/tweets/` | baoyu-url-to-markdown skill (requires Chrome login) |
| YouTube | `raw/articles/` | youtube-transcript skill |
| Xiaohongshu | `raw/xiaohongshu/` | User manually pastes content |
| PDF / Local PDF | `raw/pdfs/` | Direct read |
| Markdown/Text/HTML | `raw/notes/` | Direct read |
| Plain text paste | `raw/notes/` | Used directly |

## Alias Table

Used to automatically expand search terms during query and digest. Searching for any term will also search all aliases on the same line.
During ingest, if the AI discovers new synonym relationships, it can suggest that the user add them.

Format: one group of synonyms per line, separated by `=`.

```
LLM = Large Language Model
RAG = Retrieval Augmented Generation
fine-tuning = fine-tune
prompt engineering = prompt design
```

Maintenance guidelines:
- Only include synonyms that **actually appear** in your knowledge base; do not pre-fill unused terms
- Keep each group to 5 or fewer; too many suggests the concept itself needs splitting
- When mixing languages, put the most commonly used term first
- When ingest discovers new synonym relationships, the AI should proactively suggest adding them to this table

## Query Rules

1. First read `index.md` to locate relevant entries
2. Use Grep to search for keywords under `wiki/`
3. Read relevant pages and compose a synthesized answer
4. Cite source pages in the answer (with reference links)
5. Save valuable analyses as new wiki pages

## Lint (Health Check) Rules

1. Check scope: randomly sample 10 pages + 10 most recently updated pages
2. Check items:
   - Contradictions between pages (inconsistent claims across different pages)
   - Orphan pages (no other pages link to them)
   - Missing concept pages (linked via `[[Some Concept]]` but the page does not exist)
   - Missing cross-references (related pages not linked to each other)
   - Index consistency (whether `index.md` entries match actual files)
3. Output a report with fix suggestions for each issue
4. If issues are found, ask the user whether to auto-fix

## Relationship Type Vocabulary (optional, for manual knowledge graph annotation)

This table provides **optional** relationship type vocabulary for the `wiki/knowledge-graph.md` generated by the graph workflow.
By default, the AI uses plain `-->` (unlabeled) for all graph edges and does not auto-detect relationship types. If you want the graph to express the semantics between nodes more clearly, you can use an editor to rewrite the most important arrows with labeled notation:

| Type Keyword | Meaning | Mermaid Example |
|-------------|---------|-----------------|
| implements  | A is a concrete implementation of B | `A -->|implements| B` |
| depends-on  | A depends on B to function | `A -->|depends-on| B` |
| compares    | A and B are comparable alternatives | `A -->|compares| B` |
| contradicts | A and B have conflicting viewpoints | `A -->|contradicts| B` |
| derives     | A evolved from B | `A -->|derives| B` |

Usage guidelines:
- Only label the 3-5 most important relationships; do not force-label every arrow
- Keep uncertain relationships as default `-->` arrows
- Limit custom types to 2 or fewer to avoid vocabulary bloat
- After labeling, re-render in Obsidian / VS Code (Markdown Preview Enhanced) / Typora to see the labels
