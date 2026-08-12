#!/usr/bin/env bash
# 02-gh-enable-push-protection.sh
# Summary: Enable GitHub Advanced Security Push Protection (Secret Scanning Push Protection)
# for one or more repositories using the GitHub CLI (`gh`).
#
# Prerequisites:
#  - `gh` (GitHub CLI) installed and authenticated: `gh auth login`
#  - Admin access to target repositories and GH Advanced Security available
#  - Secret scanning must be enabled first
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 04-gh-enable-push-protection.sh
#  If empty, public repos for OWNER are fetched.

set -euo pipefail

OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}
REPOS_TO_PROCESS=()

echo "Preparing to enable push protection for $OWNER..."

if [ -z "${REPOS}" ]; then
  echo "  (fetching public repositories for $OWNER)"
  REPOS=$(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public | paste -sd, -)
  if [ -z "${REPOS}" ]; then
    echo "ERROR: No public repositories found for $OWNER."
    exit 1
  fi
fi

# Split comma-separated string into array and trim whitespace
IFS=',' read -r -a REPOS_ARRAY <<< "$REPOS"
for r in "${REPOS_ARRAY[@]}"; do
  r="${r// /}"
  REPOS_TO_PROCESS+=("$r")
done

count=0
for repo_name in "${REPOS_TO_PROCESS[@]}"; do
  if [[ "$repo_name" == *"/"* ]]; then
    repo="$repo_name"
  else
    repo="$OWNER/$repo_name"
  fi
  echo "=========================================="
  echo "Processing $repo"

  # Skip archived repositories
  archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    continue
  fi

  # Check if secret scanning is enabled (required for push protection)
  secret_scanning=$(gh api "repos/$repo" --jq '.security_and_analysis.secret_scanning.status' 2>/dev/null || echo "disabled")
  if [ "$secret_scanning" != "enabled" ]; then
    echo "  -> WARNING: Secret scanning is not enabled. Push protection requires secret scanning to be enabled first."
    echo "  -> Skipping $repo"
    continue
  fi

  # Enable push protection via API
  # Use PATCH on the repo endpoint with security_and_analysis settings
  if gh api "repos/$repo" --method PATCH -f security_and_analysis[secret_scanning_push_protection][status]=enabled >/dev/null 2>&1; then
    echo "  -> Push protection enabled for $repo"
    count=$((count+1))
  else
    echo "  -> ERROR: Failed to enable push protection for $repo"
  fi
done

echo "=========================================="
echo "Done. Enabled push protection for $count repositories."
