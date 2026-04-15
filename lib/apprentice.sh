#!/bin/bash
# Practicum CLI — Apprenticeship Engine
# Makes every interaction feel like working alongside a senior engineer.
# Three systems: Situational Awareness, Skill Mastery, Scenario Chains

# ============================================
# 1. SITUATIONAL AWARENESS
# Shows real system state before/after commands
# "A senior engineer would tell you to check this first"
# ============================================

show_situation() {
    local command="$1"
    
    echo -e "${C_DIM}  ── Current Situation ──${C_RESET}"
    
    case "$command" in
        pwd|cd|ls|mkdir)
            echo -e "  ${C_DIM}Directory: $(pwd)${C_RESET}"
            local file_count
            file_count=$(ls -1 2>/dev/null | wc -l)
            echo -e "  ${C_DIM}Files here: $file_count${C_RESET}"
            ;;
        rm|touch|cp|mv)
            echo -e "  ${C_DIM}Directory: $(pwd)${C_RESET}"
            local disk_usage
            disk_usage=$(du -sh . 2>/dev/null | cut -f1)
            echo -e "  ${C_DIM}Folder size: $disk_usage${C_RESET}"
            ;;
        grep|cut|sort|uniq|wc|sed|awk)
            echo -e "  ${C_DIM}Directory: $(pwd)${C_RESET}"
            local txt_count
            txt_count=$(ls -1 *.txt *.log *.csv 2>/dev/null | wc -l)
            echo -e "  ${C_DIM}Text/log files here: $txt_count${C_RESET}"
            ;;
        ps|kill|jobs)
            local proc_count
            proc_count=$(ps aux 2>/dev/null | wc -l)
            echo -e "  ${C_DIM}Running processes: $proc_count${C_RESET}"
            echo -e "  ${C_DIM}Load average: $(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs)${C_RESET}"
            ;;
        df|du|find)
            local disk_pct
            disk_pct=$(df -h / 2>/dev/null | awk 'NR==2{print $5}')
            echo -e "  ${C_DIM}Disk usage: $disk_pct${C_RESET}"
            ;;
        chmod|chown|useradd|groups|sudo)
            echo -e "  ${C_DIM}Current user: $(whoami)${C_RESET}"
            echo -e "  ${C_DIM}Groups: $(groups 2>/dev/null | head -c 60)${C_RESET}"
            ;;
        ssh|scp|ping|curl|ss|ip)
            local ip_addr
            ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
            echo -e "  ${C_DIM}Your IP: ${ip_addr:-unknown}${C_RESET}"
            ;;
        systemctl|journalctl|cron)
            local failed
            failed=$(systemctl --failed 2>/dev/null | grep -c "failed" || echo "0")
            echo -e "  ${C_DIM}Failed services: $failed${C_RESET}"
            echo -e "  ${C_DIM}Uptime: $(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}')${C_RESET}"
            ;;
        *)
            echo -e "  ${C_DIM}Directory: $(pwd)${C_RESET}"
            ;;
    esac
    echo -e "${C_DIM}  ────────────────────${C_RESET}"
}

# Show what a senior engineer would say
senior_tip() {
    local command="$1"
    
    case "$command" in
        rm)
            echo -e "  ${C_CYAN}💡 Senior tip: Always ls first to see what you're about to delete.${C_RESET}"
            ;;
        chmod)
            echo -e "  ${C_CYAN}💡 Senior tip: Use ls -la before and after to verify the change.${C_RESET}"
            ;;
        kill)
            echo -e "  ${C_CYAN}💡 Senior tip: Try kill (SIGTERM) first. Only use kill -9 as last resort.${C_RESET}"
            ;;
        grep)
            echo -e "  ${C_CYAN}💡 Senior tip: Add -n for line numbers — saves time finding the exact spot.${C_RESET}"
            ;;
        ssh)
            echo -e "  ${C_CYAN}💡 Senior tip: Always use key-based auth in production. Never password.${C_RESET}"
            ;;
        sudo)
            echo -e "  ${C_CYAN}💡 Senior tip: Only sudo what you must. Stay as normal user otherwise.${C_RESET}"
            ;;
        find)
            echo -e "  ${C_CYAN}💡 Senior tip: Redirect stderr with 2>/dev/null to hide permission errors.${C_RESET}"
            ;;
        tar)
            echo -e "  ${C_CYAN}💡 Senior tip: Always use tar tzf to list contents before extracting.${C_RESET}"
            ;;
        cron)
            echo -e "  ${C_CYAN}💡 Senior tip: Always redirect cron output to a log file for debugging.${C_RESET}"
            ;;
        vim)
            echo -e "  ${C_CYAN}💡 Senior tip: If you get stuck in vim, press Esc then type :q! to escape.${C_RESET}"
            ;;
        systemctl)
            echo -e "  ${C_CYAN}💡 Senior tip: Check 'systemctl status' before restarting — read the error first.${C_RESET}"
            ;;
        sed)
            echo -e "  ${C_CYAN}💡 Senior tip: Test without -i first, then add -i once the output looks right.${C_RESET}"
            ;;
    esac
}

# ============================================
# 2. SKILL MASTERY TRACKING
# Three levels: Learned → Practiced → Mastered
# ============================================

MASTERY_FILE="$HOME/.practicum/mastery.txt"

init_mastery() {
    [ ! -f "$MASTERY_FILE" ] && touch "$MASTERY_FILE"
}

# Record that a skill was used (lesson, challenge, or free practice)
record_skill_use() {
    local skill="$1"
    local context="$2"  # lesson, challenge, or practice
    local timestamp
    timestamp=$(date +%s)
    echo "${skill}:${context}:${timestamp}" >> "$MASTERY_FILE"
}

# Get mastery level for a skill
get_mastery_level() {
    local skill="$1"
    local lesson_count=0
    local challenge_count=0
    local practice_count=0
    local scenario_count=0
    
    if [ -f "$MASTERY_FILE" ] && [ -s "$MASTERY_FILE" ]; then
        lesson_count=$(grep -c "^${skill}:lesson:" "$MASTERY_FILE" 2>/dev/null) || lesson_count=0
        challenge_count=$(grep -c "^${skill}:challenge:" "$MASTERY_FILE" 2>/dev/null) || challenge_count=0
        practice_count=$(grep -c "^${skill}:practice:" "$MASTERY_FILE" 2>/dev/null) || practice_count=0
        scenario_count=$(grep -c "^${skill}:scenario:" "$MASTERY_FILE" 2>/dev/null) || scenario_count=0
    fi
    
    local total=$((lesson_count + challenge_count + practice_count + scenario_count))
    
    if [ "$total" -eq 0 ]; then
        echo "not_started"
    elif [ "$challenge_count" -ge 1 ] || [ "$scenario_count" -ge 1 ] && [ "$total" -ge 3 ]; then
        echo "mastered"
    elif [ "$total" -ge 2 ]; then
        echo "practiced"
    else
        echo "learned"
    fi
}

# Display mastery badge
mastery_badge() {
    local level="$1"
    case "$level" in
        not_started) echo -e "${C_DIM}○${C_RESET}" ;;
        learned)     echo -e "${C_YELLOW}◐${C_RESET}" ;;
        practiced)   echo -e "${C_CYAN}◑${C_RESET}" ;;
        mastered)    echo -e "${C_GREEN}●${C_RESET}" ;;
    esac
}

# Show skill mastery dashboard
show_mastery_dashboard() {
    init_mastery
    
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo -e "${C_PURPLE}  🎯 Skill Mastery Dashboard${C_RESET}"
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo ""
    echo -e "  ${C_DIM}○ = Not started  ◐ = Learned  ◑ = Practiced  ● = Mastered${C_RESET}"
    echo ""
    
    # Day 1 skills
    echo -e "  ${C_WHITE}Day 1 — Navigation & Files${C_RESET}"
    for skill in pwd ls cd mkdir touch rm; do
        local level
        level=$(get_mastery_level "$skill")
        local badge
        badge=$(mastery_badge "$level")
        printf "    %b %-12s %b\n" "$badge" "$skill" "${C_DIM}($level)${C_RESET}"
    done
    
    # Day 2 skills
    echo ""
    echo -e "  ${C_WHITE}Day 2 — Text Processing${C_RESET}"
    for skill in grep cut sort uniq wc pipes sed head_tail; do
        local level
        level=$(get_mastery_level "$skill")
        local badge
        badge=$(mastery_badge "$level")
        printf "    %b %-12s %b\n" "$badge" "$skill" "${C_DIM}($level)${C_RESET}"
    done
    
    # Day 3 skills
    echo ""
    echo -e "  ${C_WHITE}Day 3 — Scripting${C_RESET}"
    for skill in variables conditionals loops_for loops_while functions exit_codes; do
        local level
        level=$(get_mastery_level "$skill")
        local badge
        badge=$(mastery_badge "$level")
        printf "    %b %-12s %b\n" "$badge" "$skill" "${C_DIM}($level)${C_RESET}"
    done
    
    # Day 4 skills
    echo ""
    echo -e "  ${C_WHITE}Day 4 — Process & Environment${C_RESET}"
    for skill in ps kill jobs env alias path find du_df; do
        local level
        level=$(get_mastery_level "$skill")
        local badge
        badge=$(mastery_badge "$level")
        printf "    %b %-12s %b\n" "$badge" "$skill" "${C_DIM}($level)${C_RESET}"
    done
    
    # Day 6 skills
    echo ""
    echo -e "  ${C_WHITE}Day 6 — Permissions & Security${C_RESET}"
    for skill in chmod chown useradd groups sudo; do
        local level
        level=$(get_mastery_level "$skill")
        local badge
        badge=$(mastery_badge "$level")
        printf "    %b %-12s %b\n" "$badge" "$skill" "${C_DIM}($level)${C_RESET}"
    done
    
    # Day 7 skills
    echo ""
    echo -e "  ${C_WHITE}Day 7 — Networking & SSH${C_RESET}"
    for skill in ip ping_curl ss ssh scp_rsync apt tar; do
        local level
        level=$(get_mastery_level "$skill")
        local badge
        badge=$(mastery_badge "$level")
        printf "    %b %-12s %b\n" "$badge" "$skill" "${C_DIM}($level)${C_RESET}"
    done
    
    # Day 8 skills
    echo ""
    echo -e "  ${C_WHITE}Day 8 — Services & Operations${C_RESET}"
    for skill in systemctl journalctl cron vim nano awk; do
        local level
        level=$(get_mastery_level "$skill")
        local badge
        badge=$(mastery_badge "$level")
        printf "    %b %-12s %b\n" "$badge" "$skill" "${C_DIM}($level)${C_RESET}"
    done
    
    # Summary
    local total_mastered=0
    local total_skills=0
    for s in pwd ls cd mkdir touch rm grep cut sort uniq wc pipes sed head_tail variables conditionals loops_for loops_while functions exit_codes ps kill jobs env alias path find du_df chmod chown useradd groups sudo ip ping_curl ss ssh scp_rsync apt tar systemctl journalctl cron vim nano awk; do
        total_skills=$((total_skills + 1))
        local lvl
        lvl=$(get_mastery_level "$s")
        [ "$lvl" = "mastered" ] && total_mastered=$((total_mastered + 1))
    done
    
    echo ""
    echo -e "  ${C_GREEN}Skills mastered: $total_mastered / $total_skills${C_RESET}"
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo ""
}

# ============================================
# 3. SCENARIO CHAINS
# Multi-step realistic workflows
# ============================================

# Scenario: "First Day on the Job"
# Chains: ssh → ls → cd → cat → grep → ps → df
run_scenario_first_day() {
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo -e "${C_PURPLE}  🏢 Scenario: Your First Day on the Job${C_RESET}"
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}You just got SSH access to a production server.${C_RESET}"
    echo -e "  ${C_WHITE}Your manager says: 'Check the server health and${C_RESET}"
    echo -e "  ${C_WHITE}report back what you find.'${C_RESET}"
    echo ""
    echo -e "  ${C_CYAN}Tasks:${C_RESET}"
    echo -e "  ${C_WHITE}1.${C_RESET} Find out where you are (pwd)"
    echo -e "  ${C_WHITE}2.${C_RESET} Check disk space (df -h)"
    echo -e "  ${C_WHITE}3.${C_RESET} Look at running processes (ps aux | head)"
    echo -e "  ${C_WHITE}4.${C_RESET} Check for errors in logs (grep ERROR /var/log/syslog)"
    echo -e "  ${C_WHITE}5.${C_RESET} Check who else is logged in (who)"
    echo -e "  ${C_WHITE}6.${C_RESET} Write your findings to report.txt"
    echo ""
    echo -e "  ${C_DIM}Skills needed: Day 1 (pwd, ls), Day 2 (grep), Day 4 (ps, du/df)${C_RESET}"
    echo -e "  ${C_DIM}Time limit: none — take your time and learn.${C_RESET}"
    echo ""
    echo -e "  ${C_CYAN}Type 'exit' when you've written report.txt.${C_RESET}"
    echo ""
}

# Scenario: "Deploy Day"  
# Chains: scp → chmod → systemctl → journalctl → curl
run_scenario_deploy_day() {
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo -e "${C_PURPLE}  🚀 Scenario: Deploy Day${C_RESET}"
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}The team just finished a new feature. Your job:${C_RESET}"
    echo -e "  ${C_WHITE}deploy it to production and verify it works.${C_RESET}"
    echo ""
    echo -e "  ${C_CYAN}Tasks:${C_RESET}"
    echo -e "  ${C_WHITE}1.${C_RESET} Check the deploy script permissions (ls -la deploy.sh)"
    echo -e "  ${C_WHITE}2.${C_RESET} Make it executable if needed (chmod +x)"
    echo -e "  ${C_WHITE}3.${C_RESET} Run the deploy script (bash deploy.sh)"
    echo -e "  ${C_WHITE}4.${C_RESET} Check the service status (systemctl status app)"
    echo -e "  ${C_WHITE}5.${C_RESET} Check logs for errors (journalctl -u app --since '5 min ago')"
    echo -e "  ${C_WHITE}6.${C_RESET} Verify the app responds (curl localhost:8080)"
    echo ""
    echo -e "  ${C_DIM}Skills needed: Day 6 (chmod), Day 7 (curl), Day 8 (systemctl, journalctl)${C_RESET}"
    echo ""
}

# Scenario: "Midnight Emergency"
# Chains: top → kill → df → find → rm → journalctl
run_scenario_midnight() {
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo -e "${C_PURPLE}  🔥 Scenario: Midnight Emergency${C_RESET}"
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo ""
    echo -e "  ${C_RED}ALERT: Server disk is 98% full. Users can't save files.${C_RESET}"
    echo -e "  ${C_RED}A rogue process is eating CPU. Fix it NOW.${C_RESET}"
    echo ""
    echo -e "  ${C_CYAN}Tasks:${C_RESET}"
    echo -e "  ${C_WHITE}1.${C_RESET} Check disk usage (df -h)"
    echo -e "  ${C_WHITE}2.${C_RESET} Find the biggest files (du -sh /* | sort -rh | head)"
    echo -e "  ${C_WHITE}3.${C_RESET} Delete old log files safely (find /var/log -name '*.gz' -mtime +30)"
    echo -e "  ${C_WHITE}4.${C_RESET} Find the CPU hog (ps aux --sort=-%cpu | head)"
    echo -e "  ${C_WHITE}5.${C_RESET} Kill the rogue process"
    echo -e "  ${C_WHITE}6.${C_RESET} Verify disk is below 80% and CPU is normal"
    echo ""
    echo -e "  ${C_DIM}Skills needed: Day 1 (rm), Day 4 (ps, kill, find, du/df)${C_RESET}"
    echo ""
}

# Scenario menu
cmd_scenarios() {
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo -e "${C_PURPLE}  🏢 Practicum CLI — Work Scenarios${C_RESET}"
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo ""
    echo -e "  ${C_DIM}Real situations. Multiple skills. Like your first week on the job.${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}[1]${C_RESET} 🏢 Your First Day on the Job ${C_DIM}(beginner)${C_RESET}"
    echo -e "  ${C_WHITE}[2]${C_RESET} 🚀 Deploy Day ${C_DIM}(intermediate)${C_RESET}"
    echo -e "  ${C_WHITE}[3]${C_RESET} 🔥 Midnight Emergency ${C_DIM}(advanced)${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}[9]${C_RESET} Back to main menu"
    echo ""
    printf "  ${C_CYAN}Your choice: ${C_RESET}"
    read -r choice || return 0
    
    case "$choice" in
        1)
            run_scenario_first_day
            init_challenge_env
            setup_scenario_first_day
            cd "$CHALLENGE_SANDBOX" || true
            export PS1="🏢 [SCENARIO] \w\$ "
            bash --norc --noprofile -i
            verify_scenario_first_day
            ;;
        2)
            run_scenario_deploy_day
            init_challenge_env
            setup_scenario_deploy_day
            cd "$CHALLENGE_SANDBOX" || true
            export PS1="🚀 [SCENARIO] \w\$ "
            bash --norc --noprofile -i
            verify_scenario_deploy_day
            ;;
        3)
            run_scenario_midnight
            init_challenge_env
            setup_scenario_midnight
            cd "$CHALLENGE_SANDBOX" || true
            export PS1="🔥 [SCENARIO] \w\$ "
            bash --norc --noprofile -i
            verify_scenario_midnight
            ;;
        9) return 0 ;;
        *) echo "  Invalid choice."; cmd_scenarios ;;
    esac
}

# Scenario setups and verifications
setup_scenario_first_day() {
    rm -rf "$CHALLENGE_SANDBOX"
    mkdir -p "$CHALLENGE_SANDBOX"/{var/log,home/user,etc}
    cat > "$CHALLENGE_SANDBOX/var/log/syslog" << 'LOG'
2026-04-15 08:00:01 INFO: System boot complete
2026-04-15 08:01:23 INFO: SSH service started
2026-04-15 08:15:42 ERROR: Failed to mount /dev/sdb1
2026-04-15 09:00:00 INFO: Cron job /etc/cron.daily started
2026-04-15 09:12:33 ERROR: Out of memory: killed process 4521
2026-04-15 10:00:00 INFO: Backup completed successfully
2026-04-15 10:30:15 WARNING: Disk usage above 80% on /var
LOG
    echo "Welcome to production!" > "$CHALLENGE_SANDBOX/home/user/welcome.txt"
}

verify_scenario_first_day() {
    echo ""
    if [ -f "$CHALLENGE_SANDBOX/report.txt" ]; then
        local score=0
        grep -qi "disk\|space\|%" "$CHALLENGE_SANDBOX/report.txt" && score=$((score+1))
        grep -qi "error\|process\|memory" "$CHALLENGE_SANDBOX/report.txt" && score=$((score+1))
        [ -s "$CHALLENGE_SANDBOX/report.txt" ] && score=$((score+1))
        
        if [ "$score" -ge 2 ]; then
            echo -e "  ${C_GREEN}✅ SCENARIO COMPLETE: First Day on the Job${C_RESET}"
            echo -e "  ${C_CYAN}  Your report covered the key issues. Good work!${C_RESET}"
            record_skill_use "pwd" "scenario"
            record_skill_use "grep" "scenario"
            record_skill_use "ps" "scenario"
        else
            echo -e "  ${C_YELLOW}⚠️  Report is incomplete. Check disk and log errors.${C_RESET}"
        fi
    else
        echo -e "  ${C_RED}❌ No report.txt found. Write your findings to report.txt.${C_RESET}"
    fi
    echo ""
}

setup_scenario_deploy_day() {
    rm -rf "$CHALLENGE_SANDBOX"
    mkdir -p "$CHALLENGE_SANDBOX"/{scripts,var/log,etc}
    cat > "$CHALLENGE_SANDBOX/scripts/deploy.sh" << 'SCRIPT'
#!/bin/bash
echo "Pulling latest code..."
echo "Running migrations..."
echo "Restarting application..."
echo "Deploy complete at $(date)"
SCRIPT
    chmod 644 "$CHALLENGE_SANDBOX/scripts/deploy.sh"  # NOT executable
    echo "Deploy the latest feature" > "$CHALLENGE_SANDBOX/MISSION.txt"
}

verify_scenario_deploy_day() {
    echo ""
    if [ -x "$CHALLENGE_SANDBOX/scripts/deploy.sh" ]; then
        echo -e "  ${C_GREEN}✅ SCENARIO COMPLETE: Deploy Day${C_RESET}"
        echo -e "  ${C_CYAN}  Deploy script is executable and ready.${C_RESET}"
        record_skill_use "chmod" "scenario"
        record_skill_use "systemctl" "scenario"
    else
        echo -e "  ${C_RED}❌ Deploy script still not executable.${C_RESET}"
        echo -e "  ${C_YELLOW}  Hint: chmod +x scripts/deploy.sh${C_RESET}"
    fi
    echo ""
}

setup_scenario_midnight() {
    rm -rf "$CHALLENGE_SANDBOX"
    mkdir -p "$CHALLENGE_SANDBOX"/{var/log,tmp,home/user}
    dd if=/dev/zero of="$CHALLENGE_SANDBOX/var/log/huge_old.log" bs=1024 count=500 2>/dev/null
    dd if=/dev/zero of="$CHALLENGE_SANDBOX/tmp/core_dump.9999" bs=1024 count=300 2>/dev/null
    echo "critical data" > "$CHALLENGE_SANDBOX/home/user/database.db"
    echo "DO NOT DELETE" > "$CHALLENGE_SANDBOX/home/user/important.conf"
}

verify_scenario_midnight() {
    echo ""
    local score=0
    [ ! -f "$CHALLENGE_SANDBOX/var/log/huge_old.log" ] && score=$((score+1))
    [ ! -f "$CHALLENGE_SANDBOX/tmp/core_dump.9999" ] && score=$((score+1))
    [ -f "$CHALLENGE_SANDBOX/home/user/database.db" ] && score=$((score+1))
    [ -f "$CHALLENGE_SANDBOX/home/user/important.conf" ] && score=$((score+1))
    
    if [ "$score" -ge 3 ]; then
        echo -e "  ${C_GREEN}✅ SCENARIO COMPLETE: Midnight Emergency${C_RESET}"
        echo -e "  ${C_CYAN}  Disk freed, critical data preserved. Crisis averted!${C_RESET}"
        record_skill_use "find" "scenario"
        record_skill_use "du_df" "scenario"
        record_skill_use "rm" "scenario"
    else
        echo -e "  ${C_RED}❌ Not fully resolved.${C_RESET}"
        [ -f "$CHALLENGE_SANDBOX/var/log/huge_old.log" ] && echo -e "  ${C_YELLOW}  Still need to remove old logs${C_RESET}"
        [ ! -f "$CHALLENGE_SANDBOX/home/user/database.db" ] && echo -e "  ${C_RED}  WARNING: You deleted the database!${C_RESET}"
    fi
    echo ""
}
