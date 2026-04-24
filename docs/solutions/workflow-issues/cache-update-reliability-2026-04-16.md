---
title: Cache update reliability — from "depending on model behavior" to "atomic + self-healing"
date: 2026-04-16
category: docs/solutions/workflow-issues
module: ingest-workflow
problem_type: workflow_issue
component: tooling
severity: medium
root_cause: inadequate_documentation
resolution_type: workflow_improvement
applies_when:
  - Critical side effects in AI-driven workflows depend on the model executing subsequent steps
  - Multi-model compatibility scenarios (weaker models have low compliance with long workflows)
  - When cache state and file system state may be inconsistent and need self-healing
tags: [cache, ingest, workflow, reliability, write-through, self-healing]
---

# Cache update reliability — from "depending on model behavior" to "atomic + self-healing"

## Context

llm-wiki-skill's ingest workflow contains 13 steps, executed sequentially by AI models (Claude, DeepSeek, Qwen, Kimi). Step 4 performs `cache.sh check`, Step 12 performs `cache.sh update`.

Weaker models in long workflows frequently **skip Step 12's cache update**, causing already-processed files to still show MISS on next ingest, triggering redundant processing. This is not a code bug but a design-level reliability deficiency: cache updates entirely depend on whether the model "remembers" to execute step 12.

The project's core principle is "multi-model friendly" — weaker models must be able to correctly complete the flow, so this dependency must be eliminated at the architecture level.

## Guidance

### Core principle: Critical side effects should not depend on model behavior; they should be atomically bound via scripts

Merge "write file" and "update cache" into a single atomic operation. The model only needs to call one script, and cache update completes automatically. Also add a self-healing mechanism so even if the cache is missing, it can be reverse-recovered from existing files.

### Pattern 1: Write-through atomic script

`scripts/create-source-page.sh` binds source page write + cache update as one operation:

```bash
# Usage
bash scripts/create-source-page.sh <raw_file> <output_path> <content_file>

# Internal flow:
# 1. Temp file + mv atomic write to output_path
# 2. Call cache.sh update raw_file output_path
# 3. cache update fails -> delete written file, rollback
# 4. Both steps succeed -> return SUCCESS
```

The model at Step 8 only needs to call this one script; no need to remember to update cache at Step 12.

### Pattern 2: Cache self-healing

`scripts/cache.sh check` proactively probes existing files on MISS, using filename stem exact match:

```python
# Python logic inside cache_check() (simplified)
raw_stem = pathlib.Path(relative_path).stem
sources_dir = os.path.join(wiki_root, "wiki", "sources")

if os.path.isdir(sources_dir):
    for f in os.listdir(sources_dir):
        if pathlib.Path(f).stem == raw_stem and f.endswith(".md"):
            # Self-heal: rebuild cache entry from existing source page
            save_cache_entry(relative_path, current_hash, source_page)
            print("HIT(repaired)")
```

MISS reason breakdown helps models and users understand current state:

- `MISS:no_entry` — First-time processing, normal
- `MISS:hash_changed` — Source material content changed, needs reprocessing
- `MISS:no_source` — Cache exists but source page was deleted

### Pattern 3: Workflow simplification

SKILL.md changes:

- Step 4: Display MISS reason and `HIT(repaired)` status
- Step 8: Source page write now uses `create-source-page.sh`
- Step 12: **Removed** `cache.sh update` call (now automatically done by Step 8)

## Why This Matters

**Eliminates an entire class of failures.** Previously every time a weak model skipped Step 12, cache would become stale, and the error was silent (no error message, just redundant processing). After atomicization, as long as the model executes "write file" (not doing it = no output = flow failure), cache is guaranteed to update.

**Self-healing is a safety net.** Even if the atomic script isn't called (manual operation, script interruption), self-healing can reverse-rebuild cache entries from existing files.

**MISS reason classification aids debugging.** Models and users can distinguish between "new file", "file modified", and "source lost" scenarios.

## When to Apply

- In AI-driven workflows, when critical side effects (cache write, index update, status marking) depend on model executing subsequent steps -> bind to earlier, unavoidable operations
- Multi-model compatibility scenarios -> architecture design cannot assume models will perfectly execute every step
- Cache systems prone to "drift" (cache state vs actual files inconsistent) -> need self-healing capability
- Idempotency required -> repeating the same operation should not produce extra side effects

## Examples

### Before

```
Step 8:  Write source page to wiki/sources/example.md
         (model writes file, cache not updated)

... Steps 9-11 in between ...

Step 12: bash scripts/cache.sh update raw/example.md
         (weak models often skip this step)

Result: next ingest of the same file, cache.sh check returns MISS, redundant processing
```

### After

```
Step 8:  bash scripts/create-source-page.sh raw/example.md \
           wiki/sources/example.md /tmp/content.txt
         -> SUCCESS (file write + cache update completed atomically)

Step 12: (removed — cache update now done automatically by Step 8)

Even if historical cache is lost, self-healing provides a safety net:
Step 4:  bash scripts/cache.sh check raw/example.md
         → HIT(repaired)
```

## Related

- `docs/solutions/workflow-issues/ingest-step1-validation-contract-and-crystallize-workflow-2026-04-13.md` — sibling doc, also ingest workflow hardening (Step 1 validation)
- `docs/plans/2026-04-11-wiki-core-upgrades-design.md` — original cache system design, defining check/update/invalidate semantics
- PR #10 — full diff of this fix
