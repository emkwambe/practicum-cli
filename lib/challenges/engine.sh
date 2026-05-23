#!/bin/bash
# Practicum CLI — Challenge Engine
# Each challenge maps to specific lessons. Feedback references those lessons.

CHALLENGE_DIR="$HOME/.practicum/challenges"
CHALLENGE_SANDBOX="$HOME/.practicum/challenge_sandbox"

init_challenge_env() {
    mkdir -p "$CHALLENGE_DIR" "$CHALLENGE_SANDBOX"
}

# ============================================
# Challenge-Lesson Mapping
# ============================================
# Each challenge lists the lessons required to solve it.
# Used in pass/fail feedback.

get_challenge_lessons() {
    local challenge_id="$1"
    case "$challenge_id" in
        find_the_error)
            echo "Day 2 Lesson 1 (grep), Day 2 Lesson 7 (sed)"
            ;;
        permission_fix)
            echo "Day 3 Lesson 6 (exit codes/chmod), Day 1 Lesson 2 (ls -la for permissions)"
            ;;
        log_detective)
            echo "Day 2 Lesson 1 (grep), Day 2 Lesson 2 (cut), Day 2 Lesson 3 (sort), Day 2 Lesson 4 (uniq), Day 2 Lesson 6 (pipes)"
            ;;
        process_cleanup)
            echo "Day 4 Lesson 1 (ps), Day 4 Lesson 2 (kill)"
            ;;
        disk_space_crisis)
            echo "Day 4 Lesson 7 (find), Day 4 Lesson 8 (du/df), Day 1 Lesson 6 (rm)"
            ;;
        pipeline_builder)
            echo "Day 2 Lesson 1 (grep), Day 2 Lesson 2 (cut), Day 2 Lesson 3 (sort), Day 2 Lesson 4 (uniq), Day 2 Lesson 5 (wc), Day 2 Lesson 8 (head/tail)"
            ;;
    esac
}

get_challenge_hint() {
    local challenge_id="$1"
    case "$challenge_id" in
        find_the_error)
            echo "Use 'grep' to find the error in the log, then 'sed -i' to fix the config."
            echo "Review: Day 2 Lesson 1 (grep) and Day 2 Lesson 7 (sed)"
            ;;
        permission_fix)
            echo "Use 'ls -la' to check permissions, then 'chmod +x' to make it executable."
            echo "Review: Day 1 Lesson 2 (ls) and Day 3 Lesson 6 (exit codes/chmod)"
            ;;
        log_detective)
            echo "Build a pipeline: grep '401' | cut -d' ' -f1 | sort | uniq -c | sort -rn"
            echo "Review: Day 2 Lessons 1-6 (grep, cut, sort, uniq, wc, pipes)"
            ;;
        process_cleanup)
            echo "Use 'ps aux | grep crypto_miner' to find it, then 'kill <PID>' to stop it."
            echo "Review: Day 4 Lesson 1 (ps) and Day 4 Lesson 2 (kill)"
            ;;
        disk_space_crisis)
            echo "Use 'du -sh *' to find large items, 'find . -size +50k' to locate big files."
            echo "Review: Day 4 Lesson 7 (find) and Day 4 Lesson 8 (du/df)"
            ;;
        pipeline_builder)
            echo "Use 'tail -n +2' to skip headers, 'cut' for columns, 'sort | uniq -c' for counting."
            echo "Review: Day 2 Lessons 1-6 and Day 2 Lesson 8 (head/tail)"
            ;;
    esac
}

# ============================================
# Challenge Setup Functions
# ============================================

setup_challenge() {
    local challenge_id="$1"
    rm -rf "$CHALLENGE_SANDBOX"
    mkdir -p "$CHALLENGE_SANDBOX"
    
    case "$challenge_id" in
        find_the_error)    setup_find_the_error ;;
        permission_fix)    setup_permission_fix ;;
        log_detective)     setup_log_detective ;;
        process_cleanup)   setup_process_cleanup ;;
        disk_space_crisis) setup_disk_space_crisis ;;
        pipeline_builder)  setup_pipeline_builder ;;
        *) echo "Unknown challenge: $challenge_id"; return 1 ;;
    esac
}

verify_challenge() {
    local challenge_id="$1"
    case "$challenge_id" in
        find_the_error)    verify_find_the_error ;;
        permission_fix)    verify_permission_fix ;;
        log_detective)     verify_log_detective ;;
        process_cleanup)   verify_process_cleanup ;;
        disk_space_crisis) verify_disk_space_crisis ;;
        pipeline_builder)  verify_pipeline_builder ;;
    esac
}

# --- Challenge 1: Find the Error ---
setup_find_the_error() {
    mkdir -p "$CHALLENGE_SANDBOX/etc" "$CHALLENGE_SANDBOX/var/log"
    cat > "$CHALLENGE_SANDBOX/etc/app.conf" << 'CONF'
# Application Configuration
server_name=myapp
listen_port=eighty
log_level=info
database_host=localhost
database_port=5432
max_connections=100
CONF
    cat > "$CHALLENGE_SANDBOX/var/log/app.log" << 'LOG'
2026-04-15 10:00:01 INFO: Starting application...
2026-04-15 10:00:01 INFO: Reading config from /etc/app.conf
2026-04-15 10:00:01 ERROR: Invalid port number: 'eighty' - must be numeric
2026-04-15 10:00:01 FATAL: Cannot bind to port. Exiting.
LOG
    cat > "$CHALLENGE_SANDBOX/MISSION.txt" << 'MISSION'
MISSION: Find the Error
=======================
The app won't start. Something is wrong in the config.

1. Read the log file at var/log/app.log to find the error
2. Fix the config file at etc/app.conf
3. The port should be a number (like 80 or 8080), not a word

Skills needed:
  - grep or cat to read the log (Day 2 Lesson 1)
  - sed -i to fix the config (Day 2 Lesson 7)

Type 'exit' when you've fixed the config.
MISSION
}

verify_find_the_error() {
    local config="$CHALLENGE_SANDBOX/etc/app.conf"
    if grep -qE "listen_port=[0-9]+" "$config" 2>/dev/null; then
        return 0
    fi
    return 1
}

# --- Challenge 2: Permission Fix ---
setup_permission_fix() {
    mkdir -p "$CHALLENGE_SANDBOX/home/deploy/scripts"
    cat > "$CHALLENGE_SANDBOX/home/deploy/scripts/deploy.sh" << 'SCRIPT'
#!/bin/bash
echo "Deploying application..."
echo "Pulling latest code..."
echo "Restarting service..."
echo "Deploy complete!"
SCRIPT
    chmod 644 "$CHALLENGE_SANDBOX/home/deploy/scripts/deploy.sh"
    cat > "$CHALLENGE_SANDBOX/MISSION.txt" << 'MISSION'
MISSION: Permission Fix
=======================
The deploy script is failing with "Permission denied."

1. Use ls -la to check the permissions of home/deploy/scripts/deploy.sh
2. Make the script executable
3. Verify by running: bash home/deploy/scripts/deploy.sh

Skills needed:
  - ls -la to see permissions (Day 1 Lesson 2)
  - chmod +x to fix permissions (Day 3 Lesson 6)

Type 'exit' when you've fixed the permissions.
MISSION
}

verify_permission_fix() {
    [ -x "$CHALLENGE_SANDBOX/home/deploy/scripts/deploy.sh" ]
}

# --- Challenge 3: Log Detective ---
setup_log_detective() {
    mkdir -p "$CHALLENGE_SANDBOX/var/log"
    cat > "$CHALLENGE_SANDBOX/var/log/access.log" << 'LOG'
192.168.1.10 GET /index.html 200
10.0.0.5 GET /about.html 200
192.168.1.10 GET /contact.html 200
203.0.113.42 POST /admin/login 401
203.0.113.42 POST /admin/login 401
203.0.113.42 POST /admin/login 401
10.0.0.5 GET /products.html 200
203.0.113.42 POST /admin/login 401
203.0.113.42 POST /admin/login 401
192.168.1.10 GET /faq.html 200
203.0.113.42 POST /admin/login 401
203.0.113.42 POST /admin/login 401
203.0.113.42 POST /admin/login 401
203.0.113.42 POST /admin/login 401
10.0.0.5 GET /pricing.html 200
203.0.113.42 POST /admin/login 401
LOG
    cat > "$CHALLENGE_SANDBOX/MISSION.txt" << 'MISSION'
MISSION: Log Detective
======================
Someone is brute-forcing the admin login!

1. Analyze var/log/access.log
2. Find the attacker's IP (look for repeated 401 failures)
3. Count how many failed attempts they made
4. Write your answer to answer.txt:
   IP: <attacker_ip>
   ATTEMPTS: <number>

Skills needed:
  - grep to filter 401 lines (Day 2 Lesson 1)
  - cut to extract the IP column (Day 2 Lesson 2)
  - sort | uniq -c to count per IP (Day 2 Lessons 3-4)
  - Pipes to chain it all together (Day 2 Lesson 6)

Example pipeline:
  grep "401" var/log/access.log | cut -d' ' -f1 | sort | uniq -c

Type 'exit' when you've written answer.txt.
MISSION
}

verify_log_detective() {
    local answer="$CHALLENGE_SANDBOX/answer.txt"
    [ ! -f "$answer" ] && return 1
    grep -qi "203.0.113.42" "$answer" && grep -qi "10" "$answer" && return 0
    return 1
}

# --- Challenge 4: Process Cleanup ---
setup_process_cleanup() {
    mkdir -p "$CHALLENGE_SANDBOX/var/run"
    cat > "$CHALLENGE_SANDBOX/MISSION.txt" << 'MISSION'
MISSION: Process Cleanup
========================
The server is slow. Rogue processes may be running.

1. Use ps aux to list all processes
2. Look for anything suspicious (like "crypto_miner")
3. Kill the suspicious process using kill or pkill
4. Write the name of the process you found to solved.txt

Skills needed:
  - ps aux to view processes (Day 4 Lesson 1)
  - grep to filter the list (Day 2 Lesson 1)
  - kill or pkill to stop it (Day 4 Lesson 2)

Example: ps aux | grep suspicious_name

Type 'exit' when you've written solved.txt.
MISSION
}

verify_process_cleanup() {
    [ -f "$CHALLENGE_SANDBOX/solved.txt" ] && grep -qi "crypto_miner" "$CHALLENGE_SANDBOX/solved.txt"
}

# --- Challenge 5: Disk Space Crisis ---
setup_disk_space_crisis() {
    mkdir -p "$CHALLENGE_SANDBOX/var/log" "$CHALLENGE_SANDBOX/tmp" "$CHALLENGE_SANDBOX/home/user"
    dd if=/dev/zero of="$CHALLENGE_SANDBOX/var/log/old_app.log.1" bs=1024 count=100 2>/dev/null
    dd if=/dev/zero of="$CHALLENGE_SANDBOX/var/log/old_app.log.2" bs=1024 count=100 2>/dev/null
    dd if=/dev/zero of="$CHALLENGE_SANDBOX/var/log/old_app.log.3" bs=1024 count=100 2>/dev/null
    dd if=/dev/zero of="$CHALLENGE_SANDBOX/tmp/core_dump.12345" bs=1024 count=500 2>/dev/null
    dd if=/dev/zero of="$CHALLENGE_SANDBOX/home/user/backup_2024.tar.gz" bs=1024 count=200 2>/dev/null
    echo "important data - DO NOT DELETE" > "$CHALLENGE_SANDBOX/home/user/important.txt"
    cat > "$CHALLENGE_SANDBOX/MISSION.txt" << 'MISSION'
MISSION: Disk Space Crisis
==========================
The server disk is almost full! Free up space.

1. Find the largest files: du -sh * or find . -size +50k
2. Delete unnecessary files (old logs, core dumps, old backups)
3. Do NOT delete home/user/important.txt!
4. Free at least 500KB of space

What to delete (safe):
  - Old log files in var/log/ (.log.1, .log.2, .log.3)
  - Core dumps in tmp/
  - Old backups in home/user/ (backup_2024.tar.gz)

What to keep:
  - home/user/important.txt (CRITICAL)

Skills needed:
  - du -sh to check sizes (Day 4 Lesson 8)
  - find . -size +50k to locate large files (Day 4 Lesson 7)
  - rm to delete files (Day 1 Lesson 6)

Type 'exit' when you've cleaned up.
MISSION
}

verify_disk_space_crisis() {
    local important="$CHALLENGE_SANDBOX/home/user/important.txt"
    local core_dump="$CHALLENGE_SANDBOX/tmp/core_dump.12345"
    [ -f "$important" ] && [ ! -f "$core_dump" ]
}

# --- Challenge 6: Pipeline Builder ---
setup_pipeline_builder() {
    mkdir -p "$CHALLENGE_SANDBOX/data"
    cat > "$CHALLENGE_SANDBOX/data/sales.csv" << 'CSV'
date,product,region,amount
2026-01-15,Widget,North,150
2026-01-16,Gadget,South,200
2026-01-17,Widget,North,175
2026-01-18,Gadget,North,300
2026-01-19,Widget,South,125
2026-01-20,Widget,North,200
2026-01-21,Gadget,South,250
2026-01-22,Widget,North,150
2026-01-23,Gadget,North,400
2026-01-24,Widget,South,100
CSV
    cat > "$CHALLENGE_SANDBOX/MISSION.txt" << 'MISSION'
MISSION: Pipeline Builder
=========================
You have a sales CSV at data/sales.csv.

Build command pipelines to answer these questions:

1. How many sales were in the North region?
   Write the number to answer1.txt

2. What is the most sold product?
   Write the product name to answer2.txt

3. List all unique regions, sorted alphabetically.
   Write to answer3.txt (one per line)

Skills needed:
  - tail -n +2 to skip the header (Day 2 Lesson 8)
  - grep to filter rows (Day 2 Lesson 1)
  - cut -d, to extract columns (Day 2 Lesson 2)
  - sort | uniq -c for counting (Day 2 Lessons 3-4)
  - wc -l for counting lines (Day 2 Lesson 5)
  - Pipes to chain commands (Day 2 Lesson 6)

Example to get you started:
  tail -n +2 data/sales.csv | grep "North" | wc -l

Type 'exit' when you've created all three answer files.
MISSION
}

verify_pipeline_builder() {
    local score=0
    [ -f "$CHALLENGE_SANDBOX/answer1.txt" ] && grep -q "5" "$CHALLENGE_SANDBOX/answer1.txt" && score=$((score + 1))
    [ -f "$CHALLENGE_SANDBOX/answer2.txt" ] && grep -qi "widget" "$CHALLENGE_SANDBOX/answer2.txt" && score=$((score + 1))
    [ -f "$CHALLENGE_SANDBOX/answer3.txt" ] && grep -q "North" "$CHALLENGE_SANDBOX/answer3.txt" && grep -q "South" "$CHALLENGE_SANDBOX/answer3.txt" && score=$((score + 1))
    [ "$score" -ge 2 ]
}

# ============================================
# Challenge Menu and Runner
# ============================================

list_challenges() {
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo -e "${C_PURPLE}  🏋️ Practicum CLI — Linux Challenges${C_RESET}"
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}[1]${C_RESET} 🔍 Find the Error ${C_DIM}(fix a broken config)${C_RESET}"
    echo -e "  ${C_WHITE}[2]${C_RESET} 🔐 Permission Fix ${C_DIM}(make a script runnable)${C_RESET}"
    echo -e "  ${C_WHITE}[3]${C_RESET} 🕵️ Log Detective ${C_DIM}(find the attacker)${C_RESET}"
    echo -e "  ${C_WHITE}[4]${C_RESET} ⚡ Process Cleanup ${C_DIM}(kill rogue processes)${C_RESET}"
    echo -e "  ${C_WHITE}[5]${C_RESET} 💾 Disk Space Crisis ${C_DIM}(free up disk space)${C_RESET}"
    echo -e "  ${C_WHITE}[6]${C_RESET} 🔧 Pipeline Builder ${C_DIM}(process CSV data)${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}[9]${C_RESET} Back to main menu"
    echo ""
}

run_challenge() {
    local challenge_id="$1"
    local challenge_name="$2"
    
    init_challenge_env
    setup_challenge "$challenge_id"
    
    local required_lessons
    required_lessons=$(get_challenge_lessons "$challenge_id")
    
    echo ""
    echo -e "${C_GREEN}  Challenge loaded: $challenge_name${C_RESET}"
    echo -e "  ${C_CYAN}Sandbox: $CHALLENGE_SANDBOX${C_RESET}"
    echo -e "  ${C_DIM}  Skills needed from: $required_lessons${C_RESET}"
    echo ""
    
    if [ -f "$CHALLENGE_SANDBOX/MISSION.txt" ]; then
        echo -e "${C_PURPLE}--- MISSION ---${C_RESET}"
        cat "$CHALLENGE_SANDBOX/MISSION.txt"
        echo -e "${C_PURPLE}--- END MISSION ---${C_RESET}"
    fi
    
    echo ""
    echo -e "  ${C_CYAN}You are now in the challenge sandbox.${C_RESET}"
    echo -e "  ${C_CYAN}Type 'exit' when you think you've solved it.${C_RESET}"
    echo ""
    
    cd "$CHALLENGE_SANDBOX" || true
    export PS1="🏋️ [CHALLENGE] \w\$ "
    bash --norc --noprofile -i
    
    echo ""
    echo -e "  ${C_WHITE}Checking your solution...${C_RESET}"
    echo ""
    
    if verify_challenge "$challenge_id"; then
        echo -e "  ${C_GREEN}✅ CHALLENGE PASSED: $challenge_name${C_RESET}"
        echo -e "  ${C_GREEN}  Well done! You correctly applied skills from:${C_RESET}"
        echo -e "  ${C_CYAN}  $required_lessons${C_RESET}"
        echo "$challenge_id" >> "$CHALLENGE_DIR/completed.txt"
        sort -u "$CHALLENGE_DIR/completed.txt" -o "$CHALLENGE_DIR/completed.txt"
    else
        echo -e "  ${C_RED}❌ Not quite right: $challenge_name${C_RESET}"
        echo ""
        echo -e "  ${C_YELLOW}  Review these lessons before trying again:${C_RESET}"
        echo -e "  ${C_CYAN}  $required_lessons${C_RESET}"
        echo ""
        echo -e "  ${C_DIM}  Hint:${C_RESET}"
        get_challenge_hint "$challenge_id" | while IFS= read -r line; do
            echo -e "  ${C_DIM}  $line${C_RESET}"
        done
    fi
    echo ""
}

cmd_challenges() {
    list_challenges
    printf "  ${C_CYAN}Your choice: ${C_RESET}"
    read -r choice || return 0
    
    case "$choice" in
        1) run_challenge "find_the_error" "Find the Error" ;;
        2) run_challenge "permission_fix" "Permission Fix" ;;
        3) run_challenge "log_detective" "Log Detective" ;;
        4) run_challenge "process_cleanup" "Process Cleanup" ;;
        5) run_challenge "disk_space_crisis" "Disk Space Crisis" ;;
        6) run_challenge "pipeline_builder" "Pipeline Builder" ;;
        9) return 0 ;;
        *) echo "  Invalid choice."; cmd_challenges ;;
    esac
}
