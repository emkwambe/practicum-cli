#!/bin/bash
# Practicum CLI — Quiz Engine (pure bash)

run_quiz() {
    local quiz_file="$1"
    
    if [ ! -f "$quiz_file" ]; then
        echo "Quiz file not found: $quiz_file"
        return 1
    fi
    
    local total=0
    local correct=0
    local question=""
    local options=""
    local answer=""
    local in_question=0
    
    echo ""
    echo "========================================="
    echo "  Practicum CLI — Quiz"
    echo "========================================="
    echo ""
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # New question
        if echo "$line" | grep -q "^Q[0-9]"; then
            if [ -n "$answer" ] && [ "$in_question" -eq 1 ]; then
                # Grade previous question
                echo ""
                printf "Your answer: "
                read -r user_answer < /dev/stdin || user_answer=""
                user_answer=$(echo "$user_answer" | tr '[:lower:]' '[:upper:]')
                total=$((total + 1))
                if [ "$user_answer" = "$answer" ]; then
                    echo "  ✅ Correct!"
                    correct=$((correct + 1))
                else
                    echo "  ❌ Wrong. Correct answer: $answer"
                fi
                answer=""
            fi
            in_question=1
            echo ""
            echo "$line"
            continue
        fi
        
        # Answer options (A-D lines)
        if echo "$line" | grep -q "^[A-D])"; then
            echo "   $line"
            continue
        fi
        
        # Correct answer line
        if echo "$line" | grep -q "^Correct:"; then
            answer=$(echo "$line" | sed 's/Correct: *//')
            continue
        fi
    done < "$quiz_file"
    
    # Grade last question
    if [ -n "$answer" ] && [ "$in_question" -eq 1 ]; then
        echo ""
        printf "Your answer: "
        read -r user_answer < /dev/stdin || user_answer=""
        user_answer=$(echo "$user_answer" | tr '[:lower:]' '[:upper:]')
        total=$((total + 1))
        if [ "$user_answer" = "$answer" ]; then
            echo "  ✅ Correct!"
            correct=$((correct + 1))
        else
            echo "  ❌ Wrong. Correct answer: $answer"
        fi
    fi
    
    # Score
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
    
    # Return pass/fail as exit code
    [ "$pct" -ge 70 ]
}