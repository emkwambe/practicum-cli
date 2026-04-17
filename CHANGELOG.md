# Changelog

All notable changes to Practicum CLI are documented here.

## [v2.8.0] — 2026-04-18

### Added
- **Data Forge course** — 24 lessons, 78 quiz questions covering jq, csvkit, xsv, sqlite3, curl, ETL pipelines
- **IT Clinic as product** — Field Mode rebuilt as diagnostic environment with 🩺 prompt
- **Error pattern scanner** — 8 auto-detection rules (disk, memory, OOM, DNS, services, SSH brute force, kernel)
- **Diagnostic history** — every verdict logged, 7-day trends, recurring issue detection, recommendations
- **Saveable reports** — timestamped diagnostic reports to `~/.practicum/reports/`
- **CLI commands** — `practicum scan`, `practicum history`, `practicum report`
- Log rotation for clinic_history.log (capped at 1000 entries)
- LICENSE file (proprietary, free tier for Days 1-3)
- CHANGELOG file

### Fixed
- CPU parsing bug in health check (3 instances — `top` output parsing)
- Health grade softened: 1 critical + high score = D (was F)
- Certificate text now course-aware (was hardcoded to "Linux Foundations")
- Dynamic day menus — blank Day 9/10 hidden for 8-day courses
- Quiz score display dynamic (was hardcoded to 8 days)

### Changed
- Field Mode prompt changed from 🌍 [FIELD] to 🩺 [CLINIC]
- Field Mode now sources diagnose.sh with 14 shell commands available
- Challenges/Scenarios/Mastery hidden for non-Linux courses
- README completely rewritten for 5-course platform

## [v2.7.0] — 2026-04-17

### Added
- **Data Forge course** (initial) — 18 lessons, 61 quiz questions
- Course registered in engine with `data-forge` slug

## [v2.6.0] — 2026-04-16

### Added
- **Shell Scripting Mastery course** — 31 lessons, 61 quiz questions, 8 days
- IT Clinic expanded to 95% — hardware/kernel category, firewall, routing, filesystem, mounts, swap
- IT Clinic closed to 100% — config syntax checker, dependency analyzer, SELinux/AppArmor
- Health score (A-F grade) integrated into `practicum status`

### Fixed
- Quality sweep — dynamic menus, course-aware certificates, Linux-only feature hiding

## [v2.5.0] — 2026-04-16

### Added
- **IT Clinic MVP** — 14 subcategories, diagnostic navigator
- Health check with A-F grading

## [v2.4.0] — 2026-04-16

### Added
- **Docker & Containers course** — 46 lessons, 74 quiz questions, 10 days

## [v2.3.0] — 2026-04-16

### Added
- Multi-course platform engine
- Course switcher (`practicum course`)
- Per-course day titles, unlock chains, career overviews
- `get_course_name()`, `set_active_course()`, `list_available_courses()`

## [v2.0.0] — 2026-04-15

### Added
- **Git & Version Control course** — 46 lessons, 77 quiz questions, 10 days

## [v1.0.0] — 2026-04-14

### Added
- **Linux Foundations course** — 56 lessons, 72 quiz questions, 10 days
- ICAR pedagogical framework
- Wizard, Lab, and Field modes
- Quiz engine with scoring
- Certificate generation
- Challenge engine (6 Linux-specific challenges)
- Work scenarios
- Skill mastery dashboard
- License gating (Days 1-3 free)
- One-line installer
- Landing page at GitHub Pages
