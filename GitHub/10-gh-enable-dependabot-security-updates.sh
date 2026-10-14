#!/usr/bin/env bash
# 10-gh-enable-dependabot-security-updates.sh
# Summary: Enable Dependabot security updates (automated upgrade PRs) for one
# or more repositories using the GitHub CLI (`gh`).
#
# This is a different toggle from Dependabot alerts: alerts only notify you
# about vulnerable dependencies, security updates actually open the PRs that
# bump them.
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to the target repositories
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 10-gh-enable-dependabot-security-updates.sh
#  DRY_RUN=1 bash 10-gh-enable-dependabot-security-updates.sh
#  Default target: all public repos of OWNER.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

init_targets
log "Enabling Dependabot security updates for ${#TARGETS[@]} repositories..."

for repo in "${TARGETS[@]}"; do
  repo_header "$repo"

  if is_archived "$repo"; then
    skipped "archived repository"
    continue
  fi

  state="$(gh api "repos/$repo/automated-security-fixes" --jq '.enabled // false' 2>/dev/null || echo false)"
  if [[ "$state" == "true" ]]; then
    already "Dependabot security updates"
    continue
  fi
  log "  current state: enabled=$state"

  step "Dependabot security updates enabled" \
    gh api "repos/$repo/automated-security-fixes" --method PUT
done

finish
