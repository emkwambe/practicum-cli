#!/bin/bash
# Practicum CLI — Quiz Engine (pure bash)
# Reads quiz file into memory first, then asks questions via stdin

run_quiz() {
    local quiz_file="$1"
    
    if [ ! -f "$quiz_file" ]; then
        echo "Quiz file not found: $quiz_file"
        return 1
    fi
    
    local lines=()
    while IFS= read -r l || [ -n "$l" ]; do
        lines+=("$l")
    done < "$quiz_file"
    
    local total=0
    local correct=0
    local current_answer=""
    
    echo ""
    echo "========================================="
    echo "  Practicum CLI — Quiz"
    echo "========================================="
    
    local i=0
    while [ "$i" -lt "${#lines[@]}" ]; do
        local line="${lines[$i]}"
        i=$((i + 1))
        
        [ -z "$line" ] && continue
        
        if echo "$line" | grep -q "^Q[0-9]"; then
            echo ""
            echo "$line"
            continue
        fi
        
        if echo "$line" | grep -q "^[A-D])"; then
            echo "   $line"
            continue
        fi
        
        if echo "$line" | grep -q "^Correct:"; then
            current_answer=$(echo "$line" | sed 's/Correct: *//')
            echo ""
            printf "Your answer: "
            read -r user_answer || user_answer=""
            user_answer=$(echo "$user_answer" | tr '[:lower:]' '[:upper:]')
            total=$((total + 1))
            if [ "$user_answer" = "$current_answer" ]; then
                echo "  ✅ Correct!"
                correct=$((correct + 1))
            else
                echo "  ❌ Wrong. Correct answer: $current_answer"
            fi
            current_answer=""
            continue
        fi
    done
    
    local pct=0
    if [ "$total" -gt 0 ]; then
        pct=$(( (correct * 100) / total ))
    fi
    
    echo ""
    echo "========================================="
    echo "  Score: $correct / $total ($pct%)"
    if [ "$pct" -ge 70 ]; then
        echo "  ✅ PASSED! (70% required)"
    else
        echo "  ❌ FAILED. Need 70% to pass."
    fi
    echo "========================================="
    echo ""
    
    [ "$pct" -ge 70 ]
}