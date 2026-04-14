#!/usr/bin/env bash
# 00-gh-bootstrap-new-repo.sh
# Summary: Run GitHub repository startup scripts in the recommended order.
# Usage:
#   OWNER="my-org" REPOS="repo1,repo2" bash 00-gh-bootstrap-new-repo.sh
#   OWNER="my-org" REPOS="repo1,repo2" SNAPSHOT_FILE="./08-test-snapshot.json" bash 00-gh-bootstrap-new-repo.sh
# Notes:
#   - If REPOS is empty, the script fetches public repos for OWNER.
#   - SNAPSHOT_FILE is optional and only used for dependency snapshot submission.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}
SNAPSHOT_FILE=${SNAPSHOT_FILE:-""}

export OWNER

if [ -z "$REPOS" ]; then
  echo "REPOS not set. Fetching public repositories for OWNER=$OWNER..."
  mapfile -t repo_names < <(gh repo list "$OWNER" --limit 1000 --json name -q '.[].name' --visibility public)
  if [ ${#repo_names[@]} -eq 0 ]; then
    echo "ERROR: No public repositories found for OWNER=$OWNER or fetch failed."
    exit 1
  fi
  REPOS=$(IFS=,; echo "${repo_names[*]}")
  echo "Resolved REPOS for bootstrap: $REPOS"
fi

export REPOS

run_script() {
  local script_name="$1"
  echo
  echo "=================================================="
  echo "Running $script_name"
  bash "$script_dir/$script_name"
  echo "Completed $script_name"
}

# Bootstrapping order
run_script "01-gh-setup-dev-branches.sh"
run_script "07-gh-enable-dependency-graph.sh"

if [ -n "$SNAPSHOT_FILE" ]; then
  export SNAPSHOT_FILE
  run_script "08-gh-auto-dependency-submission.sh"
else
  echo
  echo "Skipping dependency snapshot submission because SNAPSHOT_FILE is not set."
fi

run_script "04-gh-enable-secret-scanning.sh"
run_script "02-gh-enable-push-protection.sh"
run_script "06-gh-enable-private-vuln-reporting.sh"
run_script "09-gh-enable-dependabot-alerts.sh"
run_script "10-gh-enable-dependabot-security-updates.sh"
run_script "03-gh-setup-rulesets.sh"
run_script "05-gh-copilot-code-review.sh"

echo
echo "=================================================="
echo "Bootstrap complete. Review the output above for any warnings or errors."
