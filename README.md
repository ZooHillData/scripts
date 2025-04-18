# Script Management System

This repository contains a collection of shell scripts and a management system to make them easily accessible from anywhere in your terminal.

## Quick Start

1. Install the scripts (from the root of this repository):
   ```bash
   ./add-to-rc.sh
   ```

2. Source your shell configuration:
   ```bash
   source ~/.zshrc  # or restart your terminal
   ```

3. List available scripts:
   ```bash
   get-scripts
   ```

## Script Management

### Installation (`add-to-rc.sh`)

The `add-to-rc.sh` script:
- Finds all `.sh` files in the repository (top level and one directory deep)
- Creates aliases for each script in your shell configuration file
- Uses the script's basename as the alias (e.g., `deployment/script.sh` becomes `script`)
- Defaults to `~/.zshrc` but can use a different file:
  ```bash
  ./add-to-rc.sh ~/.bashrc
  ```

### List available scripts (`get-scripts`)

The `get-scripts` command shows all available scripts with their installation status:
- Groups scripts by directory
- Shows installation status with `[installed]` or `[uninstalled]`
- Options:
  - `--include-uninstalled`: Show all scripts, including uninstalled ones
  - `--no-paths`: Hide full file paths (cleaner output)
  - `--include-paths`: Show full file paths (default)

## Script Organization

Scripts are organized in the repository with the following assumptions:
- Scripts are either at the root level or one directory deep
- Each script's alias is based on its filename (without the `.sh` extension)
- Scripts in subdirectories are grouped by their directory name

## Example Usage

### Script Management

```bash
# Install all scripts
./add-to-rc.sh

# List installed scripts
get-scripts

# List all scripts including uninstalled ones
get-scripts --include-uninstalled

# List scripts without paths
get-scripts --no-paths
```

### Specific Scripts (Deployment)

```bash
# Use env-to-1p to create a 1Password item from a .env file
env-to-1p --vault <vault_name> --item <item_id> [--env-file <path>]

# Required arguments:
# --vault     : Name of the 1Password vault to store the item in
# --item      : ID/name of the item to create/update
# --env-file  : Path to the .env file (defaults to .env)

# Example:
env-to-1p --vault Development --item my-project-env --env-file .env.local
``` 