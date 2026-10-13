#!/usr/bin/env bash
# preflight.sh — check the prerequisites the Agent Ready methodology needs on
# this machine, and print exactly how to fix anything missing. READ-ONLY:
# installs nothing, changes nothing.
#
# Exit 0 if every REQUIRED prerequisite is present; exit 1 if any is missing.
# Optional items print INFO/WARN and never fail the run.
set -uo pipefail

fails=0
req_ok()  { printf '  OK    %s\n' "$1"; }
req_bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
info()    { printf '  INFO  %s\n' "$1"; }

echo "Agent Ready — preflight"
echo "Required tools:"
for t in git jq gh; do
  if command -v "$t" >/dev/null 2>&1; then
    req_ok "$t present"
  else
    req_bad "$t not found — install it before continuing"
  fi
done

echo "GitHub auth:"
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    req_ok "gh is authenticated ($(gh api user --jq '.login' 2>/dev/null || echo '?'))"
  else
    req_bad "gh is not authenticated — run: gh auth login"
  fi
else
  info "gh missing (reported above) — auth check skipped"
fi

echo "Claude Code marketplace + plugins:"
if command -v claude >/dev/null 2>&1; then
  req_ok "claude CLI present"
  known="$HOME/.claude/plugins/known_marketplaces.json"
  if [ -f "$known" ] && jq -e '.["agent-ready"]' "$known" >/dev/null 2>&1; then
    req_ok "agent-ready marketplace is added"
  else
    info "agent-ready marketplace not detected — the setup skill will add it (idempotent):"
    info "    claude plugin marketplace add wanderindev/agent-ready"
  fi
else
  info "claude CLI not on PATH — plugin steps run inside Claude Code, so this is fine"
  info "if you use the CLI outside a session, ensure 'claude' is installed"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "preflight: OK — all required prerequisites present."
  exit 0
else
  echo "preflight: $fails required item(s) missing — fix the FAILs above, then re-run."
  exit 1
fi
