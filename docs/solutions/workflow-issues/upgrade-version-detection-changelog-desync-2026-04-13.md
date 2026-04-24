---
title: "Upgrade script version detection failure: git tag out of sync with CHANGELOG.md"
date: 2026-04-13
category: docs/solutions/workflow-issues
module: llm-wiki-skill
problem_type: workflow_issue
component: tooling
severity: medium
root_cause: missing_workflow_step
resolution_type: workflow_improvement
applies_when:
  - After releasing a new version and pushing git tag
  - When running /llm-wiki-upgrade to verify version detection
  - Any upgrade flow that uses CHANGELOG.md as the version source
tags: [changelog, version, git-tag, release-workflow, upgrade]
---

# Upgrade script version detection failure: git tag out of sync with CHANGELOG.md

## Context

After merging the Phase A+B feature PR, git tag `v2.1.0` was created and pushed to remote. When running `/llm-wiki-upgrade`, the script reported version still as `v2.0.0`, saying "already on latest version."

The upgrade script reads version number from CHANGELOG.md:

```bash
# llm-wiki-upgrade SKILL.md line 22
OLD_VERSION=$(grep -m1 "^## v" "$SKILL_DIR/CHANGELOG.md" 2>/dev/null \
  | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
```

CHANGELOG.md's first `## v` heading was still `## v2.0.0 (2026-04-11)`. Git tag exists but changelog was not updated; script compares `v2.0.0 == v2.0.0` and determines no upgrade needed.

## Guidance

### Rule: Every git tag must be accompanied by a CHANGELOG.md update, and the tag must be placed on the commit that contains the changelog

Correct release sequence:

```bash
# 1. Update CHANGELOG.md first (add new version entry at top)
# 2. Commit changelog
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for vX.Y.Z"

# 3. Tag the commit that contains the changelog
git tag vX.Y.Z

# 4. Push
git push && git push origin vX.Y.Z
```

### Fix operations for this instance

```bash
# 1. Update CHANGELOG.md with v2.1.0 entry
# 2. Commit
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for v2.1.0"

# 3. Delete old tag and re-create
git tag -d v2.1.0
git tag v2.1.0

# 4. Push commit and force-push tag
git push origin main
git push origin v2.1.0 --force
```

## Why This Matters

1. **Upgrade detection depends on CHANGELOG.md**: `/llm-wiki-upgrade` uses the first `## v` heading in CHANGELOG.md to determine version. If changelog is not updated, even if tag exists, upgrade won't trigger.

2. **Tag and changelog must point to the same commit**: The commit pointed to by the tag must contain the corresponding changelog entry. Otherwise the changelog version users see after cloning won't match the tag.

3. **Consequence of skipping this step**: In this bug, after completing development, merging PR, and creating tag, running upgrade returned "already on latest." Users in other environments also couldn't detect the new version.

## When to Apply

- Every time a semantic version tag (`vX.Y.Z`) is created
- When preparing to release after merging a feature PR or release PR
- Before running `/llm-wiki-upgrade` to check version consistency

## Examples

### Wrong approach (this bug)

```bash
# Merge PR
gh pr merge 6 --merge

# Create tag directly, skipping CHANGELOG
git tag v2.1.0
git push origin v2.1.0

# Result: upgrade skill reads v2.0.0, determines "already on latest"
```

### Correct approach

```bash
# Merge PR
gh pr merge 6 --merge

# First update CHANGELOG.md
# ...add ## v2.1.0 (2026-04-13) entry...

# Commit changelog
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for v2.1.0"

# Tag the commit that contains changelog
git tag v2.1.0

# Push
git push && git push origin v2.1.0
```

### Release checklist

Confirm before releasing a new version:

- [ ] CHANGELOG.md has new version entry at top
- [ ] CHANGELOG.md entry version matches the tag about to be created
- [ ] Tag is on the commit that contains the changelog update
- [ ] Locally run `/llm-wiki-upgrade` to verify correct version detection

## Related

- `~/.claude/skills/llm-wiki-upgrade/SKILL.md` — Upgrade script, where version detection logic lives
- `docs/plans/2026-04-11-wiki-core-upgrades-design.md` — Phase 5 mentions CHANGELOG update but did not define release gate
