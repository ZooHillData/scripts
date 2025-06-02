# Supabase Scripts

This directory contains scripts for managing Supabase-related tasks.

## Scripts

### generate-migration

The `generate-migration` script automates the process of generating Supabase migrations by:

1. Stopping the local Supabase instance
2. Generating a migration diff based on schema changes
3. Providing guidance for next steps

#### Usage

```bash
generate-migration --filename DESCRIPTION
```

#### Arguments

- `--filename`: Description of the change that will be used as the migration filename
  - Example: `add-user-profile-table`
  - The actual migration file will be created at: `supabase/migrations/YYYYMMDDHHMMSS_description.sql`

#### Example

```bash
# Generate a migration for adding a user profile table
generate-migration --filename "add-user-profile-table"
```

#### Workflow

1. Make changes to your schema files in `supabase/schemas/`
2. Run the `generate-migration` script with a descriptive filename
3. Review the generated migration file (IMPORTANT!)
4. Start Supabase for testing using: `op-nomask -- npx supabase start`

#### Notes

- Always review the generated migration file before proceeding
- The script uses `op-nomask` for secure credential handling
- Migration files are automatically named with a timestamp prefix

### link-remote

The `link-remote` script facilitates linking to a remote Supabase database and comparing the local `config.toml` with the remote configuration by:

1. Using 1Password vault credentials to authenticate
2. Linking to the remote Supabase project
3. Comparing local and remote configurations
4. Providing guidance for resolving any differences

#### Usage

```bash
link-remote --vault VAULT_NAME
```

#### Arguments

- `--vault`: Name of the 1Password vault containing the required credentials
  - Must contain:
    - `env.PROD/SUPABASE_PROJECT_ID`
    - `env.PROD/SUPABASE_DB_PASSWORD`

#### Example

```bash
# Link to remote database using my-project vault
link-remote --vault "my-project"
```

#### Workflow

1. Run the `link-remote` script with your vault name
2. If configuration differences are found, you have two options:
   - Update your local config based on the displayed differences
   - Push your local changes using `op-nomask -- npx supabase config push`
3. Run the script again to verify changes if needed

#### Notes

- Uses `op-nomask` for secure credential handling
- Automatically detects and reports configuration differences
- Provides clear guidance for resolving configuration conflicts

### gen-types

The `gen-types` script automates the process of generating TypeScript type definitions from your Supabase database schema by:

1. Using the local Supabase instance to inspect the database schema
2. Generating TypeScript types for all tables and custom types
3. Writing the output to a predefined location

#### Usage

```bash
gen-types [--schema SCHEMA]
```

#### Arguments

- `--schema`: Optional schema name to filter types by
  - If not provided, types will be generated for all schemas
  - Example: `auth`, `public`, etc.

#### Examples

```bash
# Generate types for all schemas
gen-types

# Generate types for a specific schema
gen-types --schema auth
```

#### Workflow

1. Ensure your local Supabase instance is running
2. Run the `gen-types` script, optionally specifying a schema
3. TypeScript types will be generated at `src/lib/types/db.ts`

#### Notes

- Uses `op-nomask` for secure credential handling
- Requires a running local Supabase instance
- Always writes output to `src/lib/types/db.ts`
- Generated types reflect the current state of your database schema
