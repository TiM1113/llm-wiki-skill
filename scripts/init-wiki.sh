#!/bin/bash
# llm-wiki initialization script
# Automatically creates the wiki directory structure
# Usage: bash init-wiki.sh <wiki_path> <topic>

set -e

WIKI_ROOT="${1:-$HOME/Documents/my-wiki}"
TOPIC="${2:-My Wiki}"
LANGUAGE="${3:-English}"
DATE=$(date +%Y-%m-%d)
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Safe template variable substitution function (uses perl instead of sed to avoid issues with CJK chars/spaces/special chars)
replace_vars() {
    local input_file="$1"
    local output_file="$2"
    TOPIC_VALUE="$TOPIC" \
    DATE_VALUE="$DATE" \
    WIKI_ROOT_VALUE="$WIKI_ROOT" \
    LANGUAGE_VALUE="$LANGUAGE" \
    perl -pe '
        s/\{\{TOPIC\}\}/$ENV{TOPIC_VALUE}/g;
        s/\{\{DATE\}\}/$ENV{DATE_VALUE}/g;
        s/\{\{WIKI_ROOT\}\}/$ENV{WIKI_ROOT_VALUE}/g;
        s/\{\{LANGUAGE\}\}/$ENV{LANGUAGE_VALUE}/g;
    ' "$input_file" > "$output_file"
}

echo "Creating wiki..."
echo "   Path: $WIKI_ROOT"
echo "   Topic: $TOPIC"
echo "   Language: $LANGUAGE"
echo ""

# Create directory structure
mkdir -p "$WIKI_ROOT"/raw/{articles,tweets,xiaohongshu,pdfs,notes,assets}
mkdir -p "$WIKI_ROOT"/wiki/{entities,topics,sources,comparisons,synthesis,synthesis/sessions,queries}

cat > "$WIKI_ROOT/.gitignore" <<'EOF'
.wiki-tmp/
EOF

echo "[Done] Directory structure created"

# Generate files from templates
replace_vars "$SKILL_DIR/templates/schema-template.md" "$WIKI_ROOT/.wiki-schema.md"
echo "[Done] Schema file generated"

replace_vars "$SKILL_DIR/templates/index-template.md" "$WIKI_ROOT/index.md"
echo "[Done] Index file generated"

replace_vars "$SKILL_DIR/templates/log-template.md" "$WIKI_ROOT/log.md"
echo "[Done] Log file generated"

replace_vars "$SKILL_DIR/templates/overview-template.md" "$WIKI_ROOT/wiki/overview.md"
echo "[Done] Overview file generated"

if [ "$LANGUAGE" = "English" ]; then
    replace_vars "$SKILL_DIR/templates/purpose-en-template.md" "$WIKI_ROOT/purpose.md"
else
    replace_vars "$SKILL_DIR/templates/purpose-template.md" "$WIKI_ROOT/purpose.md"
fi
echo "[Done] Purpose file generated"

cat > "$WIKI_ROOT/.wiki-cache.json" <<'EOF'
{
  "version": 1,
  "entries": {}
}
EOF
echo "[Done] Cache file generated"

echo ""
echo "Wiki creation complete!"
echo ""
echo "Directory structure:"
echo "   $WIKI_ROOT/"
echo "   ├── raw/        (raw materials)"
echo "   │   ├── articles/     Web articles"
echo "   │   ├── tweets/       X/Twitter"
echo "   │   ├── xiaohongshu/  Xiaohongshu"
echo "   │   ├── pdfs/         PDF"
echo "   │   ├── notes/        Notes"
echo "   │   └── assets/       Images and attachments"
echo "   ├── wiki/       (knowledge base)"
echo "   ├── index.md    (index)"
echo "   ├── log.md      (log)"
echo "   ├── purpose.md  (research purpose)"
echo "   ├── .wiki-cache.json (cache)"
echo "   └── .wiki-schema.md (config)"
echo ""
echo "Next step: give the agent a link or file to start building your wiki!"
