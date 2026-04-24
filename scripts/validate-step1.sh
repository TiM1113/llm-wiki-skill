#!/bin/bash
# Validate ingest Step 1 JSON output format
# Usage: bash validate-step1.sh <json_file>
# Returns: 0 = format correct, 1 = format issues (triggers rollback)

JSON_FILE="$1"

# Parameter check
[ -z "$1" ] && { echo "ERROR: usage: validate-step1.sh <json_file>"; exit 1; }

# Check if jq is available (required dependency)
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found. Run: brew install jq"; exit 1; }

# Check if file exists
[ -f "$JSON_FILE" ] || { echo "ERROR: file not found: $JSON_FILE"; exit 1; }

# Check if valid JSON
jq empty "$JSON_FILE" 2>/dev/null || { echo "ERROR: invalid JSON format"; exit 1; }

# Check required fields exist and have correct types
jq -e '.entities | type == "array"' "$JSON_FILE" >/dev/null 2>&1 || { echo "ERROR: 'entities' must be an array"; exit 1; }
jq -e '.topics | type == "array"' "$JSON_FILE" >/dev/null 2>&1 || { echo "ERROR: 'topics' must be an array"; exit 1; }
jq -e '.connections | type == "array"' "$JSON_FILE" >/dev/null 2>&1 || { echo "ERROR: 'connections' must be an array"; exit 1; }
jq -e '.contradictions | type == "array"' "$JSON_FILE" >/dev/null 2>&1 || { echo "ERROR: 'contradictions' must be an array"; exit 1; }
jq -e '.new_vs_existing | type == "object"' "$JSON_FILE" >/dev/null 2>&1 || { echo "ERROR: 'new_vs_existing' must be an object"; exit 1; }

# Check required sub-fields of each entity
VALID_CONFIDENCE="EXTRACTED|INFERRED|AMBIGUOUS|UNVERIFIED"

ENTITY_COUNT=$(jq '.entities | length' "$JSON_FILE" 2>/dev/null)
if [ "$ENTITY_COUNT" -gt 0 ] 2>/dev/null; then
    # All entity items must be objects
    NON_OBJECT=$(jq '[.entities[] | select(type != "object")] | length' "$JSON_FILE" 2>/dev/null)
    if [ "$NON_OBJECT" -gt 0 ] 2>/dev/null; then
        echo "ERROR: $NON_OBJECT entity/entities are not JSON objects"
        exit 1
    fi

    # name, type, confidence must exist and be non-empty
    BAD_ENTITY_COUNT=$(jq '
        [.entities[] | select(
            (.name // "" | length) == 0 or
            (.type // "" | length) == 0 or
            (.confidence // "" | length) == 0
        )] | length
    ' "$JSON_FILE" 2>/dev/null)
    if [ "$BAD_ENTITY_COUNT" -gt 0 ] 2>/dev/null; then
        echo "ERROR: $BAD_ENTITY_COUNT entity/entities missing required fields (name/type/confidence)"
        exit 1
    fi

    # confidence value must be one of four valid values
    INVALID=$(jq -r '.entities[]? | (.confidence // "MISSING")' "$JSON_FILE" 2>/dev/null | \
        grep -v -E "^($VALID_CONFIDENCE)$" | head -3)
    if [ -n "$INVALID" ]; then
        echo "ERROR: invalid entity confidence value(s): $INVALID"
        echo "       Valid values: EXTRACTED | INFERRED | AMBIGUOUS | UNVERIFIED"
        exit 1
    fi

    # EXTRACTED and INFERRED must provide the evidence field
    NO_EVIDENCE_COUNT=$(jq '
        [.entities[] | select(
            (.confidence == "EXTRACTED" or .confidence == "INFERRED") and
            ((.evidence // "" | length) == 0)
        )] | length
    ' "$JSON_FILE" 2>/dev/null)
    if [ "$NO_EVIDENCE_COUNT" -gt 0 ] 2>/dev/null; then
        echo "WARN: $NO_EVIDENCE_COUNT entity/entities with EXTRACTED/INFERRED confidence missing 'evidence' field"
    fi
fi

# Check required sub-fields of each topic
TOPIC_COUNT=$(jq '.topics | length' "$JSON_FILE" 2>/dev/null)
if [ "$TOPIC_COUNT" -gt 0 ] 2>/dev/null; then
    NON_OBJECT=$(jq '[.topics[] | select(type != "object")] | length' "$JSON_FILE" 2>/dev/null)
    if [ "$NON_OBJECT" -gt 0 ] 2>/dev/null; then
        echo "ERROR: $NON_OBJECT topic(s) are not JSON objects"
        exit 1
    fi

    BAD_TOPIC_COUNT=$(jq '
        [.topics[] | select(
            (.name // "" | length) == 0
        )] | length
    ' "$JSON_FILE" 2>/dev/null)
    if [ "$BAD_TOPIC_COUNT" -gt 0 ] 2>/dev/null; then
        echo "ERROR: $BAD_TOPIC_COUNT topic(s) missing required 'name' field"
        exit 1
    fi
fi

# Check required sub-fields of each connection (from, to, confidence)
CONN_COUNT=$(jq '.connections | length' "$JSON_FILE" 2>/dev/null)
if [ "$CONN_COUNT" -gt 0 ] 2>/dev/null; then
    NON_OBJECT=$(jq '[.connections[] | select(type != "object")] | length' "$JSON_FILE" 2>/dev/null)
    if [ "$NON_OBJECT" -gt 0 ] 2>/dev/null; then
        echo "ERROR: $NON_OBJECT connection(s) are not JSON objects"
        exit 1
    fi

    BAD_CONN_COUNT=$(jq '
        [.connections[] | select(
            (.from // "" | length) == 0 or
            (.to // "" | length) == 0 or
            (.confidence // "" | length) == 0
        )] | length
    ' "$JSON_FILE" 2>/dev/null)
    if [ "$BAD_CONN_COUNT" -gt 0 ] 2>/dev/null; then
        echo "ERROR: $BAD_CONN_COUNT connection(s) missing required fields (from/to/confidence)"
        exit 1
    fi

    INVALID_CONN_CONF=$(jq -r '.connections[]? | (.confidence // "MISSING")' "$JSON_FILE" 2>/dev/null | \
        grep -v -E "^($VALID_CONFIDENCE)$" | head -3)
    if [ -n "$INVALID_CONN_CONF" ]; then
        echo "ERROR: invalid connection confidence value(s): $INVALID_CONN_CONF"
        echo "       Valid values: EXTRACTED | INFERRED | AMBIGUOUS | UNVERIFIED"
        exit 1
    fi

    # EXTRACTED and INFERRED connections must provide evidence
    NO_CONN_EVIDENCE=$(jq '
        [.connections[] | select(
            (.confidence == "EXTRACTED" or .confidence == "INFERRED") and
            ((.evidence // "" | length) == 0)
        )] | length
    ' "$JSON_FILE" 2>/dev/null)
    if [ "$NO_CONN_EVIDENCE" -gt 0 ] 2>/dev/null; then
        echo "WARN: $NO_CONN_EVIDENCE connection(s) with EXTRACTED/INFERRED confidence missing 'evidence' field"
    fi
fi

echo "OK: Step 1 JSON validation passed"
exit 0
