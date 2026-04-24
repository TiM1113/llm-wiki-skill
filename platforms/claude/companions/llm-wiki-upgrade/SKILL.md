---
name: llm-wiki-upgrade
version: 1.1.0
description: |
  Upgrade llm-wiki to the latest version. Pulls the latest code from GitHub and upgrades the core mainline via the official install.sh.
  Optional adapters for web, X, YouTube auto-extraction are not refreshed by default; enable explicitly when needed.
  Trigger phrases: upgrade llm-wiki, update llm-wiki, llm-wiki upgrade, llm-wiki update
allowed-tools:
  - Bash
  - Read
---

# /llm-wiki-upgrade

Upgrade the llm-wiki skill to the latest version.

## Upgrade Flow

### Step 1: Read current version

```bash
SKILL_DIR="$HOME/.claude/skills/llm-wiki"
OLD_VERSION=$(grep -m1 "^## v" "$SKILL_DIR/CHANGELOG.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
echo "CURRENT_VERSION=$OLD_VERSION"
```

If `SKILL_DIR` does not exist, inform the user that llm-wiki is not installed and stop.

### Step 2: Clone the latest version to a temp directory

```bash
TMP_DIR=$(mktemp -d)
git clone --depth 1 https://github.com/sdyckjq-lab/llm-wiki-skill.git "$TMP_DIR/llm-wiki-skill" 2>&1
echo "CLONE_EXIT=$?"
```

If clone fails (`CLONE_EXIT` is non-zero), inform the user of the network issue and stop.

### Step 3: Read the new version number

```bash
NEW_VERSION=$(grep -m1 "^## v" "$TMP_DIR/llm-wiki-skill/CHANGELOG.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
echo "NEW_VERSION=$NEW_VERSION"
```

If `OLD_VERSION == NEW_VERSION`, inform the user they are already on the latest version, clean up the temp directory and finish:

```bash
rm -rf "$TMP_DIR"
```

### Step 4: Run the official upgrade

Execute `install.sh --upgrade` from the temp directory (which has `.git`).

Note: The default upgrade only updates the core wiki mainline and does not proactively refresh optional adapters for web, X, YouTube auto-extraction.

```bash
bash "$TMP_DIR/llm-wiki-skill/install.sh" --upgrade --platform claude 2>&1
echo "UPGRADE_EXIT=$?"
```

If `UPGRADE_EXIT` is non-zero, inform the user the upgrade failed, show key information, clean up the temp directory and stop.

### Step 5: Clean up the temp directory

```bash
rm -rf "$TMP_DIR"
```

### Step 6: Show what changed

Read `$HOME/.claude/skills/llm-wiki/CHANGELOG.md`, extract changes between `OLD_VERSION` and `NEW_VERSION`, and summarize the 3-5 changes users care about most.

If the new version includes changes like "default install only covers core mainline / optional extractors require explicit opt-in", clearly tell the user:

- Default upgrades no longer proactively refresh web, X, YouTube auto-extraction capabilities
- If the user needs these auto-extraction capabilities, they can run:

```bash
bash "$HOME/.claude/skills/llm-wiki/install.sh" --upgrade --platform claude --with-optional-adapters
```

Output format:

```text
llm-wiki $NEW_VERSION upgrade complete (from $OLD_VERSION)

Changes:
- [change1]
- [change2]
- ...

If you need to enable or refresh web / X / YouTube auto-extraction, let me know to run the upgrade with --with-optional-adapters.
```
