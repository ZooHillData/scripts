#!/bin/bash

# Default values
INCLUDE_UNINSTALLED=false
INCLUDE_PATHS=true
RC_FILE="$HOME/.zshrc"

# Color codes
BLUE_BOLD='\033[1;34m'  # Bold Blue
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --include-uninstalled)
            INCLUDE_UNINSTALLED=true
            shift
            ;;
        --include-paths)
            INCLUDE_PATHS=true
            shift
            ;;
        --no-paths)
            INCLUDE_PATHS=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Find all shell scripts in the repository (excluding add-to-rc.bash)
SCRIPTS=$(find . -maxdepth 2 -type f -name "*.bash" | grep -v "add-to-rc.bash" | sort)

# Process scripts by directory
current_dir=""
while IFS= read -r script; do
    dir=$(dirname "$script" | sed 's|^./||')
    if [ "$dir" = "." ]; then
        dir="root"
    fi
    
    # Print directory header if we're in a new directory
    if [ "$dir" != "$current_dir" ]; then
        [ -n "$current_dir" ] && echo
        echo -e "${BLUE_BOLD}=== $dir ===${NC}"
        current_dir="$dir"
    fi
    
    # Get script name without extension
    script_name=$(basename "$script" .bash)
    
    # Check if script is installed
    if grep -q "alias $script_name=" "$RC_FILE"; then
        status="[installed]"
    else
        status="[uninstalled]"
        if [ "$INCLUDE_UNINSTALLED" = false ]; then
            continue
        fi
    fi
    
    # Print script info
    if [ "$INCLUDE_PATHS" = true ]; then
        echo "  $script_name $status ($script)"
    else
        echo "  $script_name $status"
    fi
done <<< "$SCRIPTS" 