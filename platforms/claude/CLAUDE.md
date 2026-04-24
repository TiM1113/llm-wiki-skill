# Claude Code Entry Point

This is a thin entry file for Claude Code. See [../../README.md](../../README.md) for shared instructions, and [../../SKILL.md](../../SKILL.md) for core capabilities and workflows.

## How to Install for Claude

Run the following first:

```bash
bash install.sh --platform claude
```

If you also need automatic extraction for web pages / X / YouTube, run:

```bash
bash install.sh --platform claude --with-optional-adapters
```

If you want Claude Code to automatically detect the current wiki context at session start, run:

```bash
bash install.sh --platform claude --install-hooks
```

Default install location: `~/.claude/skills/llm-wiki`

After installation, `/llm-wiki-upgrade` is also included. To update the core mainline in the future, you can have Claude run this command directly. If you also want to refresh web / X / YouTube auto-extraction capabilities, run the upgrade with `--with-optional-adapters`.

## Legacy Entry

Existing users can still run:

```bash
bash setup.sh
```

It now follows the same installation flow and no longer maintains separate logic. If you need URL-based source auto-extraction, explicitly append `--with-optional-adapters`.
