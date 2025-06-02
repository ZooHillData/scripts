#!/bin/bash

# Default values
ENV_FILE=".env.example"

# Check if help is requested
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: $0 [options] [-- command...]"
    echo ""
    echo "Options:"
    echo "  --prod           : Use production environment file (.env.local)"
    echo "  --env <file>     : Use a custom environment file"
    echo "                     This overrides --prod if both are specified"
    echo "  -h, --help       : Show this help message"
    echo ""
    echo "If no options are provided, uses .env.example"
    echo ""
    echo "Examples:"
    echo "Simple commands:"
    echo "  $0                                     # Uses .env.example"
    echo "  $0 --prod                             # Uses .env.local"
    echo "  $0 --env .env.staging                 # Uses .env.staging"
    echo ""
    echo "With command arguments:"
    echo "  $0 -- printenv                        # Basic command"
    echo "  $0 --prod -- printenv                 # With prod env"
    echo "  $0 --env .env.test -- printenv        # With custom env"
    echo ""
    echo "Complex commands:"
    echo "  $0 --prod -- npx supabase link -p \"value\"  # Command with flags"
    echo "  $0 -- \"command with spaces\" arg1 arg2       # Command with spaces"
    exit 0
fi

# Parse arguments until we hit -- or run out of arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prod)
            ENV_FILE=".env.local"
            shift
            ;;
        --env)
            if [ -z "$2" ]; then
                echo "Error: --env requires a file path argument"
                exit 1
            fi
            ENV_FILE="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error: Unknown option $1"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

# Run 1Password CLI with no masking, passing all remaining arguments
op run --env-file="$ENV_FILE" --no-masking -- "$@" 
