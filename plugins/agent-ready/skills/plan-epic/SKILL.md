---
name: plan-epic
description: "Group open GitHub issues into a workable epic. Scans the open backlog high→low by severity, proposes 2–3 candidate epics (clusters of issues that make sense to resolve together), lets the operator pick one, then creates the GitHub epic issue linking the constituents in execution order. Invoked when planning what to work on next. Use when the operator says any of \"plan an epic\", \"what should we work on next\", \"propose some epics\", \"group these issues\", \"cluster the backlog\", \"suggest a few epics from the open issues\", or wants the next chunk of work scoped. Proposes then confirms before creating anything. Pairs with fix-epic, which executes the result."
---

# plan-epic

Turns an overwhelming backlog into the next workable chunk. The methodology's
backlog insight is **cluster-not-individual**: N issues are overwhelming; the
same N seen as a handful of clusters are not. This skill is the *planning* half
of the clustered pair-mode path; `fix-epic` is the *execution* half.

## Prerequisites

- Run from the target repo root. `gh` authenticated; `jq` available.
- The `epic` label exists (created by `repo-bootstrap`).

## Workflow

### Step 1 — Rank the backlog
```
bash "${CLAUDE_PLUGIN_ROOT}/skills/plan-epic/scripts/rank-backlog.sh"
```
Lists open issues (epics excluded) high→low by severity, flagging which are
`agent-friendly`. Clustering starts from the top of this list.

### Step 2 — Propose 2–3 candidate epics
Each candidate is a **cluster**, not an arbitrary group. The cluster boundary is
the synthesis's rule: **"if you fix one without the others, you do the others'
work badly."** Good cluster seeds:
- same code area / module
- shared root cause or a half-applied pattern across sites
- a **linchpin** that gates several issues (sequence it first within the epic)

For each candidate present: a name, the constituent issue numbers (with
severities), a one-line rationale for why they belong together, the intended
intra-cluster order (linchpins first), and a rough size. Bias toward clusters
anchored on the highest-severity open issues.

### Step 3 — Operator picks
Surface the candidates; let the operator choose one, adjust membership, or ask
for different cuts. **Create nothing until the operator confirms.**

### Step 4 — Create the epic
```
bash "${CLAUDE_PLUGIN_ROOT}/skills/plan-epic/scripts/create-epic.sh" \
     "<epic title>" "<one-line scope>" <issue#> <issue#> ...
```
Pass the constituents **in execution order** — that order becomes the epic's
task list, which `fix-epic` inherits. The script labels it `epic`, builds the
`- [ ] #N — title` body, and prints the new epic's URL.

### Step 5 — Hand off
Report the new epic number and tell the operator to run
`/agent-ready:fix-epic <id>` to execute it.

## Principles

- **Severity-ordered.** Clustering starts at the top of the severity stack;
  never bury a critical inside a nice-to-have epic.
- **Real clusters only.** Don't pad to hit a count — two tightly-coupled issues
  beat five loosely-related ones.
- **Bounded scope.** Keep an epic small enough to finish in a focused session;
  the "productive from minute one" payoff depends on it.
- **Respect linchpins.** Encode prerequisite order in the task list.
- **Propose, then confirm.** Never auto-create.

## Relationship to the audit

`area-audit` groups findings by *area* at audit time and can stamp an epic per
cluster there. `plan-epic` is the *fix-time* path: it re-clusters the live
backlog by severity across areas, catching groupings the per-area audit didn't.
Both produce epics that `fix-epic` executes — complementary entry points, not
alternatives.

## Files this skill uses

- `scripts/rank-backlog.sh` — severity-ranked open backlog.
- `scripts/create-epic.sh` — create the epic with an ordered task-list body.
