# Handoff Notes

## Last Session: April 14, 2026
- Built complete platform: state, lessons, quiz, modes, sandbox, wrappers
- Claude Code cloud environment crashed twice due to zombie processes
- Recovery done via local PowerShell using [System.IO.File]::WriteAllText()
- All code is pure bash, no external dependencies

## Current State
- All lib/*.sh files created and populated
- 6 lesson files for Day 1 (pwd, ls, cd, mkdir, touch, rm)
- Quiz with 5 questions
- Main practicum script sources all libs and implements all commands

## Known Issues
- Interactive commands (wizard, lab, field) spawn bash subshells
  Use echo "input" | bash practicum wizard for non-interactive testing
- Quiz reads from stdin — pipe answers for testing
- No badge system yet
- No certificate generation yet
- No payment/licensing yet

## Next Session Should
1. Test all commands in a real bash environment
2. Fix any bugs found during testing
3. Begin Day 2 content (text processing)
4. Add .gitignore for ~/.practicum/ artifacts