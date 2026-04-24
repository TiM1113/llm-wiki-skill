#!/bin/bash
# llm-wiki source page write script
# Atomic write of source page + automatic cache update, bound as a single operation

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/create-source-page.sh <raw_file> <output_path> <content_file>

Arguments:
  raw_file     : path to the raw material file (absolute or relative)
  output_path  : target page path (relative to wiki root, e.g., wiki/sources/2026-04-16-rlhf.md)
  content_file : path to the temporary file containing the content to write
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parameter validation
if [ "$#" -ne 3 ]; then
  usage
  exit 1
fi

raw_file="$1"
output_path="$2"
content_file="$3"

# raw_file and content_file must exist
if [ ! -f "$raw_file" ]; then
  echo "ERROR: Raw material file not found: $raw_file" >&2
  exit 1
fi

if [ ! -f "$content_file" ]; then
  echo "ERROR: Content file not found: $content_file" >&2
  exit 1
fi

# Find wiki root using cache.sh's find_wiki_root logic
# Reuse functions from cache.sh
source_cache_helpers() {
  # Inline find_wiki_root (kept in sync with cache.sh)
  find_wiki_root() {
    local file_path="$1"
    local dir parent

    dir="$(cd "$(dirname "$file_path")" && pwd)"

    while true; do
      if [ -f "$dir/.wiki-cache.json" ] || [ -f "$dir/.wiki-schema.md" ]; then
        printf '%s\n' "$dir"
        return 0
      fi

      parent="$(dirname "$dir")"
      [ "$parent" = "$dir" ] && return 1
      dir="$parent"
    done
  }
}

source_cache_helpers

wiki_root="$(find_wiki_root "$raw_file")" || {
  echo "ERROR: Wiki root not found: $raw_file" >&2
  exit 1
}

# Construct full target path
full_output="$wiki_root/$output_path"

# Ensure target directory exists
mkdir -p "$(dirname "$full_output")"

# Step 1: Atomic write (temp file + rename, prevents partial writes on crash)
tmp_output="${full_output}.tmp.$$"
if ! cp "$content_file" "$tmp_output"; then
  rm -f "$tmp_output" 2>/dev/null || true
  echo "ERROR: Failed to write temporary file" >&2
  exit 1
fi

if ! mv "$tmp_output" "$full_output"; then
  rm -f "$tmp_output" 2>/dev/null || true
  echo "ERROR: Atomic rename failed" >&2
  exit 1
fi

# Step 2: Update cache
if ! bash "$SCRIPT_DIR/cache.sh" update "$raw_file" "$output_path"; then
  # Cache update failed → rollback: delete the written file
  rm -f "$full_output"
  echo "ERROR: Cache update failed, write has been rolled back" >&2
  exit 1
fi

echo "SUCCESS"
