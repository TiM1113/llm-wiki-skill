#!/bin/bash
# llm-wiki deletion helper script

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/delete-helper.sh scan-refs <wiki_root> <material_filename>
EOF
}

scan_refs() {
  local wiki_root="$1"
  local needle="$2"
  local wiki_dir="$wiki_root/wiki"

  [ -n "$needle" ] || {
    echo "Material filename cannot be empty" >&2
    exit 1
  }

  [ -d "$wiki_dir" ] || {
    echo "Wiki directory not found: $wiki_dir" >&2
    exit 1
  }

  {
    grep -rlF --include='*.md' -- "$needle" "$wiki_dir" 2>/dev/null || true
  } | python3 -c '
import os
import sys

wiki_root = os.path.realpath(sys.argv[1])
seen = []

for line in sys.stdin:
    path = line.strip()
    if not path:
        continue
    real_path = os.path.realpath(path)
    if real_path in seen:
        continue
    seen.append(real_path)

for path in sorted(seen):
    print(os.path.relpath(path, wiki_root))
' "$wiki_root"
}

command_name="${1:-}"

case "$command_name" in
  scan-refs)
    [ "$#" -eq 3 ] || { usage; exit 1; }
    scan_refs "$2" "$3"
    ;;
  *)
    usage
    exit 1
    ;;
esac
