---
title: fix: Separate core install from optional adapter bootstrap
type: fix
status: completed
date: 2026-04-14
origin: docs/brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md
deepened: 2026-04-14
---

# fix: Separate core install from optional adapter bootstrap

## Overview

This plan addresses the problem that the install and upgrade paths mistakenly treat "optional extractors" as "default prerequisites".

The goal is not to redo the extraction system, nor to keep expanding the installer, but to re-constrain the product promise to a more stable boundary:

- Default install and default upgrade only ensure the knowledge base core main pipeline is usable
- Automatic extraction for web pages, X/Twitter, WeChat public accounts, YouTube, and Zhihu becomes explicitly enabled
- Dependency state judgment no longer conflates source directories, installed directories, and upgrade temporary copies
- Tests and documentation protect this new default, rather than continuing to lock in the wrong default

## Problem Frame

Phase B has already made it clear that "the core main pipeline stands independently, extractors are just optional feeding capabilities" (see origin: `docs/brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md`). The current implementation says "PDF / local files / plain text don't depend on extractors" in the explanation, but the install and upgrade behavior still places optional extractors on the default main path:

- Default `install.sh` copies bundled extractors, installs Node dependencies for web extraction, then tries to install public account tools
- `install.sh --upgrade` also repeats the same optional extractor pipeline
- `SKILL.md`'s first-use description makes the agent first check these extractor dependencies; when missing, it guides all platforms to run `setup.sh`
- `adapter-state.sh` assumes by default it runs within the installed directory structure, leading to conclusion drift when debugging source code directories or troubleshooting upgrades
- `tests/regression.sh` currently writes "default install must install all optional extractors" as a regression assertion

The result: users who only want to process local documents and plain text repeatedly hit optional dependencies on pulling the latest version or reinstalling; once network is slow, source is slow, or environment is incomplete, the experience feels like "stuck on dependencies".

## Requirements Trace

- R1. Default install and default upgrade must only ensure the knowledge base core main pipeline is usable; they must not block the success path due to missing or slow optional extractors.
- R2. Optional extractors must become explicitly enabled; the corresponding install pipeline is entered only when the user explicitly needs URL-type automatic extraction.
- R3. Shared instructions and skill instructions must give correct install commands for the current platform; `setup.sh` is no longer treated as the universal entry.
- R4. Dependency state judgment must reliably distinguish between three scenarios: source directory, installed directory, and upgrade temporary copy.
- R5. Default upgrade must avoid accidentally operating on non-target platforms when multiple installed platforms exist.
- R6. Regression tests must take "core is available by default, optional features are enabled on demand" as the new protection boundary.

## Scope Boundaries

- Do not rewrite the implementation of web, YouTube, public account, or other extractors themselves.
- Do not change the content analysis, page generation, and directory structure of the core knowledge base workflows.
- Do not introduce a plugin market, auto-discovery system, or complex toggle UI.
- Do not design complex parameters for fine-grained per-source extractor selection this round; first establish "off by default, explicit enable".
- Do not require existing users to migrate existing knowledge bases.

## Context & Research

### Relevant Code and Patterns

- `install.sh` already centralizes install actions in one script, with unified entry points like `--platform`, `--upgrade`, hook registration; suitable for continuing to constrain the default path.
- `scripts/source-registry.sh` and `scripts/source-registry.tsv` already provide authoritative definitions of sources and dependencies, suitable as the single source of truth for "which are optional extractors".
- `scripts/adapter-state.sh` already handles state classification, but path resolution is still local guessing, not sharing run scenario definitions with the install script.
- `tests/adapter-state.sh` already has a state classification test skeleton, suitable for expanding to a "source / installed / upgrade temporary copy" matrix.
- `tests/regression.sh` already covers install, upgrade entries, and doc alignment, suitable for changing to protect the new default contract.

### Institutional Learnings

- `docs/plans/2026-04-06-002-phase-b-core-and-adapter-separation-plan.md` has made "the core main pipeline stands independently" the bottom line.
- `docs/solutions/integration-issues/unify-optional-adapter-states-and-fallback-paths-2026-04-06.md` explains that optional extractor failures must be clearly isolated, cannot drag down the main pipeline.
- `.context/compound-engineering/todos/005-pending-p2-separate-source-and-installed-skill-paths.md` has converged the core issue of this review to "source directory vs installed directory not clearly distinguished".
- `docs/solutions/logic-errors/lint-runner-index-path-and-install-sync-2026-04-14.md` reminds us this repo has a long-standing high-frequency risk of "source changed, but installed copy out of sync"; the plan must consider both install copy and run copy.

### External References

- No additional external references needed. The issue here is that the boundary already set by this repo hasn't been followed by the default install path; existing plans, instructions, and tests in the repo are enough to define the correct direction.

## Key Technical Decisions

- Default install contract becomes "core first, extractors explicitly enabled".
  Reason: This directly addresses R1/R2, and is the most painful point in user feedback. As long as the default path still touches optional extractors, no matter how much copy and state hints are added, the experience will continue to be dragged down.

- Add explicit switch `--with-optional-adapters` to actively enable optional extractor pipeline during install and upgrade.
  Reason: First solve the "shouldn't be installed by default" problem, more stable than starting with fine-grained per-source selection. A boolean switch is enough to express "I want to enable URL automatic extraction", and it's easier to explain clearly in docs and skill instructions.

- Keep `setup.sh` as Claude-compatible entry, but only appears in Claude-specific docs; shared instructions always use `install.sh --platform <current-platform>`.
  Reason: This preserves backward compatibility while eliminating cross-platform misleading.

- Introduce a shared run scenario resolution helper, used jointly by install script and `adapter-state.sh`.
  Reason: Path judgment for source directory, installed directory, and upgrade temporary copy cannot continue to have each script write its own version. Shared helper is more stable than "adding another special case to some script".

- Keep the `deps/` inside the `llm-wiki` package as the optional extractor source repository, but by default don't activate them as enabled extractors on the target platform.
  Reason: This way future explicit enabling doesn't need to re-pull source, and also clearly separates "skill package carries source" from "this extractor is currently enabled on this platform".

- Change test strategy from "default installs the whole suite" to "two-layer protection": default core path + explicit optional path.
  Reason: Without test guardrails, the new default contract will soon be pulled back to the old path by later changes.

## Open Questions

### Resolved During Planning

- Should default install and default upgrade continue to touch optional extractors?
  Conclusion: No. Default only guarantees the core main pipeline; extractors must be explicitly enabled.

- Does this round need to design complex parameters for fine-grained per-source extractor selection?
  Conclusion: No. This round uses `--with-optional-adapters` to establish a clear boundary; fine-grained selection deferred.

- For source vs installed directory, do we add a local special case or establish a shared model?
  Conclusion: Establish a shared model. Otherwise install script and state script will continue to drift.

### Deferred to Implementation

- Whether `--with-optional-adapters` should be extended to `--optional-adapters=<list>` later.
  Not this round; in implementation, just keep internal structure extensible.

- Whether the shared run scenario helper is a standalone `scripts/runtime-context.sh` or merged into existing `shared-config.sh`.
  Deferred to implementation, decided by shell reuse boundary, but must be single logic shared by both scripts.

- Whether to add a separate `doctor` or `status --install` diagnostic entry after install completion.
  No new command this round; first align existing install output and state output.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

### Behavior Matrix

| Scenario | Default behavior | After explicitly enabling optional extractors |
|---|---|---|
| `bash install.sh --platform <x>` | Copy core skill, scripts, templates, platform entry; do not trigger Node/uv/Chrome-related installs | Add optional extractor copy and dependency install |
| `bash install.sh --upgrade --platform <x>` | Pull latest code and update core install copy; do not trigger optional extractor install | Add optional extractor refresh and dependency install |
| Shared instructions / `SKILL.md` first use | Local files, plain text directly enter main pipeline; don't pre-check extractors | Only when user provides URL and extractor is missing, prompt current platform to run explicit switch install |
| `adapter-state.sh check` run in source directory | Read bundled dependencies in source directory location; don't mis-report as not installed | Same state model, additionally reflects environment conditions |
| `adapter-state.sh check` run in installed / upgrade temp copy | Read bundled dependencies in target skill root | Same state model, additionally reflects environment conditions |

### Shared Context Shape

- `layout_mode`: `source_checkout` / `installed_skill` / `upgrade_target`
- `bundle_root`: Root directory of the current llm-wiki body
- `optional_adapter_root`: Directory where bundled extractors should be checked or written
- `platform`: `claude` / `codex` / `openclaw` / `unknown`

All install and state judgments only read this shared result, no longer locally inferring paths from `dirname "$PROJECT_ROOT"`-style logic.

## Implementation Units

- [x] **Unit 1: Redefine the default contract for install and upgrade**

**Goal:** Change default install and default upgrade from "install optional extractors along the way" to "only guarantee core main pipeline".

**Requirements:** R1, R2, R5

**Dependencies:** None

**Files:**
- Modify: `install.sh`
- Modify: `README.md`
- Modify: `platforms/claude/CLAUDE.md`
- Modify: `platforms/codex/AGENTS.md`
- Modify: `platforms/openclaw/README.md`
- Test: `tests/regression.sh`

**Approach:**
- In `install.sh`, split "core bundle install" and "optional extractor bootstrap" into two paths.
- Keep `MANAGED_ITEMS` copying `deps/`, so the skill package continues to carry optional extractor source; the default path only skips sibling adapter install and additional dependency bootstrap.
- Add explicit switch `--with-optional-adapters` shared by `install` and `upgrade`.
- Default `install` / `upgrade` only runs the core path; only when the switch is present does it run bundled extractor copy, Node dependency install, `uv tool install`.
- Fix the behavior of `--upgrade --platform auto`: when multiple installed platforms are detected, fail directly to avoid accidentally updating multiple install copies in the default upgrade.
- Preserve existing hook behavior; don't let core upgrade break Claude's hook config.

**Patterns to follow:**
- Existing `--platform` / `--upgrade` parameter handling and unified output style in `install.sh`
- Current multi-platform install entry expression in `README.md`

**Test scenarios:**
- Happy path: When only core platform directories exist, default install completes successfully and generates `~/.<platform>/skills/llm-wiki` core copy.
- Happy path: When `--with-optional-adapters` is explicitly passed, the optional extractor pipeline runs.
- Error path: When machine has multiple platform installs and executes `bash install.sh --upgrade`, the script refuses to continue and indicates platform must be explicitly specified.
- Integration: When Claude has existing hook config, core upgrade keeps the hook config unchanged.

**Verification:**
- Default install and default upgrade output no longer contain optional extractor install success/failure as a necessary condition for the success path.
- Multi-platform upgrade no longer "automatically updates multiple install copies simultaneously".

- [x] **Unit 2: Establish shared run scenario resolution**

**Goal:** Let the install script and dependency state script use the same path model for "source directory / installed directory / upgrade temporary copy".

**Requirements:** R4

**Dependencies:** Unit 1

**Files:**
- Create: `scripts/runtime-context.sh`
- Modify: `scripts/adapter-state.sh`
- Modify: `install.sh`
- Test: `tests/adapter-state.sh`
- Test: `tests/regression.sh`

**Approach:**
- Extract shared helper, unifying resolution of `layout_mode`, `bundle_root`, `optional_adapter_root`, and `platform`.
- `install.sh` explicitly passes target root or mode in install, upgrade, and status summary calls; no longer letting `adapter-state.sh` guess itself.
- `adapter-state.sh` still keeps auto-detection fallback for manual calls, but prioritizes consuming the context explicitly passed by the caller.
- In source directory mode, bundled extractor presence should read `deps/` inside the repo; in installed directory and upgrade target modes, should read sibling directories under target skill root.
- Source directory mode needs to clearly distinguish "repo carries extractor source" from "target install copy already meets runnable conditions", avoiding residual `deps/.../node_modules` again creating the illusion of "already installed".
- Add sufficient diagnostic info to state output to help locate problems like "source code has, install copy doesn't", but don't leak debug details to default instructions for regular users.

**Patterns to follow:**
- Current "multi-script sharing single config" pattern in `scripts/shared-config.sh`
- Existing temporary skill root fixture style in `tests/adapter-state.sh`

**Test scenarios:**
- Happy path: In source directory mode checking `web_article` and `youtube_video` no longer mis-reports bundled extractors as not installed.
- Happy path: In installed directory mode, the same source check result matches the actual install state.
- Happy path: In upgrade temporary target mode, the state script reads the target directory instead of the current source directory.
- Edge case: When historical residue of `node_modules` or other extractor artifacts exists in the repo, state check doesn't mistake source directory for target install copy being ready.
- Error path: When `classify-run` preflight is `not_installed`, `env_unavailable`, or `unsupported`, original state is preserved rather than overwritten to `runtime_failed` or `empty_result`.

**Verification:**
- The same fixture in three modes produces conclusions that only vary with actual directory and environment, no longer drifting with script execution location.

- [x] **Unit 3: Change shared instructions and skill routing to on-demand check optional extractors**

**Goal:** Let users be guided to enable optional extractors only when they really need URL automatic extraction.

**Requirements:** R1, R2, R3

**Dependencies:** Unit 1

**Files:**
- Modify: `SKILL.md`
- Modify: `README.md`
- Modify: `setup.sh`
- Modify: `platforms/claude/CLAUDE.md`
- Modify: `platforms/codex/AGENTS.md`
- Modify: `platforms/openclaw/README.md`
- Test: `tests/adapter-state.sh`
- Test: `tests/regression.sh`

**Approach:**
- Remove the "check all extractor dependencies first on first use" default prerequisite description from `SKILL.md`, change to two-layer explanation:
  - Core main pipeline prerequisites: can run shell, can read/write local files
  - URL automatic extraction additional conditions: only check Chrome / uv / extractor when hitting the corresponding source
- Unify the supplementary install command for missing extractors to current platform's `bash install.sh --platform <current-platform> --with-optional-adapters`.
- `setup.sh` keeps Claude-compatible wrapping, but in docs it's only mentioned at Claude-specific entries, no longer appearing in shared instructions and cross-platform skill instructions.
- README's "update" instructions sync to: default upgrade updates core; if need to re-pull optional extractors, explicitly add switch.

**Patterns to follow:**
- README.md's current "shared instructions + thin platform entries" structure
- Current source-based URL / file / text routing organization in `SKILL.md`

**Test scenarios:**
- Happy path: When only processing local files or plain text, skill instructions no longer require first installing web/YouTube/public account extractors.
- Happy path: When hitting a URL source with extractor not enabled, instructions give explicit supplementary install command for current platform.
- Error path: Codex or OpenClaw docs no longer treat `setup.sh` as a universal supplementary install action.
- Integration: README, platform entries, and `SKILL.md` three locations keep consistent wording on default install vs explicit enabling.

**Verification:**
- Shared instructions and platform entries no longer misleadingly give Claude-specific commands to other platforms.
- Local file / plain text workflows no longer polluted by optional extractor thresholds at the instruction layer.

- [x] **Unit 4: Rewrite regression matrix, lock new default boundary**

**Goal:** Let tests protect the new contract of "core available by default, optional features explicitly enabled", and fill regression gaps for upgrade and run scenarios.

**Requirements:** R4, R5, R6

**Dependencies:** Unit 1, Unit 2, Unit 3

**Files:**
- Modify: `tests/regression.sh`
- Modify: `tests/adapter-state.sh`

**Approach:**
- Change the existing "default install should install all extractors" assertion to:
  - Default install only verifies core copy lands and doesn't block
  - Only when explicit `--with-optional-adapters` verify extractors are copied/installed
- Add fixtured regression for `upgrade`:
  - Core upgrade when installed copy exists
  - `--upgrade` refusal branch when multiple platforms exist
  - hook config preserved
- Add three-category run scenario matrix and preflight preservation assertion for `adapter-state`.
- Keep existing state classification tests, but reorganize them around the shared context helper rather than only testing a single path.

**Patterns to follow:**
- `tests/regression.sh`'s current way of simulating install environment with temporary HOME and stub binaries
- `tests/adapter-state.sh`'s current way of assembling small fixtures with `mktemp` skill root

**Test scenarios:**
- Happy path: Default install completes core install successfully even without `bun`, `uv`, or Chrome debug port.
- Happy path: With explicit optional extractors enabled, web extraction Node dependencies and public account tool install pipeline runs.
- Error path: Default upgrade with multiple platforms installed, test should see the script refuse to continue.
- Integration: Running state check from source directory, installed directory, and upgrade target directory respectively, output matches actual directory state.

**Verification:**
- Regression suite will directly fail on changes like "who re-stuffed optional extractors back into the default path".

## System-Wide Impact

- **Interaction graph:** `install.sh`, `SKILL.md`, `README.md`, platform entries, and tests change together; any location retaining the old default will pull users back to the wrong path.
- **Error propagation:** Default path no longer propagates Node, uv, Chrome-related issues as install failures; these errors only appear after explicit optional extractor enabling.
- **State lifecycle risks:** If the run scenario helper isn't uniformly used by all callers, source directory and installed directory will continue to drift.
- **API surface parity:** Three platforms' install wording must stay consistent; Claude's compatibility entry can only be kept as a special case, cannot re-leak to shared instructions.
- **Integration coverage:** Unit shell assertions alone aren't enough; must add combined regression of "default install + explicit optional + upgrade + three run scenarios".
- **Unchanged invariants:** Main workflow for local files, plain text, and initialized knowledge bases remains unchanged; URL automatic extraction still exists, just moved out of the default install path.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| After adding new switch, README / SKILL / platform entries drift again | Constrain together in Unit 3 and Unit 4, protected simultaneously by string assertions and install regression |
| Shared run scenario helper design too heavy, instead expanding change surface | Only extract path and mode resolution, not install business logic |
| After default upgrade changes to core-first, existing users think optional extractors "got deleted" | Clearly write in upgrade output and README: "core updated; if URL automatic extraction needed, add explicit switch" |
| Existing compatibility entry `setup.sh` being fully marginalized causes confusion for Claude legacy users | Keep the wrapping script, only adjust where it appears in docs |

## Documentation / Operational Notes

- README needs to change "default upgrade installs dependencies" to "default upgrade only updates core".
- Platform thin entries should uniformly add a line: URL automatic extraction is an optional feature and needs to be explicitly enabled.
- Install output recommends separating "core ready" from "optional extractor state", avoiding users misinterpreting optional problems as core unavailability.

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/docs/brainstorms/2026-04-06-project-cleanup-and-restructuring-requirements.md)
- Related plan: [docs/plans/2026-04-06-002-phase-b-core-and-adapter-separation-plan.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/docs/plans/2026-04-06-002-phase-b-core-and-adapter-separation-plan.md)
- Related solution: [docs/solutions/integration-issues/unify-optional-adapter-states-and-fallback-paths-2026-04-06.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/docs/solutions/integration-issues/unify-optional-adapter-states-and-fallback-paths-2026-04-06.md)
- Related solution: [docs/solutions/logic-errors/lint-runner-index-path-and-install-sync-2026-04-14.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/docs/solutions/logic-errors/lint-runner-index-path-and-install-sync-2026-04-14.md)
- Related todo: [.context/compound-engineering/todos/005-pending-p2-separate-source-and-installed-skill-paths.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/.context/compound-engineering/todos/005-pending-p2-separate-source-and-installed-skill-paths.md)
