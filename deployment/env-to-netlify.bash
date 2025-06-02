#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 --env <env_file> --site-name <netlify_site_name> [--context <context>]"
    echo "  --env      : Path to the .env file to load"
    echo "  --site-name: Netlify site name to link to"
    echo "  --context  : Netlify context to set variables for (e.g., production, branch:staging)"
    exit 1
}

# Parse command line arguments
ENV_FILE=""
SITE_NAME=""
CONTEXT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV_FILE="$2"
            shift 2
            ;;
        --site-name)
            SITE_NAME="$2"
            shift 2
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
if [ -z "$ENV_FILE" ] || [ -z "$SITE_NAME" ]; then
    echo "Error: .env file and site name are required"
    usage
fi

# Check if env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: File '$ENV_FILE' does not exist"
    exit 1
fi

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
}

# Link to the site
check_site

# Read the env file and set each variable in Netlify
while IFS='=' read -r key value; do
    # Skip empty lines and comments
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    
    # Trim whitespace from key and value
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    
    # Skip if key is empty after trimming
    [ -z "$key" ] && continue
    
    echo "Setting $key in Netlify..."
    if [ -n "$CONTEXT" ]; then
        netlify env:set "$key" "$value" --context "$CONTEXT"
    else
        netlify env:set "$key" "$value"
    fi
done < "$ENV_FILE"

echo "Environment variables have been set in Netlify"
