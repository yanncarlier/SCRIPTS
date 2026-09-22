#!/usr/bin/env bash
#
# mkproject.sh
# Creates a generic project folder structure.
#
# Usage:
#   ./mkproject.sh my-app
#
set -euo pipefail

# Use the first argument as the project name, or fall back to "my-app"
PROJECT="${1:-my-app}"

# Create all folders in one command (-p also creates parent folders)
mkdir -p \
  "$PROJECT/Frontend" \
  "$PROJECT/Backend" \
  "$PROJECT/Mobile/" \
  "$PROJECT/Docs" \
  "$PROJECT/Infra" \
  "$PROJECT/Desktop" \
  "$PROJECT/gitignore"

echo "Created project structure in: $PROJECT"


# Create the empty root files
touch "$PROJECT/README.md" "$PROJECT/.gitignore"
cat gitignores/VisualStudio.gitignore >> "$PROJECT/.gitignore"
echo gitignore >> "$PROJECT/.gitignore"
