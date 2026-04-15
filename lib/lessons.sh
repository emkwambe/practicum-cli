#!/bin/bash
# Practicum CLI — Lesson Loader

COURSE_DIR=""

detect_course_dir() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    COURSE_DIR="$script_dir/courses/linux-foundations"
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
    echo "========================================="
    cat "$filepath"
    echo ""
    echo "========================================="
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