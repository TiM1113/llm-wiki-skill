# Codex Entry Point

<!-- llm-wiki context: if a wiki exists, consult wiki/index.md first -->

This is a thin entry file for Codex. See [../../README.md](../../README.md) for shared instructions, and [../../SKILL.md](../../SKILL.md) for core capabilities and workflows.

## How to Install for Codex

Run:

```bash
bash install.sh --platform codex
```

If you also need automatic extraction for web pages / X / YouTube, run:

```bash
bash install.sh --platform codex --with-optional-adapters
```

Default install location: `~/.codex/skills/llm-wiki`

If the user's environment still uses the legacy `~/.Codex/skills`, the installer will automatically handle compatibility.
