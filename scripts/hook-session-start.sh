#!/bin/bash
# SessionStart hook: inject wiki context at session start (fires once)

set -euo pipefail

WIKI_PATH=""

if [ -f "$HOME/.llm-wiki-path" ]; then
  WIKI_PATH="$(cat "$HOME/.llm-wiki-path")"
fi

if [ -z "$WIKI_PATH" ] && [ -f .wiki-schema.md ]; then
  WIKI_PATH="$(pwd)"
fi

if [ -z "$WIKI_PATH" ] || [ ! -f "$WIKI_PATH/.wiki-schema.md" ]; then
  printf '{}\n'
  exit 0
fi

python3 - "$WIKI_PATH" <<'PY'
import json
import os
import sys

wiki_path = os.path.realpath(sys.argv[1])
message = f"[llm-wiki] Wiki detected: {wiki_path}/index.md — prioritize wiki content for context when answering questions"

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": message,
    }
}, ensure_ascii=False))
PY
