#!/usr/bin/env bash
# 09-gh-enable-dependabot-alerts.sh
# Summary: Enable Dependabot alerts (vulnerable dependency alerts) for one or
# more repositories using the GitHub CLI (`gh`).
#
# Note: `PUT /repos/{owner}/{repo}/vulnerability-alerts` is the single toggle
#       behind Dependabot alerts, the dependency graph (07) and the malware
#       alert coverage (11). Scripts 07, 09 and 11 check the current state
#       first, so after one of them has run the others report "already".
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to the target repositories
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 09-gh-enable-dependabot-alerts.sh
#  DRY_RUN=1 bash 09-gh-enable-dependabot-alerts.sh
#  Default target: all public repos of OWNER.
#
# Related: 10-gh-enable-dependabot-security-updates.sh (auto-fix PRs)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

init_targets
log "Enabling Dependabot alerts for ${#TARGETS[@]} repositories..."

for repo in "${TARGETS[@]}"; do
  repo_header "$repo"

  if is_archived "$repo"; then
    skipped "archived repository"
    continue
  fi

  if api_status "repos/$repo/vulnerability-alerts"; then
    already "Dependabot alerts"
    continue
  fi

  step "Dependabot alerts enabled" \
    gh api "repos/$repo/vulnerability-alerts" --method PUT
done

finish
