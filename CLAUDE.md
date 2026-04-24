# CLAUDE.md

Start with these three files:

- [README.md](README.md): Multi-platform overview
- [platforms/claude/CLAUDE.md](platforms/claude/CLAUDE.md): Claude-specific entry point
- [SKILL.md](SKILL.md): Core capabilities and workflows

## Claude Installation

If the current task is to install this skill, run first:

```bash
bash install.sh --platform claude
```

> `setup.sh` is a compatibility wrapper for `install.sh --platform claude`; existing users can continue using it.

By default, only the core wiki mainline is prepared. If you also need automatic extraction for web pages / X / WeChat Official Accounts / YouTube / Zhihu, run:

```bash
bash install.sh --platform claude --with-optional-adapters
```

After installation, `/llm-wiki-upgrade` is also included. To update the core mainline in the future, you can have Claude run this command directly.

## Branch Management Rules

When making code changes (not purely documentation/comments), follow this workflow:

1. Create a new branch: branch from main, use feat/ or fix/ prefix (e.g., fix/cache-reliability-write-through)
2. Commit incrementally: commit after each logical unit (script implementation -> tests -> documentation update, as separate commits)
3. Push and create PR: push to remote, then use `gh pr create` to create a PR
4. Merge: merge on GitHub after confirming tests pass

No branch needed when:
- Only changing CLAUDE.md, documentation, or comments
- Only exploratory code reading

When a design document or plan is ready and you're about to start coding, create a branch first before implementing.

## Recorded Solutions

`docs/solutions/` stores documents about past problem resolutions (bugs, best practices, workflow improvements), organized by category subdirectories, each with YAML frontmatter (`module`, `tags`, `problem_type`). When working in documented areas (graph, cache, install, lint, etc.), search for existing experience first.

## Pre-Push Testing Rules

Before every `git push`, verification is required. Choose depth based on the scope of changes:

### Tier 1: Quick checks (Claude Code runs directly, under 1 minute)

Always run these 3 checks regardless of what changed:

1. `bash install.sh --dry-run --platform codex` — install script runs without errors
2. If modified scripts have `tests/fixtures/`, run diff against expected output
3. `grep -r '/Users/kangjiaqi\|康佳琦' scripts/ templates/ tests/ SKILL.md` — no leaked private paths

### Tier 2/3: Workflow tests (run manually in codex terminal)

- **Tier 2** (only changed individual workflows in SKILL.md): Claude Code generates test prompts and writes them to a file, tells you the path, and you copy them to codex to run the affected workflows
- **Tier 3** (multi-workflow changes / version bumps): Claude Code generates full regression prompts, and you run the complete flow in codex (init -> ingest -> lint -> digest -> graph)

Reuse the 3 articles in `~/Desktop/llm-wiki-cowork-test/raw-input/` as test material, no need to find new ones each time.

After codex completes, send back the `test-report.md`. Claude Code confirms no blocking issues before running `git push`.

## Pre-Push Documentation Update Rules

After every commit containing feature changes (feat/fix), before `git push`, you **must** proactively check and update the following documents without waiting for user reminders:

1. **CHANGELOG.md**: Add a new version entry at the top (date, categorized by Added/Improved/Fixed)
2. **README.md feature list**: When adding new features or behavior changes, add an entry in the "Features" section
3. **Version number**: If changes involve new features, use a new version number in the CHANGELOG entry (increment from current version)

Skip condition: Pure documentation/formatting/comment changes do not require updates.

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
