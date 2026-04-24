---
title: "Claude Code Hook Output Mechanism: PreToolUse vs SessionStart"
date: 2026-04-11
category: integration-issues
module: claude-code-hooks
problem_type: integration_issue
component: tooling
severity: high
symptoms:
  - "PreToolUse hook echo output is completely invisible to LLM"
  - "PreToolUse triggers on every tool call (50-200+ times/session), causing performance waste"
  - "Hook script runs successfully with exit code 0, but agent never responds to injected context"
root_cause: wrong_api
resolution_type: code_fix
tags: [hooks, sessionstart, pretooluse, context-injection, settings-json, claude-code]
---

# Claude Code Hook Output Mechanism: PreToolUse vs SessionStart

## Problem

llm-wiki-skill needed Claude Code to auto-detect whether a wiki exists at session start and inject that information into agent context. Initially implemented with PreToolUse hook + `echo` output, but Phase 0 validation discovered the LLM couldn't see the injected content at all. This is a **silent failure**: the script runs normally, exit code 0, `echo` does print text, but Claude Code doesn't forward it to the LLM.

## Symptoms

- Hook script runs successfully (exit code 0), but agent behavior doesn't change at all
- PreToolUse triggers on every Bash, Read, Write, Grep etc. tool call, typically 50-200+ times per session
- `echo` output only appears in tool stdout; Claude Code does not inject it into LLM context

## What Didn't Work

**PreToolUse + echo plain text output.**

```json
// settings.json — wrong approach
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "command",
        "command": "bash -c 'if [ -f .wiki-schema.md ]; then echo \"[llm-wiki] Wiki detected\"; fi'"
      }
    ]
  }
}
```

Two fatal issues:
1. `echo` output is plain text; Claude Code only processes PreToolUse's `decision` field (for blocking/allowing tool calls), doesn't forward plain text
2. PreToolUse triggers on every tool call; even if output were visible, it would create massive noise

## Solution

Switch to **SessionStart hook**, output JSON format, inject context via `additionalContext` field.

### Hook Script Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

# Detect wiki location
wiki_index=""  # Actual detection logic omitted

if [ -z "$wiki_index" ]; then
  # No wiki detected, exit silently
  echo '{}'
  exit 0
fi

# Wiki detected, output JSON context
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[llm-wiki] Wiki detected: ${wiki_index}, consult wiki content first when answering questions"}}
EOF
```

### Hook Registration (via jq in install.sh)

```bash
# Idempotent registration — skip if command already exists
jq --arg cmd "$hook_command" '
  .hooks = (.hooks // {}) |
  .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":$cmd}]}])
' "$settings_path" > "$tmp_file" && mv "$tmp_file" "$settings_path"
```

### Three Hook Event Types Compared

| Hook Event | Trigger Frequency | LLM-Visible Output | Use Case |
|-----------|----------|-------------|---------|
| `SessionStart` | 1x per session | JSON `additionalContext` | Inject global context |
| `PreToolUse` | Every tool call | Only `decision` field | Tool call filtering/blocking |
| `PostToolUse` | After every tool call | Not visible | Logging, side effects |

## Why This Works

- SessionStart only triggers once per session, no performance overhead
- `additionalContext` field text is injected into the LLM's context window by Claude Code
- Returns `{}` when no wiki detected, completely silent, no token waste
- Idempotent registration ensures repeated `install.sh` runs don't add duplicate hooks

## Prevention

- **Always use SessionStart for one-time session context injection**, not PreToolUse
- **PreToolUse is only for tool call interception**; only the `decision` field is visible to LLM
- **Hook scripts must output JSON**; plain text `echo` is invisible for most hook events
- Phase 0 validation step: after implementing a hook, manually test whether the LLM actually sees the output; don't assume hook output is always forwarded

## Minor Bugs Fixed During Review

The following bugs were found and fixed during the same adversarial review:

| Bug | File | Fix |
|-----|------|-----|
| `grep -rl` treats `.` in filenames as regex wildcard | `scripts/delete-helper.sh` | Added `-F` for fixed-string matching |
| `invalidate` requires file to exist, but file is already gone after cascading delete | `scripts/cache.sh` | Removed `require_file` check |
| mkdir missing `wiki/queries/` directory | `scripts/init-wiki.sh` | Added to brace expansion |
| Python inline script missing `import os` | `scripts/cache.sh` | Added import |

## Related

- `scripts/hook-session-start.sh` — SessionStart hook full implementation
- `install.sh` — `--install-hooks` / `--uninstall-hooks` registration logic
- `tests/regression.sh` — 3 hook-related regression tests
