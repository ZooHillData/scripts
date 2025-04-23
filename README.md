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

```

### Project Management

#### add-issue

```bash
# Create GitHub issues with optional charge code creation
add-issue --repo REPO [--org ORG] --title TITLE [--description] [--active] [charge code options]

# Required arguments:
# --repo         : Repository name
# --title        : Issue title

# Optional arguments:
# --org          : Organization name (default: zoohilldata)
# --description  : Enter description interactively
# --active       : Add issue to Active project

# Charge code integration:
# If --client is provided, a charge code will be created after the issue
# The GitHub issue URL will be automatically linked to the charge code
# --client TEXT        : Client name (triggers charge code creation)
# --contract TEXT      : Contract identifier (required with --client)
# --project TEXT       : Project name (default: '-')
# --project-item TEXT  : Project item (default: '-')
# --authorized NUMBER  : Authorized hours for the charge code

# Examples:
# Create a simple issue
add-issue --repo scripts --title "Bug Fix" --description

# Create an issue and add to Active project
add-issue --repo scripts --title "New Feature" --active

# Create an issue with charge code
add-issue --repo scripts --title "New Feature" --description \
  --client ACME --contract CT123

# Create an issue with full charge code details
add-issue --repo scripts --title "Project Setup" --description \
  --client ACME \
  --contract CT123 \
  --project PRJ1 \
  --project-item ITEM1 \
  --authorized 40

# Description Input:
# When --description is used, you'll be prompted to enter a multi-line description
# - Type or paste your description
# - Use markdown formatting if desired
# - Press Ctrl+D when done
```

#### Repository Configuration

The `standard-repo-config.json` file defines standard settings for repository management. Currently, it includes:

- Standard label definitions with descriptions and colors
- (More configuration options will be added as repository standardization evolves)

#### add-standard-labels

```bash
# Add or update standard labels in a GitHub repository
add-standard-labels --repo REPO [--org ORG] [--execute]

# Required arguments:
# --repo         : Repository name

# Optional arguments:
# --org          : Organization name (default: ZooHillData)
# --execute      : Actually create/update the labels (default: dry-run)

# Examples:
# Preview label changes
add-standard-labels --repo my-repo

# Apply label changes
add-standard-labels --repo my-repo --execute

# Apply to different organization
add-standard-labels --repo my-repo --org MyOrg --execute

# Notes:
# - Labels are defined in standard-repo-config.json
# - Existing labels with same names will be updated
# - Uses GitHub CLI (gh) for authentication
# - Requires repository admin access
```

#### delete-labels

```bash
# Delete GitHub repository labels that match a pattern
delete-labels --repo REPO --pattern PATTERN [--org ORG] [--execute]

# Required arguments:
# --repo         : Repository name
# --pattern      : Regular expression pattern for labels to keep

# Optional arguments:
# --org          : Organization name (default: ZooHillData)
# --execute      : Actually delete the labels (default: dry-run)

# Examples:
# Preview label deletions
delete-labels --repo my-repo --pattern '^(bug|feature|enhancement)$'

# Execute label deletions
delete-labels --repo my-repo --pattern '^(bug|feature|enhancement)$' --execute

# Notes:
# - Pattern is a regular expression that matches labels to KEEP
# - All labels NOT matching the pattern will be deleted
# - Uses GitHub CLI (gh) for authentication
# - Requires repository admin access
# - Use with caution as deletion cannot be undone
```

### Vista

Scripts for managing Vista charge codes and contracts.

#### add-code

```bash
# Add a new charge code to the vista.charge_codes table
add-code [options]

# Required arguments:
# --client TEXT        : Client name
# --contract TEXT      : Contract identifier

# Optional arguments:
# --project TEXT       : Project name (default: '-')
# --project-item TEXT  : Project item (default: '-')
# --authorized NUMBER  : Authorized hours for the charge code
# --gh-url TEXT       : GitHub URL to associate with the charge code

# Examples:
# Add basic charge code
add-code --client ACME --contract CT123

# Add charge code with project details and GitHub URL
add-code --client ACME --contract CT123 --project PRJ1 --project-item ITEM1 --gh-url 'https://github.com/org/repo/issues/1'

# Add charge code with authorized hours
add-code --client ACME --contract CT123 --authorized 40

# Note:
# - Client/contract will be automatically created if they don't exist
# - Charge code format: <CLIENT_PREFIX>:<CONTRACT>:<PROJECT>:<PROJECT_ITEM>
# - All inputs are automatically converted to uppercase
# - When used with add-issue, the GitHub URL is automatically linked
```

#### add-contract

```bash
# Add a new contract to the vista.contracts table
add-contract --client CLIENT --contract CONTRACT

# Required arguments:
# --client TEXT    : Client name
# --contract TEXT  : Contract identifier

# Example:
add-contract --client ACME --contract CT123

# Note:
# - All inputs are automatically converted to uppercase
# - Used automatically by add-code when needed
```

#### close-codes

Close charge codes by setting their closed_date to today's date.

```bash
close-codes --code CHARGE_CODE
```

Example:

```bash
close-codes --code "ACM:CT123:PRJ1:ITEM1"
```

#### delete-codes

```bash
# Delete charge codes from the vista.charge_codes table using regex patterns
delete-codes --code PATTERN

# Required arguments:
# --code TEXT  : Regex pattern to match charge codes

# Examples:
# Delete all codes for a client
delete-codes --code 'ACME:.*'

# Delete codes for specific contract
delete-codes --code 'ACME:CT123:.*'

# Delete codes for specific project
delete-codes --code 'ACME:CT123:PRJ1:.*'

# Note:
# - Pattern is automatically converted to uppercase
# - Matches are shown for confirmation before deletion
# - Use with caution as deletion cannot be undone
# - Uses PostgreSQL regex syntax
```
