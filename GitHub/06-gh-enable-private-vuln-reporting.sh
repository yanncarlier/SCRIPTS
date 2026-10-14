#!/usr/bin/env bash
# 06-gh-enable-private-vuln-reporting.sh
# Summary: Enable private vulnerability reporting for one or more repositories
# using the GitHub CLI (`gh`).
#
# With this on, people can report vulnerabilities privately through the
# repository's Security tab instead of opening a public issue.
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to the target repositories
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 06-gh-enable-private-vuln-reporting.sh
#  DRY_RUN=1 bash 06-gh-enable-private-vuln-reporting.sh
#  Default target: all public repos of OWNER.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

init_targets
log "Enabling private vulnerability reporting for ${#TARGETS[@]} repositories..."

for repo in "${TARGETS[@]}"; do
  repo_header "$repo"

  if is_archived "$repo"; then
    skipped "archived repository"
    continue
  fi

  state="$(gh api "repos/$repo/private-vulnerability-reporting" --jq '.enabled' 2>/dev/null || echo unknown)"
  if [[ "$state" == "true" ]]; then
    already "private vulnerability reporting"
    continue
  fi
  log "  current state: $state"

  step "private vulnerability reporting enabled" \
    gh api "repos/$repo/private-vulnerability-reporting" --method PUT -f enabled=true
done

finish
