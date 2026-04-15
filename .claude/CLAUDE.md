# Practicum CLI

## Overview
CLI-native Linux courses. Intent → Context → Action → Result.
The foundation platform for all CLI:CE courses.

## Tech Stack
- Bash 4+ (POSIX compatible)
- Coreutils only (no jq, no Python, no Node, no Docker)
- State stored in ~/.practicum/ as plain text

## Architecture
- practicum — main entrypoint, sources all libs
- lib/state.sh — progress tracking, scores, unlocking
- lib/lessons.sh — lesson loader and listing
- lib/quiz_engine.sh — multiple-choice quiz grader
- lib/modes.sh — WIZARD/LAB/FIELD/LMS mode switching
- lib/sandbox.sh — sandbox init, snapshot, restore
- lib/wrappers.sh — ICAR display, command wrapping for LAB/WIZARD
- courses/linux-foundations/day1/ — lesson and quiz files

## Key Commands
./practicum --help
./practicum start
./practicum status
./practicum quiz
./practicum wizard
./practicum lab
./practicum field
./practicum snapshot save|restore|list

## Development
- Windows dev: use [System.IO.File]::WriteAllText() for BOM-free UTF-8
- Test with Git Bash or WSL: bash practicum status
- No cd required — use absolute paths