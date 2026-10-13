---
name: report
description: Print the agent-ready methodology scorecard — the self-computed retrospective. Joins the local git-untracked event log (what the fix-issue loop emitted as it ran) with live read-only gh/git queries (backlog by label, PRs merged, base-branch reverts, commit cadence) and reports backlog/clarity, autonomous quality (dispatch outcomes + fresh-review pass rate), safety, and throughput. Read-only — writes nothing. Use when the operator asks "how is the methodology doing", "show the agent-ready metrics/scorecard/telemetry", "did autonomy actually work", "run the retrospective numbers", or wants to see the effectiveness of the audit-to-autonomy loop. The write side (emitting events as the loop runs) is scripts/emit-event.sh, called by the fix-issue orchestrator.
---

# report — the methodology scorecard, self-computed

The case study's retrospective — issues filed and closed, PRs merged, breakages
of `main`, commit cadence — was hand-counted at the end of the pilot. This skill
makes it **self-computing**: the audit-to-autonomy loop emits its own evidence as
a byproduct of running, and this report rolls it up on demand. That is
"adoption measures itself" translated to a solo remediation methodology — the
methodology measuring **its own effectiveness**, not who is using it.

## What it measures

- **Backlog / clarity** (the pilot's real win was clarity, not autonomy): issues
  the audit filed, by severity label and `agent-friendly` count. *Derived from
  GitHub.*
- **Autonomous quality**: of dispatched issues → clean-merge / needs-revision /
  blocked / abandoned, plus the **fresh-session review first-pass rate**
  (the sharpest quality signal, and one that only exists because of the fresh
  review). *From the local event log.*
- **Safety**: PRs merged, and revert/hotfix commits on the base branch — the
  headline "zero breakages of `main`" claim. *Derived from gh/git.*
- **Throughput** ("blank page cured"): commit cadence this window vs the prior
  one, issues closed, PRs merged. *Derived from git/gh.*

## Store vs derive — the design

Most of the scorecard is already durably in GitHub/git and is **derived at
report time**, never stored (storing it again would just be a stale copy). The
local event log persists **only the process facts GitHub cannot reconstruct**:
whether an issue was dispatched to an agent vs hand-fixed, whether a brief was
held at the gate, and the fresh-review verdict that happens before a human sees
the PR. Schema and storage rules: `references/events-schema.md`.

## Run it

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/report/scripts/report.sh" [--since <days>] [--base <branch>] [--events <path>]
```

Defaults: `--since 14` (the pilot's window), `--base main`, events at
`docs/agent-fixes/events.jsonl`. It is **read-only** — it writes nothing, pushes
nothing, commits nothing. It degrades gracefully: with no event log yet it prints
the gh/git-derived sections and says so; with `gh` unavailable or unauthed it
skips the GitHub-derived sections and still prints the git-derived ones.

Read the numbers as a trend, not a target. A high needs-revision rate or a
falling fresh-review pass rate says the briefs are slipping (the load-bearing
variable) — look there first. Revert/hotfix on the base branch is a heuristic
(a grep of commit subjects); treat a non-zero count as a prompt to look, not a
proof of breakage.

## The write side (how the log fills)

The `fix-issue` orchestrator calls `scripts/emit-event.sh` at four points —
dispatch, a held brief, a review verdict, a finalized outcome — appending one
JSON line to the local log. The orchestrator writes it from the main session,
never a worktree agent, and the helper excludes it locally via
`.git/info/exclude` so it is never committed (the same conflict-avoidance
discipline as the outcomes log). You do not run `emit-event.sh` by hand; it is
wired into `fix-issue`. See `references/events-schema.md` for the event types.

## Notes

- **No external service.** Everything is local files + read-only `gh`/`git`. The
  team-scale usage collector (per-dev sessions, model mix, a Notion rollup) is
  deliberately *not* here — that measures adoption across people, which is the
  team program's concern, not this methodology's.
- **Honest about what it can't see.** Hand-fixed issues that never went through
  `fix-issue` won't appear in the autonomous-quality section (no dispatch event);
  they still show up in the derived backlog/throughput numbers via GitHub.
