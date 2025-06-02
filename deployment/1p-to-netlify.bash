#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 --vault <vault_name> --item <item_id> --site-name <netlify_site_name> [--to <netlify|1p>] [--remove] [--context <context>]"
    echo "  --vault     : Name of the 1Password vault"
    echo "  --item      : ID of the item in the vault"
    echo "  --site-name : Netlify site name to link to"
    echo "  --to        : Target system to sync to (netlify or 1p, default: netlify)"
    echo "  --remove    : Automatically remove keys that don't exist in the source"
    echo "  --context   : Netlify context to set variables for (e.g., production, branch:staging)"
    exit 1
}

# Parse command line arguments
VAULT=""
ITEM=""
SITE_NAME=""
TARGET="netlify"
AUTO_REMOVE=false
CONTEXT=""

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
        --site-name)
            SITE_NAME="$2"
            shift 2
            ;;
        --to)
            TARGET="$2"
            shift 2
            ;;
        --remove)
            AUTO_REMOVE=true
            shift
            ;;
        --context)
            CONTEXT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$VAULT" ] || [ -z "$ITEM" ] || [ -z "$SITE_NAME" ]; then
    echo "Error: Vault name, item ID, and site name are required"
    usage
fi

# Validate target
if [ "$TARGET" != "netlify" ] && [ "$TARGET" != "1p" ]; then
    echo "Error: Invalid target. Must be either 'netlify' or '1p'"
    usage
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

# Function to check if Netlify site exists and link to it
check_site() {
    # Check if there's a currently linked site
    local previous_site=""
    local previous_site_id=""
    local was_linked=false
    
    # Get current site info if linked
    if netlify status | grep -q "Current site:"; then
        was_linked=true
        previous_site=$(netlify status | grep "Current site:" | cut -d':' -f2- | xargs)
        previous_site_id=$(netlify status | grep "Site Id:" | cut -d':' -f2- | xargs)
        echo "Currently linked to site: $previous_site"
        netlify unlink &>/dev/null
    fi

    # Try to link to the target site
    if ! netlify link --name "$SITE_NAME" &>/dev/null; then
        echo "Error: Could not link to Netlify site '$SITE_NAME'. Please check the site name and your Netlify authentication."
        # If there was a previous site, try to restore it
        if [ "$was_linked" = true ]; then
            echo "Restoring previous site link..."
            netlify link --id "$previous_site_id" &>/dev/null
        fi
        exit 1
    fi

    # Run the rest of the script with the target site linked
    echo "Successfully linked to site: $SITE_NAME"

    # Add a trap to restore the previous site link on script exit
    if [ "$was_linked" = true ]; then
        trap 'echo "Restoring previous site link..."; netlify unlink &>/dev/null && netlify link --id "$previous_site_id" &>/dev/null' EXIT
    else
        trap 'echo "Unlinking from site..."; netlify unlink &>/dev/null' EXIT
    fi

    return 0
}

# Function to get environment variables from 1Password
get_1p_env() {
    op item get "$ITEM" --vault "$VAULT" --format json --reveal | \
        jq -r '.fields[] | select(.label != "notesPlain" and .label != "") | "\(.label)=\(.value // "")"'
}

# Function to get environment variables from Netlify
get_netlify_env() {
    if [ -n "$CONTEXT" ]; then
        netlify env:list --plain --context "$CONTEXT"
    else
        netlify env:list --plain
    fi
}

# Function to analyze and apply changes
analyze_and_apply_changes() {
    local source_output="$1"
    local target_output="$2"
    local source_type="$3"
    local target_type="$4"
    
    # Track changes
    local to_update=""
    local to_add=""
    local to_remove=""
    
    # Check for updates and additions
    while IFS='=' read -r key value; do
        if [ -n "$key" ]; then
            if echo "$target_output" | grep -q "^$key="; then
                target_value=$(echo "$target_output" | grep "^$key=" | cut -d'=' -f2-)
                if [ "$target_value" != "$value" ]; then
                    to_update="$to_update $key"
                fi
            else
                to_add="$to_add $key"
            fi
        fi
    done < <(echo "$source_output")
    
    # Check for removals
    while IFS='=' read -r key value; do
        if [ -n "$key" ]; then
            if ! echo "$source_output" | grep -q "^$key="; then
                to_remove="$to_remove $key"
            fi
        fi
    done < <(echo "$target_output")
    
    # Show changes
    if [ -z "$to_update" ] && [ -z "$to_add" ] && [ -z "$to_remove" ]; then
        echo "No changes detected."
        exit 0
    fi
    
    echo "The following changes will be made:"
    
    # Show updates
    for key in $to_update; do
        old_value=$(echo "$target_output" | grep "^$key=" | cut -d'=' -f2-)
        new_value=$(echo "$source_output" | grep "^$key=" | cut -d'=' -f2-)
        echo "- $key (will be updated from '$old_value' to '$new_value')"
    done
    
    # Show additions
    for key in $to_add; do
        value=$(echo "$source_output" | grep "^$key=" | cut -d'=' -f2-)
        echo "- $key (will be added with value '$value')"
    done
    
    # Show removals
    if [ -n "$to_remove" ]; then
        echo "The following keys will be removed:"
        for key in $to_remove; do
            value=$(echo "$target_output" | grep "^$key=" | cut -d'=' -f2-)
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
        # Apply changes based on target type
        if [ "$target_type" = "1p" ]; then
            # Apply removals first for 1Password
            for key in $to_remove; do
                if [ -n "$key" ]; then
                    echo "Removing $key from 1Password..."
                    op item edit "$ITEM" --vault "$VAULT" "$key[delete]" --reveal
                fi
            done
            
            # Then apply updates and additions
            if [ -n "$to_update" ] || [ -n "$to_add" ]; then
                local updates=""
                for key in $to_update $to_add; do
                    if [ -n "$key" ]; then
                        value=$(echo "$source_output" | grep "^$key=" | cut -d'=' -f2-)
                        updates="$updates $key[text]=$value"
                    fi
                done
                
                if [ -n "$updates" ]; then
                    echo "Applying updates to 1Password..."
                    op item edit "$ITEM" --vault "$VAULT" $updates --reveal
                fi
            fi
        else
            # Apply changes to Netlify
            # Remove keys first
            for key in $to_remove; do
                if [ -n "$key" ]; then
                    echo "Removing $key from Netlify..."
                    if [ -n "$CONTEXT" ]; then
                        netlify env:unset "$key" --context "$CONTEXT"
                    else
                        netlify env:unset "$key"
                    fi
                fi
            done
            
            # Apply updates and additions
            for key in $to_update $to_add; do
                if [ -n "$key" ]; then
                    value=$(echo "$source_output" | grep "^$key=" | cut -d'=' -f2-)
                    echo "Setting $key in Netlify..."
                    if [ -n "$CONTEXT" ]; then
                        netlify env:set "$key" "$value" --context "$CONTEXT"
                    else
                        netlify env:set "$key" "$value"
                    fi
                fi
            done
        fi
    else
        echo "Operation cancelled"
        exit 1
    fi
}

# Main script execution
check_vault
check_site

# Get environment variables from both sources
if [ "$TARGET" = "netlify" ]; then
    source_output=$(get_1p_env)
    target_output=$(get_netlify_env)
    analyze_and_apply_changes "$source_output" "$target_output" "1p" "netlify"
else
    source_output=$(get_netlify_env)
    target_output=$(get_1p_env)
    analyze_and_apply_changes "$source_output" "$target_output" "netlify" "1p"
fi

echo "Operation completed successfully" 