#!/bin/bash
# lint-runner.sh — wiki mechanical health check
# Usage: bash scripts/lint-runner.sh <wiki_root>
# Output: structured text report (for AI follow-up analysis)
# Exit code: 0 = completed, 1 = script error (path not found, incomplete wiki structure)

set -u
shopt -s nullglob

WIKI_ROOT="${1:-.}"
WIKI_DIR="$WIKI_ROOT/wiki"
INDEX_FILE="$WIKI_ROOT/index.md"

if [ ! -d "$WIKI_DIR" ]; then
  echo "ERROR: wiki directory not found: $WIKI_DIR" >&2
  echo "       Please verify the path is correct, or run the init workflow to initialize the wiki first." >&2
  exit 1
fi
if [ ! -f "$INDEX_FILE" ]; then
  echo "ERROR: index.md not found: $INDEX_FILE" >&2
  exit 1
fi

echo "=== llm-wiki lint report ==="
echo "Time: $(date '+%Y-%m-%d %H:%M')"
echo "Scan path: $WIKI_DIR"
echo ""

# Check 1: Orphan pages
# Definition: pages under entities/, topics/, sources/ that are not referenced by any other wiki page via [[name]]
echo "--- Orphan pages (not referenced by any other page) ---"
_ORPHANS=0
for _subdir in entities topics sources; do
  for f in "$WIKI_DIR"/$_subdir/*.md; do
    [ -f "$f" ] || continue
    BASENAME=$(basename "$f" .md)
    if ! grep -rlF "[[$BASENAME]]" "$WIKI_DIR" 2>/dev/null | grep -vxF "$f" | grep -q .; then
      echo "  Orphan: $_subdir/$BASENAME"
      _ORPHANS=$((_ORPHANS + 1))
    fi
  done
done
[ "$_ORPHANS" -eq 0 ] && echo "  (no orphan pages)"
echo ""

# Check 2: Broken links
# Definition: pages under wiki/ contain [[X]] links (supports [[X|alias]] syntax), but X.md is not found in any wiki/ subdirectory
echo "--- Broken links (linked but non-existent pages) ---"
_TMP_BROKEN=$(mktemp)
grep -rohE "\[\[[^]]+\]\]" "$WIKI_DIR" 2>/dev/null | \
  sed -e 's/\[\[//g' -e 's/\]\]//g' -e 's/|.*//' | \
  sort -u | \
  while read -r LINK; do
    [ -z "$LINK" ] && continue
    if ! find "$WIKI_DIR" -name "$LINK.md" 2>/dev/null | grep -q .; then
      echo "  Broken: [[$LINK]]"
      echo "$LINK" >> "$_TMP_BROKEN"
    fi
  done
if [ ! -s "$_TMP_BROKEN" ]; then
  echo "  (no broken links)"
fi
rm -f "$_TMP_BROKEN"
echo ""

# Check 3: Index consistency
# Definition: index.md has [[X]] entries (alias stripped), but X.md is not found in any wiki/ subdirectory
echo "--- Index consistency (index.md entry exists but file is missing) ---"
_TMP_MISSING=$(mktemp)
grep -ohE "\[\[[^]]+\]\]" "$INDEX_FILE" 2>/dev/null | \
  sed -e 's/\[\[//g' -e 's/\]\]//g' -e 's/|.*//' | \
  sort -u | \
  while read -r ENTRY; do
    [ -z "$ENTRY" ] && continue
    if ! find "$WIKI_DIR" -name "$ENTRY.md" 2>/dev/null | grep -q .; then
      echo "  In index but file missing: $ENTRY"
      echo "$ENTRY" >> "$_TMP_MISSING"
    fi
  done
if [ ! -s "$_TMP_MISSING" ]; then
  echo "  (index and files are consistent)"
fi
rm -f "$_TMP_MISSING"
echo ""

# Check 4: Reverse index consistency
# Definition: pages that exist under wiki/ but are not listed in index.md via [[page_name]]
# Excludes derived pages (queries/, synthesis/sessions/)
echo "--- Reverse index consistency (file exists but not listed in index.md) ---"
_TMP_UNLISTED=$(mktemp)
for _subdir in entities topics sources comparisons synthesis; do
  for f in "$WIKI_DIR"/$_subdir/*.md; do
    [ -f "$f" ] || continue
    BASENAME=$(basename "$f" .md)
    # Skip derived pages
    case "$f" in
      */queries/*|*/sessions/*) continue ;;
    esac
    if ! grep -qF "[[$BASENAME]]" "$INDEX_FILE" 2>/dev/null; then
      echo "  Unlisted: $_subdir/$BASENAME"
      echo "$BASENAME" >> "$_TMP_UNLISTED"
    fi
  done
done
if [ ! -s "$_TMP_UNLISTED" ]; then
  echo "  (all pages are listed)"
fi
rm -f "$_TMP_UNLISTED"
echo ""

# Check 5: Image asset consistency
# Definition: files listed in image_paths in source page frontmatter are checked for actual existence in the wiki
# Supports both block list format and inline array format
echo "--- Image asset consistency (image_paths declared but file missing) ---"
_IMG_ISSUES=0
for f in "$WIKI_DIR"/sources/*.md; do
  [ -f "$f" ] || continue
  _BASENAME=$(basename "$f" .md)
  # Extract image_paths values from frontmatter
  _IN_FM=false
  _IN_IMG=false
  _INLINE_VAL=""
  while IFS= read -r line; do
    case "$line" in
      "---")
        if [ "$_IN_FM" = true ]; then break; fi
        _IN_FM=true
        continue
        ;;
    esac
    [ "$_IN_FM" = true ] || continue
    case "$line" in
      image_paths:*)
        # Check for inline value (e.g., image_paths: ["a.png", "b.jpg"])
        _INLINE_VAL=$(echo "$line" | sed 's/^image_paths:[[:space:]]*//')
        if [ -n "$_INLINE_VAL" ] && [ "$_INLINE_VAL" != "[]" ]; then
          # Parse inline array: strip [], split by comma
          echo "$_INLINE_VAL" | tr -d '[]' | tr ',' '\n' | while IFS= read -r _ITEM; do
            _PATH=$(echo "$_ITEM" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '"' | tr -d "'")
            [ -z "$_PATH" ] && continue
            if [ ! -f "$WIKI_ROOT/$_PATH" ]; then
              echo "  Missing: $_BASENAME → $_PATH"
            fi
          done
          _INLINE_COUNT=$(echo "$_INLINE_VAL" | tr -d '[]' | tr ',' '\n' | while IFS= read -r _ITEM; do
            _P=$(echo "$_ITEM" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '"' | tr -d "'")
            [ -z "$_P" ] && continue
            [ ! -f "$WIKI_ROOT/$_P" ] && echo "x"
          done | wc -l | tr -d ' ')
          _IMG_ISSUES=$((_IMG_ISSUES + _INLINE_COUNT))
          _IN_IMG=false
        else
          _IN_IMG=true
        fi
        continue
        ;;
      "  - "*)
        if [ "$_IN_IMG" = true ]; then
          _PATH=$(echo "$line" | sed 's/^[[:space:]]*- //' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '"' | tr -d "'")
          [ -z "$_PATH" ] && continue
          if [ ! -f "$WIKI_ROOT/$_PATH" ]; then
            echo "  Missing: $_BASENAME → $_PATH"
            _IMG_ISSUES=$((_IMG_ISSUES + 1))
          fi
        fi
        ;;
      *) _IN_IMG=false ;;
    esac
  done < "$f"
done
[ "$_IMG_ISSUES" -eq 0 ] && echo "  (no missing images)"
echo ""

# Check 6: Source-signal coverage
echo "--- Source-signal coverage ---"
_COVERAGE_SCRIPT="$(cd "$(dirname "$0")" && pwd)/source-signal-coverage.js"
if [ -f "$_COVERAGE_SCRIPT" ] && command -v node >/dev/null 2>&1; then
  _COVERAGE_JSON=$(node "$_COVERAGE_SCRIPT" "$WIKI_ROOT" 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$_COVERAGE_JSON" ]; then
    node -e '
      const data = JSON.parse(require("fs").readFileSync("/dev/stdin", "utf8"));
      const s = data.summary;
      console.log("  Eligible: " + s.ok);
      console.log("  Missing sources field: " + s.missing_sources);
      console.log("  Empty sources: " + s.empty_sources);
      console.log("  Invalid sources format: " + s.invalid_sources);
      console.log("  Not applicable: " + s.not_applicable);
      const issues = data.pages.filter(p => p.reason !== "ok" && p.reason !== "not_applicable");
      if (issues.length > 0) {
        const byReason = { missing_sources: [], empty_sources: [], invalid_sources: [] };
        for (const p of issues) { if (byReason[p.reason]) byReason[p.reason].push(p.path); }
        for (const [reason, paths] of Object.entries(byReason)) {
          if (paths.length === 0) continue;
          const label = { missing_sources: "Missing sources field", empty_sources: "Empty sources", invalid_sources: "Invalid sources format" }[reason];
          console.log("");
          console.log("  " + label + "：");
          for (const p of paths) console.log("  - " + p);
        }
      }
    ' <<< "$_COVERAGE_JSON"
  else
    echo "  (coverage script execution failed, skipping coverage check)"
  fi
else
  echo "  (coverage script or node not available, skipping coverage check)"
fi
echo ""

echo "=== Mechanical checks complete. Contradiction detection, cross-referencing, and confidence spot-checks will be handled by AI ==="
exit 0
