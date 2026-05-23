#!/bin/bash
# Git Assessment 1 Grader — midpoint skills check

score=0
total=8

echo "=== Git Assessment 1: Grading ==="
echo ""

# Task 1: Git repo exists
if [ -d ".git" ]; then
    echo "  ✅ Task 1a: Git repository initialized"
    score=$((score + 1))
else
    echo "  ❌ Task 1a: Run: git init"
fi

# Task 2: README.md exists with content
if [ -f "README.md" ] && [ "$(wc -l < README.md)" -gt 0 ]; then
    echo "  ✅ Task 1b: README.md exists with content"
    score=$((score + 1))
else
    echo "  ❌ Task 1b: Missing README.md or it is empty"
fi

# Task 3: .gitignore exists
if [ -f ".gitignore" ]; then
    echo "  ✅ Task 1c: .gitignore exists"
    score=$((score + 1))
else
    echo "  ❌ Task 1c: Missing .gitignore"
fi

# Task 4: At least 4 commits
commit_count=$(git log --oneline 2>/dev/null | wc -l)
if [ "$commit_count" -ge 4 ]; then
    echo "  ✅ Task 2a: Has $commit_count commits (need 4+)"
    score=$((score + 1))
else
    echo "  ❌ Task 2a: Only $commit_count commits, need 4+"
fi

# Task 5: config.txt exists (from feature branch)
if [ -f "config.txt" ]; then
    echo "  ✅ Task 2b: config.txt exists (merged from feature branch)"
    score=$((score + 1))
else
    echo "  ❌ Task 2b: Missing config.txt"
fi

# Task 6: Feature branch was deleted (clean repo)
if ! git branch | grep -q "feature/add-config"; then
    echo "  ✅ Task 2c: Feature branch was cleaned up"
    score=$((score + 1))
else
    echo "  ⚠️  Task 2c: feature/add-config branch still exists — delete it"
fi

# Task 7: CONTRIBUTING.md exists
if [ -f "CONTRIBUTING.md" ]; then
    echo "  ✅ Task 3a: CONTRIBUTING.md exists"
    score=$((score + 1))
else
    echo "  ❌ Task 3a: Missing CONTRIBUTING.md"
fi

# Task 8: Commit messages are meaningful (no "wip" or "stuff")
bad_msgs=$(git log --oneline 2>/dev/null | grep -iE "\b(wip|stuff|asdf|test|fix)$" | wc -l)
if [ "$bad_msgs" -eq 0 ]; then
    echo "  ✅ Task 4: Commit messages look meaningful"
    score=$((score + 1))
else
    echo "  ⚠️  Task 4: Found $bad_msgs vague commit messages (use more descriptive ones)"
fi

echo ""
echo "  Score: $score / $total"
echo ""

if [ "$score" -ge 6 ]; then
    echo "  ✅ ASSESSMENT 1 PASSED! ($score/$total)"
    echo "  You have demonstrated solid Git collaboration skills."
    exit 0
else
    echo "  ❌ Need at least 6/$total to pass. Review Days 1-4 and try again."
    exit 1
fi
