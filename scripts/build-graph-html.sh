#!/bin/bash
# build-graph-html.sh — assemble interactive knowledge graph HTML (wash watercolor card style)
#
# Usage:
#   bash scripts/build-graph-html.sh <wiki_root>
#
# Prerequisite: run build-graph-data.sh first to generate wiki/graph-data.json
#
# Behavior:
#   1. Read wash template header/footer
#   2. Replace brand bar placeholders (__WIKI_TITLE__ / __NODE_COUNT__ / __EDGE_COUNT__ / __BUILD_DATE__)
#   3. Embed wiki/graph-data.json into <script id="graph-data"> block
#      (pre-escape </script> to <\/script> to prevent JSON strings containing </script>
#       from prematurely closing the tag — standard JSON-in-HTML practice)
#   4. Append footer
#   5. Copy vendor assets required by wash to the HTML output directory
#
# Exit code: 0 success; 1 dependency/file missing/argument error

set -eu

print_usage() {
  cat <<'EOF'
Usage:
  bash scripts/build-graph-html.sh <wiki_root>

Example:
  bash scripts/build-graph-html.sh /path/to/wiki-root
EOF
}

die() {
  echo "ERROR: $1" >&2
  exit 1
}

ensure_file() {
  local file="$1"
  local label="${2:-file}"
  [ -f "$file" ] || {
    echo "ERROR: ${label} not found: $file" >&2
    echo "       Reinstalling the skill can fix this (bash install.sh --platform claude)" >&2
    exit 1
  }
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

[ "$#" -eq 1 ] || {
  print_usage >&2
  exit 1
}

WIKI_ROOT="$1"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is not installed. Run: brew install jq" >&2
  exit 1
}

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$SKILL_DIR/templates"
DEPS_DIR="$SKILL_DIR/deps"
DATA="$WIKI_ROOT/wiki/graph-data.json"

[ -f "$DATA" ] || {
  echo "ERROR: $DATA not found" >&2
  echo "       Please run build-graph-data.sh first to generate graph data" >&2
  exit 1
}

HEADER="$TEMPLATES_DIR/graph-styles/wash/header.html"
FOOTER="$TEMPLATES_DIR/graph-styles/wash/footer.html"
OUTPUT="$WIKI_ROOT/wiki/knowledge-graph.html"

ensure_file "$HEADER" "template"
ensure_file "$FOOTER" "template"

WIKI_TITLE=$(jq -r '.meta.wiki_title // "Wiki"' "$DATA")
NODE_COUNT=$(jq -r '.meta.total_nodes // 0' "$DATA")
EDGE_COUNT=$(jq -r '.meta.total_edges // 0' "$DATA")
BUILD_DATE=$(jq -r '.meta.build_date // ""' "$DATA")
BUILD_DATE_SHORT="${BUILD_DATE:0:10}"
[ -n "$BUILD_DATE_SHORT" ] || BUILD_DATE_SHORT="Unknown"

ASSET_SPECS=(
  "$DEPS_DIR/d3.min.js|d3.min.js"
  "$DEPS_DIR/rough.min.js|rough.min.js"
  "$DEPS_DIR/marked.min.js|marked.min.js"
  "$DEPS_DIR/purify.min.js|purify.min.js"
  "$DEPS_DIR/LICENSE-d3.txt|LICENSE-d3.txt"
  "$DEPS_DIR/LICENSE-roughjs.txt|LICENSE-roughjs.txt"
  "$DEPS_DIR/LICENSE-marked.txt|LICENSE-marked.txt"
  "$DEPS_DIR/LICENSE-purify.txt|LICENSE-purify.txt"
  "$TEMPLATES_DIR/graph-styles/wash/graph-wash-helpers.js|graph-wash-helpers.js"
  "$TEMPLATES_DIR/graph-styles/wash/graph-wash.js|graph-wash.js"
)

output_dir="$(dirname "$OUTPUT")"
mkdir -p "$output_dir"
output_tmp="$OUTPUT.partial"
output_next="$OUTPUT.next"
rm -f "$output_tmp" "$output_next"

# Replace placeholders
WIKI_TITLE_VAL="$WIKI_TITLE" \
NODE_COUNT_VAL="$NODE_COUNT" \
EDGE_COUNT_VAL="$EDGE_COUNT" \
BUILD_DATE_VAL="$BUILD_DATE_SHORT" \
perl -pe '
  s/__WIKI_TITLE__/$ENV{WIKI_TITLE_VAL}/g;
  s/__NODE_COUNT__/$ENV{NODE_COUNT_VAL}/g;
  s/__EDGE_COUNT__/$ENV{EDGE_COUNT_VAL}/g;
  s/__BUILD_DATE__/$ENV{BUILD_DATE_VAL}/g;
' "$HEADER" > "$output_tmp"

# Embed graph-data.json, escaping </script>
perl -pe 's|</script>|<\\/script>|gi' "$DATA" >> "$output_tmp"

cat "$FOOTER" >> "$output_tmp"

# Copy vendor assets first, replace HTML only after all succeed
for spec in "${ASSET_SPECS[@]}"; do
  src="${spec%%|*}"
  name="${spec#*|}"
  ensure_file "$src" "vendor"
  cp "$src" "$output_dir/$name"
done

mv "$output_tmp" "$output_next"
mv "$output_next" "$OUTPUT"

output_size=$(wc -c < "$OUTPUT" | tr -d ' ')
output_kb=$((output_size / 1024))

echo "Interactive graph generated:"
echo "  - $OUTPUT (${output_kb} KB)"
echo "  Nodes: $NODE_COUNT | Edges: $EDGE_COUNT"
echo ""
echo "How to view:"
echo "  1. Double-click $OUTPUT"
echo "     (Chrome / Firefox recommended; Safari may block local scripts due to file:// policy)"
echo "  2. If the browser blocks local scripts, run in $output_dir:"
echo "       python3 -m http.server 8000"
echo "     Then visit:"
echo "       http://localhost:8000/$(basename "$OUTPUT")"
