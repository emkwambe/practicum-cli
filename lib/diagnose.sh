#!/bin/bash
# Practicum CLI — Diagnostic Navigator (IT Clinic)
# A decision-support system for Linux troubleshooting
# 6 major categories → 21 subcategories → specific diagnostic actions

# ══════════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════════

cmd_diagnose() {
    print_header "🔍 IT Clinic — Diagnostic Navigator"
    echo ""
    echo -e "  ${C_DIM}Systematic troubleshooting. Narrow down. Fix it.${C_RESET}"
    echo -e "  ${C_DIM}Ctrl+C to exit anytime.${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}What type of issue are you experiencing?${C_RESET}"
    echo ""
    print_menu_item "1" "🐢 System is slow or unresponsive"
    print_menu_item "2" "🌐 Network or connectivity problems"
    print_menu_item "3" "💾 Disk or storage issues"
    print_menu_item "4" "⚙️  Service or application won't work"
    print_menu_item "5" "🔒 Permission denied or access issues"
    print_menu_item "6" "🔧 Hardware or kernel problems"
    print_menu_item "7" "🩺 Full system health check"
    echo ""
    print_menu_item "0" "Back"
    print_prompt
    read -r choice || return 0

    case "$choice" in
        1) diag_performance ;;
        2) diag_network ;;
        3) diag_storage ;;
        4) diag_services ;;
        5) diag_permissions ;;
        6) diag_hardware_menu ;;
        7) diag_health_check ;;
        0) return 0 ;;
        *) echo -e "  ${C_RED}Invalid choice.${C_RESET}"; cmd_diagnose ;;
    esac
}

# ══════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════

diag_section() {
    echo ""
    echo -e "  ${C_PURPLE}━━━ $1 ━━━${C_RESET}"
    echo ""
}

diag_run() {
    local label="$1"
    local cmd="$2"
    echo -e "  ${C_CYAN}▶ $label${C_RESET}"
    echo -e "  ${C_DIM}\$ $cmd${C_RESET}"
    echo ""
    eval "$cmd" 2>&1 | sed 's/^/    /'
    echo ""
}

diag_verdict() {
    local status="$1"  # ok, warn, critical
    local msg="$2"
    case "$status" in
        ok)       echo -e "  ${C_GREEN}✅ $msg${C_RESET}" ;;
        warn)     echo -e "  ${C_YELLOW}⚠️  $msg${C_RESET}" ;;
        critical) echo -e "  ${C_RED}🚨 $msg${C_RESET}" ;;
    esac
}

diag_explain() {
    echo -e "  ${C_DIM}💡 $1${C_RESET}"
}

diag_fix() {
    echo -e "  ${C_GREEN}🔧 Suggested fix: ${C_WHITE}$1${C_RESET}"
}

diag_pause() {
    echo ""
    printf "  ${C_CYAN}Press Enter to continue...${C_RESET}"
    read -r
}

diag_back_prompt() {
    echo ""
    print_menu_item "r" "Run another diagnostic"
    print_menu_item "0" "Back to main menu"
    print_prompt
    read -r choice || return 0
    case "$choice" in
        r|R) cmd_diagnose ;;
        *) return 0 ;;
    esac
}

# ══════════════════════════════════════════════
#  CATEGORY 1: SYSTEM PERFORMANCE
# ══════════════════════════════════════════════

diag_performance() {
    print_header "🐢 Performance & Resources"
    echo ""
    echo -e "  ${C_WHITE}What's happening?${C_RESET}"
    echo ""
    print_menu_item "1" "High CPU usage (system is hot/loud)"
    print_menu_item "2" "Out of memory / OOM killed"
    print_menu_item "3" "Swap thrashing (system very slow)"
    print_menu_item "4" "System feels sluggish (high load)"
    print_menu_item "5" "Run all performance checks"
    echo ""
    print_menu_item "9" "Back"
    print_prompt
    read -r choice || return 0

    case "$choice" in
        1) diag_cpu ;;
        2) diag_memory ;;
        3) diag_swap ;;
        4) diag_load ;;
        5) diag_cpu; diag_pause; diag_memory; diag_pause; diag_swap; diag_pause; diag_load ;;
        9) cmd_diagnose ;;
        *) diag_performance ;;
    esac
    diag_back_prompt
}

diag_cpu() {
    diag_section "CPU Analysis"

    diag_run "Top CPU consumers" "ps aux --sort=-%cpu | head -11"

    # Check overall CPU
    local idle
    idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' 2>/dev/null | cut -d. -f1)
    if [ -n "$idle" ]; then
        local used=$((100 - idle))
        if [ "$used" -gt 90 ]; then
            diag_verdict "critical" "CPU at ${used}% — system is overloaded"
            diag_explain "One or more processes are consuming nearly all CPU."
            diag_fix "Identify the top consumer above. Kill it: kill -9 <PID>"
            diag_fix "Or reduce priority: renice +10 -p <PID>"
        elif [ "$used" -gt 70 ]; then
            diag_verdict "warn" "CPU at ${used}% — elevated but manageable"
            diag_explain "System is working hard. Monitor if it stays here."
        else
            diag_verdict "ok" "CPU at ${used}% — healthy"
        fi
    else
        diag_run "CPU overview (top not available)" "cat /proc/loadavg"
    fi
}

diag_memory() {
    diag_section "Memory Analysis"

    diag_run "Memory usage" "free -h"

    # Parse available memory
    local avail_mb
    avail_mb=$(free -m | awk '/^Mem:/ {print $7}')
    local total_mb
    total_mb=$(free -m | awk '/^Mem:/ {print $2}')

    if [ -n "$avail_mb" ] && [ -n "$total_mb" ] && [ "$total_mb" -gt 0 ]; then
        local used_pct=$(( (total_mb - avail_mb) * 100 / total_mb ))

        if [ "$used_pct" -gt 90 ]; then
            diag_verdict "critical" "Memory at ${used_pct}% — OOM risk"
            diag_explain "System may start killing processes to free memory."
            diag_run "Top memory consumers" "ps aux --sort=-%mem | head -6"
            diag_fix "Kill the biggest consumer: kill <PID>"
            diag_fix "Or add swap: sudo fallocate -l 2G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
        elif [ "$used_pct" -gt 75 ]; then
            diag_verdict "warn" "Memory at ${used_pct}% — getting tight"
            diag_run "Top memory consumers" "ps aux --sort=-%mem | head -6"
        else
            diag_verdict "ok" "Memory at ${used_pct}% — healthy"
        fi
    fi

    # Check swap
    local swap_total
    swap_total=$(free -m | awk '/^Swap:/ {print $2}')
    local swap_used
    swap_used=$(free -m | awk '/^Swap:/ {print $3}')
    if [ "$swap_total" -gt 0 ] && [ "$swap_used" -gt 0 ]; then
        local swap_pct=$(( swap_used * 100 / swap_total ))
        if [ "$swap_pct" -gt 50 ]; then
            diag_verdict "warn" "Swap ${swap_pct}% used — system is swapping (slow)"
            diag_explain "High swap = RAM is full, system uses disk as overflow. Very slow."
            diag_fix "Find and restart the memory-hungry process."
        fi
    fi

    # Check for OOM kills
    local oom_count
    oom_count=$(dmesg 2>/dev/null | grep -ci "oom" 2>/dev/null)
    oom_count="${oom_count:-0}"
    oom_count=$(echo "$oom_count" | head -1 | tr -dc '0-9')
    oom_count="${oom_count:-0}"
    if [ "$oom_count" -gt 0 ] 2>/dev/null; then
        diag_verdict "warn" "Found $oom_count OOM-related kernel messages"
        diag_run "Recent OOM events" "dmesg 2>/dev/null | grep -i 'oom' | tail -5"
    fi
}

diag_load() {
    diag_section "System Load"

    diag_run "Load averages (1m / 5m / 15m)" "cat /proc/loadavg"
    diag_run "CPU core count" "nproc"

    local load1
    load1=$(cat /proc/loadavg | awk '{print $1}' | cut -d. -f1)
    local cores
    cores=$(nproc 2>/dev/null || echo 1)

    if [ "$load1" -gt "$((cores * 2))" ]; then
        diag_verdict "critical" "Load ($load1) is >2x CPU cores ($cores) — severely overloaded"
        diag_explain "Load average counts processes waiting for CPU. More than 2x cores = bottleneck."
        diag_fix "Check CPU and memory sections. Kill or reschedule heavy tasks."
    elif [ "$load1" -gt "$cores" ]; then
        diag_verdict "warn" "Load ($load1) exceeds CPU cores ($cores) — busy"
    else
        diag_verdict "ok" "Load ($load1) within capacity ($cores cores)"
    fi

    diag_run "Uptime" "uptime"
}

diag_swap() {
    diag_section "Swap Analysis"

    diag_run "Swap devices" "swapon --show 2>/dev/null || cat /proc/swaps"
    diag_run "Memory + swap overview" "free -h"

    local swap_total
    swap_total=$(free -m | awk '/^Swap:/ {print $2}')
    local swap_used
    swap_used=$(free -m | awk '/^Swap:/ {print $3}')

    if [ "$swap_total" -eq 0 ] 2>/dev/null; then
        diag_verdict "warn" "No swap configured"
        diag_explain "Without swap, the OOM killer activates immediately when RAM is full."
        diag_fix "Create swap: sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
        diag_fix "Make permanent: echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab"
        return
    fi

    local swap_pct=$((swap_used * 100 / swap_total))

    if [ "$swap_pct" -gt 80 ]; then
        diag_verdict "critical" "Swap ${swap_pct}% used (${swap_used}M / ${swap_total}M) — system is thrashing"
        diag_explain "The system is constantly moving data between RAM and disk. Everything is slow."
        diag_run "Top memory consumers" "ps aux --sort=-%mem | head -6"
        diag_run "Per-process swap usage" "for pid in /proc/[0-9]*/status; do awk '/^(Name|VmSwap)/ {printf \$2\" \"}' \"\$pid\" 2>/dev/null; echo; done | sort -k2 -rn | head -10"
        diag_fix "Kill or restart the memory hog identified above"
        diag_fix "Add more RAM (permanent solution)"
        diag_fix "Increase swap: sudo swapoff -a && sudo fallocate -l 4G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
    elif [ "$swap_pct" -gt 50 ]; then
        diag_verdict "warn" "Swap ${swap_pct}% used — elevated"
        diag_explain "Some swapping is normal. Above 50% indicates memory pressure."
        diag_run "Top memory consumers" "ps aux --sort=-%mem | head -6"
    elif [ "$swap_pct" -gt 0 ]; then
        diag_verdict "ok" "Swap ${swap_pct}% used — some swap activity, normal"
    else
        diag_verdict "ok" "Swap configured but unused — RAM is sufficient"
    fi

    # Check swappiness
    local swappiness
    swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null)
    if [ -n "$swappiness" ]; then
        diag_explain "Swappiness: $swappiness (0=avoid swap, 100=swap aggressively, default=60)"
        if [ "$swappiness" -gt 60 ] && [ "$swap_pct" -gt 50 ]; then
            diag_fix "Reduce swappiness: sudo sysctl vm.swappiness=10"
        fi
    fi
}

# ══════════════════════════════════════════════
#  CATEGORY 2: NETWORK & CONNECTIVITY
# ══════════════════════════════════════════════

diag_network() {
    print_header "🌐 Network & Connectivity"
    echo ""
    echo -e "  ${C_WHITE}What's happening?${C_RESET}"
    echo ""
    print_menu_item "1" "Can't reach the internet"
    print_menu_item "2" "DNS not resolving (names don't work)"
    print_menu_item "3" "Port conflict or connection refused"
    print_menu_item "4" "SSH connection problems"
    print_menu_item "5" "Firewall blocking traffic"
    print_menu_item "6" "Routing issues (can't reach specific hosts)"
    print_menu_item "7" "Run all network checks"
    echo ""
    print_menu_item "9" "Back"
    print_prompt
    read -r choice || return 0

    case "$choice" in
        1) diag_internet ;;
        2) diag_dns ;;
        3) diag_ports ;;
        4) diag_ssh ;;
        5) diag_firewall ;;
        6) diag_routing ;;
        7) diag_internet; diag_pause; diag_dns; diag_pause; diag_ports; diag_pause; diag_firewall ;;
        9) cmd_diagnose ;;
        *) diag_network ;;
    esac
    diag_back_prompt
}

diag_internet() {
    diag_section "Internet Connectivity"

    # Check interface
    diag_run "Network interfaces" "ip -br addr 2>/dev/null || ifconfig 2>/dev/null | grep -E 'inet |flags'"

    # Check gateway
    local gw
    gw=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -1)
    if [ -n "$gw" ]; then
        diag_verdict "ok" "Default gateway: $gw"
        echo ""
        diag_run "Ping gateway" "ping -c 2 -W 2 $gw 2>&1 | tail -3"

        if ping -c 1 -W 2 "$gw" >/dev/null 2>&1; then
            diag_verdict "ok" "Gateway reachable"
        else
            diag_verdict "critical" "Gateway unreachable — likely a local network issue"
            diag_explain "Your machine can't reach the router. Check cable, WiFi, or IP config."
            diag_fix "sudo dhclient -r && sudo dhclient   (renew DHCP lease)"
            return
        fi
    else
        diag_verdict "critical" "No default gateway configured"
        diag_fix "sudo dhclient   or   sudo ip route add default via <gateway_ip>"
        return
    fi

    # Check internet
    diag_run "Ping external (8.8.8.8)" "ping -c 2 -W 3 8.8.8.8 2>&1 | tail -3"
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        diag_verdict "ok" "Internet reachable"
    else
        diag_verdict "critical" "Gateway OK but internet unreachable"
        diag_explain "Router can't reach the internet. ISP issue or firewall."
        diag_fix "Check router/modem. Try: curl -v http://example.com"
    fi
}

diag_dns() {
    diag_section "DNS Resolution"

    diag_run "DNS config" "cat /etc/resolv.conf 2>/dev/null | grep -v '^#'"

    # Test DNS
    if command -v nslookup >/dev/null 2>&1; then
        diag_run "Resolve google.com" "nslookup google.com 2>&1 | head -6"
    elif command -v dig >/dev/null 2>&1; then
        diag_run "Resolve google.com" "dig +short google.com 2>&1"
    elif command -v host >/dev/null 2>&1; then
        diag_run "Resolve google.com" "host google.com 2>&1"
    else
        diag_run "Resolve google.com (via ping)" "ping -c 1 -W 2 google.com 2>&1 | head -2"
    fi

    if ping -c 1 -W 2 google.com >/dev/null 2>&1; then
        diag_verdict "ok" "DNS resolving correctly"
    else
        # Can we reach IPs but not names?
        if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            diag_verdict "critical" "Internet works by IP but DNS fails"
            diag_explain "Your DNS server isn't responding. Names can't be resolved."
            diag_fix "Temporarily fix: echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf"
            diag_fix "Permanent fix: configure DNS in /etc/systemd/resolved.conf or your network manager"
        else
            diag_verdict "warn" "Can't reach DNS — but internet also down (see connectivity check)"
        fi
    fi
}

diag_ports() {
    diag_section "Port & Connection Analysis"

    diag_run "Listening ports" "ss -tlnp 2>/dev/null | head -20 || netstat -tlnp 2>/dev/null | head -20"

    echo -e "  ${C_WHITE}Check a specific port? Enter port number (or press Enter to skip):${C_RESET}"
    printf "  Port (or Enter to skip): "
    read -r port

    if [ -n "$port" ]; then
        local in_use
        in_use=$(ss -tlnp 2>/dev/null | grep ":${port} " || echo "")
        if [ -n "$in_use" ]; then
            diag_verdict "warn" "Port $port is IN USE"
            diag_run "What's using port $port" "ss -tlnp | grep ':${port} '"
            local pid
            pid=$(echo "$in_use" | grep -oP 'pid=\K[0-9]+' | head -1)
            if [ -n "$pid" ]; then
                diag_run "Process details" "ps -p $pid -o pid,user,comm,args 2>/dev/null"
                diag_fix "Kill it: sudo kill $pid"
                diag_fix "Or change your app to use a different port"
            fi
        else
            diag_verdict "ok" "Port $port is available (not in use)"
        fi

        # Test if something is responding
        if command -v nc >/dev/null 2>&1; then
            if nc -z -w 2 localhost "$port" 2>/dev/null; then
                diag_verdict "ok" "Port $port is accepting connections"
            else
                if [ -n "$in_use" ]; then
                    diag_verdict "warn" "Port $port is bound but NOT accepting connections"
                    diag_explain "The process is listening but may not be ready yet."
                fi
            fi
        fi
    fi
}

diag_ssh() {
    diag_section "SSH Diagnostics"

    # Check if sshd is running
    if systemctl is-active sshd >/dev/null 2>&1 || systemctl is-active ssh >/dev/null 2>&1; then
        diag_verdict "ok" "SSH service is running"
    else
        diag_verdict "critical" "SSH service is NOT running"
        diag_fix "sudo systemctl start ssh   (or sshd on RHEL/CentOS)"
        diag_fix "sudo systemctl enable ssh"
    fi

    diag_run "SSH config check" "sshd -T 2>/dev/null | grep -E 'port |permitroot|passwordauth|pubkey' | head -6 || echo 'Cannot read sshd config (need root)'"

    # Check recent failures
    local fail_count
    fail_count=$(journalctl -u ssh -u sshd --since "1 hour ago" 2>/dev/null | grep -ci "failed\|invalid\|refused" || echo "0")
    if [ "$fail_count" -gt 10 ]; then
        diag_verdict "warn" "$fail_count SSH failures in the last hour"
        diag_run "Recent failures" "journalctl -u ssh -u sshd --since '1 hour ago' 2>/dev/null | grep -i 'failed\|invalid' | tail -5"
        diag_explain "Many failures could indicate a brute-force attack."
        diag_fix "Install fail2ban: sudo apt install fail2ban"
    elif [ "$fail_count" -gt 0 ]; then
        diag_verdict "ok" "$fail_count SSH failures in the last hour (normal)"
    fi

    diag_run "SSH listening port" "ss -tlnp | grep ssh"
}

diag_firewall() {
    diag_section "Firewall Analysis"

    # Detect firewall type
    if command -v ufw >/dev/null 2>&1; then
        diag_run "UFW status" "sudo ufw status verbose 2>/dev/null || ufw status 2>/dev/null || echo 'Need sudo to check UFW'"

        local ufw_active
        ufw_active=$(sudo ufw status 2>/dev/null | head -1 || echo "unknown")
        if echo "$ufw_active" | grep -qi "active"; then
            diag_verdict "ok" "UFW firewall is active"
            diag_run "UFW rules" "sudo ufw status numbered 2>/dev/null | head -20"
        elif echo "$ufw_active" | grep -qi "inactive"; then
            diag_verdict "warn" "UFW is installed but NOT active"
            diag_fix "Enable: sudo ufw enable"
            diag_fix "Allow SSH first: sudo ufw allow ssh"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        diag_run "firewalld status" "sudo firewall-cmd --state 2>/dev/null"
        diag_run "firewalld rules" "sudo firewall-cmd --list-all 2>/dev/null"

        if sudo firewall-cmd --state 2>/dev/null | grep -q "running"; then
            diag_verdict "ok" "firewalld is running"
        else
            diag_verdict "warn" "firewalld is NOT running"
            diag_fix "Start: sudo systemctl start firewalld"
        fi
    else
        diag_explain "No UFW or firewalld found. Checking raw iptables..."
    fi

    # Always show iptables (underlying mechanism)
    diag_run "iptables rules (filter table)" "sudo iptables -L -n --line-numbers 2>/dev/null | head -30 || echo 'Need sudo for iptables'"

    local drop_rules
    drop_rules=$(sudo iptables -L -n 2>/dev/null | grep -ci "DROP\|REJECT" || echo "0")
    if [ "$drop_rules" -gt 0 ]; then
        diag_verdict "warn" "$drop_rules DROP/REJECT rules found"
        diag_explain "These rules may block traffic. Check if your port is affected."
    fi

    echo ""
    echo -e "  ${C_WHITE}Check if a specific port is allowed? (Enter port or press Enter to skip):${C_RESET}"
    printf "  Port: "
    read -r fw_port
    if [ -n "$fw_port" ]; then
        if command -v ufw >/dev/null 2>&1; then
            local allowed
            allowed=$(sudo ufw status 2>/dev/null | grep "$fw_port" || echo "")
            if [ -n "$allowed" ]; then
                diag_verdict "ok" "Port $fw_port has a UFW rule"
                echo "    $allowed"
            else
                diag_verdict "warn" "Port $fw_port has NO UFW rule"
                diag_fix "Allow it: sudo ufw allow ${fw_port}/tcp"
            fi
        else
            local blocked
            blocked=$(sudo iptables -L -n 2>/dev/null | grep "$fw_port" | grep -ci "DROP\|REJECT" || echo "0")
            if [ "$blocked" -gt 0 ]; then
                diag_verdict "critical" "Port $fw_port is BLOCKED by iptables"
            else
                diag_verdict "ok" "Port $fw_port is not explicitly blocked"
            fi
        fi
    fi
}

diag_routing() {
    diag_section "Routing Analysis"

    diag_run "Routing table" "ip route show 2>/dev/null || route -n 2>/dev/null"

    # Check default route
    local gw
    gw=$(ip route 2>/dev/null | grep "^default" | awk '{print $3}' | head -1)
    if [ -n "$gw" ]; then
        diag_verdict "ok" "Default gateway: $gw"
    else
        diag_verdict "critical" "No default gateway — cannot reach external networks"
        diag_fix "Set gateway: sudo ip route add default via <gateway_ip>"
        diag_fix "Or renew DHCP: sudo dhclient"
        return
    fi

    # ARP table
    diag_run "ARP neighbors" "ip neigh show 2>/dev/null | head -10"

    echo ""
    echo -e "  ${C_WHITE}Trace route to a specific host? (Enter hostname/IP or press Enter to skip):${C_RESET}"
    printf "  Host: "
    read -r trace_host
    if [ -n "$trace_host" ]; then
        if command -v traceroute >/dev/null 2>&1; then
            diag_run "Traceroute to $trace_host" "traceroute -m 15 -w 2 $trace_host 2>&1 | head -20"
        elif command -v tracepath >/dev/null 2>&1; then
            diag_run "Tracepath to $trace_host" "tracepath $trace_host 2>&1 | head -20"
        else
            diag_run "Route to $trace_host" "ip route get $trace_host 2>&1"
            diag_explain "Install traceroute for full path analysis: sudo apt install traceroute"
        fi
    fi
}

# ══════════════════════════════════════════════
#  CATEGORY 3: STORAGE & FILESYSTEM
# ══════════════════════════════════════════════

diag_storage() {
    print_header "💾 Storage & Filesystem"
    echo ""
    echo -e "  ${C_WHITE}What's happening?${C_RESET}"
    echo ""
    print_menu_item "1" "Disk full (no space left on device)"
    print_menu_item "2" "Inode exhaustion (can't create files)"
    print_menu_item "3" "Slow disk I/O"
    print_menu_item "4" "Filesystem errors or corruption"
    print_menu_item "5" "Mount failures (device won't mount)"
    print_menu_item "6" "Run all storage checks"
    echo ""
    print_menu_item "9" "Back"
    print_prompt
    read -r choice || return 0

    case "$choice" in
        1) diag_disk_full ;;
        2) diag_inodes ;;
        3) diag_disk_io ;;
        4) diag_filesystem ;;
        5) diag_mounts ;;
        6) diag_disk_full; diag_pause; diag_inodes; diag_pause; diag_disk_io; diag_pause; diag_filesystem ;;
        9) cmd_diagnose ;;
        *) diag_storage ;;
    esac
    diag_back_prompt
}

diag_disk_full() {
    diag_section "Disk Space Analysis"

    diag_run "Filesystem usage" "df -h | grep -vE 'tmpfs|devtmpfs|udev'"

    # Find full filesystems
    local critical_fs
    critical_fs=$(df -h 2>/dev/null | awk 'NR>1 && int($5)>=90 {print $6 " at " $5 " (" $4 " free)"}')
    if [ -n "$critical_fs" ]; then
        diag_verdict "critical" "Filesystems at 90%+ capacity:"
        echo "$critical_fs" | while IFS= read -r line; do
            echo -e "    ${C_RED}$line${C_RESET}"
        done
        echo ""
        diag_run "Largest directories in /" "du -sh /* 2>/dev/null | sort -rh | head -10"
        diag_run "Largest files (>100MB)" "find / -xdev -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -5"

        diag_fix "Clean package cache: sudo apt clean"
        diag_fix "Clean old journals: sudo journalctl --vacuum-size=100M"
        diag_fix "Find and delete large log files: sudo find /var/log -name '*.log' -size +50M"
        diag_fix "Remove old Docker data: docker system prune -a"
    else
        local warn_fs
        warn_fs=$(df -h 2>/dev/null | awk 'NR>1 && int($5)>=75 && int($5)<90 {print $6 " at " $5}')
        if [ -n "$warn_fs" ]; then
            diag_verdict "warn" "Filesystems at 75-89%:"
            echo "$warn_fs" | while IFS= read -r line; do
                echo -e "    ${C_YELLOW}$line${C_RESET}"
            done
        else
            diag_verdict "ok" "All filesystems below 75% — healthy"
        fi
    fi
}

diag_inodes() {
    diag_section "Inode Usage"

    diag_run "Inode usage by filesystem" "df -ih | grep -vE 'tmpfs|devtmpfs|udev'"

    local inode_full
    inode_full=$(df -i 2>/dev/null | awk 'NR>1 && int($5)>=90 {print $6 " at " $5}')
    if [ -n "$inode_full" ]; then
        diag_verdict "critical" "Inode exhaustion detected!"
        echo "$inode_full" | while IFS= read -r line; do
            echo -e "    ${C_RED}$line${C_RESET}"
        done
        diag_explain "Millions of tiny files used all inode slots. Disk has space but can't create files."
        diag_fix "Find directories with most files: find / -xdev -type d -exec sh -c 'echo \"\$(find \"{}\" -maxdepth 1 | wc -l) {}\"' \\; | sort -rn | head -10"
        diag_fix "Common culprits: /tmp, /var/spool, session files, cache dirs"
    else
        diag_verdict "ok" "Inode usage healthy"
    fi
}

diag_disk_io() {
    diag_section "Disk I/O"

    if command -v iostat >/dev/null 2>&1; then
        diag_run "I/O statistics" "iostat -x 1 2 2>/dev/null | tail -20"
    else
        diag_explain "iostat not available. Install with: sudo apt install sysstat"
    fi

    diag_run "Processes waiting on I/O" "ps aux | awk '\$8 ~ /D/ {print}' | head -10"

    local iowait
    iowait=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk -F',' '{for(i=1;i<=NF;i++) if($i ~ /wa/) print $i}' | grep -oP '[0-9.]+' | head -1 | cut -d. -f1)
    if [ -n "$iowait" ] && [ "$iowait" -gt 20 ]; then
        diag_verdict "warn" "I/O wait at ${iowait}% — disk is a bottleneck"
        diag_explain "Processes are waiting for the disk. Could be heavy writes or dying drive."
        diag_fix "Check SMART status: sudo smartctl -a /dev/sda"
        diag_fix "Check what's writing: sudo iotop -oP (if available)"
    elif [ -n "$iowait" ]; then
        diag_verdict "ok" "I/O wait at ${iowait}% — normal"
    fi
}

diag_filesystem() {
    diag_section "Filesystem Integrity"

    # Check for read-only remounts (sign of corruption)
    diag_run "Read-only mounted filesystems" "mount | grep 'ro,' | grep -v 'snap\|squashfs' || echo 'None found (good)'"

    local ro_mounts
    ro_mounts=$(mount | grep "ro," | grep -cv "snap\|squashfs\|tmpfs\|sysfs\|proc" 2>/dev/null || echo "0")
    if [ "$ro_mounts" -gt 0 ]; then
        diag_verdict "critical" "$ro_mounts filesystem(s) remounted read-only — possible corruption"
        diag_explain "A filesystem remounting as read-only is the kernel protecting data."
        diag_fix "Check dmesg for the error, then unmount and run fsck"
    fi

    # Check dmesg for filesystem errors
    diag_run "Kernel filesystem errors" "dmesg 2>/dev/null | grep -iE 'ext4.*error|xfs.*error|corrupt|I/O error|remount.*ro' | tail -10 || echo 'No errors (or no access to dmesg)'"

    local fs_errors
    fs_errors=$(dmesg 2>/dev/null | grep -ciE "ext4.*error|xfs.*error|corrupt|remount.*ro" || echo "0")
    fs_errors=$(echo "$fs_errors" | head -1 | tr -dc '0-9')
    fs_errors="${fs_errors:-0}"
    if [ "$fs_errors" -gt 0 ] 2>/dev/null; then
        diag_verdict "critical" "$fs_errors filesystem error messages in kernel log"
        diag_fix "Identify the affected device from the messages above"
        diag_fix "Unmount the filesystem, then: sudo fsck -y /dev/sdX"
        diag_fix "If root filesystem: schedule fsck on next boot: sudo touch /forcefsck"
    else
        diag_verdict "ok" "No filesystem corruption detected in kernel log"
    fi

    # Show filesystem types
    diag_run "Filesystem types" "df -Th | grep -vE 'tmpfs|devtmpfs|udev|squashfs' | head -10"
}

diag_mounts() {
    diag_section "Mount Analysis"

    diag_run "Currently mounted filesystems" "findmnt --real 2>/dev/null || mount | grep -v 'cgroup\|tmpfs\|proc\|sys'"
    diag_run "Block devices" "lsblk 2>/dev/null || echo 'lsblk not available'"
    diag_run "fstab entries" "cat /etc/fstab 2>/dev/null | grep -v '^#' | grep -v '^$'"

    # Compare fstab vs mounted
    if [ -f /etc/fstab ]; then
        local fstab_count
        fstab_count=$(grep -cv '^#\|^$\|swap\|none' /etc/fstab 2>/dev/null || echo "0")
        local mount_count
        mount_count=$(findmnt --real --noheadings 2>/dev/null | wc -l || echo "0")

        diag_explain "fstab entries: $fstab_count | Active mounts: $mount_count"

        # Try mount -a to find failures
        local mount_errors
        mount_errors=$(sudo mount -a 2>&1 || echo "")
        if [ -n "$mount_errors" ]; then
            diag_verdict "warn" "mount -a reported issues:"
            echo "    $mount_errors"
            diag_fix "Check /etc/fstab for typos or missing devices"
            diag_fix "Verify device exists: sudo blkid"
        else
            diag_verdict "ok" "All fstab entries can be mounted"
        fi
    fi

    # Check for UUIDs vs device names
    if grep -q "^/dev/sd" /etc/fstab 2>/dev/null; then
        diag_verdict "warn" "fstab uses device names (/dev/sdX) instead of UUIDs"
        diag_explain "Device names can change between reboots. UUIDs are stable."
        diag_fix "Use UUID= instead: sudo blkid to find UUIDs"
    fi
}

# ══════════════════════════════════════════════
#  CATEGORY 4: SERVICES & APPLICATIONS
# ══════════════════════════════════════════════

diag_services() {
    print_header "⚙️  Services & Applications"
    echo ""
    echo -e "  ${C_WHITE}What's happening?${C_RESET}"
    echo ""
    print_menu_item "1" "A specific service won't start"
    print_menu_item "2" "Service keeps crashing (restart loop)"
    print_menu_item "3" "Configuration syntax error"
    print_menu_item "4" "Service dependency failure"
    print_menu_item "5" "Show all failed services"
    print_menu_item "6" "Check Docker containers"
    print_menu_item "7" "Run all service checks"
    echo ""
    print_menu_item "9" "Back"
    print_prompt
    read -r choice || return 0

    case "$choice" in
        1) diag_service_start ;;
        2) diag_service_crash ;;
        3) diag_config_syntax ;;
        4) diag_dependencies ;;
        5) diag_failed_services ;;
        6) diag_docker ;;
        7) diag_failed_services; diag_pause; diag_docker ;;
        9) cmd_diagnose ;;
        *) diag_services ;;
    esac
    diag_back_prompt
}

diag_service_start() {
    diag_section "Service Startup Failure"

    echo -e "  ${C_WHITE}Which service? (e.g., nginx, postgresql, docker — or Enter to go back):${C_RESET}"
    printf "  Service name: "
    read -r svc

    if [ -z "$svc" ]; then
        echo -e "  ${C_DIM}Skipped.${C_RESET}"
        return
    fi

    diag_run "Service status" "systemctl status $svc 2>&1 | head -15"

    local active
    active=$(systemctl is-active "$svc" 2>/dev/null)
    case "$active" in
        active)
            diag_verdict "ok" "$svc is running"
            ;;
        failed)
            diag_verdict "critical" "$svc has FAILED"
            diag_run "Last 20 log lines" "journalctl -u $svc -n 20 --no-pager 2>/dev/null"
            diag_explain "Read the logs above. The error usually appears in the last few lines."
            diag_fix "Try restarting: sudo systemctl restart $svc"
            diag_fix "Check config: sudo $svc -t  (works for nginx, apache, etc.)"
            ;;
        inactive)
            diag_verdict "warn" "$svc is stopped (not running)"
            diag_fix "Start it: sudo systemctl start $svc"
            diag_fix "Enable on boot: sudo systemctl enable $svc"
            ;;
        *)
            diag_verdict "warn" "$svc status: $active"
            diag_run "Full status" "systemctl status $svc 2>&1"
            ;;
    esac
}

diag_service_crash() {
    diag_section "Service Crash Loop Detection"

    echo -e "  ${C_WHITE}Which service? (or Enter to go back):${C_RESET}"
    printf "  Service name: "
    read -r svc

    if [ -z "$svc" ]; then
        echo -e "  ${C_DIM}Skipped.${C_RESET}"
        return
    fi

    # Count recent restarts
    local restart_count
    restart_count=$(journalctl -u "$svc" --since "1 hour ago" 2>/dev/null | grep -ci "started\|restarted" || echo "0")

    if [ "$restart_count" -gt 5 ]; then
        diag_verdict "critical" "$svc restarted $restart_count times in the last hour"
        diag_explain "This is a crash loop. The service starts, fails, restarts, fails again."
    elif [ "$restart_count" -gt 0 ]; then
        diag_verdict "warn" "$svc restarted $restart_count times in the last hour"
    else
        diag_verdict "ok" "No recent restarts detected"
    fi

    diag_run "Error lines from logs" "journalctl -u $svc -p err --since '1 hour ago' --no-pager 2>/dev/null | tail -10"
    diag_run "Service configuration" "systemctl cat $svc 2>/dev/null | head -20"

    diag_fix "Stop the loop: sudo systemctl stop $svc"
    diag_fix "Check config files for syntax errors"
    diag_fix "Check dependencies: systemctl list-dependencies $svc"
}

diag_failed_services() {
    diag_section "All Failed Services"

    diag_run "Failed units" "systemctl --failed 2>/dev/null"

    local fail_count
    fail_count=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    if [ "$fail_count" -gt 0 ]; then
        diag_verdict "warn" "$fail_count failed service(s) found"
        diag_explain "Check each with: systemctl status <service> and journalctl -u <service>"
    else
        diag_verdict "ok" "No failed services"
    fi
}

diag_docker() {
    diag_section "Docker Container Status"

    if ! command -v docker >/dev/null 2>&1; then
        diag_verdict "warn" "Docker is not installed"
        diag_fix "Install: curl -fsSL https://get.docker.com | sh"
        return
    fi

    if ! docker info >/dev/null 2>&1; then
        diag_verdict "critical" "Docker daemon is not running or you lack permissions"
        diag_fix "Start Docker: sudo systemctl start docker"
        diag_fix "Add yourself to docker group: sudo usermod -aG docker \$USER"
        return
    fi

    diag_run "Running containers" "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null"
    diag_run "Stopped/crashed containers" "docker ps -a --filter 'status=exited' --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null | head -10"

    local exited
    exited=$(docker ps -a --filter 'status=exited' -q 2>/dev/null | wc -l)
    if [ "$exited" -gt 0 ]; then
        diag_verdict "warn" "$exited stopped container(s) found"
        diag_fix "Check logs: docker logs <container_name>"
        diag_fix "Remove stopped: docker container prune"
    fi

    diag_run "Docker disk usage" "docker system df 2>/dev/null"
}

diag_config_syntax() {
    diag_section "Configuration Syntax Check"

    echo -e "  ${C_WHITE}Which service to check? (or Enter to go back):${C_RESET}"
    echo ""
    echo -e "  ${C_DIM}  Common services: nginx, apache2, sshd, named, postfix${C_RESET}"
    echo -e "  ${C_DIM}  Or enter a config file path to check bash/python syntax${C_RESET}"
    echo ""
    printf "  Service or file: "
    read -r target

    if [ -z "$target" ]; then
        echo -e "  ${C_DIM}Skipped.${C_RESET}"
        return
    fi

    case "$target" in
        nginx)
            diag_run "nginx config test" "sudo nginx -t 2>&1"
            if sudo nginx -t 2>/dev/null; then
                diag_verdict "ok" "nginx configuration is valid"
            else
                diag_verdict "critical" "nginx configuration has errors"
                diag_fix "Edit the config: sudo nano /etc/nginx/nginx.conf"
                diag_fix "Check sites-enabled: ls -la /etc/nginx/sites-enabled/"
                diag_fix "Common issue: duplicate listen directives or missing semicolons"
            fi
            ;;
        apache2|httpd)
            diag_run "Apache config test" "sudo apache2ctl configtest 2>&1 || sudo httpd -t 2>&1"
            if sudo apache2ctl configtest 2>/dev/null || sudo httpd -t 2>/dev/null; then
                diag_verdict "ok" "Apache configuration is valid"
            else
                diag_verdict "critical" "Apache configuration has errors"
                diag_fix "Check: sudo apache2ctl configtest"
                diag_fix "Common: missing module, bad VirtualHost, typo in path"
            fi
            ;;
        sshd|ssh)
            diag_run "SSHD config test" "sudo sshd -t 2>&1"
            if sudo sshd -t 2>/dev/null; then
                diag_verdict "ok" "SSHD configuration is valid"
            else
                diag_verdict "critical" "SSHD configuration has errors"
                diag_fix "Edit: sudo nano /etc/ssh/sshd_config"
                diag_fix "Common: invalid keyword, bad permissions on config"
            fi
            ;;
        named|bind)
            diag_run "BIND/named config check" "sudo named-checkconf 2>&1"
            if sudo named-checkconf 2>/dev/null; then
                diag_verdict "ok" "BIND configuration is valid"
            else
                diag_verdict "critical" "BIND configuration has errors"
            fi
            ;;
        postfix)
            diag_run "Postfix config check" "sudo postfix check 2>&1"
            ;;
        *.sh)
            if [ -f "$target" ]; then
                diag_run "Bash syntax check" "bash -n '$target' 2>&1"
                if bash -n "$target" 2>/dev/null; then
                    diag_verdict "ok" "$target has no syntax errors"
                    if command -v shellcheck >/dev/null 2>&1; then
                        diag_run "Shellcheck analysis" "shellcheck '$target' 2>&1 | head -20"
                    else
                        diag_explain "Install shellcheck for deeper analysis: sudo apt install shellcheck"
                    fi
                else
                    diag_verdict "critical" "$target has bash syntax errors"
                fi
            else
                diag_verdict "critical" "File not found: $target"
            fi
            ;;
        *.py)
            if [ -f "$target" ]; then
                diag_run "Python syntax check" "python3 -m py_compile '$target' 2>&1"
                if python3 -m py_compile "$target" 2>/dev/null; then
                    diag_verdict "ok" "$target has no Python syntax errors"
                else
                    diag_verdict "critical" "$target has Python syntax errors"
                fi
            else
                diag_verdict "critical" "File not found: $target"
            fi
            ;;
        *)
            # Try systemd config check
            if systemctl cat "$target" >/dev/null 2>&1; then
                diag_run "Systemd unit syntax" "systemd-analyze verify ${target}.service 2>&1 | head -10"
                diag_run "Unit file" "systemctl cat '$target' 2>/dev/null | head -20"
                diag_verdict "ok" "Checked systemd unit for $target"
            elif [ -f "$target" ]; then
                # Try to guess file type
                local filetype
                filetype=$(file -b "$target" 2>/dev/null | head -1)
                diag_explain "File type: $filetype"
                diag_run "File contents (first 10 lines)" "head -10 '$target'"
            else
                diag_verdict "warn" "Unknown service: $target"
                diag_explain "Supported services: nginx, apache2, sshd, named, postfix"
                diag_explain "Or provide a file path for bash/python syntax check"
            fi
            ;;
    esac
}

diag_dependencies() {
    diag_section "Service Dependency Analysis"

    echo -e "  ${C_WHITE}Which service to check dependencies for? (or Enter to go back):${C_RESET}"
    printf "  Service name: "
    read -r svc

    if [ -z "$svc" ]; then
        echo -e "  ${C_DIM}Skipped.${C_RESET}"
        return
    fi

    # Check if service exists
    if ! systemctl cat "$svc" >/dev/null 2>&1; then
        diag_verdict "critical" "Service '$svc' not found"
        diag_fix "List available services: systemctl list-unit-files --type=service | grep '$svc'"
        return
    fi

    # Show what this service depends on
    diag_run "Dependencies of $svc (what it needs)" "systemctl list-dependencies '$svc' 2>/dev/null | head -20"

    # Show what depends on this service
    diag_run "Reverse dependencies (what needs $svc)" "systemctl list-dependencies '$svc' --reverse 2>/dev/null | head -15"

    # Check if dependencies are running
    echo ""
    echo -e "  ${C_WHITE}Checking if dependencies are active:${C_RESET}"
    echo ""

    local dep_issues=0
    while IFS= read -r dep; do
        dep=$(echo "$dep" | sed 's/[│├└─● ]//g' | sed 's/\x1b\[[0-9;]*m//g' | tr -d ' ')
        [ -z "$dep" ] && continue
        [[ "$dep" == *".service" ]] || continue
        local dep_name="${dep%.service}"

        local status
        status=$(systemctl is-active "$dep_name" 2>/dev/null || echo "unknown")
        case "$status" in
            active)
                echo -e "    ${C_GREEN}✅ $dep_name: active${C_RESET}"
                ;;
            inactive|failed)
                echo -e "    ${C_RED}❌ $dep_name: $status${C_RESET}"
                dep_issues=$((dep_issues + 1))
                ;;
            *)
                echo -e "    ${C_DIM}── $dep_name: $status${C_RESET}"
                ;;
        esac
    done < <(systemctl list-dependencies "$svc" --plain 2>/dev/null)

    echo ""
    if [ "$dep_issues" -gt 0 ]; then
        diag_verdict "critical" "$dep_issues dependency issue(s) found"
        diag_explain "Fix the failed dependencies first, then restart $svc."
        diag_fix "Start failed dep: sudo systemctl start <dependency>"
        diag_fix "Then restart: sudo systemctl restart $svc"
    else
        diag_verdict "ok" "All dependencies are active"
    fi

    # Show service ordering
    diag_run "Service ordering (After/Before)" "systemctl cat '$svc' 2>/dev/null | grep -iE '^After=|^Before=|^Requires=|^Wants=' || echo 'No explicit ordering found'"
}

# ══════════════════════════════════════════════
#  CATEGORY 5: PERMISSIONS & SECURITY
# ══════════════════════════════════════════════

diag_permissions() {
    print_header "🔒 Permissions & Security"
    echo ""
    echo -e "  ${C_WHITE}What's happening?${C_RESET}"
    echo ""
    print_menu_item "1" "Permission denied on a file/directory"
    print_menu_item "2" "Sudo not working"
    print_menu_item "3" "SELinux or AppArmor blocking something"
    print_menu_item "4" "Security audit (quick scan)"
    print_menu_item "5" "Run all security checks"
    echo ""
    print_menu_item "9" "Back"
    print_prompt
    read -r choice || return 0

    case "$choice" in
        1) diag_file_perms ;;
        2) diag_sudo ;;
        3) diag_mac ;;
        4) diag_security_audit ;;
        5) diag_file_perms; diag_pause; diag_sudo; diag_pause; diag_mac; diag_pause; diag_security_audit ;;
        9) cmd_diagnose ;;
        *) diag_permissions ;;
    esac
    diag_back_prompt
}

diag_file_perms() {
    diag_section "File Permission Analysis"

    echo -e "  ${C_WHITE}Which file or directory? (full path, or Enter to go back):${C_RESET}"
    printf "  Path: "
    read -r filepath

    if [ -z "$filepath" ]; then
        echo -e "  ${C_DIM}Skipped.${C_RESET}"
        return
    fi

    if [ ! -e "$filepath" ]; then
        diag_verdict "critical" "Path does not exist: $filepath"
        diag_fix "Check spelling. Use tab completion. Run: find / -name '$(basename "$filepath")' 2>/dev/null"
        return
    fi

    diag_run "File details" "ls -la $filepath"
    diag_run "Full path ownership chain" "namei -l $filepath 2>/dev/null || ls -ld $(dirname $filepath)"
    diag_run "Your identity" "id"

    local owner
    owner=$(stat -c '%U' "$filepath" 2>/dev/null)
    local group
    group=$(stat -c '%G' "$filepath" 2>/dev/null)
    local perms
    perms=$(stat -c '%a' "$filepath" 2>/dev/null)

    echo -e "  ${C_WHITE}Owner: $owner  |  Group: $group  |  Mode: $perms${C_RESET}"

    if [ ! -r "$filepath" ]; then
        diag_verdict "critical" "You cannot READ this file"
        diag_fix "sudo chmod +r $filepath"
        diag_fix "Or: sudo chown \$(whoami) $filepath"
    fi
    if [ ! -w "$filepath" ]; then
        diag_verdict "warn" "You cannot WRITE to this file"
        diag_fix "sudo chmod u+w $filepath"
    fi
    if [ -d "$filepath" ] && [ ! -x "$filepath" ]; then
        diag_verdict "warn" "You cannot ENTER this directory (no execute bit)"
        diag_fix "sudo chmod +x $filepath"
    fi

    if [ -r "$filepath" ] && [ -w "$filepath" ]; then
        diag_verdict "ok" "You have read and write access"
    fi
}

diag_sudo() {
    diag_section "Sudo Access"

    diag_run "Your user and groups" "id"

    if sudo -n true 2>/dev/null; then
        diag_verdict "ok" "You have passwordless sudo access"
    else
        local in_sudo
        in_sudo=$(groups 2>/dev/null | grep -wc "sudo\|wheel")
        if [ "$in_sudo" -gt 0 ]; then
            diag_verdict "ok" "You are in the sudo/wheel group (password required)"
        else
            diag_verdict "critical" "You are NOT in the sudo/wheel group"
            diag_fix "Ask an admin to run: sudo usermod -aG sudo $(whoami)"
            diag_fix "Or login as root: su -"
        fi
    fi

    diag_run "Sudo configuration for your user" "sudo -l 2>/dev/null | head -10 || echo 'Cannot check (may need password)'"
}

diag_security_audit() {
    diag_section "Quick Security Scan"

    # World-writable files
    local ww_count
    ww_count=$(find /etc /var -xdev -type f -perm -o+w 2>/dev/null | wc -l)
    if [ "$ww_count" -gt 0 ]; then
        diag_verdict "warn" "$ww_count world-writable files in /etc and /var"
        diag_run "World-writable files" "find /etc /var -xdev -type f -perm -o+w 2>/dev/null | head -10"
        diag_fix "Fix: sudo chmod o-w <file>"
    else
        diag_verdict "ok" "No world-writable files in /etc or /var"
    fi

    # SUID binaries
    local suid_count
    suid_count=$(find /usr -xdev -type f -perm -4000 2>/dev/null | wc -l)
    diag_verdict "ok" "$suid_count SUID binaries found (review if unexpected)"

    # Users with UID 0
    local root_count
    root_count=$(awk -F: '$3 == 0 {print $1}' /etc/passwd | wc -l)
    if [ "$root_count" -gt 1 ]; then
        diag_verdict "critical" "Multiple users with UID 0 (root-level access):"
        awk -F: '$3 == 0 {print "    " $1}' /etc/passwd
    else
        diag_verdict "ok" "Only root has UID 0"
    fi

    # Password-less accounts
    local nopass
    nopass=$(awk -F: '($2 == "" || $2 == "!") && $1 != "root" {print $1}' /etc/shadow 2>/dev/null | wc -l)
    if [ "$nopass" -gt 0 ]; then
        diag_verdict "warn" "$nopass accounts without passwords"
    fi

    # Firewall
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status
        ufw_status=$(sudo ufw status 2>/dev/null | head -1 || echo "unknown")
        if echo "$ufw_status" | grep -qi "active"; then
            diag_verdict "ok" "Firewall (UFW) is active"
        else
            diag_verdict "warn" "Firewall (UFW) is NOT active"
            diag_fix "Enable: sudo ufw enable"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            diag_verdict "ok" "Firewall (firewalld) is running"
        else
            diag_verdict "warn" "Firewall is NOT running"
        fi
    fi

    # Unattended upgrades
    if dpkg -l unattended-upgrades 2>/dev/null | grep -q "^ii"; then
        diag_verdict "ok" "Unattended security updates enabled"
    else
        diag_verdict "warn" "Automatic security updates not configured"
        diag_fix "Install: sudo apt install unattended-upgrades"
    fi
}

diag_mac() {
    diag_section "Mandatory Access Control (SELinux / AppArmor)"

    local mac_type="none"

    # Detect which MAC system is in use
    if command -v getenforce >/dev/null 2>&1; then
        mac_type="selinux"
        local se_status
        se_status=$(getenforce 2>/dev/null || echo "Unknown")

        diag_run "SELinux status" "sestatus 2>/dev/null || getenforce 2>/dev/null"

        case "$se_status" in
            Enforcing)
                diag_verdict "ok" "SELinux is Enforcing (active protection)"
                ;;
            Permissive)
                diag_verdict "warn" "SELinux is Permissive (logging only, not blocking)"
                diag_explain "Permissive mode logs violations but doesn't enforce. Good for debugging."
                diag_fix "Re-enable: sudo setenforce 1"
                ;;
            Disabled)
                diag_verdict "warn" "SELinux is Disabled"
                diag_fix "Enable in /etc/selinux/config (requires reboot)"
                ;;
        esac

        # Check for recent denials
        diag_run "Recent SELinux denials" "sudo ausearch -m AVC -ts recent 2>/dev/null | tail -15 || journalctl 2>/dev/null | grep -i 'avc.*denied' | tail -10 || echo 'No denials found (or no access)'"

        local avc_count
        avc_count=$(sudo ausearch -m AVC -ts recent 2>/dev/null | grep -c "^type=AVC" || echo "0")
        avc_count=$(echo "$avc_count" | head -1 | tr -dc '0-9')
        avc_count="${avc_count:-0}"
        if [ "$avc_count" -gt 0 ] 2>/dev/null; then
            diag_verdict "warn" "$avc_count recent SELinux denial(s)"
            diag_explain "Something was blocked by SELinux policy."
            diag_fix "Generate a fix: sudo audit2allow -a"
            diag_fix "Temporarily allow: sudo setenforce 0 (test only!)"
            diag_fix "Create custom policy: sudo audit2allow -a -M mypolicy && sudo semodule -i mypolicy.pp"
        fi

        # Boolean status
        if command -v getsebool >/dev/null 2>&1; then
            diag_run "Key SELinux booleans" "getsebool httpd_can_network_connect httpd_enable_cgi 2>/dev/null || echo 'No httpd booleans (may not be installed)'"
        fi

    elif command -v aa-status >/dev/null 2>&1 || [ -d /etc/apparmor.d ]; then
        mac_type="apparmor"

        diag_run "AppArmor status" "sudo aa-status 2>/dev/null || echo 'Need sudo for aa-status'"

        local aa_enforcing
        aa_enforcing=$(sudo aa-status 2>/dev/null | grep -c "enforce" || echo "0")
        local aa_complain
        aa_complain=$(sudo aa-status 2>/dev/null | grep -c "complain" || echo "0")

        if [ "$aa_enforcing" -gt 0 ] 2>/dev/null; then
            diag_verdict "ok" "AppArmor active: $aa_enforcing profile(s) enforcing"
        fi
        if [ "$aa_complain" -gt 0 ] 2>/dev/null; then
            diag_verdict "warn" "$aa_complain profile(s) in complain mode (logging only)"
        fi

        # Check for denials
        diag_run "Recent AppArmor denials" "dmesg 2>/dev/null | grep -i 'apparmor.*denied' | tail -10 || journalctl -k 2>/dev/null | grep -i 'apparmor.*denied' | tail -10 || echo 'No denials found'"

        local aa_denials
        aa_denials=$(dmesg 2>/dev/null | grep -ci "apparmor.*denied" || echo "0")
        aa_denials=$(echo "$aa_denials" | head -1 | tr -dc '0-9')
        aa_denials="${aa_denials:-0}"
        if [ "$aa_denials" -gt 0 ] 2>/dev/null; then
            diag_verdict "warn" "$aa_denials AppArmor denial(s) in kernel log"
            diag_explain "AppArmor is blocking an application. Check which profile is involved."
            diag_fix "Set profile to complain: sudo aa-complain /path/to/binary"
            diag_fix "Disable a profile: sudo aa-disable /path/to/binary"
            diag_fix "After fixing, re-enforce: sudo aa-enforce /path/to/binary"
        else
            diag_verdict "ok" "No AppArmor denials detected"
        fi

        # List profiles
        diag_run "AppArmor profiles" "ls /etc/apparmor.d/ 2>/dev/null | grep -v 'abstractions\|cache\|force\|local\|tunables' | head -15 || echo 'No profiles directory'"
    fi

    if [ "$mac_type" = "none" ]; then
        diag_verdict "warn" "No MAC system detected (neither SELinux nor AppArmor)"
        diag_explain "Most production Linux distributions use AppArmor (Ubuntu/Debian) or SELinux (RHEL/CentOS)."
        diag_explain "MAC provides mandatory access control beyond standard file permissions."
        diag_fix "Ubuntu/Debian: sudo apt install apparmor apparmor-utils"
        diag_fix "RHEL/CentOS: usually pre-installed, check /etc/selinux/config"
    fi
}

# ══════════════════════════════════════════════
#  CATEGORY 6: HARDWARE & KERNEL
# ══════════════════════════════════════════════

diag_hardware_menu() {
    print_header "🔧 Hardware & Kernel"
    echo ""
    echo -e "  ${C_WHITE}What's happening?${C_RESET}"
    echo ""
    print_menu_item "1" "Device not detected (USB, disk, NIC)"
    print_menu_item "2" "Driver or module issues"
    print_menu_item "3" "Kernel errors (OOPS, panics)"
    print_menu_item "4" "Hardware health (SMART, temperature)"
    print_menu_item "5" "Run all hardware checks"
    echo ""
    print_menu_item "9" "Back"
    print_prompt
    read -r choice || return 0

    case "$choice" in
        1) diag_devices ;;
        2) diag_drivers ;;
        3) diag_kernel ;;
        4) diag_hw_health ;;
        5) diag_devices; diag_pause; diag_drivers; diag_pause; diag_kernel; diag_pause; diag_hw_health ;;
        9) cmd_diagnose ;;
        *) diag_hardware_menu ;;
    esac
    diag_back_prompt
}

diag_devices() {
    diag_section "Device Detection"

    diag_run "PCI devices (NICs, GPUs, controllers)" "lspci 2>/dev/null | head -20 || echo 'lspci not available (install pciutils)'"
    diag_run "USB devices" "lsusb 2>/dev/null | head -15 || echo 'lsusb not available (install usbutils)'"
    diag_run "Block devices (disks, partitions)" "lsblk 2>/dev/null || echo 'lsblk not available'"
    diag_run "Recent device events (last 20)" "dmesg 2>/dev/null | grep -iE 'usb|sd[a-z]|eth|wlan|nvme|attached|removed|new.*device' | tail -20 || echo 'No access to dmesg'"

    echo ""
    echo -e "  ${C_WHITE}Looking for a specific device? (Enter keyword or press Enter to skip):${C_RESET}"
    printf "  Device keyword: "
    read -r dev_keyword
    if [ -n "$dev_keyword" ]; then
        diag_run "PCI devices matching '$dev_keyword'" "lspci 2>/dev/null | grep -i '$dev_keyword' || echo 'Not found in PCI'"
        diag_run "USB devices matching '$dev_keyword'" "lsusb 2>/dev/null | grep -i '$dev_keyword' || echo 'Not found in USB'"
        diag_run "dmesg mentions of '$dev_keyword'" "dmesg 2>/dev/null | grep -i '$dev_keyword' | tail -10 || echo 'Not found in kernel log'"
    fi
}

diag_drivers() {
    diag_section "Kernel Modules & Drivers"

    diag_run "Loaded kernel modules (count)" "lsmod 2>/dev/null | wc -l"
    diag_run "Recently loaded modules" "dmesg 2>/dev/null | grep -i 'module\|firmware\|driver' | tail -15 || echo 'No access to dmesg'"

    # Check for module load failures
    local mod_errors
    mod_errors=$(dmesg 2>/dev/null | grep -ciE "firmware.*fail|module.*error|driver.*fail" || echo "0")
    mod_errors=$(echo "$mod_errors" | head -1 | tr -dc '0-9')
    mod_errors="${mod_errors:-0}"
    if [ "$mod_errors" -gt 0 ] 2>/dev/null; then
        diag_verdict "warn" "$mod_errors driver/firmware errors in kernel log"
        diag_run "Driver errors" "dmesg 2>/dev/null | grep -iE 'firmware.*fail|module.*error|driver.*fail' | tail -10"
        diag_fix "Check if firmware is installed: apt search firmware"
        diag_fix "Try loading manually: sudo modprobe <module_name>"
    else
        diag_verdict "ok" "No driver errors detected"
    fi

    echo ""
    echo -e "  ${C_WHITE}Check a specific module? (Enter name or press Enter to skip):${C_RESET}"
    printf "  Module name: "
    read -r mod_name
    if [ -n "$mod_name" ]; then
        if lsmod 2>/dev/null | grep -q "^$mod_name"; then
            diag_verdict "ok" "Module '$mod_name' is loaded"
            diag_run "Module info" "modinfo $mod_name 2>/dev/null | head -10"
        else
            diag_verdict "warn" "Module '$mod_name' is NOT loaded"
            diag_fix "Load it: sudo modprobe $mod_name"
            diag_fix "Check if it exists: modinfo $mod_name"
        fi
    fi
}

diag_kernel() {
    diag_section "Kernel Health"

    diag_run "Kernel version" "uname -r"
    diag_run "Full kernel info" "uname -a"

    # Check for kernel panics, oops, bugs
    diag_run "Kernel errors" "dmesg 2>/dev/null | grep -iE 'oops|panic|bug|rip|call.trace|segfault' | tail -15 || echo 'No access to dmesg'"

    local kernel_errors
    kernel_errors=$(dmesg 2>/dev/null | grep -ciE "oops|panic|bug.*kernel|call.trace" || echo "0")
    kernel_errors=$(echo "$kernel_errors" | head -1 | tr -dc '0-9')
    kernel_errors="${kernel_errors:-0}"
    if [ "$kernel_errors" -gt 0 ] 2>/dev/null; then
        diag_verdict "critical" "$kernel_errors kernel errors detected (OOPS/panic/bug)"
        diag_explain "Kernel errors indicate serious issues: bad hardware, driver bugs, or memory corruption."
        diag_fix "Update kernel: sudo apt update && sudo apt upgrade"
        diag_fix "Check for bad RAM: schedule memtest on next boot"
        diag_fix "If a specific driver crashes, try disabling it: sudo modprobe -r <module>"
    else
        diag_verdict "ok" "No kernel errors detected"
    fi

    # Kernel log errors (via journalctl)
    diag_run "Kernel error messages (last hour)" "journalctl -k -p err --since '1 hour ago' --no-pager 2>/dev/null | tail -10 || echo 'No journalctl access'"

    # Tainted kernel check
    local tainted
    tainted=$(cat /proc/sys/kernel/tainted 2>/dev/null || echo "0")
    if [ "$tainted" != "0" ]; then
        diag_verdict "warn" "Kernel is tainted (value: $tainted)"
        diag_explain "Tainted = non-free module loaded, or a previous error. Not always a problem."
    else
        diag_verdict "ok" "Kernel is not tainted"
    fi
}

diag_hw_health() {
    diag_section "Hardware Health"

    # Temperature
    if command -v sensors >/dev/null 2>&1; then
        diag_run "Temperature sensors" "sensors 2>/dev/null"
    else
        # Try thermal zones directly
        local has_thermal=0
        for tz in /sys/class/thermal/thermal_zone*/temp; do
            if [ -f "$tz" ]; then
                has_thermal=1
                break
            fi
        done
        if [ "$has_thermal" -eq 1 ]; then
            diag_run "Thermal zones" "for tz in /sys/class/thermal/thermal_zone*/temp; do zone=\$(dirname \"\$tz\"); name=\$(cat \"\$zone/type\" 2>/dev/null || basename \"\$zone\"); temp=\$(cat \"\$tz\" 2>/dev/null); echo \"\$name: \$((temp/1000))°C\"; done"
        else
            diag_explain "No temperature sensors accessible. Install lm-sensors: sudo apt install lm-sensors && sudo sensors-detect"
        fi
    fi

    # SMART disk health
    if command -v smartctl >/dev/null 2>&1; then
        local disks
        disks=$(lsblk -dno NAME,TYPE 2>/dev/null | awk '$2=="disk" {print "/dev/"$1}')
        for disk in $disks; do
            diag_run "SMART health: $disk" "sudo smartctl -H $disk 2>/dev/null | grep -E 'result|Health' || echo 'Cannot read SMART (may need sudo)'"
        done
    else
        diag_explain "SMART not available. Install: sudo apt install smartmontools"
        diag_explain "Then check: sudo smartctl -a /dev/sda"
    fi

    # Memory errors
    diag_run "Memory hardware info" "dmesg 2>/dev/null | grep -iE 'memory|EDAC|mce|ecc' | tail -5 || echo 'No memory errors in dmesg'"

    local mem_errors
    mem_errors=$(dmesg 2>/dev/null | grep -ciE "EDAC.*error|mce.*error|ecc.*error" || echo "0")
    mem_errors=$(echo "$mem_errors" | head -1 | tr -dc '0-9')
    mem_errors="${mem_errors:-0}"
    if [ "$mem_errors" -gt 0 ] 2>/dev/null; then
        diag_verdict "critical" "Memory hardware errors detected"
        diag_fix "Run memtest86+ on next boot to identify faulty RAM"
        diag_fix "Check which DIMM: sudo dmidecode -t memory"
    else
        diag_verdict "ok" "No memory hardware errors"
    fi

    # Uptime and load context
    diag_run "System uptime" "uptime"
}

# ══════════════════════════════════════════════
#  CATEGORY 7: FULL HEALTH CHECK
# ══════════════════════════════════════════════

diag_health_check() {
    print_header "🩺 Full System Health Check"
    echo ""
    echo -e "  ${C_DIM}Running comprehensive diagnostics...${C_RESET}"
    echo ""

    local score=0
    local total=0
    local warnings=0
    local criticals=0

    # --- CPU ---
    total=$((total + 1))
    local idle
    idle=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $8}' | cut -d. -f1)
    if [ -n "$idle" ]; then
        local cpu_used=$((100 - idle))
        if [ "$cpu_used" -lt 80 ]; then
            score=$((score + 1))
            echo -e "  ${C_GREEN}✅ CPU: ${cpu_used}%${C_RESET}"
        elif [ "$cpu_used" -lt 95 ]; then
            warnings=$((warnings + 1))
            echo -e "  ${C_YELLOW}⚠️  CPU: ${cpu_used}%${C_RESET}"
        else
            criticals=$((criticals + 1))
            echo -e "  ${C_RED}🚨 CPU: ${cpu_used}%${C_RESET}"
        fi
    else
        score=$((score + 1))
        echo -e "  ${C_DIM}── CPU: unable to check${C_RESET}"
    fi

    # --- Memory ---
    total=$((total + 1))
    local mem_pct
    mem_pct=$(free 2>/dev/null | awk '/^Mem:/ {printf "%.0f", ($2-$7)/$2*100}')
    if [ -n "$mem_pct" ]; then
        if [ "$mem_pct" -lt 80 ]; then
            score=$((score + 1))
            echo -e "  ${C_GREEN}✅ Memory: ${mem_pct}%${C_RESET}"
        elif [ "$mem_pct" -lt 95 ]; then
            warnings=$((warnings + 1))
            echo -e "  ${C_YELLOW}⚠️  Memory: ${mem_pct}%${C_RESET}"
        else
            criticals=$((criticals + 1))
            echo -e "  ${C_RED}🚨 Memory: ${mem_pct}%${C_RESET}"
        fi
    fi

    # --- Disk ---
    total=$((total + 1))
    local max_disk
    max_disk=$(df 2>/dev/null | awk 'NR>1 && $1 !~ /tmpfs|devtmpfs/ {gsub(/%/,"",$5); if($5+0 > max) max=$5+0} END {print max}')
    if [ -n "$max_disk" ]; then
        if [ "$max_disk" -lt 80 ]; then
            score=$((score + 1))
            echo -e "  ${C_GREEN}✅ Disk: ${max_disk}% (highest partition)${C_RESET}"
        elif [ "$max_disk" -lt 95 ]; then
            warnings=$((warnings + 1))
            echo -e "  ${C_YELLOW}⚠️  Disk: ${max_disk}%${C_RESET}"
        else
            criticals=$((criticals + 1))
            echo -e "  ${C_RED}🚨 Disk: ${max_disk}%${C_RESET}"
        fi
    fi

    # --- Load ---
    total=$((total + 1))
    local load1
    load1=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' | cut -d. -f1)
    local cores
    cores=$(nproc 2>/dev/null || echo 1)
    if [ -n "$load1" ]; then
        if [ "$load1" -le "$cores" ]; then
            score=$((score + 1))
            echo -e "  ${C_GREEN}✅ Load: ${load1} (${cores} cores)${C_RESET}"
        elif [ "$load1" -le "$((cores * 2))" ]; then
            warnings=$((warnings + 1))
            echo -e "  ${C_YELLOW}⚠️  Load: ${load1} (${cores} cores)${C_RESET}"
        else
            criticals=$((criticals + 1))
            echo -e "  ${C_RED}🚨 Load: ${load1} (${cores} cores)${C_RESET}"
        fi
    fi

    # --- Failed services ---
    total=$((total + 1))
    local failed_svcs
    failed_svcs=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    if [ "$failed_svcs" -eq 0 ]; then
        score=$((score + 1))
        echo -e "  ${C_GREEN}✅ Services: all OK${C_RESET}"
    else
        warnings=$((warnings + 1))
        echo -e "  ${C_YELLOW}⚠️  Services: ${failed_svcs} failed${C_RESET}"
    fi

    # --- Network ---
    total=$((total + 1))
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        score=$((score + 1))
        echo -e "  ${C_GREEN}✅ Network: internet reachable${C_RESET}"
    else
        if ip route 2>/dev/null | grep -q default; then
            warnings=$((warnings + 1))
            echo -e "  ${C_YELLOW}⚠️  Network: gateway set but internet unreachable${C_RESET}"
        else
            criticals=$((criticals + 1))
            echo -e "  ${C_RED}🚨 Network: no connectivity${C_RESET}"
        fi
    fi

    # --- Calculate grade ---
    echo ""
    echo -e "  ${C_PURPLE}━━━ Health Report ━━━${C_RESET}"
    echo ""

    if [ "$total" -gt 0 ]; then
        local pct=$((score * 100 / total))
        local grade
        if [ "$criticals" -gt 0 ]; then
            grade="F"
        elif [ "$pct" -ge 90 ]; then
            grade="A"
        elif [ "$pct" -ge 80 ]; then
            grade="B"
        elif [ "$pct" -ge 60 ]; then
            grade="C"
        elif [ "$pct" -ge 40 ]; then
            grade="D"
        else
            grade="F"
        fi

        case "$grade" in
            A) echo -e "  ${C_GREEN}Grade: $grade ($pct%) — Excellent${C_RESET}" ;;
            B) echo -e "  ${C_GREEN}Grade: $grade ($pct%) — Good${C_RESET}" ;;
            C) echo -e "  ${C_YELLOW}Grade: $grade ($pct%) — Needs Attention${C_RESET}" ;;
            *) echo -e "  ${C_RED}Grade: $grade ($pct%) — Action Required${C_RESET}" ;;
        esac

        echo -e "  ${C_WHITE}Checks: $score/$total passed | $warnings warnings | $criticals critical${C_RESET}"
    fi

    echo ""
    if [ "$criticals" -gt 0 ]; then
        echo -e "  ${C_RED}Run: practicum diagnose → pick the category with issues${C_RESET}"
    elif [ "$warnings" -gt 0 ]; then
        echo -e "  ${C_YELLOW}Minor issues found. Run specific diagnostics for details.${C_RESET}"
    else
        echo -e "  ${C_GREEN}System is healthy. No action needed.${C_RESET}"
    fi

    diag_back_prompt
}

# ══════════════════════════════════════════════
#  COMPACT HEALTH (for practicum status)
# ══════════════════════════════════════════════

diag_health_compact() {
    # Runs silently, returns a one-line health summary
    local score=0
    local total=0
    local issues=""

    # CPU
    total=$((total + 1))
    local idle
    idle=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $8}' | cut -d. -f1)
    idle="${idle:-0}"
    if [ "$idle" -gt 0 ] 2>/dev/null && [ "$((100 - idle))" -lt 80 ]; then
        score=$((score + 1))
    elif [ "$idle" -gt 0 ] 2>/dev/null; then
        issues="${issues}CPU "
    else
        score=$((score + 1))
    fi

    # Memory
    total=$((total + 1))
    local mem_pct
    mem_pct=$(free 2>/dev/null | awk '/^Mem:/ {printf "%.0f", ($2-$7)/$2*100}')
    if [ -n "$mem_pct" ] && [ "$mem_pct" -lt 80 ]; then
        score=$((score + 1))
    elif [ -n "$mem_pct" ]; then
        issues="${issues}MEM "
    else
        score=$((score + 1))
    fi

    # Disk
    total=$((total + 1))
    local max_disk
    max_disk=$(df 2>/dev/null | awk 'NR>1 && $1 !~ /tmpfs|devtmpfs|loop|none/ {gsub(/%/,"",$5); if($5+0 > max) max=$5+0} END {print max+0}')
    if [ "$max_disk" -lt 80 ] 2>/dev/null; then
        score=$((score + 1))
    else
        issues="${issues}DISK "
    fi

    # Load
    total=$((total + 1))
    local load1
    load1=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' | cut -d. -f1)
    local cores
    cores=$(nproc 2>/dev/null || echo 1)
    if [ -n "$load1" ] && [ "$load1" -le "$cores" ] 2>/dev/null; then
        score=$((score + 1))
    elif [ -n "$load1" ]; then
        issues="${issues}LOAD "
    else
        score=$((score + 1))
    fi

    # Services
    total=$((total + 1))
    local failed_svcs
    failed_svcs=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    if [ "$failed_svcs" -eq 0 ] 2>/dev/null; then
        score=$((score + 1))
    else
        issues="${issues}SVCS "
    fi

    # Network
    total=$((total + 1))
    if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        score=$((score + 1))
    else
        issues="${issues}NET "
    fi

    # Grade
    local pct=0
    [ "$total" -gt 0 ] && pct=$((score * 100 / total))
    local grade
    if [ "$pct" -ge 90 ]; then grade="A"
    elif [ "$pct" -ge 80 ]; then grade="B"
    elif [ "$pct" -ge 60 ]; then grade="C"
    elif [ "$pct" -ge 40 ]; then grade="D"
    else grade="F"; fi

    # Output
    case "$grade" in
        A|B) echo -e "  ${C_WHITE}System:${C_RESET}    ${C_GREEN}${grade} (${score}/${total} checks passed)${C_RESET}" ;;
        C)   echo -e "  ${C_WHITE}System:${C_RESET}    ${C_YELLOW}${grade} (${score}/${total}) ⚠️  ${issues}${C_RESET}" ;;
        *)   echo -e "  ${C_WHITE}System:${C_RESET}    ${C_RED}${grade} (${score}/${total}) 🚨 ${issues}${C_RESET}" ;;
    esac
}
