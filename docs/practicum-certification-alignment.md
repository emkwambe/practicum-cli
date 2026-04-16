# Practicum CLI — Certification Exam Alignment Guide
# Mpingo Systems LLC
#
# Maps every Practicum CLI lesson to official certification exam objectives.
# Use this to prove alignment, market to students, and identify gaps.
#
# Target certifications:
#   Course 1 (Linux): LFCS + CompTIA Linux+ XK0-005/XK0-006
#   Course 2 (Git): GitHub Foundations
#   Course 3 (Docker): DCA (Docker Certified Associate)
#   Course 5 (K8s): CKA / CKAD

# ============================================================
# CERTIFICATION 1: LFCS (Linux Foundation Certified Sysadmin)
# ============================================================
#
# Exam: Performance-based, 2 hours, 17-20 tasks, 67% to pass
# Cost: $445 (exam only), $645 (exam + LFS207 course)
# Valid: 24 months
# Format: Live Linux shell, distribution-agnostic
#
# Official domains and weights (2026):
#   Essential Commands    — 20%
#   Operations Deployment — 25%
#   Networking            — 25%
#   Storage               — 20%
#   Users and Groups      — 10%

## LFCS Domain 1: Essential Commands (20% of exam)

Objective                                          | Practicum Day | Lesson(s)           | Status
---------------------------------------------------|---------------|---------------------|--------
Navigate the filesystem (cd, pwd, ls)              | Day 1         | 1-3 (pwd, ls, cd)   | ✅ Full
Create, delete, copy, move files and dirs          | Day 1         | 4-6 (mkdir,touch,rm) | ✅ Full
Search for files (find, locate)                    | Day 4         | 7 (find)             | ✅ Full
Evaluate and compare basic file types              | Day 1         | 2 (ls -la)           | ✅ Full
Compare text files (diff, comm)                    | —             | —                    | ⚠️ Gap
Use input/output redirection (>, >>, |, 2>)        | Day 2         | 6 (pipes)            | ✅ Full
Analyze text (grep, awk, sed, sort, uniq, cut, wc) | Day 2         | 1-8 (all)            | ✅ Full
Archive and compress files (tar, gzip, bzip2)      | Day 7         | 7 (tar)              | ✅ Full
Create and manage soft/hard links                  | —             | —                    | ⚠️ Gap
List, set, and change file permissions              | Day 6         | 1-3 (chmod, chown)   | ✅ Full
Read/use system documentation (man, info)          | —             | —                    | ⚠️ Gap

Coverage: 8/11 objectives = 73%
Gaps to add: diff/comm, symlinks (ln -s), man pages

## LFCS Domain 2: Operations Deployment (25% of exam)

Objective                                          | Practicum Day | Lesson(s)            | Status
---------------------------------------------------|---------------|----------------------|--------
Boot, reboot, shut down system                     | Day 8         | 1 (systemctl)        | ✅ Partial
Boot into different targets (runlevels)            | —             | —                    | ⚠️ Gap
Install, configure, troubleshoot bootloaders       | —             | —                    | ⚠️ Gap
Manage system processes (ps, kill, top, nice)       | Day 4         | 1-3 (ps, kill, jobs) | ✅ Full
Manage startup services (systemctl enable/disable) | Day 8         | 1 (systemctl)        | ✅ Full
Schedule tasks (cron, at)                          | Day 8         | 3 (cron)             | ✅ Full
Verify completion of scheduled jobs                | Day 8         | 3,7 (cron, logs)     | ✅ Full
Manage software packages (apt, yum, dnf)           | Day 7         | 6 (apt)              | ✅ Full
Verify integrity of packages                       | —             | —                    | ⚠️ Gap
Manage kernel modules/runtime parameters           | —             | —                    | ⚠️ Gap
Update/manage software to improve functionality    | Day 7         | 6 (apt upgrade)      | ✅ Full
Create and manage local user accounts              | Day 6         | 4-5 (useradd,groups) | ✅ Full
Configure environment profiles                     | Day 4         | 4-6 (env,alias,PATH) | ✅ Full

Coverage: 9/13 objectives = 69%
Gaps: Bootloaders (GRUB), runlevels/targets, kernel modules, package integrity

## LFCS Domain 3: Networking (25% of exam)

Objective                                          | Practicum Day | Lesson(s)            | Status
---------------------------------------------------|---------------|----------------------|--------
Configure networking and hostname resolution       | Day 7         | 1 (ip)               | ✅ Full
Configure network services to start at boot        | Day 8         | 1 (systemctl enable) | ✅ Full
Implement packet filtering (iptables/nftables)     | —             | —                    | ⚠️ Gap
Configure firewall settings                        | —             | —                    | ⚠️ Gap
Start, stop, status of network services            | Day 8         | 1 (systemctl)        | ✅ Full
Statically route IP traffic                        | —             | —                    | ⚠️ Gap
Synchronize time using NTP                         | —             | —                    | ⚠️ Gap
Troubleshoot network issues (ss, ping, traceroute) | Day 7         | 2,3,8 (ping,ss,diag) | ✅ Full
Configure SSH (ssh-keygen, sshd_config)            | Day 7         | 4 (ssh)              | ✅ Full
Transfer files securely (scp, rsync)               | Day 7         | 5 (scp/rsync)        | ✅ Full

Coverage: 6/10 objectives = 60%
Gaps: Firewalls (iptables/ufw), static routing, NTP

## LFCS Domain 4: Storage (20% of exam)

Objective                                          | Practicum Day | Lesson(s)            | Status
---------------------------------------------------|---------------|----------------------|--------
List, create, delete partitions on disks           | —             | —                    | ❌ Not covered
Create and manage volumes (LVM)                    | —             | —                    | ❌ Not covered
Create and configure file systems (mkfs, ext4)     | —             | —                    | ❌ Not covered
Mount/unmount filesystems (mount, fstab)           | —             | —                    | ❌ Not covered
Configure swap space                              | —             | —                    | ❌ Not covered
Manage and configure NFS                           | —             | —                    | ❌ Not covered
Check disk usage (du, df)                          | Day 4         | 8 (du/df)            | ✅ Full
Manage RAID devices                                | —             | —                    | ❌ Not covered

Coverage: 1/8 objectives = 12%
NOTE: Storage is our biggest gap. This maps to Course 7 (Server Administration).

## LFCS Domain 5: Users and Groups (10% of exam)

Objective                                          | Practicum Day | Lesson(s)            | Status
---------------------------------------------------|---------------|----------------------|--------
Create, delete, modify local user accounts         | Day 6         | 4 (useradd)          | ✅ Full
Create, delete, modify local groups                | Day 6         | 5 (groups)           | ✅ Full
Manage system-wide environment profiles            | Day 4         | 4-6 (env,alias,PATH) | ✅ Full
Manage user privileges (sudo, visudo)              | Day 6         | 6 (sudo)             | ✅ Full
Configure PAM                                      | —             | —                    | ⚠️ Gap

Coverage: 4/5 objectives = 80%
Gaps: PAM (Pluggable Authentication Modules)

## LFCS Overall Coverage Summary

Domain                    | Weight | Coverage | Score (weight × coverage)
--------------------------|--------|----------|-------------------------
Essential Commands        | 20%    | 73%      | 14.6%
Operations Deployment     | 25%    | 69%      | 17.3%
Networking                | 25%    | 60%      | 15.0%
Storage                   | 20%    | 12%      | 2.4%
Users and Groups          | 10%    | 80%      | 8.0%
                          |        |          |
**Weighted Total**        | **100%** |        | **57.3%**

Passing score: 67%
Current coverage: 57.3% — CLOSE but not passing
With Server Administration course (Course 7): ~80%+ — PASSING with margin

### Critical gaps to close for LFCS pass guarantee:
1. Storage (LVM, mount, fstab, partitions) — Course 7 Day 4
2. Firewalls (iptables/ufw) — Course 7 Day 3
3. man pages, diff, symlinks — can add to Linux Foundations Day 1-2
4. Bootloader/GRUB — Course 7

# ============================================================
# CERTIFICATION 2: CompTIA Linux+ (XK0-005 / XK0-006)
# ============================================================
#
# Exam: 90 questions (MCQ + performance-based), 90 minutes
# Cost: $369
# Passing: 720/900
# Valid: 3 years
#
# XK0-005 Domains (retiring Jan 2026, replaced by XK0-006):
#   1.0 System Management          — 32%
#   2.0 Security                   — 21%
#   3.0 Scripting/Containers/Auto  — 19%
#   4.0 Troubleshooting            — 28%
#
# XK0-006 Domains (new, effective July 2025):
#   Adds: Ansible, Python basics, Git, AI best practices

## Linux+ Domain 1: System Management (32%)

Objective                              | Practicum Coverage | Status
---------------------------------------|-------------------|--------
1.1 Linux fundamentals (FHS, boot)     | Day 1 (partial)   | ⚠️ Partial
1.2 Manage files and directories       | Day 1, Day 4      | ✅ Full
1.3 Configure and manage storage       | —                 | ❌ Gap
1.4 Configure and manage processes     | Day 4             | ✅ Full
1.5 Manage services (systemd)          | Day 8             | ✅ Full
1.6 Build and install software         | Day 7             | ✅ Full
1.7 Manage software configurations     | Day 4 (env, PATH) | ✅ Full

Coverage: 5/7 = 71%

## Linux+ Domain 2: Security (21%)

Objective                              | Practicum Coverage | Status
---------------------------------------|-------------------|--------
2.1 Linux security fundamentals        | Day 6             | ✅ Full
2.2 Identity management                | Day 6             | ✅ Full
2.3 Permissions (files, dirs, special) | Day 6             | ✅ Full
2.4 Firewalls (iptables, ufw)          | —                 | ❌ Gap
2.5 Access controls (ACLs, SELinux)    | —                 | ⚠️ Gap
2.6 Logging and auditing               | Day 8             | ✅ Full

Coverage: 4/6 = 67%

## Linux+ Domain 3: Scripting, Containers, Automation (19%)

Objective                              | Practicum Coverage | Status
---------------------------------------|-------------------|--------
3.1 Shell scripts (bash)               | Day 3             | ✅ Full
3.2 Script arguments and I/O           | Day 3             | ✅ Full
3.3 Conditionals and loops             | Day 3             | ✅ Full
3.4 Version control (Git basics)       | —                 | ❌ Course 2
3.5 Container operations (Docker)      | —                 | ❌ Course 3
3.6 Container orchestration concepts   | —                 | ❌ Course 5

Coverage: 3/6 = 50% (but 100% for bash scripting portion)

## Linux+ Domain 4: Troubleshooting (28%)

Objective                              | Practicum Coverage | Status
---------------------------------------|-------------------|--------
4.1 Storage troubleshooting            | Day 4 (du/df)     | ⚠️ Partial
4.2 Network troubleshooting            | Day 7 (full diag) | ✅ Full
4.3 Process troubleshooting            | Day 4 (ps, kill)  | ✅ Full
4.4 User/permission troubleshooting    | Day 6             | ✅ Full
4.5 Application troubleshooting        | Day 8 (logs)      | ✅ Full

Coverage: 4/5 = 80%

## Linux+ Overall Coverage

Domain                        | Weight | Coverage
------------------------------|--------|----------
System Management             | 32%    | 71%
Security                      | 21%    | 67%
Scripting/Containers/Auto     | 19%    | 50%
Troubleshooting               | 28%    | 80%
**Weighted Total**            |        | **68%**

Passing requires 720/900 = ~80%
Current course alone: ~68% coverage
With Git + Docker courses: ~85%+ — PASSING

# ============================================================
# CERTIFICATION 3: GitHub Foundations (Course 2 target)
# ============================================================
#
# Exam: 75 questions, 120 minutes, 70% to pass
# Cost: $99
# Topics: Git basics, GitHub features, collaboration, security

## GitHub Foundations Domains

Domain                                 | Practicum Course 2 Day | Status
---------------------------------------|------------------------|--------
Introduction to Git and GitHub         | Day 1                  | Planned
Working with GitHub Repositories       | Day 2-3                | Planned
Collaboration Features                 | Day 4                  | Planned
Modern Development (Actions, Copilot)  | Day 7                  | Planned
Project Management (Issues, Projects)  | Day 7                  | Planned
Privacy, Security, Administration      | Day 6                  | Planned

# ============================================================
# CERTIFICATION 4: DCA — Docker Certified Associate (Course 3)
# ============================================================
#
# Exam: 55 questions, 90 minutes
# Topics: Image creation, orchestration, networking, security

## DCA Domains

Domain                                 | Practicum Course 3 Day | Status
---------------------------------------|------------------------|--------
Image creation and management          | Day 2-3                | Planned
Container operations                   | Day 1                  | Planned
Orchestration (Swarm/Compose)          | Day 4                  | Planned
Networking                             | Day 3                  | Planned
Security                               | Day 7                  | Planned
Storage and volumes                    | Day 3                  | Planned

# ============================================================
# CERTIFICATION 5: CKA — Certified Kubernetes Admin (Course 5)
# ============================================================
#
# Exam: Performance-based, 2 hours, 66% to pass
# Cost: $395
# Topics: Cluster architecture, workloads, services, storage

## CKA Domains

Domain                                 | Practicum Course 5 Day | Status
---------------------------------------|------------------------|--------
Cluster Architecture (25%)             | Day 1                  | Planned
Workloads & Scheduling (15%)           | Day 2, 7               | Planned
Services & Networking (20%)            | Day 3                  | Planned
Storage (10%)                          | Day 6                  | Planned
Troubleshooting (30%)                  | Day 8                  | Planned

# ============================================================
# ACTION ITEMS — Gaps to Close
# ============================================================

## Immediate (add to Linux Foundations v2.2):
  [ ] Add lesson on man pages (Day 1 or Day 2)
  [ ] Add lesson on diff/comm (Day 2)
  [ ] Add ln -s to Day 1 mkdir lesson or new lesson
  [ ] Add note about /etc/resolv.conf in Day 7 networking

## Course 7 (Server Administration) — closes LFCS storage gap:
  [ ] LVM (create, extend, reduce)
  [ ] Partitions (fdisk, parted, gdisk)
  [ ] Filesystems (mkfs, ext4, xfs)
  [ ] mount/umount, fstab
  [ ] Firewalls (ufw, iptables basics)
  [ ] GRUB bootloader basics

## Marketing claim after gaps are closed:
  "Practicum CLI covers 85%+ of LFCS exam objectives and
   95%+ of CompTIA Linux+ XK0-005 exam objectives.
   Students who complete the Linux Foundations + Server
   Administration courses are fully prepared to pass both exams."

## Student success metric:
  Track: "How many Practicum CLI students passed LFCS or Linux+?"
  Goal: 70%+ first-attempt pass rate → this becomes your best marketing
