# Telemetry event schema

The methodology emits its own effectiveness evidence as a byproduct of running.
The **orchestrator** (never a worktree agent) appends one JSON object per line
to a local, git-untracked event log — default `docs/agent-fixes/events.jsonl` —
via `scripts/emit-event.sh`. The `report` skill reads that log and joins it with
live read-only `gh`/`git` queries to compute the scorecard.

## Why store only these events

Most of the scorecard is already durably in GitHub/git and is **derived at
report time**, not stored: backlog by label, PRs merged/open/draft, reverts to
`main`, commit cadence. Storing them again would just be a stale copy. The event
log persists only the **process facts GitHub cannot reconstruct** — whether an
issue was dispatched to an agent vs hand-fixed, whether a brief was held at the
gate, and the fresh-session review verdict that happens *before* a human ever
sees the PR.

## Storage rules (same discipline as the outcomes log)

- **Orchestrator-written, never by a worktree agent.** Agents writing a shared
  file from their worktrees made every concurrent PR conflict on it — the
  documented cost-guardrail lesson. The orchestrator appends from the main
  session instead.
- **Local-only, never committed.** `emit-event.sh` adds the log to
  `.git/info/exclude` on first write, so it is excluded locally without
  modifying the tracked `.gitignore`. Do not commit `events.jsonl`; do not
  include it in a PR.
- **Append-only.** One object per line; never rewrite past lines.

## Common fields

Every event carries:

| Field | Type | Meaning |
|---|---|---|
| `ts` | string | ISO-8601 UTC, **added by `emit-event.sh`** — do not pass it yourself. |
| `event` | string | One of the event types below. |

## Event types

### `issue_dispatched`
An implementation agent was launched for an issue (fix-issue step 5).

| Field | Type | Meaning |
|---|---|---|
| `issue` | int | GitHub issue number. |
| `mode` | `"autonomous"` \| `"review"` | Whether the human brief-review gate was on. |
| `agent_friendly` | bool | Whether the issue carried the `agent-friendly` label (should be true; an override is worth recording). |

### `brief_held`
The well-formedness / production-touch gate (fix-issue gate 3) held a brief
instead of dispatching it (fix-issue step 3).

| Field | Type | Meaning |
|---|---|---|
| `issue` | int | GitHub issue number. |
| `reason` | string | Short reason, e.g. `"production-touch: YES"`, `"unfilled placeholders"`, `"tractable: no"`. |

### `review_verdict`
The fresh-session review returned a verdict for a believe-complete PR
(fix-issue step 6). Not emitted for a blocked report (no review runs).

| Field | Type | Meaning |
|---|---|---|
| `issue` | int | GitHub issue number. |
| `pr` | int | PR number reviewed. |
| `verdict` | `"PASS"` \| `"FAIL"` | The **effective** verdict after the consistency downgrade. |
| `blockers` | int | Number of blocker findings. |
| `docs_check` | `"pass"` \| `"fail"` | The reviewer's docs-check result. |

### `outcome_finalized`
The operator settled an issue's end state (fix-issue step 7, after merge or
close). Emit the latest state; the report uses the last one per issue.

| Field | Type | Meaning |
|---|---|---|
| `issue` | int | GitHub issue number. |
| `pr` | int (optional) | PR number, if one exists. |
| `outcome` | `"clean-merge"` \| `"needs-revision"` \| `"blocked"` \| `"abandoned"` | `clean-merge`: merged with no post-review changes. `needs-revision`: merged after operator edits or a re-dispatch. `blocked`: draft-for-cause, not pursued autonomously. `abandoned`: closed without merging. |

## Examples

```jsonl
{"ts":"2026-05-30T14:02:11Z","event":"issue_dispatched","issue":204,"mode":"autonomous","agent_friendly":true}
{"ts":"2026-05-30T14:03:05Z","event":"brief_held","issue":205,"reason":"production-touch: YES"}
{"ts":"2026-05-30T14:41:22Z","event":"review_verdict","issue":204,"pr":312,"verdict":"PASS","blockers":0,"docs_check":"pass"}
{"ts":"2026-05-30T15:10:48Z","event":"outcome_finalized","issue":204,"pr":312,"outcome":"clean-merge"}
```

## Adding a new event type

Keep the vocabulary small and process-focused. Before adding a type, check the
fact is not already derivable from `gh`/`git` at report time (if it is, derive
it — don't store it). If you do add one, update this file and teach `report.sh`
to read it.
