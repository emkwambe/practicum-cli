# Practicum CLI

**Intent. Context. Action. Result.**
Learn Linux entirely inside your terminal. No GUI. No browser. No videos.

## Install (one line)

```bash
curl -sL https://raw.githubusercontent.com/emkwambe/practicum-cli/main/install.sh | bash
```

Then run `practicum --help`.

## What You'll Learn

| Day | Topic | Commands |
|-----|-------|----------|
| 1 | Navigation & Files | pwd, ls, cd, mkdir, touch, rm |
| 2 | Text Processing & Pipes | grep, cut, sort, uniq, wc, \| |
| 3 | Scripting Basics | variables, conditionals, loops, functions, exit codes |
| 4 | Process & Environment | ps, kill, jobs, env, alias, PATH |
| 5 | Final Assessment | Write a monitoring script (capstone) |

## How It Works

Every command is explained **before** you run it:

```
[INTENT]  "Find lines that match a pattern."
[CONTEXT] You have a 500MB log file with mixed INFO/ERROR entries.
[ACTION]  grep "ERROR" server.log
[RESULT]  Only ERROR lines are printed. File is not modified.
[RISK]    Read-only (safe)
```

After each lesson, you take a quiz. Pass to unlock the next lesson.

## Modes

| Mode | What it does |
|------|-------------|
| **WIZARD** | Guided lessons with Intent→Context→Action→Result |
| **LAB** | Safe sandbox — destructive commands only affect `~/.practicum/sandbox/` |
| **FIELD** | Real system — no sandbox, warnings only |

## Commands

```
practicum start        Begin or resume the course
practicum status       Show your progress
practicum quiz         Take a quiz
practicum wizard       Enter guided mode
practicum lab          Enter sandbox mode
practicum field        Enter real system mode
practicum snapshot     Save/restore lab state
practicum certificate  Generate completion certificate
practicum final        Submit Day 5 capstone for grading
```

## Requirements

- Linux, macOS, or WSL2
- Bash 4+
- No root, no Docker, no external dependencies

## Author

**Eddy Mkwambe** — [GitHub](https://github.com/emkwambe)

Practicum CLI is a product of Mpingo Systems LLC.
