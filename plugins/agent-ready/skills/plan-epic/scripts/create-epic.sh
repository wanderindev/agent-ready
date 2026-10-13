#!/usr/bin/env bash
# Create an epic tracking issue with a task-list body of its constituents.
# The task-list order IS the intended execution order (linchpins first).
#
# Usage: create-epic.sh "<title>" "<scope sentence>" <issue#> [<issue#> ...]
# Prints the created epic's URL on success.
#
# Requires: gh (authenticated, with issue-create permission).

set -euo pipefail
command -v gh >/dev/null || { echo "error: gh required" >&2; exit 1; }

TITLE="${1:?usage: create-epic.sh <title> <scope> <issue#>...}"; shift
SCOPE="${1:?error: need a one-line scope sentence}"; shift
[ "$#" -ge 1 ] || { echo "error: need at least one constituent issue#" >&2; exit 1; }

body="$SCOPE"$'\n\n'"## Issues (in execution order)"$'\n'
for n in "$@"; do
  n="${n#\#}"
  t=$(gh issue view "$n" --json title -q .title 2>/dev/null) || {
    echo "error: cannot read issue #$n (does it exist in this repo?)" >&2; exit 1; }
  body+="- [ ] #$n — $t"$'\n'
done
body+=$'\n'"_Epic tracked by the Agent Ready methodology. Resolve with \`/agent-ready:fix-epic <this number>\`; close when all boxes are checked._"

gh issue create --label epic --title "$TITLE" --body "$body"
