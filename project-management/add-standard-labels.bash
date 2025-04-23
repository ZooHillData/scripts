#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Default values
DRY_RUN=true
ORG="ZooHillData"  # Default organization
REPO=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --execute)
            DRY_RUN=false
            shift
            ;;
        --repo)
            REPO="$2"
            shift 2
            ;;
        --org)
            ORG="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 --repo REPO [--org ORG] [--execute]"
            echo ""
            echo "Options:"
            echo "  --repo REPO    Repository name (required)"
            echo "  --org ORG      Organization name (default: ZooHillData)"
            echo "  --execute      Actually create the labels (default: dry-run)"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$REPO" ]]; then
    echo "Error: --repo is required"
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated with gh
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI"
    echo "Please run 'gh auth login' first"
    exit 1
fi

# Verify repository access
echo "Verifying repository access..."
if ! gh repo view "$ORG/$REPO" --json name >/dev/null 2>&1; then
    echo "Error: Cannot access repository $ORG/$REPO"
    echo "Please check:"
    echo "  1. The repository exists"
    echo "  2. You have the correct permissions"
    echo "  3. The organization name is correct"
    exit 1
fi

# Path to the labels JSON file
LABELS_FILE="$SCRIPT_DIR/standard-repo-config.json"

# Check if the labels file exists
if [ ! -f "$LABELS_FILE" ]; then
    echo "Error: Labels file not found at $LABELS_FILE"
    exit 1
fi

echo "Reading standard labels configuration..."

# Read and process the labels
jq -c '.labels[]' "$LABELS_FILE" | while read -r label; do
    name=$(echo "$label" | jq -r '.name')
    description=$(echo "$label" | jq -r '.description')
    color=$(echo "$label" | jq -r '.color')

    if [ "$DRY_RUN" = true ]; then
        echo "Would create label: $name"
        echo "  Description: $description"
        echo "  Color: $color"
        echo "---"
    else
        echo "Creating label: $name"
        if gh label create "$name" --repo "$ORG/$REPO" --description "$description" --color "$color"; then
            echo "✓ Created label: $name"
        else
            # If label already exists, update it
            if gh label edit "$name" --repo "$ORG/$REPO" --description "$description" --color "$color"; then
                echo "✓ Updated existing label: $name"
            else
                echo "✗ Failed to create/update label: $name"
            fi
        fi
    fi
done

if [ "$DRY_RUN" = true ]; then
    echo "Dry run complete. Use --execute to actually create the labels."
else
    echo "Label creation complete!"
fi
