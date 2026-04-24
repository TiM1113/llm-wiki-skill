# OpenClaw Entry Point

This is a thin entry file for OpenClaw. See [../../README.md](../../README.md) for shared instructions, and [../../SKILL.md](../../SKILL.md) for core capabilities and workflows.

## How to Install for OpenClaw

Run:

```bash
bash install.sh --platform openclaw
```

If you also need automatic extraction for web pages / X / YouTube, run:

```bash
bash install.sh --platform openclaw --with-optional-adapters
```

Default install location: `~/.openclaw/skills/llm-wiki`

If your OpenClaw uses a different directory, use:

```bash
bash install.sh --platform openclaw --target-dir <your-skill-directory>/llm-wiki
```

When upgrading the same custom directory later, pass the same target directory:

```bash
bash install.sh --upgrade --platform openclaw --target-dir <your-skill-directory>/llm-wiki
```
