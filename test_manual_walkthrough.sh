#!/bin/bash
# Practicum CLI — Manual Testing Walkthrough
# Run this script, follow the prompts, and it captures everything to a log file.
# Share the log file with your review team (Claude Chat + DeepSeek).

LOG_FILE="$HOME/practicum-test-$(date +%Y%m%d-%H%M%S).log"

# Capture both terminal and log
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================"
echo "  PRACTICUM CLI — MANUAL TEST WALKTHROUGH"
echo "  Date: $(date)"
echo "  Tester: $(whoami)@$(hostname)"
echo "  Log: $LOG_FILE"
echo "============================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRACTICUM="$SCRIPT_DIR/practicum"

# Ensure clean state
echo "[TEST] Resetting state..."
rm -rf ~/.practicum
echo "[TEST] State reset complete."
echo ""

# =============================================
# SECTION 1: Initial State Check
# =============================================
echo "============================================"
echo "  SECTION 1: Initial State"
echo "============================================"
echo ""
echo "[TEST] Running: practicum status"
$PRACTICUM status
echo ""
echo "[TEST] Running: practicum --help"
$PRACTICUM --help
echo ""

# =============================================
# SECTION 2: Day 1 — Lesson Flow
# =============================================
echo "============================================"
echo "  SECTION 2: Day 1 — Lesson by Lesson"
echo "============================================"
echo ""

echo "[TEST] Opening main menu and selecting Day 1..."
echo "[INSTRUCTION] You will now go through each Day 1 lesson interactively."
echo "[INSTRUCTION] For each lesson:"
echo "  - Read the lesson content"
echo "  - Note if [WHEN], [INTENT], [CONTEXT], [ACTION], [RESULT] are all present"
echo "  - Rate clarity: 1=confusing, 2=ok, 3=clear, 4=excellent"
echo "  - After reading, choose [1] Next lesson to continue"
echo ""
read -p "[TESTER] Press Enter to start Day 1..."
echo ""

$PRACTICUM start

# =============================================
# SECTION 3: Day 1 Quiz
# =============================================
echo ""
echo "============================================"
echo "  SECTION 3: Day 1 Quiz"
echo "============================================"
echo ""
echo "[INSTRUCTION] Take the Day 1 quiz honestly."
echo "[INSTRUCTION] Note any confusing questions."
echo ""
read -p "[TESTER] Press Enter to take Day 1 quiz..."
echo ""

$PRACTICUM quiz

echo ""
echo "[TEST] Checking status after Day 1 quiz..."
$PRACTICUM status
echo ""

echo "[TEST] Checking state files..."
echo "--- unlocked.txt ---"
cat ~/.practicum/unlocked.txt 2>/dev/null || echo "(empty)"
echo "--- completed.txt ---"
cat ~/.practicum/completed.txt 2>/dev/null || echo "(empty)"
echo "--- scores.txt ---"
cat ~/.practicum/scores.txt 2>/dev/null || echo "(empty)"
echo ""

# =============================================
# SECTION 4: Day 2 — Lesson Flow
# =============================================
echo "============================================"
echo "  SECTION 4: Day 2 — Lesson by Lesson"
echo "============================================"
echo ""
echo "[INSTRUCTION] Go through each Day 2 lesson."
echo "[INSTRUCTION] Same criteria: check ICAR format, rate clarity."
echo ""
read -p "[TESTER] Press Enter to start Day 2..."
echo ""

$PRACTICUM start

# =============================================
# SECTION 5: Day 2 Quiz
# =============================================
echo ""
echo "============================================"
echo "  SECTION 5: Day 2 Quiz"
echo "============================================"
echo ""
read -p "[TESTER] Press Enter to take Day 2 quiz..."
echo ""

# Use quiz selector
echo "2" | $PRACTICUM start 2>/dev/null
# Actually let them do it interactively
$PRACTICUM start

echo ""
echo "[TEST] Checking status after Day 2..."
$PRACTICUM status
echo ""

echo "[TEST] Final state files..."
echo "--- unlocked.txt ---"
cat ~/.practicum/unlocked.txt 2>/dev/null || echo "(empty)"
echo "--- completed.txt ---"
cat ~/.practicum/completed.txt 2>/dev/null || echo "(empty)"
echo "--- scores.txt ---"
cat ~/.practicum/scores.txt 2>/dev/null || echo "(empty)"
echo ""

# =============================================
# SECTION 6: Navigation Testing
# =============================================
echo "============================================"
echo "  SECTION 6: Navigation Tests"
echo "============================================"
echo ""
echo "[INSTRUCTION] Test these navigation scenarios:"
echo "  1. From main menu, go to Day 1, then press [9] back — does it return?"
echo "  2. Complete a lesson, press [2] repeat — does it show again?"
echo "  3. From Day 2 menu, try selecting a locked lesson — does it block?"
echo "  4. Try invalid input (e.g., 'x') — does it handle gracefully?"
echo ""
read -p "[TESTER] Press Enter to test navigation..."
echo ""

$PRACTICUM start

# =============================================
# SECTION 7: Lab Mode Quick Test
# =============================================
echo ""
echo "============================================"
echo "  SECTION 7: Lab Mode"
echo "============================================"
echo ""
echo "[INSTRUCTION] Lab mode will drop you into a sandboxed shell."
echo "[INSTRUCTION] Try these commands inside lab:"
echo "  mkdir testdir"
echo "  touch testdir/file.txt"
echo "  ls"
echo "  rm testdir/file.txt"
echo "  exit (to leave lab)"
echo ""
read -p "[TESTER] Press Enter to enter Lab mode..."
echo ""

$PRACTICUM lab

# =============================================
# SECTION 8: Certificate
# =============================================
echo ""
echo "============================================"
echo "  SECTION 8: Certificate"
echo "============================================"
echo ""
$PRACTICUM certificate
echo ""

# =============================================
# SECTION 9: Tester Feedback
# =============================================
echo "============================================"
echo "  SECTION 9: Your Feedback"
echo "============================================"
echo ""

read -p "Overall experience (1-5): " rating
echo "[FEEDBACK] Rating: $rating"

read -p "Was any lesson confusing? Which one? " confusing
echo "[FEEDBACK] Confusing lesson: $confusing"

read -p "Did navigation feel natural? (yes/no): " nav_feel
echo "[FEEDBACK] Navigation natural: $nav_feel"

read -p "Did colors help readability? (yes/no): " colors_help
echo "[FEEDBACK] Colors helpful: $colors_help"

read -p "Any bugs or crashes? Describe: " bugs
echo "[FEEDBACK] Bugs: $bugs"

read -p "What feature would you add? " feature
echo "[FEEDBACK] Feature request: $feature"

read -p "Would you recommend this to a colleague? (yes/no): " recommend
echo "[FEEDBACK] Would recommend: $recommend"

echo ""
echo "============================================"
echo "  TEST COMPLETE"
echo "  Log saved to: $LOG_FILE"
echo "  Share this file for review."
echo "============================================"
echo ""
echo "To view: cat $LOG_FILE"
echo "To share: copy the file or paste its contents."
