#!/usr/bin/env bash
# =============================================================================
# PowerKit Keybinding Conflict Toast
# Displays a formatted popup showing keybinding conflicts
# =============================================================================

set -eu

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit"
LOG_FILE="${CACHE_DIR}/keybinding_conflicts.log"

# Check if log file exists
if [[ ! -f "$LOG_FILE" ]]; then
    echo "No keybinding conflicts detected."
    read -r -n 1 -s
    exit 0
fi

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

# Clear screen
clear

# Header
echo ""
echo -e "  ${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "  ${RED}║${NC}  ${YELLOW}⚠️  PowerKit: Keybinding Conflicts Detected!${NC}                 ${RED}║${NC}"
echo -e "  ${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Count conflicts
conflict_count=$(grep -c "•" "$LOG_FILE" 2>/dev/null || echo "0")
echo -e "  ${WHITE}Found ${YELLOW}${conflict_count}${WHITE} conflict(s):${NC}"
echo ""

# Read and display conflicts from log file
while IFS= read -r line; do
    if [[ "$line" == *"•"* ]]; then
        # Color the conflict type
        if [[ "$line" == *"PowerKit internal"* ]]; then
            echo -e "  ${YELLOW}$line${NC}"
        elif [[ "$line" == *"Tmux conflict"* ]]; then
            echo -e "  ${RED}$line${NC}"
        else
            echo -e "  $line"
        fi
    fi
done < "$LOG_FILE"

echo ""
echo -e "  ${DIM}────────────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "  ${CYAN}💡 How to fix:${NC}"
echo -e "     Add to your ${WHITE}tmux.conf${NC}:"
echo -e "     ${DIM}set -g @powerkit_plugin_<plugin>_<option>_key \"<new_key>\"${NC}"
echo ""
echo -e "  ${DIM}📄 Log file: $LOG_FILE${NC}"
echo ""
echo -e "  ${DIM}Press any key to close...${NC}"

# Wait for keypress
read -r -n 1 -s
