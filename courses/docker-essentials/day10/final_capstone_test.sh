#!/bin/bash
# Docker Final Capstone Grader

score=0
total=10

echo "=== Docker Final Capstone Grading ==="
echo ""

# Stack deployed?
if docker stack ls --format '{{.Name}}' 2>/dev/null | grep -qx "capstone"; then
    echo "  ✅ 1. Stack 'capstone' deployed"
    score=$((score + 1))

    SERVICES=$(docker stack services capstone --format '{{.Name}}' 2>/dev/null | wc -l)
    if [ "$SERVICES" -ge 3 ]; then
        echo "  ✅ 2. 3+ services in stack"
        score=$((score + 1))
    else
        echo "  ❌ 2. Stack should have 3 services (web, db, cache)"
    fi

    # Web service has 3 replicas?
    WEB_REPS=$(docker service inspect capstone_web --format '{{.Spec.Mode.Replicated.Replicas}}' 2>/dev/null)
    if [ "$WEB_REPS" = "3" ]; then
        echo "  ✅ 3. Web service has 3 replicas"
        score=$((score + 1))
    else
        echo "  ❌ 3. Web replicas should be 3 (got: $WEB_REPS)"
    fi
else
    echo "  ❌ 1. Stack 'capstone' not deployed"
fi

# Secret exists
if docker secret ls --format '{{.Name}}' 2>/dev/null | grep -qx "db_password"; then
    echo "  ✅ 4. Secret 'db_password' exists"
    score=$((score + 1))
else
    echo "  ❌ 4. Secret 'db_password' not created"
fi

# Image built
if docker images capstone-app:1.0 --format '{{.Tag}}' 2>/dev/null | grep -q "1.0"; then
    echo "  ✅ 5. Image capstone-app:1.0 built"
    score=$((score + 1))
else
    echo "  ❌ 5. Image not built"
fi

# Networks
if docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "capstone_backend"; then
    echo "  ✅ 6. Backend network exists"
    score=$((score + 1))
fi
if docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "capstone_frontend"; then
    echo "  ✅ 7. Frontend network exists"
    score=$((score + 1))
fi

# Volume
if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q "capstone_dbdata"; then
    echo "  ✅ 8. Volume 'dbdata' exists"
    score=$((score + 1))
fi

# Endpoint test
if command -v curl >/dev/null 2>&1; then
    sleep 2
    if curl -s --max-time 3 http://localhost:8080 2>/dev/null | grep -q "Hello from"; then
        echo "  ✅ 9. Web service responds with greeting"
        score=$((score + 1))
    fi
    if curl -s --max-time 3 http://localhost:8080/health 2>/dev/null | grep -q "OK"; then
        echo "  ✅ 10. Health endpoint returns OK"
        score=$((score + 1))
    fi
fi

echo ""
echo "  Score: $score / $total"
echo ""

if [ "$score" -ge 8 ]; then
    echo "  🎉 DOCKER COURSE COMPLETE! ($score/$total)"
    echo ""
    echo "  You have mastered:"
    echo "    ✅ Container fundamentals"
    echo "    ✅ Production-grade image building"
    echo "    ✅ Multi-service orchestration with Compose"
    echo "    ✅ Registry push/pull with private registries"
    echo "    ✅ Security hardening"
    echo "    ✅ Swarm orchestration with rolling updates"
    echo ""
    echo "  You are ready for:"
    echo "    🎓 Docker Certified Associate (DCA) exam"
    echo "    💼 DevOps / SRE / Platform Engineer roles"
    echo ""
    echo "  Generate your certificate: practicum certificate"
    exit 0
else
    echo "  ❌ Need 8/$total to complete. Review and try again."
    exit 1
fi
