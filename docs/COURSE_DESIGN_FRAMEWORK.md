# Practicum CLI — Course Design Framework
# Mpingo Systems LLC
# Version 1.0 — Derived from Linux Foundations (Course 1)
#
# This document is the blueprint for creating any Practicum CLI course.
# Follow it exactly and a new course can be built in 2-4 hours.

# ============================================================
# PART 1: PHILOSOPHY
# ============================================================

## 1.1 The ICAR Method

Every lesson follows Intent → Context → Action → Result.

The analogy: Getting to the market.
  INTENT  = "I need to get to the market"    (What you want to do)
  CONTEXT = "Raining, 2 miles, bus every 15"  (The situation)
  ACTION  = "Take the #7 bus from Main St"    (The command)
  RESULT  = "Arrive dry in 20 minutes"        (What changes)

Rules:
  - NEVER start with the command. Start with WHY.
  - Every lesson answers: "When would I need this?"
  - Commands are the bus routes. The curriculum is organized by DESTINATIONS.

## 1.2 The Apprenticeship Model

The course should feel like working alongside a senior engineer, NOT
watching a lecture. Three systems reinforce this:

  1. Situational Awareness — Show real system state before each lesson
  2. Senior Tips — Practical advice after key lessons ("always ls before rm")
  3. Skill Mastery — Track learned → practiced → mastered per skill

## 1.3 Course Structure (Standard Template)

Every course follows this 10-day structure:

  FOUNDATION (Free tier — Days 1-3)
    Day 1: First skills — "I need to ___"
    Day 2: Core skills — "I need to ___"
    Day 3: Power skills — "I need to ___"

  ADVANCED (Premium — Days 4-8)
    Day 4: Applied skills — "I need to ___"
    Day 5: ASSESSMENT 1 (Midpoint checkpoint)
    Day 6: Professional skills — "I need to ___"
    Day 7: Advanced skills — "I need to ___"
    Day 8: Expert skills — "I need to ___"

  CAPSTONE (Premium — Days 9-10)
    Day 9: ASSESSMENT 2 (Advanced checkpoint)
    Day 10: Final Review + Capstone Project

Standard metrics per course:
  - 40-56 lessons
  - 56-72 quiz questions (8 per quiz day)
  - 6+ challenges with lesson references
  - 3 work scenarios (beginner, intermediate, advanced)
  - 3 assessments (midpoint, advanced, final capstone)
  - 1 career overview (shown on first run)

# ============================================================
# PART 2: FILE STRUCTURE
# ============================================================

## 2.1 Directory Layout

courses/
  <course-slug>/                    # e.g., linux-foundations, git-essentials
    career_overview.txt             # Shown on first run
    day1/
      lesson1_<command>.txt         # ICAR lesson file
      lesson2_<command>.txt
      lesson3_<command>.txt
      ...
      quiz1.txt                     # Multiple-choice quiz
    day2/
      lesson1_<command>.txt
      ...
      quiz2.txt
    ...
    day5/
      lesson1_assessment1_intro.txt # Assessment instructions
      capstone_test.sh              # Automated grader
      quiz5.txt                     # Knowledge quiz
    ...
    day9/
      lesson1_assessment2_intro.txt
      assess2_test.sh
      quiz9.txt
    day10/
      lesson1_review.txt
      lesson2_final_capstone.txt
      final_capstone_test.sh
      quiz10.txt

## 2.2 Naming Conventions

  Lessons:  lesson<N>_<command_or_topic>.txt
  Quizzes:  quiz<day_number>.txt
  Graders:  <assessment_name>_test.sh
  Overview: career_overview.txt

  Course slug: lowercase, hyphens, no spaces
    ✅ linux-foundations
    ✅ git-essentials
    ✅ docker-containers
    ❌ Linux_Foundations
    ❌ gitEssentials

# ============================================================
# PART 3: LESSON TEMPLATE (ICAR FORMAT)
# ============================================================

## 3.1 Standard Lesson Template

Copy this template for every lesson. Fill in the blanks.

```
# Lesson: <command> — <Short Description>

## [WHEN] You need this when:
1. <Real scenario where a practitioner needs this>
2. <Another real scenario>
3. <Another real scenario>
4. <Another real scenario>

## [INTENT] "<One sentence: what the learner wants to achieve>"

## [CONTEXT]
<2-4 paragraphs explaining:>
<- What this command/concept is>
<- Why it exists / what problem it solves>
<- How it relates to what they already know>
<- Any important warnings or mental models>

## [ACTION] <command> [options]
Common patterns:
  <command> <basic usage>              — <what it does>
  <command> <variation 1>              — <what it does>
  <command> <variation 2>              — <what it does>
  <command> <variation 3>              — <what it does>

## [EXPECTED RESULT]
<What the learner will see after running the command.>
<Include example output if helpful.>

## Try it now:
<1-3 commands the learner should try immediately.>

## Next:
Type menu to continue or <related_command> to <next logical step>.
```

## 3.2 Lesson Writing Rules

  1. [WHEN] section: Always use real job scenarios, not abstract examples.
     ✅ "A server is throwing errors and you need to find them in log files."
     ❌ "When you want to search for patterns in text."

  2. [INTENT] section: Always a quoted first-person statement.
     ✅ "Where am I?"
     ✅ "Find lines that match a pattern."
     ❌ grep searches for patterns (this is CONTEXT, not INTENT)

  3. [CONTEXT] section: 2-4 paragraphs. Include:
     - What the command is (1 sentence)
     - Why it exists / what problem it solves (1-2 sentences)
     - How it relates to previous knowledge (1 sentence)
     - Mental model or analogy if helpful

  4. [ACTION] section: Show 4-6 common patterns with em-dash descriptions.
     Format: <code>              — <plain english>
     Include the most common real-world usages, not every flag.

  5. [EXPECTED RESULT]: What they will actually see. Include sample output.

  6. "Try it now": 1-3 safe commands they can run immediately.

  7. Warnings: Use WARNING prefix for dangerous commands (rm, chmod 777).
     The lesson renderer colors these red automatically.

## 3.3 Lesson Colorization (Automatic)

The lesson renderer in lib/lessons.sh automatically colors:
  # Title          → Purple
  ## [WHEN/INTENT/CONTEXT/ACTION/EXPECTED RESULT] → Green
  ## Other headers → Cyan
  WARNING/DANGEROUS → Red
  command — desc   → Cyan command + dim description
  1. 2. 3.        → White (numbered items)
  Regular text     → Default terminal color

No manual color codes needed in lesson files. Just follow the template.

# ============================================================
# PART 4: QUIZ TEMPLATE
# ============================================================

## 4.1 Standard Quiz Format

```
Q1: <Question text — clear, unambiguous>
A) <Wrong answer>
B) <Correct answer>
C) <Wrong answer>
D) <Wrong answer>
Correct: B

Q2: <Next question>
A) <option>
B) <option>
C) <option>
D) <option>
Correct: <letter>
```

## 4.2 Quiz Writing Rules

  1. 8 questions per quiz (except Day 5 assessment = 5)
  2. 4 options per question (A/B/C/D)
  3. Correct answer on its own line: "Correct: B"
  4. Blank line between questions
  5. Questions test APPLICATION, not memorization:
     ✅ "A developer says 'permission denied' when running deploy.sh.
         What do you check first?"
     ❌ "What does chmod stand for?"
  6. Include at least 2 scenario-based questions per quiz
  7. Passing score: 70% (handled by quiz_engine.sh)
  8. Distractor answers should be plausible but clearly wrong

# ============================================================
# PART 5: CHALLENGE TEMPLATE
# ============================================================

## 5.1 Challenge Structure

Each challenge requires 4 functions in lib/challenges/engine.sh:

```bash
# 1. Setup — creates the broken/initial state
setup_<challenge_id>() {
    rm -rf "$CHALLENGE_SANDBOX"
    mkdir -p "$CHALLENGE_SANDBOX"/{dir1,dir2}
    # Create files that represent the problem
    # Write MISSION.txt with instructions
}

# 2. Verify — checks if the student solved it
verify_<challenge_id>() {
    # Return 0 = solved, 1 = not solved
    # Check file states, not commands used
}

# 3. Lesson mapping — which lessons teach the needed skills
get_challenge_lessons() {
    case "$challenge_id" in
        <challenge_id>)
            echo "Day X Lesson Y (command), Day X Lesson Z (command)"
            ;;
    esac
}

# 4. Hint — shown on failure, references specific lessons
get_challenge_hint() {
    case "$challenge_id" in
        <challenge_id>)
            echo "Use '<command>' to <action>, then '<command>' to <action>."
            echo "Review: Day X Lesson Y (command) and Day X Lesson Z (command)"
            ;;
    esac
}
```

## 5.2 Challenge Design Rules

  1. Every challenge MUST map to specific lessons (get_challenge_lessons)
  2. Every command needed to solve it MUST be taught before the challenge
  3. MISSION.txt always includes:
     - What's wrong (the scenario)
     - What to do (numbered steps)
     - Skills needed (with Day/Lesson references)
     - How to signal completion (usually "type exit")
  4. Verification checks STATE, not HOW they got there
     ✅ Check: [ -x "deploy.sh" ] (is it executable?)
     ❌ Check: grep "chmod" history (did they use chmod?)
  5. Failure feedback always references specific lessons to review
  6. Minimum 6 challenges per course, 1+ per major topic

## 5.3 Challenge Categories

  - Fix-It: Something is broken, find and repair it
  - Investigation: Analyze data/logs to find the answer
  - Build-It: Create something from scratch
  - Cleanup: Remove/organize without breaking things
  - Pipeline: Chain multiple commands to produce a result

# ============================================================
# PART 6: WORK SCENARIO TEMPLATE
# ============================================================

## 6.1 Scenario Structure

Three scenarios per course, one per difficulty level:

```bash
# Beginner: "Your First Day"
# Chains 3-5 skills from Days 1-3
run_scenario_beginner() {
    # Print the scenario narrative
    # List 5-6 tasks
    # Show skills needed
}
setup_scenario_beginner() {
    # Create sandbox state
}
verify_scenario_beginner() {
    # Check deliverables
}

# Intermediate: "The Project"
# Chains 5-8 skills from Days 1-6

# Advanced: "The Emergency"
# Chains 8+ skills from all days
```

## 6.2 Scenario Design Rules

  1. Each scenario tells a STORY (not "do these commands")
  2. The story puts the learner in a realistic role
  3. Tasks require multiple skills chained together
  4. Verification checks deliverable files, not process
  5. Scenarios record mastery for involved skills

# ============================================================
# PART 7: ASSESSMENT TEMPLATE
# ============================================================

## 7.1 Three Assessments Per Course

Assessment 1 (Day 5 — Midpoint):
  - Tests Days 1-4 skills
  - 1-2 deliverable scripts
  - Automated grading script
  - Knowledge quiz (8 questions)

Assessment 2 (Day 9 — Advanced):
  - Tests Days 6-8 skills
  - 2-3 deliverable scripts
  - Automated grading script
  - Knowledge quiz (8 questions)

Final Capstone (Day 10):
  - Tests ALL skills combined
  - 4-5 deliverable files
  - Scored out of 100 (20 points per phase)
  - Pass: 60+, Distinction: 80+
  - Includes documentation deliverable (tests writing skills)

## 7.2 Assessment Grading Script Template

```bash
#!/bin/bash
# Assessment grader — checks deliverables
score=0
total=<N>

echo "=== Assessment: Grading ==="

# Check each deliverable
if [ -f "script.sh" ] && [ -x "script.sh" ]; then
    if grep -q "<required_command>" script.sh; then
        echo "  ✅ Task 1: PASS"
        score=$((score + 1))
    else
        echo "  ❌ Task 1: Missing <required_command>"
    fi
else
    echo "  ❌ Task 1: script.sh not found or not executable"
fi

# ... repeat for each deliverable ...

echo ""
echo "  Score: $score / $total"

if [ "$score" -ge <passing_threshold> ]; then
    echo "  ✅ ASSESSMENT PASSED!"
    exit 0
else
    echo "  ❌ Need at least <threshold>/<total>. Review and try again."
    exit 1
fi
```

## 7.3 Assessment Design Rules

  1. Grading checks PRESENCE and CONTENT of deliverables
  2. Never check exact implementation — check for key commands/patterns
  3. Scripts must be executable (tests if they learned chmod +x)
  4. At least one deliverable must be documentation (README/report)
  5. Grading script outputs clear pass/fail per task with hints

# ============================================================
# PART 8: CAREER OVERVIEW TEMPLATE
# ============================================================

## 8.1 career_overview.txt Template

Shown on first run of the course. Must include:

```
# <Course Name> — What You're Training For

## 🎯 This course prepares you for <role description>

After completing all <N> days, you will be able to handle these
responsibilities that <X>% of employers require:

  ✅ <SKILL CLUSTER 1> (<X>% of job postings)
     - <Concrete ability>
     - <Concrete ability>
     - <Concrete ability>

  ✅ <SKILL CLUSTER 2> (<X>% of job postings)
     - <Concrete ability>
     ...

## 📋 Skills You Will Develop (by day)

  Day 1: <command list>
  Day 2: <command list>
  ...

## 🏆 By the end, you can:
  - <Outcome 1>
  - <Outcome 2>
  ...

## 💼 Roles this prepares you for:
  - <Role 1>
  - <Role 2>
  ...
  Average salary range: $XX,000 - $YY,000

## ▶ Ready? Type any key to begin.
```

# ============================================================
# PART 9: ENGINE INTEGRATION CHECKLIST
# ============================================================

When adding a new course, update these files:

## 9.1 Main Script (practicum)

  [ ] Add course directory detection in detect_course_dir()
  [ ] Add menu items for all 10 days
  [ ] Add cmd_dayN_menu() for each day (copy pattern from existing)
  [ ] Add unlock chains for each day's lessons
  [ ] Add quiz functions (cmd_quiz_dayN)
  [ ] Add assessment commands (cmd_assess1, cmd_assess2, cmd_final_capstone)
  [ ] Add day scores to cmd_status display
  [ ] Add premium gating (Days 4-10 check license)
  [ ] Add to quiz selector menu
  [ ] Wire into main entry point case statement

## 9.2 Apprentice Engine (lib/apprentice.sh)

  [ ] Add show_situation() cases for new commands
  [ ] Add senior_tip() entries for key commands
  [ ] Add skills to show_mastery_dashboard()
  [ ] Create 3 work scenarios (beginner/intermediate/advanced)
  [ ] Add scenario setup/verify functions

## 9.3 Challenge Engine (lib/challenges/engine.sh)

  [ ] Create 6+ challenges
  [ ] Each challenge has: setup, verify, lesson_map, hint
  [ ] Add to challenge menu (list_challenges, cmd_challenges)

## 9.4 License (lib/license.sh)

  [ ] Update is_premium_content() if free tier differs
  [ ] Update show_upgrade_prompt() if pricing changes

## 9.5 Content Files

  [ ] career_overview.txt
  [ ] 40-56 lesson files (ICAR format)
  [ ] 8-10 quiz files (8 questions each)
  [ ] 2-3 assessment grading scripts
  [ ] All lesson files follow naming: lessonN_command.txt

# ============================================================
# PART 10: QUALITY CHECKLIST
# ============================================================

Before shipping any course, verify:

## Content Quality
  [ ] Every lesson has all 5 ICAR sections
  [ ] Every [WHEN] uses real job scenarios (not abstract)
  [ ] Every [INTENT] is a quoted first-person statement
  [ ] Every [ACTION] shows 4-6 common patterns
  [ ] No command is used in a challenge that isn't taught in a lesson
  [ ] All quiz questions have 4 options + correct answer
  [ ] At least 2 scenario-based quiz questions per quiz
  [ ] Assessment graders test deliverables, not process

## Technical Quality
  [ ] bash -n practicum passes (syntax check)
  [ ] bash -n lib/*.sh passes
  [ ] Fresh install test: rm -rf ~/.practicum && ./practicum start
  [ ] All 10 days accessible with license
  [ ] Free tier (Days 1-3) works without license
  [ ] Premium gate shows upgrade prompt for Days 4+
  [ ] Unlock chains work (completing Day N lessons unlocks Day N quiz)
  [ ] Quiz passing unlocks next day's first lesson
  [ ] Mastery dashboard shows all course skills
  [ ] Certificate generates with correct course name and day count

## Competitive Alignment
  [ ] Map every day to an industry certification domain
  [ ] Map every skill cluster to job posting percentages
  [ ] Verify no major industry topic is missing
  [ ] Career overview salary ranges are current

# ============================================================
# PART 11: RAPID BUILD PROCESS
# ============================================================

## Step-by-step to build a new course in 2-4 hours:

  Hour 1: Planning (30 min)
    1. Define the 10-day structure with practitioner destinations
    2. List all commands/skills per day
    3. Map to certification domains and job posting %
    4. Write career_overview.txt

  Hour 1-2: Content (60 min)
    5. Write Day 1-3 lessons (free tier) — 18-24 lessons
    6. Write Day 1-3 quizzes — 24 questions
    7. Write Day 4-8 lessons — 24-40 lessons
    8. Write Day 4-8 quizzes — 40 questions

  Hour 2-3: Assessments & Challenges (60 min)
    9. Write Assessment 1 (Day 5) — intro + grading script
    10. Write Assessment 2 (Day 9) — intro + grading script
    11. Write Final Capstone (Day 10) — review + capstone + grader
    12. Write 6 challenges with lesson references
    13. Write 3 work scenarios

  Hour 3-4: Integration (30 min)
    14. Add day menus to practicum script (copy existing pattern)
    15. Add unlock chains
    16. Add mastery skills and situational awareness
    17. Test: syntax check, fresh install, full walkthrough
    18. Push and tag

# ============================================================
# PART 12: REFERENCE — LINUX FOUNDATIONS STATS
# ============================================================

Course 1 (Linux Foundations) final metrics:
  Days: 10
  Lessons: 56
  Quiz questions: 72
  Challenges: 6
  Work scenarios: 3
  Assessments: 3 (midpoint, advanced, final capstone)
  Skills tracked: 46
  Free tier: Days 1-3 (18 lessons)
  Premium: Days 4-10 (38 lessons)
  Lines of bash (engine): ~1,200
  Lines of content: ~2,500
  Build time (first course): ~12 hours (includes engine creation)
  Estimated build time (subsequent courses): 2-4 hours
