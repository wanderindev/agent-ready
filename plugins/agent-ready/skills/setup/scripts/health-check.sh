#!/usr/bin/env bash
# health-check.sh — verify an Agent Ready setup is actually in place, on this
# machine and (if run inside a target repo) for this repo. READ-ONLY: checks
# only, changes nothing.
#
# Machine checks: the guardrails deny/ask/allow policy is installed.
# Repo checks:    methodology docs, labels, CI, branch protection, event-log exclude.
#
# Exit 1 if any hard FAIL (a missing safety floor); 0 if only PASS/WARN/INFO.
# WARNs are "not set up yet / can't verify from here", not errors.
set -uo pipefail

fails=0
pass() { printf '  PASS  %s\n' "$1"; }
warn() { printf '  WARN  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
info() { printf '  INFO  %s\n' "$1"; }

# Signature rules the guardrails baseline installs.
SIG1='Bash(git push --force*)'
SIG2='Bash(gh pr merge*)'

has_sig() { # has_sig <settings-file>
  local f="$1"
  [ -f "$f" ] || return 1
  jq -e --arg a "$SIG1" --arg b "$SIG2" \
     '(.permissions.deny // []) as $d | ($d | index($a)) and ($d | index($b))' \
     "$f" >/dev/null 2>&1
}

echo "== Machine =="
found_policy=0
for f in "$HOME/.claude/settings.json" "/etc/claude-code/managed-settings.json"; do
  if has_sig "$f"; then pass "guardrails policy installed in $f"; found_policy=1; fi
done
if [ "$found_policy" -eq 0 ]; then
  # distinguish "no policy at all" from "some deny rules but not ours"
  any_deny=0
  for f in "$HOME/.claude/settings.json" "/etc/claude-code/managed-settings.json"; do
    [ -f "$f" ] && jq -e '((.permissions.deny // []) | length) > 0' "$f" >/dev/null 2>&1 && any_deny=1
  done
  if [ "$any_deny" -eq 1 ]; then
    warn "settings has deny rules, but not the agent-ready-guardrails signature — re-run install-policy.sh"
  else
    fail "guardrails policy not installed — run install-policy.sh (agent-ready-guardrails)"
  fi
fi
info "the PreToolUse guard hook loads at session start — restart / reload-plugins can't be verified from here"

echo "== Repo =="
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  info "not inside a git repository — repo checks skipped (run this from a target repo)"
else
  cd "$(git rev-parse --show-toplevel)" || { fail "cannot cd to repo root"; exit 1; }

  # local checks (no gh needed)
  if [ -d docs/methodology ]; then pass "methodology docs present (docs/methodology/)"
  else warn "no docs/methodology/ — run /agent-ready:methodology-install (or note your custom dest)"; fi

  excl="$(git rev-parse --git-dir)/info/exclude"
  if [ -f "$excl" ] && grep -qxF "docs/agent-fixes/events.jsonl" "$excl" 2>/dev/null; then
    info "telemetry event-log is locally excluded"
  else
    info "telemetry event-log not yet excluded — happens automatically on the first fix-issue run"
  fi

  # gh-dependent checks
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 \
       && slug="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" && [ -n "$slug" ]; then
    branch="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo main)"

    labels="$(gh api "repos/$slug/labels" --paginate --jq '.[].name' 2>/dev/null || true)"
    if printf '%s\n' "$labels" | grep -qx "agent-friendly" \
       && printf '%s\n' "$labels" | grep -qx "code-quality:critical"; then
      pass "issue labels present (agent-friendly + code-quality:*)"
    else
      warn "methodology labels missing — run /agent-ready:repo-bootstrap"
    fi

    if ls .github/workflows/*.yml >/dev/null 2>&1; then pass "CI workflow present (.github/workflows/)"
    else warn "no CI workflow — run /agent-ready:repo-bootstrap"; fi

    if gh api "repos/$slug/branches/$branch/protection" >/dev/null 2>&1; then
      pass "branch protection on '$branch'"
    else
      warn "branch protection on '$branch' not confirmed (unprotected, or you lack admin to read it) — see repo-bootstrap"
    fi
  else
    warn "gh unavailable / no GitHub remote — label, CI, and branch-protection checks skipped"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "health-check: OK (any WARNs above are 'not set up yet' or 'can't verify from here')."
  exit 0
else
  echo "health-check: $fails hard failure(s) — fix the FAILs above and re-run."
  exit 1
fi
