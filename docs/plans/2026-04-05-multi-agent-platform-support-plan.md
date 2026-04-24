<!-- /autoplan restore point: /Users/kangjiaqi/.gstack/projects/sdyckjq-lab-llm-wiki-skill/main-autoplan-restore-20260405-165224.md -->
---
date: 2026-04-05
topic: multi-agent-platform-support
status: reviewed
requirements: /Users/kangjiaqi/Desktop/project/llm-wiki-skill/docs/brainstorms/2026-04-05-multi-agent-platform-support-requirements.md
---

# llm-wiki multi-platform adaptation implementation plan

## Plan Summary

The goal of this refactoring is not to "write the repo for three platforms simultaneously", but to turn the repo into a unified source, and then have thin platform entries connect the same set of capabilities to Claude Code, Codex, and OpenClaw. Users externally only see one GitHub link; internally each platform sees its familiar install entry and usage; the project body still only maintains one set of knowledge base capabilities.

The recommended route is: keep the existing knowledge base logic, templates, scripts, and dependency handling as the shared core; first remove platform coupling from core files, then add a unified installer and three platform entries, and finally use an explicit verification matrix to prove this isn't "looks compatible" but actually installable, usable, and without capability loss.

## Problem Frame

The current repo has `CLAUDE.md`, `AGENTS.md`, and some Codex instructions, but the real workflow entries, install paths, and copy are still clearly biased toward Claude Code. The result is:

- When users give the repo link to different agents, install and entry are unstable
- The same knowledge base capabilities get polluted by platform-specific terminology; future platform expansion will get messier and messier
- Dependency and fault recovery already have a prototype, but lack a unified install contract to catch multi-platform scenarios

This isn't a "copy problem" but a problem caused by product entry, repo structure, and install path coupling simultaneously.

## Premises

| # | Premise | Assessment | Notes |
|---|---------|------------|-------|
| P1 | Users mainly install by "throwing the GitHub link at an agent" | Confirmed | User has explicitly prioritized agent auto-install |
| P2 | First version must preserve complete functionality, no stripped-down version accepted | Confirmed | All 8 workflows need to be preserved |
| P3 | Platform differences mainly concentrate in install, entry, and prompt methods, not knowledge base rules themselves | Confirmed | Repo scan supports this |
| P4 | Short-term, can continue to keep external material extraction dependencies | Confirmed with caution | But this round won't redo extraction; only record for later |
| P5 | Single-repo is more aligned with current goals than multi-repo | Confirmed | Unified link is the core demand |
| P6 | Pure shell auto-detection can't always know "which platform we're installing for" | Confirmed | So repo entry docs must explicitly guide agent to pass explicit `--platform` |

## System Audit

### Current System State

- Current main capability centralized in [SKILL.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/SKILL.md)
- Install logic centralized in [setup.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/setup.sh)
- Initialization logic centralized in [scripts/init-wiki.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/scripts/init-wiki.sh)
- Platform instructions currently scattered in [README.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/README.md), [CLAUDE.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/CLAUDE.md), [AGENTS.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/AGENTS.md)
- Most-recent-30-days frequently-modified files concentrated in `SKILL.md`, `README.md`, `setup.sh`, `scripts/init-wiki.sh`

### In-Flight / Known Context

- Current branch is `main`
- No current stash
- Before this plan started, the repo had no `TODOS.md`; existing todos mainly in [PLAN.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/PLAN.md)
- [PLAN.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/PLAN.md) has already clearly pointed out "insufficient platform coverage" and "too-tight Claude Code binding" as current problems
- Found one structural problem directly related to this plan:
  - Install path in repo appears in three forms `~/.claude/skills`, `~/.Codex/skills`, and the actual environment's `~/.codex/skills`; without unifying them, confusion will persist

### Relevant Design Context

- There's an existing design doc [kangjiaqi-unknown-design-20260405-125420.md](/Users/kangjiaqi/.gstack/projects/LLMknowledgeskill/kangjiaqi-unknown-design-20260405-125420.md)
- That design doc focuses on "domestic beginner llm-wiki"; can reuse its product goals and low-threshold requirements
- But that design doc defaults platform to Claude Code; insufficient to directly answer this multi-platform question

## What Already Exists

| Sub-problem | Existing asset | How we should reuse it |
|-------------|----------------|------------------------|
| Knowledge base workflow definitions | [SKILL.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/SKILL.md) | Continue as main capability source, but remove platform-hardcoded statements |
| Knowledge base directories and templates | [templates/](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/templates) | Share directly, no platform forking |
| Initialization script | [scripts/init-wiki.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/scripts/init-wiki.sh) | Continue sharing; only remove Claude-specific closing copy |
| Dependency install and environment check | [setup.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/setup.sh) | Upgrade to unified installer rather than Claude-only |
| Claude project instructions | [CLAUDE.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/CLAUDE.md) | Change to Claude adapter-layer instructions, not the sole product instructions |
| Codex project instructions | [AGENTS.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/AGENTS.md) | Upgrade to one of the cross-platform shared instruction sources |
| Existing install / DX conclusions | [PLAN.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/PLAN.md) | Reuse its conclusions about install failure points, paths, dependency checks |

## Landscape Check

- Claude Code official docs treat `CLAUDE.md` as memory file loaded at startup; also supports skills and plugin extensions. This means Claude adapter layer should continue to exist, but shouldn't also carry the global product definition.
- OpenAI official docs clearly state Codex reads the repo's `AGENTS.md` instruction file; this means repo-level instructions are a first-class entry point for Codex and can't only do local skill install while ignoring repo-root instructions.
- OpenClaw official docs explain the system prompt injects available skills list, and supports shared or workspace-level skills. This means OpenClaw doesn't need an independent product fork, just correct skill landing and entry shell.

## NOT in Scope

- Rewriting web, X, YouTube material extraction capabilities
- Retrofitting into a Web App, desktop App, or SaaS
- Covering more platforms beyond Claude Code / Codex / OpenClaw
- Maintaining separate long-term knowledge base logic per platform

## Dream State

```text
CURRENT
  One repo, one main skill spec, but strongly Claude-shaped
  ↓
THIS PLAN
  One repo, one shared core, three native entry layers, one installer
  ↓
12-MONTH IDEAL
  One repo, many adapters, install-on-link reliability, key dependencies gradually internalized
```

### Dream State Delta

- `CURRENT → THIS PLAN`
  - Platform instructions change from mixed to layered
  - Install upgrades from "written for humans" to "agent-executable"
  - Preserves existing capabilities; no longer treats Claude as sole default platform
- `THIS PLAN → 12-MONTH IDEAL`
  - Gradually internalize key material extraction capabilities later
  - Expansion to more agent platforms only adds adapter layers

## Implementation Alternatives

| Approach | Description | Pros | Cons | Recommendation |
|----------|-------------|------|------|----------------|
| A. Single-file hard compatibility | Continue using one large `SKILL.md` mixing three platform rules | Fastest to change | Worst later maintenance; copy and rules will continue to fight | Reject |
| B. Single repo + shared core + platform adapter layer | Core capabilities shared, platform entries and install logic layered | Best aligned with "one link + multi-platform native support" | Requires one-time structure cleanup | Choose |
| C. Multi-repo distribution | Claude/Codex/OpenClaw each maintain separate versions | Each platform fully customizable | Highest maintenance cost, easiest to drift | Reject |

## Chosen Approach

Chosen **B. Single repo + shared core + platform adapter layer**.

### Why this is the right balance

- Preserves the "one official link" distribution advantage
- Avoids dragging repo into "three similar files drift long-term" trap
- Allows install and entry to be native per platform, without having to rewrite the knowledge base body

## Target Architecture

### High-Level Dependency Graph

```text
                     [GitHub Repo: llm-wiki-skill]
                                |
      ---------------------------------------------------------
      |                         |                            |
      v                         v                            v
[Shared Core]            [Unified Installer]         [Platform Adapters]
  SKILL core               install.sh                 claude/
  templates/               doctor.sh (optional)       codex/
  scripts/                 dry-run support            openclaw/
  deps/                                                 
      |                         |                            |
      ---------------------------------------------------------
                                |
                                v
                    Detected target platform(s)
                                |
        ------------------------------------------------------------
        |                          |                              |
        v                          v                              v
 Claude Code install        Codex install                  OpenClaw install
 ~/.claude/skills/...       ~/.codex/skills/...            ~/.openclaw/skills/...
 CLAUDE.md import path      AGENTS.md + skill bundle       skill bundle / workspace skill
```

### Key Architectural Principle

**Root repo becomes the universal installation contract.**
Instead of making all three platforms eat the same entry file, make the repo root clearly tell the agent:

- What capabilities this project provides
- Where the installer is
- How platform recognition is done
- If you're some platform, which layer should be installed where

This is more stable than "forcing all platforms to share one entry file" and better fits existing platform reality.

## Installation Contract

### Default rule

- The repo root docs tell the current agent: whichever platform you belong to, call `./install.sh --platform <your-platform>`
- `install.sh --platform auto` only takes effect when "only one supported platform is detected"
- If multiple supported platforms are detected, the installer doesn't guess; the current agent passes the explicit parameter per its own platform

### Why this contract is necessary

- This avoids the high-cost-low-value complexity of "script guessing platform wrong"
- This still satisfies the "one-command install" user experience, since the agent passes in the platform on behalf of the user
- This is more controllable than "install all three platforms by default" and easier to rollback and troubleshoot

## Compatibility / Migration

- Keep existing [setup.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/setup.sh) as a compatibility entry, don't delete directly
- `setup.sh` in the first phase only does one thing: delegate to the new installer and explicitly run Claude-compatible mode
- Existing Claude users can continue to use the old command; won't immediately fail due to multi-platform refactoring
- Codex path compatible with both `~/.codex` and `~/.Codex`, but planned to converge to one standard spelling with migration safety net
- OpenClaw first supports shared skill install, then decides whether workspace fallback is needed based on actual verification

## Platform Capability Map

| Platform | Current official model | Relevant source | Planning implication |
|----------|------------------------|-----------------|----------------------|
| Claude Code | Native skill support; `CLAUDE.md` is project memory entry; skills can be placed in `.claude/skills/<name>/SKILL.md` | Anthropic docs: skills + memory | Need to preserve Claude skill entry, but don't let it swallow the global product description |
| Codex | Official emphasizes that `AGENTS.md` in repo persistently guides Codex; Codex also supports skills workflow | OpenAI docs: Codex + AGENTS.md + skills | Need to provide both repo-level `AGENTS.md` description and Codex skill install path compatibility |
| OpenClaw | Native support for shared/workspace skills; supports `~/.openclaw/skills` and workspace `skills/` | OpenClaw docs: skills / plugins / bootstrapping | Need to provide OpenClaw shared skill install landing, try not to require user to manually configure plugins |

## Detailed Plan

### Phase 1: Uncouple the Shared Core

**Goal:** First decouple "knowledge base capabilities themselves" from Claude-style terminology.

**Changes**

- Transform [SKILL.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/SKILL.md) into shared core doc:
  - Change platform-hardcoded statements like `AskUserQuestion`, `Read tool`, `Write tool`, `Skill tool` to platform-neutral statements
  - Keep 8 workflows and all knowledge base logic unchanged
- Adjust [scripts/init-wiki.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/scripts/init-wiki.sh) user prompt copy, no longer only mentioning Claude
- Clean up unnecessary Claude/Codex example bias in templates and schema, keep content semantics unchanged

**Why first**

- Without first decoupling the core, the platform adapter layer later just keeps patching on a wrong center

**Files likely touched**

- [SKILL.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/SKILL.md)
- [scripts/init-wiki.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/scripts/init-wiki.sh)
- [templates/schema-template.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/templates/schema-template.md)

**Exit criteria**

- Shared core no longer contains "the sole correct approach only for some platform"
- All three platforms can call the same set of 8 workflow definitions through their adapter layers

### Phase 2: Add Platform Adapter Layers

**Goal:** Provide native entries for Claude Code, Codex, and OpenClaw respectively.

**Changes**

- Add `platforms/claude/`
  - Place Claude skill entry file and Claude-specific supplementary instructions
- Add `platforms/codex/`
  - Place Codex skill entry / install instructions
  - Complement with repo root [AGENTS.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/AGENTS.md)
- Add `platforms/openclaw/`
  - Place OpenClaw skill entry file
  - Prepare content for `~/.openclaw/skills` shared install pattern
- Transform [CLAUDE.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/CLAUDE.md) and [AGENTS.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/AGENTS.md) into:
  - Root shared install instructions + platform jump hints
  - Claude also reads project-common rules via `CLAUDE.md` import/shared text

**Why second**

- Only after the shared core is stable can the platform adapter layer become a "thin shell" rather than another body of main logic

**Files likely touched**

- [CLAUDE.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/CLAUDE.md)
- [AGENTS.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/AGENTS.md)
- new: `platforms/claude/...`
- new: `platforms/codex/...`
- new: `platforms/openclaw/...`

**Exit criteria**

- All three platforms each have their own "looks natural" entry
- Platform entry body text is mainly "how to connect to shared core", not copying the 8 workflows
- All three platform entries clearly tell the agent how to call the unified installer

### Phase 3: Replace setup.sh with a Unified Installer

**Goal:** Upgrade from "Claude's setup script" to "unified installer".

**Changes**

- Upgrade or split [setup.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/setup.sh) into:
  - `install.sh`: unified entry
  - `setup.sh`: kept as compatibility shell, internally delegates to `install.sh --platform claude`
- Installer has the following capabilities:
  - When `--platform` is explicitly passed, install per target platform
  - Only when `auto` and only one platform detected, do auto-detect install
  - Support `--dry-run` for agent verification without polluting real directories
  - Install shared core + corresponding adapter layer to the correct directory per platform
  - Unified dependency check (bun/npm, uv, Chrome port, etc.)
- Handle `~/.codex` / `~/.Codex` path difference:
  - Detect existing environment, prioritize really-existing path
  - Clearly pick one standard spelling and keep compatibility logic

**Why third**

- Only after platform adapter layer is finalized can the installer correctly copy the right content to the right place in one pass

**Files likely touched**

- [setup.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/setup.sh)
- new: `install.sh`
- optional: `scripts/install-lib.sh` only if `install.sh` obviously gets out of control; default is not to split helper first

**Exit criteria**

- User or agent only needs one install command
- Installer can in dry-run mode clearly output "what will be installed, where"
- Old Claude install command still works

### Phase 4: Rewrite the Root Entry Surfaces for Agent-First Discovery

**Goal:** When users give the repo link to an agent, the agent can more easily read and execute install itself.

**Changes**

- Rewrite [README.md](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/README.md):
  - First screen no longer says "built for Claude Code"
  - Add "one-sentence install for agents"
  - Add unified command install
- Adjust root instruction file responsibilities:
  - README: main entry for humans and agents
  - AGENTS: executable project instructions for Codex / OpenClaw / generic agents
  - CLAUDE: project instructions for Claude, and import shared rules
- Add `INSTALL.md` or `docs/install/`:
  - Uniformly list target landing, auto-detect, and exceptions for three platforms

**Why fourth**

- Only after correct structure and installer are in place, rewriting entry instructions prevents docs from going wrong again

**Exit criteria**

- README first screen can clearly answer: what is this, how to install, what should the agent do
- No longer need to read full README to know it's not "for Claude only"
- Root instructions clearly state: when repo link is given to agent, agent should call explicit `--platform` per its own platform

### Phase 5: Add Verification Matrix and Regression Harness

**Goal:** Use a reproducible way to prove "multi-platform native support" isn't just words.

**Changes**

- Extend [tests/regression.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/tests/regression.sh) or add smoke tests:
  - Simulate Claude / Codex / OpenClaw install in temp HOME directories respectively
  - Verify key files exist after install, paths correct, entry files readable
  - Keep compat regression test for old `setup.sh`, ensure existing Claude install command doesn't regress
- Add a manual verification checklist:
  - agent auto-install hint
  - Whether init/ingest/query three main paths can walk through
  - Whether graph/digest/lint/status are still preserved
- Post-install hint:
  - Clear how agent should hint and recover when Chrome/uv missing

**Why last**

- Verification should target final structure, not mid-process structure

**Exit criteria**

- Each platform has at least one auto smoke check
- Install and core usage paths have clear manual acceptance checklist

## Sequencing

```text
Phase 1 shared core decoupling
   ↓
Phase 2 three platform entry layers
   ↓
Phase 3 unified installer
   ↓
Phase 4 root entry rewrite (README / AGENTS / CLAUDE)
   ↓
Phase 5 verification matrix and regression check
```

### Why this order is right

- First handle core, then adapt, avoiding three-side rework
- First define "what to install" clearly, then write "how to install"
- Finally add verification, ensuring what's tested is the final form rather than a half-product

## Execution Breakdown

| Step | Outcome | Human effort | CC effort | Notes |
|------|---------|--------------|-----------|-------|
| 1 | Shared core de-platformization | ~0.5 day | ~20 min | High value, low risk |
| 2 | Three platform entry shells | ~1 day | ~30 min | Mainly structure and instruction organization |
| 3 | Unified installer | ~1 day | ~30 min | Highest risk, needs dry-run |
| 4 | Root entry doc rewrite | ~0.5 day | ~20 min | Delivered with installer has most value |
| 5 | Verification and regression | ~1 day | ~30 min | Not omittable |

## Error & Rescue Registry

| Failure | Likely cause | User impact | Rescue |
|--------|--------------|-------------|--------|
| Install to wrong directory | Platform path hardcoded or case-inconsistent | Skill installed but platform can't see | Installer first detects path, then outputs final landing |
| Claude continues reading only CLAUDE ignoring shared rules | `CLAUDE.md` doesn't import shared content | Claude behavior drifts from other platforms | Use `CLAUDE.md` to explicitly import shared instructions |
| Codex only eats AGENTS, not skill bundle | Different Codex forms have different entries | Repo link works, but local skill install unstable | Provide both repo-level `AGENTS.md` and local skill bundle compatibility |
| OpenClaw installs to workspace instead of shared path | agent/user environment differs | Skill only visible in current workspace | Prioritize shared path, support workspace fallback when necessary |
| Install success but dependencies not all installed | bun/npm, uv, Chrome not ready | URL sources can't fully work | Installer unified check and gives recovery hint |
| Shared core and platform adapter layer content drifts | Too much copy-paste | Functions inconsistent across three platforms | Platform entry only keeps thin shell, doesn't copy main logic |
| Old Claude install command invalid | Directly replaced `setup.sh` behavior | Existing users can't upgrade | Keep compatibility shell and add regression test |

## Failure Modes Registry

| Area | Failure mode | Severity | Mitigation |
|------|--------------|----------|------------|
| Structural design | Shared core still has platform-specific terminology residue | High | Phase 1 does full-text decoupling scan |
| Install | Auto-detect mis-judges user platform | High | Repo root explicitly guides agent to pass `--platform`; `auto` only takes effect when single platform |
| Path | `.Codex` / `.codex` conflict | High | Unify standard spelling + compatibility branch |
| Docs | README still talks Claude first | Medium | Doc rewrite later than structural design, ensures no rework |
| Verification | Only test install, not usage | High | Add manual verification matrix for main paths |
| Later maintenance | Copy another set of logic when adding new platform | Medium | Clarify shared core and adapter layer boundary |
| Upgrade | Existing old-version users can't migrate smoothly | High | Add compatibility install path and setup regression test |

## Test Diagram

```text
INSTALL PATH COVERAGE
=====================

[Entry]
  ├── GitHub repo link handed to agent
  │   ├── [GAP] agent reads root README/AGENTS/CLAUDE correctly
  │   └── [PLAN] rewrite root entry docs for agent-first discovery
  │
  └── install.sh
      ├── detect Claude
      │   ├── install shared core
      │   ├── install Claude adapter
      │   └── verify ~/.claude/skills/... exists
      │
      ├── detect Codex
      │   ├── normalize ~/.codex vs ~/.Codex
      │   ├── install shared core
      │   ├── install Codex adapter
      │   └── verify skill/AGENTS compatibility
      │
      ├── detect OpenClaw
      │   ├── install shared core
      │   ├── install OpenClaw adapter
      │   └── verify ~/.openclaw/skills/... exists
      │
      └── dependency checks
          ├── bun/npm
          ├── uv
          └── Chrome debug port

USAGE FLOW COVERAGE
===================

Installed skill
  ├── init
  ├── ingest
  ├── query
  ├── digest
  ├── lint
  ├── status
  └── graph

Each platform must prove:
  1. skill visible
  2. skill instructions load
  3. core workflow names still reachable
  4. dependency problems surface as actionable guidance
  5. existing Claude install command still upgrades cleanly
```

## Verification Plan

### Automated

- Install dry-run: run once for Claude / Codex / OpenClaw each
- Temp HOME smoke install: verify final directories and key entry files exist
- Shared core scan: block newly added Claude-only / Codex-only platform-hardcoded terminology from flowing back

### Manual

- Give repo link to Claude Code, confirm agent can find unified install entry
- Give repo link to Codex, confirm agent can complete install per Codex habits
- Give repo link to OpenClaw, confirm shared skill landing is correct
- Verify at least `init`, `ingest`, `query` on each platform
- Pick one platform additionally test `digest`, `lint`, `status`, `graph`

## Deferred to Later

- Internalization plan for material extraction capabilities
- Expansion to more agent platforms
- If later confirmed needed, further split installer into formal doctor / migrate / uninstall subcommands

## Temporal Interrogation

### Hour 1

- Lock unified install contract and `--platform` rule
- Complete shared core decoupling checklist
- Clarify which old entries must keep compatibility

### Hour 6

- Three platform entry shells have prototypes
- `install.sh --dry-run` can print each platform's target paths and actions
- `setup.sh` has become compatibility shell

### Day 2

- Root README / AGENTS / CLAUDE rewritten per new responsibilities
- Three-platform smoke install passes
- Old Claude install command regression doesn't fail

### 6 Months

- Key paths of material extraction gradually internalized
- New platform expansions mainly add adapter layers, not touch knowledge base core

## CEO Review Summary

| Dimension | Assessment | Notes |
|-----------|------------|-------|
| Right problem | Strong | Directly addresses real demand of "one link, multi-platform, fully usable" |
| Scope calibration | Correct after tightening | Removed redoing material extraction in same round, kept multi-platform main line |
| Simplicity | Improved | Explicit `--platform` rule avoids over-smart detection |
| 6-month trajectory | Strong | Shared core + thin adapter layer more sustainable than multi-repo |

## Engineering Review Summary

| Dimension | Assessment | Notes |
|-----------|------------|-------|
| Architecture | Sound with migration guardrails | Clear boundary between core and adapter layer; compatibility shell reduces upgrade risk |
| Complexity | Acceptable | Biggest risk is installer; tightened via explicit platform param and not splitting helper first |
| Testability | Good after additions | Added old `setup.sh` compat regression and temp HOME smoke install |
| Residual risk | Medium | Codex/OpenClaw real install landing still needs actual environment verification |

## Independent Codex Notes

- Existing [tests/regression.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/tests/regression.sh) and [setup.sh](/Users/kangjiaqi/Desktop/project/llm-wiki-skill/setup.sh) are both typical Claude-only assumption sources; so migration plan must treat "old command doesn't regress" as a first-class constraint.
- Installer shouldn't split into multi-layer helpers in the first round; first do explicit `--platform`, dry-run, and compatibility shell well, then decide whether abstraction is needed.

<!-- AUTONOMOUS DECISION LOG -->
## Decision Audit Trail

| # | Phase | Decision | Principle | Rationale | Rejected |
|---|-------|----------|-----------|-----------|----------|
| 1 | Draft | Adopt "single repo + shared core + platform adapter layer" | P1 Choose completeness | Satisfies both unified link and later expansion goals | Multi-repo distribution |
| 2 | Draft | Don't redo material extraction this round, only record for later phase | P3 Pragmatic | User explicitly wants multi-platform adaptation first this round | Refactor extraction layer same round |
| 3 | Draft | Unified installer implemented later than platform entry layer | P5 Explicit over clever | First define what to install, then implement how to install; less rework | Change installer first and back-derive structure |
| 4 | Review | Default has current agent explicitly pass `--platform`, rather than script blind-guessing | P5 Explicit over clever | More stable and easier to troubleshoot than multi-platform auto-guess | Default installs all detected platforms |
| 5 | Review | Keep `setup.sh` as Claude compatibility shell | P1 Choose completeness | Can't break existing users' upgrade path for sake of new platform | Directly replace old command with `install.sh` |
| 6 | Review | Don't split `install-lib` helper first | P3 Pragmatic | Installer complexity doesn't yet prove need for additional abstraction | Split multi-file install framework from the start |

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/autoplan` | Scope & strategy | 1 | clean | 0 unresolved |
| Codex Review | `/autoplan` | Independent 2nd opinion | 1 | clean | 0 unresolved after plan tightening |
| Eng Review | `/autoplan` | Architecture & tests | 1 | clean | 0 unresolved |
| Design Review | `/autoplan` | UI/UX gaps | 0 | skipped | no UI scope |

**VERDICT:** REVIEWED — plan is ready for execution. Main residual risk is platform-specific path verification in real environments, already captured in the verification phase.
