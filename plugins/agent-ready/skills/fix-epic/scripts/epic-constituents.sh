#!/usr/bin/env bash
# Print the constituent issue numbers from an epic's task list, in order.
# Reads only task-list lines ("- [ ] #N" / "- [x] #N") so prose mentions of
# other issues in the epic body are ignored.
#
# Usage: epic-constituents.sh <epic#>
# Requires: gh (authenticated).

set -euo pipefail
command -v gh >/dev/null || { echo "error: gh required" >&2; exit 1; }

EPIC="${1:?usage: epic-constituents.sh <epic#>}"; EPIC="${EPIC#\#}"

gh issue view "$EPIC" --json body -q .body \
  | grep -E '^[[:space:]]*- \[[ xX]\]' \
  | grep -oE '#[0-9]+' \
  | tr -d '#' \
  | awk '!seen[$0]++'
