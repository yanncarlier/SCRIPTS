#!/usr/bin/env bash
# 02-gh-enable-secret-scanning.sh
# Summary: Enable GitHub secret scanning (Secret Protection) for one or more
# repositories using the GitHub CLI (`gh`).
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to the target repositories
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 02-gh-enable-secret-scanning.sh
#  DRY_RUN=1 bash 02-gh-enable-secret-scanning.sh
#  Default target: all public repos of OWNER.
#
# Next step: 04-gh-enable-push-protection.sh (requires secret scanning first).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

init_targets
log "Enabling secret scanning for ${#TARGETS[@]} repositories..."

for repo in "${TARGETS[@]}"; do
  repo_header "$repo"

  if is_archived "$repo"; then
    skipped "archived repository"
    continue
  fi

  state="$(get_repo "$repo" '.security_and_analysis.secret_scanning.status // "unknown"')"
  if [[ "$state" == "enabled" ]]; then
    already "secret scanning"
    continue
  fi
  log "  current state: $state"

  step "secret scanning enabled" \
    gh api "repos/$repo" --method PATCH \
    -f 'security_and_analysis[secret_scanning][status]=enabled'
done

finish
