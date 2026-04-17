#!/bin/bash
# Practicum CLI — Lesson Loader

COURSE_DIR=""
ACTIVE_COURSE_FILE="$HOME/.practicum/active_course"

get_active_course() {
    if [ -f "$ACTIVE_COURSE_FILE" ]; then
        cat "$ACTIVE_COURSE_FILE"
    else
        echo "linux-foundations"
    fi
}

set_active_course() {
    mkdir -p "$HOME/.practicum"
    echo "$1" > "$ACTIVE_COURSE_FILE"
    seed_course_unlocks
}

# Seed the first 3 lessons of Day 1 into the unlock list for the active course
seed_course_unlocks() {
    detect_course_dir
    local day1_dir="$COURSE_DIR/day1"
    [ -d "$day1_dir" ] || return 0
    local i=0
    for f in "$day1_dir"/lesson*.txt; do
        [ -f "$f" ] || continue
        i=$((i + 1))
        [ "$i" -gt 3 ] && break
        local cmd
        cmd=$(basename "$f" .txt | sed 's/lesson[0-9]*_//')
        unlock_lesson "$cmd" 2>/dev/null || true
    done
}

detect_course_dir() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local active
    active=$(get_active_course)
    COURSE_DIR="$script_dir/courses/$active"
}

get_course_name() {
    local slug="${1:-$(get_active_course)}"
    case "$slug" in
        linux-foundations) echo "Linux Foundations" ;;
        git-essentials)    echo "Git & Version Control" ;;
        docker-essentials) echo "Docker & Containers" ;;
        shell-mastery)     echo "Shell Scripting Mastery" ;;
        *) echo "$slug" ;;
    esac
}

list_available_courses() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    for d in "$script_dir/courses"/*/; do
        [ -d "$d" ] || continue
        basename "$d"
    done
}

get_day_title() {
    local day_num="$1"
    detect_course_dir
    local titles_file="$COURSE_DIR/day_titles.txt"
    if [ -f "$titles_file" ]; then
        sed -n "${day_num}p" "$titles_file"
    else
        echo "Day $day_num"
    fi
}

# Unlock the next lesson based on the course's unlock_chain.txt
# Usage: unlock_next_from_chain <current_cmd>
unlock_next_from_chain() {
    local current_cmd="$1"
    detect_course_dir
    local chain_file="$COURSE_DIR/unlock_chain.txt"
    if [ ! -f "$chain_file" ]; then
        return 1
    fi
    local next
    next=$(grep "^${current_cmd}|" "$chain_file" | cut -d'|' -f2 | head -1)
    if [ -n "$next" ]; then
        unlock_lesson "$next"
    fi
}

list_lessons() {
    detect_course_dir
    local day="${1:-day1}"
    local lesson_dir="$COURSE_DIR/$day"
    
    if [ ! -d "$lesson_dir" ]; then
        echo "No lessons found for $day"
        return 1
    fi
    
    print_header "Practicum CLI — $day Lessons"
    
    local i=1
    for f in "$lesson_dir"/lesson*.txt; do
        [ -f "$f" ] || continue
        local name
        name=$(head -1 "$f" | sed 's/^# //')
        local cmd
        cmd=$(basename "$f" .txt | sed 's/lesson[0-9]*_//')
        
        if is_completed "$cmd" 2>/dev/null; then
            print_completed "[$i] $name"
        elif is_unlocked "$cmd" 2>/dev/null; then
            print_unlocked "[$i] $name"
        else
            print_locked "[$i] $name"
        fi
        i=$((i + 1))
    done
    
    echo ""
    print_menu_item "9" "Back to main menu"
    print_menu_item "0" "Exit"
    echo ""
}

load_lesson() {
    detect_course_dir
    local day="${1:-day1}"
    local lesson_file="$2"
    local filepath="$COURSE_DIR/$day/$lesson_file"
    
    if [ ! -f "$filepath" ]; then
        echo "Lesson file not found: $filepath"
        return 1
    fi
    
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    
    while IFS= read -r line; do
        case "$line" in
            "# "*)
                # Main title — bold purple
                echo -e "${C_PURPLE}${line#\# }${C_RESET}"
                ;;
            "## ["*"]"*)
                # ICAR headers — green bold: [WHEN], [INTENT], [CONTEXT], [ACTION], [EXPECTED RESULT]
                echo -e ""
                echo -e "${C_GREEN}${line#\#\# }${C_RESET}"
                ;;
            "## "*)
                # Other H2 headers — cyan
                echo -e ""
                echo -e "${C_CYAN}${line#\#\# }${C_RESET}"
                ;;
            "### "*)
                # H3 headers — white bold
                echo -e "${C_WHITE}${line#\#\#\# }${C_RESET}"
                ;;
            "  "*"-"*|"     -"*)
                # Bullet points — dim
                echo -e "${C_DIM}${line}${C_RESET}"
                ;;
            "WARNING"*|"DANGEROUS"*)
                # Warnings — red
                echo -e "${C_RED}${line}${C_RESET}"
                ;;
            "  "*"—"*)
                # Command examples with em-dash — cyan command, dim description
                local cmd_part="${line%%—*}"
                local desc_part="${line#*—}"
                echo -e "${C_CYAN}${cmd_part}${C_DIM}—${desc_part}${C_RESET}"
                ;;
            [0-9]". "*)
                # Numbered items — white
                echo -e "${C_WHITE}${line}${C_RESET}"
                ;;
            "")
                echo ""
                ;;
            *)
                echo -e "${line}"
                ;;
        esac
    done < "$filepath"
    
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo ""
}

get_lesson_file_by_number() {
    detect_course_dir
    local day="${1:-day1}"
    local num="$2"
    local lesson_dir="$COURSE_DIR/$day"
    local i=1
    
    for f in "$lesson_dir"/lesson*.txt; do
        [ -f "$f" ] || continue
        if [ "$i" -eq "$num" ]; then
            basename "$f"
            return 0
        fi
        i=$((i + 1))
    done
    return 1
}

get_lesson_command() {
    local filename="$1"
    echo "$filename" | sed 's/lesson[0-9]*_//' | sed 's/\.txt//'
}

count_day_lessons() {
    detect_course_dir
    local day="${1:-day1}"
    local count=0
    for f in "$COURSE_DIR/$day"/lesson*.txt; do
        [ -f "$f" ] && count=$((count + 1))
    done
    echo "$count"
}

get_next_lesson_preview() {
    detect_course_dir
    local day="${1:-day1}"
    local completed_count="$2"
    local next_num=$((completed_count + 1))
    local i=1
    for f in "$COURSE_DIR/$day"/lesson*.txt; do
        [ -f "$f" ] || continue
        if [ "$i" -eq "$next_num" ]; then
            head -1 "$f" | sed 's/^# //'
            return 0
        fi
        i=$((i + 1))
    done
    echo ""
}

show_encouragement() {
    local day="${1:-day1}"
    local completed
    completed=$(count_completed)
    local total
    total=$(count_day_lessons "$day")
    local next_name
    next_name=$(get_next_lesson_preview "$day" "$completed")

    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo -e "  ${C_GREEN}🎉 Great job!${C_RESET}"
    echo -e "  ${C_WHITE}Progress: $completed of $total lessons completed${C_RESET}"
    echo ""
    if [ -n "$next_name" ]; then
        echo -e "  ${C_CYAN}📚 Next up: $next_name${C_RESET}"
    else
        echo -e "  ${C_GREEN}🏆 You've completed all lessons for this day!${C_RESET}"
        echo -e "  ${C_CYAN}Take the quiz to test your knowledge.${C_RESET}"
    fi
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo ""
}