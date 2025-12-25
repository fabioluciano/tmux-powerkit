#!/usr/bin/env bash
# =============================================================================
# Helper: log_viewer
# Description: Display PowerKit logs in a popup with tail -f
# Type: popup
# =============================================================================

# Source helper base (handles all initialization)
. "$(dirname "${BASH_SOURCE[0]}")/../contract/helper_contract.sh"
helper_init

# =============================================================================
# Metadata
# =============================================================================

helper_get_metadata() {
    helper_metadata_set "id" "log_viewer"
    helper_metadata_set "name" "Log Viewer"
    helper_metadata_set "description" "View PowerKit logs with follow mode"
    helper_metadata_set "type" "popup"
}

helper_get_actions() {
    echo "view - Interactive mode (default)"
    echo "follow - Follow log in real-time"
    echo "tail [N] - Show last N lines"
    echo "clear - Clear the log file"
}

# =============================================================================
# Configuration
# =============================================================================

LOG_FILE="$(get_log_file)"
# shellcheck disable=SC2034 # Reserved for future use
LOG_DIR="$(dirname "$LOG_FILE")"
LOG_FILE_OLD="${LOG_FILE}.old"

# Use ANSI colors from defaults.sh
BOLD="${POWERKIT_ANSI_BOLD}"
DIM="${POWERKIT_ANSI_DIM}"
RESET="${POWERKIT_ANSI_RESET}"
RED="${POWERKIT_ANSI_RED}"
GREEN="${POWERKIT_ANSI_GREEN}"
YELLOW="${POWERKIT_ANSI_YELLOW}"
# shellcheck disable=SC2034 # May be used in future features
BLUE="${POWERKIT_ANSI_BLUE}"
CYAN="${POWERKIT_ANSI_CYAN}"
MAGENTA="${POWERKIT_ANSI_MAGENTA}"

# =============================================================================
# Functions
# =============================================================================

print_header() {
    clear
    echo "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${RESET}"
    echo "${BOLD}${CYAN}║${RESET}              ${BOLD}PowerKit Log Viewer${RESET}                               ${BOLD}${CYAN}║${RESET}"
    echo "${BOLD}${CYAN}╠══════════════════════════════════════════════════════════════════╣${RESET}"
    echo "${BOLD}${CYAN}║${RESET} ${DIM}Log file:${RESET} ${LOG_FILE}  ${BOLD}${CYAN}║${RESET}"
    echo "${BOLD}${CYAN}║${RESET} ${DIM}Press${RESET} ${BOLD}q${RESET} ${DIM}to quit,${RESET} ${BOLD}c${RESET} ${DIM}to clear,${RESET} ${BOLD}r${RESET} ${DIM}to refresh,${RESET} ${BOLD}o${RESET} ${DIM}for old log${RESET}  ${BOLD}${CYAN}║${RESET}"
    echo "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

colorize_log() {
    # Colorize log levels
    sed -E \
        -e "s/\[DEBUG\]/${DIM}[DEBUG]${RESET}/g" \
        -e "s/\[INFO\]/${GREEN}[INFO]${RESET}/g" \
        -e "s/\[WARN\]/${YELLOW}[WARN]${RESET}/g" \
        -e "s/\[ERROR\]/${RED}[ERROR]${RESET}/g" \
        -e "s/^\[([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})\]/${DIM}[\1]${RESET}/g"
}

show_log() {
    local file="${1:-$LOG_FILE}"
    local lines="${2:-50}"
    
    if [[ ! -f "$file" ]]; then
        echo "${YELLOW}No log file found: ${file}${RESET}"
        echo ""
        echo "${DIM}Logs will appear here when PowerKit generates them.${RESET}"
        return
    fi
    
    local size
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    local human_size
    if (( size > 1048576 )); then
        human_size="$(( size / 1048576 ))MB"
    elif (( size > 1024 )); then
        human_size="$(( size / 1024 ))KB"
    else
        human_size="${size}B"
    fi
    
    echo "${DIM}File size: ${human_size} | Showing last ${lines} lines${RESET}"
    echo "${DIM}────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    
    tail -n "$lines" "$file" | colorize_log
}

show_log_follow() {
    local file="${1:-$LOG_FILE}"
    
    if [[ ! -f "$file" ]]; then
        echo "${YELLOW}No log file found: ${file}${RESET}"
        echo "${DIM}Waiting for logs...${RESET}"
        # Create file and wait
        mkdir -p "$(dirname "$file")"
        touch "$file"
    fi
    
    echo "${DIM}Following log file (Ctrl+C to stop)...${RESET}"
    echo "${DIM}────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    
    tail -f "$file" | colorize_log
}

clear_log() {
    if [[ -f "$LOG_FILE" ]]; then
        : > "$LOG_FILE"
        echo "${GREEN}✓ Log file cleared${RESET}"
    else
        echo "${YELLOW}No log file to clear${RESET}"
    fi
}

interactive_menu() {
    local current_file="$LOG_FILE"
    local viewing_old=false
    
    while true; do
        print_header
        
        if [[ "$viewing_old" == true ]]; then
            echo "${MAGENTA}[Viewing old log]${RESET}"
            current_file="$LOG_FILE_OLD"
        fi
        
        show_log "$current_file" 40
        
        echo ""
        echo "${DIM}────────────────────────────────────────────────────────────────────${RESET}"
        echo -n "${BOLD}Command [q/c/r/o/f]: ${RESET}"
        
        read -rsn1 key
        echo ""
        
        case "$key" in
            q|Q)
                echo "${DIM}Goodbye!${RESET}"
                exit 0
                ;;
            c|C)
                clear_log
                sleep 1
                ;;
            r|R)
                # Just refresh (loop continues)
                ;;
            o|O)
                if [[ "$viewing_old" == true ]]; then
                    viewing_old=false
                else
                    if [[ -f "$LOG_FILE_OLD" ]]; then
                        viewing_old=true
                    else
                        echo "${YELLOW}No old log file available${RESET}"
                        sleep 1
                    fi
                fi
                ;;
            f|F)
                print_header
                show_log_follow "$current_file"
                ;;
            *)
                # Unknown key, just refresh
                ;;
        esac
    done
}

# =============================================================================
# Main Entry Point
# =============================================================================

helper_main() {
    local action="${1:-view}"
    shift 2>/dev/null || true

    case "$action" in
        -f|--follow|follow)
            print_header
            show_log_follow
            ;;
        -t|--tail|tail)
            show_log "$LOG_FILE" "${1:-100}"
            ;;
        -c|--clear|clear)
            clear_log
            ;;
        view|"")
            interactive_menu
            ;;
        *)
            interactive_menu
            ;;
    esac
}

# Dispatch to handler
helper_dispatch "$@"
