#!/bin/bash
# lint-output.regression-1.sh — verify lint output structure (excluding time and path)
set -eu

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$SKILL_DIR/tests/fixtures/lint-sample-wiki"
EXPECTED="$SKILL_DIR/tests/expected/lint-output.txt"

if [ ! -f "$EXPECTED" ]; then
  echo "FAIL: expected output not found: $EXPECTED"
  exit 1
fi

# Run lint and capture output
ACTUAL=$(bash "$SKILL_DIR/scripts/lint-runner.sh" "$FIXTURE" 2>/dev/null)

# Stabilize: replace time with placeholder, replace absolute paths with relative paths
ACTUAL_STABLE=$(echo "$ACTUAL" | \
  sed -E 's/Time: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}/Time: YYYY-MM-DD HH:MM/' | \
  sed "s|$FIXTURE|tests/fixtures/lint-sample-wiki|g")

EXPECTED_STABLE=$(cat "$EXPECTED")

if [ "$ACTUAL_STABLE" = "$EXPECTED_STABLE" ]; then
  echo "PASS: lint output regression"
  exit 0
else
  echo "FAIL: lint output does not match expected"
  echo "--- diff (actual vs expected) ---"
  diff <(echo "$ACTUAL_STABLE") <(echo "$EXPECTED_STABLE") || true
  exit 1
fi
