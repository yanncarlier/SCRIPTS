#!/usr/bin/env bash
# 04-gh-enable-push-protection.sh
# Summary: Enable secret scanning push protection for one or more repositories
# using the GitHub CLI (`gh`).
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to the target repositories
#  - Secret scanning must be enabled first (02-gh-enable-secret-scanning.sh)
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 04-gh-enable-push-protection.sh
#  DRY_RUN=1 bash 04-gh-enable-push-protection.sh
#  Default target: all public repos of OWNER.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

init_targets
log "Enabling push protection for ${#TARGETS[@]} repositories..."

for repo in "${TARGETS[@]}"; do
  repo_header "$repo"

  if is_archived "$repo"; then
    skipped "archived repository"
    continue
  fi

  secret_state="$(get_repo "$repo" '.security_and_analysis.secret_scanning.status // "unknown"')"
  if [[ "$secret_state" != "enabled" ]]; then
    printf '  %sWARNING:%s secret scanning is "%s" - push protection requires it first.\n' \
      "$C_YELLOW" "$C_OFF" "$secret_state"
    printf '         Run 02-gh-enable-secret-scanning.sh before this script.\n'
    skipped "secret scanning not enabled"
    continue
  fi

  state="$(get_repo "$repo" '.security_and_analysis.secret_scanning_push_protection.status // "unknown"')"
  if [[ "$state" == "enabled" ]]; then
    already "push protection"
    continue
  fi
  log "  current state: $state"

  step "push protection enabled" \
    gh api "repos/$repo" --method PATCH \
    -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
done

finish
