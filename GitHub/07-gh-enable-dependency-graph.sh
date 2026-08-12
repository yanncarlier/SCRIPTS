#!/usr/bin/env bash
# 7-gh-enable-dependency-graph.sh
# Summary: Enable GitHub dependency graph for one or more repositories using `gh`.
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to the target repositories
#
# Note: There is no REST endpoint for the dependency graph itself; GitHub
#       enables it via `PUT /repos/{owner}/{repo}/vulnerability-alerts`,
#       which also enables Dependabot alerts.
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 7-gh-enable-dependency-graph.sh
#  If empty, public repos for OWNER are fetched.

set -euo pipefail

OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}
REPOS_TO_PROCESS=()

echo "Preparing to enable dependency graph for $OWNER..."

if [ -z "${REPOS}" ]; then
  echo "  (fetching public repositories for $OWNER)"
  REPOS=$(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public | paste -sd, -)
  if [ -z "${REPOS}" ]; then
    echo "ERROR: No public repositories found for $OWNER."
    exit 1
  fi
fi

# Parse comma-separated REPOS and normalize
IFS=',' read -r -a REPOS_ARRAY <<< "$REPOS"
for r in "${REPOS_ARRAY[@]}"; do
  r="${r// /}"
  # If user provided owner/repo, use as-is; otherwise prefix with OWNER
  if [[ "$r" == *"/"* ]]; then
    REPOS_TO_PROCESS+=("$r")
  else
    REPOS_TO_PROCESS+=("$OWNER/$r")
  fi
done

count=0
for repo in "${REPOS_TO_PROCESS[@]}"; do
  echo "=========================================="
  echo "Processing $repo"

  archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    continue
  fi

  # Attempt to enable dependency graph (and Dependabot alerts) via API
  if gh api "repos/$repo/vulnerability-alerts" --method PUT >/dev/null 2>&1; then
    echo "  -> Dependency graph enabled for $repo"
    count=$((count+1))
  else
    echo "  -> ERROR: Failed to enable dependency graph for $repo"
  fi
done

echo "=========================================="
echo "Done. Attempted to enable dependency graph for $count repositories."
