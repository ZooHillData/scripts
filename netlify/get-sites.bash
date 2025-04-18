#!/usr/bin/env bash

# Default values
NAME=""
URL=""
FIELDS="name,id,url"
FORMAT="json"

# Function to show usage
show_usage() {
    echo "Usage: get-sites [options]"
    echo ""
    echo "Lists Netlify sites with flexible filtering and formatting"
    echo ""
    echo "Options:"
    echo "  --name PATTERN    Regex pattern to filter site names (optional)"
    echo "  --url PATTERN     Regex pattern to filter site URLs (optional)"
    echo "  --fields LIST     Comma-separated list of fields to display (default: name,id,url)"
    echo "  --format TYPE     Output format: 'json' or 'table' (default: json)"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Example:"
    echo "  get-sites --name 'zhd' --fields 'name,url'"
    echo "  get-sites --url 'netlify.app'"
    echo "  get-sites --name 'prod' --format table"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            NAME="$2"
            shift 2
            ;;
        --url)
            URL="$2"
            shift 2
            ;;
        --fields)
            FIELDS="$2"
            shift 2
            ;;
        --format)
            if [[ "$2" != "table" && "$2" != "json" ]]; then
                echo "Error: format must be 'json' or 'table'"
                exit 1
            fi
            FORMAT="$2"
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

# Check if netlify CLI is installed
if ! command -v netlify &> /dev/null; then
    echo "Error: Netlify CLI is not installed. Please install it first."
    echo "Run: npm install -g netlify-cli"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    echo "Run: brew install jq"
    exit 1
fi

# Create a temporary file for the JSON data
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# Get the data with error handling
if ! netlify sites:list --json > "$TEMP_FILE" 2>/dev/null; then
    echo "Error: Failed to fetch sites from Netlify. Please try again."
    exit 1
fi

# Build the selection filter
FILTER=".[]"

# Add name filter if specified
if [ -n "$NAME" ]; then
    FILTER="$FILTER | select(.name | tostring | test(\"$NAME\"; \"i\"))"
fi

# Add URL filter if specified
if [ -n "$URL" ]; then
    FILTER="$FILTER | select(.url | tostring | test(\"$URL\"; \"i\"))"
fi

# Convert fields to array for selection
FIELD_ARRAY=$(echo "$FIELDS" | tr ',' ' ')
read -r -a FIELDS_ARR <<< "$FIELD_ARRAY"

if [ "$FORMAT" = "json" ]; then
    # Build object with selected fields
    SELECT_EXPR="{"
    for field in "${FIELDS_ARR[@]}"; do
        SELECT_EXPR="$SELECT_EXPR\"$field\": .$field,"
    done
    SELECT_EXPR="${SELECT_EXPR%,}}"
    
    # Output JSON format
    jq "$FILTER | $SELECT_EXPR" "$TEMP_FILE"
else
    # Create markdown table
    # First, get the field names for the header
    HEADER=$(echo "$FIELDS" | tr ',' '|' | sed 's/^/|/' | sed 's/$/|/')
    SEPARATOR=$(echo "$FIELDS" | sed 's/[^,]*/---/g' | tr ',' '|' | sed 's/^/|/' | sed 's/$/|/')
    
    # Print the header
    echo "$HEADER"
    echo "$SEPARATOR"
    
    # Build array selection for fields
    ARRAY_EXPR="["
    for field in "${FIELDS_ARR[@]}"; do
        ARRAY_EXPR="$ARRAY_EXPR(.$field | tostring),"
    done
    ARRAY_EXPR="${ARRAY_EXPR%,}]"
    
    # Convert the data to table rows
    jq -r "$FILTER | $ARRAY_EXPR | @tsv" "$TEMP_FILE" | \
    while IFS=$'\t' read -r line; do
        echo "|$(echo "$line" | sed 's/\t/|/g')|"
    done
fi
