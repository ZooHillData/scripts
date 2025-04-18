#!/usr/bin/env bash

# Default values
CLIENT=""
CONTRACT=""

# Color codes
GREEN_BOLD=$'\e[1;32m'
NC=$'\e[0m' # No Color

# Function to show usage
show_usage() {
    echo "Usage: add-contract [options]"
    echo ""
    echo "Adds a new contract to the vista.contracts table"
    echo ""
    echo "Required Options:"
    echo "  --client TEXT        Client name (will be converted to uppercase)"
    echo "  --contract TEXT      Contract identifier (will be converted to uppercase)"
    echo ""
    echo "Optional Options:"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Example:"
    echo "  add-contract --client 'acme' --contract 'ct123'"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --client)
            CLIENT="$2"
            shift 2
            ;;
        --contract)
            CONTRACT="$2"
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
if [ -z "$CLIENT" ] || [ -z "$CONTRACT" ]; then
    echo "Error: --client and --contract are required"
    echo "Use --help for usage information"
    exit 1
fi

# Convert inputs to uppercase immediately
CLIENT_UPPER=$(echo "${CLIENT}" | tr '[:lower:]' '[:upper:]')
CONTRACT_UPPER=$(echo "${CONTRACT}" | tr '[:lower:]' '[:upper:]')

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

# Prepare SQL command
SQL_COMMAND="INSERT INTO vista.contracts(client, contract, created_date) VALUES ('${CLIENT_UPPER}', '${CONTRACT_UPPER}', CURRENT_DATE)"

echo "This will execute the following SQL:"
echo
echo "${GREEN_BOLD}${SQL_COMMAND};${NC}"
echo

read -p "Would you like to proceed? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! psql $(op read op://zoo-shared-platform/env/DATABASE_URI) -c "${SQL_COMMAND}"; then
        echo "Error: Failed to insert contract"
        exit 1
    fi
    
    echo "Successfully added contract"
else
    echo "Operation cancelled"
    exit 0
fi
