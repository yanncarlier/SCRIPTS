#!/usr/bin/env bash
# 12-gh-enable-dependabot-grouped-security-updates.sh
# Summary: Enable grouped Dependabot security updates for repositories by
# updating existing `.github/dependabot.yml` files.
#
# Why this approach:
#  - As of 2026-04-21, GitHub does not expose a public REST/GraphQL repository
#    toggle for "Grouped security updates".
#  - GitHub supports grouped security updates through `dependabot.yml` rules.
#
# What this script does per repository:
#  1) Ensures prerequisites are enabled:
#     - Dependency graph
#     - Dependabot alerts
#     - Dependabot security updates
#  2) Reads `.github/dependabot.yml` (must already exist)
#  3) Adds/updates a security group rule on each `updates` entry:
#       groups:
#         grouped-security-updates:
#           applies-to: security-updates
#           patterns: ["*"]
#  4) Commits the updated `dependabot.yml` directly to the default branch
#
# Prerequisites:
#  - `gh` installed and authenticated: `gh auth login`
#  - Admin access to target repositories
#  - `python3` with PyYAML available (`import yaml`)
#
# Usage:
#  REPOS="repo1,repo2" OWNER="username" \
#  bash 12-gh-enable-dependabot-grouped-security-updates.sh
#
# Optional env vars:
#  AUTO_CREATE_DEPENDABOT_YML=true|false   (default: true)
#  DEPENDABOT_SCHEDULE_INTERVAL=daily|weekly|monthly (default: weekly)

set -euo pipefail

OWNER=${OWNER:-"username"}
REPOS=${REPOS:-""}
REPOS_TO_PROCESS=()
AUTO_CREATE_DEPENDABOT_YML=${AUTO_CREATE_DEPENDABOT_YML:-"true"}
DEPENDABOT_SCHEDULE_INTERVAL=${DEPENDABOT_SCHEDULE_INTERVAL:-"weekly"}

echo "Preparing to enable grouped Dependabot security updates for $OWNER..."

if [ -z "${REPOS}" ]; then
  echo "ERROR: No repositories specified."
  echo "Provide a comma-separated list via the REPOS variable:"
  echo "  REPOS=\"repo1,repo2\" OWNER=\"username\" bash 12-gh-enable-dependabot-grouped-security-updates.sh"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required."
  exit 1
fi

if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "ERROR: PyYAML is required (python3 module 'yaml')."
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

count_changed=0
count_skipped=0
count_failed=0

for repo in "${REPOS_TO_PROCESS[@]}"; do
  echo "=========================================="
  echo "Processing $repo"

  archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "false")
  if [ "$archived" = "true" ]; then
    echo "  -> Skipping archived repository"
    count_skipped=$((count_skipped+1))
    continue
  fi

  # Prerequisites for grouped security updates
  gh api "repos/$repo/dependency-graph" --method PUT -f enabled=true >/dev/null 2>&1 || true
  gh api "repos/$repo/vulnerability-alerts" --method PUT >/dev/null 2>&1 || true
  gh api "repos/$repo/automated-security-fixes" --method PUT >/dev/null 2>&1 || true

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  raw_json="$tmpdir/content.json"
  decoded_file="$tmpdir/dependabot.yml"
  updated_file="$tmpdir/dependabot.updated.yml"

  if ! gh api "repos/$repo/contents/.github/dependabot.yml" > "$raw_json" 2>/dev/null; then
    if [ "$AUTO_CREATE_DEPENDABOT_YML" != "true" ]; then
      echo "  -> Skipping: .github/dependabot.yml not found (AUTO_CREATE_DEPENDABOT_YML=false)"
      count_skipped=$((count_skipped+1))
      rm -rf "$tmpdir"
      trap - EXIT
      continue
    fi

    echo "  -> .github/dependabot.yml not found; generating one from detected manifests"
    paths_file="$tmpdir/repo-paths.txt"
    generated_file="$tmpdir/dependabot.generated.yml"

    default_branch=$(gh api "repos/$repo" --jq '.default_branch' 2>/dev/null || echo "main")
    if ! gh api "repos/$repo/git/trees/$default_branch?recursive=1" --jq '.tree[].path' > "$paths_file" 2>/dev/null; then
      echo "  -> ERROR: Failed to inspect repository tree for auto-generation"
      count_failed=$((count_failed+1))
      rm -rf "$tmpdir"
      trap - EXIT
      continue
    fi

    gen_status="$(python3 - "$paths_file" "$generated_file" "$DEPENDABOT_SCHEDULE_INTERVAL" <<'PY'
import os
import sys
import yaml

paths_file, out_file, interval = sys.argv[1], sys.argv[2], sys.argv[3]

with open(paths_file, "r", encoding="utf-8") as f:
    paths = [line.strip() for line in f if line.strip()]

ecos = set()

def to_dir(path: str) -> str:
    d = os.path.dirname(path)
    return "/" if d in ("", ".") else f"/{d}"

for p in paths:
    base = os.path.basename(p)
    d = to_dir(p)
    lp = p.lower()

    if base == "package.json":
        ecos.add(("npm", d))
    if base in {"requirements.txt", "requirements-dev.txt", "pyproject.toml", "pipfile", "setup.py"}:
        ecos.add(("pip", d))
    if base == "go.mod":
        ecos.add(("gomod", d))
    if base == "cargo.toml":
        ecos.add(("cargo", d))
    if base == "composer.json":
        ecos.add(("composer", d))
    if base == "pubspec.yaml":
        ecos.add(("pub", d))
    if base == "pom.xml":
        ecos.add(("maven", d))
    if base in {"build.gradle", "build.gradle.kts"}:
        ecos.add(("gradle", d))
    if base in {"packages.config"} or p.endswith((".csproj", ".vbproj", ".fsproj", ".sln")):
        ecos.add(("nuget", d))
    if lp.startswith(".github/workflows/") and lp.endswith((".yml", ".yaml")):
        ecos.add(("github-actions", "/"))
    if base == "Dockerfile":
        ecos.add(("docker", d))

if not ecos:
    print("no_ecosystems")
    raise SystemExit(0)

updates = []
for eco, directory in sorted(ecos):
    updates.append({
        "package-ecosystem": eco,
        "directory": directory,
        "schedule": {"interval": interval},
        "groups": {
            "grouped-security-updates": {
                "applies-to": "security-updates",
                "patterns": ["*"],
            }
        },
    })

doc = {"version": 2, "updates": updates}
with open(out_file, "w", encoding="utf-8") as f:
    yaml.safe_dump(doc, f, sort_keys=False, default_flow_style=False)

print("generated")
PY
)"

    if [ "$gen_status" = "no_ecosystems" ]; then
      echo "  -> Skipping: no supported manifest/workflow files found for auto-generation"
      count_skipped=$((count_skipped+1))
      rm -rf "$tmpdir"
      trap - EXIT
      continue
    fi

    if [ "$gen_status" != "generated" ]; then
      echo "  -> ERROR: Failed to auto-generate dependabot.yml"
      count_failed=$((count_failed+1))
      rm -rf "$tmpdir"
      trap - EXIT
      continue
    fi

    new_content=$(base64 -w0 "$generated_file")
    if gh api "repos/$repo/contents/.github/dependabot.yml" \
        --method PUT \
        -f message="chore(dependabot): add grouped security updates config" \
        -f content="$new_content" >/dev/null 2>&1; then
      echo "  -> Created .github/dependabot.yml with grouped security updates rules"
      count_changed=$((count_changed+1))
      rm -rf "$tmpdir"
      trap - EXIT
      continue
    else
      echo "  -> ERROR: Failed to create .github/dependabot.yml"
      count_failed=$((count_failed+1))
      rm -rf "$tmpdir"
      trap - EXIT
      continue
    fi
  fi

  sha=$(jq -r '.sha // empty' "$raw_json")
  content=$(jq -r '.content // empty' "$raw_json" | tr -d '\n')
  if [ -z "$sha" ] || [ -z "$content" ]; then
    echo "  -> ERROR: Unable to read .github/dependabot.yml content/sha"
    count_failed=$((count_failed+1))
    rm -rf "$tmpdir"
    trap - EXIT
    continue
  fi

  printf '%s' "$content" | base64 --decode > "$decoded_file"

  py_status="$(python3 - "$decoded_file" "$updated_file" <<'PY'
import sys
import yaml

in_path, out_path = sys.argv[1], sys.argv[2]

with open(in_path, "r", encoding="utf-8") as f:
    raw = f.read()

data = yaml.safe_load(raw)
if not isinstance(data, dict):
    print("invalid")
    sys.exit(0)

updates = data.get("updates")
if not isinstance(updates, list) or len(updates) == 0:
    print("no_updates")
    sys.exit(0)

changed = False
for u in updates:
    if not isinstance(u, dict):
        continue
    groups = u.get("groups")
    if not isinstance(groups, dict):
        groups = {}
        u["groups"] = groups

    target = groups.get("grouped-security-updates")
    desired = {
        "applies-to": "security-updates",
        "patterns": ["*"],
    }
    if target != desired:
        groups["grouped-security-updates"] = desired
        changed = True

if not changed:
    print("no_change")
    sys.exit(0)

with open(out_path, "w", encoding="utf-8") as f:
    yaml.safe_dump(data, f, sort_keys=False, default_flow_style=False)

print("changed")
PY
)"

  if [ "$py_status" = "invalid" ]; then
    echo "  -> ERROR: dependabot.yml is not a valid YAML mapping"
    count_failed=$((count_failed+1))
    rm -rf "$tmpdir"
    trap - EXIT
    continue
  fi

  if [ "$py_status" = "no_updates" ]; then
    echo "  -> Skipping: dependabot.yml has no 'updates' entries"
    count_skipped=$((count_skipped+1))
    rm -rf "$tmpdir"
    trap - EXIT
    continue
  fi

  if [ "$py_status" = "no_change" ]; then
    echo "  -> Already configured for grouped security updates"
    count_skipped=$((count_skipped+1))
    rm -rf "$tmpdir"
    trap - EXIT
    continue
  fi

  new_content=$(base64 -w0 "$updated_file")
  if gh api "repos/$repo/contents/.github/dependabot.yml" \
      --method PUT \
      -f message="chore(dependabot): enable grouped security updates" \
      -f content="$new_content" \
      -f sha="$sha" >/dev/null 2>&1; then
    echo "  -> Updated .github/dependabot.yml and enabled grouped security updates rules"
    count_changed=$((count_changed+1))
  else
    echo "  -> ERROR: Failed to update .github/dependabot.yml"
    count_failed=$((count_failed+1))
  fi

  rm -rf "$tmpdir"
  trap - EXIT
done

echo "=========================================="
echo "Done."
echo "  Changed: $count_changed"
echo "  Skipped: $count_skipped"
echo "  Failed : $count_failed"
