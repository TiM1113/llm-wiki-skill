---
date: 2026-04-05
topic: multi-agent-platform-support
---

# llm-wiki Multi-Agent Platform Native Support

## Problem Frame

Although `llm-wiki` already has some Codex documentation, the overall codebase is still primarily written following Claude Code conventions. When users hand the same GitHub link to different agents, whether auto-installation works, whether full functionality is available after installation, and whether the agent knows how to handle environment issues -- all of these are unstable.

This directly raises the usage barrier and limits distribution methods. The goal is not to make users understand platform differences, but to let users install via the same repo link regardless of whether they use Claude Code, Codex, or OpenClaw, and get full functionality.

## Requirements

**Unified Entry**
- R1. The project must provide a single official repo entry. Users should be able to hand the same GitHub link to any of Claude Code, Codex, or OpenClaw agents for installation.
- R2. The project must support both “agent auto-install” and “README one-click install command” entry points, but product priority places “agent auto-install” success rate as highest.
- R3. The project's external messaging must upgrade from “this is a skill for one platform” to “this is a knowledge base capability that can be natively installed and used by multiple agent platforms.”

**Complete Capabilities**
- R4. The first version of multi-platform support must not trade feature reduction for compatibility. All currently promised capabilities -- initialization, material digestion, batch digestion, query, synthesis, health check, status viewing, and knowledge graph -- must remain fully available on Claude Code, Codex, and OpenClaw.
- R5. The core usage path on any target platform must be consistent and simple enough: after installation, users can directly have the agent initialize a wiki, add materials, query, and generate syntheses without learning new terminology.
- R6. If certain material types or processes depend on additional environment capabilities, the project must have the agent proactively discover, handle, and report these, rather than leaving users to troubleshoot.

**Platform-Native Experience**
- R7. Each platform must have its own installation and usage entry that it can directly understand, avoiding mixing multiple platforms' operational conventions in one document.
- R8. The project must internally separate “wiki core rules” from “platform adapter layer,” so platform differences only reside in thin adapter layers, not scattered across core capability descriptions and templates.
- R9. Platform difference handling must primarily manifest in installation entry, prompting style, file read/write guidance, dependency invocation methods, and error recovery strategies; wiki directory structure, templates, and content rules must be shared as much as possible.

**Installation & Recovery**
- R10. The install flow must auto-handle dependency checks, dependency installation, and necessary initialization as much as possible, minimizing manual steps.
- R11. When auto-install encounters unavoidable external conditions, user participation should be limited to minimal actions like “grant authorization / login” and “allow browser or environment capabilities.”
- R12. The project must avoid building the success path on the premise that “external dependency skills happen to be compatible across all platforms.” Critical capabilities should be gradually internalized within the project's control.

## Success Criteria

- When users hand the same GitHub link to any of Claude Code, Codex, or OpenClaw agents, the agent can identify the installation method and complete installation.
- After installation, all three platforms can complete full workflows, not just a subset.
- Users don't need to manually read install docs in most scenarios; confirmation is only needed for login or environment authorization.
- README, repo description, install script, and skill entry no longer designate one platform as the sole default.
- When adding a fourth platform later, new work primarily focuses on the adapter layer, not rewriting the entire wiki logic.

## Scope Boundaries

- This phase does not transform the project into a web product or standalone application.
- This phase does not target “zero prerequisites, zero authorization, zero environment differences”; when the platform itself can't achieve this, only minimal user confirmation actions are allowed.
- This phase does not aim to be compatible with all agent platforms simultaneously; target platforms are limited to Claude Code, Codex, and OpenClaw.
- This phase no longer relies on “one big file with all platform conditional branches” as a long-term approach.
- This phase does not redo the entire material extraction capability; deep restructuring of web, X, YouTube etc. sources is deferred until after multi-platform adaptation is complete.

## Key Decisions

- Single repo, single official link: keep user entry unique, reducing distribution and comprehension cost.
- Shared core + thin platform adapter layer: avoid evolving into three long-term-drifting products.
- Preserve full functionality, no compromises: multi-platform support's value comes from “users don't lose capabilities when switching platforms.”
- Prioritize agent auto-install optimization: this better matches actual usage habits than manual README installation.
- Gradually internalize key dependencies: rather than betting external skills are stable on all platforms, gradually bring critical capabilities under project control.

## Dependencies / Assumptions

- Target platforms all have basic capabilities of reading repo docs, executing install commands, manipulating local files, and running necessary scripts.
- Some material extraction flows may still depend on browser, login state, or system tools; these capabilities may not fully abstract across platforms.
- The first version allows retaining some external dependencies, but the overall direction is to bring critical paths under project control.

## Outstanding Questions

### Resolve Before Planning

(none)

### Deferred to Planning

- [Affects R7][Technical] What are the most suitable entry files and placement for each of the three platforms to maximize agent auto-recognition rate?
- [Affects R10][Needs research] Which installation actions should be handled by the unified installer vs declared by platform adapter layers?
- [Affects R12][Needs research] Among existing external dependencies, which must be internalized in the first phase, which can be deferred?
- [Affects R4][Technical] What minimum viable verification checklist should be used for full functionality validation across three platforms, to prove it's not “surface compatibility”?
- [Affects R12][Future phase] Material extraction capability internalization order, replacement strategy, and long-term maintenance approach, to be planned in a separate round after multi-platform adaptation is complete.

## Next Steps

-> `/prompts:ce-plan` for structured implementation planning
