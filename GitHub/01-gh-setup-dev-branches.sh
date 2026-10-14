#!/usr/bin/env bash
# 01-gh-setup-dev-branches.sh
# Summary: Ensure a development branch (default: "dev") exists across one or
# more repositories using the GitHub CLI (`gh`).
#
# Prerequisites:
#  - GitHub CLI installed and authenticated: `gh auth login`
#  - Write access to the target repositories
#
# Usage:
#  OWNER="username" bash 01-gh-setup-dev-branches.sh
#  OWNER="username" REPOS="repo1,repo2" bash 01-gh-setup-dev-branches.sh
#  DRY_RUN=1 bash 01-gh-setup-dev-branches.sh
#
# Environment variables:
#  - OWNER:      GitHub user/org. Default: login of the authenticated account.
#  - DEV_BRANCH: branch to create. Default: "dev"
#  - REPOS:      comma-separated list ("repo1,other/repo2").
#                Default: all public repos of OWNER.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

DEV_BRANCH=${DEV_BRANCH:-dev}

init_targets
log "Ensuring branch '$DEV_BRANCH' exists in ${#TARGETS[@]} repositories..."

for repo in "${TARGETS[@]}"; do
  repo_header "$repo"

  if is_archived "$repo"; then
    skipped "archived repository"
    continue
  fi

  if api_status "repos/$repo/branches/$DEV_BRANCH"; then
    already "branch $DEV_BRANCH already exists"
    continue
  fi

  default_branch="$(get_repo "$repo" '.default_branch' main)"
  sha="$(gh api "repos/$repo/branches/$default_branch" --jq '.commit.sha' 2>/dev/null || true)"

  if [[ -z "$sha" ]]; then
    printf '  %sFAILED:%s could not resolve the head commit of %s\n' \
      "$C_RED" "$C_OFF" "$default_branch"
    C_FAIL=$((C_FAIL + 1))
    continue
  fi

  step "branch $DEV_BRANCH created from $default_branch" \
    gh api "repos/$repo/git/refs" \
    -f ref="refs/heads/$DEV_BRANCH" \
    -f sha="$sha"
done

finish
