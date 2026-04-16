#!/bin/bash
# Git Final Capstone Grader — 5 phases, 100 points

score=0
total=100

echo "=========================================="
echo "  Git Course — Final Capstone Grading"
echo "=========================================="
echo ""

# === Phase 1: Repository Foundation (20 points) ===
echo "### Phase 1: Repository Foundation (20 points) ###"
phase1=0

if [ -d ".git" ]; then
    echo "  ✅ Git repository initialized (+4)"
    phase1=$((phase1 + 4))
else
    echo "  ❌ Not a Git repository"
fi

if [ -f "README.md" ] && [ "$(wc -l < README.md)" -gt 5 ]; then
    echo "  ✅ README.md with real content (+4)"
    phase1=$((phase1 + 4))
else
    echo "  ❌ README.md missing or too short"
fi

if [ -f "LICENSE" ] || [ -f "LICENSE.md" ]; then
    echo "  ✅ LICENSE file (+4)"
    phase1=$((phase1 + 4))
else
    echo "  ❌ LICENSE file missing"
fi

if [ -f ".gitignore" ]; then
    echo "  ✅ .gitignore (+2)"
    phase1=$((phase1 + 2))
else
    echo "  ❌ .gitignore missing"
fi

if [ -f "CONTRIBUTING.md" ]; then
    echo "  ✅ CONTRIBUTING.md (+3)"
    phase1=$((phase1 + 3))
else
    echo "  ❌ CONTRIBUTING.md missing"
fi

if [ -f "CHANGELOG.md" ]; then
    echo "  ✅ CHANGELOG.md (+3)"
    phase1=$((phase1 + 3))
else
    echo "  ❌ CHANGELOG.md missing"
fi

echo "  Phase 1 score: $phase1 / 20"
echo ""
score=$((score + phase1))

# === Phase 2: Feature Development (20 points) ===
echo "### Phase 2: Feature Development (20 points) ###"
phase2=0

commit_count=$(git log --oneline 2>/dev/null | wc -l)
if [ "$commit_count" -ge 10 ]; then
    echo "  ✅ 10+ commits ($commit_count total) (+10)"
    phase2=$((phase2 + 10))
elif [ "$commit_count" -ge 5 ]; then
    echo "  ⚠️  Only $commit_count commits, need 10+ (+5)"
    phase2=$((phase2 + 5))
else
    echo "  ❌ Only $commit_count commits, need 10+"
fi

# Check for merge commits (evidence of feature branches)
merge_count=$(git log --merges --oneline 2>/dev/null | wc -l)
if [ "$merge_count" -ge 3 ]; then
    echo "  ✅ 3+ merge commits — feature branches used (+10)"
    phase2=$((phase2 + 10))
elif [ "$merge_count" -ge 1 ]; then
    echo "  ⚠️  Only $merge_count merge commits (+5)"
    phase2=$((phase2 + 5))
else
    echo "  ❌ No merge commits found. Use --no-ff when merging branches"
fi

echo "  Phase 2 score: $phase2 / 20"
echo ""
score=$((score + phase2))

# === Phase 3: Release (20 points) ===
echo "### Phase 3: Release (20 points) ###"
phase3=0

if git tag | grep -qE "^v[0-9]+\.[0-9]+\.[0-9]+$"; then
    tag=$(git tag | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | head -1)
    echo "  ✅ Semver tag exists: $tag (+10)"
    phase3=$((phase3 + 10))

    # Check if annotated
    if git cat-file -t "$tag" 2>/dev/null | grep -q "tag"; then
        echo "  ✅ Tag is annotated (+5)"
        phase3=$((phase3 + 5))
    else
        echo "  ⚠️  Tag is lightweight, use -a for annotated"
    fi
else
    echo "  ❌ No semantic version tag (vX.Y.Z) found"
fi

if [ -f "RELEASE_NOTES.md" ]; then
    echo "  ✅ RELEASE_NOTES.md exists (+5)"
    phase3=$((phase3 + 5))
else
    echo "  ❌ RELEASE_NOTES.md missing"
fi

echo "  Phase 3 score: $phase3 / 20"
echo ""
score=$((score + phase3))

# === Phase 4: Automation (20 points) ===
echo "### Phase 4: Automation (20 points) ###"
phase4=0

if [ -d ".github/workflows" ] && ls .github/workflows/*.yml >/dev/null 2>&1; then
    echo "  ✅ GitHub Actions workflow exists (+10)"
    phase4=$((phase4 + 10))

    # Check for basic structure
    if grep -q "runs-on" .github/workflows/*.yml 2>/dev/null; then
        echo "  ✅ Workflow has runs-on (+2)"
        phase4=$((phase4 + 2))
    fi
    if grep -q "steps:" .github/workflows/*.yml 2>/dev/null; then
        echo "  ✅ Workflow has steps (+3)"
        phase4=$((phase4 + 3))
    fi
else
    echo "  ❌ Missing .github/workflows/*.yml"
fi

if [ -f ".git/hooks/pre-commit" ] && [ -x ".git/hooks/pre-commit" ]; then
    echo "  ✅ Pre-commit hook installed and executable (+5)"
    phase4=$((phase4 + 5))
else
    echo "  ❌ Missing or non-executable .git/hooks/pre-commit"
fi

echo "  Phase 4 score: $phase4 / 20"
echo ""
score=$((score + phase4))

# === Phase 5: Documentation (20 points) ===
echo "### Phase 5: Documentation (20 points) ###"
phase5=0

if [ -f "PROJECT_REPORT.md" ]; then
    echo "  ✅ PROJECT_REPORT.md exists (+10)"
    phase5=$((phase5 + 10))

    # Check for required sections
    required_sections=("Project Overview" "Architecture" "Git Workflow" "Contribute" "Release History" "Acknowledgments")
    missing=0
    for section in "${required_sections[@]}"; do
        if grep -iq "$section" PROJECT_REPORT.md; then
            phase5=$((phase5 + 1))
        else
            missing=$((missing + 1))
        fi
    done

    if [ "$missing" -eq 0 ]; then
        echo "  ✅ All 6 required sections present (+6)"
    else
        echo "  ⚠️  Missing $missing of 6 required sections"
    fi

    # Check length (should be substantive)
    lines=$(wc -l < PROJECT_REPORT.md)
    if [ "$lines" -gt 30 ]; then
        echo "  ✅ Report is substantive ($lines lines) (+4)"
        phase5=$((phase5 + 4))
    elif [ "$lines" -gt 15 ]; then
        echo "  ⚠️  Report is short ($lines lines), needs more detail (+2)"
        phase5=$((phase5 + 2))
    else
        echo "  ❌ Report too short ($lines lines)"
    fi
else
    echo "  ❌ PROJECT_REPORT.md missing"
fi

echo "  Phase 5 score: $phase5 / 20"
echo ""
score=$((score + phase5))

# === Final Score ===
echo "=========================================="
echo "  FINAL SCORE: $score / $total"
echo "=========================================="

if [ "$score" -ge 90 ]; then
    echo ""
    echo "  🏆 PERFECT EXECUTION ($score/$total)!"
    echo "  Exceptional work across all phases."
    echo "  You are ready to lead professional Git projects."
    exit 0
elif [ "$score" -ge 80 ]; then
    echo ""
    echo "  🥇 DISTINCTION ($score/$total)!"
    echo "  You have mastered professional Git workflows."
    echo "  You qualify for the Advanced Git certificate."
    exit 0
elif [ "$score" -ge 60 ]; then
    echo ""
    echo "  ✅ PASSED ($score/$total)!"
    echo "  Solid Git fundamentals."
    echo "  You qualify for the Git Fundamentals certificate."
    exit 0
else
    echo ""
    echo "  ❌ Need 60+ to pass. You got $score."
    echo "  Review the phases that scored low and try again."
    exit 1
fi
