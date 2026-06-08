#!/bin/bash

set -e

IMAGE_NAME="dasel-image:latest-amd64"

echo "=== Starting Image Tests for $IMAGE_NAME ==="

# ---------------------------------------------------------
# Test 1: Sanity Check
# ---------------------------------------------------------
echo "[1/4] Checking if dasel is present and runnable..."
docker run --rm "$IMAGE_NAME" version
echo "✅ Test 1 Passed: Dasel is present and runnable."
echo ""

# ---------------------------------------------------------
# Test 2: Real Runtime Behavior
# ---------------------------------------------------------
echo "[2/4] Testing real runtime behavior (JSON query)..."
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
echo "[3/4] Checking image architecture is Linux AMD64 (x86_64)..."
ARCH=$(docker run --rm --entrypoint uname "$IMAGE_NAME" -m)
if [ "$ARCH" = "x86_64" ]; then
    echo "✅ Test 3 Passed: Architecture is x86_64 (Linux AMD64)."
else
    echo "❌ Test 3 Failed: Expected x86_64, got '$ARCH'."
    exit 1
fi
echo ""

# ---------------------------------------------------------
# Test 4: CVE-2026-33320 Patch Verification
# ---------------------------------------------------------
echo "[4/4] Testing CVE-2026-33320 patch (YAML Bomb / Expansion Limit)..."

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

echo "🎉 All tests completed successfully!"