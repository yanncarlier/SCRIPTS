#!/usr/bin/env bash
# 03-gh-setup-rulesets.sh
# Summary: Create or update (upsert) the branch protection ruleset for one or
# more repositories using the GitHub CLI (`gh`). The ruleset is NOT deleted
# and recreated: an existing ruleset with the same name is updated in place,
# so protection never drops during a re-run and manual edits are preserved
# on other rulesets.
#
# Prerequisites:
#  - `gh` installed and authenticated with admin access to target repos.
#
# Usage:
#  OWNER="username" bash 03-gh-setup-rulesets.sh
#  REPOS="repo1,repo2" OWNER="username" bash 03-gh-setup-rulesets.sh
#  DRY_RUN=1 bash 03-gh-setup-rulesets.sh
#  REQUIRED_APPROVALS=2 BLOCK_DIRECT_PUSH=0 bash 03-gh-setup-rulesets.sh
#
# Environment variables:
#  - RULESET_NAME             name of the managed ruleset
#                             (default: protect-default-branch)
#  - PROTECT_BRANCHES         comma separated refs to protect
#                             (default: ~DEFAULT_BRANCH,refs/heads/dev)
#  - REQUIRED_APPROVALS       approving reviews required (default: 1)
#  - REQUIRE_LAST_PUSH_APPROVAL  block self-approval of your own push (default: 1)
#  - REQUIRE_THREAD_RESOLUTION   all review threads resolved (default: 1)
#  - BLOCK_DIRECT_PUSH        only bypass roles may update the refs, i.e.
#                             everyone else must use a PR (default: 1)
#  - REQUIRE_LINEAR_HISTORY   forbid merge commits (default: 0)
#  - BYPASS_MODE              always | pull_request | exempt (default: always)
#                             "pull_request" is stricter: admins can only
#                             bypass while merging a PR, never by pushing.
#  - DRY_RUN=1                print the payload instead of applying it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

# === CONFIGURATION =======================================================

RULESET_NAME=${RULESET_NAME:-protect-default-branch}
PROTECT_BRANCHES=${PROTECT_BRANCHES:-"~DEFAULT_BRANCH,refs/heads/dev"}
REQUIRED_APPROVALS=${REQUIRED_APPROVALS:-1}
REQUIRE_LAST_PUSH_APPROVAL=${REQUIRE_LAST_PUSH_APPROVAL:-1}
REQUIRE_THREAD_RESOLUTION=${REQUIRE_THREAD_RESOLUTION:-1}
BLOCK_DIRECT_PUSH=${BLOCK_DIRECT_PUSH:-1}
REQUIRE_LINEAR_HISTORY=${REQUIRE_LINEAR_HISTORY:-0}
BYPASS_MODE=${BYPASS_MODE:-always}

# Admin role id (RepositoryRole 5) keeps a way to merge when nobody else can.
BYPASS_ACTOR_ID=${BYPASS_ACTOR_ID:-5}

# === VALIDATION ==========================================================

[[ "$RULESET_NAME" =~ ^[A-Za-z0-9._\ -]+$ ]] ||
  die "RULESET_NAME may only contain letters, digits, spaces, dot, dash and underscore"
[[ "$REQUIRED_APPROVALS" =~ ^[0-9]+$ ]] ||
  die "REQUIRED_APPROVALS must be a number (got: $REQUIRED_APPROVALS)"
for flag in REQUIRE_LAST_PUSH_APPROVAL REQUIRE_THREAD_RESOLUTION BLOCK_DIRECT_PUSH REQUIRE_LINEAR_HISTORY; do
  [[ "${!flag}" =~ ^[01]$ ]] ||
    die "$flag must be 0 or 1 (got: ${!flag})"
done
[[ "$BYPASS_MODE" == "always" || "$BYPASS_MODE" == "pull_request" || "$BYPASS_MODE" == "exempt" ]] ||
  die "BYPASS_MODE must be always, pull_request or exempt (got: $BYPASS_MODE)"

bool() {
  if [[ "$1" == "1" ]]; then printf 'true'; else printf 'false'; fi
}

# === BRANCH LIST =========================================================

include_json=""
IFS=',' read -r -a branches <<<"$PROTECT_BRANCHES"
for b in "${branches[@]}"; do
  b="${b// /}"
  [[ -z "$b" ]] && continue
  if [[ "$b" == *'"'* || "$b" == *'\'* ]]; then
    die "PROTECT_BRANCHES contains an unsupported character: $b"
  fi
  include_json+="\"$b\","
done
include_json="${include_json%,}"
[[ -n "$include_json" ]] || die "PROTECT_BRANCHES is empty"

# === OPTIONAL RULES ======================================================

extra_rules=""
if [[ "$BLOCK_DIRECT_PUSH" == "1" ]]; then
  extra_rules+=$',\n    { "type": "update", "parameters": { "update_allows_fetch_and_merge": true } }'
fi
if [[ "$REQUIRE_LINEAR_HISTORY" == "1" ]]; then
  extra_rules+=$',\n    { "type": "required_linear_history" }'
fi

# === PAYLOAD =============================================================

payload="$(mk_payload_file)"
trap 'rm -f "$payload"' EXIT

cat >"$payload" <<EOF
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": [ $include_json ],
      "exclude": []
    }
  },
  "bypass_actors": [
    {
      "actor_id": $BYPASS_ACTOR_ID,
      "actor_type": "RepositoryRole",
      "bypass_mode": "$BYPASS_MODE"
    }
  ],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": $(bool "$REQUIRE_LAST_PUSH_APPROVAL"),
        "required_approving_review_count": $REQUIRED_APPROVALS,
        "required_review_thread_resolution": $(bool "$REQUIRE_THREAD_RESOLUTION")
      }
    }$extra_rules
  ]
}
EOF

log "Ruleset '$RULESET_NAME'"
log "  protects:       $PROTECT_BRANCHES"
log "  approvals:      $REQUIRED_APPROVALS (last-push approval: $REQUIRE_LAST_PUSH_APPROVAL, threads: $REQUIRE_THREAD_RESOLUTION)"
log "  direct pushes:  $([[ "$BLOCK_DIRECT_PUSH" == "1" ]] && echo "blocked (PR required)" || echo "allowed")"
log "  linear history: $([[ "$REQUIRE_LINEAR_HISTORY" == "1" ]] && echo "required" || echo "not required")"
log "  bypass:         RepositoryRole id $BYPASS_ACTOR_ID, mode $BYPASS_MODE"
if [[ "$DRY_RUN" == "1" ]]; then
  log "  payload:"
  sed 's/^/    /' "$payload"
fi

# === APPLY ===============================================================

init_targets

for repo in "${TARGETS[@]}"; do
  repo_header "$repo"

  if is_archived "$repo"; then
    skipped "archived repository"
    continue
  fi

  # Only consider rulesets owned by this repository (not org-level ones).
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
