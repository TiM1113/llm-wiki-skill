---
date: 2026-04-06
topic: project-cleanup-and-restructuring
---

# llm-wiki-skill Project Cleanup and Restructuring Plan

## Problem Frame

After 4 versions of iteration (v0.1->v0.4), llm-wiki-skill has complete functionality (8 workflows, multi-platform, bilingual), but internal structure has accumulated duplication and inconsistency. Core issues: SKILL.md 930 lines, CWD check duplicated 7 times, bilingual output occupies 40% of content, English seed files hardcoded, install script copies non-runtime files. These make maintenance and iteration increasingly difficult (each workflow modification requires synchronous updates across multiple locations, increasing risk of introducing inconsistent behavior).

Split into two phases: **Phase A (immediate execution)** is cleanup, no functional changes; **Phase B (recorded for reference)** is structural refactoring, for future reference.

---

## Phase A: Cleanup (Immediate Execution)

### SKILL.md Slimming

**R1. CWD Pre-check Deduplication**
- After the "workflow routing" section in SKILL.md but before individual workflow definitions, add a new "common pre-check" section
- Content: complete CWD check logic (check `.wiki-schema.md` → fall back to `~/.llm-wiki-path` → if missing, prompt initialization) + `WIKI_LANG` reading rules
- Each workflow's "pre-check" section changed to a single reference: "Execute **common pre-check** (see definition above)"
- Applies to 7 workflows: ingest, batch-ingest, query, lint, status, digest, graph (init has different pre-check logic, keep it independent)

**R2. Bilingual Output Simplification**
- In or adjacent to the "common pre-check" section, add an "output language rules" section:
  - Explain that all workflow user outputs follow `WIKI_LANG` for language selection
  - Provide general formatting rules for English output (same structure, English wording)
  - List English terminology mapping table (e.g. Source, Entity, Topic, Summary, Synthesis)
- Each workflow's output section: keep only the Chinese example, add a one-line comment "(English version generated according to output language rules, same structure)"
- Applies to workflows: init, ingest (full + simplified), batch-ingest, lint, status, digest, graph (note: query only has a single `WIKI_LANG` toggle instruction, no independent bilingual output block, not in scope for simplification)

**R3. Move init English Seed Files Out**
- Move the English seed file content from the init workflow in SKILL.md (index.md en, overview.md en, log.md en — three code blocks) to the `templates/` directory
- New files: `templates/index-en-template.md`, `templates/overview-en-template.md`, `templates/log-en-template.md` (consistent with existing `*-template.md` naming convention)
- In the init workflow, change to: "If `WIKI_LANG=en`, use `templates/index-en-template.md`, `templates/overview-en-template.md`, `templates/log-en-template.md` to replace the corresponding Chinese templates"
- Keep init-wiki.sh unchanged (it only handles directory creation and generic variable substitution)

### Install Script Simplification

**R4. install.sh MANAGED_ITEMS Audit**
- Check the current `MANAGED_ITEMS` array, confirm whether each item is required at runtime
- Current array: `SKILL.md`, `README.md`, `CLAUDE.md`, `AGENTS.md`, `CHANGELOG.md`, `install.sh`, `setup.sh`, `scripts`, `templates`, `deps`, `platforms`
- `platforms/` **must be kept**: README.md (4 references), CLAUDE.md (1 reference), AGENTS.md (1 reference) contain links pointing to files under platforms/; these links must be valid after installation
- `docs/` is not in the current MANAGED_ITEMS, no action needed
- Candidates for possible removal: `CHANGELOG.md` (no runtime references after installation), `install.sh` itself (installation already complete) — but keeping them is safer, not removing
- Verification: run `tests/regression.sh` to ensure installation works correctly

**R5. Mark setup.sh as Deprecated**
- Add a comment at the top of setup.sh: `# Deprecated: please use bash install.sh --platform claude`
- Do not delete the file (maintain backward compatibility)
- If README mentions setup.sh separately anywhere, update to recommend install.sh

### Success Criteria

- SKILL.md line count reduced to ~750 lines or below (CWD deduplication saves ~40 lines, English output block deletion saves ~120 lines, English seed externalization saves ~115 lines, total savings ~200 lines)
- Each modified workflow functions identically to before the modification
- `tests/regression.sh` all pass
- `bash install.sh --platform claude --dry-run` output still correctly copies platforms/ (contains runtime references)
- For `WIKI_LANG=en` init execution, manually verify that index.md, overview.md, log.md English content is identical to before the modification (this verification requires manual execution; regression.sh cannot cover AI-driven template substitution)

### Scope Boundaries

- Do not change any workflow's functional logic
- Do not split SKILL.md into multiple files
- Do not modify deps/ structure
- Do not add version management/upgrade mechanisms
- Do not modify init-wiki.sh

### Key Decisions

- **Internal deduplication rather than splitting files**: CWD check extracted as a shared paragraph but kept within the same file, avoiding introducing a multi-file loading mechanism
- **Single-language display + unified rules**: Bilingual output only shows the Chinese version; English version derived through top-level rules, greatly reducing duplication
- **English seed files go through the template system**: Consistent mechanism with Chinese templates, making init workflow logic more unified. English and Chinese templates go through different variable substitution paths (AI vs script); this inconsistency is acceptable under the current "do not modify init-wiki.sh" constraint — init-wiki.sh still handles Chinese templates, AI reads `templates/*-en-template.md` in subsequent steps, replaces `{{DATE}}`/`{{TOPIC}}` and overwrites the corresponding files
- **platforms/ must be kept in the install package**: README.md (4 references), CLAUDE.md (1 reference), AGENTS.md (1 reference) contain runtime links

---

## Phase B: Structural Refactoring (Recorded for Reference)

The following items are not within the scope of this cleanup, recorded for future reference.

### Shared Constraints for Phase B

Phase B is not about building a shell that “looks more like a plugin system” first, but about separating the **knowledge base mainline** from the **adapter ingestion capabilities**.

**Bottom line**:
- The knowledge base mainline must stand on its own: local files, plain text, existing knowledge base `query / digest / lint / status / graph` cannot depend on adapters
- All adapters are only responsible for converting external content into unified source material; once entering the mainline, the subsequent processing flow is completely identical
- Removing any single adapter must not cause core knowledge base capabilities to fail
- Phase 1 does not implement auto-discovery, plugin marketplace, or complex enable/disable UI; focus on boundaries, degradation, and compatibility first

**Documentation prerequisites that must be completed before Phase 1 begins**:
- Unified source material entry definition: minimum fields, who fills them, what information must be present before entering the mainline
- Single adapter registry: source, category, dependencies, original directory, fallback method
- Adapter failure state table: not installed / environment not met / runtime failure / source not supported / extraction empty
- Legacy knowledge base compatibility and migration rules: old directories, old source materials, old installations continue to work

### B1. SKILL.md Multi-file Split (Split for Maintenance, Keep Single Entry for Delivery)

> **Relationship with Phase A**: Phase A's deduplication will not block B1; but B1 should not be done before boundaries are stabilized.

**Current state**: Core instructions are concentrated in a single file; modifying one place during maintenance easily leads to missing other places.

**Goal**:
- For maintenance, can be split into main router + `workflows/` sub-files, reducing cognitive load during modifications
- Externally, still keep a stable single entry point, not requiring runtime multi-file reference mechanisms

**Benefits**:
- Change isolation, easier to review
- Main router and specific workflow responsibilities are clearer

**Risks**:
- Different agents have inconsistent support for skill file references
- If runtime is also made multi-file, the installation experience may become fragile

**Conclusion**: B1 is not Phase 1. First nail down boundaries, registry, and failure states, then decide whether to split files.

### B2. deps/ Dependency Management Refactoring (Establish Boundaries First, Then Decide on External Fetching)

**Current state**: `baoyu-url-to-markdown` and `youtube-transcript` are directly embedded in the repo, while `wechat-article-to-markdown` is fetched externally during installation.

**Goal**:
- First clarify the boundary between “core built-in” and “optional adapter dependencies”
- Then decide which dependencies continue to be built-in, which are allowed to be fetched during installation
- Installation, status checks, and future upgrade logic all read from the same source registry

**Benefits**:
- When subsequently adding or removing adapters, core functionality is not affected
- Dependency strategy is more consistent, avoiding the state where half are built-in and half are scattered in scripts

**Risks**:
- If dependencies are all externalized too early, it introduces network and installation instability
- Submodules increase maintenance complexity

**Conclusion**: Phase 1 only does boundaries and the registry, no rush to externalize all dependencies.

### B3. Bilingual i18n Externalization (Deferred)

**Current state**: Bilingual content is more converged than before, but still scattered in core instructions.

**Goal**: In the future, use `locales/zh.md` and `locales/en.md` to centrally manage output templates.

**Benefits**:
- Adding new languages won't require repeatedly modifying the main file
- Copy maintenance is more centralized

**Risks**:
- Continuing to split copy before boundaries are stable will expand the maintenance surface
- Depends on file reference capability, same compatibility concerns as B1

**Conclusion**: B3 does not enter Phase 1; wait until core/adapter boundaries are stable before doing this.

### B4. Version Management and Upgrades (Start with Lightweight Version)

**Current state**: Repeated installation overwrites files, but users don't know the current version or adapter status.

**Goal**:
- First make the version and installed capabilities visible
- Then consider upgrade, rollback, uninstall and other complete lifecycle commands

**First step only does**:
- Can see the current skill version
- Can see which optional adapters are currently in available / unavailable status
- Leave entry points for subsequent `doctor / upgrade / uninstall`

**Conclusion**: B4 is worth doing, but start with the lightweight version; don't pursue a complete rollback system in Phase 1.

### B5. Deterministic Logic Scriptification (Phase 1 Top Priority)

**Current state**: CWD checks, source material classification, status determination and other deterministic actions are still primarily driven by instruction text.

**Goal**:
- First convert the most drift-prone deterministic logic into scripts or unified rules
- AI is only responsible for analysis and generation, not for repeatedly making the same judgments

**Phase 1 priority scriptification targets**:
- CWD / knowledge base root path determination
- Source registry reading and raw directory mapping
- Status check classification (core available, adapter missing, environment not met, runtime failure)

**Phase 1 does not require scriptification of**:
- Complete update flow for `index.md` / `log.md`
- Complex batch repair logic

**Conclusion**: B5 is the starting point of Phase 1. Do it first, then B2/B4 will have a stable foundation.

### Recommended Execution Order for Phase B

1. B5: First establish deterministic boundaries, registry, and status determination
2. B4 (lightweight version): Make version and adapter status visible
3. B2: Refactor dependency management strategy under the unified registry
4. B1: Consider maintenance-mode splitting after boundaries are stable
5. B3: Handle deeper bilingual externalization last

---

## Outstanding Questions

### Resolve Before Planning

- [Resolved] Phase 1's goal is not a complete plugin platform, but “core mainline independent + adapters pluggable”
- [Resolved] Need to first complete unified source material entry, adapter registry, failure state table, and compatibility rules before entering implementation
- [Resolved] Auto-discovery, plugin marketplace, complex enable/disable are not part of Phase 1

### Deferred to Planning
- [Phase 1][Technical] What format should the unified source registry ultimately use, balancing maintainability with bash 3.2 compatibility
- [Phase 1][Technical] Should `status` directly display the five adapter failure states, or keep them as internal rules for now
- [Phase 1][Compatibility] When legacy knowledge bases lack new fields or new directories, use lazy compatibility or explicit migrate

## Next Steps

→ First complete `docs/plans/2026-04-06-002-phase-b-core-and-adapter-separation-plan.md`
→ Then generate Phase 1 execution tasks based on that plan, proceeding in dependency order
