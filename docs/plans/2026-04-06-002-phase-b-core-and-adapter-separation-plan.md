---
title: "phase-b: Separating knowledge base core from external adapter feeding (Phase 1)"
type: architecture
status: implemented
date: 2026-04-06
origin: docs/brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md
---

# phase-b: Separating knowledge base core from external adapter feeding (Phase 1)

## Overview

This plan only answers one question: how to separate the **knowledge base core** from the **external adapter feeding capabilities** without dismantling the "full-suite experience".

Phase 1's goal is not to build a complete plugin system, but to first let the core path stand on its own and then let adapters become truly pluggable entries. Users will barely feel the refactoring, but the core becomes more stable, and later maintenance won't be dragged down by the whole system because some external skill fails.

## Problem Frame

The current repo already implicitly contains two different responsibilities:

- One is the **knowledge base core**: initialization, local file / plain text ingest, existing knowledge base query / digest / lint / status / graph
- The other is **external adapter feeding**: extraction for external sources like web pages, X/Twitter, WeChat public accounts, YouTube, Zhihu

The issue isn't lack of functionality, but that the boundary hasn't been formally set. Currently these facts are scattered across `SKILL.md`, `README.md`, `install.sh`, `templates/schema-template.md`, `tests/regression.sh`, and other locations. If we continue evolving like this, every time an adapter is added or removed in the future, docs, install, state hints, and core behavior may gradually drift.

## Decision Summary

Phase 1 locks in the following judgments:

1. **Knowledge base core is the bottom line**
   - Local files, plain text, and operations on existing knowledge bases must be independently usable.

2. **Adapters only "translate" external content**
   - An adapter's sole responsibility is to translate external sources into unified material; after entering the main pipeline, processing flow no longer branches.

3. **Don't build a complete plugin platform first**
   - Phase 1 doesn't do auto-discovery, plugin market, complex start/stop UI, nor pursue complete upgrade/rollback system.

4. **Set boundaries first, then move structure**
   - First do unified material entry, adapter summary table, failure state table, compatibility rules.
   - B1 (multi-file split) and B3 (i18n externalization) deferred.

## Phase 1 Scope

### In Scope

- Clarify the fixed boundary of "core main pipeline vs optional adapters"
- Define minimum fields for unified material entry
- Establish a single source registry, as the common basis for install, state, and routing
- Define adapter failure states and unified fallback paths
- Clarify compatibility and migration rules for old knowledge bases
- Add corresponding regression tests, prioritizing coverage of "main pipeline doesn't regress"

### Out of Scope

- Auto-discovery of adapters
- Plugin market
- Complex toggle management UI
- Complete upgrade/rollback/uninstall system
- Multi-file splitting for all workflows
- Comprehensive bilingual copy externalization

## Success Criteria

- After removing any single adapter, the core main pipeline still works completely
- Users can distinguish "core usable" from "some adapter unavailable" as two separate things
- All adapters enter the main pipeline through the same kind of material entry
- Install, instructions, state check no longer maintain separate source definitions
- Old knowledge bases and existing directory structures continue to work, no forced migration required

## Required Contracts

### 1. Unified material entry

All sources, before entering the main pipeline, must at least have this information:

| Field | Description |
|------|------|
| `source_id` | Unique identifier for source type |
| `source_label` | User-facing source name |
| `source_category` | `core_builtin` / `optional_adapter` / `manual_only` |
| `input_mode` | `url` / `file` / `text` / `asset` |
| `raw_dir` | Directory where raw material should land |
| `original_ref` | Original URL, file path, or "user paste" |
| `ingest_text` | Material text that actually enters the main pipeline |
| `adapter_name` | Which adapter was used; empty for core path |
| `fallback_hint` | How to fall back to manual entry when auto extraction fails |

### 2. Single adapter registry

Phase 1 needs a single registry describing at least:

- Source identifier and user-facing name
- Whether it belongs to core main pipeline, optional adapter, or manual-only entry
- Corresponding `raw/` subdirectory
- Entry type (URL / file / text)
- Dependency name and dependency type (built-in / install-time pulled / none)
- Fallback method

This table can later land as `tsv`, `json`, or shell-readable format; the current plan doesn't preset a specific file format, but requires **bash 3.2 consumable, human-maintainable**.

### 3. Adapter failure state table

Phase 1 uniformly uses the following five categories of state:

| State | Meaning | User-layer behavior |
|------|------|------------|
| `not_installed` | Adapter not installed | Prompt installable, allow switching to manual entry |
| `env_unavailable` | Environment doesn't meet requirements | Tell what condition is missing, allow switching to manual entry |
| `runtime_failed` | Adapter execution failed | Tell extraction failed, allow retry or continue manually |
| `unsupported` | This source currently doesn't support auto extraction | Directly give manual entry |
| `empty_result` | Adapter ran, but no valid content | Doesn't count as success, prompt user to manually complete text |

### 4. Compatibility and migration rules

- Existing knowledge base directory structures remain readable
- Old material files aren't required to be rewritten or relocated
- When new fields are missing, prioritize lazy compatibility over forced migrate
- Only when truly incompatible new structures appear later, introduce explicit migration command

## Planned Implementation Order

### Unit 1. Freeze boundary and registry

**Goal:** First pin down source boundary and unified entry, avoiding later implementations each writing their own.

**Likely files:**
- `docs/brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md`
- `docs/plans/2026-04-06-002-phase-b-core-and-adapter-separation-plan.md`
- Future new source registry file

**Exit criteria:**
- Three source categories (core / optional adapter / manual) have explicit list
- Unified entry fields are pinned down
- Later implementations no longer argue "is some source a plugin"

### Unit 2. Let main pipeline routing stand independently first

**Goal:** First ensure local files and plain text directly enter the main pipeline without going through adapter judgment.

**Likely files:**
- `SKILL.md`
- Future source registry reading script
- `tests/regression.sh`

**Exit criteria:**
- Local files / plain text don't depend on adapters
- Adapter judgment only happens for URL-type sources

### Unit 3. Introduce adapter state model

**Goal:** Handle "not installed, environment no good, run failed, unsupported, empty result" separately.

**Likely files:**
- `install.sh`
- `SKILL.md`
- Future `status` / `doctor` helper script
- `tests/regression.sh`

**Exit criteria:**
- User-layer hints no longer describe all failures as "extraction failed"
- Install output and state output give consistent classification for the same source

### Unit 4. Lock compatibility path

**Goal:** New structure must not break old knowledge bases.

**Likely files:**
- `scripts/init-wiki.sh`
- `templates/schema-template.md`
- `SKILL.md`
- `tests/regression.sh`

**Exit criteria:**
- Old directories remain readable
- When new fields are absent, default behavior still exists
- Old users aren't required to run migration first to continue using

### Unit 5. Align install, state, and tests

**Goal:** The same source definition is jointly reused by install, state, instructions, and regression checks.

**Likely files:**
- `install.sh`
- `README.md`
- `SKILL.md`
- `templates/schema-template.md`
- `tests/regression.sh`

**Exit criteria:**
- Install, instructions, state, tests use the same source definition
- Regression tests cover the bottom line of "main pipeline doesn't depend on adapters"

## Risks and Guardrails

### Risk 1: Premature platformization

If from the start we pursue "complete plugin system", workload will inflate from "cutting boundaries" into "building a platform".

**Guardrail:** All implementations must answer one question: is this step protecting the core main pipeline, or pre-building a plugin platform? The latter is deferred without exception.

### Risk 2: Docs change first, behavior doesn't follow

If README / SKILL / install / tests aren't closed off together, an illusion will arise of "looks pluggable, actually still wired in".

**Guardrail:** Only when install, state, and regression checks are all aligned is a boundary considered landed.

### Risk 3: Old knowledge bases disturbed by new rules

If the new structure requires old users to migrate first, Phase 1 violates the "users barely feel it" goal.

**Guardrail:** Compatibility over cleanliness; if lazy compatibility works, don't force migration.

## Verification Plan

When Phase 1 starts implementation, at least the following categories of verification should exist:

- Core path regression: local files / plain text still work when adapters aren't present
- Adapter missing regression: when an adapter doesn't exist, install and state hints are clear, but main pipeline unaffected
- State classification regression: five failure states don't conflate into one vague error
- Compatibility regression: old knowledge base directories and old materials still work

## Recommended Execution Order After This Plan

1. First land the single source registry and unified material entry
2. Then do adapter state classification and fallback paths
3. Then add compatibility logic
4. Finally unify install, instructions, and tests

## Implementation Status

Phase 1 has landed per the above order:

- Source registry and unified material entry landed in `scripts/source-registry.tsv`, `scripts/source-record-contract.tsv`, `scripts/source-registry.sh`
- Adapter state and fallback path landed in `scripts/adapter-state.sh`
- Old knowledge base compatibility rules landed in `scripts/wiki-compat.sh`
- Install, instructions, templates, and regression tests aligned to the same source definition

Verification commands:

- `bash tests/adapter-state.sh`
- `bash tests/regression.sh`
- `bash -n install.sh scripts/source-registry.sh scripts/adapter-state.sh scripts/wiki-compat.sh scripts/shared-config.sh tests/regression.sh tests/adapter-state.sh`
