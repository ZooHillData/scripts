#!/bin/bash

# Default rc file
RC_FILE="${1:-$HOME/.zshrc}"

# Check if rc file exists
if [ ! -f "$RC_FILE" ]; then
    echo "Error: RC file $RC_FILE does not exist"
    exit 1
fi

# Create a temporary file
TEMP_FILE=$(mktemp)

# Find all shell scripts in the repository (top level and one level deep)
SCRIPTS=$(find . -maxdepth 2 -type f -name "*.bash" | grep -v "add-to-rc.bash" | sort)

# Arrays to store new and existing aliases
declare -a new_aliases
declare -a existing_aliases

# Process the RC file
in_section=false
section_found=false
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "# === BEGIN: Script Management System Aliases ===" ]]; then
        in_section=true
        section_found=true
        echo "$line" >> "$TEMP_FILE"
        echo "# These aliases are automatically managed by $PWD/add-to-rc.bash" >> "$TEMP_FILE"
        echo "# Do not modify this section manually" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        
        # Add all scripts here
        for script in $SCRIPTS; do
            script_name=$(basename "$script" .bash)
            script_path="$PWD/${script#./}"
            alias_cmd="alias $script_name=\"$script_path\""
            echo "$alias_cmd" >> "$TEMP_FILE"
            
            # Check if alias already existed
            if grep -q "alias $script_name=" "$RC_FILE"; then
                existing_aliases+=("$script_name")
            else
                new_aliases+=("$script_name")
            fi
        done
        echo "" >> "$TEMP_FILE"
        
    elif [[ "$line" == "# === END: Script Management System Aliases ===" ]]; then
        in_section=false
        echo "$line" >> "$TEMP_FILE"
    elif [[ "$in_section" == "false" ]]; then
        echo "$line" >> "$TEMP_FILE"
    fi
done < "$RC_FILE"

# If no section was found, add it at the end
if [[ "$section_found" == "false" ]]; then
    echo -e "\n# === BEGIN: Script Management System Aliases ===" >> "$TEMP_FILE"
    echo "# These aliases are automatically managed by $PWD/add-to-rc.bash" >> "$TEMP_FILE"
    echo "# Do not modify this section manually" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    
    # Add all scripts
    for script in $SCRIPTS; do
        script_name=$(basename "$script" .bash)
        script_path="$PWD/${script#./}"
        alias_cmd="alias $script_name=\"$script_path\""
        echo "$alias_cmd" >> "$TEMP_FILE"
        new_aliases+=("$script_name")
    done
    
    echo -e "\n# === END: Script Management System Aliases ===\n" >> "$TEMP_FILE"
fi

# Replace the original file with our temporary file
mv "$TEMP_FILE" "$RC_FILE"

# Print summary with colors
BOLD=$(tput bold)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

# Print new aliases if any exist
if [ ${#new_aliases[@]} -gt 0 ]; then
    echo "${BOLD}${GREEN}New aliases added:${RESET}"
    printf "  %s\n" "${new_aliases[@]}"
    echo
fi

# Print existing aliases if any exist
if [ ${#existing_aliases[@]} -gt 0 ]; then
    echo "${BOLD}${YELLOW}Existing aliases:${RESET}"
    printf "  %s\n" "${existing_aliases[@]}"
    echo
fi

echo "Done! Please source $RC_FILE or restart your shell to use the new aliases."
