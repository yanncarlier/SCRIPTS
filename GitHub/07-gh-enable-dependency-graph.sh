#!/usr/bin/env bash
# 07-gh-enable-dependency-graph.sh
# Summary: Enable the dependency graph for one or more repositories using `gh`.
#
# Note: there is no dedicated REST endpoint for the dependency graph.
#       `PUT /repos/{owner}/{repo}/vulnerability-alerts` enables the dependency
#       graph AND Dependabot alerts together, which is why 07, 09 and 11 all
#       touch the same endpoint - with the built-in "already enabled" check
#       only the first of them actually performs a write.
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to the target repositories
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 07-gh-enable-dependency-graph.sh
#  DRY_RUN=1 bash 07-gh-enable-dependency-graph.sh
#  Default target: all public repos of OWNER.
#
# Next step: 08-gh-auto-dependency-submission.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

init_targets
log "Enabling dependency graph for ${#TARGETS[@]} repositories..."

for repo in "${TARGETS[@]}"; do
  repo_header "$repo"

  if is_archived "$repo"; then
    skipped "archived repository"
    continue
  fi

  if api_status "repos/$repo/vulnerability-alerts"; then
    already "dependency graph + dependency alerts"
    continue
  fi

  step "dependency graph + dependency alerts enabled" \
    gh api "repos/$repo/vulnerability-alerts" --method PUT
done

finish
