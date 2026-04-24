# Hermes Entry Point

This is a thin entry file for Hermes. See [../../README.md](../../README.md) for shared instructions, and [../../SKILL.md](../../SKILL.md) for core capabilities and workflows.

## How to Install for Hermes

Run:

```bash
bash install.sh --platform hermes
```

If you also need automatic extraction for web pages / X / YouTube, run:

```bash
bash install.sh --platform hermes --with-optional-adapters
```

Default install location: `~/.hermes/skills/llm-wiki`

If your Hermes has a different skill directory configured, use:

```bash
bash install.sh --platform hermes --target-dir <your-skill-directory>/llm-wiki
```

When upgrading the same custom directory later, pass the same target directory:

```bash
bash install.sh --upgrade --platform hermes --target-dir <your-skill-directory>/llm-wiki
```
