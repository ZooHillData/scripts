# Script Management System

This repository contains a collection of shell scripts and a management system to make them easily accessible from anywhere in your terminal.

## Quick Start

1. Install the scripts (from the root of this repository):
   ```bash
   ./add-to-rc.bash
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

### Installation (`add-to-rc.bash`)

The `add-to-rc.bash` script:
- Finds all `.bash` files in the repository (top level and one directory deep)
- Creates aliases for each script in your shell configuration file
- Uses the script's basename as the alias (e.g., `deployment/script.bash` becomes `script`)
- Defaults to `~/.zshrc` but can use a different file:
  ```bash
  ./add-to-rc.bash ~/.bashrc
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
- Each script's alias is based on its filename (without the `.bash` extension)
- Scripts in subdirectories are grouped by their directory name

## Example Usage

### Script Management

```bash
# Install all scripts
./add-to-rc.bash

# List installed scripts
get-scripts

# List all scripts including uninstalled ones
get-scripts --include-uninstalled

# List scripts without paths
get-scripts --no-paths
```

## Scripts

### Deployment

#### env-to-1p

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

#### 1p-to-netlify

```bash
# Sync environment variables between 1Password and Netlify
1p-to-netlify --vault <vault_name> --item <item_id> --site-name <netlify_site_name> [--to <netlify|1p>] [--remove]

# Required arguments:
# --vault     : Name of the 1Password vault
# --item      : ID of the item in the vault
# --site-name : Netlify site name to link to

# Optional arguments:
# --to        : Target system to sync to (netlify or 1p, default: netlify)
# --remove    : Automatically remove keys that don't exist in the source

# Examples:
# Sync from 1Password to Netlify
1p-to-netlify --vault Development --item prod-env --site-name my-site

# Sync from Netlify to 1Password
1p-to-netlify --vault Development --item prod-env --site-name my-site --to 1p

# Sync and remove extra variables
1p-to-netlify --vault Development --item prod-env --site-name my-site --remove
```

### Netlify

#### get-sites

```bash
# List Netlify sites with flexible filtering and formatting
get-sites [options]

# Options:
# --name PATTERN    : Regex pattern to filter site names
# --url PATTERN     : Regex pattern to filter site URLs
# --fields LIST     : Comma-separated list of fields to display (default: name,id,url)
# --format TYPE     : Output format: 'json' or 'table' (default: json)

# Examples:
get-sites --name 'prod' --fields 'name,url'           # Filter prod sites, show name and URL
get-sites --url 'netlify.app' --format table          # Filter by URL, show as table
get-sites --fields 'name,id,url,build_settings.repo'  # Custom fields
```

## Patterns

### Push Env from 1Password to Netlify (and build)

```bash
VAULT=wgb
ITEM=env
URL=wgb.cpa

site_name=$(get-sites --url $URL --format json | jq -r '.name')
netlify link --name $site_name
1p-to-netlify --vault $VAULT --item $ITEM --site-name $site_name --to netlify
netlify build --trigger --prod
```

### Pull Env from Netlify to 1Password

```bash
VAULT=wgb
ITEM=env
URL=wgb.cpa

site_name=$(get-sites --url $URL --format json | jq -r '.name')
netlify link --name $site_name
1p-to-netlify --vault $VAULT --item $ITEM --site-name $site_name --to 1p

```

### Push Env from 1Password to Netlify (and build)

```bash
