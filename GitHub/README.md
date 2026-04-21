# GitHub Tools Repository

Use at Your Own Risk.
This repository contains Bash scripts for automating GitHub repository security and configuration with the GitHub CLI (`gh`).

## Prerequisites
- Install GitHub CLI: https://cli.github.com
- Authenticate with `gh auth login`
- Have admin or write access for target repositories
- Ensure the GitHub token has the required scopes

---

## Recommended startup order for a new repo
1. `01-gh-setup-dev-branches.sh`
   - Create a consistent development branch before applying protections.
2. `07-gh-enable-dependency-graph.sh`
   - Enable the dependency graph before submitting dependency snapshots.
3. `08-gh-auto-dependency-submission.sh`
   - Submit a dependency snapshot if you have a valid JSON file.
4. `04-gh-enable-secret-scanning.sh`
   - Enable secret scanning before push protection.
5. `02-gh-enable-push-protection.sh`
   - Enable push protection once secret scanning is active.
6. `06-gh-enable-private-vuln-reporting.sh`
   - Turn on private vulnerability reporting.
7. `09-gh-enable-dependabot-alerts.sh`
   - Enable Dependabot alerts (vulnerability + malware alerts coverage).
8. `10-gh-enable-dependabot-security-updates.sh`
   - Enable Dependabot automated security updates.
9. `12-gh-enable-dependabot-grouped-security-updates.sh` (optional)
   - Configure grouped Dependabot security updates via `.github/dependabot.yml`.
10. `03-gh-setup-rulesets.sh`
   - Apply branch protection rulesets.
11. `05-gh-copilot-code-review.sh`
    - Configure Copilot Code Review rulesets after protections are in place.

---

## Wrapper script
`00-gh-bootstrap-new-repo.sh` runs the recommended workflow in one pass.

Usage:
```bash
OWNER="my-org" REPOS="repo1,repo2" bash 00-gh-bootstrap-new-repo.sh
```
If `REPOS` is empty, the wrapper will fetch public repos for `OWNER`.
If `SNAPSHOT_FILE` is set, it will also run `08-gh-auto-dependency-submission.sh`.

---

## Script reference
- `00-gh-bootstrap-new-repo.sh` — orchestrate recommended setup order
- `01-gh-setup-dev-branches.sh` — create a development branch across repos
- `02-gh-enable-push-protection.sh` — enable secret scanning push protection
- `03-gh-setup-rulesets.sh` — create or replace branch protection rulesets
- `04-gh-enable-secret-scanning.sh` — enable GitHub secret scanning
- `05-gh-copilot-code-review.sh` — create Copilot Code Review rulesets
- `06-gh-enable-private-vuln-reporting.sh` — enable private vulnerability reporting
- `07-gh-enable-dependency-graph.sh` — enable the dependency graph
- `08-gh-auto-dependency-submission.sh` — submit dependency snapshots
- `09-gh-enable-dependabot-alerts.sh` — enable Dependabot alerts (vulnerability + malware alerts coverage)
- `10-gh-enable-dependabot-security-updates.sh` — enable Dependabot automated security fixes
- `11-gh-enable-dependabot-malware-alerts.sh` — explicitly enable Dependabot malware alerts coverage (uses Dependabot alerts setting)
- `12-gh-enable-dependabot-grouped-security-updates.sh` — add grouped security update rules to existing `.github/dependabot.yml`
  - If `.github/dependabot.yml` is missing, it can auto-generate one from detected manifest/workflow files.
- `13-gh-branch-hygiene-main.sh` — enable GitHub auto-delete for merged branches and optionally clean existing merged remote/local branches
- `20-gh-delete-rulesets.sh` — delete all repository rulesets (destructive)
- `24-gh-disable-codeql.sh` — disable CodeQL default setup
- `git_fetch_pull_all_subfolders.sh` — helper for git fetch/pull across nested folders

---

## Usage examples
Run the full bootstrap flow:
```bash
OWNER="my-org" REPOS="repo1,repo2" SNAPSHOT_FILE="./08-test-snapshot.json" bash 00-gh-bootstrap-new-repo.sh
```
Run a specific script:
```bash
OWNER="my-org" REPOS="repo1,repo2" bash 03-gh-setup-rulesets.sh
```
Enable push protection:
```bash
OWNER="my-org" REPOS="repo1,repo2" bash 02-gh-enable-push-protection.sh
```

---

## Important notes
- `02-gh-enable-push-protection.sh` requires `04-gh-enable-secret-scanning.sh` first.
- `08-gh-auto-dependency-submission.sh` should run after `07-gh-enable-dependency-graph.sh`.
- `20-gh-delete-rulesets.sh` is destructive; use it only when you intend to remove all rulesets.
- Always review script headers and `gh` output before running in production.

---

## Troubleshooting
- Confirm `gh auth status` succeeds.
- Verify the account has admin rights for the target repositories.
- Re-run with corrected token scopes or repo access if a script fails.
