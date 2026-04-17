# Practicum CLI

**Intent. Context. Action. Result.**

A terminal-native IT training platform with 5 courses, 203 lessons, and a real-system diagnostic tool — all from the command line. No GUI. No browser. No videos.

Built by [Mpingo Systems LLC](https://github.com/emkwambe) — Precision Tools. African Roots.

## Install (one line)

```bash
curl -sL https://raw.githubusercontent.com/emkwambe/practicum-cli/main/install.sh | bash
```

Then run `practicum start`.

## Courses

| # | Course | Days | Lessons | Quiz Qs | Prerequisites |
|---|--------|------|---------|---------|---------------|
| 1 | Linux Foundations | 10 | 56 | 72 | None (start here) |
| 2 | Git & Version Control | 10 | 46 | 77 | None |
| 3 | Docker & Containers | 10 | 46 | 74 | Linux + Git |
| 4 | Shell Scripting Mastery | 8 | 31 | 61 | Linux |
| 5 | Data Forge | 8 | 24 | 78 | Linux + Shell |

**Total: 203 lessons | 361 quiz questions**

### Career Paths

```
🐧 Linux SysAdmin:    Linux → Shell → (Server Admin)
🚀 DevOps Engineer:   Linux → Git → Docker → Shell → Data Forge → (CI/CD → Terraform → K8s)
💻 Full-Stack CLI Pro: All courses
```

## IT Clinic — Diagnostic Navigator

A real-system troubleshooting tool built into the platform. Enter with `practicum field` or `practicum diagnose`.

**7 diagnostic categories | 27 subcategories | 48 functions | 2,178 lines**

```
🐢 Performance     — CPU, memory, swap, load
🌐 Network         — internet, DNS, ports, SSH, firewall, routing
💾 Storage          — disk, inodes, I/O, filesystem, mounts
⚙️  Services        — start failures, crash loops, config syntax, dependencies, Docker
🔒 Security         — permissions, sudo, SELinux/AppArmor, security audit
🔧 Hardware         — devices, drivers, kernel, SMART health
🩺 Health Check     — full system grade (A-F)
```

**Additional features:**
- `scan` — auto-detect known error patterns (disk, memory, OOM, DNS, services, SSH brute force, kernel)
- `history` — diagnostic trends over time, recurring issues, recommendations
- `report` — save timestamped diagnostic reports to `~/.practicum/reports/`

**Security:** The IT Clinic is read-only. It never modifies your system. All suggested fixes are displayed as text — never auto-applied.

## How It Works

Every lesson follows the ICAR framework:

```
[INTENT]   What are you trying to do?
[CONTEXT]  Why does this command exist? When do you need it?
[ACTION]   The exact command to run, with real examples.
[RESULT]   What you should see. What to do if it's different.
```

After each day's lessons, take a quiz. Pass to unlock the next day.

### Learning Modes

| Mode | Command | What it does |
|------|---------|-------------|
| **Wizard** | `practicum wizard` | Guided lessons with ICAR flow |
| **Lab** | `practicum lab` | Safe sandbox — commands only affect `~/.practicum/sandbox/` |
| **Field** | `practicum field` | IT Clinic — real system diagnostics with guided troubleshooting |

### Progression

```
📚 Apprenticeship  → 5 courses, 203 lessons (learn the commands)
🏋️ Internship      → challenges, scenarios, assessments (practice under pressure)
🩺 IT Clinic       → 27 diagnostic tools (solve real problems on real systems)
🎓 Credential      → certificates per course
```

## Commands

```
practicum start           Begin or resume a course
practicum status          Show progress + system health grade
practicum quiz            Take the current quiz
practicum course          Switch between courses
practicum wizard          Enter guided lesson mode
practicum lab             Enter safe sandbox mode
practicum field           Enter IT Clinic (real system diagnostics)
practicum diagnose        IT Clinic diagnostic navigator
practicum scan            Auto-detect known error patterns
practicum history         View diagnostic trends over time
practicum report          Generate and save a diagnostic report
practicum snapshot        Save/restore lab state
practicum certificate     Generate completion certificate
practicum challenges      Interactive problem-solving (Linux course)
practicum scenarios       Multi-step work scenarios (Linux course)
practicum mastery         Skill mastery dashboard (Linux course)
practicum activate <key>  Activate a license key
practicum help            Show help
```

## Pricing

| Tier | Price | What you get |
|------|-------|-------------|
| Free | $0 | Days 1-3 of any course + full IT Clinic |
| Single Course | $49 | One course, all days |
| Silver (Annual) | $129/year | All courses, 3 devices |
| Early Bird Silver | $79/year | First 200 subscribers |
| Gold (Annual) | $199/year | All courses + capstone grading |

## Requirements

- Linux, macOS, or WSL2
- Bash 4+
- No root required, no Docker, no external dependencies
- IT Clinic diagnostic commands may prompt for sudo (read-only checks only)

## Data & Privacy

Practicum CLI stores all data locally in `~/.practicum/`:

| File | Contents |
|------|----------|
| `unlocked.txt` | Lesson progress |
| `completed.txt` | Completed lessons |
| `scores.txt` | Quiz scores |
| `active_course` | Current course |
| `license.json` | License key (if activated) |
| `clinic_history.log` | Diagnostic verdicts with timestamps |
| `reports/` | Saved diagnostic reports |
| `sandbox/` | Lab mode sandbox directory |

**No telemetry. No analytics. No network calls.** Your data never leaves your machine.

**Note:** Diagnostic reports contain system information including hostnames, IP addresses, and service status. Review reports before sharing.

## License

Practicum CLI is proprietary software by Mpingo Systems LLC.
Free tier (Days 1-3) is available at no cost.
Premium content requires a license key.

See [LICENSE](LICENSE) for full terms.

## Author

**Eddy Mkwambe** — Founder, Mpingo Systems LLC
- GitHub: [emkwambe](https://github.com/emkwambe)
- Website: [practicum-cli](https://emkwambe.github.io/practicum-cli/)

## Version

Current: v2.8.0
