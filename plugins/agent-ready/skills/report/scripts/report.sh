#!/usr/bin/env bash
# report.sh — the agent-ready methodology scorecard, self-computed.
#
# Joins the local, git-untracked event log (what the loop emitted as it ran —
# see emit-event.sh / events-schema.md) with live read-only gh/git queries
# (what GitHub already stores) and prints the retrospective on demand:
# backlog/clarity, autonomous quality, safety, throughput.
#
# Everything here is READ-ONLY. Nothing is written, pushed, or committed.
#
# Usage:
#   report.sh [--events <path>] [--since <days>] [--base <branch>]
# Defaults: events=docs/agent-fixes/events.jsonl, since=14, base=main.
set -euo pipefail

EVENTS="docs/agent-fixes/events.jsonl"
SINCE_DAYS=14
BASE="main"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --events) EVENTS="$2"; shift 2 ;;
    --since)  SINCE_DAYS="$2"; shift 2 ;;
    --base)   BASE="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 2; }
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "error: not in a git repository" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)"

HAVE_GH=0
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then HAVE_GH=1; fi

SINCE_ISO="$(date -u -d "${SINCE_DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
             || date -u -v-"${SINCE_DAYS}"d +%Y-%m-%dT%H:%M:%SZ)"   # GNU or BSD date
# Resolve the base to a ref that actually exists: prefer origin/<base>, then a
# local <base>, else fall back to HEAD — so no git-log below can fail on a
# missing ref (e.g. a repo whose default branch isn't <base>).
BASE_REF=""
for _c in "origin/$BASE" "$BASE"; do
  if git rev-parse --verify --quiet "${_c}^{commit}" >/dev/null; then BASE_REF="$_c"; break; fi
done
[[ -n "$BASE_REF" ]] || BASE_REF="HEAD"

hr() { printf '%s\n' "------------------------------------------------------------"; }
pct() { # pct <num> <denom>
  [[ "${2:-0}" -gt 0 ]] && printf '%d%%' $(( $1 * 100 / $2 )) || printf 'n/a'
}

echo "agent-ready scorecard   (window: last ${SINCE_DAYS}d · base: ${BASE_REF})"
hr

# ---------------------------------------------------------------------------
# 1. BACKLOG / CLARITY  — derived from GitHub issue labels
# ---------------------------------------------------------------------------
echo "BACKLOG / CLARITY"
if [[ "$HAVE_GH" -eq 1 ]]; then
  issues="$(gh issue list --state all --limit 2000 \
              --json number,state,labels 2>/dev/null || echo '[]')"
  echo "$issues" | jq -r '
    def has(l): any(.labels[].name; . == l);
    {
      filed:  length,
      open:   (map(select(.state=="OPEN"))   | length),
      closed: (map(select(.state=="CLOSED")) | length),
      critical:     (map(select(has("code-quality:critical")))     | length),
      moderate:     (map(select(has("code-quality:moderate")))     | length),
      nice:         (map(select(has("code-quality:nice-to-have"))) | length),
      agentfriendly:(map(select(has("agent-friendly")))            | length),
      epic:         (map(select(has("epic")))                      | length)
    } |
    "  filed: \(.filed)   (open \(.open) / closed \(.closed))",
    "  severity: \(.critical) critical · \(.moderate) moderate · \(.nice) nice-to-have",
    "  \(.agentfriendly) agent-friendly · \(.epic) epics"'
else
  echo "  (gh unavailable / not authed — skipped; backlog is derived from GitHub labels)"
fi
hr

# ---------------------------------------------------------------------------
# 2. AUTONOMOUS QUALITY  — from the local event log
# ---------------------------------------------------------------------------
echo "AUTONOMOUS QUALITY (fix-issue)"
if [[ -f "$EVENTS" ]]; then
  EV="$(jq -R 'fromjson? // empty' "$EVENTS" | jq -s '.')"
  summary="$(printf '%s' "$EV" | jq '
    [.[] | select(.event=="issue_dispatched")] as $disp |
    [.[] | select(.event=="brief_held")]       as $held |
    [.[] | select(.event=="review_verdict")]   as $rev  |
    [.[] | select(.event=="outcome_finalized")]as $out  |
    ($rev | group_by(.issue) | map(.[0]))  as $firstrev |
    ($out | group_by(.issue) | map(.[-1])) as $lastout  |
    {
      dispatched:  ($disp | map(.issue) | unique | length),
      briefs_held: ($held | length),
      review_pass: ($firstrev | map(select(.verdict=="PASS")) | length),
      review_fail: ($firstrev | map(select(.verdict=="FAIL")) | length),
      clean_merge:    ($lastout | map(select(.outcome=="clean-merge"))    | length),
      needs_revision: ($lastout | map(select(.outcome=="needs-revision")) | length),
      blocked:        ($lastout | map(select(.outcome=="blocked"))        | length),
      abandoned:      ($lastout | map(select(.outcome=="abandoned"))      | length)
    }')"
  d()  { printf '%s' "$summary" | jq -r ".$1"; }
  rp=$(d review_pass); rf=$(d review_fail)
  echo "  dispatched: $(d dispatched)   briefs held at gate: $(d briefs_held)"
  echo "  fresh-review first pass: ${rp} PASS / ${rf} FAIL   (pass rate $(pct "$rp" $((rp+rf))))"
  echo "  outcomes: $(d clean_merge) clean-merge · $(d needs_revision) needs-revision · $(d blocked) blocked · $(d abandoned) abandoned"
else
  echo "  (no local event log at $EVENTS yet — run fix-issue to start emitting)"
fi
hr

# ---------------------------------------------------------------------------
# 3. SAFETY  — PRs merged (gh) + breakages of the base branch (git heuristic)
# ---------------------------------------------------------------------------
echo "SAFETY"
if [[ "$HAVE_GH" -eq 1 ]]; then
  prs="$(gh pr list --state all --limit 2000 --json number,mergedAt 2>/dev/null || echo '[]')"
  merged_total="$(printf '%s' "$prs" | jq '[.[] | select(.mergedAt != null)] | length')"
  merged_win="$(printf '%s' "$prs" | jq --arg s "$SINCE_ISO" \
                  '[.[] | select(.mergedAt != null and .mergedAt >= $s)] | length')"
  echo "  PRs merged: ${merged_total} total · ${merged_win} in window"
else
  echo "  PRs merged: (gh unavailable — skipped)"
fi
# Heuristic: revert/hotfix commits on the base branch in the window.
breaks="$(git log "$BASE_REF" --since="$SINCE_ISO" -i \
            --grep='revert' --grep='hotfix' --grep='rollback' \
            --oneline 2>/dev/null | wc -l | tr -d ' ')"
echo "  base-branch revert/hotfix commits in window: ${breaks}   (heuristic — grep of commit subjects)"
hr

# ---------------------------------------------------------------------------
# 4. THROUGHPUT  — "blank page cured": commit cadence + close/merge rate
# ---------------------------------------------------------------------------
echo "THROUGHPUT"
PRIOR_ISO="$(date -u -d "$((SINCE_DAYS * 2)) days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
             || date -u -v-"$((SINCE_DAYS * 2))"d +%Y-%m-%dT%H:%M:%SZ)"
commits_win="$(git log "$BASE_REF" --since="$SINCE_ISO" --oneline 2>/dev/null | wc -l | tr -d ' ')"
commits_prior="$(git log "$BASE_REF" --since="$PRIOR_ISO" --until="$SINCE_ISO" --oneline 2>/dev/null | wc -l | tr -d ' ')"
echo "  commits: ${commits_win} in window vs ${commits_prior} in the prior ${SINCE_DAYS}d"
if [[ "$HAVE_GH" -eq 1 ]]; then
  closed_win="$(gh issue list --state closed --limit 2000 --json closedAt 2>/dev/null \
                 | jq --arg s "$SINCE_ISO" '[.[] | select(.closedAt >= $s)] | length')"
  echo "  issues closed in window: ${closed_win}   ·   PRs merged in window: ${merged_win:-n/a}"
fi
hr
echo "read-only — nothing was written. Event log: ${EVENTS} (local, git-untracked)."
