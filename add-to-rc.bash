#!/bin/bash

# Default rc file
RC_FILE="${1:-$HOME/.zshrc}"

# Check if rc file exists
if [ ! -f "$RC_FILE" ]; then
    echo "Error: RC file $RC_FILE does not exist"
    exit 1
fi

# Find all shell scripts in the repository (top level and one level deep)
SCRIPTS=$(find . -maxdepth 2 -type f -name "*.bash" | grep -v "add-to-rc.bash" | sort)

# Check if our section header already exists
if ! grep -q "# === BEGIN: Script Management System Aliases ===" "$RC_FILE"; then
    echo -e "\n# === BEGIN: Script Management System Aliases ===" >> "$RC_FILE"
    echo "# These aliases are automatically managed by $PWD/add-to-rc.bash" >> "$RC_FILE"
    echo "# Do not modify this section manually" >> "$RC_FILE"
fi

# Add each script to the rc file
for script in $SCRIPTS; do
    # Get the script name without extension and path
    script_name=$(basename "$script" .bash)
    # Get the relative path from repository root
    rel_path=$(dirname "$script" | sed 's|^./||')
    
    # Create alias command (removing ./ from the beginning of the path)
    script_path="$PWD/${script#./}"
    alias_cmd="alias $script_name=\"$script_path\""
    
    # Check if alias already exists
    if grep -q "alias $script_name=" "$RC_FILE"; then
        echo "Alias for $script_name already exists in $RC_FILE"
    else
        echo "Adding alias for $script_name to $RC_FILE"
        echo "$alias_cmd" >> "$RC_FILE"
    fi
done

# Add closing comment if it doesn't exist
if ! grep -q "# === END: Script Management System Aliases ===" "$RC_FILE"; then
    echo -e "\n# === END: Script Management System Aliases ===\n" >> "$RC_FILE"
fi

echo "Done! Please source $RC_FILE or restart your shell to use the new aliases."
