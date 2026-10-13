#!/usr/bin/env bash
# List open issues (excluding epics) ranked high->low by methodology severity.
# Clustering for an epic starts from the top of this list.
#
# Output: one issue per line, TAB-separated:
#   <severity>  #<number>  <title>  <agent-friendly|->
# grouped by severity (critical -> moderate -> nice-to-have -> bug -> unlabeled).
#
# Usage: rank-backlog.sh
# Requires: gh (authenticated), jq.

set -euo pipefail
command -v gh >/dev/null || { echo "error: gh required" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq required" >&2; exit 1; }

gh issue list --state open --limit 500 --json number,title,labels | jq -r '
  def names: (.labels | map(.name));
  def sev:
    names as $l
    | if   ($l | index("code-quality:critical"))     then [0,"critical"]
      elif ($l | index("code-quality:moderate"))      then [1,"moderate"]
      elif ($l | index("code-quality:nice-to-have"))  then [2,"nice-to-have"]
      elif ($l | index("bug"))                        then [3,"bug"]
      else [4,"unlabeled"] end;
  def isepic: (names | index("epic")) != null;
  def af:     (names | index("agent-friendly")) != null;
  map(select(isepic | not) | . + {s: sev})
  | sort_by(.s[0], .number)
  | .[]
  | "\(.s[1])\t#\(.number)\t\(.title)\t\(if af then "agent-friendly" else "-" end)"
'
