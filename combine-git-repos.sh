#!/usr/bin/env bash
#
# combine-git-repos.sh - Merge multiple Git repositories found in a directory
# tree into ONE new repository, preserving each repo's full history.
# Each source repo ends up in a subdirectory with the same relative path it
# had in the source tree (e.g. ./TERRAFORM_AWS/AWS_Simple_services).
#
# Usage:
#   ./combine-git-repos.sh SOURCE_DIR DEST_DIR
#
# Example:
#   ./combine-git-repos.sh ~/work ~/work-combined
#
# Notes:
#   - The original repositories are NOT modified.
#   - Only committed work is imported. Uncommitted changes and untracked
#     files are ignored (commit or stash them first if you need them).
#   - DEST_DIR must not already exist.
#   - Requires git with the "subtree" command (included in most installs).

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 SOURCE_DIR DEST_DIR" >&2
    exit 1
fi

SRC="$(cd "$1" && pwd)"
DEST="$2"

if [[ -e "$DEST" ]]; then
    echo "Error: '$DEST' already exists. Choose a new destination." >&2
    exit 1
fi

# Collect repositories (directories containing a .git directory).
# -prune stops find from descending into .git itself.
mapfile -d '' GIT_PATHS < <(find "$SRC" -type d -name .git -prune -print0)

if [[ ${#GIT_PATHS[@]} -eq 0 ]]; then
    echo "No Git repositories found under '$SRC'." >&2
    exit 1
fi

echo "Found ${#GIT_PATHS[@]} repositories:"
for gp in "${GIT_PATHS[@]}"; do
    echo "  ${gp%/.git}"
done
echo

# Create the new combined repository with an initial empty commit
# (git subtree add needs an existing HEAD to build on).
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
cd "$DEST"
git init -q
git commit -q --allow-empty -m "Initial commit for combined repository"

for gp in "${GIT_PATHS[@]}"; do
    repo="${gp%/.git}"
    rel="${repo#"$SRC"/}"    # path relative to SOURCE_DIR, used as the prefix

    # Skip repos that have no commits.
    if ! git -C "$repo" rev-parse --verify -q HEAD >/dev/null; then
        echo "Skipping '$rel' (no commits)."
        continue
    fi

    # Warn about uncommitted changes that won't be imported.
    if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
        echo "WARNING: '$rel' has uncommitted changes; they will not be imported."
    fi

    echo "Importing '$rel' ..."
    # Fetch whatever HEAD points to (works even on a detached HEAD),
    # then graft it in under the subdirectory with its history intact.
    git fetch -q "$repo" HEAD
    git subtree add --prefix="$rel" FETCH_HEAD \
        -m "Import $rel into combined repository"
done

echo
echo "Done. Combined repository created at: $DEST"
echo "Recent history:"
git log --oneline --graph -n 15