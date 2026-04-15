#!/bin/bash
# Practicum CLI — Mode Switching

enter_mode() {
    local mode="$1"
    set_mode "$mode"
    
    case "$mode" in
        WIZARD)
            export PRACTICUM_MODE="WIZARD"
            echo ""
            echo "========================================="
            echo "  🧙 WIZARD MODE"
            echo "  Every command is explained before running."
            echo "  Intent → Context → Action → Result"
            echo "========================================="
            echo ""
            ;;
        LAB)
            export PRACTICUM_MODE="LAB"
            echo ""
            echo "========================================="
            echo "  🔬 LAB MODE"
            echo "  All commands affect sandbox only."
            echo "  Sandbox: ~/.practicum/sandbox/"
            echo "  Use 'practicum snapshot save <name>' to save state."
            echo "========================================="
            echo ""
            ;;
        FIELD)
            export PRACTICUM_MODE="FIELD"
            echo ""
            echo "========================================="
            echo "  🌍 FIELD MODE"
            echo "  Real system. No sandbox. Be careful."
            echo "  Guardrails: warnings only, no blocks."
            echo "========================================="
            echo ""
            ;;
        LMS)
            export PRACTICUM_MODE="LMS"
            echo ""
            echo "========================================="
            echo "  📚 LMS MODE"
            echo "  View progress, take quizzes, earn badges."
            echo "========================================="
            echo ""
            ;;
    esac
}