#!/usr/bin/env bash
# 05-gh-copilot-code-review.sh
# Summary: Create or update (upsert) the Copilot code review ruleset on the
# default branch of one or more repositories using the GitHub CLI (`gh`).
#
# Prerequisites:
#  - `gh` installed and authenticated with admin access
#  - The owner must have GitHub Copilot code review available
#    (Copilot Business/Enterprise, or Copilot Pro with code review enabled)
#    If it is not, the API rejects the ruleset and the error is printed.
#
# Usage:
#  REPOS="my-repo" OWNER="username" bash 05-gh-copilot-code-review.sh
#  DRY_RUN=1 bash 05-gh-copilot-code-review.sh
#  Default target: all public repos of OWNER.
#
# Environment:
#  - RULESET_NAME          name of the managed ruleset
#                          (default: copilot-code-review-default)
#  - REVIEW_ON_PUSH        review every new push (default: 1)
#  - REVIEW_DRAFT_PRS      also review draft PRs (default: 0)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

RULESET_NAME=${RULESET_NAME:-copilot-code-review-default}
REVIEW_ON_PUSH=${REVIEW_ON_PUSH:-1}
REVIEW_DRAFT_PRS=${REVIEW_DRAFT_PRS:-0}

[[ "$RULESET_NAME" =~ ^[A-Za-z0-9._\ -]+$ ]] ||
  die "RULESET_NAME may only contain letters, digits, spaces, dot, dash and underscore"
for flag in REVIEW_ON_PUSH REVIEW_DRAFT_PRS; do
  [[ "${!flag}" =~ ^[01]$ ]] || die "$flag must be 0 or 1 (got: ${!flag})"
done

bool() {
  if [[ "$1" == "1" ]]; then printf 'true'; else printf 'false'; fi
}

payload="$(mk_payload_file)"
trap 'rm -f "$payload"' EXIT

cat >"$payload" <<EOF
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": [ "~DEFAULT_BRANCH" ],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "copilot_code_review",
      "parameters": {
        "review_on_push": $(bool "$REVIEW_ON_PUSH"),
        "review_draft_pull_requests": $(bool "$REVIEW_DRAFT_PRS")
      }
    }
  ],
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ]
}
EOF

log "Copilot code review ruleset '$RULESET_NAME'"
log "  review on push:    $([[ "$REVIEW_ON_PUSH" == "1" ]] && echo yes || echo no)"
log "  review draft PRs:  $([[ "$REVIEW_DRAFT_PRS" == "1" ]] && echo yes || echo no)"
if [[ "$DRY_RUN" == "1" ]]; then
  log "  payload:"
  sed 's/^/    /' "$payload"
fi

init_targets

for repo in "${TARGETS[@]}"; do
  repo_header "$repo"

  if is_archived "$repo"; then
    skipped "archived repository"
    continue
  fi

  existing="$(
    gh api "repos/$repo/rulesets?includes_parents=false" \
      --jq "map(select(.name == \"$RULESET_NAME\")) | .[0].id // empty" 2>/dev/null || true
  )"

  if [[ -n "$existing" ]]; then
    step "ruleset '$RULESET_NAME' updated (id $existing)" \
      gh api "repos/$repo/rulesets/$existing" --method PUT --input "$payload"
  else
    step "ruleset '$RULESET_NAME' created" \
      gh api "repos/$repo/rulesets" --method POST --input "$payload"
  fi

  log "  -> https://github.com/$repo/settings/rules"
done

finish
