#!/bin/bash
# Install (merge) the agent-ready-guardrails permission policy into a Claude
# Code settings file. Idempotent: existing rules are kept, policy rules are
# added, duplicates removed. Everything outside `permissions` is left untouched.
#
# Usage:
#   ./install-policy.sh                                    # → ~/.claude/settings.json
#   sudo ./install-policy.sh /etc/claude-code/managed-settings.json   # strict variant
#
# The managed-settings variant cannot be overridden by user/project settings —
# use it where the machine is centrally administered.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY="$SCRIPT_DIR/../policy/permissions.json"
TARGET="${1:-$HOME/.claude/settings.json}"

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }
[ -f "$POLICY" ] || { echo "error: policy file not found: $POLICY" >&2; exit 1; }

mkdir -p "$(dirname "$TARGET")"
[ -f "$TARGET" ] || echo '{}' > "$TARGET"

backup="$TARGET.bak.$(date +%Y%m%d%H%M%S)"
cp "$TARGET" "$backup"

tmp=$(mktemp)
jq -s '
  .[0] as $cur | .[1] as $pol |
  ($cur.permissions // {}) as $curp |
  ($pol.permissions // {}) as $polp |
  $cur | .permissions = ($curp + {
    allow: ((($curp.allow // []) + ($polp.allow // [])) | unique),
    ask:   ((($curp.ask   // []) + ($polp.ask   // [])) | unique),
    deny:  ((($curp.deny  // []) + ($polp.deny  // [])) | unique)
  })
' "$TARGET" "$POLICY" > "$tmp"
mv "$tmp" "$TARGET"

echo "agent-ready-guardrails policy merged into $TARGET"
echo "backup of previous settings: $backup"
echo "rules now active: $(jq '.permissions.deny | length' "$TARGET") deny / $(jq '.permissions.ask | length' "$TARGET") ask / $(jq '.permissions.allow | length' "$TARGET") allow"
