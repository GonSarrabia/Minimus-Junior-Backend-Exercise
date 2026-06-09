#!/bin/bash

set -e

IMAGE_NAME="dasel-image:latest-amd64"

echo "=== Starting Image Tests for $IMAGE_NAME ==="

# ---------------------------------------------------------
# Test 1: Sanity Check
# ---------------------------------------------------------
echo "[1/10] Checking if dasel is present and runnable..."
docker run --rm "$IMAGE_NAME" version
echo "✅ Test 1 Passed: Dasel is present and runnable."
echo ""

# ---------------------------------------------------------
# Test 2: Real Runtime Behavior
# ---------------------------------------------------------
echo "[2/10] Testing real runtime behavior (JSON query)..."
JSON_DATA='{"task": "Junior Backend", "status": "Success"}'

RESULT=$(echo "$JSON_DATA" | docker run -i --rm "$IMAGE_NAME" -i json 'status')
CLEAN_RESULT=$(echo "$RESULT" | tr -d '"' | tr -d '\n' | tr -d '\r')

if [ "$CLEAN_RESULT" = "Success" ]; then
    echo "✅ Test 2 Passed: Real behavior works. Expected 'Success', got '$CLEAN_RESULT'."
else
    echo "❌ Test 2 Failed: Expected 'Success', got '$CLEAN_RESULT'."
    exit 1
fi
echo ""

# ---------------------------------------------------------
# Test 3: Architecture Check
# ---------------------------------------------------------
echo "[3/10] Checking image architecture is Linux AMD64 (x86_64)..."
ARCH=$(docker inspect --format '{{.Architecture}}' "$IMAGE_NAME")
if [ "$ARCH" = "amd64" ]; then
    echo "✅ Test 3 Passed: Architecture is amd64 (Linux AMD64)."
else
    echo "❌ Test 3 Failed: Expected amd64, got '$ARCH'."
    exit 1
fi
echo ""

# ---------------------------------------------------------
# Test 4: CVE-2026-33320 — Budget Limit
# ---------------------------------------------------------
echo "[4/10] Testing CVE-2026-33320 patch (YAML Bomb / Expansion Budget Limit)..."

YAML_BOMB="
a: &a [\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\"]
b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a]
c: &c [*b,*b,*b,*b,*b,*b,*b,*b,*b]
d: &d [*c,*c,*c,*c,*c,*c,*c,*c,*c]
"

set +e
ERROR_OUTPUT=$(echo "$YAML_BOMB" | docker run -i --rm "$IMAGE_NAME" -i yaml 'd' 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ] && [[ "$ERROR_OUTPUT" == *"yaml expansion"* ]]; then
     echo "✅ Test 4 Passed: CVE patch verified. Dasel successfully blocked the YAML bomb."
     echo "   (Error received: $ERROR_OUTPUT)"
else
     echo "❌ Test 4 Failed: Dasel accepted the YAML bomb or returned an unexpected error."
     echo "   Exit code: $EXIT_CODE"
     echo "   Output: $ERROR_OUTPUT"
     exit 1
fi
echo ""

# ---------------------------------------------------------
# Test 5: Normal YAML Read (green path)
# ---------------------------------------------------------
echo "[5/10] Testing normal YAML parsing (valid document, no aliases)..."
YAML_DATA="project: dasel
lang: go"

RESULT=$(echo "$YAML_DATA" | docker run -i --rm "$IMAGE_NAME" -i yaml 'project')
CLEAN_RESULT=$(echo "$RESULT" | tr -d '"' | tr -d '\n' | tr -d '\r')

if [ "$CLEAN_RESULT" = "dasel" ]; then
    echo "✅ Test 5 Passed: YAML parsed correctly. Expected 'dasel', got '$CLEAN_RESULT'."
else
    echo "❌ Test 5 Failed: Expected 'dasel', got '$CLEAN_RESULT'."
    exit 1
fi
echo ""

# ---------------------------------------------------------
# Test 6: Nested JSON Path
# ---------------------------------------------------------
echo "[6/10] Testing nested JSON path query (dot notation)..."
JSON_DATA='{"build":{"tool":"melange","arch":"amd64"}}'

RESULT=$(echo "$JSON_DATA" | docker run -i --rm "$IMAGE_NAME" -i json 'build.tool')
CLEAN_RESULT=$(echo "$RESULT" | tr -d '"' | tr -d '\n' | tr -d '\r')

if [ "$CLEAN_RESULT" = "melange" ]; then
    echo "✅ Test 6 Passed: Nested path resolved correctly. Expected 'melange', got '$CLEAN_RESULT'."
else
    echo "❌ Test 6 Failed: Expected 'melange', got '$CLEAN_RESULT'."
    exit 1
fi
echo ""

# ---------------------------------------------------------
# Test 7: Array Element Access
# ---------------------------------------------------------
echo "[7/10] Testing array index selector..."
JSON_DATA='{"steps":["clone","patch","build"]}'

RESULT=$(echo "$JSON_DATA" | docker run -i --rm "$IMAGE_NAME" -i json 'steps[1]')
CLEAN_RESULT=$(echo "$RESULT" | tr -d '"' | tr -d '\n' | tr -d '\r')

if [ "$CLEAN_RESULT" = "patch" ]; then
    echo "✅ Test 7 Passed: Array index resolved correctly. Expected 'patch', got '$CLEAN_RESULT'."
else
    echo "❌ Test 7 Failed: Expected 'patch', got '$CLEAN_RESULT'."
    exit 1
fi
echo ""

# ---------------------------------------------------------
# Test 8: TOML Format
# ---------------------------------------------------------
echo "[8/10] Testing TOML input format..."
TOML_DATA="[package]
name = \"dasel\""

RESULT=$(echo "$TOML_DATA" | docker run -i --rm "$IMAGE_NAME" -i toml 'package.name')
CLEAN_RESULT=$(echo "$RESULT" | tr -d "\"'" | tr -d '\n' | tr -d '\r')

if [ "$CLEAN_RESULT" = "dasel" ]; then
    echo "✅ Test 8 Passed: TOML parsed correctly. Expected 'dasel', got '$CLEAN_RESULT'."
else
    echo "❌ Test 8 Failed: Expected 'dasel', got '$CLEAN_RESULT'."
    exit 1
fi
echo ""

# ---------------------------------------------------------
# Test 9: YAML Integer Value
# ---------------------------------------------------------
echo "[9/10] Testing YAML integer value parsing..."
YAML_DATA="count: 42
label: done"

RESULT=$(echo "$YAML_DATA" | docker run -i --rm "$IMAGE_NAME" -i yaml 'count')
CLEAN_RESULT=$(echo "$RESULT" | tr -d '"' | tr -d '\n' | tr -d '\r')

if [ "$CLEAN_RESULT" = "42" ]; then
    echo "✅ Test 9 Passed: YAML integer parsed correctly. Expected '42', got '$CLEAN_RESULT'."
else
    echo "❌ Test 9 Failed: Expected '42', got '$CLEAN_RESULT'."
    exit 1
fi
echo ""

# ---------------------------------------------------------
# Test 10: Invalid Input Rejection
# ---------------------------------------------------------
echo "[10/10] Testing rejection of malformed JSON input..."
BAD_JSON='{not: valid: json'

set +e
docker run -i --rm "$IMAGE_NAME" -i json 'key' <<< "$BAD_JSON" > /dev/null 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "✅ Test 10 Passed: Malformed JSON correctly rejected (exit code $EXIT_CODE)."
else
    echo "❌ Test 10 Failed: Dasel accepted malformed JSON input."
    exit 1
fi
echo ""

echo "🎉 All tests completed successfully!"
