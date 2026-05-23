#!/bin/bash
# Practicum CLI — Day 5 Capstone Test
# Tests the student's monitor.sh script

STUDENT_SCRIPT="$1"
if [ ! -f "$STUDENT_SCRIPT" ]; then
    echo "  ❌ Script not found: $STUDENT_SCRIPT"
    echo "  Create monitor.sh in your current directory first."
    exit 1
fi

SCORE=0
TOTAL=5
TEST_DIR=$(mktemp -d)

# Create test environment
cat > "$TEST_DIR/test.log" << LOG
2026-04-15 10:00:00 INFO: system started
2026-04-15 10:01:00 ERROR: disk full on /dev/sdb1
2026-04-15 10:02:00 WARNING: low memory (512MB free)
2026-04-15 10:03:00 ERROR: connection refused to db-server
2026-04-15 10:04:00 INFO: backup completed successfully
2026-04-15 10:05:00 ERROR: permission denied on /etc/shadow
LOG

# Run student script
OUTPUT=$(bash "$STUDENT_SCRIPT" "$TEST_DIR/test.log" 2>&1) || true

# Test 1: Script produces output
if [ -n "$OUTPUT" ]; then
    SCORE=$((SCORE + 1))
    echo "  ✅ Test 1: Script produces output"
else
    echo "  ❌ Test 1: Script produced no output"
fi

# Test 2: Output contains date
if echo "$OUTPUT" | grep -q "$(date +%Y)" 2>/dev/null; then
    SCORE=$((SCORE + 1))
    echo "  ✅ Test 2: Report includes date"
else
    echo "  ❌ Test 2: Report missing date"
fi

# Test 3: Script counts errors (should find 3)
if echo "$OUTPUT" | grep -qi "3.*error\|error.*3" 2>/dev/null; then
    SCORE=$((SCORE + 1))
    echo "  ✅ Test 3: Correctly counted 3 errors"
else
    echo "  ❌ Test 3: Did not count errors correctly (expected 3)"
fi

# Test 4: Script mentions disk usage
if echo "$OUTPUT" | grep -qi "disk" 2>/dev/null; then
    SCORE=$((SCORE + 1))
    echo "  ✅ Test 4: Reports disk usage"
else
    echo "  ❌ Test 4: No disk usage reporting"
fi

# Test 5: Script has structured report format
if echo "$OUTPUT" | grep -qi "report\|status\|summary" 2>/dev/null; then
    SCORE=$((SCORE + 1))
    echo "  ✅ Test 5: Structured report format"
else
    echo "  ❌ Test 5: No structured report format"
fi

# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "  ========================================="
echo "  Score: $SCORE / $TOTAL"
if [ "$SCORE" -ge 4 ]; then
    echo "  ✅ PASSED! (4/$TOTAL required)"
    echo "  ========================================="
    exit 0
else
    echo "  ❌ FAILED. Need at least 4/$TOTAL."
    echo "  Review Days 1-4 and try again."
    echo "  ========================================="
    exit 1
fi
