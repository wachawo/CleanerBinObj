#!/usr/bin/env bash
set -euxo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
# BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to check if directory is protected
is_protected_directory() {
    local dir="$1"
    local abs_path
    abs_path=$(realpath "$dir" 2>/dev/null || echo "$dir")

    # List of protected directories and patterns
    local protected_patterns=(
        "/"
        "/var"
        "/usr"
        "/home"
        "/etc"
        "/bin"
        "/sbin"
        "/lib"
        "/lib64"
        "/opt"
        "/tmp"
        "/root"
        "/boot"
        "/dev"
        "/proc"
        "/sys"
        "/mnt"
        "/media"
        "/run"
        "/srv"
        "/var/log"
        "/var/cache"
        "/var/tmp"
        "/usr/local"
        "/usr/bin"
        "/usr/sbin"
        "/usr/lib"
        "/usr/share"
        "/usr/src"
        "/home/*"
        "/root/*"
    )

    for pattern in "${protected_patterns[@]}"; do
        if [[ "$abs_path" == "$pattern" || "$abs_path" == "$pattern"/* ]]; then
            return 0  # Protected
        fi
    done

    return 1  # Not protected
}

# Function to check if directory is a C# repository
is_csharp_repository() {
    local dir="$1"

    # Check for .sln files
    if find "$dir" -maxdepth 2 -name "*.sln" -type f | grep -q .; then
        return 0
    fi

    # Check for .csproj files
    if find "$dir" -maxdepth 2 -name "*.csproj" -type f | grep -q .; then
        return 0
    fi

    return 1
}

# Get the target directory (default to current directory)
TARGET_DIR="${1:-.}"

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: Directory '$TARGET_DIR' does not exist${NC}"
    exit 1
fi

# Get absolute path
TARGET_DIR=$(realpath "$TARGET_DIR")

# Check if directory is protected
if is_protected_directory "$TARGET_DIR"; then
    echo -e "${RED}Error: Cannot clean protected directory '$TARGET_DIR'${NC}"
    echo -e "${YELLOW}This directory is protected to prevent accidental deletion of system files.${NC}"
    exit 1
fi

# Check if directory is a C# repository
if ! is_csharp_repository "$TARGET_DIR"; then
    echo -e "${RED}Error: Directory '$TARGET_DIR' does not appear to be a C# repository${NC}"
    echo -e "${YELLOW}No .sln or .csproj files found in the directory or its immediate subdirectories.${NC}"
    echo -e "${YELLOW}Please ensure you're running this script in a C# project directory.${NC}"
    exit 1
fi

echo -e "${GREEN} Target directory is safe to clean${NC}"
echo -e "${GREEN} C# repository detected${NC}"

# Variables for statistics
TOTAL_SIZE=0
START_TIME=$(date +%s)

echo -e "Starting search and removal of ${CYAN}bin${NC} and ${CYAN}obj${NC} directories in: ${CYAN}$TARGET_DIR${NC}"

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
find "$TARGET_DIR" \( -path "*/node_modules/*" -o -path "*/.git/*" \) -prune -o \
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
