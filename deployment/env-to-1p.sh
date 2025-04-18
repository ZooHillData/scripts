#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 --vault <vault_name> --item <item_id> [--env-file <path>]"
    echo "  --vault     : Name of the 1Password vault"
    echo "  --item      : ID of the item in the vault"
    echo "  --env-file  : Path to the .env file (default: .env)"
    exit 1
}

# Parse command line arguments
VAULT=""
ITEM=""
ENV_FILE=".env"

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
        echo "Item '$ITEM' exists. The following changes will be made:"
        
        # Get existing fields
        existing_fields=$(op item get "$ITEM" --vault "$VAULT" --format json | jq -r '.fields[] | select(.type == "CONCEALED") | .label')
        
        # Compare with new fields
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ $line =~ ^[^#].*=.* ]]; then
                key=$(echo "$line" | cut -d '=' -f 1)
                if echo "$existing_fields" | grep -q "^$key$"; then
                    echo "- $key (will be updated)"
                else
                    echo "- $key (will be added)"
                fi
            fi
        done < "$ENV_FILE"
        
        read -p "Proceed with update? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Update all fields
            while IFS= read -r line || [[ -n "$line" ]]; do
                if [[ $line =~ ^[^#].*=.* ]]; then
                    key=$(echo "$line" | cut -d '=' -f 1)
                    value=$(echo "$line" | cut -d '=' -f 2-)
                    op item edit "$ITEM" --vault "$VAULT" "$key[text]=$value"
                fi
            done < "$ENV_FILE"
        else
            echo "Operation cancelled"
            exit 1
        fi
    fi
}

# Main script execution
check_vault
check_and_confirm_changes

echo "Operation completed successfully"
