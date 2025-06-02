#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$REPO_ROOT/../stairwell" && pwd )"

# ANSI color codes
BOLD="\033[1m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# Function to print usage
print_usage() {
    echo "Usage: generate-migration --filename DESCRIPTION [--replace]"
    echo
    echo "Description:"
    echo "  Automates the Supabase migration generation process by stopping the local"
    echo "  instance, generating a migration diff, and providing next steps."
    echo
    echo "Arguments:"
    echo "  --filename    Description of the change (will be used as migration filename)"
    echo "                Example: 'add-user-profile-table'"
    echo "  --replace    Automatically replace any existing migration files with the"
    echo "               same name without prompting"
    echo
    echo "Example:"
    echo "  generate-migration --filename 'add-user-profile-table'"
    echo "  generate-migration --filename 'add-user-profile-table' --replace"
    exit 1
}

# Function to handle errors
handle_error() {
    echo -e "${BOLD}${RED}Error: $1${RESET}"
    exit 1
}

# Function to find and handle existing migration files
check_existing_migrations() {
    local name="$1"
    local auto_replace="$2"
    
    # Convert the name to a standardized format (lowercase, replace spaces/special chars with hyphens)
    local normalized_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    
    # Find any migration files containing the normalized name (case insensitive)
    # We look for the name part after the timestamp
    local files=$(find "${PROJECT_ROOT}/supabase/migrations" -type f -name "*_${normalized_name}.sql" 2>/dev/null)
    
    if [[ -n "$files" ]]; then
        echo -e "${BOLD}${YELLOW}Found existing migration files with similar names:${RESET}"
        echo "$files" | sed 's/^/  /'
        echo
        
        if [[ "$auto_replace" == "true" ]]; then
            echo "Automatically removing existing migration files..."
            echo "$files" | xargs rm
            echo "✓ Existing migration files removed"
            return 0
        fi
        
        echo -e "${BOLD}This will replace the existing migration file(s).${RESET}"
        read -p "Do you want to proceed? [y/N] " response
        if [[ "$response" =~ ^[Yy] ]]; then
            echo "$files" | xargs rm
            echo "✓ Existing migration files removed"
            return 0
        else
            echo "Operation cancelled by user"
            exit 1
        fi
    fi
}

# Default values
REPLACE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --filename)
            FILENAME="$2"
            shift 2
            ;;
        --replace)
            REPLACE=true
            shift
            ;;
        *)
            echo -e "${BOLD}${RED}Error: Unknown argument $1${RESET}"
            print_usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$FILENAME" ]]; then
    echo -e "${BOLD}${RED}Error: --filename is required${RESET}"
    print_usage
fi

# Check for existing migrations
check_existing_migrations "$FILENAME" "$REPLACE"

echo "Stopping Supabase instance..."
cd "${PROJECT_ROOT}" && "${REPO_ROOT}/op/op-nomask.bash" -- npx supabase stop || handle_error "Failed to stop Supabase"

echo "Generating migration diff..."
# Create a temporary file for capturing output
TEMP_OUTPUT=$(mktemp)

# Run the command and capture output to temp file, while also redirecting stderr to stdout
cd "${PROJECT_ROOT}" && "${REPO_ROOT}/op/op-nomask.bash" -- npx supabase db diff -f "$FILENAME" > "$TEMP_OUTPUT" 2>&1

# Check if the command failed
if [[ $? -ne 0 ]]; then
    cat "$TEMP_OUTPUT"  # Show the error output
    rm "$TEMP_OUTPUT"
    handle_error "Failed to generate migration diff"
fi

# Extract the migration file path from the output
MIGRATION_FILE=$(grep -o "supabase/migrations/.*\.sql" "$TEMP_OUTPUT" || echo "")

# Display the command output (without double printing)
cat "$TEMP_OUTPUT"

# Clean up
rm "$TEMP_OUTPUT"

echo "✓ Migration file generated successfully"
if [[ -n "$MIGRATION_FILE" ]]; then
    echo -e "${BOLD}⚠️  Please review the migration file before proceeding:${RESET}"
    echo "   $MIGRATION_FILE"
else
    echo -e "${BOLD}⚠️  Please review the migration file before proceeding!${RESET}"
fi
echo
echo "Next steps:"
echo "1. Review the migration file carefully"
echo "2. If you find problems, you can update the schema definition file and re-create the migration:"
echo "   - Run the same command again (will prompt for confirmation)"
echo "   - Use --replace to skip the confirmation prompt"
echo "   - ‼️  It is recommended that as much as possible, you modify the files in supabase/schemas/ instead of directly modifying the migration"
echo "3. To start the local instance of Supabase for testing, run:"
echo "   ${REPO_ROOT}/op/op-nomask.bash -- npx supabase start"

