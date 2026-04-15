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
    
    echo ""
    echo "========================================="
    echo "  Practicum CLI — $day Lessons"
    echo "========================================="
    echo ""
    
    local i=1
    for f in "$lesson_dir"/lesson*.txt; do
        [ -f "$f" ] || continue
        local name
        name=$(head -1 "$f" | sed 's/^# //')
        local cmd
        cmd=$(basename "$f" .txt | sed 's/lesson[0-9]*_//')
        
        local status="  "
        if is_completed "$cmd" 2>/dev/null; then
            status="✅"
        elif is_unlocked "$cmd" 2>/dev/null; then
            status="🔓"
        else
            status="🔒"
        fi
        
        echo "  [$i] $status $name"
        i=$((i + 1))
    done
    
    echo ""
    echo "  [9] Back to main menu"
    echo "  [0] Exit"
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
    echo "========================================="
    echo "  🎉 Great job!"
    echo "  Progress: $completed of $total lessons completed"
    echo ""
    if [ -n "$next_name" ]; then
        echo "  📚 Next up: $next_name"
    else
        echo "  🏆 You've completed all lessons for this day!"
        echo "  Take the quiz to test your knowledge."
    fi
    echo "========================================="
    echo ""
}