# Practicum CLI – Development Blueprint

**Version:** 1.0  
**Role:** Software Architect / Curriculum Developer / Co‑Instructional Designer / Co‑PM / Prompt Engineer  
**Human in the loop:** Eddy Mkwambe  

---

## Table of Contents

1. [Project Philosophy & Guardrails](#philosophy--guardrails)  
2. [Product Overview](#product-overview)  
3. [High‑Level Architecture](#high-level-architecture)  
4. [Development Phases & Sprints](#development-phases--sprints)  
5. [Quality Gates & Checklists](#quality-gates--checklists)  
6. [Workflow with Claude Code](#workflow-with-claude-code)  
7. [Initial Setup Instructions](#initial-setup-instructions)  
8. [Appendix: Templates & Examples](#appendix-templates--examples)  

---

## Philosophy & Guardrails

### Core Philosophy

1. **Intent → Context → Action → Result**  
   Every user interaction must show *why* they need a command, the current situation, what will happen, and what actually happened. No blind typing.

2. **Zero‑dependency, pure CLI**  
   Practicum CLI runs on bare Linux/macOS/WSL with only POSIX tools and bash. No Docker, no Node, no Python, no external services unless strictly required (payments are handled via browser out‑of‑band).

3. **Pedagogy first, code second**  
   All technical decisions serve the learning outcome. If a feature doesn't help a student understand Linux, it doesn't belong.

4. **State is visible and persistent**  
   The student always knows where they are, what they've done, and what's next. Progress is saved in `~/.practicum/` and is human‑readable.

5. **Fail safely, recover instantly**  
   Sandbox mode (LAB) must allow destructive experimentation with one‑command reset. FIELD mode must have guardrails (warnings) but no blocks.

### Guardrails (Non‑Negotiable Rules)

| ID | Rule |
|----|------|
| G1 | Never run a command without showing the [INTENT], [CONTEXT], [ACTION], and [RESULT] **before execution** (WIZARD mode). |
| G2 | Never delete or modify files outside the sandbox when in LAB mode. |
| G3 | Every destructive command (rm, kill, mv overwrite) must require confirmation in WIZARD and LAB modes. |
| G4 | No external dependencies for core functionality. Payment handling is the only exception, and it must be out‑of‑band (browser). |
| G5 | All student progress must be stored in `~/.practicum/` as plain text (JSON or newline‑separated). No binary formats. |
| G6 | Every lesson must include at least one [WHEN] scenario explaining real‑world use. |
| G7 | Every quiz must be answerable without internet, using only the terminal. |
| G8 | The CLI must work over a 9600 baud serial connection (no ANSI color required, but allowed). |
| G9 | No command should take longer than 200ms to respond (excluding intentional long operations like `find /`). |
| G10 | The student can always type `menu`, `back`, or `status` to escape confusion. |

---

## Product Overview

### What is Practicum CLI?

A complete short‑course platform delivered entirely inside the terminal. It teaches Linux command line through:

- **Wizard mode** – Step‑by‑step guided lessons with phone‑menu navigation.
- **LMS mode** – Progress tracking, quizzes, certificates.
- **Lab mode** – Safe sandbox with snapshots and undo.
- **Field mode** – Real system execution with guardrails.

### Target Audience (Primary)

- IT professionals new to Linux  
- DevOps / Cloud engineers needing CLI fluency  
- Students in bootcamps or university CS programs  
- Corporate teams standardising Linux skills  

### Launch Course (Rank 1 – Highest Business Opportunity)

**Linux Foundations for IT & DevOps**  
- Duration: 20 hours  
- Modules: Navigation, files, processes, permissions, text tools (grep/awk/sed basics), bash scripting basics  
- Output: Automation script + certificate  

---

## High‑Level Architecture

### Components

```
practicum (bash entrypoint)
├── commands/
│   ├── start      – initialise course, show menu
│   ├── status     – show progress
│   ├── quiz       – run quiz engine
│   ├── lab        – enter sandbox mode
│   ├── field      – enter real mode
│   ├── wizard     – enter guided mode
│   ├── snapshot   – save/restore lab state
│   └── activate   – license key (payment)
├── lib/
│   ├── wrappers.sh    – command overrides (rm, mkdir, cd, etc.)
│   ├── state.sh       – read/write progress, unlocked lessons
│   ├── sandbox.sh     – manage ~/.practicum/sandbox/
│   ├── quiz_engine.sh – ask questions, grade, unlock
│   └── menu.sh        – phone‑tree navigation
├── courses/
│   └── linux-foundations/
│       ├── day1/
│       │   ├── lesson.txt
│       │   ├── quiz.txt
│       │   └── exercises/
│       └── ...
└── .claude/           – context for Claude Code (will be created)
```

### State Storage

All under `~/.practicum/`:

```
~/.practicum/
├── config              – user preferences, mode
├── progress.json       – completed lessons, quiz scores
├── unlocked.txt        – one lesson per line
├── sandbox/            – virtual root for LAB mode
├── snapshots/          – timestamped copies of sandbox
└── license.json        – payment activation
```

---

## Development Phases & Sprints

We will build in **four phases**, each containing multiple sprints.  
Each sprint produces a working, testable increment.

### Phase 0 – Foundation (CLI skeleton & state management)

| Sprint | Goal | Deliverable | Checklist |
|--------|------|-------------|-----------|
| 0.1 | Create project structure, `practicum` entrypoint | Bash script that prints "Practicum CLI v0.1" | [ ] Runs without errors<br>[ ] Accepts `--help` |
| 0.2 | Implement `~/.practicum/` state directory | `practicum init` creates folder with defaults | [ ] Creates all subdirs<br>[ ] Sets correct permissions (700) |
| 0.3 | Add `practicum status` | Shows progress (empty course) | [ ] Reads/writes progress.json<br>[ ] Handles missing files gracefully |
| 0.4 | Add mode switching (`wizard`, `lab`, `field`, `lms`) | Sets `PRACTICUM_MODE` env var, changes prompt | [ ] Each mode changes PS1<br>[ ] Mode persists across commands |

### Phase 1 – Core Pedagogic Engine (Intent → Context → Action → Result)

| Sprint | Goal | Deliverable | Checklist |
|--------|------|-------------|-----------|
| 1.1 | Command wrapper framework | `lib/wrappers.sh` overrides `cd`, `ls`, `mkdir`, `touch`, `rm` | [ ] Overrides only when PRACTICUM_MODE=LAB or WIZARD<br>[ ] Passes through in FIELD |
| 1.2 | Implement [INTENT] resolution | Map natural language intents to commands (phase 2 of earlier design) | [ ] Student can type "where am I" → suggests `pwd`<br>[ ] Shows [WHEN] scenarios |
| 1.3 | Pre‑execution display | Before any command, show [INTENT], [CONTEXT], [ACTION], [RESULT] (predicted) | [ ] Uses current state (pwd, files, disk)<br>[ ] Asks "Execute? (y/n)" |
| 1.4 | Post‑execution menu | After command, show numbered next moves (1‑9, 0=exit, 9=back) | [ ] Dynamic menu based on command just run<br>[ ] Accepts numbers or raw commands |

### Phase 2 – Course Content: Linux Foundations (Rank 1)

| Sprint | Goal | Deliverable | Checklist |
|--------|------|-------------|-----------|
| 2.1 | Lesson structure & loader | `practicum start` loads `courses/linux-foundations/day1/lesson.txt` | [ ] Displays lesson in `less` or paginated<br>[ ] Tracks completion |
| 2.2 | Day 1 – Navigation & Files | Lessons: pwd, ls, cd, mkdir, touch, rm (safe) | [ ] Each lesson includes [WHEN]<br>[ ] Hands‑on exercises with auto‑grading |
| 2.3 | Day 2 – Text Processing & Pipes | grep, cut, sort, uniq, wc, pipe compositions | [ ] Exercises use hidden test files<br>[ ] Student writes pipelines |
| 2.4 | Day 3 – Scripting Basics | Variables, conditionals, loops, functions, exit codes | [ ] Student writes `backup.sh`<br>[ ] Automated tests pass |
| 2.5 | Day 4 – Process & Environment | ps, kill, bg, fg, jobs, env, alias, PATH | [ ] Can start/stop background processes<br>[ ] Modifies PATH safely |
| 2.6 | Day 5 – Integration & Final Assessment | Capstone script + timed quiz | [ ] Script passes hidden tests<br>[ ] Quiz score ≥80% unlocks certificate |

### Phase 3 – LMS & Gamification

| Sprint | Goal | Deliverable | Checklist |
|--------|------|-------------|-----------|
| 3.1 | Quiz engine | `practicum quiz` asks multiple‑choice, records score | [ ] Questions from course/<day>/quiz.txt<br>[ ] Stores score in progress.json |
| 3.2 | Lesson gating | `rm` locked until Day 1 quiz passed | [ ] Gate check in wrapper<br>[ ] `practicum status` shows locked/unlocked |
| 3.3 | Badges | ASCII badges for milestones (First Command, Folder Master) | [ ] Displayed after achievement<br>[ ] Stored in progress.json |
| 3.4 | Certificate generation | OpenSSL self‑signed certificate with SHA256 hash | [ ] `practicum certificate` prints ASCII art + hash<br>[ ] Hash includes student name + date |

### Phase 4 – Sandbox & Lab Enhancements

| Sprint | Goal | Deliverable | Checklist |
|--------|------|-------------|-----------|
| 4.1 | LAB mode sandbox | All commands redirect to `~/.practicum/sandbox/` | [ ] `cd /` goes to sandbox root<br>[ ] Real system untouched |
| 4.2 | Snapshot / Undo | `practicum snapshot save <name>` and `restore` | [ ] Uses `cp -r` (no dependencies)<br>[ ] Works across sessions |
| 4.3 | Dry‑run mode | `practicum dry-run "rm -rf /"` shows predicted result | [ ] Simulates without execution<br>[ ] Shows files that would be deleted |

### Phase 5 – Payment & Licensing (Out‑of‑Band)

| Sprint | Goal | Deliverable | Checklist |
|--------|------|-------------|-----------|
| 5.1 | License key activation | `practicum activate <key>` validates offline (signed JWT or simple HMAC) | [ ] Stores in `~/.practicum/license.json`<br>[ ] Rejects invalid keys |
| 5.2 | Purchase URL generator | `practicum purchase` prints a unique checkout URL (calls a simple backend) | [ ] URL expires after 1 hour<br>[ ] Opens browser automatically if possible |
| 5.3 | License validation in commands | Paid courses check license before starting | [ ] Soft check (local), periodic online re‑validation |

### Phase 6 – Polish & Release

| Sprint | Goal | Deliverable | Checklist |
|--------|------|-------------|-----------|
| 6.1 | Installer script | One‑line `curl | bash` install | [ ] Works on Ubuntu, macOS, WSL<br>[ ] Adds `practicum` to PATH |
| 6.2 | Documentation | `man practicum` or `practicum --help` | [ ] Covers all commands<br>[ ] Examples for each mode |
| 6.3 | Beta test with 5 users | Collect feedback on confusion points | [ ] Iterate on [WHEN] scenarios<br>[ ] Fix any sandbox escape bugs |
| 6.4 | Launch | GitHub repo + landing page | [ ] README with demo GIF<br>[ ] First 10 paid users |

---

## Quality Gates & Checklists

### For Every Sprint Completion

Before marking a sprint as done, verify:

- [ ] **Build / syntax** – `bash -n practicum` passes  
- [ ] **No new dependencies** – `ldd` on any binary? (none)  
- [ ] **State persistence** – restarting the CLI retains progress  
- [ ] **Mode switching** – wizard/lab/field/lms each behave correctly  
- [ ] **Destructive command guard** – `rm` in WIZARD asks for confirmation  
- [ ] **`.claude/` docs updated** – at least `CURRENT.md` and `HANDOFF.md`  
- [ ] **Commit message follows convention** – `type: description`  

### Integration Test Checklist (After Each Phase)

- [ ] Fresh install on Ubuntu 22.04 – works  
- [ ] Fresh install on macOS (Intel) – works  
- [ ] Fresh install on WSL2 (Ubuntu) – works  
- [ ] Student can complete Day 1 without errors  
- [ ] Sandbox reset (`rm -rf ~/.practicum/sandbox`) doesn't break anything  
- [ ] Quiz scores persist after closing terminal  

---

## Workflow with Claude Code

### Roles & Handoffs

```
Eddy runs Claude Code CLI with prompts I write.
I (Claude Chat) act as:
  - Software Architect – design decisions
  - Curriculum Developer – lesson content, [WHEN] scenarios
  - Co‑Instructional Designer – pedagogy, flow
  - Co‑PM – track sprints, adjust priorities
  - Prompt Engineer – write precise prompts for Claude Code
```

### Standard Cycle

1. **I write a sprint prompt** (based on blueprint above).  
2. **Eddy runs it** in Claude Code (inside the repo).  
3. **Claude Code executes** – reads `.claude/` context, writes code, runs tests.  
4. **Eddy shares results** (screenshot or paste).  
5. **I interpret** – did it pass checklist? Any errors?  
6. **I either**:
   - Accept and move to next sprint, or  
   - Write a correction prompt (with specific fixes).  
7. **Repeat** until sprint complete.

### Prompt Template for a Sprint

```markdown
Read .claude/CLAUDE.md and .claude/CURRENT.md for context.

## Sprint: [Phase.Sprint] – [Name]
**Goal:** [One sentence]

### Tasks
1. [Specific task 1]
2. [Specific task 2]

### Files to create/modify
- `path/to/file` – [what to do]

### Acceptance Checklist (must all pass)
- [ ] [Check 1]
- [ ] [Check 2]

### Verification
- Run `[command]` and expect `[output]`

### Commit message
`[type]: [description]`

### After completion
Update .claude/CURRENT.md with progress.
```

### Example Sprint Prompt (Sprint 0.1)

```markdown
Read .claude/CLAUDE.md and .claude/CURRENT.md for context.

## Sprint: 0.1 – Project skeleton
**Goal:** Create the main `practicum` bash script and basic help.

### Tasks
1. Create `practicum` in repo root with shebang `#!/bin/bash`
2. Add `--help` flag that prints usage: 
   ```
   Practicum CLI – Linux terminal courses
   Usage: practicum {start|status|quiz|lab|field|wizard|activate}
   ```
3. Make script executable (`chmod +x practicum`)
4. Create empty directories: `lib/`, `courses/`, `.claude/`

### Acceptance Checklist
- [ ] `./practicum --help` prints usage without errors
- [ ] Running without arguments shows same help
- [ ] Directories exist

### Verification
```bash
./practicum --help
```
Expected exit code 0.

### Commit message
`chore: add practicum skeleton and help`

### After completion
Update .claude/CURRENT.md with "Sprint 0.1 complete".
```

---

## Initial Setup Instructions (for Eddy)

Follow these steps to create the local repo and introduce Claude Code.

### Step 1 – Create local repository

```bash
mkdir practicum-cli
cd practicum-cli
git init
```

### Step 2 – Create the `.claude/` folder and initial context files

Create the following files manually (or let me write the prompts for Claude Code to do it).  
I recommend Eddy runs this first Claude Code prompt:

```bash
claude "Read the blueprint at the URL below (or paste it). Then create .claude/CLAUDE.md, .claude/CURRENT.md, .claude/BACKLOG.md, .claude/HANDOFF.md based on the project described. Also create the skeleton directories: lib/, courses/linux-foundations/day1/. Make the main practicum script with --help as described in Sprint 0.1."
```

But better: I will write the exact prompt after this blueprint is saved.

### Step 3 – Commit initial structure

```bash
git add .
git commit -m "chore: initial practicum-cli structure"
```

### Step 4 – Share the blueprint with Claude Code

Save this blueprint as `PRACTICUM-CLI-BLUEPRINT.md` in the repo root.  
Then Claude Code can read it via:

```markdown
Read PRACTICUM-CLI-BLUEPRINT.md for the full development plan. Then read .claude/CLAUDE.md. Start with Sprint 0.1.
```

---

## Appendix: Templates & Examples

### A. Example Lesson File (`courses/linux-foundations/day1/lesson-pwd.txt`)

```
# Lesson: pwd – Print Working Directory

## [WHEN] You need this when:
1. You just logged into a server and forgot where you are.
2. A script says "file not found" and you need to confirm the path.
3. You've used `cd` several times and are lost.

## [INTENT] "Where am I?"

## [ACTION] pwd

## [EXPECTED RESULT]
Shows the absolute path of the current directory.

## Try it:
Type `pwd` now.

> After running, you will see a path like `/home/student`.

## Next:
Type `menu` to continue or `ls` to see what's here.
```

### B. Example Quiz File (`courses/linux-foundations/day1/quiz.txt`)

```
Q1: What command shows your current directory?
A) ls
B) pwd
C) cd
D) whoami
Correct: B

Q2: Which command lists files including hidden ones?
A) ls
B) ls -a
C) ls -l
D) list --all
Correct: B
```

### C. Example Wrapper Function (`lib/wrappers.sh` excerpt)

```bash
rm() {
    if [[ "$PRACTICUM_MODE" == "LAB" || "$PRACTICUM_MODE" == "WIZARD" ]]; then
        echo "🔒 [SANDBOX] rm $*"
        local target="$HOME/.practicum/sandbox/$1"
        if [[ -e "$target" ]]; then
            command rm "$target"
            echo "   Removed: $target"
        else
            echo "   File not in sandbox. No action."
        fi
    else
        command rm "$@"
    fi
}
```

