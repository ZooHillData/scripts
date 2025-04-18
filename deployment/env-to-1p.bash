#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 --vault <vault_name> --item <item_id> [--env-file <path>] [--remove]"
    echo "  --vault     : Name of the 1Password vault"
    echo "  --item      : ID of the item in the vault"
    echo "  --env-file  : Path to the .env file (default: .env)"
    echo "  --remove    : Automatically remove keys that are not in the env file"
    exit 1
}

# Parse command line arguments
VAULT=""
ITEM=""
ENV_FILE=".env"
AUTO_REMOVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --vault)
            VAULT="$2"
            shift 2
            ;;
        --item)
            ITEM="$2"
            shift 2
            ;;
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --remove)
            AUTO_REMOVE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$VAULT" ] || [ -z "$ITEM" ]; then
    echo "Error: Vault name and item ID are required"
    usage
fi

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

# Function to check if vault exists
check_vault() {
    if ! op vault get "$VAULT" &>/dev/null; then
        read -p "Vault '$VAULT' does not exist. Create it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            op vault create "$VAULT"
            return 0
        else
            echo "Operation cancelled"
            exit 1
        fi
    fi
    return 0
}

# Function to create a new item
create_new_item() {
    local first_key=""
    local first_value=""
    
    # Read first key-value pair to initialize the item
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $line =~ ^[^#].*=.* ]]; then
            first_key=$(echo "$line" | cut -d '=' -f 1)
            first_value=$(echo "$line" | cut -d '=' -f 2-)
            break
        fi
    done < "$ENV_FILE"
    
    # Create the initial item with the first key-value pair
    op item create --vault "$VAULT" --category "Secure Note" --title "$ITEM" "$first_key[text]=$first_value"
    
    # Add remaining key-value pairs
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $line =~ ^[^#].*=.* ]]; then
            key=$(echo "$line" | cut -d '=' -f 1)
            value=$(echo "$line" | cut -d '=' -f 2-)
            if [ "$key" != "$first_key" ]; then
                op item edit "$ITEM" --vault "$VAULT" "$key[text]=$value"
            fi
        fi
    done < "$ENV_FILE"
}

# Function to check if item exists and show changes
check_and_confirm_changes() {
    if ! op item get "$ITEM" --vault "$VAULT" &>/dev/null; then
        echo "Item '$ITEM' does not exist in vault '$VAULT'"
        echo "The following variables will be added:"
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ $line =~ ^[^#].*=.* ]]; then
                key=$(echo "$line" | cut -d '=' -f 1)
                echo "- $key"
            fi
        done < "$ENV_FILE"
        
        read -p "Create new item? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            create_new_item
        else
            echo "Operation cancelled"
            exit 1
        fi
    else
        echo "Item '$ITEM' exists. Analyzing changes..."
        
        # Create temporary files for storing key-value pairs
        tmp_existing=$(mktemp)
        tmp_new=$(mktemp)
        tmp_seen=$(mktemp)
        
        # Get existing fields and values, excluding built-in fields
        op item get "$ITEM" --vault "$VAULT" --format json --reveal | \
            jq -r '.fields[] | select(.label != "notesPlain" and .label != "") | "\(.label)=\(.value // "")"' > "$tmp_existing"
        
        # Debug output
        echo "Current values in 1Password:"
        cat "$tmp_existing"
        echo
        echo "New values from $ENV_FILE:"
        cat "$ENV_FILE"
        echo
        
        # Read new values into temp file, ensuring unique keys
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ $line =~ ^[^#].*=.* ]]; then
                key=$(echo "$line" | cut -d '=' -f 1)
                if ! grep -q "^$key$" "$tmp_seen" 2>/dev/null; then
                    echo "$line" >> "$tmp_new"
                    echo "$key" >> "$tmp_seen"
                fi
            fi
        done < "$ENV_FILE"
        
        # Track changes
        to_update=""
        to_add=""
        to_remove=""
        
        # Check for updates and additions
        while IFS='=' read -r key value; do
            if [ -n "$key" ]; then
                existing_line=$(grep "^$key=" "$tmp_existing" || true)
                if [ -n "$existing_line" ]; then
                    existing_value=$(echo "$existing_line" | cut -d'=' -f2-)
                    if [ "$existing_value" != "$value" ]; then
                        to_update="$to_update $key"
                    fi
                else
                    to_add="$to_add $key"
                fi
            fi
        done < "$tmp_new"
        
        # Check for removals
        while IFS='=' read -r key value; do
            if [ -n "$key" ]; then
                if ! grep -q "^$key=" "$tmp_new"; then
                    to_remove="$to_remove $key"
                fi
            fi
        done < "$tmp_existing"
        
        # Show changes
        if [ -z "$to_update" ] && [ -z "$to_add" ] && [ -z "$to_remove" ]; then
            echo "No changes detected."
            rm -f "$tmp_existing" "$tmp_new" "$tmp_seen"
            exit 0
        fi
        
        echo "The following changes will be made:"
        
        # Show updates
        for key in $to_update; do
            old_value=$(grep "^$key=" "$tmp_existing" | cut -d'=' -f2-)
            new_value=$(grep "^$key=" "$tmp_new" | cut -d'=' -f2-)
            echo "- $key (will be updated from '$old_value' to '$new_value')"
        done
        
        # Show additions
        for key in $to_add; do
            value=$(grep "^$key=" "$tmp_new" | cut -d'=' -f2-)
            echo "- $key (will be added with value '$value')"
        done
        
        # Show removals
        if [ -n "$to_remove" ]; then
            echo "The following keys will be removed:"
            for key in $to_remove; do
                value=$(grep "^$key=" "$tmp_existing" | cut -d'=' -f2-)
                echo "- $key (current value: '$value')"
            done
            
            if [ "$AUTO_REMOVE" = false ]; then
                read -p "Do you want to remove these keys? (y/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "Skipping key removal"
                    to_remove=""
                fi
            fi
        fi
        
        read -p "Proceed with these changes? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Apply removals first
            for key in $to_remove; do
                if [ -n "$key" ]; then
                    echo "Removing $key..."
                    op item edit "$ITEM" --vault "$VAULT" "$key[delete]" --reveal
                fi
            done
            
            # Then apply updates and additions
            if [ -n "$to_update" ] || [ -n "$to_add" ]; then
                # Create a temporary file for the field updates
                tmp_updates=$(mktemp)
                
                # Build the update command arguments
                for key in $to_update $to_add; do
                    if [ -n "$key" ]; then
                        value=$(grep "^$key=" "$tmp_new" | cut -d'=' -f2-)
                        echo "$key[text]=$value" >> "$tmp_updates"
                    fi
                done
                
                # Apply all updates in a single command
                if [ -s "$tmp_updates" ]; then
                    echo "Applying updates..."
                    op item edit "$ITEM" --vault "$VAULT" $(cat "$tmp_updates") --reveal
                fi
                
                rm -f "$tmp_updates"
            fi
        else
            echo "Operation cancelled"
            rm -f "$tmp_existing" "$tmp_new" "$tmp_seen"
            exit 1
        fi
        
        # Cleanup temp files
        rm -f "$tmp_existing" "$tmp_new" "$tmp_seen"
    fi
}

# Main script execution
check_vault
check_and_confirm_changes

echo "Operation completed successfully"
