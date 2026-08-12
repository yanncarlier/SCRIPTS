#!/usr/bin/env bash
# 8-gh-auto-dependency-submission.sh
# Summary: Submit dependency snapshots to GitHub's dependency submission API
# for one or more repositories using the GitHub CLI (`gh`).
#
# By default the snapshot is auto-generated from the repository's
# requirements.txt (pinned dependencies only). Repos without a
# requirements.txt are skipped. To submit a custom snapshot to every repo,
# set SNAPSHOT_FILE to a valid snapshot JSON payload (see
# https://docs.github.com/en/rest/dependency-graph/dependency-submission).
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin or write access to target repositories
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" bash 8-gh-auto-dependency-submission.sh
#  REPOS="repo1" OWNER="username" SNAPSHOT_FILE="./snapshot.json" bash 8-gh-auto-dependency-submission.sh
#  If REPOS is empty, public repos for OWNER are fetched.

set -euo pipefail

OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}
SNAPSHOT_FILE=${SNAPSHOT_FILE:-""}
REPOS_TO_PROCESS=()

if [ -z "$REPOS" ]; then
  echo "  (fetching public repositories for $OWNER)"
  mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public)
  if [ "${#REPOS[@]}" -eq 0 ]; then
    echo "ERROR: No public repositories found for $OWNER."
    exit 1
  fi
fi

if [ -n "$SNAPSHOT_FILE" ] && [ ! -f "$SNAPSHOT_FILE" ]; then
  echo "ERROR: Snapshot file not found: $SNAPSHOT_FILE"
  exit 1
fi

# Parse comma-separated REPOS and normalize
IFS=',' read -r -a REPOS_ARRAY <<< "$REPOS"
for r in "${REPOS_ARRAY[@]}"; do
  r="${r// /}"
  if [[ "$r" == *"/"* ]]; then
    REPOS_TO_PROCESS+=("$r")
  else
    REPOS_TO_PROCESS+=("$OWNER/$r")
  fi
done

# Build a valid snapshot payload from a requirements.txt file.
# Usage: build_snapshot <requirements-file> <sha> <ref> <output-json>
build_snapshot() {
  python3 - "$1" "$2" "$3" "$4" <<'PYEOF'
import json
import re
import sys
from datetime import datetime, timezone

req_file, sha, ref, out_file = sys.argv[1:5]
resolved = {}
with open(req_file) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("-"):
            continue
        m = re.match(r"^([A-Za-z0-9_.\-\[\]]+)\s*(==|>=|<=|~=|!=)\s*([^\s;]+)", line)
        if not m:
            continue
        name, op, ver = m.group(1), m.group(2), m.group(3)
        name = name.split("[")[0].lower()
        if op == "==":
            resolved[name] = f"pkg:pypi/{name}@{ver}"

if not resolved:
    sys.exit(1)

snapshot = {
    "version": 0,
    "sha": sha,
    "ref": ref,
    "job": {"correlator": "gh-auto-dependency-submission", "id": "snapshot-run-1"},
    "detector": {
        "name": "gh-dependency-submission-detector",
        "version": "1.0.0",
        "url": "https://github.com/yanncarlier/scripts",
    },
    "scanned": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "manifests": {
        "requirements.txt": {
            "name": "requirements.txt",
            "file": {"source_location": "requirements.txt"},
            "resolved": {name: {"package_url": purl} for name, purl in sorted(resolved.items())},
        }
    },
}

with open(out_file, "w") as f:
    json.dump(snapshot, f, indent=2)
PYEOF
}

count=0
skipped=0
for repo in "${REPOS_TO_PROCESS[@]}"; do
  repo_name="${repo#*/}"
  echo "=========================================="
  echo "Processing $repo"

  # Skip archived repositories
  archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    skipped=$((skipped+1))
    continue
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  if [ -n "$SNAPSHOT_FILE" ]; then
    snapshot="$SNAPSHOT_FILE"
  else
    # Auto-generate snapshot from requirements.txt on the default branch
    branch=$(gh api "repos/$repo" --jq '.default_branch')
    if ! gh api "repos/$repo/contents/requirements.txt" \
        -H "Accept: application/vnd.github.raw+json" > "$tmp_dir/requirements.txt" 2>/dev/null; then
      echo "  -> Skipping: no requirements.txt found (auto-generation requires a manifest)"
      skipped=$((skipped+1))
      continue
    fi

    sha=$(gh api "repos/$repo/commits/$branch" --jq '.sha')
    snapshot="$tmp_dir/snapshot.json"
    if ! build_snapshot "$tmp_dir/requirements.txt" "$sha" "refs/heads/$branch" "$snapshot"; then
      echo "  -> Skipping: requirements.txt has no pinned (==) dependencies"
      skipped=$((skipped+1))
      continue
    fi

    n_deps=$(python3 -c "import json,sys; print(len(json.load(open('$snapshot'))['manifests']['requirements.txt']['resolved']))")
    echo "  -> Snapshot generated for $repo_name ($n_deps pinned deps, sha $sha)"
  fi

  # POST the snapshot JSON to the dependency submission endpoint
  if gh api "repos/$repo/dependency-graph/snapshots" --method POST --input "$snapshot" --jq '.result + ": " + .message' 2>/dev/null; then
    count=$((count+1))
  else
    echo "  -> ERROR: Failed to submit snapshot for $repo"
  fi
done

echo "=========================================="
echo "Done. Snapshot submitted for $count repositories, skipped $skipped."