---
title: Fix crystallize log path documentation vs actual location mismatch
date: 2026-04-13
category: documentation-gaps
module: llm-wiki crystallize workflow
problem_type: documentation_gap
component: documentation
symptoms:
  - Phase B acceptance instructions required checking `$WIKI_ROOT/wiki/log.md`, but the repo only generates root-level `log.md`.
  - Crystallization files were generated correctly, but acceptance still failed due to log path assertion failure.
  - Temporary wikis contained `log.md` but not `wiki/log.md`, causing test criteria and actual behavior to mismatch.
root_cause: inadequate_documentation
resolution_type: documentation_update
severity: medium
related_components:
  - development_workflow
  - testing_framework
tags: [crystallize, log-path, acceptance-test, skill-md, documentation-drift]
---

# Fix crystallize log path documentation vs actual location mismatch

## Problem
The `crystallize` workflow itself correctly generates crystallization files, but the log path in documentation had drifted. Acceptance steps required testers to check `$WIKI_ROOT/wiki/log.md`, while the repo initialization and other workflows have always used root-level `log.md`, causing Phase B acceptance criteria to conflict with actual behavior.

## Symptoms
- Following old [`SKILL.md`](../../../SKILL.md) instructions for acceptance, Phase B would fail at the log check step.
- Temporary wikis showed `wiki/synthesis/sessions/{topic}-{date}.md` generated correctly, but `wiki/log.md` was nowhere to be found.
- [`scripts/init-wiki.sh`](../../../scripts/init-wiki.sh) creates `$WIKI_ROOT/log.md`, not `$WIKI_ROOT/wiki/log.md`.
- `ingest` and all other workflows already write "update `log.md`"; only the `crystallize` section still had the old path.

## What Didn't Work
- First acceptance test strictly followed old documentation to check `wiki/log.md`, incorrectly diagnosing a documentation issue as a functional problem.
- Further investigating crystallization file generation logic couldn't resolve the acceptance failure, because the real error was in the acceptance contract, not the output flow.
- Looking at the `crystallize` section text alone made it hard to spot the problem; only by cross-referencing with the initialization script, actual wiki structure, and `ingest`'s log convention could one see this was documentation drift.

## Solution
Changed the `crystallize` log path documentation back to root-level `log.md`, consistent with the repo's actual behavior.

This fix occurred in commit `65f4a90f634461cd45dca18480e117d5a4015ff0`, with changes in two places in [`SKILL.md`](../../../SKILL.md):

```diff
-4. Update `wiki/log.md` (record this crystallization)
+4. Update `log.md` (record this crystallization)
```

```diff
-Updated wiki/log.md
+Updated log.md
```

After the fix, a new isolated wiki was created and acceptance was re-run from scratch. Results showed:
- Crystallization files still generate correctly in `wiki/synthesis/sessions/`
- Log records land in root-level `log.md`
- Checking against the corrected documentation, Phase B passes

## Why This Works
This fix directly realigns the written contract to the repo's existing real file layout.

[`scripts/init-wiki.sh`](../../../scripts/init-wiki.sh) explicitly writes:

```bash
replace_vars "$SKILL_DIR/templates/log-template.md" "$WIKI_ROOT/log.md"
```

And the `ingest` workflow has always been written as "update `log.md`". So the problem was not that `crystallize`'s implementation differed from other workflows, but that this one documentation section had drifted from the unified convention. Changing it back to `log.md` brings the acceptance steps, initialization results, and other workflows back to the same path convention, and tests naturally recover consistency.

## Prevention
- Whenever documentation says "which file is generated," cross-check against [`scripts/init-wiki.sh`](../../../scripts/init-wiki.sh)'s actual output paths item by item; don't fill in paths from memory.
- When modifying a single workflow's documentation, also check similar workflows' output conventions to avoid one section drifting from the global convention.
- When encountering "functionality appears normal but acceptance fails," first check whether the acceptance contract matches the repo's actual behavior before continuing to investigate implementation.
- For new or modified workflow documentation, do at least one end-to-end verification with a new temporary wiki to confirm that the documented file paths actually exist.

## Related Issues
- Moderate overlap: [`docs/solutions/workflow-issues/ingest-step1-validation-contract-and-crystallize-workflow-2026-04-13.md`](../workflow-issues/ingest-step1-validation-contract-and-crystallize-workflow-2026-04-13.md). It covers the introduction and validation gates for the `crystallize` workflow, but this issue is more focused on log path documentation drift.
- GitHub issues: Searched with `gh issue list --search "crystallize log.md wiki/log.md acceptance"`, no related issues found.
