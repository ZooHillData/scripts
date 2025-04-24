#!/bin/bash

# Pass all arguments through to the supabase command
op run --env-file=./.env.local --no-masking -- npx supabase@latest "$@"