#!/bin/bash

# עוצר את הסקריפט במקרה של שגיאה בלתי צפויה
set -e

# הגדרת שם האימג' במדויק כפי שנטען מקומית (עומד בדרישת סיומת amd64)
IMAGE_NAME="dasel-image:latest-amd64"

echo "=== Starting Image Tests for $IMAGE_NAME ==="

# ---------------------------------------------------------
# Test 1: Sanity Check
# ---------------------------------------------------------
echo "[1/3] Checking if dasel is present and runnable..."
docker run --rm "$IMAGE_NAME" version
echo "✅ Test 1 Passed: Dasel is present and runnable."
echo ""

# ---------------------------------------------------------
# Test 2: Real Runtime Behavior
# ---------------------------------------------------------
echo "[2/3] Testing real runtime behavior (JSON query)..."
JSON_DATA='{"task": "Junior Backend", "status": "Success"}'

# שימוש ב-stdin כדי להעביר את הנתונים ל-dasel ולשלוף את הערך של 'status'
RESULT=$(echo "$JSON_DATA" | docker run -i --rm "$IMAGE_NAME" -i json 'status')

# ניקוי התוצאה ממרכאות (במידה ו-dasel מחזיר אותן)
CLEAN_RESULT=$(echo "$RESULT" | tr -d '"' | tr -d '\n' | tr -d '\r')

if [ "$CLEAN_RESULT" = "Success" ]; then
    echo "✅ Test 2 Passed: Real behavior works. Expected 'Success', got '$CLEAN_RESULT'."
else
    echo "❌ Test 2 Failed: Expected 'Success', got '$CLEAN_RESULT'."
    exit 1
fi
echo ""

# ---------------------------------------------------------
# Test 3: CVE-2026-33320 Patch Verification
# ---------------------------------------------------------
echo "[3/3] Testing CVE-2026-33320 patch (YAML Bomb / Expansion Limit)..."

# יצירת "פצצת YAML" קטנה שמנצלת Alias כדי ליצור עומק רב
YAML_BOMB="
a: &a [\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\",\"lol\"]
b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a]
c: &c [*b,*b,*b,*b,*b,*b,*b,*b,*b]
d: &d [*c,*c,*c,*c,*c,*c,*c,*c,*c]
"

# אנחנו מצפים שהפקודה הזו תיכשל, לכן נכבה זמנית את set -e
set +e
ERROR_OUTPUT=$(echo "$YAML_BOMB" | docker run -i --rm "$IMAGE_NAME" -i yaml 'd' 2>&1)
EXIT_CODE=$?
set -e

# בדיקה אם הפקודה נכשלה ואם הודעת השגיאה מכילה את המילים מהפאטץ' שהוספנו
if [ $EXIT_CODE -ne 0 ] && [[ "$ERROR_OUTPUT" == *"yaml expansion"* ]]; then
     echo "✅ Test 3 Passed: CVE patch verified. Dasel successfully blocked the YAML bomb."
     echo "   (Error received: $ERROR_OUTPUT)"
else
     echo "❌ Test 3 Failed: Dasel accepted the YAML bomb or returned an unexpected error."
     echo "   Exit code: $EXIT_CODE"
     echo "   Output: $ERROR_OUTPUT"
     exit 1
fi
echo ""

echo "🎉 All tests completed successfully!"