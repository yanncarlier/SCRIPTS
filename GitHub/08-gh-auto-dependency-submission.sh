#!/usr/bin/env bash
# 8-gh-auto-dependency-submission.sh
# Summary: Submit dependency snapshots to GitHub's dependency submission API
# for one or more repositories using the GitHub CLI (`gh`).
#
# By default the snapshot is auto-generated from the first supported manifest
# found in the repo root:
#   - package-lock.json  -> pkg:npm (lockfile v2/v3)
#   - Cargo.lock         -> pkg:cargo
#   - pubspec.lock       -> pkg:pub (Flutter/Dart)
#   - requirements.txt   -> pkg:pypi (pinned == only)
#   - pyproject.toml     -> pkg:pypi (pinned == only)
# Repos with none of these are skipped. To submit a custom snapshot to every
# repo, set SNAPSHOT_FILE to a valid snapshot JSON payload (see
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
  REPOS=$(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner' --visibility public | paste -sd, -)
  if [ -z "$REPOS" ]; then
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

# Build a valid snapshot payload from downloaded manifests in a directory.
# Usage: build_snapshot <manifest-dir> <sha> <ref> <output-json>
build_snapshot() {
  python3 - "$1" "$2" "$3" "$4" <<'PYEOF'
import json
import os
import re
import sys
from datetime import datetime, timezone

manifest_dir, sha, ref, out_file = sys.argv[1:5]

def parse_requirements(path):
    resolved = {}
    with open(path) as f:
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
    return resolved

def parse_pyproject(path):
    resolved = {}
    with open(path) as f:
        text = f.read()
    for m in re.finditer(r"^\s*[\"']([A-Za-z0-9_.\-\[\]]+)(?:==|===)\s*([0-9][^\s\"']*)[\"']?\s*,?\s*$", text, re.M):
        name, ver = m.group(1), m.group(2)
        resolved[name.split("[")[0].lower()] = f"pkg:pypi/{name.split('[')[0].lower()}@{ver}"
    return resolved

def parse_cargo_lock(path):
    resolved = {}
    with open(path) as f:
        text = f.read()
    for block in re.finditer(r"\[\[package\]\](.*?)(?=\n\[\[package\]\]|\Z)", text, re.S):
        name = re.search(r'^name = "([^"]+)"', block.group(1), re.M)
        ver = re.search(r'^version = "([^"]+)"', block.group(1), re.M)
        if name and ver:
            resolved[name.group(1)] = f"pkg:cargo/{name.group(1)}@{ver.group(1)}"
    return resolved

def parse_package_lock(path):
    resolved = {}
    with open(path) as f:
        data = json.load(f)
    packages = data.get("packages") or {}
    for key, info in packages.items():
        if not key or not isinstance(info, dict):
            continue
        name = info.get("name") or key.rstrip("/").split("/")[-1]
        ver = info.get("version")
        if name and ver:
            resolved[name] = f"pkg:npm/{name}@{ver}"
    if not resolved:
        for name, info in (data.get("dependencies") or {}).items():
            ver = info.get("version") if isinstance(info, dict) else None
            if ver:
                resolved[name] = f"pkg:npm/{name}@{ver}"
    return resolved

def parse_pubspec_lock(path):
    resolved = {}
    with open(path) as f:
        text = f.read()
    m = re.search(r"^packages:$", text, re.M)
    if not m:
        return resolved
    body = text[m.end():]
    for block in re.finditer(r"^  (\S+):\s*\n(.*?)(?=^  \S+:\s*\n|\Z)", body, re.M | re.S):
        name, rest = block.group(1), block.group(2)
        ver = re.search(r'^    version: "([^"]+)"', rest, re.M)
        if ver:
            resolved[name] = f"pkg:pub/{name}@{ver.group(1)}"
    return resolved

PARSERS = [
    ("package-lock.json", "package-lock.json", parse_package_lock),
    ("Cargo.lock", "Cargo.lock", parse_cargo_lock),
    ("pubspec.lock", "pubspec.lock", parse_pubspec_lock),
    ("requirements.txt", "requirements.txt", parse_requirements),
    ("pyproject.toml", "pyproject.toml", parse_pyproject),
]

manifests = {}
for filename, label, parser in PARSERS:
    path = os.path.join(manifest_dir, filename)
    if not os.path.isfile(path):
        continue
    resolved = parser(path)
    if resolved:
        manifests[label] = {
            "name": label,
            "file": {"source_location": filename},
            "resolved": {n: {"package_url": p} for n, p in sorted(resolved.items())},
        }

if not manifests:
    sys.exit(2)

snapshot = {
    "version": 0,
    "sha": sha,
    "ref": ref,
    "job": {"correlator": "gh-auto-dependency-submission", "id": "snapshot-run-1"},
    "detector": {
        "name": "gh-dependency-submission-detector",
        "version": "2.0.0",
        "url": "https://github.com/yanncarlier/scripts",
    },
    "scanned": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "manifests": manifests,
}

with open(out_file, "w") as f:
    json.dump(snapshot, f, indent=2)
PYEOF
}

count=0
skipped=0
for repo in "${REPOS_TO_PROCESS[@]}"; do
  echo "=========================================="
  echo "Processing $repo"

  # Skip archived repositories
  archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    skipped=$((skipped+1))
    continue
  fi

  if [ -n "$SNAPSHOT_FILE" ]; then
    snapshot="$SNAPSHOT_FILE"
  else
    branch=$(gh api "repos/$repo" --jq '.default_branch')
    sha=$(gh api "repos/$repo/commits/$branch" --jq '.sha')

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    # Download supported manifests from the repo root
    found=0
    for mf in package-lock.json Cargo.lock pubspec.lock requirements.txt pyproject.toml; do
      if gh api "repos/$repo/contents/$mf" \
          -H "Accept: application/vnd.github.raw+json" > "$tmp_dir/$mf" 2>/dev/null; then
        found=1
      fi
    done

    if [ "$found" -eq 0 ]; then
      echo "  -> Skipping: no supported manifest found (package-lock.json, Cargo.lock, pubspec.lock, requirements.txt, pyproject.toml)"
      skipped=$((skipped+1))
      continue
    fi

    snapshot="$tmp_dir/snapshot.json"
    if ! build_snapshot "$tmp_dir" "$sha" "refs/heads/$branch" "$snapshot"; then
      echo "  -> Skipping: no resolvable (pinned) dependencies found in manifests"
      skipped=$((skipped+1))
      continue
    fi

    manifest_names=$(python3 -c "import json,sys; print(', '.join(sorted(json.load(open('$snapshot'))['manifests'].keys())))")
    n_deps=$(python3 -c "import json,sys; print(sum(len(m['resolved']) for m in json.load(open('$snapshot'))['manifests'].values()))")
    echo "  -> Snapshot generated for $repo ($n_deps deps from $manifest_names, sha $(echo "$sha" | cut -c1-8))"
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