#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

assert_file_contains() {
    local file="$1"
    local text="$2"

    if ! grep -F -- "$text" "$file" > /dev/null; then
        fail "Expected $file to contain: $text"
    fi
}

assert_file_not_contains() {
    local file="$1"
    local text="$2"

    if grep -F -- "$text" "$file" > /dev/null; then
        fail "Expected $file to not contain: $text"
    fi
}

assert_text_contains() {
    local text="$1"
    local expected="$2"

    if ! printf '%s' "$text" | grep -F -- "$expected" > /dev/null; then
        fail "Expected output to contain: $expected"
    fi
}

assert_text_not_contains() {
    local text="$1"
    local unexpected="$2"

    if printf '%s' "$text" | grep -F -- "$unexpected" > /dev/null; then
        fail "Expected output to not contain: $unexpected"
    fi
}

assert_path_exists() {
    local path="$1"

    [ -e "$path" ] || fail "Expected path to exist: $path"
}

each_registry_label() {
    local category="$1"

    bash "$REPO_ROOT/scripts/source-registry.sh" list-by-category "$category" \
        | awk -F '\t' 'NF { print $2 }'
}

assert_registry_labels_present_in_text() {
    local text="$1"
    local category="$2"
    local label

    while IFS= read -r label; do
        [ -n "$label" ] || continue
        assert_text_contains "$text" "$label"
    done <<EOF
$(each_registry_label "$category")
EOF
}

assert_registry_labels_present_in_file() {
    local file="$1"
    local category="$2"
    local label

    while IFS= read -r label; do
        [ -n "$label" ] || continue
        assert_file_contains "$file" "$label"
    done <<EOF
$(each_registry_label "$category")
EOF
}

make_stub() {
    local path="$1"
    local body="$2"

    printf '%s\n' "$body" > "$path"
    chmod +x "$path"
}

make_repo_copy_without_git() {
    local dest="$1"

    cp -R "$REPO_ROOT" "$dest"
    rm -rf "$dest/.git"
}

make_legacy_wiki() {
    local wiki_root="$1"

    mkdir -p "$wiki_root"/raw/{articles,tweets,wechat,pdfs,notes,assets}
    mkdir -p "$wiki_root"/wiki/{entities,topics,sources,comparisons,synthesis}

    cat > "$wiki_root/.wiki-schema.md" <<'EOF'
# Wiki Schema (Knowledge Base Configuration Spec)

- Topic: Legacy Knowledge Base
- Created: 2026-04-01
EOF

    printf '# Index\n' > "$wiki_root/index.md"
    printf '# Log\n' > "$wiki_root/log.md"
    printf '# Overview\n' > "$wiki_root/wiki/overview.md"
}

test_setup_runs_on_bash_3_2() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" "#!/bin/sh
printf '%s\n' bun >> \"$tmp_dir/tool.log\"
mkdir -p node_modules
exit 0"

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    make_stub "$tmp_dir/bin/uv" "#!/bin/sh
printf '%s\n' uv >> \"$tmp_dir/tool.log\"
exit 0"

    output="$(
        HOME="$tmp_dir/home" \
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/setup.sh" 2>&1
    )" || fail "setup.sh should run successfully under bash 3.2"

    assert_path_exists "$tmp_dir/home/.claude/skills/llm-wiki/SKILL.md"
    assert_path_exists "$tmp_dir/home/.claude/skills/llm-wiki-upgrade/SKILL.md"
    assert_path_exists "$tmp_dir/home/.claude/skills/llm-wiki/deps/baoyu-url-to-markdown"
    [ ! -d "$tmp_dir/home/.claude/skills/baoyu-url-to-markdown" ] || fail "Did not expect optional adapters to be enabled by default"
    [ ! -f "$tmp_dir/tool.log" ] || fail "Did not expect bun or uv to run for core-only setup"

    assert_text_contains "$output" "Only the core wiki pipeline has been set up"
    assert_text_contains "$output" "--with-optional-adapters"
    assert_text_contains "$output" "/llm-wiki-upgrade"
}

test_install_with_optional_adapters_bootstraps_dependencies() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    output="$(
        HOME="$tmp_dir/home" \
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/install.sh" --platform claude --with-optional-adapters 2>&1
    )" || fail "install.sh should support explicit optional adapter bootstrap"

    [ -d "$tmp_dir/home/.claude/skills/baoyu-url-to-markdown" ] || fail "Expected baoyu-url-to-markdown to be installed when explicitly enabled"
    [ -d "$tmp_dir/home/.claude/skills/youtube-transcript" ] || fail "Expected youtube-transcript to be installed when explicitly enabled"

    assert_text_contains "$output" "Chrome debug port 9222 not detected"
    assert_text_contains "$output" "baoyu-url-to-markdown can still launch a temporary browser automatically"
    assert_text_contains "$output" "open -na \"Google Chrome\" --args --remote-debugging-port=9222"
}

test_install_dry_run_for_claude() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills"

    output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/install.sh" --platform claude --dry-run 2>&1
    )" || fail "install.sh dry-run for Claude should succeed"

    assert_text_contains "$output" "Platform: claude"
    assert_text_contains "$output" "$tmp_dir/home/.claude/skills/llm-wiki"
    assert_text_contains "$output" "--with-optional-adapters"
    assert_text_not_contains "$output" "uv tool install"
    assert_text_not_contains "$output" "bun install"
}

test_install_auto_refuses_ambiguous_platforms() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/home/.codex/skills" "$tmp_dir/home/.hermes/skills"

    if output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/install.sh" --platform auto 2>&1
    )"; then
        fail "install.sh auto should fail when multiple platform homes are present"
    fi

    assert_text_contains "$output" "Multiple available platforms detected"
    assert_text_contains "$output" "--platform"
}

test_install_openclaw_copies_bundle() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.openclaw/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    HOME="$tmp_dir/home" \
    PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "$REPO_ROOT/install.sh" --platform openclaw > /dev/null 2>&1 || fail "install.sh should install for OpenClaw"

    assert_path_exists "$tmp_dir/home/.openclaw/skills/llm-wiki/SKILL.md"
    assert_path_exists "$tmp_dir/home/.openclaw/skills/llm-wiki/install.sh"
    assert_path_exists "$tmp_dir/home/.openclaw/skills/llm-wiki/scripts/source-registry.sh"
    assert_path_exists "$tmp_dir/home/.openclaw/skills/llm-wiki/deps/baoyu-url-to-markdown"
    [ ! -d "$tmp_dir/home/.openclaw/skills/llm-wiki-upgrade" ] || fail "Did not expect Claude-only companion skill to be installed for OpenClaw"
    [ ! -d "$tmp_dir/home/.openclaw/skills/baoyu-url-to-markdown" ] || fail "Did not expect optional adapters to be enabled by default"
}

test_install_hermes_copies_bundle() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.hermes/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    HOME="$tmp_dir/home" \
    PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "$REPO_ROOT/install.sh" --platform hermes > /dev/null 2>&1 || fail "install.sh should install for Hermes"

    assert_path_exists "$tmp_dir/home/.hermes/skills/llm-wiki/SKILL.md"
    assert_path_exists "$tmp_dir/home/.hermes/skills/llm-wiki/HERMES.md"
    assert_path_exists "$tmp_dir/home/.hermes/skills/llm-wiki/platforms/hermes/README.md"
    assert_path_exists "$tmp_dir/home/.hermes/skills/llm-wiki/scripts/source-registry.sh"
    [ ! -d "$tmp_dir/home/.hermes/skills/baoyu-url-to-markdown" ] || fail "Did not expect optional adapters to be enabled by default"
}

test_upgrade_refreshes_claude_companion_skill() {
    local tmp_dir output repo_copy
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    repo_copy="$tmp_dir/repo"
    make_repo_copy_without_git "$repo_copy"

    mkdir -p "$tmp_dir/home/.claude/skills/llm-wiki" "$tmp_dir/home/.claude/skills/llm-wiki-upgrade"
    printf '# Changelog\n\n## v2.3.0 (2026-04-15)\n' > "$tmp_dir/home/.claude/skills/llm-wiki/CHANGELOG.md"
    printf 'old\n' > "$tmp_dir/home/.claude/skills/llm-wiki-upgrade/SKILL.md"

    output="$(
        HOME="$tmp_dir/home" \
        bash "$repo_copy/install.sh" --upgrade --platform claude 2>&1
    )" || fail "install.sh --upgrade should refresh the Claude companion skill"

    assert_text_contains "$output" "/llm-wiki-upgrade"
    assert_path_exists "$tmp_dir/home/.claude/skills/llm-wiki-upgrade/SKILL.md"
    assert_file_contains "$tmp_dir/home/.claude/skills/llm-wiki-upgrade/SKILL.md" "--with-optional-adapters"
    assert_file_contains "$tmp_dir/home/.claude/skills/llm-wiki-upgrade/SKILL.md" 'bash "$TMP_DIR/llm-wiki-skill/install.sh" --upgrade --platform claude'
}

test_init_fills_language_placeholder() {
    local tmp_dir wiki_root
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/Test Wiki"
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$wiki_root" "Test Topic" "English" > /dev/null

    assert_file_contains "$wiki_root/.wiki-schema.md" "- Language: English"
    assert_file_not_contains "$wiki_root/.wiki-schema.md" "{{LANGUAGE}}"
}

test_phase1_templates_exist() {
    assert_path_exists "$REPO_ROOT/templates/purpose-template.md"
    assert_path_exists "$REPO_ROOT/templates/purpose-en-template.md"
    assert_path_exists "$REPO_ROOT/templates/query-template.md"

    assert_file_contains "$REPO_ROOT/templates/purpose-template.md" "# Research Purpose and Direction"
    assert_file_contains "$REPO_ROOT/templates/purpose-template.md" "## Core Goal"
    assert_file_contains "$REPO_ROOT/templates/purpose-en-template.md" "# Research Purpose and Direction"
    assert_file_contains "$REPO_ROOT/templates/purpose-en-template.md" "## Core Goal"
    assert_file_contains "$REPO_ROOT/templates/query-template.md" "type: query"
    assert_file_contains "$REPO_ROOT/templates/query-template.md" "derived: true"
}

test_init_creates_purpose_and_cache_files() {
    local tmp_dir wiki_root
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/English Wiki"
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$wiki_root" "Test Topic" "English" > /dev/null

    assert_path_exists "$wiki_root/purpose.md"
    assert_path_exists "$wiki_root/.wiki-cache.json"
    assert_file_contains "$wiki_root/purpose.md" "# Research Purpose and Direction"
    assert_file_contains "$wiki_root/.wiki-cache.json" '"version": 1'
    assert_file_contains "$wiki_root/.wiki-cache.json" '"entries": {}'
}

test_cache_script_handles_miss_hit_and_invalidate() {
    local tmp_dir wiki_root file_path output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/cache-wiki"
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$wiki_root" "Cache Test" "Chinese" > /dev/null

    file_path="$wiki_root/raw/articles/example.md"
    printf 'Cache test content\n' > "$file_path"

    output="$(
        bash "$REPO_ROOT/scripts/cache.sh" check "$file_path" 2>&1
    )" || fail "cache.sh check should work for uncached files"
    [ "$output" = "MISS:no_entry" ] || fail "Expected initial cache check to be MISS:no_entry, got: $output"

    # source page must have source_path frontmatter for self-healing to validate
    cat > "$wiki_root/wiki/sources/example.md" <<'SRCEOF'
---
source_path: raw/articles/example.md
---
# Source Page
SRCEOF
    bash "$REPO_ROOT/scripts/cache.sh" update "$file_path" "wiki/sources/example.md" > /dev/null 2>&1 \
        || fail "cache.sh update should succeed"

    output="$(
        bash "$REPO_ROOT/scripts/cache.sh" check "$file_path" 2>&1
    )" || fail "cache.sh check should work for cached files"
    [ "$output" = "HIT" ] || fail "Expected updated cache check to be HIT, got: $output"

    bash "$REPO_ROOT/scripts/cache.sh" invalidate "$file_path" > /dev/null 2>&1 \
        || fail "cache.sh invalidate should succeed"

    output="$(
        bash "$REPO_ROOT/scripts/cache.sh" check "$file_path" 2>&1
    )" || fail "cache.sh check should work after invalidation"
    # Self-heal: after invalidate, source page still exists, stem + source_path match → HIT(repaired)
    [ "$output" = "HIT(repaired)" ] || fail "Expected invalidated cache check to be HIT(repaired), got: $output"
}

test_skill_md_phase2_init_mentions_purpose_and_cache() {
    local section
    section="$(sed -n '/## Workflow 1: init/,/## Workflow 2: ingest/p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$section" "purpose.md"
    assert_text_contains "$section" ".wiki-cache.json"
    assert_text_contains "$section" "fill in core goals and key questions"
}

test_skill_md_phase2_ingest_mentions_two_step_cache_and_confidence() {
    local section
    section="$(sed -n '/## Workflow 2: ingest/,/## Workflow 3: batch-ingest/p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$section" '`purpose.md` > `.wiki-schema.md` > `index.md`'
    assert_text_contains "$section" 'bash ${SKILL_DIR}/scripts/cache.sh check'
    assert_text_contains "$section" "Step 1: Structured analysis"
    assert_text_contains "$section" "Step 2: Page generation"
    assert_text_contains "$section" '"confidence": "EXTRACTED"'
    assert_text_contains "$section" "<!-- confidence: UNVERIFIED -->"
    assert_text_contains "$section" "add a comment at the top of the page explaining that this processing was downgraded"
}

test_skill_md_phase2_batch_ingest_mentions_cache_skip_summary() {
    local section
    section="$(sed -n '/## Workflow 3: batch-ingest/,/## Workflow 4: query/p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$section" 'Run `cache check` for each file first'
    assert_text_contains "$section" "Skipped N (no changes), processed M (new/updated)"
}

test_skill_md_phase2_status_mentions_purpose_presence() {
    local section
    section="$(sed -n '/## Workflow 6: status/,/## Workflow 7: digest/p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$section" "Whether \`purpose.md\` exists"
}

test_skill_md_phase2_has_delete_workflow_and_route() {
    local route_section delete_section
    route_section="$(sed -n '/## Workflow Routing/,/## Common Pre-checks/p' "$REPO_ROOT/SKILL.md")"
    delete_section="$(sed -n '/## Workflow 9: delete/,$p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$route_section" '"delete source", "remove"'
    assert_text_contains "$route_section" "→ **delete**"
    assert_text_contains "$delete_section" "more than 5 pages are affected"
    assert_text_contains "$delete_section" 'bash ${SKILL_DIR}/scripts/delete-helper.sh scan-refs'
    assert_text_contains "$delete_section" "cache.sh invalidate"
}

test_delete_helper_scans_reference_files() {
    local tmp_dir wiki_root output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/delete-wiki"
    mkdir -p "$wiki_root"/raw/articles
    mkdir -p "$wiki_root"/wiki/{sources,entities,topics}

    printf 'Original text\n' > "$wiki_root/raw/articles/2024-01-15-ai-article.md"
    cat > "$wiki_root/wiki/sources/2024-01-15-ai-article.md" <<'EOF'
---
sources: ["raw/articles/2024-01-15-ai-article.md"]
---

[source: AI Article](../raw/articles/2024-01-15-ai-article.md)
EOF
    printf 'See raw/articles/2024-01-15-ai-article.md\n' > "$wiki_root/wiki/entities/AI-Agent.md"
    printf 'Reference [source: AI Article](../raw/articles/2024-01-15-ai-article.md)\n' > "$wiki_root/wiki/topics/大语言模型.md"

    output="$(
        bash "$REPO_ROOT/scripts/delete-helper.sh" scan-refs "$wiki_root" "2024-01-15-ai-article.md" 2>&1
    )" || fail "delete-helper scan-refs should succeed"

    assert_text_contains "$output" "wiki/entities/AI-Agent.md"
    assert_text_contains "$output" "wiki/sources/2024-01-15-ai-article.md"
    assert_text_contains "$output" "wiki/topics/大语言模型.md"
}

test_skill_md_phase3_query_mentions_persistence_and_duplicate_handling() {
    local section
    section="$(sed -n '/## Workflow 4: query/,/## Workflow 5: lint/p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$section" "wiki/queries/{date}-{short-hash}.md"
    assert_text_contains "$section" "derived: true"
    assert_text_contains "$section" "synthesizes 3 or more sources"
    assert_text_contains "$section" "Match by frontmatter tags and title"
    assert_text_contains "$section" "superseded-by"
    assert_text_contains "$section" "not as primary knowledge sources"
}

test_hook_session_start_outputs_context_when_wiki_exists() {
    local tmp_dir output wiki_root
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/my-wiki"
    mkdir -p "$tmp_dir/home" "$wiki_root"
    printf '# schema\n' > "$wiki_root/.wiki-schema.md"
    printf '# index\n' > "$wiki_root/index.md"
    printf '%s\n' "$wiki_root" > "$tmp_dir/home/.llm-wiki-path"

    output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/scripts/hook-session-start.sh" 2>&1
    )" || fail "hook-session-start.sh should succeed when wiki exists"

    assert_text_contains "$output" "hookSpecificOutput"
    assert_text_contains "$output" "SessionStart"
    assert_text_contains "$output" "[llm-wiki] Wiki detected"
}

test_hook_session_start_returns_empty_json_without_wiki() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home"

    output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/scripts/hook-session-start.sh" 2>&1
    )" || fail "hook-session-start.sh should succeed without wiki"

    [ "$output" = "{}" ] || fail "Expected hook-session-start.sh to return {} without wiki"
}

test_install_registers_and_uninstalls_session_start_hook() {
    local tmp_dir settings_path output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/bin"
    settings_path="$tmp_dir/home/.claude/settings.json"
    cat > "$settings_path" <<'EOF'
{
  "enabledPlugins": {
    "demo": true
  }
}
EOF

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    make_stub "$tmp_dir/bin/uv" '#!/bin/sh
exit 0'

    HOME="$tmp_dir/home" \
    PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "$REPO_ROOT/install.sh" --platform claude --install-hooks > /dev/null 2>&1 \
      || fail "install.sh should register session hook for Claude"

    assert_path_exists "$tmp_dir/home/.claude/settings.json.bak.llm-wiki"
    assert_file_contains "$settings_path" '"SessionStart"'
    assert_file_contains "$settings_path" "$tmp_dir/home/.claude/skills/llm-wiki/scripts/hook-session-start.sh"

    HOME="$tmp_dir/home" \
    PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "$REPO_ROOT/install.sh" --uninstall-hooks > /dev/null 2>&1 \
      || fail "install.sh should remove session hook"

    assert_file_not_contains "$settings_path" "hook-session-start.sh"
    assert_file_contains "$settings_path" '"enabledPlugins"'
}

test_platform_entries_mention_hook_and_wiki_context() {
    assert_file_contains "$REPO_ROOT/platforms/claude/CLAUDE.md" "/llm-wiki-upgrade"
    assert_file_contains "$REPO_ROOT/platforms/claude/CLAUDE.md" "--install-hooks"
    assert_file_contains "$REPO_ROOT/platforms/codex/AGENTS.md" "consult wiki/index.md first"
    assert_file_contains "$REPO_ROOT/platforms/openclaw/README.md" "--upgrade --platform openclaw --target-dir <your-skill-directory>/llm-wiki"
    assert_file_contains "$REPO_ROOT/platforms/hermes/README.md" "--platform hermes"
    assert_file_contains "$REPO_ROOT/platforms/hermes/README.md" "~/.hermes/skills/llm-wiki"
}

test_root_entries_explain_core_only_optional_and_target_dir() {
    assert_file_contains "$REPO_ROOT/AGENTS.md" "--with-optional-adapters"
    assert_file_contains "$REPO_ROOT/AGENTS.md" "only the core wiki mainline is prepared"
    assert_file_contains "$REPO_ROOT/AGENTS.md" "--target-dir <your-skill-directory>/llm-wiki"
    assert_file_contains "$REPO_ROOT/CLAUDE.md" "/llm-wiki-upgrade"
    assert_file_contains "$REPO_ROOT/CLAUDE.md" "--with-optional-adapters"
    assert_file_contains "$REPO_ROOT/CLAUDE.md" "only the core wiki mainline is prepared"
    assert_file_contains "$REPO_ROOT/HERMES.md" "--platform hermes"
    assert_file_contains "$REPO_ROOT/HERMES.md" "~/.hermes/skills/llm-wiki"
}

test_skill_md_phase5_lint_mentions_confidence_audit() {
    local section
    section="$(sed -n '/## Workflow 5: lint/,/## Workflow 6: status/p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$section" "Confidence report"
    assert_text_contains "$section" "AMBIGUOUS"
    assert_text_contains "$section" "Spot-check entries marked as EXTRACTED"
}

test_changelog_mentions_wiki_core_upgrades() {
    assert_file_contains "$REPO_ROOT/CHANGELOG.md" "purpose.md"
    assert_file_contains "$REPO_ROOT/CHANGELOG.md" "SessionStart hook"
    assert_file_contains "$REPO_ROOT/CHANGELOG.md" "delete workflow"
    assert_file_contains "$REPO_ROOT/CHANGELOG.md" "/llm-wiki-upgrade"
    assert_file_contains "$REPO_ROOT/CHANGELOG.md" "--with-optional-adapters"
    assert_file_contains "$REPO_ROOT/CHANGELOG.md" "core mainline"
}

test_readme_sections() {
    assert_file_contains "$REPO_ROOT/README.md" "## 30-Second Start"
    assert_file_contains "$REPO_ROOT/README.md" "<summary><strong>FAQ</strong></summary>"
    assert_file_contains "$REPO_ROOT/README.md" "bash install.sh --platform claude"
    assert_file_contains "$REPO_ROOT/README.md" "bash install.sh --platform codex"
    assert_file_contains "$REPO_ROOT/README.md" "bash install.sh --platform openclaw"
    assert_file_contains "$REPO_ROOT/README.md" "bash install.sh --platform hermes"
    assert_file_contains "$REPO_ROOT/README.md" "--with-optional-adapters"
    assert_file_contains "$REPO_ROOT/README.md" "/llm-wiki-upgrade"
    assert_file_contains "$REPO_ROOT/README.md" "--target-dir <your-skill-dir>/llm-wiki"
    assert_file_contains "$REPO_ROOT/README.md" "--upgrade --platform openclaw --target-dir <your-skill-dir>/llm-wiki"
    assert_file_contains "$REPO_ROOT/README.md" "--upgrade --platform hermes --target-dir <your-skill-dir>/llm-wiki"
    assert_file_contains "$REPO_ROOT/README.md" "HERMES.md"
    assert_file_not_contains "$REPO_ROOT/README.md" "bash setup.sh"
    assert_file_not_contains "$REPO_ROOT/README.md" "x-article-extractor"
    assert_file_not_contains "$REPO_ROOT/README.md" "baoyu-danger-x-to-markdown"
}

test_claude_upgrade_companion_source_exists() {
    assert_path_exists "$REPO_ROOT/platforms/claude/companions/llm-wiki-upgrade/SKILL.md"
    assert_file_contains "$REPO_ROOT/platforms/claude/companions/llm-wiki-upgrade/SKILL.md" "--with-optional-adapters"
    assert_file_contains "$REPO_ROOT/platforms/claude/companions/llm-wiki-upgrade/SKILL.md" 'bash "$TMP_DIR/llm-wiki-skill/install.sh" --upgrade --platform claude'
}

test_install_succeeds_without_uv() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    output="$(
        HOME="$tmp_dir/home" \
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/install.sh" --platform claude --with-optional-adapters 2>&1
    )" || fail "install.sh should succeed without uv available"

    assert_text_contains "$output" "llm-wiki setup complete"
    assert_path_exists "$tmp_dir/home/.claude/skills/llm-wiki/SKILL.md"
}

test_upgrade_auto_refuses_ambiguous_installed_platforms() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills/llm-wiki" "$tmp_dir/home/.codex/skills/llm-wiki" "$tmp_dir/home/.hermes/skills/llm-wiki"

    if output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/install.sh" --upgrade --platform auto 2>&1
    )"; then
        fail "install.sh --upgrade --platform auto should fail when multiple installs exist"
    fi

    assert_text_contains "$output" "Multiple installed platforms detected"
    assert_text_contains "$output" "--platform"
}

test_upgrade_uses_explicit_target_dir() {
    local tmp_dir output custom_target repo_copy
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    repo_copy="$tmp_dir/repo"
    make_repo_copy_without_git "$repo_copy"

    custom_target="$tmp_dir/custom/llm-wiki"
    mkdir -p "$tmp_dir/home/.openclaw/skills" "$custom_target"
    printf 'stale\n' > "$custom_target/README.md"

    output="$(
        HOME="$tmp_dir/home" \
        bash "$repo_copy/install.sh" --upgrade --platform openclaw --target-dir "$custom_target" 2>&1
    )" || fail "install.sh --upgrade should support explicit target directories"

    assert_text_contains "$output" "Target directory: $custom_target"
    assert_text_contains "$output" "llm-wiki upgrade complete"
    assert_path_exists "$custom_target/install.sh"
    cmp -s "$custom_target/README.md" "$repo_copy/README.md" \
        || fail "Expected explicit target dir upgrade to refresh README.md"
    [ ! -d "$tmp_dir/home/.openclaw/skills/llm-wiki" ] || fail "Did not expect upgrade to write into the default OpenClaw skill path"
}

test_upgrade_fails_when_explicit_target_dir_is_missing() {
    local tmp_dir output custom_target repo_copy
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    repo_copy="$tmp_dir/repo"
    make_repo_copy_without_git "$repo_copy"

    custom_target="$tmp_dir/custom/llm-wiki"
    mkdir -p "$tmp_dir/home/.openclaw/skills"

    if output="$(
        HOME="$tmp_dir/home" \
        bash "$repo_copy/install.sh" --upgrade --platform openclaw --target-dir "$custom_target" 2>&1
    )"; then
        fail "install.sh --upgrade should fail when the explicit target directory is missing"
    fi

    assert_text_contains "$output" "llm-wiki not yet installed"
    assert_text_contains "$output" "llm-wiki upgrade failed"
}

test_skill_md_routes_via_registry() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "scripts/source-registry.sh match-url"
    assert_file_contains "$REPO_ROOT/SKILL.md" "scripts/source-registry.sh match-file"
    assert_file_contains "$REPO_ROOT/SKILL.md" '`adapter_name`'
    assert_file_not_contains "$REPO_ROOT/SKILL.md" "x-article-extractor"
    assert_file_not_contains "$REPO_ROOT/SKILL.md" "wechat_article"
    assert_file_not_contains "$REPO_ROOT/SKILL.md" "zhihu_article"
}

test_templates_have_no_empty_links() {
    assert_file_not_contains "$REPO_ROOT/templates/entity-template.md" "- [[]]"
    assert_file_not_contains "$REPO_ROOT/templates/source-template.md" "- [[]]"
    assert_file_not_contains "$REPO_ROOT/templates/topic-template.md" "- [[]]"
}

test_batch_ingest_has_step_two() {
    local section
    section="$(sed -n '/## Workflow 3: batch-ingest/,/## Workflow 4: query/p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$section" "1. **Confirm knowledge base path**"
    assert_text_contains "$section" "2. **List all processable files**"
    assert_text_contains "$section" "3. **Display file list**"
}

test_english_templates_exist_and_have_placeholders() {
    assert_path_exists "$REPO_ROOT/templates/index-en-template.md"
    assert_path_exists "$REPO_ROOT/templates/overview-en-template.md"
    assert_path_exists "$REPO_ROOT/templates/log-en-template.md"

    assert_file_contains "$REPO_ROOT/templates/index-en-template.md" "{{DATE}}"
    assert_file_contains "$REPO_ROOT/templates/index-en-template.md" "{{TOPIC}}"
    assert_file_contains "$REPO_ROOT/templates/overview-en-template.md" "{{DATE}}"
    assert_file_contains "$REPO_ROOT/templates/overview-en-template.md" "{{TOPIC}}"
    assert_file_contains "$REPO_ROOT/templates/log-en-template.md" "{{DATE}}"
    assert_file_contains "$REPO_ROOT/templates/log-en-template.md" "{{TOPIC}}"
}

test_english_templates_have_no_empty_links() {
    assert_file_not_contains "$REPO_ROOT/templates/index-en-template.md" "[[]]"
    assert_file_not_contains "$REPO_ROOT/templates/overview-en-template.md" "[[]]"
    assert_file_not_contains "$REPO_ROOT/templates/log-en-template.md" "[[]]"
}

test_skill_md_has_shared_preflight_and_language_rules() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "## Common Pre-checks"
    assert_file_contains "$REPO_ROOT/SKILL.md" "## Output Language Rules"
    assert_file_contains "$REPO_ROOT/SKILL.md" "- Source"
    assert_file_contains "$REPO_ROOT/SKILL.md" "- Knowledge Graph"
}

test_skill_md_uses_external_english_templates_and_no_english_output_blocks() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "templates/index-en-template.md"
    assert_file_contains "$REPO_ROOT/SKILL.md" "templates/overview-en-template.md"
    assert_file_contains "$REPO_ROOT/SKILL.md" "templates/log-en-template.md"
    assert_file_not_contains "$REPO_ROOT/SKILL.md" "**English（en）**："
}

test_setup_wrapper_is_marked_deprecated() {
    assert_file_contains "$REPO_ROOT/setup.sh" "Deprecated: please use bash install.sh --platform claude"
}

test_source_registry_contract_is_frozen() {
    local output

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" fields 2>&1
    )" || fail "source-registry fields should be readable"

    assert_text_contains "$output" "source_id"
    assert_text_contains "$output" "source_label"
    assert_text_contains "$output" "source_category"
    assert_text_contains "$output" "input_mode"
    assert_text_contains "$output" "raw_dir"
    assert_text_contains "$output" "original_ref"
    assert_text_contains "$output" "ingest_text"
    assert_text_contains "$output" "adapter_name"
    assert_text_contains "$output" "fallback_hint"
}

test_source_registry_groups_core_optional_and_manual_sources() {
    local output

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" list 2>&1
    )" || fail "source-registry list should be readable"

    assert_text_contains "$output" "core_builtin"
    assert_text_contains "$output" "optional_adapter"
    assert_text_contains "$output" "manual_only"
    assert_text_contains "$output" "local_pdf"
    assert_text_contains "$output" "plain_text"
    assert_text_contains "$output" "web_article"
    assert_text_contains "$output" "xiaohongshu_post"
}

test_source_registry_exposes_install_dependency_groups() {
    local bundled_output

    bundled_output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" unique-dependencies bundled 2>&1
    )" || fail "source-registry should list bundled dependencies"

    assert_text_contains "$bundled_output" "baoyu-url-to-markdown"
    assert_text_contains "$bundled_output" "youtube-transcript"
}

test_source_registry_validation_passes() {
    bash "$REPO_ROOT/scripts/source-registry.sh" validate > /dev/null 2>&1 \
        || fail "source-registry validate should succeed"
}

test_source_registry_matches_urls_and_files_from_shared_table() {
    local output

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" match-url "https://x.com/openai/status/1" 2>&1
    )" || fail "source-registry should match X/Twitter URLs"
    assert_text_contains "$output" "x_twitter"

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" match-url "https://example.com/post" 2>&1
    )" || fail "source-registry should match generic web URLs"
    assert_text_contains "$output" "web_article"

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" match-file "/tmp/example.md" 2>&1
    )" || fail "source-registry should match local document files"
    assert_text_contains "$output" "local_document"

    output="$(
        bash "$REPO_ROOT/scripts/source-registry.sh" match-file "/tmp/paper.pdf" 2>&1
    )" || fail "source-registry should match PDF files"
    assert_text_contains "$output" "local_pdf"
}

test_legacy_wiki_defaults_missing_fields_without_forcing_migration() {
    local tmp_dir wiki_root output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/legacy-wiki"
    make_legacy_wiki "$wiki_root"

    output="$(
        bash "$REPO_ROOT/scripts/wiki-compat.sh" inspect "$wiki_root" 2>&1
    )" || fail "legacy wiki inspect should succeed without migration"

    assert_text_contains "$output" "schema_version=1.0"
    assert_text_contains "$output" "language=zh"
    assert_text_contains "$output" "migration_required=no"
    assert_text_contains "$output" "missing_optional_raw_dirs=raw/xiaohongshu"
    assert_text_contains "$output" "purpose_file=missing"
    assert_text_contains "$output" "cache_file=missing"

    bash "$REPO_ROOT/scripts/wiki-compat.sh" validate "$wiki_root" > /dev/null 2>&1 \
        || fail "legacy wiki validate should accept the old layout"
}

test_legacy_wiki_lazily_creates_new_source_dirs_without_moving_old_materials() {
    local tmp_dir wiki_root output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/legacy-wiki"
    make_legacy_wiki "$wiki_root"
    printf 'Old source material\n' > "$wiki_root/raw/articles/2026-04-01-old-source.md"

    bash "$REPO_ROOT/scripts/wiki-compat.sh" ensure-source-dir "$wiki_root" xiaohongshu_post > /dev/null 2>&1 \
        || fail "legacy wiki should lazily create missing source directories"

    assert_path_exists "$wiki_root/raw/xiaohongshu"
    assert_path_exists "$wiki_root/raw/articles/2026-04-01-old-source.md"

    output="$(
        bash "$REPO_ROOT/scripts/wiki-compat.sh" inspect "$wiki_root" 2>&1
    )" || fail "inspect should still succeed after lazily creating a source directory"

    assert_text_contains "$output" "missing_optional_raw_dirs=-"
}

test_new_wiki_compat_reports_purpose_and_cache_present() {
    local tmp_dir wiki_root output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/new-wiki"
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$wiki_root" "New Wiki" "Chinese" > /dev/null

    output="$(
        bash "$REPO_ROOT/scripts/wiki-compat.sh" inspect "$wiki_root" 2>&1
    )" || fail "new wiki inspect should succeed"

    assert_text_contains "$output" "purpose_file=present"
    assert_text_contains "$output" "cache_file=present"
}

test_readme_aligns_source_boundary_to_registry() {
    assert_file_contains "$REPO_ROOT/README.md" "## Source Support"
    assert_file_contains "$REPO_ROOT/README.md" "| Core |"
    assert_file_contains "$REPO_ROOT/README.md" "| Optional |"
    assert_file_contains "$REPO_ROOT/README.md" "| Manual |"
    assert_file_contains "$REPO_ROOT/README.md" "PDF"
    assert_file_contains "$REPO_ROOT/README.md" "Markdown"
    assert_file_contains "$REPO_ROOT/README.md" "HTML"
    assert_file_contains "$REPO_ROOT/README.md" "Plain text"
    assert_file_contains "$REPO_ROOT/README.md" "Web articles"
    assert_file_contains "$REPO_ROOT/README.md" "X/Twitter"
    assert_file_contains "$REPO_ROOT/README.md" "YouTube"
    assert_file_contains "$REPO_ROOT/README.md" "Xiaohongshu"
}

test_skill_status_and_ingest_align_to_registry() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "scripts/source-registry.sh list"
    assert_file_contains "$REPO_ROOT/SKILL.md" "scripts/source-registry.sh get"
    assert_file_contains "$REPO_ROOT/SKILL.md" "source_id"
    assert_file_contains "$REPO_ROOT/SKILL.md" "recovery_action"
    assert_file_contains "$REPO_ROOT/SKILL.md" "install_hint"
    assert_file_contains "$REPO_ROOT/SKILL.md" 'by `source_label` and `raw_dir` from the source registry'
    assert_file_contains "$REPO_ROOT/SKILL.md" "Adapter status should directly use"
}

test_schema_template_aligns_source_boundary_to_registry() {
    assert_file_contains "$REPO_ROOT/templates/schema-template.md" "Core pipeline"
    assert_file_contains "$REPO_ROOT/templates/schema-template.md" "Optional adapters"
    assert_file_contains "$REPO_ROOT/templates/schema-template.md" "Manual entry"
    assert_registry_labels_present_in_file "$REPO_ROOT/templates/schema-template.md" "core_builtin"
    assert_registry_labels_present_in_file "$REPO_ROOT/templates/schema-template.md" "optional_adapter"
    assert_registry_labels_present_in_file "$REPO_ROOT/templates/schema-template.md" "manual_only"
}

test_install_prints_source_boundary_from_registry() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills"

    output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/install.sh" --platform claude --dry-run 2>&1
    )" || fail "install.sh dry-run should print shared source boundary"

    assert_text_contains "$output" "Source Boundary"
    assert_text_contains "$output" "Core pipeline"
    assert_text_contains "$output" "Optional adapters"
    assert_text_contains "$output" "Manual entry"
    assert_registry_labels_present_in_text "$output" "core_builtin"
    assert_registry_labels_present_in_text "$output" "optional_adapter"
    assert_registry_labels_present_in_text "$output" "manual_only"
    assert_text_contains "$output" "--with-optional-adapters"
}

test_install_warns_when_managed_source_is_missing() {
    assert_file_contains "$REPO_ROOT/install.sh" "install source file missing, skipping"
}

test_validate_step1_no_args_exits_with_usage() {
    local output
    if output="$(bash "$REPO_ROOT/scripts/validate-step1.sh" 2>&1)"; then
        fail "validate-step1.sh should exit non-zero with no args"
    fi
    assert_text_contains "$output" "usage"
}

test_validate_step1_valid_json_passes() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    printf '%s\n' '{"entities":[{"name":"test","type":"concept","confidence":"EXTRACTED"}],"topics":[],"connections":[],"contradictions":[],"new_vs_existing":{}}' \
        > "$tmp_dir/step1.json"
    bash "$REPO_ROOT/scripts/validate-step1.sh" "$tmp_dir/step1.json" \
        || fail "validate-step1.sh should pass with valid JSON"
}

test_validate_step1_missing_confidence_fails() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    printf '%s\n' '{"entities":[{"name":"test","type":"concept"}],"topics":[],"connections":[],"contradictions":[],"new_vs_existing":{}}' \
        > "$tmp_dir/step1.json"
    if output="$(bash "$REPO_ROOT/scripts/validate-step1.sh" "$tmp_dir/step1.json" 2>&1)"; then
        fail "validate-step1.sh should fail when confidence is missing"
    fi
    assert_text_contains "$output" "missing required fields"
}

test_validate_step1_invalid_confidence_value_fails() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    printf '%s\n' '{"entities":[{"name":"test","type":"concept","confidence":"HIGH"}],"topics":[],"connections":[],"contradictions":[],"new_vs_existing":{}}' \
        > "$tmp_dir/step1.json"
    if output="$(bash "$REPO_ROOT/scripts/validate-step1.sh" "$tmp_dir/step1.json" 2>&1)"; then
        fail "validate-step1.sh should fail with invalid confidence value"
    fi
    assert_text_contains "$output" "HIGH"
}

test_validate_step1_entities_not_array_fails() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    printf '%s\n' '{"entities":{},"topics":[],"connections":[],"contradictions":[],"new_vs_existing":{}}' \
        > "$tmp_dir/step1.json"
    if output="$(bash "$REPO_ROOT/scripts/validate-step1.sh" "$tmp_dir/step1.json" 2>&1)"; then
        fail "validate-step1.sh should fail when entities is not an array"
    fi
    assert_text_contains "$output" "entities"
}

test_validate_step1_empty_entities_array_passes() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    printf '%s\n' '{"entities":[],"topics":[],"connections":[],"contradictions":[],"new_vs_existing":{}}' \
        > "$tmp_dir/step1.json"
    bash "$REPO_ROOT/scripts/validate-step1.sh" "$tmp_dir/step1.json" \
        || fail "validate-step1.sh should pass with empty entities array"
}

test_validate_step1_rejects_non_object_items() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    printf '%s\n' '{"entities":["not-an-object"],"topics":[],"connections":[],"contradictions":[],"new_vs_existing":{}}' \
        > "$tmp_dir/entity.json"
    if output="$(bash "$REPO_ROOT/scripts/validate-step1.sh" "$tmp_dir/entity.json" 2>&1)"; then
        fail "validate-step1.sh should fail when an entity item is not an object"
    fi
    assert_text_contains "$output" "entity"

    printf '%s\n' '{"entities":[],"topics":["not-an-object"],"connections":[],"contradictions":[],"new_vs_existing":{}}' \
        > "$tmp_dir/topic.json"
    if output="$(bash "$REPO_ROOT/scripts/validate-step1.sh" "$tmp_dir/topic.json" 2>&1)"; then
        fail "validate-step1.sh should fail when a topic item is not an object"
    fi
    assert_text_contains "$output" "topic"

    printf '%s\n' '{"entities":[],"topics":[],"connections":["not-an-object"],"contradictions":[],"new_vs_existing":{}}' \
        > "$tmp_dir/connection.json"
    if output="$(bash "$REPO_ROOT/scripts/validate-step1.sh" "$tmp_dir/connection.json" 2>&1)"; then
        fail "validate-step1.sh should fail when a connection item is not an object"
    fi
    assert_text_contains "$output" "connection"
}

test_lint_runner_accepts_index_alias_entries() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/wiki/entities"
    printf '# Index\n\n## 实体页\n- [[Real|真实页面]]\n' > "$tmp_dir/index.md"
    printf '# Real\n' > "$tmp_dir/wiki/entities/Real.md"

    output="$(bash "$REPO_ROOT/scripts/lint-runner.sh" "$tmp_dir" 2>&1)" \
        || fail "lint-runner.sh should run on alias index fixture"
    assert_text_not_contains "$output" "未收录: entities/Real"
}

test_lint_fix_does_not_require_macos_sed_in_place() {
    local tmp_dir wiki_root real_sed
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    wiki_root="$tmp_dir/wiki-root"
    real_sed="$(command -v sed)"

    mkdir -p "$wiki_root/wiki/entities" "$tmp_dir/bin"
    printf '# Index\n\n## 实体页\n' > "$wiki_root/index.md"
    printf '# Lonely\n' > "$wiki_root/wiki/entities/Lonely.md"

    make_stub "$tmp_dir/bin/sed" "#!/bin/sh
if [ \"\${1:-}\" = \"-i\" ] && [ \"\${2+x}\" = \"x\" ] && [ \"\$2\" = \"\" ]; then
  echo 'sed -i empty extension is not portable' >&2
  exit 2
fi
exec \"$real_sed\" \"\$@\"
"

    PATH="$tmp_dir/bin:$PATH" bash "$REPO_ROOT/scripts/lint-fix.sh" "$wiki_root" > /dev/null \
        || fail "lint-fix.sh should not depend on macOS sed -i syntax"
    assert_file_contains "$wiki_root/index.md" "- [[Lonely]]"
}

test_skill_md_ingest_has_confidence_assignment_rules() {
    local section
    section="$(sed -n '/## Workflow 2: ingest/,/## Workflow 3: batch-ingest/p' "$REPO_ROOT/SKILL.md")"
    assert_text_contains "$section" "EXTRACTED: Information appears directly in the source text"
    assert_text_contains "$section" "INFERRED:"
    assert_text_contains "$section" "AMBIGUOUS:"
    assert_text_contains "$section" "UNVERIFIED:"
    assert_text_contains "$section" "validate-step1.sh"
}

test_skill_md_has_crystallize_workflow_and_route() {
    local route_section crystallize_section
    route_section="$(sed -n '/## Workflow Routing/,/## Common Pre-checks/p' "$REPO_ROOT/SKILL.md")"
    crystallize_section="$(sed -n '/## Workflow 10: crystallize/,$p' "$REPO_ROOT/SKILL.md")"
    assert_text_contains "$route_section" "crystallize"
    assert_text_contains "$crystallize_section" "wiki/synthesis/sessions/"
    assert_text_contains "$crystallize_section" "INFERRED"
}

test_init_creates_synthesis_sessions_subdir() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$tmp_dir/wiki" "Test Wiki" > /dev/null 2>&1 \
        || fail "init-wiki.sh should succeed"
    assert_path_exists "$tmp_dir/wiki/wiki/synthesis/sessions"
}

test_create_source_page_writes_and_updates_cache() {
    local tmp_dir wiki_root raw_file content_file output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/wiki"
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$wiki_root" "Cache Test" "Chinese" > /dev/null

    raw_file="$wiki_root/raw/articles/test-article.md"
    printf 'Raw source content\n' > "$raw_file"

    content_file="$tmp_dir/content.tmp"
    printf '# Test Summary Page\n\nThis is test content.\n' > "$content_file"

    output="$(
        bash "$REPO_ROOT/scripts/create-source-page.sh" "$raw_file" "wiki/sources/test-article.md" "$content_file" 2>&1
    )" || fail "create-source-page.sh should succeed"
    assert_text_contains "$output" "SUCCESS"

    # Verify the page file was written
    assert_path_exists "$wiki_root/wiki/sources/test-article.md"
    assert_file_contains "$wiki_root/wiki/sources/test-article.md" "This is test content"

    # Verify cache was updated (check returns HIT)
    output="$(
        bash "$REPO_ROOT/scripts/cache.sh" check "$raw_file" 2>&1
    )"
    [ "$output" = "HIT" ] || fail "Expected HIT after create-source-page, got: $output"
}

test_create_source_page_rollback_on_cache_failure() {
    local tmp_dir wiki_root raw_file content_file
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/wiki"
    mkdir -p "$wiki_root/raw/articles" "$wiki_root/wiki/sources"
    # Use a corrupted cache file (not valid JSON) to make cache update fail
    printf 'not json\n' > "$wiki_root/.wiki-cache.json"
    printf '# Schema\n' > "$wiki_root/.wiki-schema.md"

    raw_file="$wiki_root/raw/articles/test-article.md"
    printf 'Raw source content\n' > "$raw_file"

    content_file="$tmp_dir/content.tmp"
    printf '# Test Summary Page\n' > "$content_file"

    bash "$REPO_ROOT/scripts/create-source-page.sh" "$raw_file" "wiki/sources/test-article.md" "$content_file" 2>/dev/null \
        && fail "create-source-page.sh should fail when cache update fails"

    # Verify the page file was rolled back (deleted)
    [ ! -f "$wiki_root/wiki/sources/test-article.md" ] || fail "Output file should be rolled back on cache failure"
}

test_cache_check_self_heals_with_matching_stem() {
    local tmp_dir wiki_root raw_file output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/wiki"
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$wiki_root" "Cache Test" "Chinese" > /dev/null

    raw_file="$wiki_root/raw/articles/rlhf-paper.md"
    printf 'RLHF paper content\n' > "$raw_file"

    # Write source page directly (not through script, simulating AI forgetting to update)
    cat > "$wiki_root/wiki/sources/rlhf-paper.md" <<'SRCEOF'
---
source_path: raw/articles/rlhf-paper.md
---
# RLHF Summary
SRCEOF

    # cache check should self-heal
    output="$(
        bash "$REPO_ROOT/scripts/cache.sh" check "$raw_file" 2>&1
    )"
    [ "$output" = "HIT(repaired)" ] || fail "Expected HIT(repaired) for self-heal, got: $output"

    # Second check should return normal HIT
    output="$(
        bash "$REPO_ROOT/scripts/cache.sh" check "$raw_file" 2>&1
    )"
    [ "$output" = "HIT" ] || fail "Expected HIT after repair, got: $output"
}

test_cache_check_miss_no_source_when_page_deleted() {
    local tmp_dir wiki_root raw_file output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/wiki"
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$wiki_root" "Cache Test" "Chinese" > /dev/null

    raw_file="$wiki_root/raw/articles/example.md"
    printf 'Original content\n' > "$raw_file"

    # Create cache normally
    printf '# Source Page\n' > "$wiki_root/wiki/sources/example.md"
    bash "$REPO_ROOT/scripts/cache.sh" update "$raw_file" "wiki/sources/example.md" > /dev/null 2>&1

    # Delete the source page
    rm "$wiki_root/wiki/sources/example.md"

    output="$(
        bash "$REPO_ROOT/scripts/cache.sh" check "$raw_file" 2>&1
    )"
    [ "$output" = "MISS:no_source" ] || fail "Expected MISS:no_source, got: $output"
}

test_cache_check_miss_hash_changed_when_content_differs() {
    local tmp_dir wiki_root raw_file output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/wiki"
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$wiki_root" "Cache Test" "Chinese" > /dev/null

    raw_file="$wiki_root/raw/articles/example.md"
    printf 'Original content v1\n' > "$raw_file"

    printf '# Source Page\n' > "$wiki_root/wiki/sources/example.md"
    bash "$REPO_ROOT/scripts/cache.sh" update "$raw_file" "wiki/sources/example.md" > /dev/null 2>&1

    # Modify source content
    printf 'Original content v2 changed\n' > "$raw_file"

    output="$(
        bash "$REPO_ROOT/scripts/cache.sh" check "$raw_file" 2>&1
    )"
    [ "$output" = "MISS:hash_changed" ] || fail "Expected MISS:hash_changed, got: $output"
}

test_skill_md_ingest_uses_create_source_page() {
    local section
    section="$(sed -n '/## Workflow 2: ingest/,/## Workflow 3: batch-ingest/p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$section" "create-source-page.sh"
    assert_text_contains "$section" "MISS:no_entry"
    assert_text_contains "$section" "MISS:hash_changed"
    assert_text_contains "$section" "MISS:no_source"
    assert_text_contains "$section" "HIT(repaired)"
}

test_skill_md_step12_does_not_call_cache_update() {
    local section step12
    section="$(sed -n '/## Workflow 2: ingest/,/## Workflow 3: batch-ingest/p' "$REPO_ROOT/SKILL.md")"
    step12="$(printf '%s' "$section" | sed -n '/^12\. \*\*Update log\.md/,/^13\./p')"

    # Step 12 should not contain executable cache.sh update code blocks (only mentioned in description text)
    # Check there are no lines starting with "bash" that contain "cache.sh update"
    if printf '%s' "$step12" | grep -E 'bash.*cache\.sh update' > /dev/null; then
        fail "Step 12 should not contain executable cache.sh update call"
    fi
    # Should mention that caching is handled by create-source-page.sh
    assert_text_contains "$step12" "create-source-page.sh"
}

test_setup_runs_on_bash_3_2
test_install_with_optional_adapters_bootstraps_dependencies
test_install_dry_run_for_claude
test_install_auto_refuses_ambiguous_platforms
test_upgrade_auto_refuses_ambiguous_installed_platforms
test_upgrade_uses_explicit_target_dir
test_upgrade_fails_when_explicit_target_dir_is_missing
test_upgrade_refreshes_claude_companion_skill
test_install_openclaw_copies_bundle
test_install_hermes_copies_bundle
test_init_fills_language_placeholder
test_phase1_templates_exist
test_init_creates_purpose_and_cache_files
test_cache_script_handles_miss_hit_and_invalidate
test_skill_md_phase2_init_mentions_purpose_and_cache
test_skill_md_phase2_ingest_mentions_two_step_cache_and_confidence
test_skill_md_phase2_batch_ingest_mentions_cache_skip_summary
test_skill_md_phase2_status_mentions_purpose_presence
test_skill_md_phase2_has_delete_workflow_and_route
test_delete_helper_scans_reference_files
test_skill_md_phase3_query_mentions_persistence_and_duplicate_handling
test_hook_session_start_outputs_context_when_wiki_exists
test_hook_session_start_returns_empty_json_without_wiki
test_install_registers_and_uninstalls_session_start_hook
test_platform_entries_mention_hook_and_wiki_context
test_root_entries_explain_core_only_optional_and_target_dir
test_skill_md_phase5_lint_mentions_confidence_audit
test_changelog_mentions_wiki_core_upgrades
test_readme_sections
test_claude_upgrade_companion_source_exists
test_install_succeeds_without_uv
test_skill_md_routes_via_registry
test_templates_have_no_empty_links
test_batch_ingest_has_step_two
test_english_templates_exist_and_have_placeholders
test_english_templates_have_no_empty_links
test_skill_md_has_shared_preflight_and_language_rules
test_skill_md_uses_external_english_templates_and_no_english_output_blocks
test_setup_wrapper_is_marked_deprecated
test_source_registry_contract_is_frozen
test_source_registry_groups_core_optional_and_manual_sources
test_source_registry_exposes_install_dependency_groups
test_source_registry_validation_passes
test_source_registry_matches_urls_and_files_from_shared_table
test_legacy_wiki_defaults_missing_fields_without_forcing_migration
test_legacy_wiki_lazily_creates_new_source_dirs_without_moving_old_materials
test_new_wiki_compat_reports_purpose_and_cache_present
test_readme_aligns_source_boundary_to_registry
test_skill_status_and_ingest_align_to_registry
test_schema_template_aligns_source_boundary_to_registry
test_install_prints_source_boundary_from_registry
test_install_warns_when_managed_source_is_missing
test_validate_step1_no_args_exits_with_usage
test_validate_step1_valid_json_passes
test_validate_step1_missing_confidence_fails
test_validate_step1_invalid_confidence_value_fails
test_validate_step1_entities_not_array_fails
test_validate_step1_empty_entities_array_passes
test_validate_step1_rejects_non_object_items
test_lint_runner_accepts_index_alias_entries
test_lint_fix_does_not_require_macos_sed_in_place
test_skill_md_ingest_has_confidence_assignment_rules
test_skill_md_has_crystallize_workflow_and_route
test_init_creates_synthesis_sessions_subdir
test_create_source_page_writes_and_updates_cache
test_create_source_page_rollback_on_cache_failure
test_cache_check_self_heals_with_matching_stem
test_cache_check_miss_no_source_when_page_deleted
test_cache_check_miss_hash_changed_when_content_differs
test_skill_md_ingest_uses_create_source_page
test_skill_md_step12_does_not_call_cache_update

# ─── Interactive graph tests ────────────────────────────────────────────

GRAPH_DATA_SAMPLE="tests/fixtures/graph-data-sample-wiki"
GRAPH_DATA_EMPTY="tests/fixtures/graph-data-empty-wiki"
GRAPH_HTML_BASIC="tests/fixtures/graph-interactive-basic"

test_graph_data_sample_wiki_matches_expected() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    LLM_WIKI_TEST_MODE=1 \
        bash "$REPO_ROOT/scripts/build-graph-data.sh" \
        "$REPO_ROOT/$GRAPH_DATA_SAMPLE" \
        "$tmp_dir/graph-data.json" > /dev/null 2>&1 \
        || fail "build-graph-data.sh should succeed on sample wiki"

    jq 'del(.nodes[].source_path)' "$tmp_dir/graph-data.json" > "$tmp_dir/normalized.json"
    diff "$tmp_dir/normalized.json" "$REPO_ROOT/tests/expected/graph-data-sample.json" \
        || fail "sample wiki graph-data output differs from expected"
}

test_graph_data_empty_wiki_matches_expected() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    LLM_WIKI_TEST_MODE=1 \
        bash "$REPO_ROOT/scripts/build-graph-data.sh" \
        "$REPO_ROOT/$GRAPH_DATA_EMPTY" \
        "$tmp_dir/graph-data.json" > /dev/null 2>&1 \
        || fail "build-graph-data.sh should succeed on empty wiki"

    diff "$tmp_dir/graph-data.json" "$REPO_ROOT/tests/expected/graph-data-empty.json" \
        || fail "empty wiki graph-data output differs from expected"
}

test_graph_data_test_mode_is_stable() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    LLM_WIKI_TEST_MODE=1 \
        bash "$REPO_ROOT/scripts/build-graph-data.sh" \
        "$REPO_ROOT/$GRAPH_DATA_SAMPLE" \
        "$tmp_dir/run1.json" > /dev/null 2>&1

    LLM_WIKI_TEST_MODE=1 \
        bash "$REPO_ROOT/scripts/build-graph-data.sh" \
        "$REPO_ROOT/$GRAPH_DATA_SAMPLE" \
        "$tmp_dir/run2.json" > /dev/null 2>&1

    diff "$tmp_dir/run1.json" "$tmp_dir/run2.json" \
        || fail "TEST_MODE output should be identical across runs"
}

test_graph_data_has_three_confidence_types() {
    local tmp_dir edges
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    LLM_WIKI_TEST_MODE=1 \
        bash "$REPO_ROOT/scripts/build-graph-data.sh" \
        "$REPO_ROOT/$GRAPH_DATA_SAMPLE" \
        "$tmp_dir/graph-data.json" > /dev/null 2>&1

    edges=$(jq -r '.edges[].type' "$tmp_dir/graph-data.json" | sort -u)
    assert_text_contains "$edges" "EXTRACTED"
    assert_text_contains "$edges" "INFERRED"
    assert_text_contains "$edges" "AMBIGUOUS"
}

test_graph_data_community_clustering() {
    local tmp_dir arch_nodes finetune_nodes paper_comm attention_comm
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    LLM_WIKI_TEST_MODE=1 \
        bash "$REPO_ROOT/scripts/build-graph-data.sh" \
        "$REPO_ROOT/$GRAPH_DATA_SAMPLE" \
        "$tmp_dir/graph-data.json" > /dev/null 2>&1

    arch_nodes=$(jq -r '.nodes[] | select(.community == "arch") | .id' "$tmp_dir/graph-data.json" | sort | tr '\n' ' ')
    assert_text_contains "$arch_nodes" "Decoder"
    assert_text_contains "$arch_nodes" "Encoder"
    assert_text_contains "$arch_nodes" "Transformer"
    assert_text_contains "$arch_nodes" "arch"

    finetune_nodes=$(jq -r '.nodes[] | select(.community == "finetune") | .id' "$tmp_dir/graph-data.json" | sort | tr '\n' ' ')
    assert_text_contains "$finetune_nodes" "GPT"
    assert_text_contains "$finetune_nodes" "finetune"

    attention_comm=$(jq -r '.nodes[] | select(.community == "Attention") | .id' "$tmp_dir/graph-data.json" | sort | tr '\n' ' ')
    assert_text_contains "$attention_comm" "Attention"
    assert_text_contains "$attention_comm" "paper"

    paper_comm=$(jq -r '.nodes[] | select(.id == "paper") | .community' "$tmp_dir/graph-data.json")
    [ "$paper_comm" = "Attention" ] || fail "Expected paper community to be Attention, got: $paper_comm"
}

test_graph_data_empty_wiki_has_zero_nodes_and_edges() {
    local tmp_dir nodes_count edges_count
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    LLM_WIKI_TEST_MODE=1 \
        bash "$REPO_ROOT/scripts/build-graph-data.sh" \
        "$REPO_ROOT/$GRAPH_DATA_EMPTY" \
        "$tmp_dir/graph-data.json" > /dev/null 2>&1

    nodes_count=$(jq '.meta.total_nodes' "$tmp_dir/graph-data.json")
    edges_count=$(jq '.meta.total_edges' "$tmp_dir/graph-data.json")
    [ "$nodes_count" = "0" ] || fail "Expected 0 nodes in empty wiki, got: $nodes_count"
    [ "$edges_count" = "0" ] || fail "Expected 0 edges in empty wiki, got: $edges_count"
}

test_graph_html_basic_assembly() {
    local tmp_dir output_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    output_dir="$tmp_dir/wiki"
    mkdir -p "$output_dir"
    cp "$REPO_ROOT/$GRAPH_HTML_BASIC/wiki/graph-data.json" "$output_dir/graph-data.json"

    bash "$REPO_ROOT/scripts/build-graph-html.sh" \
        "$tmp_dir" > /dev/null 2>&1 \
        || fail "build-graph-html.sh should succeed on basic fixture"

    # HTML file exists
    assert_path_exists "$output_dir/knowledge-graph.html"

    # Contains brand bar placeholder replacement results
    assert_file_contains "$output_dir/knowledge-graph.html" "HTML Test Wiki"
    assert_file_contains "$output_dir/knowledge-graph.html" "3"
    assert_file_contains "$output_dir/knowledge-graph.html" "2"

    # wash vendor assets copied
    assert_path_exists "$output_dir/d3.min.js"
    assert_path_exists "$output_dir/rough.min.js"
    assert_path_exists "$output_dir/marked.min.js"
    assert_path_exists "$output_dir/purify.min.js"
    assert_path_exists "$output_dir/graph-wash.js"
    assert_path_exists "$output_dir/LICENSE-d3.txt"
    assert_path_exists "$output_dir/LICENSE-roughjs.txt"
    assert_path_exists "$output_dir/LICENSE-marked.txt"
    assert_path_exists "$output_dir/LICENSE-purify.txt"
}

test_graph_html_escapes_script_tag_in_content() {
    local tmp_dir output_dir html
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    output_dir="$tmp_dir/wiki"
    mkdir -p "$output_dir"
    cp "$REPO_ROOT/$GRAPH_HTML_BASIC/wiki/graph-data.json" "$output_dir/graph-data.json"

    bash "$REPO_ROOT/scripts/build-graph-html.sh" \
        "$tmp_dir" > /dev/null 2>&1

    # </script> must be escaped as <\/script>
    html=$(cat "$output_dir/knowledge-graph.html")
    assert_text_not_contains "$html" '</script> tag test'
    assert_text_contains "$html" '<\/script> tag test'
}

test_graph_html_missing_data_exits_with_error() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/wiki"

    if bash "$REPO_ROOT/scripts/build-graph-html.sh" "$tmp_dir" > /dev/null 2>&1; then
        fail "build-graph-html.sh should fail when graph-data.json is missing"
    fi
}

test_graph_html_missing_template_exits_with_error() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/wiki/scripts" "$tmp_dir/wiki"
    printf '{}' > "$tmp_dir/wiki/graph-data.json"

    # Copy the script to a temp directory so it cannot find templates/
    cp "$REPO_ROOT/scripts/build-graph-html.sh" "$tmp_dir/wiki/scripts/"
    chmod +x "$tmp_dir/wiki/scripts/build-graph-html.sh"

    if bash "$tmp_dir/wiki/scripts/build-graph-html.sh" "$tmp_dir/wiki" > /dev/null 2>&1; then
        fail "build-graph-html.sh should fail when templates are missing"
    fi
}

test_graph_data_dead_links_are_ignored() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/wiki/entities"

    printf '# Alpha\n\nLinks to [[NonExistent]] entity.\n' > "$tmp_dir/wiki/entities/Alpha.md"

    LLM_WIKI_TEST_MODE=1 \
        bash "$REPO_ROOT/scripts/build-graph-data.sh" "$tmp_dir" "$tmp_dir/wiki/graph-data.json" > /dev/null 2>&1

    # Should have only 1 node (Alpha), 0 edges (NonExistent does not exist)
    local node_count edge_count
    node_count=$(jq '.meta.total_nodes' "$tmp_dir/wiki/graph-data.json")
    edge_count=$(jq '.meta.total_edges' "$tmp_dir/wiki/graph-data.json")
    [ "$node_count" = "1" ] || fail "Expected 1 node, got: $node_count"
    [ "$edge_count" = "0" ] || fail "Expected 0 edges (dead link ignored), got: $edge_count"
}

test_graph_data_self_links_are_ignored() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/wiki/entities"

    printf '# Self\n\nSelf-referencing [[Self]].\n' > "$tmp_dir/wiki/entities/Self.md"

    LLM_WIKI_TEST_MODE=1 \
        bash "$REPO_ROOT/scripts/build-graph-data.sh" "$tmp_dir" "$tmp_dir/wiki/graph-data.json" > /dev/null 2>&1

    local edge_count
    edge_count=$(jq '.meta.total_edges' "$tmp_dir/wiki/graph-data.json")
    [ "$edge_count" = "0" ] || fail "Expected 0 edges (self-link ignored), got: $edge_count"
}

test_graph_data_exits_without_jq() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/wiki/entities"
    mkdir -p "$tmp_dir/bin"
    ln -s /bin/bash "$tmp_dir/bin/bash"

    # Use an isolated PATH containing only bash to test jq dependency missing, avoiding host jq in /bin
    if output="$(PATH="$tmp_dir/bin" "$tmp_dir/bin/bash" "$REPO_ROOT/scripts/build-graph-data.sh" "$tmp_dir" 2>&1)"; then
        fail "build-graph-data.sh should fail when jq is not available"
    fi
    assert_text_contains "$output" "jq"
}

test_graph_data_wiki_dir_missing_exits() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    if bash "$REPO_ROOT/scripts/build-graph-data.sh" "$tmp_dir" 2>/dev/null; then
        fail "build-graph-data.sh should fail when wiki/ directory is missing"
    fi
}

test_graph_data_sample_wiki_matches_expected
test_graph_data_empty_wiki_matches_expected
test_graph_data_test_mode_is_stable
test_graph_data_has_three_confidence_types
test_graph_data_community_clustering
test_graph_data_empty_wiki_has_zero_nodes_and_edges
test_graph_html_basic_assembly
test_graph_html_escapes_script_tag_in_content
test_graph_html_missing_data_exits_with_error
test_graph_html_missing_template_exits_with_error
bash "$REPO_ROOT/tests/graph-analysis-helper.regression-1.sh" || fail "graph-analysis-helper.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-build-failures.regression-1.sh" || fail "graph-build-failures.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-brand-link.regression-1.sh" || fail "graph-html-brand-link.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-long-label.regression-1.sh" || fail "graph-html-long-label.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-minimap.regression-1.sh" || fail "graph-html-minimap.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-toolbar.regression-1.sh" || fail "graph-html-toolbar.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-drawer-neighbors.regression-1.sh" || fail "graph-html-drawer-neighbors.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-insights.regression-1.sh" || fail "graph-html-insights.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-a11y.regression-1.sh" || fail "graph-html-a11y.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-styles.regression-1.sh" || fail "graph-html-styles.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-search.regression-1.sh" || fail "graph-html-search.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-mobile.regression-1.sh" || fail "graph-html-mobile.regression-1.sh test failed"
bash "$REPO_ROOT/tests/graph-html-learning-cockpit.regression-1.sh" || fail "graph-html-learning-cockpit.regression-1.sh test failed"
test_graph_data_dead_links_are_ignored
test_graph_data_self_links_are_ignored
test_graph_data_exits_without_jq
test_graph_data_wiki_dir_missing_exits

bash "$REPO_ROOT/tests/adapter-state.sh" || fail "adapter-state.sh test failed"

# ─── JS unit tests ──────────────────────────────────────────────────────
node --test "$REPO_ROOT/tests/js/source-signal-eligibility.test.js" || fail "source-signal-eligibility unit tests failed"
node --test "$REPO_ROOT/tests/js/source-signal-coverage.test.js" || fail "source-signal-coverage integration tests failed"
node --test "$REPO_ROOT/tests/js/graph-wash-helpers.test.js" || fail "graph-wash-helpers unit tests failed"
node --test "$REPO_ROOT/tests/js/graph-wash-bootstrap.test.js" || fail "graph-wash bootstrap unit tests failed"
node --test "$REPO_ROOT/tests/js/graph-wash-queue.test.js" || fail "graph-wash queue unit tests failed"
node --test "$REPO_ROOT/tests/js/graph-wash-learning.test.js" || fail "graph-wash learning unit tests failed"
node --test "$REPO_ROOT/tests/js/graph-wash-runtime-state.test.js" || fail "graph-wash runtime state unit tests failed"

# ─── Lint regression ────────────────────────────────────────────────────
bash "$REPO_ROOT/tests/lint-output.regression-1.sh" || fail "lint output regression failed"

echo "All regression checks passed."
