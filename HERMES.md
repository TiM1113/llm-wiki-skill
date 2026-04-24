# HERMES.md

This is the entry file for llm-wiki under Hermes.

Start with these three files:

- [README.md](README.md): Multi-platform overview
- [platforms/hermes/README.md](platforms/hermes/README.md): Hermes-specific entry point
- [SKILL.md](SKILL.md): Core capabilities and workflows

## Hermes Installation

If the current task is to install this skill, run:

```bash
bash install.sh --platform hermes
```

Default install location: `~/.hermes/skills/llm-wiki`.

By default, only the core wiki mainline is prepared. If you also need automatic extraction for web pages / X / WeChat Official Accounts / YouTube / Zhihu, run:

```bash
bash install.sh --platform hermes --with-optional-adapters
```

## Important Notes

- Do not treat this repo as Hermes-exclusive; Claude Code, Codex, and OpenClaw also share the same core content
- Hermes reads the root `HERMES.md` first; this file handles the installation entry point, while the wiki capabilities themselves are defined in [SKILL.md](SKILL.md)
- After installation, continue following the workflows in [SKILL.md](SKILL.md)

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
