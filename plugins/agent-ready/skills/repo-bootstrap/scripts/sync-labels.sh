#!/usr/bin/env bash
# Idempotently sync GitHub labels from a labels.json file to the current repo.
#
# Usage: sync-labels.sh <path-to-labels.json>
#
# labels.json is an array of {name, color, description}. Each label is created
# if missing, or updated in place if it already exists. Safe to re-run.
#
# Requires: gh (authenticated, with repo access), jq.

set -euo pipefail

LABELS_FILE="${1:?usage: sync-labels.sh <path-to-labels.json>}"

command -v gh >/dev/null || { echo "error: gh CLI is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }
[ -f "$LABELS_FILE" ] || { echo "error: no such file: $LABELS_FILE" >&2; exit 1; }

count=$(jq 'length' "$LABELS_FILE")
echo "Syncing $count labels from $LABELS_FILE ..."

for i in $(seq 0 $((count - 1))); do
  name=$(jq -r ".[$i].name"        "$LABELS_FILE")
  color=$(jq -r ".[$i].color"      "$LABELS_FILE")
  desc=$(jq -r ".[$i].description" "$LABELS_FILE")

  if gh label create "$name" --color "$color" --description "$desc" >/dev/null 2>&1; then
    echo "  created: $name"
  else
    # Already exists (or transient) — bring it to the desired state.
    if gh label edit "$name" --color "$color" --description "$desc" >/dev/null 2>&1; then
      echo "  updated: $name"
    else
      echo "  FAILED:  $name (check gh auth / repo permissions)" >&2
      exit 1
    fi
  fi
done

echo "Labels in sync."
