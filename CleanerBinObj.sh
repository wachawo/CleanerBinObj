#!/usr/bin/env bash
set -euxo pipefail

# Colors for output
RED='\033[0;31m'
# BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables for statistics
TOTAL_SIZE=0
START_TIME=$(date +%s)

echo -e "Starting search and removal of ${CYAN}bin${NC} and ${CYAN}obj${NC} directories..."

# Function to format size
format_size() {
    local size=$1
    if [ "$size" -ge 1073741824 ]; then
        awk -v s="$size" 'BEGIN{printf "%.2f GB\n", s/1073741824}'
    elif [ "$size" -ge 1048576 ]; then
        awk -v s="$size" 'BEGIN{printf "%.2f MB\n", s/1048576}'
    elif [ "$size" -ge 1024 ]; then
        awk -v s="$size" 'BEGIN{printf "%.2f KB\n", s/1024}'
    else
        echo "$size B"
    fi
}

# Search and remove directories
find . \( -path "*/node_modules/*" -o -path "*/.git/*" \) -prune -o \
       -type d \( -name "bin" -o -name "obj" \) -print0 |
while IFS= read -r -d '' dir; do
    if [ -d "$dir" ]; then
        # Clean up path from extra spaces
        dir=$(echo "$dir" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip empty paths
        [ -z "$dir" ] && continue

        # Get directory size in kilobytes
        size_kb=$(du -sk -- "$dir" 2>/dev/null | awk '{print $1}')
        
        # Verify we got a number
        if [[ "$size_kb" =~ ^[0-9]+$ ]]; then
            # Update total (in bytes)
            TOTAL_SIZE=$(( TOTAL_SIZE + size_kb * 1024 ))
            # Format size for display
            size_display="${size_kb}K"
        else
            size_display="0B"
        fi

        # Display removal info
        dir_name=$(basename -- "$dir")
        dir_path=$(dirname -- "$dir")
        [[ "$dir_path" == "." ]] && full_path="" || full_path="${dir_path#./}/"
        echo -e "${RED}Removing:${NC} ${full_path:+$full_path/}${CYAN}${dir_name}${NC} ${YELLOW}(${size_display})${NC}"
        
        # Remove directory
        rm -rf -- "$dir" 2>/dev/null
    fi
done

# Calculate execution time
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))

# Display report
echo -e "\n${CYAN}=== REPORT ===${NC}"
echo -e "Total space freed: ${YELLOW}$(format_size "$TOTAL_SIZE")${NC}"
echo -e "Total execution time: ${YELLOW}${ELAPSED_TIME} seconds${NC}"
echo -e "Cleanup completed!${NC}"
