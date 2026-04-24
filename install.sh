#!/bin/bash
# llm-wiki unified installer
set -euo pipefail

SKILL_NAME="llm-wiki"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_REGISTRY_SCRIPT="$SCRIPT_DIR/scripts/source-registry.sh"
ADAPTER_STATE_SCRIPT="$SCRIPT_DIR/scripts/adapter-state.sh"
PLATFORM="auto"
PLATFORM_EXPLICIT=0
DRY_RUN=0
TARGET_DIR=""
INSTALL_HOOKS=0
UNINSTALL_HOOKS=0
UPGRADE=0
WITH_OPTIONAL_ADAPTERS=0

# These items are read or linked at runtime:
# - Entry and description files: README / CLAUDE / AGENTS / CHANGELOG
# - Install entry points: install.sh / setup.sh
# - Actual execution content: SKILL.md / scripts / templates / deps
# - Platform thin entry points: platforms (referenced by README, CLAUDE, AGENTS)
MANAGED_ITEMS=(
  "SKILL.md"
  "README.md"
  "CLAUDE.md"
  "AGENTS.md"
  "HERMES.md"
  "CHANGELOG.md"
  "install.sh"
  "setup.sh"
  "scripts"
  "templates"
  "deps"
  "platforms"
)

DEP_SKILLS=()

list_companion_skill_sources() {
  case "$1" in
    claude)
      printf '%s\n' "platforms/claude/companions/llm-wiki-upgrade"
      ;;
  esac
}

source "$SCRIPT_DIR/scripts/shared-config.sh"
source "$SCRIPT_DIR/scripts/runtime-context.sh"

info()  { printf '\033[36m[Info]\033[0m %s\n' "$1"; }
ok()    { printf '\033[32m[Done]\033[0m %s\n' "$1"; }
warn()  { printf '\033[33m[Warn]\033[0m %s\n' "$1"; }
err()   { printf '\033[31m[Error]\033[0m %s\n' "$1" >&2; }

usage() {
  cat <<'EOF'
Usage:
  bash install.sh --platform <claude|codex|openclaw|hermes|auto> [--dry-run]
  bash install.sh --platform claude --install-hooks
  bash install.sh --install-hooks
  bash install.sh --uninstall-hooks
  bash install.sh --upgrade [--platform <claude|codex|openclaw|hermes|auto>]
  bash install.sh --platform codex --with-optional-adapters

Options:
  --platform         Target platform. Defaults to auto; only auto-installs when exactly one platform is detected.
  --dry-run          Only print the install plan, do not write files.
  --target-dir       Specify the skill target directory (pass the final llm-wiki directory directly).
  --with-optional-adapters  Explicitly enable installation of optional extractors (web / X / YouTube).
  --install-hooks    Register the Claude Code SessionStart hook.
  --uninstall-hooks  Remove the Claude Code SessionStart hook.
  --upgrade          Pull latest code and update the installed llm-wiki (preserves hook configuration).
  -h, --help         Show help.
EOF
}

hook_command_for_skill_dir() {
  printf 'bash %s/scripts/hook-session-start.sh\n' "$1"
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    err "jq is required to register or remove hooks"
    exit 1
  fi
}

register_claude_session_hook() {
  local skill_dir="$1"
  local settings_dir settings_path backup_path hook_command tmp_file

  [ -d "$skill_dir" ] || {
    err "Installed llm-wiki not found: $skill_dir"
    exit 1
  }

  require_jq

  settings_dir="$HOME/.claude"
  settings_path="$settings_dir/settings.json"
  backup_path="$settings_dir/settings.json.bak.llm-wiki"
  hook_command="$(hook_command_for_skill_dir "$skill_dir")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] register SessionStart hook: %s\n' "$hook_command"
    return 0
  fi

  mkdir -p "$settings_dir"
  [ -f "$settings_path" ] || printf '{}\n' > "$settings_path"
  cp "$settings_path" "$backup_path"

  if jq -e --arg cmd "$hook_command" '[ (.hooks.SessionStart // [])[]? | (.hooks // [])[]? | .command ] | index($cmd) != null' "$settings_path" > /dev/null; then
    ok "Claude Code SessionStart hook already exists, skipping"
    return 0
  fi

  tmp_file="$(mktemp)"
  jq --arg cmd "$hook_command" '
    .hooks = (.hooks // {}) |
    .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks":[{"type":"command","command":$cmd}]}])
  ' "$settings_path" > "$tmp_file"
  mv "$tmp_file" "$settings_path"

  ok "Claude Code SessionStart hook registered"
}

uninstall_claude_session_hook() {
  local skill_dir="$1"
  local settings_dir settings_path backup_path hook_command tmp_file

  require_jq

  settings_dir="$HOME/.claude"
  settings_path="$settings_dir/settings.json"
  backup_path="$settings_dir/settings.json.bak.llm-wiki"
  hook_command="$(hook_command_for_skill_dir "$skill_dir")"

  if [ ! -f "$settings_path" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '[dry-run] uninstall SessionStart hook: %s\n' "$hook_command"
      return 0
    fi
    ok "Claude Code settings.json not found, skipping hook removal"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] uninstall SessionStart hook: %s\n' "$hook_command"
    return 0
  fi

  cp "$settings_path" "$backup_path"

  tmp_file="$(mktemp)"
  jq --arg cmd "$hook_command" '
    .hooks = (.hooks // {}) |
    .hooks.SessionStart = (
      (.hooks.SessionStart // [])
      | map(.hooks = ((.hooks // []) | map(select(.command != $cmd))))
      | map(select((.hooks // []) | length > 0))
    ) |
    if ((.hooks.SessionStart // []) | length) == 0 then del(.hooks.SessionStart) else . end |
    if (.hooks | length) == 0 then del(.hooks) else . end
  ' "$settings_path" > "$tmp_file"
  mv "$tmp_file" "$settings_path"

  ok "Claude Code SessionStart hook removed"
}

load_dependency_skills() {
  local dep

  DEP_SKILLS=()

  while IFS= read -r dep; do
    [ -n "$dep" ] && DEP_SKILLS+=("$dep")
  done < <(bash "$SOURCE_REGISTRY_SCRIPT" unique-dependencies bundled)
}

join_source_labels() {
  local category="$1"

  bash "$SOURCE_REGISTRY_SCRIPT" list-by-category "$category" \
    | awk -F '\t' '
      BEGIN { separator = "" }
      NF {
        printf "%s%s", separator, $2
        separator = ", "
      }
      END {
        if (separator == "") {
          printf "-"
        }
        printf "\n"
      }
    '
}

run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

copy_item() {
  local source_path="$1"
  local target_path="$2"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] copy %s -> %s\n' "$source_path" "$target_path"
    return 0
  fi

  rm -rf "$target_path"
  cp -R "$source_path" "$target_path"
}

detect_available_platforms() {
  local found=()

  if [ -d "$HOME/.claude" ] || [ -d "$HOME/.claude/skills" ]; then
    found+=("claude")
  fi

  if [ -d "$HOME/.codex" ] || [ -d "$HOME/.codex/skills" ] || [ -d "$HOME/.Codex" ] || [ -d "$HOME/.Codex/skills" ]; then
    found+=("codex")
  fi

  if [ -d "$HOME/.openclaw" ] || [ -d "$HOME/.openclaw/skills" ]; then
    found+=("openclaw")
  fi

  if [ -d "$HOME/.hermes" ] || [ -d "$HOME/.hermes/skills" ]; then
    found+=("hermes")
  fi

  printf '%s\n' "${found[@]}"
}

install_dependency_skills() {
  local skill_root="$1"
  local dep dep_target dep_source

  for dep in "${DEP_SKILLS[@]}"; do
    dep_source="$SCRIPT_DIR/deps/$dep"
    dep_target="$skill_root/$dep"

    if [ ! -d "$dep_source" ]; then
      warn "$dep: source not found in deps/, skipping"
      continue
    fi

    copy_item "$dep_source" "$dep_target"
    ok "$dep prepared at $dep_target"
  done
}

install_companion_skills() {
  local platform="$1"
  local skill_root="$2"
  local skill_rel skill_source skill_target skill_name

  while IFS= read -r skill_rel; do
    [ -n "$skill_rel" ] || continue

    skill_source="$SCRIPT_DIR/$skill_rel"
    skill_name="$(basename "$skill_rel")"
    skill_target="$skill_root/$skill_name"

    if [ ! -d "$skill_source" ]; then
      warn "$skill_name: source not found in repository, skipping"
      continue
    fi

    copy_item "$skill_source" "$skill_target"
    ok "$skill_name installed at $skill_target"
  done < <(list_companion_skill_sources "$platform")
}

install_bundle() {
  local target_dir="$1"
  local item source_path target_path

  for item in "${MANAGED_ITEMS[@]}"; do
    source_path="$SCRIPT_DIR/$item"
    target_path="$target_dir/$item"

    if [ ! -e "$source_path" ]; then
      warn "$item: install source file missing, skipping"
      continue
    fi

    if [ "$source_path" = "$target_path" ] && [ -e "$target_path" ]; then
      continue
    fi

    copy_item "$source_path" "$target_path"
  done
}

install_node_deps() {
  local skill_root="$1"
  local baoyu_dir="$skill_root/baoyu-url-to-markdown/scripts"

  if [ ! -d "$baoyu_dir" ] || [ ! -f "$baoyu_dir/package.json" ]; then
    return 0
  fi

  if [ -d "$baoyu_dir/node_modules" ]; then
    ok "Node dependencies for baoyu-url-to-markdown already exist"
    return 0
  fi

  info "Installing Node dependencies for baoyu-url-to-markdown..."

  if [ "$DRY_RUN" -eq 1 ]; then
    if command -v bun >/dev/null 2>&1; then
      printf '[dry-run] (cd %s && bun install)\n' "$baoyu_dir"
    elif command -v npm >/dev/null 2>&1; then
      printf '[dry-run] (cd %s && npm install)\n' "$baoyu_dir"
    else
      printf '[dry-run] Neither bun nor npm found, cannot install Node dependencies\n'
    fi
    return 0
  fi

  if command -v bun >/dev/null 2>&1; then
    (cd "$baoyu_dir" && bun install) || warn "bun install failed, skipping (you can manually paste text as an alternative)"
  elif command -v npm >/dev/null 2>&1; then
    (cd "$baoyu_dir" && npm install) || warn "npm install failed, skipping (you can manually paste text as an alternative)"
  else
    warn "Neither bun nor npm found, cannot install Node dependencies"
    echo "  Recommended: install bun via: curl -fsSL https://bun.sh/install | bash"
    return 0
  fi

  [ -d "$baoyu_dir/node_modules" ] && ok "Node dependencies for baoyu-url-to-markdown installed"
}

bootstrap_optional_adapters() {
  local skill_root="$1"

  if [ "$WITH_OPTIONAL_ADAPTERS" -ne 1 ]; then
    return 0
  fi

  load_dependency_skills
  install_dependency_skills "$skill_root"
  install_node_deps "$skill_root"
}

check_environment() {
  echo ""
  echo "================================"
  echo "  Environment Check"
  echo "================================"
  echo ""

  if command -v uv >/dev/null 2>&1; then
    ok "uv is installed (can run youtube-transcript)"
  else
    warn "uv not found. youtube-transcript requires uv"
    echo "  Install via Homebrew: brew install uv"
  fi

  if command -v lsof >/dev/null 2>&1 && lsof -i :9222 -sTCP:LISTEN >/dev/null 2>&1; then
    ok "Chrome debug port 9222 is listening (can reuse existing session)"
  else
    info "Chrome debug port 9222 not detected. baoyu-url-to-markdown can still launch a temporary browser automatically"
    echo "  To reuse an existing session, run: open -na \"Google Chrome\" --args --remote-debugging-port=9222"
  fi

  echo ""
  echo "Note: Even if some adapters are unavailable, PDF / local files / plain text can still enter the pipeline directly."
}

print_source_boundary() {
  local core_sources optional_sources manual_sources

  core_sources="$(join_source_labels core_builtin)"
  optional_sources="$(join_source_labels optional_adapter)"
  manual_sources="$(join_source_labels manual_only)"

  echo ""
  echo "================================"
  echo "  Source Boundary"
  echo "================================"
  echo ""
  echo "Core pipeline: $core_sources"
  echo "Optional adapters: $optional_sources"
  echo "Manual entry: $manual_sources"
}

print_adapter_states() {
  local output

  echo ""
  echo "================================"
  echo "  Adapter Status"
  echo "================================"
  echo ""

  output="$(
    bash "$ADAPTER_STATE_SCRIPT" --skill-root "$SKILL_ROOT" --layout-mode installed_skill summary-human 2>&1
  )" || {
    warn "Unable to generate adapter status summary"
    printf '%s\n' "$output"
    return 0
  }

  printf '%s\n' "$output"
}

print_optional_adapter_hint() {
  local command

  command="bash install.sh"
  if [ "$UPGRADE" -eq 1 ]; then
    command="$command --upgrade"
  fi
  command="$command --platform ${PLATFORM}"
  if [ -n "$TARGET_DIR" ]; then
    command="$command --target-dir ${TARGET_DIR}"
  fi
  command="$command --with-optional-adapters"

  echo ""
  echo "Note: Only the core wiki pipeline has been set up."
  echo "To enable auto-extraction for web / X / YouTube, run:"
  echo "  $command"
}

print_claude_upgrade_hint() {
  local platform="$1"

  if [ "$platform" != "claude" ]; then
    return 0
  fi

  echo ""
  echo "Note: After Claude Code installation, you can also use /llm-wiki-upgrade to update the core pipeline."
}

while [ $# -gt 0 ]; do
  case "$1" in
    --platform)
      [ $# -ge 2 ] || { err "--platform requires a value"; usage; exit 1; }
      PLATFORM="$2"
      PLATFORM_EXPLICIT=1
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --target-dir)
      [ $# -ge 2 ] || { err "--target-dir requires a value"; usage; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    --with-optional-adapters)
      WITH_OPTIONAL_ADAPTERS=1
      shift
      ;;
    --install-hooks)
      INSTALL_HOOKS=1
      shift
      ;;
    --uninstall-hooks)
      UNINSTALL_HOOKS=1
      shift
      ;;
    --upgrade)
      UPGRADE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [ "$INSTALL_HOOKS" -eq 1 ] && [ "$UNINSTALL_HOOKS" -eq 1 ]; then
  err "--install-hooks and --uninstall-hooks cannot be used together"
  exit 1
fi

if [ "$UPGRADE" -eq 1 ]; then
  if [ -n "$TARGET_DIR" ] && [ "$PLATFORM" = "auto" ]; then
    err "When upgrading with a custom target directory, please explicitly pass --platform"
    exit 1
  fi

  if [ "$PLATFORM" = "auto" ]; then
    detected_platforms=()
    for p in claude codex openclaw hermes; do
      skill_root_candidate="$(resolve_platform_skill_root "$p")"
      [ -d "$skill_root_candidate/$SKILL_NAME" ] && detected_platforms+=("$p")
    done

    if [ "${#detected_platforms[@]}" -eq 0 ]; then
      err "No installed llm-wiki detected, please run the installer first"
      exit 1
    fi

    if [ "${#detected_platforms[@]}" -gt 1 ]; then
      err "Multiple installed platforms detected: ${detected_platforms[*]}. Please explicitly pass --platform for upgrade"
      exit 1
    fi

    PLATFORM="${detected_platforms[0]}"
    UPGRADE_PLATFORMS=("${detected_platforms[@]}")
  else
    UPGRADE_PLATFORMS=("$PLATFORM")
  fi

  echo ""
  echo "================================"
  echo "  llm-wiki Upgrade"
  echo "================================"
  echo ""

  if [ -d "$SCRIPT_DIR/.git" ]; then
    info "Pulling latest code from remote..."
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '[dry-run] git -C %s pull\n' "$SCRIPT_DIR"
    else
      git -C "$SCRIPT_DIR" pull || {
        err "git pull failed, please check your network or pull manually and retry"
        exit 1
      }
    fi
    ok "Code pulled to latest"
  else
    warn "Current directory is not a git repository, skipping git pull"
  fi

  upgrade_failures=0

  for upgrade_platform in "${UPGRADE_PLATFORMS[@]}"; do
    upgrade_root="$(resolve_platform_skill_root "$upgrade_platform")"
    if [ -n "$TARGET_DIR" ]; then
      upgrade_target="$TARGET_DIR"
      upgrade_root="$(dirname "$upgrade_target")"
    else
      upgrade_target="$upgrade_root/$SKILL_NAME"
    fi

    echo ""
    info "Updating llm-wiki for $upgrade_platform..."
    echo "  Target directory: $upgrade_target"

    if [ ! -d "$upgrade_target" ]; then
      err "llm-wiki not yet installed for $upgrade_platform: $upgrade_target"
      upgrade_failures=$((upgrade_failures + 1))
      continue
    fi

    run_cmd mkdir -p "$upgrade_target"
    install_bundle "$upgrade_target"
    install_companion_skills "$upgrade_platform" "$upgrade_root"
    bootstrap_optional_adapters "$upgrade_root"
    ok "llm-wiki for $upgrade_platform has been updated"
  done

  if [ "$upgrade_failures" -gt 0 ]; then
    echo ""
    err "llm-wiki upgrade failed, please verify the target directory exists and installation was completed"
    exit 1
  fi

  print_source_boundary
  if [ "$WITH_OPTIONAL_ADAPTERS" -eq 1 ]; then
    check_environment
  else
    print_optional_adapter_hint
  fi
  print_claude_upgrade_hint "$PLATFORM"

  echo ""
  ok "llm-wiki upgrade complete"
  exit 0
fi

if [ "$PLATFORM" = "auto" ] && { [ "$INSTALL_HOOKS" -eq 1 ] || [ "$UNINSTALL_HOOKS" -eq 1 ]; }; then
  PLATFORM="claude"
fi

if [ "$PLATFORM" = "auto" ]; then
  detected_platforms=()
  while IFS= read -r platform_name; do
    [ -n "$platform_name" ] && detected_platforms+=("$platform_name")
  done < <(detect_available_platforms)
  if [ "${#detected_platforms[@]}" -eq 1 ]; then
    PLATFORM="${detected_platforms[0]}"
  elif [ "${#detected_platforms[@]}" -eq 0 ]; then
    err "No supported platform directory detected. Please explicitly pass --platform claude|codex|openclaw|hermes"
    exit 1
  else
    err "Multiple available platforms detected: ${detected_platforms[*]}. Please explicitly pass --platform"
    exit 1
  fi
fi

SKILL_ROOT="$(resolve_platform_skill_root "$PLATFORM")"

if { [ "$INSTALL_HOOKS" -eq 1 ] || [ "$UNINSTALL_HOOKS" -eq 1 ]; } && [ "$PLATFORM" != "claude" ]; then
  err "Only Claude Code supports SessionStart hooks"
  exit 1
fi

if [ -n "$TARGET_DIR" ]; then
  TARGET_SKILL_DIR="$TARGET_DIR"
  SKILL_ROOT="$(dirname "$TARGET_SKILL_DIR")"
else
  TARGET_SKILL_DIR="$SKILL_ROOT/$SKILL_NAME"
fi

if [ "$UNINSTALL_HOOKS" -eq 1 ]; then
  uninstall_claude_session_hook "$TARGET_SKILL_DIR"
  echo ""
  ok "llm-wiki hook removed"
  exit 0
fi

if [ "$INSTALL_HOOKS" -eq 1 ] && [ "$PLATFORM_EXPLICIT" -eq 0 ] && [ -z "$TARGET_DIR" ]; then
  register_claude_session_hook "$TARGET_SKILL_DIR"
  echo ""
  ok "llm-wiki hook setup complete"
  exit 0
fi

echo ""
echo "================================"
echo "  llm-wiki Install"
echo "================================"
echo ""
echo "Platform: $PLATFORM"
echo "Skill root: $SKILL_ROOT"
echo "Target directory: $TARGET_SKILL_DIR"

run_cmd mkdir -p "$SKILL_ROOT"
run_cmd mkdir -p "$TARGET_SKILL_DIR"

install_bundle "$TARGET_SKILL_DIR"
install_companion_skills "$PLATFORM" "$SKILL_ROOT"
bootstrap_optional_adapters "$SKILL_ROOT"
print_source_boundary
if [ "$WITH_OPTIONAL_ADAPTERS" -eq 1 ]; then
  check_environment
  print_adapter_states
else
  print_optional_adapter_hint
fi
print_claude_upgrade_hint "$PLATFORM"

if [ "$INSTALL_HOOKS" -eq 1 ]; then
  register_claude_session_hook "$TARGET_SKILL_DIR"
fi

echo ""
ok "llm-wiki setup complete"
