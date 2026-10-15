#!/usr/bin/env bash
#
# mkproject.sh
# Creates a generic project folder structure using lowercase kebab-case names.
#
# Usage:
#   ./mkproject.sh my-app
#
# Expects (optional) a gitignore template at:
#   <directory of this script>/gitignores/VisualStudio.gitignore
#
set -euo pipefail

# Resolve the directory this script lives in, so the gitignore template is
# found no matter which directory the script is run from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITIGNORE_TEMPLATE="$SCRIPT_DIR/gitignores/VisualStudio.gitignore"

# Use the first argument as the project name, or fall back to "my-app"
PROJECT="${1:-my-app}"

# Enforce lowercase kebab-case (letters, digits, single hyphens between words)
if [[ ! "$PROJECT" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "Error: project name '$PROJECT' must be lowercase kebab-case (e.g. my-app)." >&2
  exit 1
fi

# Refuse to overwrite an existing file or folder
if [[ -e "$PROJECT" ]]; then
  echo "Error: '$PROJECT' already exists." >&2
  exit 1
fi

# Folders named by role, all lowercase
FOLDERS=(
  frontend
  backend
  mobile
  desktop
  docs
  infra
  security
  config
  offline
)

# Create each folder, plus a .gitkeep so Git tracks otherwise-empty folders
for folder in "${FOLDERS[@]}"; do
  mkdir -p "$PROJECT/$folder"
  touch "$PROJECT/$folder/.gitkeep"
done

# Create the root README with the project name as its title
printf '# %s\n' "$PROJECT" > "$PROJECT/README.md"

# Create .gitignore, seeded from the template if it exists
if [[ -f "$GITIGNORE_TEMPLATE" ]]; then
  cat "$GITIGNORE_TEMPLATE" > "$PROJECT/.gitignore"
else
  touch "$PROJECT/.gitignore"
  echo "Warning: template not found at $GITIGNORE_TEMPLATE; created an empty .gitignore." >&2
fi

echo "Created project structure in: $PROJECT"