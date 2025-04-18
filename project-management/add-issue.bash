#!/bin/bash

# Default values
ORG="zoohilldata"
DESCRIPTION=""
INTERACTIVE_DESCRIPTION=false
ACTIVE=false

# Add-code related defaults
CLIENT=""
CONTRACT=""
PROJECT="-"
PROJECT_ITEM="-"
AUTHORIZED_HOURS=""

# Function to print usage
print_usage() {
    echo "Usage: add-issue --repo REPO [--org ORG] --title TITLE [--description] [--active] [add-code options]"
    echo
    echo "Arguments:"
    echo "  --repo         Repository name"
    echo "  --org          Organization name (default: zoohilldata)"
    echo "  --title        Issue title"
    echo "  --description  Enter description interactively (optional)"
    echo "  --active       Add issue to Active project (optional)"
    echo
    echo "Optional charge code creation:"
    echo "  --client TEXT    Client name (if provided, will create a charge code)"
    echo "  --contract TEXT  Contract identifier (required if --client is provided)"
    echo "  --project TEXT   Project name (default: '-')"
    echo "  --project-item TEXT  Project item (default: '-')"
    echo "  --authorized NUMBER   Authorized hours for the charge code"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO="$2"
            shift 2
            ;;
        --org)
            ORG="$2"
            shift 2
            ;;
        --title)
            TITLE="$2"
            shift 2
            ;;
        --description)
            INTERACTIVE_DESCRIPTION=true
            shift 1
            ;;
        --active)
            ACTIVE=true
            shift 1
            ;;
        # Add-code related arguments
        --client)
            CLIENT="$2"
            shift 2
            ;;
        --contract)
            CONTRACT="$2"
            shift 2
            ;;
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --project-item)
            PROJECT_ITEM="$2"
            shift 2
            ;;
        --authorized)
            AUTHORIZED_HOURS="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown argument $1"
            print_usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$REPO" ]]; then
    echo "Error: --repo is required"
    print_usage
fi

if [[ -z "$TITLE" ]]; then
    echo "Error: --title is required"
    print_usage
fi

# Validate add-code arguments if client is provided
if [[ -n "$CLIENT" ]]; then
    if [[ -z "$CONTRACT" ]]; then
        echo "Error: When --client is provided, --contract is also required"
        print_usage
    fi
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed. Please install it first."
    echo "Visit: https://cli.github.com/ for installation instructions"
    exit 1
fi

# Check if user is authenticated with gh
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI. Please run 'gh auth login' first."
    exit 1
fi

# Handle interactive description input
if [[ "$INTERACTIVE_DESCRIPTION" = true ]]; then
    echo "Enter description (Press Ctrl+D when done):"
    echo "----------------------------------------"
    
    # Read all input until Ctrl+D (EOF)
    DESCRIPTION=$(cat)
    
    echo "----------------------------------------"
    echo "Description captured. Creating issue..."
fi

# Create the issue
if [[ -n "$DESCRIPTION" ]]; then
    ISSUE_URL=$(gh issue create --repo "$ORG/$REPO" --title "$TITLE" --body "$DESCRIPTION")
else
    ISSUE_URL=$(gh issue create --repo "$ORG/$REPO" --title "$TITLE" --body "")
fi

# Extract issue number from URL
ISSUE_NUM=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')

# Check if issue creation was successful
if [[ -n "$ISSUE_NUM" ]]; then
    echo "✓ Issue created successfully"
    
    # Add to Active project if specified
    
    if [[ "$ACTIVE" = true ]]; then
        echo "Adding issue to Active project..."
        if gh issue edit "$ISSUE_NUM" --repo "$ORG/$REPO" --add-project "Active"; then
            echo "✓ Added to Active project"
        else
            echo "Error: Failed to add issue to Active project"
        fi
    fi
    
    # If client is provided, create charge code
    if [[ -n "$CLIENT" ]]; then
        echo
        echo "Creating charge code..."
        CMD="./vista/add-code.bash --client '$CLIENT' --contract '$CONTRACT'"
        
        # Add optional arguments if they were provided
        if [[ "$PROJECT" != "-" ]]; then
            CMD="$CMD --project '$PROJECT'"
        fi
        if [[ "$PROJECT_ITEM" != "-" ]]; then
            CMD="$CMD --project-item '$PROJECT_ITEM'"
        fi
        if [[ -n "$AUTHORIZED_HOURS" ]]; then
            CMD="$CMD --authorized '$AUTHORIZED_HOURS'"
        fi
        
        echo "Executing: $CMD"
        eval "$CMD"
        
        if [[ $? -eq 0 ]]; then
            echo "✓ Charge code created successfully"
        else
            echo "Error: Failed to create charge code"
            exit 1
        fi
    fi
else
    echo "Error: Failed to create issue"
    exit 1
fi
