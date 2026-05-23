#!/bin/bash
# Docker Assessment 2 Grader

score=0
total=10

echo "=== Docker Assessment 2: Production Deployment Grading ==="
echo ""

# Task 1: Files
if [ -f "Dockerfile" ]; then
    echo "  ✅ Task 1a: Dockerfile exists"
    score=$((score + 1))
else
    echo "  ❌ Task 1a: Missing Dockerfile"
fi

if [ -f "app.py" ]; then
    echo "  ✅ Task 1b: app.py exists"
    score=$((score + 1))
else
    echo "  ❌ Task 1b: Missing app.py"
fi

# Dockerfile hardening checks
if [ -f "Dockerfile" ]; then
    if grep -q "USER " Dockerfile; then
        echo "  ✅ Task 1c: USER directive (non-root)"
        score=$((score + 1))
    else
        echo "  ❌ Task 1c: Missing USER directive"
    fi

    if grep -q "HEALTHCHECK" Dockerfile; then
        echo "  ✅ Task 1d: HEALTHCHECK defined"
        score=$((score + 1))
    else
        echo "  ❌ Task 1d: Missing HEALTHCHECK"
    fi
fi

# Swarm initialized
if docker info 2>/dev/null | grep -qi "Swarm: active"; then
    echo "  ✅ Task 2a: Swarm is active"
    score=$((score + 1))
else
    echo "  ❌ Task 2a: Swarm not initialized (run: docker swarm init)"
fi

# Secret exists
if docker secret ls --format '{{.Name}}' 2>/dev/null | grep -qx "greeting"; then
    echo "  ✅ Task 2b: Secret 'greeting' exists"
    score=$((score + 1))
else
    echo "  ❌ Task 2b: Secret 'greeting' missing"
fi

# Image built
if docker images production-app:1.0 --format '{{.Tag}}' 2>/dev/null | grep -q "1.0"; then
    echo "  ✅ Task 3: Image production-app:1.0 built"
    score=$((score + 1))
else
    echo "  ❌ Task 3: Image not built (docker build -t production-app:1.0 .)"
fi

# Service exists
if docker service ls --format '{{.Name}}' 2>/dev/null | grep -qx "api"; then
    echo "  ✅ Task 4a: Service 'api' exists"
    score=$((score + 1))

    REPLICAS=$(docker service inspect api --format '{{.Spec.Mode.Replicated.Replicas}}' 2>/dev/null)
    if [ "$REPLICAS" = "3" ]; then
        echo "  ✅ Task 4b: 3 replicas configured"
        score=$((score + 1))
    else
        echo "  ❌ Task 4b: Replicas should be 3 (got: $REPLICAS)"
    fi
else
    echo "  ❌ Task 4: Service 'api' not running"
fi

# Endpoint test
if command -v curl >/dev/null 2>&1; then
    sleep 2
    RESPONSE=$(curl -s --max-time 3 http://localhost:8080 2>/dev/null)
    if echo "$RESPONSE" | grep -q "Hello, Production"; then
        echo "  ✅ Task 5: Service returns 'Hello, Production!'"
        score=$((score + 1))
    else
        echo "  ❌ Task 5: Service did not return expected greeting (got: $RESPONSE)"
    fi
fi

echo ""
echo "  Score: $score / $total"
echo ""

if [ "$score" -ge 7 ]; then
    echo "  ✅ ASSESSMENT 2 PASSED! ($score/$total)"
    echo "  You can now ship production-grade containerized services."
    exit 0
else
    echo "  ❌ Need 7/$total to pass. Review Days 5-8 and try again."
    exit 1
fi
