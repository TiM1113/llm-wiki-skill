# llm-wiki-skill Improvement Plan

> Based on /plan-ceo-review audit results, selective expansion mode
> Date: 2026-04-05
> Status: All completed (P1/P2/P3/P4/P5/P6)

## Audit Conclusion

Skeleton is qualified, 0 CRITICAL GAPs, 0 blocking issues. Improvement direction: lower first-use barrier + increase wiki depth value.

---

## P1: Multi-Wiki Support (Completed)

**Problem**: `~/.llm-wiki-path` only stores one path; creating a second wiki would overwrite the first.

**Solution**: Add a CWD check at the beginning of ingest/query/lint/status workflows in SKILL.md:

```
1. Check if the current working directory contains .wiki-schema.md
   - If yes -> use the current directory as wiki root path
   - If no -> fall back to reading ~/.llm-wiki-path
2. Both missing -> run the init workflow
```

**Changed files**:
- `SKILL.md` — Add CWD check logic to the "prerequisites" section of 5 workflows

**Effort**: S

---

## P2: Chrome + Dependency Check Upfront (Completed)

**Problem**: Beginner user provides a URL -> waits 30 seconds -> gets a vague error -> doesn't know what happened. baoyu-url-to-markdown depends on Chrome CDP, but never checks if Chrome is running.

**Solution**:

1. Add Chrome process check in setup.sh:
   ```bash
   if ! pgrep -x "Google Chrome" > /dev/null 2>&1; then
       echo "Warning: Chrome is not running. baoyu-url-to-markdown requires Chrome. Please start Chrome first."
   fi
   ```

2. Add pre-check to the URL routing section of the SKILL.md ingest workflow:
   - Check Chrome process before calling baoyu
   - If not running, prompt user to start Chrome instead of wasting 30 seconds waiting for timeout

**Changed files**:
- `setup.sh` — Add Chrome check
- `SKILL.md` — Add pre-check to ingest source extraction routing

**Effort**: S

---

## P3: Digest Deep Report Workflow (Completed)

**Problem**: Current query is Q&A style (user asks, AI answers). But the core value of the Karpathy methodology is **cross-source synthesis**.

**Solution**: Add `digest` workflow to SKILL.md:

**Trigger**:
- "Tell me about XX", "Summarize all knowledge about XX", "Deep analysis of XX"
- "digest XX", "overview of XX"

**Difference from query**:
- query: Quick answer, no new page generated
- digest: Deep report, synthesizes all related sources, generates `wiki/synthesis/{topic}-deep-report.md`

**Steps**:
1. Read index.md to locate related entries
2. Grep search + read all related wiki pages
3. Synthesize analysis, generate structured report:
   - Background overview
   - Core viewpoints (annotate source for each viewpoint)
   - Comparison of different viewpoints
   - Knowledge trajectory (sorted by time or logic)
   - Unresolved questions
4. Save to `wiki/synthesis/`
5. Update index.md and log.md

**Changed files**:
- `SKILL.md` — Add workflow 7 + add one row to routing table

**Effort**: S

---

## P4: One-Click Install (Completed)

**Problem**: Current installation requires 4 steps (clone -> setup.sh -> cd deps -> bun install), beginners easily get stuck.

**Solution**:

1. **Integrate bun install into setup.sh**:
   - After copying deps, automatically check baoyu-url-to-markdown/scripts/ directory
   - If package.json exists and bun is available -> auto `bun install`
   - If bun is unavailable -> prompt to install bun (`curl -fsSL https://bun.sh/install | bash`)

2. **Add one-click install command to README**:
   ```bash
   git clone https://github.com/sdyckjq-lab/llm-wiki-skill.git ~/.claude/skills/llm-wiki && bash ~/.claude/skills/llm-wiki/setup.sh
   ```

3. **Add Chrome check to setup.sh** (merged with P2)

**Changed files**:
- `setup.sh` — Integrate bun install + Chrome check
- `README.md` — Update install instructions to one-line command

**Effort**: M

---

## P5: Bilingual Templates (Completed)

**Problem**: User chose to support Chinese-English bilingual, target audience includes international users.

**Solution**:

1. Add English version for each template, in the same directory:
   - `templates/entity-template.md` -> Add English sections (separated by `<!-- English -->` comments)
   - Or: Add language detection logic to SKILL.md, choose template language based on user environment

2. **Recommended sub-approach**: Add language selection to SKILL.md init workflow:
   - Ask user language preference (Chinese/English)
   - Write to `language` field in `.wiki-schema.md`
   - ingest/query output language based on language field
   - Templates not split; AI generates dynamically based on language config

**Changed files**:
- `SKILL.md` — Add language selection to init, add language awareness to each workflow
- `templates/schema-template.md` — Support zh/en for language field

**Effort**: M

---

## P6: Mermaid Knowledge Graph (Completed)

**Problem**: `[[bidirectional links]]` can only be rendered by Obsidian. Users without Obsidian can't see knowledge relationships.

**Solution**: Add `graph` workflow:

**Trigger**:
- "Draw a knowledge graph", "Show relationship map", "graph", "wiki map"

**Steps**:
1. Read index.md to get all page list
2. Scan all `[[links]]` in wiki/ pages to extract relationships
3. Generate Mermaid chart file `wiki/knowledge-graph.md`:
   ```markdown
   # Knowledge Graph

   ```mermaid
   graph LR
     A[Transformer] --> B[Attention Mechanism]
     A --> C[RNN Alternative]
     D[Karpathy Method] --> A
     D --> E[Wiki Building]
   ```
   ```

4. User can view with any Mermaid-compatible editor (Typora, VS Code, GitHub)

**Changed files**:
- `SKILL.md` — Add workflow 8 + add one row to routing table

**Effort**: S

---

## TODO (Recorded, not in current scope)

| Task | Effort | Priority | Reason |
|------|--------|----------|--------|
| Refactor critical path to scripts (Approach C) | L | P3 | Current pure SKILL.md approach is sufficient; refactor after more user feedback |
| URL dedup check | S | P3 | Low probability scenario, only triggered by manual re-feeding |
| Fix path after wiki directory move | S | P3 | Extremely low probability scenario |

---

## Implementation Order

```
P1 Multi-wiki    -+
P2 Chrome check  -+-> P4 One-click install (merges P2's Chrome check) -> P3 digest -> P6 graph -> P5 Bilingual
P3 digest        -+
```

P1 + P2 + P4 can be parallelized. P3/P6 are independent. P5 last (involves all templates).
