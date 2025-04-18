#!/usr/bin/env bash

# Default values
CLIENT=""
CONTRACT=""
PROJECT="-"
PROJECT_ITEM="-"
AUTHORIZED_HOURS=""

# Function to show usage
show_usage() {
    echo "Usage: add-code [options]"
    echo ""
    echo "Adds a new code to the vista.charge_codes table"
    echo ""
    echo "Required Options:"
    echo "  --client TEXT        Client name"
    echo "  --contract TEXT      Contract identifier"
    echo ""
    echo "Optional Options:"
    echo "  --project TEXT       Project name (default: '-')"
    echo "  --project-item TEXT  Project item (default: '-')"
    echo "  --authorized NUMBER  Authorized hours for the charge code"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Example:"
    echo "  add-code --client 'ACME' --contract 'CT123'"
    echo "  add-code --client 'ACME' --contract 'CT123' --project 'PRJ1' --project-item 'ITEM1' --authorized 40"
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

# Convert all inputs to uppercase immediately
CLIENT_UPPER=$(echo "${CLIENT}" | tr '[:lower:]' '[:upper:]')
CONTRACT_UPPER=$(echo "${CONTRACT}" | tr '[:lower:]' '[:upper:]')
PROJECT_UPPER=$(echo "${PROJECT}" | tr '[:lower:]' '[:upper:]')
PROJECT_ITEM_UPPER=$(echo "${PROJECT_ITEM}" | tr '[:lower:]' '[:upper:]')
CLIENT_PREFIX=$(echo "${CLIENT_UPPER}" | cut -c1-3 | tr '[:lower:]' '[:upper:]')

# Validate authorized hours is a number if provided
if [ ! -z "$AUTHORIZED_HOURS" ] && ! [[ "$AUTHORIZED_HOURS" =~ ^[0-9]+$ ]]; then
    echo "Error: --authorized must be a positive number"
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

# Check if the client/contract combination exists
CHECK_SQL="SELECT EXISTS(SELECT 1 FROM vista.contracts WHERE client = '${CLIENT_UPPER}' AND contract = '${CONTRACT_UPPER}')"
CONTRACT_EXISTS=$(psql $(op read op://zoo-shared-platform/env/DATABASE_URI) -tA -c "${CHECK_SQL}")

if [ "$CONTRACT_EXISTS" = "f" ]; then
    echo "Warning: The client/contract combination '${CLIENT_UPPER}/${CONTRACT_UPPER}' does not exist in vista.contracts"
    read -p "Would you like to create it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Use yes command to automatically answer the prompt
        yes y | ./vista/add-contract.bash --client "${CLIENT_UPPER}" --contract "${CONTRACT_UPPER}"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create contract"
            exit 1
        fi
    else
        echo "Operation cancelled - cannot add charge code without an existing contract"
        exit 1
    fi
fi

# Construct the charge code using already uppercase values
CHARGE_CODE="${CLIENT_PREFIX}:${CONTRACT_UPPER}:${PROJECT_UPPER}:${PROJECT_ITEM_UPPER}"

# Prepare SQL command with optional authorized_hours
if [ -z "$AUTHORIZED_HOURS" ]; then
    SQL_COMMAND="INSERT INTO vista.charge_codes(charge_code, client, contract, project, project_item, created_date) VALUES ('${CHARGE_CODE}', '${CLIENT_UPPER}', '${CONTRACT_UPPER}', '${PROJECT_UPPER}', '${PROJECT_ITEM_UPPER}', CURRENT_DATE)"
else
    SQL_COMMAND="INSERT INTO vista.charge_codes(charge_code, client, contract, project, project_item, created_date, authorized_hours) VALUES ('${CHARGE_CODE}', '${CLIENT_UPPER}', '${CONTRACT_UPPER}', '${PROJECT_UPPER}', '${PROJECT_ITEM_UPPER}', CURRENT_DATE, ${AUTHORIZED_HOURS})"
fi

echo "Executing SQL: ${SQL_COMMAND}"
if ! psql $(op read op://zoo-shared-platform/env/DATABASE_URI) -c "${SQL_COMMAND}"; then
    echo "Error: Failed to insert charge code"
    exit 1
fi

echo "Successfully added charge code"
