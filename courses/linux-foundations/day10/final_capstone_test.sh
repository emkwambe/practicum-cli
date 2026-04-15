#!/bin/bash
# Final Capstone Grader — checks all 5 deliverables
score=0
total=5

echo ""
echo "==========================================="
echo "  📝 Final Capstone: The Sysadmin Shift"
echo "==========================================="
echo ""

# Phase 1: Morning Report
if [ -f "/tmp/morning_report.txt" ] && [ -s "/tmp/morning_report.txt" ]; then
    echo "  ✅ Phase 1: morning_report.txt found ($(wc -l < /tmp/morning_report.txt) lines)"
    score=$((score + 20))
else
    echo "  ❌ Phase 1: /tmp/morning_report.txt missing or empty"
fi

# Phase 2: Fix Report
if [ -f "/tmp/fix_report.txt" ] && [ -s "/tmp/fix_report.txt" ]; then
    echo "  ✅ Phase 2: fix_report.txt found ($(wc -l < /tmp/fix_report.txt) lines)"
    score=$((score + 20))
else
    echo "  ❌ Phase 2: /tmp/fix_report.txt missing or empty"
fi

# Phase 3: Shared docs directory (check if it was created)
if [ -f "/tmp/morning_report.txt" ]; then
    # If they documented creating the user/group, give credit
    if grep -qi "intern\|readonly\|shared" /tmp/morning_report.txt /tmp/fix_report.txt /tmp/shift_handoff.txt 2>/dev/null; then
        echo "  ✅ Phase 3: Security setup documented"
        score=$((score + 20))
    else
        echo "  ⚠️  Phase 3: Security setup not clearly documented (partial credit)"
        score=$((score + 10))
    fi
else
    echo "  ❌ Phase 3: No evidence of security setup"
fi

# Phase 4: Automation script
if [ -f "/tmp/daily_check.sh" ] && [ -x "/tmp/daily_check.sh" ]; then
    if [ -f "/tmp/cron_entry.txt" ] && [ -s "/tmp/cron_entry.txt" ]; then
        echo "  ✅ Phase 4: daily_check.sh (executable) + cron_entry.txt"
        score=$((score + 20))
    else
        echo "  ⚠️  Phase 4: daily_check.sh exists but cron_entry.txt missing"
        score=$((score + 10))
    fi
else
    echo "  ❌ Phase 4: /tmp/daily_check.sh missing or not executable"
fi

# Phase 5: Shift handoff
if [ -f "/tmp/shift_handoff.txt" ] && [ -s "/tmp/shift_handoff.txt" ]; then
    local_lines=$(wc -l < /tmp/shift_handoff.txt)
    if [ "$local_lines" -ge 5 ]; then
        echo "  ✅ Phase 5: shift_handoff.txt ($local_lines lines — thorough)"
        score=$((score + 20))
    else
        echo "  ⚠️  Phase 5: shift_handoff.txt is brief ($local_lines lines)"
        score=$((score + 10))
    fi
else
    echo "  ❌ Phase 5: /tmp/shift_handoff.txt missing or empty"
fi

echo ""
echo "==========================================="
echo "  Final Score: $score / 100"
echo ""

if [ "$score" -ge 80 ]; then
    echo "  🏆 DISTINCTION — Outstanding work!"
elif [ "$score" -ge 60 ]; then
    echo "  ✅ PASSED — You are job-ready."
else
    echo "  ❌ Not yet passing (need 60+). Review and try again."
fi

echo "==========================================="
echo ""

[ "$score" -ge 60 ]
