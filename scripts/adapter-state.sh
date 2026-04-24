#!/bin/bash
# Adapter state detection script: unified check for optional adapter install/env/runtime status
# Five states: not_installed / env_unavailable (uv-dependent sources only) / runtime_failed / unsupported / empty_result

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_REGISTRY_SCRIPT="$SCRIPT_DIR/source-registry.sh"
# Shared config reference (kept for consistency with install.sh)
source "$SCRIPT_DIR/shared-config.sh"
source "$SCRIPT_DIR/runtime-context.sh"
SKILL_ROOT_OVERRIDE=""
LAYOUT_MODE_OVERRIDE=""

usage() {
  cat <<'EOF'
Usage:
  bash scripts/adapter-state.sh [--skill-root <path>] [--layout-mode <source_checkout|installed_skill|upgrade_target>] check <source_id>
  bash scripts/adapter-state.sh [--skill-root <path>] [--layout-mode <source_checkout|installed_skill|upgrade_target>] summary
  bash scripts/adapter-state.sh [--skill-root <path>] [--layout-mode <source_checkout|installed_skill|upgrade_target>] summary-human
  bash scripts/adapter-state.sh [--skill-root <path>] [--layout-mode <source_checkout|installed_skill|upgrade_target>] classify-run <source_id> <exit_code> <output_path>
EOF
}

resolve_optional_root() {
  resolve_optional_adapter_root "$PROJECT_ROOT" "$SKILL_ROOT_OVERRIDE" "$LAYOUT_MODE_OVERRIDE"
}

dependency_installed() {
  local dependency_name="$1"
  local dependency_type="$2"
  local optional_root

  case "$dependency_type" in
    bundled)
      optional_root="$(resolve_optional_root)"
      if [ -d "$optional_root/$dependency_name" ]; then
        return 0
      fi
      return 1
      ;;
    install_time)
      command -v "$dependency_name" >/dev/null 2>&1
      ;;
    none)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

has_uv() {
  command -v uv >/dev/null 2>&1
}

chrome_debug_ready() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -i :9222 -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi

  return 1
}

print_header() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "source_id" \
    "source_label" \
    "state" \
    "state_label" \
    "detail" \
    "recovery_action" \
    "install_hint" \
    "fallback_hint"
}

state_label() {
  case "$1" in
    available)
      printf '%s\n' "Available"
      ;;
    not_installed)
      printf '%s\n' "Not installed"
      ;;
    env_unavailable)
      printf '%s\n' "Environment not met"
      ;;
    runtime_failed)
      printf '%s\n' "Runtime failed"
      ;;
    unsupported)
      printf '%s\n' "Auto-extraction not supported"
      ;;
    empty_result)
      printf '%s\n' "Empty result"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

default_install_hint() {
  local source_id="$1"
  local adapter_name="$2"

  case "$source_id" in
    web_article|x_twitter)
      printf '%s\n' "Re-run the llm-wiki install command for your platform with --with-optional-adapters to ensure ${adapter_name} is prepared in the skill directory"
      ;;
    youtube_video)
      printf '%s\n' "Re-run the llm-wiki install command for your platform with --with-optional-adapters to ensure ${adapter_name} is prepared in the skill directory"
      ;;
    *)
      printf '%s\n' "-"
      ;;
  esac
}

optional_hint() {
  local source_id="$1"

  case "$source_id" in
    web_article|x_twitter)
      printf '%s\n' 'To reuse an existing browser session, run: open -na "Google Chrome" --args --remote-debugging-port=9222'
      ;;
    youtube_video)
      printf '%s\n' "-"
      ;;
    *)
      printf '%s\n' "-"
      ;;
  esac
}

emit_state_row() {
  local source_id="$1"
  local source_label="$2"
  local state="$3"
  local detail="$4"
  local recovery_action="$5"
  local install_hint="$6"
  local fallback_hint="$7"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$source_id" \
    "$source_label" \
    "$state" \
    "$(state_label "$state")" \
    "$detail" \
    "$recovery_action" \
    "$install_hint" \
    "$fallback_hint"
}

resolve_preflight_state() {
  local source_id="$1"
  local record
  local source_label source_category input_mode match_rule raw_dir adapter_name dependency_name dependency_type fallback_hint
  local state detail recovery_action install_hint

  record="$(bash "$SOURCE_REGISTRY_SCRIPT" get "$source_id")" || {
    echo "Unknown source: $source_id" >&2
    exit 1
  }

  IFS=$'\t' read -r source_id source_label source_category input_mode match_rule raw_dir adapter_name dependency_name dependency_type fallback_hint <<EOF
$record
EOF

  case "$source_category" in
    core_builtin)
      state="available"
      detail="Core pipeline can proceed directly, no adapter required"
      recovery_action="Continue with the core pipeline"
      install_hint="-"
      ;;
    manual_only)
      state="unsupported"
      detail="This source currently only supports manual entry into the pipeline"
      recovery_action="Use the manual entry path"
      install_hint="-"
      ;;
    optional_adapter)
      case "$source_id" in
        web_article|x_twitter)
          if ! dependency_installed "$dependency_name" "$dependency_type"; then
            state="not_installed"
            detail="${adapter_name} not found"
            recovery_action="Install the adapter first; you can also use the manual entry path now"
            install_hint="$(default_install_hint "$source_id" "$adapter_name")"
          else
            state="available"
            if chrome_debug_ready; then
              detail="${adapter_name} is available, and a reusable Chrome debug session was detected"
              recovery_action="Continue with auto-extraction"
              install_hint="-"
            else
              detail="${adapter_name} is available; port 9222 not detected, a temporary browser will be launched when needed"
              recovery_action="Continue with auto-extraction; to reuse an existing session, open Chrome debug port 9222 first"
              install_hint="$(optional_hint "$source_id")"
            fi
          fi
          ;;
        youtube_video)
          if ! dependency_installed "$dependency_name" "$dependency_type"; then
            state="not_installed"
            detail="${adapter_name} not found"
            recovery_action="Install the adapter first; you can also use the manual entry path now"
            install_hint="$(default_install_hint "$source_id" "$adapter_name")"
          elif ! has_uv; then
            state="env_unavailable"
            detail="uv is missing, cannot run YouTube transcript extraction"
            recovery_action="Install the prerequisite first; you can also use the manual entry path now"
            install_hint="$(optional_hint "$source_id")"
          else
            state="available"
            detail="${adapter_name} is available"
            recovery_action="Continue with auto-extraction"
            install_hint="-"
          fi
          ;;
        *)
          if ! dependency_installed "$dependency_name" "$dependency_type"; then
            state="not_installed"
            detail="${adapter_name} not found"
            recovery_action="Install the adapter first; you can also use the manual entry path now"
            install_hint="$(default_install_hint "$source_id" "$adapter_name")"
          else
            state="available"
            detail="${adapter_name} is available"
            recovery_action="Continue with auto-extraction"
            install_hint="-"
          fi
          ;;
      esac
      ;;
    *)
      echo "Unknown source category: $source_category" >&2
      exit 1
      ;;
  esac

  emit_state_row \
    "$source_id" \
    "$source_label" \
    "$state" \
    "$detail" \
    "$recovery_action" \
    "$install_hint" \
    "$fallback_hint"
}

classify_run_state() {
  local source_id="$1"
  local exit_code="$2"
  local output_path="$3"

  # Validate exit_code is an integer to prevent script crash from non-numeric args under set -e
  case "$exit_code" in
    ''|*[!0-9-]*) echo "exit_code must be an integer, got: $exit_code" >&2; exit 1 ;;
  esac

  local row
  local source_label state state_label_value detail recovery_action install_hint fallback_hint

  row="$(resolve_preflight_state "$source_id")"
  IFS=$'\t' read -r _ source_label state state_label_value detail recovery_action install_hint fallback_hint <<EOF
$row
EOF

  if [ "$state" != "available" ]; then
    emit_state_row \
      "$source_id" \
      "$source_label" \
      "$state" \
      "$detail" \
      "$recovery_action" \
      "$install_hint" \
      "$fallback_hint"
    return 0
  fi

  if [ "$exit_code" -ne 0 ]; then
    emit_state_row \
      "$source_id" \
      "$source_label" \
      "runtime_failed" \
      "Auto-extraction execution failed" \
      "Try again; if it still fails, use the manual entry path" \
      "-" \
      "$fallback_hint"
    return 0
  fi

  if [ ! -f "$output_path" ] || ! grep -q '[^[:space:]]' "$output_path" 2>/dev/null; then
    emit_state_row \
      "$source_id" \
      "$source_label" \
      "empty_result" \
      "Auto-extraction completed but no valid content was retrieved" \
      "Please manually provide the text and continue with the pipeline" \
      "-" \
      "$fallback_hint"
    return 0
  fi

  emit_state_row \
    "$source_id" \
    "$source_label" \
    "available" \
    "Auto-extraction retrieved valid content" \
    "Continue into the pipeline" \
    "-" \
    "$fallback_hint"
}

print_summary() {
  local source_id

  print_header

  while IFS=$'\t' read -r source_id _; do
    [ -n "$source_id" ] || continue
    resolve_preflight_state "$source_id"
  done <<EOF
$(bash "$SOURCE_REGISTRY_SCRIPT" list | awk -F '\t' 'NR > 1 && ($3 == "optional_adapter" || $3 == "manual_only") { print $1 "\t" $2 }')
EOF
}

print_summary_human() {
  local row
  local source_id source_label state state_label_value detail recovery_action install_hint fallback_hint

  while IFS= read -r row; do
    [ -n "$row" ] || continue

    IFS=$'\t' read -r source_id source_label state state_label_value detail recovery_action install_hint fallback_hint <<EOF
$row
EOF

    printf '%s\n' "- ${source_label}: ${state_label_value}. ${detail}."
    printf '%s\n' "  Next step: ${recovery_action}."
    if [ "$install_hint" != "-" ]; then
      if [ "$state" = "available" ]; then
        printf '%s\n' "  Note: ${install_hint}."
      else
        printf '%s\n' "  Install hint: ${install_hint}."
      fi
    fi
    printf '%s\n' "  Fallback: ${fallback_hint}."
  done <<EOF
$(print_summary | tail -n +2)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --skill-root)
      [ $# -ge 2 ] || { usage; exit 1; }
      SKILL_ROOT_OVERRIDE="$2"
      shift 2
      ;;
    --layout-mode)
      [ $# -ge 2 ] || { usage; exit 1; }
      LAYOUT_MODE_OVERRIDE="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

command_name="${1:-}"

case "$command_name" in
  check)
    [ "$#" -eq 2 ] || { usage; exit 1; }
    print_header
    resolve_preflight_state "$2"
    ;;
  summary)
    [ "$#" -eq 1 ] || { usage; exit 1; }
    print_summary
    ;;
  summary-human)
    [ "$#" -eq 1 ] || { usage; exit 1; }
    print_summary_human
    ;;
  classify-run)
    [ "$#" -eq 4 ] || { usage; exit 1; }
    print_header
    classify_run_state "$2" "$3" "$4"
    ;;
  *)
    usage
    exit 1
    ;;
esac
