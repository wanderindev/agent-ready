#!/usr/bin/env bash
# Copy the portable methodology docs into a target repo, then report what needs
# post-copy attention. The deterministic part (the copy) is done here; the
# contextual rewrites and the worked-example walk are driven by the skill.
#
# Usage: install.sh <src methodology dir> <dest dir>
#   e.g. install.sh "$CLAUDE_PLUGIN_ROOT/assets/methodology" docs/methodology
#
# Refuses to overwrite an existing destination (re-installing over a customized
# methodology tree would clobber the operator's swaps).

set -euo pipefail

SRC="${1:?usage: install.sh <src methodology dir> <dest dir>}"
DEST="${2:?usage: install.sh <src methodology dir> <dest dir>}"

[ -d "$SRC" ] || { echo "error: no such source dir: $SRC" >&2; exit 1; }
if [ -e "$DEST" ]; then
  echo "error: destination already exists: $DEST" >&2
  echo "       remove it or choose another path; refusing to clobber." >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
cp -r "$SRC" "$DEST"
echo "Copied methodology docs -> $DEST"
echo

echo "=== Worked-example blocks (pilot illustration; swap lazily as you audit) ==="
grep -rln "PIC-WORKED-EXAMPLE" "$DEST" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
echo

echo "=== Skill-path references to rewrite -> /agent-ready:<skill> (must-fix) ==="
grep -rn -e "\.\./\.\./skills" -e "\.\./\.\./\.\./skills" "$DEST" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
echo

echo "=== case-study references to repoint -> the Agent Ready case study (must-fix) ==="
grep -rn "case-study/" "$DEST" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
echo

echo "=== Cross-session register (must ship empty — expect 1 header row only) ==="
if [ -f "$DEST/cross-session-register.md" ]; then
  rows=$(grep -c "^| " "$DEST/cross-session-register.md" 2>/dev/null || echo 0)
  echo "  table-ish lines: $rows  (header + separator only = empty; more = stray data rows)"
else
  echo "  WARN: cross-session-register.md not found"
fi
