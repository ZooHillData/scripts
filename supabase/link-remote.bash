#!/usr/bin/env bash

# Ensure script fails on any error
set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Default values
VAULT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --vault)
      VAULT="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown argument $1"
      echo "Usage: link-remote.bash --vault <vault-name>"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$VAULT" ]]; then
  echo "Error: --vault argument is required"
  echo "Usage: link-remote.bash --vault <vault-name>"
  exit 1
fi

# Execute the Supabase link command with 1Password credentials
"${REPO_ROOT}/op/op-nomask.bash" --prod -- npx supabase link \
  --project-ref "$(op read "op://${VAULT}/env.PROD/SUPABASE_PROJECT_ID")" \
  --password "$(op read "op://${VAULT}/env.PROD/SUPABASE_DB_PASSWORD")"
