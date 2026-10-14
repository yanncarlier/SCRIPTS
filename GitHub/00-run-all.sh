#!/usr/bin/env bash
# 00-run-all.sh
# Summary: Run every GitHub security setup script (01 to 11) in order,
#          then run the read-only audit (99) to verify the result.
#
# Unlike the individual scripts this runner does NOT stop at the first
# failure: every step runs, and a pass/fail summary is printed at the end.
#
# Usage:
#   OWNER="username" REPOS="repo1,repo2" bash 00-run-all.sh
#   OWNER="username" bash 00-run-all.sh
#   bash 00-run-all.sh 02 04            # only these steps
#   DRY_RUN=1 bash 00-run-all.sh        # show what would change
#
# Environment:
#   OWNER, REPOS   passed through to every script
#   DRY_RUN=1      passed through to every script
#   AUDIT=0        skip the final audit step (default: 1)
#   ONLY="02,04"   same as passing step numbers as arguments

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -A SCRIPTS=(
  [01]="01-gh-setup-dev-branches.sh"
  [02]="02-gh-enable-secret-scanning.sh"
  [03]="03-gh-setup-rulesets.sh"
  [04]="04-gh-enable-push-protection.sh"
  [05]="05-gh-copilot-code-review.sh"
  [06]="06-gh-enable-private-vuln-reporting.sh"
  [07]="07-gh-enable-dependency-graph.sh"
  [08]="08-gh-auto-dependency-submission.sh"
  [09]="09-gh-enable-dependabot-alerts.sh"
  [10]="10-gh-enable-dependabot-security-updates.sh"
  [11]="11-gh-enable-dependabot-malware-alerts.sh"
  [99]="99-gh-audit-security.sh"
)

ORDER=(01 02 03 04 05 06 07 08 09 10 11)

# === SELECT STEPS ========================================================

SELECT=("$@")

if [[ -n "${ONLY:-}" ]]; then
  only_items="${ONLY//,/ }"
  # shellcheck disable=SC2206
  SELECT=($only_items)
fi

if [[ ${#SELECT[@]} -eq 0 ]]; then
  SELECT=("${ORDER[@]}")
  if [[ "${AUDIT:-1}" == "1" ]]; then
    SELECT+=(99)
  fi
fi

# === RUN =================================================================

echo "Running ${#SELECT[@]} step(s)..."
echo "  OWNER=${OWNER:-<derived from gh>}"
echo "  REPOS=${REPOS:-<all public repos of OWNER>}"
echo "  DRY_RUN=${DRY_RUN:-0}"
echo "=================================================="

declare -A RESULT
failed=0
hard_failed=0

for n in "${SELECT[@]}"; do
  n="$(printf '%02d' "$((10#$n))" 2>/dev/null || printf '%s' "$n")"

  if [[ -z "${SCRIPTS[$n]:-}" ]]; then
    echo ""
    echo "Warning: unknown step '$n' - skipping"
    RESULT[$n]="UNKNOWN"
    failed=1
    continue
  fi

  script="${SCRIPT_DIR}/${SCRIPTS[$n]}"

  if [[ ! -f "$script" ]]; then
    echo ""
    echo "Warning: missing script ${SCRIPTS[$n]}"
    RESULT[$n]="MISSING"
    failed=1
    continue
  fi

  echo ""
  echo "--------------------------------------------------"
  echo "Running: ${SCRIPTS[$n]}"
  echo "--------------------------------------------------"

  if bash "$script"; then
    RESULT[$n]="OK"
  else
    failed=1
    if [[ "$n" == "99" ]]; then
      # The audit failing means "gaps found", not "the script crashed".
      RESULT[$n]="GAPS FOUND"
    else
      RESULT[$n]="FAILED"
      hard_failed=1
    fi
  fi
done

# === SUMMARY =============================================================

red=''
yellow=''
off=''
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  red=$'\033[31m'
  yellow=$'\033[33m'
  off=$'\033[0m'
fi

echo ""
echo "=================================================="
echo "Run summary"
echo "=================================================="
for n in "${SELECT[@]}"; do
  status="${RESULT[$n]:-NOT RUN}"
  case "$status" in
    OK) printf '  %-4s %-45s %s\n' "$n" "${SCRIPTS[$n]:-?}" "$status" ;;
    "GAPS FOUND") printf '  %-4s %-45s %s%s%s\n' "$n" "${SCRIPTS[$n]:-?}" "$yellow" "$status" "$off" ;;
    *) printf '  %-4s %-45s %s%s%s\n' "$n" "${SCRIPTS[$n]:-?}" "$red" "$status" "$off" ;;
  esac
done
echo "=================================================="

if ((hard_failed)); then
  echo "Completed WITH FAILURES - see the errors above."
  exit 1
fi

if ((failed)); then
  echo "Setup steps completed, but the audit found gaps - see the list above."
  exit 1
fi

echo "All steps completed successfully."
