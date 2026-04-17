#!/bin/bash
# Shell Assessment 1 Grader
score=0; total=10

echo "=== Shell Assessment 1: System Monitoring Tool ==="
echo ""

[ -f "syscheck.sh" ] && { echo "  ✅ syscheck.sh exists"; score=$((score+1)); } || echo "  ❌ Missing syscheck.sh"
[ -x "syscheck.sh" ] && { echo "  ✅ Script is executable"; score=$((score+1)); } || echo "  ❌ Not executable (chmod +x)"

if [ -f "syscheck.sh" ]; then
    head -1 syscheck.sh | grep -q "#!/bin/bash\|#!/usr/bin/env bash" && { echo "  ✅ Has shebang"; score=$((score+1)); } || echo "  ❌ Missing shebang"
    grep -q "set -e\|set -euo" syscheck.sh && { echo "  ✅ Uses strict mode"; score=$((score+1)); } || echo "  ❌ Missing set -e or set -euo pipefail"
    grep -q "^check_disk\|check_disk()" syscheck.sh && { echo "  ✅ Has check_disk function"; score=$((score+1)); } || echo "  ❌ Missing check_disk()"
    grep -q "^check_memory\|check_memory()" syscheck.sh && { echo "  ✅ Has check_memory function"; score=$((score+1)); } || echo "  ❌ Missing check_memory()"
    grep -q "^check_services\|check_services()" syscheck.sh && { echo "  ✅ Has check_services function"; score=$((score+1)); } || echo "  ❌ Missing check_services()"
    grep -q "local " syscheck.sh && { echo "  ✅ Uses local variables"; score=$((score+1)); } || echo "  ❌ No local variables found"
    grep -qE "\-h\|--help\|usage" syscheck.sh && { echo "  ✅ Has help/usage"; score=$((score+1)); } || echo "  ❌ Missing -h/--help"
    bash -n syscheck.sh 2>/dev/null && { echo "  ✅ No syntax errors"; score=$((score+1)); } || echo "  ❌ Syntax errors found"
fi

echo ""
echo "  Score: $score / $total"
echo ""
[ "$score" -ge 7 ] && { echo "  ✅ ASSESSMENT 1 PASSED! ($score/$total)"; exit 0; } || { echo "  ❌ Need 7/$total. Review Days 1-4."; exit 1; }
