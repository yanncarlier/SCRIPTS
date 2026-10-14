#!/usr/bin/env bash
# lib/common.sh
# Summary: Shared helpers for the GitHub security scripts (00-99).
#
# Source it from a script that lives in the repository root:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=lib/common.sh
#   . "$SCRIPT_DIR/lib/common.sh"
#
# Environment variables honoured by every script:
#   OWNER      GitHub user or organization.
#              Default: the login returned by `gh api user`.
#   REPOS      Comma separated list: "repo1,other-owner/repo2".
#              Default: every public, non-fork repository of OWNER.
#   DRY_RUN=1  Print mutating calls instead of performing them.
#   VERBOSE=1  Print every gh command before it runs.
#   NO_COLOR=1 Disable ANSI colors (colors are also disabled when not a TTY).

if [[ -n "${_GHSEC_LIB_LOADED:-}" ]]; then
  return 0
fi
_GHSEC_LIB_LOADED=1

set -euo pipefail

# === OUTPUT ==============================================================

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_DIM=''; C_OFF=''
fi

log() { printf '%s\n' "$*"; }
die() { printf '%sERROR:%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

# === COUNTERS ============================================================
# C_OK       mutating calls that were applied
# C_ALREADY  repositories that already had the setting
# C_SKIP     repositories skipped (archived, no manifest, ...)
# C_FAIL     mutating calls that failed (drives the exit code)

C_OK=0
C_ALREADY=0
C_SKIP=0
C_FAIL=0

DRY_RUN=${DRY_RUN:-0}
VERBOSE=${VERBOSE:-0}
OWNER=${OWNER:-}
REPOS=${REPOS:-}
TARGETS=()

already() { printf '  %s- already: %s%s\n' "$C_DIM" "$*" "$C_OFF"; C_ALREADY=$((C_ALREADY + 1)); }
skipped() { printf '  %s- skipped: %s%s\n' "$C_YELLOW" "$*" "$C_OFF"; C_SKIP=$((C_SKIP + 1)); }

# Print the per-repository banner used by every loop.
repo_header() {
  printf '%s==========================================%s\n' "$C_DIM" "$C_OFF"
  printf 'Processing %s\n' "$1"
}

# Print the final tally. Exits 1 when any mutating call failed.
finish() {
  printf '%s==================================================%s\n' "$C_DIM" "$C_OFF"
  printf 'Summary: %s%d applied%s, %d already in place, %d skipped, ' \
    "$C_GREEN" "$C_OK" "$C_OFF" "$C_ALREADY" "$C_SKIP"
  if ((C_FAIL > 0)); then
    printf '%s%d failed%s\n' "$C_RED" "$C_FAIL" "$C_OFF"
    exit 1
  fi
  printf '0 failed\n'
  exit 0
}

# === PREFLIGHT ===========================================================

require_gh() {
  command -v gh >/dev/null 2>&1 ||
    die "GitHub CLI (gh) not found - install it from https://cli.github.com"
  gh auth status >/dev/null 2>&1 ||
    die "gh is not authenticated - run: gh auth login"
}

# === TARGET REPOSITORIES =================================================

# Resolve OWNER (if needed) and fill the TARGETS array from REPOS or by
# listing OWNER's public repositories (forks excluded).
init_targets() {
  require_gh

  if [[ -z "$OWNER" ]]; then
    OWNER="$(gh api user -q .login 2>/dev/null || true)"
    [[ -n "$OWNER" ]] || die "OWNER is not set and could not be derived from gh"
    log "OWNER not set - using the authenticated account: $OWNER"
  fi

  TARGETS=()

  if [[ -n "$REPOS" ]]; then
    log "Using repositories from REPOS ($OWNER)"
    local r
    local -a items
    IFS=',' read -r -a items <<<"$REPOS"
    for r in "${items[@]}"; do
      r="${r// /}"
      [[ -z "$r" ]] && continue
      if [[ "$r" == */* ]]; then
        TARGETS+=("$r")
      else
        TARGETS+=("$OWNER/$r")
      fi
    done
  else
    log "Fetching public repositories for $OWNER (forks excluded)..."
    mapfile -t TARGETS < <(
      gh repo list "$OWNER" --limit 1000 --json nameWithOwner,isFork \
        --visibility public \
        -q '.[] | select(.isFork | not) | .nameWithOwner'
    )
  fi

  ((${#TARGETS[@]} > 0)) || die "No repositories found for $OWNER"
  log "Found ${#TARGETS[@]} repositories to process."
}

# === API HELPERS =========================================================

# get_repo <owner/repo> <jq expression> [default]
# Reads a field from GET /repos/{repo}; prints <default> when it is absent
# or the call fails (so a missing field never aborts the script).
get_repo() {
  local repo=$1 expr=$2 def=${3:-}
  gh api "repos/$repo" --jq "$expr" 2>/dev/null || printf '%s' "$def"
}

# is_archived <owner/repo>  -> 0 when the repository is archived
is_archived() {
  [[ "$(get_repo "$1" '.archived' false)" == "true" ]]
}

# api_status <gh api arguments...>  -> 0 when the call returns 2xx
api_status() {
  gh api "$@" >/dev/null 2>&1
}

# step <description> <command...>
# Runs a mutating command, retries transient API errors and keeps a tally.
# Never returns non-zero so one failing repository cannot abort the loop.
step() {
  local desc=$1
  shift

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  %s> DRY-RUN:%s %s\n' "$C_BLUE" "$C_OFF" "$desc"
    C_OK=$((C_OK + 1))
    return 0
  fi

  if [[ "$VERBOSE" == "1" ]]; then
    printf '  %s$ %s%s\n' "$C_DIM" "$*" "$C_OFF"
  fi

  local out rc attempt=1 delay=5
  while true; do
    if out="$("$@" 2>&1)"; then
      rc=0
    else
      rc=$?
    fi
    ((rc == 0)) && break
    if ((attempt < 4)) &&
      grep -qiE 'rate.?limit|abuse|HTTP 429|HTTP 50[023]|connection reset|EOF' <<<"$out"; then
      printf '  %s- transient API error, retrying in %ss...%s\n' "$C_YELLOW" "$delay" "$C_OFF"
      sleep "$delay"
      delay=$((delay * 2))
      attempt=$((attempt + 1))
      continue
    fi
    break
  done

  if ((rc == 0)); then
    printf '  %sOK:%s %s\n' "$C_GREEN" "$C_OFF" "$desc"
    C_OK=$((C_OK + 1))
    return 0
  fi

  printf '  %sFAILED:%s %s\n' "$C_RED" "$C_OFF" "$desc"
  printf '    %s\n' "$out"
  C_FAIL=$((C_FAIL + 1))
  return 0
}

# mk_payload_file  -> prints a private temp file path, cleaned on exit
mk_payload_file() {
  local f
  f="$(mktemp "${TMPDIR:-/tmp}/ghsec-payload.XXXXXX")"
  printf '%s' "$f"
}
