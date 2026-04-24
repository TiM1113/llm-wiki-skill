---
name: llm-wiki
version: 3.3.0
author: sdyckjq-lab
license: MIT
description: |
  Personal knowledge base construction system (based on Karpathy's llm-wiki methodology).
  Let AI continuously build and maintain your knowledge base, supporting multiple source types
  (web pages, tweets, Xiaohongshu, YouTube, PDF, local files),
  automatically organized into a structured wiki.
  Trigger conditions: the user explicitly mentions "knowledge base", "wiki", or "llm-wiki",
  or requests operations on an already-initialized knowledge base such as ingest, query,
  health check, etc. Do NOT trigger when the user simply asks to "summarize this article"
  — there must be clear knowledge-base-related intent.
metadata:
  hermes:
    tags:
      - knowledge-base
      - wiki
      - research
      - note-taking
---

# llm-wiki — Personal Knowledge Base Construction System

> Turn fragmented information into a continuously growing, interlinked knowledge base. You just provide the sources — AI handles all the organizing.

## What This Skill Does

llm-wiki helps you build a **continuously growing personal knowledge base**. It is not traditional note-taking software, but an AI-maintained wiki system:

- You provide sources (links, files, text), and AI extracts core knowledge and organizes it into interlinked wiki pages
- The knowledge base grows richer with each use, rather than starting from scratch every time
- All content is stored as local markdown files, viewable with Obsidian or any editor

## Core Philosophy

The problem with traditional approaches (RAG/chat history): every time you ask a question, the AI has to re-read raw files from scratch with no accumulation. The value of a knowledge base lies in **knowledge being compiled once and then continuously maintained**, rather than re-derived each time.

## Quick Start

Tell the user these two steps are all they need:

1. **Initialize**: Say "help me initialize a knowledge base"
2. **Add sources**: Give a link or file and say "help me ingest this"

---

## Script Directory

Scripts located in `scripts/` subdirectory.

**Path Resolution**:
1. `SKILL_DIR` = this SKILL.md's directory
2. Script path = `${SKILL_DIR}/scripts/<script-name>`

---

## Dependency Check

The core pipeline (local files, plain text, existing knowledge base operations) does not require these extraction dependencies by default.

Only check the following optional dependencies when the user provides a URL-type source and explicitly wants automatic extraction of web pages / X / YouTube content.

If missing, prompt the user to run:

```bash
bash ${SKILL_DIR}/install.sh --platform <current-platform> --with-optional-adapters
```

Optional dependency skills / tools:
- `baoyu-url-to-markdown` — general web pages, X/Twitter
- `youtube-transcript` — YouTube transcript extraction

Even if these dependencies are missing, the skill still works (users can directly provide local files, paste text, or fall back to manual entry).

## Adapter State Model

Adapter failures are uniformly classified into five categories: `not_installed / env_unavailable / runtime_failed / unsupported / empty_result`.

Whenever you need to enumerate sources or read `source_label`, `raw_dir`, `adapter_name`, `fallback_hint`, first read the source registry:

```bash
bash ${SKILL_DIR}/scripts/source-registry.sh list
```

To get a single source definition, use:

```bash
bash ${SKILL_DIR}/scripts/source-registry.sh get <source_id>
```

For URL-type sources, first run:

```bash
bash ${SKILL_DIR}/scripts/adapter-state.sh check <source_id>
```

`adapter-state.sh check` returns 8 columns:

```text
source_id	source_label	state	state_label	detail	recovery_action	install_hint	fallback_hint
```

- `not_installed`: Prompt the user that they can install it, while also allowing manual entry
- `env_unavailable`: Explain the missing environment prerequisites, while also allowing manual entry
- `runtime_failed`: Explain that this extraction attempt failed; allow one retry, then fall back to manual entry
- `unsupported`: Provide the manual entry path directly; do not attempt automatic extraction
- `empty_result`: Explain that automatic extraction did not retrieve valid content; ask the user to manually provide the text

After automatic extraction has actually run, execute:

```bash
bash ${SKILL_DIR}/scripts/adapter-state.sh classify-run <source_id> <exit_code> <output_path>
```

Use the returned `detail`, `recovery_action`, `install_hint`, `fallback_hint` to generate prompts. The core pipeline must not be interrupted by adapter failures.

---

## Workflow Routing

Route to the corresponding workflow based on user intent:

| User Intent Keywords | Workflow |
|---|---|
| "initialize knowledge base", "new wiki", "create knowledge base" | → **init** |
| URL / file path / "add source", "ingest", "organize" / direct link | → **ingest** |
| "batch ingest", "organize all of these" / folder path provided | → **batch-ingest** |
| "about XX", "query", "what is XX", "summarize" | → **query** |
| "tell me about XX", "deep analysis of XX", "overview of XX", "digest XX" | → **digest** |
| "compare X and Y", "differences between X and Y", "organize a timeline", "chronological order" | → **digest** (specific format) |
| "check knowledge base", "health check", "lint" | → **lint** |
| "knowledge base status", "what do we have", "how many sources" | → **status** |
| "draw a knowledge graph", "show connections", "graph", "knowledge base map" | → **graph** |
| "delete source", "remove", "delete source", "remove" | → **delete** |
| "crystallize", "crystallize", "save this to the knowledge base", "this conversation is valuable" | → **crystallize** |

**Important**: If the user directly provides a URL or file without explicitly stating what to do, default to the **ingest** workflow. If the knowledge base does not yet exist, automatically run **init** first, then **ingest**.

---

## Common Pre-checks

All workflows except `init` run this check by default:

1. First check whether the **current working directory** contains `.wiki-schema.md`
   - If it does → use the current directory as the knowledge base root path
   - If it does not → fall back to reading `~/.llm-wiki-path`
2. If neither exists:
   - `ingest` / `batch-ingest` → run `init` first
   - `query` / `lint` / `status` / `digest` / `graph` / `delete` → prompt the user to initialize a knowledge base first
3. Read `.wiki-schema.md` from the knowledge base root directory
4. Determine `WIKI_LANG` from the language field in `.wiki-schema.md`
   - `语言：中文` → `WIKI_LANG=zh`
   - `语言：English` → `WIKI_LANG=en`
   - Field missing → default `WIKI_LANG=zh`

## Output Language Rules

All user-facing output and newly written wiki content is generated according to `WIKI_LANG`:

- `WIKI_LANG=zh` → use Chinese
- `WIKI_LANG=en` → use natural English with the same structure, information density, and order
- File paths, wiki links, and directory names retain existing conventions and do not change due to language switching

**Terminology Mapping**:
- Source
- Entity
- Topic
- Summary
- Synthesis
- Ingest
- Comparison
- Deep Dive Report
- Knowledge Graph

---

## Workflow 1: init (Initialize Knowledge Base)

### Pre-checks (Including Multi-Wiki CWD Check)

1. First check whether the **current working directory** contains `.wiki-schema.md`
   - If it does → the current directory is already a knowledge base; inform the user it exists and ask whether to re-initialize
2. If the current directory does not → read the `~/.llm-wiki-path` file
   - If it exists → inform the user that a knowledge base already exists (show the path); ask whether to create a new one or switch to that one
3. Neither exists → proceed with initialization

### Steps

1. **Ask for the knowledge base topic** (prompt the user first):
   - "What topic should your knowledge base focus on? For example, 'AI Learning Notes', 'Product Competitor Analysis', 'Reading Notes'"
   - If the user has no preference, default to "My Knowledge Base"

2. **Ask for the knowledge base language** (prompt the user first):
   - "What language should the knowledge base content use? English / Chinese (default: English)"
   - Options: `en` (English) or `zh` (Chinese)
   - If the user does not specify, default to `en`
   - Record the choice as `WIKI_LANG` (`zh` or `en`)

3. **Ask for the save location** (prompt the user first):
   - Default: `~/Documents/my-wiki/`
   - The user can customize the path

4. **Run the initialization script**:
   ```bash
   bash ${SKILL_DIR}/scripts/init-wiki.sh "<path>" "<topic>"
   ```

5. **Provide supplementary initialization notes**:
   - `init-wiki.sh` also generates `purpose.md` and `.wiki-cache.json`
   - `purpose.md` is stored alongside `.wiki-schema.md` and records research goals, key questions, and research scope
   - Remind the user to fill in core goals and key questions first; these are written in `purpose.md`, and subsequent ingests will prioritize directions listed there

6. **Write language configuration and localize seed files**:
   - Replace `语言：{{LANGUAGE}}` in `.wiki-schema.md` with:
     - `zh` → `语言：中文` (seed files remain in Chinese; no additional processing needed)
     - `en` → `语言：English`, **and also** overwrite the following seed files with English versions:
   - If `WIKI_LANG=en`, read `${SKILL_DIR}/templates/index-en-template.md`, `${SKILL_DIR}/templates/overview-en-template.md`, `${SKILL_DIR}/templates/log-en-template.md`, replace `{{DATE}}` and `{{TOPIC}}` with actual values, then write them to `index.md`, `wiki/overview.md`, `log.md` respectively

7. **Record the path** to `~/.llm-wiki-path`:
   ```bash
   echo "<path>" > ~/.llm-wiki-path
   ```

8. **Output onboarding guide** (switch language based on `WIKI_LANG`):

   ```
   Knowledge base created! Path: <path>

   What you can do next:
   - Give me a link and I'll automatically extract and organize it (web pages, X/Twitter, etc.)
   - For Xiaohongshu content, please paste the text directly (automatic extraction not yet supported)
   - Give me a local file path (PDF, Markdown, etc.)
   - Paste text content directly
   - Batch ingest: give me a folder path

   Recommended: Open this folder in Obsidian to see the knowledge base being built in real time.
   ```

---

## Workflow 2: ingest (Ingest Source)

This is the most critical workflow. The user provides a source, and AI handles all the organizing.

### Pre-checks

Execute the **common pre-checks** (defined above).

### Privacy Self-check Prompt (Must execute on first entry into ingest)

Before starting any extraction or analysis, the AI **must** say the following to the user and then wait for confirmation:

> Before analyzing this source, please quickly confirm that it does **not** contain any of the following sensitive information:
>
> - Phone numbers (e.g., 138xxxxxxxx)
> - National ID numbers (18-digit numbers)
> - API keys (`sk-...`, `AIzaSy...`, `OPENAI_API_KEY=`, `ANTHROPIC_API_KEY=`, `Bearer ...`)
> - Plaintext passwords (`password=`, `passwd=`)
> - Any other personal information you do not want in the knowledge base
>
> If the source contains any of the above, please remove or redact them with a text editor before continuing.
> llm-wiki does **not** automatically filter this content — processed content will enter your knowledge base.
>
> Reply `y` to confirm none of the above are present, or `n` to abort.

**Flow rules**:

- User replies `y` (or "yes", "continue", "none", or other clear affirmative) → proceed with subsequent steps
- User replies `n` (or "stop", "cancel", or other clear negative) → terminate this ingest and prompt the user to clean up before trying again
- Other ambiguous replies → ask once more, up to two times; if neither attempt yields a clear y/n, terminate
- **Bypass rule**: If the user has already explicitly stated "there is no sensitive information in the source, just start" in the current conversation, or the user is within a `batch-ingest` flow (already confirmed once at the top level), AI may skip this step

**Why a self-check list instead of a script**:
- Regex has a high false-positive rate in unstructured text (chat logs, notes), missing real sensitive data while flagging harmless words
- Giving the user the judgment is more reliable than letting a script decide
- More beginner-friendly — users won't encounter confusing script errors

### Source Extraction Routing

Automatically route to the best extraction method based on source type:

**Adapter pre-check logic**:

- For URLs, first call `bash ${SKILL_DIR}/scripts/source-registry.sh match-url "<url>"`
- For local files, first call `bash ${SKILL_DIR}/scripts/source-registry.sh match-file "<path>"`
- For pasted plain text, directly call `bash ${SKILL_DIR}/scripts/source-registry.sh get plain_text`
- `source-registry.sh` returns 10 columns: `source_id`, `source_label`, `source_category`, `input_mode`, `match_rule`, `raw_dir`, `adapter_name`, `dependency_name`, `dependency_type`, `fallback_hint`
- Call `bash ${SKILL_DIR}/scripts/adapter-state.sh check <source_id>`
- Read `state`, `detail`, `recovery_action`, `install_hint`, `fallback_hint` from the 8-column result of `adapter-state.sh check`
- If `state=not_installed` / `env_unavailable` / `unsupported` → do not call the adapter; directly inform the user of next steps using `detail`, `recovery_action`, `install_hint`, `fallback_hint`
- Only proceed with automatic extraction when the return value is `available`

**URL-type sources** (unified via source registry, no hardcoded domain table):

> **Chrome note** (only when `adapter_name=baoyu-url-to-markdown`):
> adapter-state.sh check separates "extractor available" from "whether a reusable session exists on port 9222".
> If check returns `available`, call the adapter normally; even if detail indicates no 9222 session was detected, proceed anyway. baoyu-url-to-markdown handles Chrome launch on its own — **continue execution, do not wait for user confirmation**.
> You only need to manually open port 9222 if you want to reuse a currently logged-in Chrome session.
> If extraction still fails (typically because the page requires a login session, such as X/Twitter, etc.), you can prompt the user to open the debug port to reuse their logged-in session: `open -na "Google Chrome" --args --remote-debugging-port=9222`

- If `source_category=manual_only` → do not call the adapter; directly use `fallback_hint`
- If `adapter_name=youtube-transcript` → call `youtube-transcript`
- If `adapter_name=baoyu-url-to-markdown` → call `baoyu-url-to-markdown`

**Local files**:
- Unified via `bash ${SKILL_DIR}/scripts/source-registry.sh match-file "<path>"`
- After matching, read the file directly without calling an adapter

**Pasted plain text**:
- Uniformly treated as `plain_text`
- Directly use the user-provided text

**Unified fallback rules**:

- For automatic extraction results, uniformly run `bash ${SKILL_DIR}/scripts/adapter-state.sh classify-run <source_id> <exit_code> <output_path>`
- Read `state`, `detail`, `recovery_action`, `fallback_hint` from the 8-column result of `classify-run`
- If `runtime_failed` is returned → inform the user using `detail`, `recovery_action`, `fallback_hint`: "This automatic extraction failed. You can retry once; if it still fails, fall back to manual entry."
- If `empty_result` is returned → inform the user using `detail`, `recovery_action`, `fallback_hint`: "Automatic extraction did not retrieve valid body text. Please manually provide the text to continue."
- Other states also use the same returned result; do not write a second set of fallback messages

### Content Tiered Processing

Automatically select the processing tier based on source length and information density:

**Criteria**:
- Source content > 1000 characters → **full processing**
- Source content <= 1000 characters (short tweets, Xiaohongshu notes, etc.) → **simplified processing**

### Full Processing Flow (Long sources > 1000 characters)

1. **Extract source content**: Obtain the source text via the routing above

2. **Save raw source** to the corresponding `raw/` directory:
   - Save to the appropriate directory based on source type (articles/, tweets/, xiaohongshu/, etc.)
   - Filename format: `{date}-{short-title}.md`
   - For URL-type sources, record the original URL at the top of the file

   **Image detection and tracking**: After saving the source, scan the content for image references (`![` or `<img` or `.png`/`.jpg`/`.gif`/`.svg` URLs). If images are detected:
   - Tell the user: "The source contains {N} image references. Image links may expire — consider manually downloading them to `raw/assets/` (Obsidian users can bind a hotkey in settings to download attachments in one click)"
   - In the subsequent source page's frontmatter:
     - `images`: record the number of detected image references
     - `image_paths`: if the user has already downloaded images to `raw/assets/`, record paths in YAML block list format; if not yet downloaded, keep as an empty array `[]`. Example:
       ```yaml
       image_paths:
         - raw/assets/2026-01-15-fig1.png
         - raw/assets/2026-01-15-fig2.jpg
       ```
   - Do not block the ingest flow; this is informational only
   - After the user downloads images later, they can manually update `image_paths` in the source page, or have AI assist during the next lint

3. **Read context**:
   - Priority order: `purpose.md` > `.wiki-schema.md` > `index.md`
   - If `purpose.md` exists, first read its core goals, key questions, and research scope
   - Use `purpose.md` to guide subsequent entity, topic, and connection selection and weighting

4. **Cache check**:
   - Before entering LLM processing, first run:
     ```bash
     bash ${SKILL_DIR}/scripts/cache.sh check "<raw file path>"
     ```
   - If it returns `HIT` or `HIT(repaired)` → skip this LLM call, directly read existing wiki pages, and tell the user "no changes detected, reusing existing results"
     - `HIT(repaired)` indicates cache self-heal was successful (the previous update was skipped but the source page exists and source_path matches)
   - If it returns `MISS:<reason>` → continue with the two-step flow below
     - `MISS:no_entry` — first time processing this source (normal case)
     - `MISS:hash_changed` — source content has changed; needs reprocessing
     - `MISS:no_source` — cache entry exists but the source page was deleted
     - `MISS:repaired_needs_verify` — found a source page with the same name but source_path does not match; needs reprocessing to confirm correct association

5. **Step 1: Structured analysis**:
   - Input: raw content + `purpose.md` + existing wiki structure (read at least the `index.md` overview)
   - Output: JSON-format analysis result, not persisted, only passed temporarily within the current ingest flow
   - JSON must contain at least `entities`, `topics`, `connections`
   - `confidence` is a required field; if missing, treat as a format anomaly and trigger single-step fallback

   ```json
   {
     "source_summary": "one-sentence summary",
     "entities": [{"name": "xxx", "type": "concept", "relevance": "high", "confidence": "EXTRACTED", "evidence": "excerpt from source or reasoning basis"}],
     "topics": [{"name": "xxx", "importance": "high"}],
     "connections": [{"from": "A", "to": "B", "type": "causal", "confidence": "INFERRED", "evidence": "reasoning basis"}],
     "contradictions": [{"claim_a": "...", "claim_b": "...", "context": "..."}],
     "new_vs_existing": {"new_entities": [], "updates": []}
   }
   ```

   Confidence assignment rules (Claude must follow):
   - EXTRACTED: Information appears directly in the source text and can be found verbatim. **Should provide a source excerpt in the `evidence` field** (recommended <= 50 characters); missing evidence triggers a WARN from the script but does not block
   - INFERRED: Information is inferred from multiple parts of the source text; the source does not state it directly. **Should explain the reasoning basis in the `evidence` field**; missing evidence triggers a WARN from the script but does not block
   - AMBIGUOUS: The source text is unclear or has ambiguity. `evidence` is optional
   - UNVERIFIED: Information comes from Claude's background knowledge; no evidence in the source. `evidence` is optional

   After Step 1 is complete, validation must be performed:
   1. mkdir -p {wiki_root}/.wiki-tmp
   2. Write the Step 1 JSON to {wiki_root}/.wiki-tmp/step1-latest.json
   3. Call bash ${SKILL_DIR}/scripts/validate-step1.sh {wiki_root}/.wiki-tmp/step1-latest.json
   4. Delete {wiki_root}/.wiki-tmp/step1-latest.json after validation completes

   If the script returns non-zero, automatically fall back to single-step ingest (do not proceed to Step 2).

6. **Step 2: Page generation**:
   - Input: raw content + `purpose.md` + Step 1 analysis results + existing related wiki pages
   - **Context loading rule**: Only read existing pages listed in Step 1's `new_vs_existing.updates`; if a page exceeds 2000 characters, only read the frontmatter + sections that need updating
   - Output: All wiki page content that needs to be created or updated
   - Step 2 is responsible for completing the source summary, entity pages, topic pages, index, and log updates from the original flow

7. **Error recovery fallback**:
   - If Step 1 is not valid JSON, or is missing required fields like `entities`, `topics`, `confidence`, automatically fall back to the original single-step flow
   - During fallback, all newly generated content in this session uniformly receives:
     ```markdown
     <!-- confidence: UNVERIFIED -->
     ```
   - Also add a comment at the top of the page explaining that this processing was downgraded due to format issues, to avoid a "partially annotated, partially not" state

8. **Generate source summary page** (`wiki/sources/{date}-{short-title}.md`):
   - Follow the format from `templates/source-template.md`
   - Keep the `sources: []` field in frontmatter; if this ingest has explicit sources, fill in actual raw/source references
   - Include: basic information, core insights, key concepts, connections to other sources, notable excerpts from the original
   - For relationships marked as `INFERRED` or `AMBIGUOUS` in Step 1, preserve confidence via HTML comments:
     ```markdown
     <!-- confidence: INFERRED -->
     <!-- confidence: AMBIGUOUS -->
     ```
   - **When writing the source page, you must use `create-source-page.sh`** (automatically updates cache):
     ```bash
     # First write the page content to a temp file
     echo "<page content>" > /tmp/source-content.tmp
     # Call the script for atomic write + cache update
     bash ${SKILL_DIR}/scripts/create-source-page.sh "<raw file path>" "wiki/sources/{date}-{short-title}.md" /tmp/source-content.tmp
     ```
   - If the script returns `SUCCESS` → both the write and cache have been updated
   - If the script returns `ERROR` → the write or cache failed; check the error message and retry

9. **Update or create entity pages** (`wiki/entities/`):
   - For each key concept, check whether a corresponding page already exists under `wiki/entities/`
   - If it exists → append new information, update the "perspectives from different sources" section
   - If it does not exist → create a new entity page, following `templates/entity-template.md`
   - Use `[[entity name]]` syntax for bidirectional linking

10. **Update or create topic pages** (`wiki/topics/`):
   - Identify the main research topics covered by the source
   - If a corresponding topic page already exists → update the source summary table and core insights
   - If it does not exist → create a new topic page, following `templates/topic-template.md`

11. **Update index.md**:
   - Add new entries under the corresponding category
   - Update overview statistics

12. **Update log.md**:
   - log.md append format: `## {date} ingest | {source title}`
   - Record the list of newly added and updated pages
   - Note: cache update was already completed automatically in Step 8 via `create-source-page.sh`; no need to call `cache.sh update` here

13. **Display results to the user** (switch language based on `WIKI_LANG`):

   ```
   Ingested: {source title}

   New pages:
   - {source summary page}
   - {new entity page 1}
   - {new topic page 1}

   Updated pages:
   - {existing entity page 2} (appended new information)

   Connections found:
   - This source is connected to [[existing source]] via {concept}

   Alias suggestions: (shown only when new synonym relationships are discovered)
   - Suggested alias addition: {term A} = {term B}
   ```

### Simplified Processing Flow (Short sources <= 1000 characters)

Suitable for short tweets, Xiaohongshu notes, brief comments, etc.

1. **Save raw source** to the corresponding `raw/` directory
   - **Image detection and tracking**: Same as the full processing flow — scan for image references and notify the user; record count and paths in the source page's `images` and `image_paths` frontmatter fields
2. **Read context and check cache**:
   - Still prioritize reading `purpose.md`
   - Still run `bash ${SKILL_DIR}/scripts/cache.sh check "<raw file path>"` first
   - If cache hits (`HIT` or `HIT(repaired)`), directly reuse existing results
3. **Generate simplified summary page** (`wiki/sources/`):
   - Write `sources: []` in frontmatter
   - Include only basic information and core insights
   - Omit the "notable excerpts from original" section
   - **When writing the source page, also use `create-source-page.sh`** (automatically updates cache)
4. **Extract 1-3 key concepts**:
   - If the corresponding entity page already exists → append a one-sentence note
   - If it does not exist → mark in the summary page with `[to be created: [[concept name]]]`
5. **Update index.md and log.md** (cache already updated automatically by `create-source-page.sh`)
6. **Skip**: topic page creation/update, overview update

7. **Display simplified results to the user** (switch language based on `WIKI_LANG`):

   ```
   Ingested: {source title} (short content, simplified processing)

   Added:
   - Source summary page

   To be developed:
   - [to be created: [[concept name]]] (will be organized after accumulating more sources)
   ```

---

## Workflow 3: batch-ingest (Batch Ingest)

When the user provides a folder path, or says "organize all of these."

### Steps

1. **Confirm knowledge base path**:
   - Execute the **common pre-checks** (defined above) to obtain the knowledge base root path and `WIKI_LANG`

2. **List all processable files**:
   - Supported formats: `.md`, `.txt`, `.pdf`, `.html`
   - Ignore: hidden files, `.git` directory, `node_modules`, etc.

3. **Display file list** and confirm processing scope (switch language based on `WIKI_LANG`):

   ```
   Found {N} files to process:
   1. file1.pdf
   2. file2.md
   3. file3.txt

   Estimated {N} rounds of processing. Proceed?
   ```

4. **Process one by one**: Execute the ingest workflow for each file
   - Run `cache check` for each file first
   - Files with cache hits are skipped directly, without entering LLM processing
   - Only files with `MISS` continue with full or simplified processing

5. **Pause every 5 files**, display progress and ask whether to continue (switch language based on `WIKI_LANG`):

   ```
   Progress: 5/{N} completed

   Batch results:
   - New source summaries: 5
   - New entity pages: 3
   - Updated existing pages: 7

   Continue processing the remaining {M} files?
   ```

6. **After all are complete**:
   - Run a full index.md update
   - Output a summary report (switch language based on `WIKI_LANG`):

   ```
   Batch ingest complete!

   Processed {N} files:
   - Skipped N (no changes), processed M (new/updated)
   - Succeeded: {S}
   - Skipped (empty content / unsupported format): {K}
   - Failed: {F}

   New pages: {total_new}
   Updated pages: {total_updated}
   ```

---

## Workflow 4: query (Query Knowledge Base)

### Steps

1. **Confirm knowledge base path**:
   - Execute the **common pre-checks** (defined above) to obtain the knowledge base root path and `WIKI_LANG`
   - If no knowledge base is available, prompt the user to initialize first
2. **Read index.md** to understand the full scope of the knowledge base
3. **Search for related pages**:
   - **Alias expansion**: First read the "alias vocabulary" in `.wiki-schema.md`. If the user's query keyword matches an alias group, include all synonyms in that group in the search (e.g., searching "LLM" also searches "large language model")
     - Expansion rule: Only expand within the matched group; do not propagate across groups (if A=B and B=C are two separate groups, searching A only expands the first group, without merging the second)
     - Deduplication: The expanded keyword list is automatically deduplicated, ignoring empty items and whitespace-only items
   - Locate related categories and entries in index.md (using all expanded keywords)
   - Then use Grep to search all keywords (original + alias-expanded) under `wiki/`
   - Sort by relevance: filename exact match > index.md entry match > body keyword hit count (multiple words from the same alias group hitting the same page count as one, to avoid inflated scores for alias-dense pages)
   - **Paragraph limit**: After expansion, each keyword yields at most 3 matching paragraphs, with a total paragraph cap of 15
   - Read the 3-5 most relevant pages
   - **Single-page length limit**: If a page exceeds 2000 characters, only read frontmatter + first 500 characters + Grep-matched paragraphs (3 lines of context each), to avoid long pages consuming too much context
4. **Synthesize an answer**:
   - Answer the user's question in the language corresponding to `WIKI_LANG`
   - Cite information sources (reference wiki pages using `[[page name]]` format)
   - If multiple sources present different viewpoints, list them separately with source attribution
5. **Determine whether persistence is worthwhile**:
   - If the answer synthesizes 3 or more sources, prompt the user: "Would you like to save this answer to the knowledge base?"
   - For fewer than 3 sources, default to an ephemeral answer without proactively suggesting persistence

6. **Duplicate detection**:
   - Before persisting, search for same-topic pages under `wiki/queries/`
   - Match by frontmatter tags and title to determine if a same-topic query page already exists
   - If one exists, ask the user whether to "update the existing page" or "create a new one"
   - If the user chooses to update the old page, add a `superseded-by` marker to the old version

7. **Save query page**:
   - Generate the page using `templates/query-template.md`
   - Save path uses `wiki/queries/{date}-{short-hash}.md` to avoid same-topic naming conflicts
   - Frontmatter must include `type: query` and `derived: true`
   - `derived: true` indicates this is derived content, not a primary source

8. **Self-reference protection**:
   - Query pages are treated as secondary sources in subsequent ingest analysis, not as primary knowledge sources
   - If subsequent pages reference information from query pages, related relationships are uniformly treated as `INFERRED`
   - Ingest does not proactively scan `wiki/queries/`; query pages are only read as supplementary material when the current question genuinely requires it

9. **Update index and log**:
   - After saving successfully, add a query entry in index.md
   - Also append a query save record in log.md

---

## Workflow 5: lint (Health Check)

### Trigger Conditions

- The user explicitly says "check knowledge base"
- After each ingest, if the total source count is a multiple of 10, proactively suggest running lint

### Pre-checks

Execute the **common pre-checks** (defined above). If no knowledge base is available, prompt the user to initialize first.

1. **Determine check scope**:
   - The 10 most recently updated pages (sorted by file modification time)
   - 10 randomly sampled pages (to avoid missing issues in older pages)
   - If total page count <= 20, check all pages

2. **Step 0: Run the script for mechanical checks** (must be done first, do not skip):

   ```bash
   bash ${SKILL_DIR}/scripts/lint-runner.sh <wiki_root>
   ```

   The script handles three **mechanical checks** (requiring only exact matching, no judgment):
   - Orphaned pages (entities under `entities/` not referenced by any other page)
   - Broken links (`[[X]]` links where `X.md` does not exist, supports `[[X|alias]]` syntax)
   - Index consistency (entries recorded in index.md but with missing files)

   Exit codes: `0` = completed successfully, `1` = script error (path does not exist, index.md missing).
   If exit 1, report the error to the user and do not continue.
   If exit 0, read the script's stdout into context as foundation material for subsequent AI-judgment checks.

3. **Item-by-item checks** (AI judgment type, beyond what the script can do):

   **Contradictory information** (read related pages, check for mutually contradictory claims):
   - List discovered contradictions
   - Annotate the source page for each contradiction

   **Missing cross-references** (check whether pages on related topics should be interlinked but are not):
   - Suggest cross-references to add

   **Confidence report** (tally `EXTRACTED` / `INFERRED` / `AMBIGUOUS` / `UNVERIFIED`):
   - Highlight `AMBIGUOUS` entries, reminding the user to verify these first
   - Spot-check entries marked as EXTRACTED to verify whether they can be traced back to the original source material
   - If EXTRACTED entries cannot be traced to the original text, prompt the user to downgrade confidence or re-organize

   **Supplementary recommendations**: Based on Step 0 script output for orphaned pages/broken links, provide repair suggestions (the script only lists issues, not solutions)
   - Orphaned pages → suggest which related pages to add `[[links]]` from
   - Broken links → suggest creating new pages for which concepts, or rewriting references to existing pages

4. **Output report** (switch language based on `WIKI_LANG`, integrating Step 0 script output + Step 3 AI judgment results):

   ```
   Knowledge Base Health Check Report

   Scope: 10 most recently updated + 10 randomly sampled ({N} total)

   Orphaned pages (no other pages link to them):
   - [[some page]] → suggest adding a link from [[related page]]

   Broken links (linked but do not exist):
   - [[some concept]] → suggest creating a new page

   Contradictory information:
   - Regarding "XX", [[page A]] says Y, but [[page B]] says Z

   Missing index entries:
   - {filename} exists but is not recorded in index.md

   Confidence report:
   - EXTRACTED: {N}
   - INFERRED: {N}
   - AMBIGUOUS: {N}
   - UNVERIFIED: {N}
   ```

5. **Ask the user**: Which issues should be auto-fixed? (ask in the language corresponding to `WIKI_LANG`)

---

## Workflow 6: status (View Status)

### Pre-checks

Execute the **common pre-checks** (defined above). If no knowledge base is available, prompt the user to initialize first.

### Steps

1. First run `bash ${SKILL_DIR}/scripts/source-registry.sh list` to read the source registry
2. Obtain the knowledge base path (following the CWD check logic above)
3. Gather statistics:
   - Count `raw/` files for each source by `source_label` and `raw_dir` from the source registry
   - Number of pages under `wiki/entities/`
   - Number of pages under `wiki/topics/`
   - Number of pages under `wiki/sources/`
   - Number of pages under `wiki/comparisons/` and `wiki/synthesis/`
   - Whether `purpose.md` exists
4. Read the last 5 entries from `log.md`
5. Read `index.md` for a topic overview
6. Run `bash ${SKILL_DIR}/scripts/adapter-state.sh summary-human` to get adapter status
7. Run `node ${SKILL_DIR}/scripts/source-signal-coverage.js <wiki_root>` to get source signal coverage data; read from the returned JSON's `summary`:
   - `ok` (participating), `missing_sources` (missing sources), `empty_sources` (sources field empty), `invalid_sources` (invalid format), `not_applicable` (currently not participating)
8. **Output report** (switch language based on `WIKI_LANG`):

   ```
   Knowledge Base Status: {topic}

   Source distribution (by source registry):
   - {source_label}: {N}
   - {source_label}: {N}
   ...

   Wiki pages: {total} pages
     - Entity pages: {N}
     - Topic pages: {N}
     - Source summaries: {N}
     - Comparisons: {N}
     - Syntheses: {N}

   Graph source signal coverage:
   - Participating: {ok}
   - Missing sources: {missing_sources}
   - Empty sources: {empty_sources}
   - Invalid format: {invalid_sources}
   - Not applicable: {not_applicable}

   Research direction:
   - purpose.md exists: {yes/no}

   Recent activity:
   - {date} ingest | {source title}
   - {date} ingest | {source title}
   ...

   Adapter status:
   {summary-human output}

   Suggestions:
   - You may want to dive deeper into {topic}, with {N} related sources already available
   - {entity} is mentioned in {N} sources and is worth organizing into a dedicated page
   ```

   Adapter status should directly use the output from `bash ${SKILL_DIR}/scripts/adapter-state.sh summary-human`; do not write your own source listing.

---

## Workflow 7: digest (Deep Dive Synthesis Report)

**Distinction from query**: query is a quick Q&A that does not generate new pages; digest is a cross-source deep synthesis that generates a persisted report.

### Trigger Keywords

- Default deep dive report format: `"tell me about XX", "deep analysis of XX", "overview of XX", "digest XX", "comprehensive summary of XX"`
- Comparison table format: `"compare X and Y", "differences between X and Y"`
- Timeline format: `"organize a timeline", "chronological order", "time sequence"`

### Pre-checks

Execute the **common pre-checks** (defined above). If no knowledge base is available, prompt the user to initialize first.

1. **Search for related pages**:
   - **Alias expansion**: Same as the query workflow — first read the "alias vocabulary" in `.wiki-schema.md` to expand synonyms (no cross-group propagation, automatic deduplication)
   - Use Grep to search all keywords (original + alias-expanded) under `wiki/`; multiple words from the same alias group hitting the same page count as one
   - List the pages that will be synthesized (so the user knows the report's coverage)

2. **Deep-read all related pages + select output format**:
   - Read all found related wiki pages (sources/, entities/, topics/)
   - **Single-page length limit**: If a page exceeds 3000 characters, prioritize reading frontmatter + core insights section + paragraphs directly related to the topic, skipping verbose sections like "notable excerpts from original"
   - Summarize each page's core insights and source information
   - **Select output format based on trigger keywords**:
     - User says "compare"/"differences" → use **comparison table format** (see Template B below)
     - User says "timeline"/"chronological" → use **timeline format** (see Template C below)
     - Other defaults → use **deep dive report format** (see Template A below)

3. **Generate structured deep dive report**, save to `wiki/synthesis/{topic}-{format}.md` (switch language based on `WIKI_LANG`):

   > Filename rules: default format uses `{topic}-deep-dive.md`, comparison table uses `{topic}-comparison.md`, timeline uses `{topic}-timeline.md`

   **Template A: Deep Dive Report Format (Default)**

   ```markdown
   # {Topic} Deep Dive Report

   > Synthesized from {N} sources | Generated: {date}

   ## Background Overview
   (Brief explanation of the topic's background and importance)

   ## Core Insights
   (Ordered by importance, each insight cites its sources)
   - Insight one (sources: [[source A]], [[source B]])
   - Insight two (sources: [[source C]])

   ## Contrasting Perspectives
   (If multiple sources hold different views, compare them here)
   | Dimension | Source A's View | Source B's View |
   |-----------|----------------|----------------|

   ## Knowledge Trajectory
   (Trace the development of this topic in chronological or logical order)

   ## Open Questions
   (Questions not yet answered by existing sources, which can guide future source collection)

   ## Related Pages
   (List all synthesized source links)
   ```

   **Template B: Comparison Table Format** (trigger: compare / differences)

   ```markdown
   # {Comparison Topic} Comparison Analysis

   > Comparing {N} objects | Generated: {date}

   ## Objects Compared
   - [[Object A]]
   - [[Object B]]
   - [[Object C]] (if applicable)

   ## Comparison Table

   | Dimension       | [[Object A]] | [[Object B]] | [[Object C]] |
   |----------------|-------------|-------------|-------------|
   | Core Insight    | ...         | ...         | ...         |
   | Use Cases       | ...         | ...         | ...         |
   | Strengths       | ...         | ...         | ...         |
   | Weaknesses / Limitations | ... | ...       | ...         |
   | Source Material  | [[source 1]] | [[source 2]] | [[source 3]] |

   ## Key Differences
   (Summarize the most important differences in 1-2 sentences)

   ## Related Pages
   ```

   **Template C: Timeline Format** (trigger: timeline / chronological)

   ```markdown
   # {Topic} Timeline

   > Time span: {start year} ~ {end year} | Generated: {date}

   ```mermaid
   gantt
     title {Topic} Timeline
     dateFormat YYYY-MM-DD
     section Major Events
       Event A : 2023-01-01, 1d
       Event B : 2024-03-15, 1d
       Event C : 2025-06-20, 1d
   ```

   ## Event Details
   - **2023-01-01 — Event A**: Brief description (source: [[source A]])
   - **2024-03-15 — Event B**: Brief description (source: [[source B]])
   - **2025-06-20 — Event C**: Brief description (source: [[source C]])

   ## Related Pages
   ```

   > **Timeline format notes**:
   > - `gantt` requires `YYYY-MM-DD` precision
   > - If the source only has a year (e.g., "2023"), fill in the first day of that year (`2023-01-01`)
   > - If even the year is uncertain, use a **plain text timeline** (unordered list sorted by time) instead of Mermaid gantt
   > - If there are more than 15 events, consider grouping by section to avoid an overly long chart

4. **Update index.md and log.md**:
   - Add a new report entry under the "Synthesis" category in index.md
   - Append to log.md: `## {date} digest | {topic}`

5. **Display results to the user** (switch language based on `WIKI_LANG`):

   ```
   Deep dive report generated: {topic}

   Synthesized {N} sources:
   - [[source 1]], [[source 2]]...

   Report saved: wiki/synthesis/{topic}-deep-dive.md

   Open questions found — consider collecting more sources on:
   - {question 1}
   - {question 2}
   ```

---

## Workflow 8: graph (Knowledge Graph - Mermaid + Interactive HTML)

### Trigger Keywords

"draw a knowledge graph", "show connections", "graph", "knowledge base map", "show knowledge connections"

### Pre-checks

Execute the **common pre-checks** (defined above). If no knowledge base is available, prompt the user to initialize first.

1. **Scan bidirectional links**:
   - Traverse all `.md` files under `wiki/`
   - Extract `[[link]]` syntax from each file to build a relationship list: `page A → page B`

2. **Generate Mermaid chart file** `wiki/knowledge-graph.md`:
   ````markdown
   # Knowledge Graph

   > Auto-generated | {date} | {N} nodes, {M} connections

   ```mermaid
   graph LR
     A[Concept 1] --> B[Concept 2]
     A --> C[Source 1]
     D[Topic 1] --> A
     D --> E[Concept 3]
   ```

   Viewing options: Use Typora, VS Code (Markdown Preview Enhanced), or view directly on GitHub.
   ````

   **Generation rules**:
   - Node names use brackets `[name]`; truncate names longer than 10 characters
   - Only display nodes that have bidirectional link relationships (orphaned nodes are excluded from the graph)
   - If relationships exceed 50, keep only the 30 most-referenced nodes to avoid excessive density
   - **Default to unlabeled arrows `A --> B` for all connections**; do not automatically determine relationship types

   **Optional: Manual graph beautification** (done by the user after generation; AI does not handle this automatically):

   The generated `wiki/knowledge-graph.md` defaults to `-->` arrows only. If the user wants the graph to express relationship types more clearly, they can:

   1. Open `wiki/knowledge-graph.md` in an editor
   2. Refer to the "relationship type vocabulary" in `.wiki-schema.md` (implements / depends on / compares / contradicts / derives from)
   3. Rewrite the 3-5 most important arrows as `A -->|implements| B` style labeled notation
   4. Save and re-render with Obsidian / VS Code / Typora

   AI does **not auto-label** in the graph workflow — because automatically determining relationship types requires reading extensive context, which is costly and hard to ensure accuracy. Humans are more reliable at judging "which relationships are most worth labeling."
   If the user explicitly asks AI to label specific edges, they can say "label the relationship between A and B as 'implements'", and AI will manually modify the corresponding line in `wiki/knowledge-graph.md`.

2b. **Generate interactive graph data** (`wiki/graph-data.json`):

   ```bash
   bash scripts/build-graph-data.sh "$WIKI_ROOT"
   ```

   The script scans `wiki/{entities,topics,sources,comparisons,synthesis,queries}/*.md`,
   parses inline `[[bidirectional links]]` and `<!-- confidence: EXTRACTED|INFERRED|AMBIGUOUS -->` comments,
   calls a local Node helper to compute 3-signal edge weights (co-citation strength / source overlap / type affinity), Louvain communities, and rule-based insights,
   and writes to `wiki/graph-data.json` (auto-downgrades when content >2MB, keeping only 500 lines per node; insights auto-downgrade when graph scale exceeds budget).
   Requires `jq` + `node` (install with `brew install jq node` if missing).

2c. **Graph runtime notes**:
   - Graph construction now depends on `jq` + `node`
   - No additional `npm install` required
   - `node` is only used to run the local pre-built helper distributed with the repository

2d. **Generate interactive graph HTML** (wash watercolor card style):

   ```bash
   bash scripts/build-graph-html.sh "$WIKI_ROOT"
   ```

   Generates `wiki/knowledge-graph.html`. The script embeds `graph-data.json` (with `</script>` escaped)
   into `<script id="graph-data" type="application/json">`, using local `d3` + `roughjs` +
   `marked` + `purify` for offline double-click viewing. Includes search box, relationship type filtering, edge weight visualization,
   neighbor strength indicators, Insights panel, node drawer, and community clustering interactive features.

3. **Read insights and display results to the user** (switch language based on `WIKI_LANG`):

   First read insights:
   ```bash
   jq '.insights' "$WIKI_ROOT/wiki/graph-data.json"
   ```

   ```
   Knowledge graph generated!

   {N} nodes, {M} connections

   Graph insights:
   - Surprising connection: {from} ↔ {to} (cross-community, weight {weight}) {if any}
   - Bridge node: {node} (connects {count} communities) {if any}
   - Knowledge gap: {node} (degree {degree}, consider adding sources) {if any}
   - Sparse community: {community} (density {density}) {if any}

   Viewing options:
   - Interactive (recommended): double-click wiki/knowledge-graph.html
     (Chrome / Firefox recommended; if Safari shows "blocked script",
      run `python3 -m http.server 8000` in wiki/ and access from there)
   - Mermaid static chart: wiki/knowledge-graph.md
     (renderable in Obsidian / VS Code Markdown Preview Enhanced / GitHub / Typora)

   Orphaned pages (not included in graph):
   - [[some page]] (suggest adding to a related entity or topic page)
   ```

   (Omit any insight category line when that category is empty.)

---

## Workflow 9: delete (Delete Source)

### Trigger Keywords

"delete source", "remove", "delete source", "remove"

### Pre-checks

Execute the **common pre-checks** (defined above). If no knowledge base is available, prompt the user to initialize first.

### Steps

1. **Identify target source**:
   - Search for the source name mentioned by the user under `raw/`
   - If multiple candidates match, list the candidate files for the user to confirm

2. **Scan impact scope**:
   - First run:
     ```bash
     bash ${SKILL_DIR}/scripts/delete-helper.sh scan-refs "<wiki root>" "<source filename>"
     ```
   - Use the script's returned page list as the reference scan result
   - For each page, determine whether to "delete the entire page" or "keep the page but remove that source's references"

3. **Safety confirmation**:
   - If more than 5 pages are affected, first display the complete list of affected pages to the user, then request a second confirmation
   - If an entity or topic is referenced by only this source, ask the user whether to delete that page as well

4. **Execute cascading cleanup**:
   - Delete the corresponding raw file under `raw/`
   - Delete the corresponding source summary page under `wiki/sources/`
   - For pages under `wiki/entities/`, `wiki/topics/`, `wiki/comparisons/`, `wiki/synthesis/` that should be retained, only remove paragraphs referencing that source
   - Update `index.md`
   - Append a deletion record to `log.md`
   - Mark `wiki/overview.md` as needing regeneration

5. **Clean cache**:
   - After deletion is complete, run for the corresponding raw file:
     ```bash
     bash ${SKILL_DIR}/scripts/cache.sh invalidate "<raw file path>"
     ```

6. **Broken link check**:
   - Use grep or `delete-helper.sh` to scan again for links pointing to deleted pages
   - Clean up clearly determinable broken links; if attribution is unclear, preserve the original text and prompt the user for later manual confirmation

7. **Report results to the user**:

   ```
   Deleted:
     - raw/articles/2024-01-15-ai-article.md
     - wiki/sources/2024-01-15-ai-article.md
   Updated (references removed):
     - wiki/entities/AI-Agent.md
     - wiki/topics/large-language-models.md
   Needs regeneration:
     - wiki/overview.md
   ```

---

## Workflow 10: crystallize (Crystallize)

**Trigger conditions**:
User says "crystallize", "crystallize", "save this to the knowledge base", "this conversation is valuable"

**Input**:
Content actively provided by the user (text pasted into the conversation, or explicitly referencing a specific context).
The user must actively provide the content; Claude does not automatically extract from the current session.

**Processing steps (MVP)**:

1. User provides content (text pasted into conversation)
2. Claude extracts from the content:
   - Core insights (3-5 items)
   - Key decisions and rationale
   - Conclusions worth recording
3. Generate `wiki/synthesis/sessions/{topic}-{date}.md`, following the format in `templates/synthesis-template.md`
   - This round does not require crystallize pages to include `sources`; by default they do not participate in graph source overlap
4. Update `log.md` (record this crystallization operation)

> MVP version does not automatically create entity pages or update index.md.

**Confidence rules**:
Content from crystallization sources is by default marked as `INFERRED` (from inference/conversation, not from original documents).

**Output example**:
Created wiki/synthesis/sessions/AI-agent-design-decisions-20260413.md
Updated log.md
