#!/usr/bin/env bash
# emit-event.sh — append one telemetry event to the local, git-untracked event
# log the `report` skill reads. The methodology emits its own effectiveness
# evidence as a byproduct of running; this is the write side.
#
# The ORCHESTRATOR calls this from the main session — never a worktree agent
# (agents writing a shared file from worktrees made every concurrent PR conflict
# on it; the same cost-guardrail lesson as the outcomes log).
#
# Usage:
#   emit-event.sh '<json object with an "event" key>'
#   emit-event.sh --log <path> '<json object>'     # override the default log
#
#   e.g. emit-event.sh '{"event":"issue_dispatched","issue":204,"mode":"autonomous","agent_friendly":true}'
#
# Adds an ISO-8601 UTC `ts` field (do not pass your own). Ensures the log is
# excluded locally via .git/info/exclude on first write, so it is never
# committed without touching the tracked .gitignore. Schema: references/events-schema.md.
set -euo pipefail

LOG_REL="docs/agent-fixes/events.jsonl"
OUTCOMES_REL="docs/agent-fixes/agent-friendly-outcomes.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log) LOG_REL="$2"; shift 2 ;;
    --*)   echo "unknown arg: $1" >&2; exit 2 ;;
    *)     break ;;
  esac
done

OBJ="${1:?usage: emit-event.sh [--log <path>] '<json object with an \"event\" key>'}"

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 2; }

root="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "error: not inside a git repository" >&2; exit 2; }
cd "$root"

# Validate: must be a JSON object carrying an "event" key.
printf '%s' "$OBJ" | jq -e 'type == "object" and (has("event"))' >/dev/null 2>&1 \
  || { echo "error: argument must be a JSON object with an \"event\" key" >&2; exit 1; }

mkdir -p "$(dirname "$LOG_REL")"

# Exclude the local artifacts (this log + the outcomes log) via .git/info/exclude
# — local, uncommitted, so the tracked .gitignore is left alone.
git_dir="$(git rev-parse --git-dir)"
excl="$git_dir/info/exclude"
mkdir -p "$(dirname "$excl")"; touch "$excl"
for p in "$LOG_REL" "$OUTCOMES_REL"; do
  grep -qxF "$p" "$excl" 2>/dev/null || printf '%s\n' "$p" >> "$excl"
done

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s' "$OBJ" | jq -c --arg ts "$ts" '{ts:$ts} + .' >> "$LOG_REL"

echo "emitted $(printf '%s' "$OBJ" | jq -r '.event') @ $ts -> $LOG_REL"
