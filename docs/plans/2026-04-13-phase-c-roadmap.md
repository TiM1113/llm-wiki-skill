# Phase C Roadmap

Status: DONE (C1-C4 all implemented, v2.2.0)
Recorded: 2026-04-13
Prerequisites: Execute after Phase A (ingest validation + confidence rules) and Phase B (crystallize workflow) are complete

---

## Background

Phase A + B solved two core problems: ingest validation and knowledge crystallization.
Phase C is the next batch of improvements, sourced from llm-wiki-skill vs LLM Wiki v2 comparative analysis (/plan session, 2026-04-13).

4 features are mutually independent, can be implemented in any order.

---

## C1. Lint Scriptification

**Problem:** lint workflow relies entirely on AI self-execution, no script skeleton, no test coverage.

**Changed files:**
- Create `scripts/lint-runner.sh` (~50 lines)
- Modify `SKILL.md` lint workflow section

**Script responsibilities:**
- Scan orphan pages: pages existing under `wiki/` but not referenced in `index.md`
- Scan broken links: `[[X]]` format but `wiki/entities/X.md` doesn't exist
- Scan contradiction records: extract `contradictions` tags from source pages

**SKILL.md changes:** lint workflow calls script to generate structured report; AI only responsible for writing fix recommendations

**Effort:** M

---

## C2. Multiple Output Formats

**Problem:** digest workflow only outputs Markdown summary, no comparison table, timeline, or other format options.

**Changed files:**
- Modify `SKILL.md` digest workflow section (only change SKILL.md, no scripts)

**New formats:**
- `Comparison table`: Markdown multi-column table, comparing viewpoints across multiple sources on the same dimension
- `Timeline`: Mermaid gantt format, suitable for chronologically arranged events/progress materials

**Trigger method (SKILL.md routing):**
- "Compare A and B" -> comparison table format
- "Organize the timeline" -> Mermaid gantt format

**Effort:** S (only SKILL.md changes)

---

## C3. Schema Typed Relationships

**Problem:** graph workflow only outputs simple `[[A]] --> [[B]]`, no semantic relationship types.

**Changed files:**
- Modify `templates/schema-template.md` (add entity_types, relationship_types fields)
- Modify `SKILL.md` graph workflow section

**Result:**
```mermaid
A --implements--> B
C --depends-on--> D
E --compares-with--> F
```

**schema-template.md new field examples:**
```markdown
## Relationship Types
- implements
- depends-on
- compares-with
- derived-from
- contradicts
```

**Effort:** M

---

## C4. Privacy Filtering

**Problem:** No sensitive data filtering before ingest; phone numbers, ID numbers, passwords etc. could accidentally enter the wiki.

**Changed files:**
- Create `scripts/privacy-filter.sh` (~40 lines)
- Modify `SKILL.md` ingest workflow (call before cache check)

**Script responsibilities:**
- Detect common sensitive patterns: phone number regex, ID number regex, API key format (`sk-...`, `Bearer ...`)
- Prompt user to confirm whether to continue when detected
- Append scan results to log.md: `<!-- privacy-scan: clean -->` or `<!-- privacy-scan: WARNING -->`

**Effort:** M

---

## Priority Recommendations

If implementing all four, recommended order: C1 -> C3 -> C2 -> C4

- C1 first: lint scriptification has highest ROI and is the most direct quality assurance
- C3 next: schema typed relationships affect graph workflow, natural follow-up after C1
- C2 easy: only SKILL.md changes, can be slotted in anytime
- C4 last: privacy filtering is a security enhancement, doesn't affect core functionality
