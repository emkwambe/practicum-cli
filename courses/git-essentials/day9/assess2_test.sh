#!/bin/bash
# Git Assessment 2 Grader — checks advanced Git skills

score=0
total=10

echo "=== Git Assessment 2: Grading ==="
echo ""

# Task 1: Is this a git repo?
if [ -d ".git" ]; then
    echo "  ✅ Task 1a: Git repository initialized"
    score=$((score + 1))
else
    echo "  ❌ Task 1a: Not in a Git repository. Run: git init"
fi

# Task 2: At least 3 commits?
commit_count=$(git log --oneline 2>/dev/null | wc -l)
if [ "$commit_count" -ge 3 ]; then
    echo "  ✅ Task 1b: Has $commit_count commits (need 3+)"
    score=$((score + 1))
else
    echo "  ❌ Task 1b: Only $commit_count commits, need at least 3"
fi

# Task 3: Has a tag starting with v
if git tag | grep -q "^v"; then
    tag=$(git tag | grep "^v" | head -1)
    echo "  ✅ Task 2: Release tag found: $tag"
    score=$((score + 1))
else
    echo "  ❌ Task 2: No version tag found. Create: git tag -a v1.0.0 -m 'Release'"
fi

# Task 4: LICENSE file
if [ -f "LICENSE" ] || [ -f "LICENSE.md" ] || [ -f "LICENSE.txt" ]; then
    echo "  ✅ Task 3a: LICENSE file exists"
    score=$((score + 1))
else
    echo "  ❌ Task 3a: Missing LICENSE file"
fi

# Task 5: CONTRIBUTING.md
if [ -f "CONTRIBUTING.md" ]; then
    echo "  ✅ Task 3b: CONTRIBUTING.md exists"
    score=$((score + 1))
else
    echo "  ❌ Task 3b: Missing CONTRIBUTING.md"
fi

# Task 6: CHANGELOG.md
if [ -f "CHANGELOG.md" ]; then
    echo "  ✅ Task 3c: CHANGELOG.md exists"
    score=$((score + 1))
else
    echo "  ❌ Task 3c: Missing CHANGELOG.md"
fi

# Task 7: GitHub Actions workflow
if [ -d ".github/workflows" ] && [ -n "$(ls .github/workflows/*.yml 2>/dev/null)" ]; then
    echo "  ✅ Task 3d: GitHub Actions workflow exists"
    score=$((score + 1))
else
    echo "  ❌ Task 3d: Missing .github/workflows/*.yml"
fi

# Task 8: Pre-commit hook
if [ -f ".git/hooks/pre-commit" ] && [ -x ".git/hooks/pre-commit" ]; then
    echo "  ✅ Task 4: Pre-commit hook installed and executable"
    score=$((score + 1))
else
    echo "  ❌ Task 4: Missing or non-executable .git/hooks/pre-commit"
fi

# Task 9: .gitignore file
if [ -f ".gitignore" ]; then
    echo "  ✅ Task 5a: .gitignore exists"
    score=$((score + 1))
else
    echo "  ❌ Task 5a: Missing .gitignore"
fi

# Task 10: README.md
if [ -f "README.md" ]; then
    echo "  ✅ Task 5b: README.md exists"
    score=$((score + 1))
else
    echo "  ❌ Task 5b: Missing README.md"
fi

echo ""
echo "  Score: $score / $total"
echo ""

if [ "$score" -ge 7 ]; then
    echo "  ✅ ASSESSMENT 2 PASSED! ($score/$total)"
    echo "  You have demonstrated professional Git workflow skills."
    exit 0
else
    echo "  ❌ Need at least 7/$total to pass. Review Days 6-8 and try again."
    exit 1
fi
