---
title: lint-runner INDEX_FILE path error and installed copy not synced
date: 2026-04-14
category: logic-errors
module: llm-wiki lint-runner
problem_type: logic_error
component: tooling
symptoms:
  - codex reports "ERROR: index.md does not exist: .../wiki/index.md" when running lint workflow, exits with code 1
  - Phase C regression test Step B lint failure
  - After fixing source code, codex re-run still fails with the same path error
root_cause: logic_error
resolution_type: code_fix
severity: medium
tags: [path-resolution, install-sync, regression, fixture, index-file]
---

# lint-runner INDEX_FILE path error and installed copy not synced

## Problem

`lint-runner.sh`'s `INDEX_FILE` variable pointed to `$WIKI_DIR/index.md` (i.e., `$WIKI_ROOT/wiki/index.md`), but `index.md` is actually at `$WIKI_ROOT/index.md`. The path had one extra `wiki/` level, causing the script to error-exit on any normally initialized wiki. After fixing the source code, the installed copy under `~/.codex/skills/` was not synced, so codex still ran the old version.

## Symptoms

- Running `lint-runner.sh` errors: `ERROR: index.md does not exist: .../cowork-wiki/wiki/index.md`, exit 1
- Test fixture had `index.md` inside the `wiki/` subdirectory, mismatching the real wiki root layout
- After source fix, codex side re-run still failed — the installed copy was stale

## What Didn't Work

- **Assuming fixing source code alone was enough**: Codex reads the installed copy from `~/.codex/skills/llm-wiki/scripts/lint-runner.sh`; source and runtime environments are separate
- **Test fixture masked the bug**: Fixture placed `index.md` under `wiki/`, replicating the script's wrong assumption, causing tests to pass but real environments to fail

## Solution

**Fix 1: lint-runner.sh path variable**

```bash
# Before (wrong)
INDEX_FILE="$WIKI_DIR/index.md"    # -> $WIKI_ROOT/wiki/index.md

# After (correct)
INDEX_FILE="$WIKI_ROOT/index.md"   # -> $WIKI_ROOT/index.md
```

**Fix 2: Test fixture directory structure**

```
# Before
tests/fixtures/lint-sample-wiki/wiki/index.md   # extra wiki/ level

# After
tests/fixtures/lint-sample-wiki/index.md         # matches real layout
```

Also updated `tests/expected/lint-output.txt` (broken link list changed from containing `[[Ghost]]` to being reported by index consistency check).

**Fix 3: Sync installed copy**

```bash
bash install.sh --platform codex
# Syncs source fix to ~/.codex/skills/llm-wiki/scripts/lint-runner.sh
```

Verification:

```bash
grep 'INDEX_FILE=' ~/.codex/skills/llm-wiki/scripts/lint-runner.sh
# Should output: INDEX_FILE="$WIKI_ROOT/index.md"
```

## Why This Works

The core issue was a directory level error in the path variable. `$WIKI_DIR` points to `$WIKI_ROOT/wiki/` (content subdirectory), while `index.md` is actually at `$WIKI_ROOT/` (wiki root directory), confirmed by `templates/schema-template.md` line 31 — `index.md` sits alongside `raw/`, `wiki/` and other top-level directories.

The test fixture problem was that it replicated the script's wrong assumption rather than the real directory structure, creating a "tests pass but production fails" illusion.

The installed copy issue stems from the project's architecture: source repo and runtime environment (`~/.codex/skills/`) are separate; modifying source code doesn't automatically reflect to the installed location — explicit reinstall is required.

## Prevention

- **Align fixtures with real structure**: Test fixture directories must mirror from real wiki structure, not be hand-created by feel. Can validate fixture structure against schema-template.md in CI
- **Must reinstall after modifying scripts**: Already written into CLAUDE.md's pre-push testing rules — after modifying any file under `scripts/`, must `bash install.sh --platform codex` before pushing
- **Post-install smoke test**: `lint-runner.sh` already has exit 1 check when path doesn't exist, but should add a step at install flow end: `bash scripts/lint-runner.sh tests/fixtures/lint-sample-wiki` to confirm core paths resolve
- **Centralize path variable definitions**: `WIKI_ROOT`, `WIKI_DIR`, `INDEX_FILE` and other path variables should be defined in one place to avoid inconsistencies from each script assembling its own paths

## Related

- [crystallize-log-path-mismatch-2026-04-13](../documentation-gaps/crystallize-log-path-mismatch-2026-04-13.md): Same class of path confusion (`$WIKI_ROOT/wiki/log.md` vs `$WIKI_ROOT/log.md`), that time was a documentation-level fix, this time is code-level. Two occurrences indicate `$WIKI_ROOT/wiki/X` vs `$WIKI_ROOT/X` is a high-frequency error pattern in this project, worth centralizing path variable definitions
- [ingest-step1-validation-contract-and-crystallize-workflow-2026-04-13](../workflow-issues/ingest-step1-validation-contract-and-crystallize-workflow-2026-04-13.md): Issue found during the same Phase B acceptance
