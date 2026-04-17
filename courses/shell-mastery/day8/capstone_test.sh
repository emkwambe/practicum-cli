#!/bin/bash
# Shell Final Capstone Grader
score=0; total=12

echo "=== Shell Scripting Final Capstone ==="
echo ""

[ -f "server-report.sh" ] && { echo "  ✅ server-report.sh exists"; score=$((score+1)); } || echo "  ❌ Missing server-report.sh"
[ -x "server-report.sh" ] && { echo "  ✅ Executable"; score=$((score+1)); } || echo "  ❌ Not executable"

if [ -f "server-report.sh" ]; then
    head -1 server-report.sh | grep -q "#!/bin/bash\|#!/usr/bin/env bash" && { echo "  ✅ Shebang"; score=$((score+1)); } || echo "  ❌ Missing shebang"
    grep -q "set -e\|set -euo" server-report.sh && { echo "  ✅ Strict mode"; score=$((score+1)); } || echo "  ❌ Missing strict mode"
    grep -q "trap " server-report.sh && { echo "  ✅ Uses trap"; score=$((score+1)); } || echo "  ❌ No trap found"

    funcs=$(grep -cE "^[a-z_]+\(\)|^function [a-z_]+" server-report.sh || echo 0)
    if [ "$funcs" -ge 6 ]; then
        echo "  ✅ $funcs functions defined (6+ required)"
        score=$((score+1))
    else
        echo "  ❌ Only $funcs functions (need 6+)"
    fi

    grep -q "local " server-report.sh && { echo "  ✅ Uses local variables"; score=$((score+1)); } || echo "  ❌ No local variables"

    grep -qE "\-h\|--help\|usage" server-report.sh && { echo "  ✅ Help/usage"; score=$((score+1)); } || echo "  ❌ No help flag"
    grep -qE "\-o\|--output" server-report.sh && { echo "  ✅ Output flag (-o)"; score=$((score+1)); } || echo "  ❌ No -o flag"

    grep -qE "warnings|errors|WARNINGS|ERRORS" server-report.sh && { echo "  ✅ Collects warnings/errors"; score=$((score+1)); } || echo "  ❌ No warning/error collection"

    bash -n server-report.sh 2>/dev/null && { echo "  ✅ No syntax errors"; score=$((score+1)); } || echo "  ❌ Syntax errors"

    if bash server-report.sh -h 2>/dev/null | grep -qi "usage\|help"; then
        echo "  ✅ Help flag works"
        score=$((score+1))
    else
        echo "  ❌ Help flag doesn't produce usage text"
    fi
fi

echo ""
echo "  Score: $score / $total"
echo ""
if [ "$score" -ge 9 ]; then
    echo "  🎉 SHELL SCRIPTING MASTERY COMPLETE! ($score/$total)"
    echo ""
    echo "  You have mastered:"
    echo "    ✅ Script structure and strict mode"
    echo "    ✅ Variables, quoting, and arguments"
    echo "    ✅ Conditionals, loops, and arrays"
    echo "    ✅ Functions and modular design"
    echo "    ✅ Text processing (awk, sed, regex)"
    echo "    ✅ Error handling and debugging"
    echo ""
    echo "  Generate your certificate: practicum certificate"
    exit 0
else
    echo "  ❌ Need 9/$total. Review and try again."
    exit 1
fi
