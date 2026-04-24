# AGENTS.md

This is the entry file for llm-wiki under Codex.

Start with these three files:

- [README.md](README.md): Multi-platform overview
- [platforms/codex/AGENTS.md](platforms/codex/AGENTS.md): Codex-specific entry point
- [SKILL.md](SKILL.md): Core capabilities and workflows

## Codex Installation

If the current task is to install this skill, run:

```bash
bash install.sh --platform codex
```

Default install location: `~/.codex/skills/llm-wiki`. If the user's machine still uses the legacy `~/.Codex/skills`, the installer will automatically handle compatibility.

By default, only the core wiki mainline is prepared. If you also need automatic extraction for web pages / X / YouTube, run:

```bash
bash install.sh --platform codex --with-optional-adapters
```

## Important Notes

- Do not treat this repo as Codex-exclusive; Claude Code, OpenClaw, and Hermes also share the same core content
- After installation, continue following the workflows in [SKILL.md](SKILL.md)
- If OpenClaw uses a custom skill directory, use `--target-dir <your-skill-directory>/llm-wiki` instead

## Usage Order

After installation, follow the workflows in [SKILL.md](SKILL.md):

1. `init`
2. `ingest`
3. `batch-ingest`
4. `query`
5. `digest`
6. `lint`
7. `status`
8. `graph`
