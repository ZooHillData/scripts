#!/bin/bash

# Default values
PATTERN=""
DRY_RUN=true
ORG="ZooHillData"  # Default organization
REPO=""
DELETE_ALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pattern)
            PATTERN="$2"
            shift 2
            ;;
        --all)
            DELETE_ALL=true
            shift
            ;;
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
            echo "Usage: $0 --repo REPO (--pattern <regex_pattern> | --all) [--org ORG] [--execute]"
            echo "Example: $0 --repo my-repo --pattern '^(bug|feature|enhancement)$'"
            echo ""
            echo "Options:"
            echo "  --repo REPO       Repository name (required)"
            echo "  --pattern <regex> Regular expression pattern for labels to keep"
            echo "  --all            Delete all labels"
            echo "  --org ORG         Organization name (default: ZooHillData)"
            echo "  --execute         Actually perform the deletions (default: dry-run)"
            echo ""
            echo "Note: Organization name is case-sensitive for label operations"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$PATTERN" ] && [ "$DELETE_ALL" = false ]; then
    echo "Error: either --pattern or --all argument must be supplied"
    exit 1
fi

if [ -n "$PATTERN" ] && [ "$DELETE_ALL" = true ]; then
    echo "Error: cannot use both --pattern and --all together"
    exit 1
fi

if [ -z "$REPO" ]; then
    echo "Error: --repo argument is required"
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
    echo "  3. The organization name is correct (case-sensitive)"
    exit 1
fi

echo "Fetching labels..."

# Get all labels and process them
gh label list --repo "$ORG/$REPO" --json name | jq -r '.[] | .name' | while read -r label; do
    if [ "$DELETE_ALL" = true ] || ! echo "$label" | grep -qE "$PATTERN"; then
        if [ "$DRY_RUN" = true ]; then
            echo "Would delete label: $label"
        else
            echo "Deleting label: $label"
            gh label delete "$label" --repo "$ORG/$REPO" --yes || echo "Failed to delete label: $label"
        fi
    else
        echo "Keeping label: $label (matches pattern)"
    fi
done

if [ "$DRY_RUN" = true ]; then
    echo "Dry run complete. Use --execute to actually delete the labels."
else
    echo "Label cleanup complete!"
fi
