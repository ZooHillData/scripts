#!/usr/bin/env bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Default values
TITLE_PATTERN=""
ORG="zoohilldata"
REPO=""

# Check if expect is installed
if ! command -v expect &> /dev/null; then
    echo "Error: expect is not installed"
    exit 1
fi

# Function to normalize GitHub URL
normalize_github_url() {
    local url="$1"
    # Convert organization name to lowercase
    url=$(echo "$url" | sed 's|/[A-Z][^/]*/|/'"$(echo "$ORG" | tr '[:upper:]' '[:lower:]')"'/|')
    echo "$url"
}

# Function to show usage
show_usage() {
    echo "Usage: close-issue --repo REPO [--org ORG] --title PATTERN"
    echo ""
    echo "Closes GitHub issues matching the title pattern and associated charge codes"
    echo ""
    echo "Required Options:"
    echo "  --repo REPO       Repository name"
    echo "  --title PATTERN   Regex pattern to match issue titles"
    echo ""
    echo "Optional Options:"
    echo "  --org ORG        Organization name (default: zoohilldata)"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Example:"
    echo "  close-issue --repo my-repo --title '^Bug: Fix login$'    # Close specific issue"
    echo ""
    echo "Note: The title pattern must match exactly one issue. If multiple issues match,"
    echo "      the script will fail and display the matching issues."
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --title)
            TITLE_PATTERN="$2"
            shift 2
            ;;
        --repo)
            REPO="$2"
            shift 2
            ;;
        --org)
            ORG="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$TITLE_PATTERN" ]; then
    echo "Error: --title is required"
    echo "Use --help for usage information"
    exit 1
fi

if [ -z "$REPO" ]; then
    echo "Error: --repo is required"
    echo "Use --help for usage information"
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    exit 1
fi

# Check if user is authenticated with gh
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI. Please run 'gh auth login' first."
    exit 1
fi

# Check if psql is installed
if ! command -v psql &> /dev/null; then
    echo "Error: PostgreSQL client (psql) is not installed"
    exit 1
fi

# Check if 1Password CLI is installed
if ! command -v op &> /dev/null; then
    echo "Error: 1Password CLI is not installed"
    exit 1
fi

# Get list of open issues matching the pattern
echo "Finding issues matching pattern: '${TITLE_PATTERN}' in ${ORG}/${REPO}"
MATCHING_ISSUES=$(gh issue list --repo "${ORG}/${REPO}" --json number,title,url --jq ".[] | select(.title | test(\"${TITLE_PATTERN}\")) | [.number, .title, .url] | @tsv")

if [ -z "$MATCHING_ISSUES" ]; then
    echo "No issues found matching pattern '${TITLE_PATTERN}'"
    exit 1
fi

# Count matching issues
ISSUE_COUNT=$(echo "$MATCHING_ISSUES" | wc -l | tr -d '[:space:]')

if [ "$ISSUE_COUNT" -gt 1 ]; then
    echo "Error: Multiple issues match the pattern '${TITLE_PATTERN}'"
    echo "Please provide a more specific pattern. Matching issues:"
    echo "$MATCHING_ISSUES" | while IFS=$'\t' read -r number title url; do
        echo "  #$number: $title"
        echo "      $url"
    done
    exit 1
fi

echo "Found matching issue:"
echo "$MATCHING_ISSUES" | while IFS=$'\t' read -r number title url; do
    echo "  #$number: $title"
done

read -p "Would you like to proceed with closing this issue and its associated charge codes? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled"
    exit 0
fi

# Close the issue and associated charge codes
while IFS=$'\t' read -r number title url; do
    echo "Processing issue #$number: $title"
    
    # Close the GitHub issue
    if ! gh issue close "$number" --repo "${ORG}/${REPO}"; then
        echo "Error: Failed to close issue #$number"
        exit 1
    fi
    
    # Construct the expected GitHub URL format
    ORG_LOWER=$(echo "$ORG" | tr '[:upper:]' '[:lower:]')
    EXPECTED_URL="https://github.com/${ORG_LOWER}/${REPO}/issues/${number}"
    
    # Find and close associated charge codes
    echo "Looking for charge codes with GitHub URL: ${EXPECTED_URL}"
    CHARGE_CODES=$(psql $(op read op://zoo-shared-platform/env/DATABASE_URI) -tA -c "SELECT charge_code FROM vista.charge_codes WHERE lower(gh_link) = lower('${EXPECTED_URL}') AND closed_date IS NULL")
    
    if [ -n "$CHARGE_CODES" ]; then
        echo "Found associated charge codes:"
        while IFS= read -r code; do
            echo "  Closing charge code: $code"
            # Use expect to handle the interactive confirmation
            expect << EOF
                spawn ${REPO_ROOT}/vista/close-codes.bash --code "^${code}\$"
                expect "Would you like to proceed with closing these codes? (y/n)"
                send "y\r"
                expect eof
EOF
        done <<< "$CHARGE_CODES"
    else
        echo "No associated charge codes found for issue #$number"
    fi
done <<< "$MATCHING_ISSUES"

echo "Operation completed successfully"
