#!/usr/bin/env bash
# Apply Agent Ready's default branch protection to a branch.
#
# The protection enforced:
#   - all changes go through a PR (direct pushes to the branch are blocked)
#   - the given status checks must pass before merge (strict / up-to-date)
#   - no force-pushes, no branch deletion
#   - 0 required approvals (so a solo maintainer can self-merge after CI is green)
#   - enforce_admins toggle (default ON — even admins go through the gate; this is
#     what actually blocks the owner from pushing straight to the branch)
#
# Usage:
#   protect-branch.sh [--no-enforce-admins] <branch> <check-context> [<check-context> ...]
#
# Example:
#   protect-branch.sh main "Secret scan" "Test"
#
# Requires: gh (authenticated, ADMIN on the repo), jq.
# Note: the <check-context> values are the CI job `name:` values. They may be
# registered before the check has ever run; GitHub shows them as "expected".

set -euo pipefail

command -v gh >/dev/null || { echo "error: gh CLI is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }

ENFORCE_ADMINS=true
if [ "${1:-}" = "--no-enforce-admins" ]; then
  ENFORCE_ADMINS=false
  shift
fi

BRANCH="${1:?usage: protect-branch.sh [--no-enforce-admins] <branch> <check>...}"
shift
[ "$#" -ge 1 ] || { echo "error: at least one status-check context is required" >&2; exit 1; }

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
contexts=$(printf '%s\n' "$@" | jq -R . | jq -s .)

payload=$(jq -n \
  --argjson contexts "$contexts" \
  --argjson enforce "$ENFORCE_ADMINS" \
  '{
    required_status_checks: { strict: true, contexts: $contexts },
    enforce_admins: $enforce,
    required_pull_request_reviews: { required_approving_review_count: 0 },
    restrictions: null,
    allow_force_pushes: false,
    allow_deletions: false
  }')

echo "Applying branch protection to $REPO@$BRANCH"
echo "  required checks: $*"
echo "  enforce_admins:  $ENFORCE_ADMINS"

echo "$payload" | gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" \
  -H "Accept: application/vnd.github+json" --input - >/dev/null

echo "Branch protection applied."
