#!/bin/bash
# Assessment 2 Grader — checks secure.sh, diagnose.sh, health.sh
score=0
total=3

echo "=== Assessment 2: Grading ==="
echo ""

# Task 1: secure.sh
if [ -f "secure.sh" ] && [ -x "secure.sh" ]; then
    if grep -q "groupadd\|addgroup" secure.sh && grep -q "chmod" secure.sh && grep -q "mkdir" secure.sh; then
        echo "  ✅ Task 1 (secure.sh): PASS — group, directory, and permissions"
        score=$((score + 1))
    else
        echo "  ❌ Task 1 (secure.sh): Missing groupadd, mkdir, or chmod"
    fi
else
    echo "  ❌ Task 1 (secure.sh): Not found or not executable"
fi

# Task 2: diagnose.sh
if [ -f "diagnose.sh" ] && [ -x "diagnose.sh" ]; then
    if grep -q "ip\|hostname\|ifconfig" diagnose.sh && grep -q "ss\|netstat" diagnose.sh; then
        echo "  ✅ Task 2 (diagnose.sh): PASS — network checks present"
        score=$((score + 1))
    else
        echo "  ❌ Task 2 (diagnose.sh): Missing ip/hostname or ss/netstat checks"
    fi
else
    echo "  ❌ Task 2 (diagnose.sh): Not found or not executable"
fi

# Task 3: health.sh
if [ -f "health.sh" ] && [ -x "health.sh" ]; then
    if grep -q "systemctl\|journalctl" health.sh && grep -q "df\|du" health.sh && grep -q "ps" health.sh; then
        echo "  ✅ Task 3 (health.sh): PASS — service, disk, and process checks"
        score=$((score + 1))
    else
        echo "  ❌ Task 3 (health.sh): Missing systemctl, df, or ps checks"
    fi
else
    echo "  ❌ Task 3 (health.sh): Not found or not executable"
fi

echo ""
echo "  Score: $score / $total"

if [ "$score" -ge 2 ]; then
    echo "  ✅ ASSESSMENT 2 PASSED!"
    exit 0
else
    echo "  ❌ Need at least 2/3 to pass. Review Days 6-8."
    exit 1
fi
