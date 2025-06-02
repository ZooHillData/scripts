#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Default values
SCHEMA=""

# Function to print usage
print_usage() {
    echo "Usage: gen-types [--schema SCHEMA]"
    echo
    echo "Description:"
    echo "  Generates TypeScript type definitions from your Supabase database schema."
    echo "  The types are generated using the local Supabase instance and saved to src/lib/types/db.ts"
    echo
    echo "Arguments:"
    echo "  --schema    Optional schema name to filter types by"
    echo "             If not provided, types will be generated for all schemas"
    echo "  --help, -h Show this help message"
    echo
    echo "Examples:"
    echo "  # Generate types for all schemas"
    echo "  gen-types"
    echo
    echo "  # Generate types for a specific schema"
    echo "  gen-types --schema auth"
    echo
    echo "Notes:"
    echo "  - Uses op-nomask for secure credential handling"
    echo "  - Requires a running local Supabase instance"
    echo "  - Output is always written to src/lib/types/db.ts"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --schema)
            SCHEMA="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            ;;
    esac
done

# Build the command
CMD="$REPO_ROOT/op/op-nomask.bash -- npx supabase gen types typescript --local"

# Add schema filter if provided
if [[ -n "$SCHEMA" ]]; then
    CMD="$CMD --schema $SCHEMA"
fi


# Execute the command
eval "$CMD"