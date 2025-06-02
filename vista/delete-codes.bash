#!/usr/bin/env bash

# Default values
CODE_PATTERN=""

# Color codes
GREEN_BOLD=$'\e[1;32m'
NC=$'\e[0m' # No Color

# Function to show usage
show_usage() {
    echo "Usage: delete-codes [options]"
    echo ""
    echo "Deletes charge codes matching the specified pattern"
    echo ""
    echo "Required Options:"
    echo "  --code PATTERN      Regex pattern to match charge codes"
    echo ""
    echo "Optional Options:"
    echo "  --help, -h         Show this help message"
    echo ""
    echo "Example:"
    echo "  delete-codes --code 'ACME:.*'          # Delete all ACME codes"
    echo "  delete-codes --code 'ACME:CT123:.*'    # Delete all codes for contract CT123"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --code)
            CODE_PATTERN="$2"
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
if [ -z "$CODE_PATTERN" ]; then
    echo "Error: --code is required"
    echo "Use --help for usage information"
    exit 1
fi

# Convert pattern to uppercase immediately
CODE_PATTERN_UPPER=$(echo "${CODE_PATTERN}" | tr '[:lower:]' '[:upper:]')

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

# Get matching codes
MATCHING_CODES=$(psql $(op read op://zoo-shared-platform/prod/SUPABASE_DB_URI) -tA -c "SELECT charge_code FROM vista.charge_codes WHERE charge_code ~ '${CODE_PATTERN_UPPER}' ORDER BY charge_code")

if [ -z "$MATCHING_CODES" ]; then
    echo "No charge codes found matching pattern '${CODE_PATTERN}'"
    exit 0
fi

# Format codes for display and SQL
FORMATTED_CODES=$(echo "$MATCHING_CODES" | sed "s/^/'/" | sed "s/$/'/" | paste -sd "," -)
DISPLAY_CODES=""
while IFS= read -r code; do
    DISPLAY_CODES+="    ${GREEN_BOLD}'${code}'${NC},\n"
done <<< "$MATCHING_CODES"
DISPLAY_CODES=${DISPLAY_CODES%,*} # Remove trailing comma

# Prepare SQL command
SQL_COMMAND="DELETE FROM vista.charge_codes WHERE charge_code IN (${FORMATTED_CODES})"

echo "This will execute the following SQL:"
echo
echo "DELETE FROM vista.charge_codes"
echo "WHERE charge_code IN ("
echo -e "${DISPLAY_CODES}"
echo ");"
echo

read -p "Would you like to proceed with deleting these codes? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! psql $(op read op://zoo-shared-platform/prod/SUPABASE_DB_URI) -c "${SQL_COMMAND}"; then
        echo "Error: Failed to delete charge codes"
        exit 1
    fi
    
    echo "Successfully deleted charge codes"
else
    echo "Operation cancelled"
    exit 0
fi
