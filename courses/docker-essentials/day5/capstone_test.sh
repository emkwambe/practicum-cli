#!/bin/bash
# Docker Assessment 1 Grader

score=0
total=10

echo "=== Docker Assessment 1: Grading ==="
echo ""

# Task 1: Files exist
if [ -f "Dockerfile" ]; then
    echo "  ✅ Task 1a: Dockerfile exists"
    score=$((score + 1))
else
    echo "  ❌ Task 1a: Missing Dockerfile in current directory"
fi

if [ -f "app.py" ]; then
    echo "  ✅ Task 1b: app.py exists"
    score=$((score + 1))
else
    echo "  ❌ Task 1b: Missing app.py"
fi

# Task 2: Dockerfile contains required elements
if [ -f "Dockerfile" ]; then
    if grep -q "FROM python:3.11-slim" Dockerfile; then
        echo "  ✅ Task 1c: Uses python:3.11-slim base"
        score=$((score + 1))
    else
        echo "  ❌ Task 1c: Should use FROM python:3.11-slim"
    fi

    if grep -q "USER " Dockerfile; then
        echo "  ✅ Task 1d: Drops to non-root user (USER directive)"
        score=$((score + 1))
    else
        echo "  ❌ Task 1d: Missing USER directive (security)"
    fi

    if grep -q "EXPOSE 8000" Dockerfile; then
        echo "  ✅ Task 1e: EXPOSE 8000 declared"
        score=$((score + 1))
    else
        echo "  ❌ Task 1e: Missing EXPOSE 8000"
    fi
fi

# Task 3: Image is tagged
if docker images assessment-app:1.0 --format '{{.Tag}}' 2>/dev/null | grep -q "1.0"; then
    echo "  ✅ Task 2a: Image tagged assessment-app:1.0"
    score=$((score + 1))
else
    echo "  ❌ Task 2a: Image not tagged 1.0 (run: docker build -t assessment-app:1.0 .)"
fi

if docker images assessment-app:latest --format '{{.Tag}}' 2>/dev/null | grep -q "latest"; then
    echo "  ✅ Task 2b: Also tagged assessment-app:latest"
    score=$((score + 1))
else
    echo "  ❌ Task 2b: Missing :latest tag (run: docker tag assessment-app:1.0 assessment-app:latest)"
fi

# Task 4: Container running with correct config
if docker ps --filter "name=my-app" --format '{{.Names}}' | grep -q "my-app"; then
    echo "  ✅ Task 3a: Container 'my-app' is running"
    score=$((score + 1))

    if docker port my-app 2>/dev/null | grep -q "8000.*0.0.0.0:8080"; then
        echo "  ✅ Task 3b: Port 8080->8000 mapping correct"
        score=$((score + 1))
    else
        echo "  ❌ Task 3b: Port mapping should be 8080:8000"
    fi
else
    echo "  ❌ Task 3a: Container 'my-app' not running"
fi

# Task 5: Compose file exists
if [ -f "docker-compose.yml" ] || [ -f "compose.yml" ]; then
    echo "  ✅ Task 5: Compose file exists"
    score=$((score + 1))
else
    echo "  ❌ Task 5: Missing docker-compose.yml or compose.yml"
fi

echo ""
echo "  Score: $score / $total"
echo ""

if [ "$score" -ge 7 ]; then
    echo "  ✅ ASSESSMENT 1 PASSED! ($score/$total)"
    exit 0
else
    echo "  ❌ Need 7/$total to pass. Review Days 1-4 and try again."
    exit 1
fi
