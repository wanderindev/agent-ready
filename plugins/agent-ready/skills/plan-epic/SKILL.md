---
name: plan-epic
description: "Group open GitHub issues into a workable epic. Scans the open backlog high→low by severity, proposes 2–3 candidate epics (clusters of issues that make sense to resolve together), lets the operator pick one, then creates the GitHub epic issue linking the constituents. Invoked when planning what to work on next. Use when the operator says any of \"plan an epic\", \"what should we work on next\", \"propose some epics\", \"group these issues\", \"cluster the backlog\", \"suggest a few epics from the open issues\", or wants the next chunk of work scoped. Proposes then confirms before creating anything. Pairs with fix-epic, which executes the result. STATUS: scaffold — not yet implemented."
---

# plan-epic

> **STATUS: scaffold.** Specified, not yet implemented. The design below is the
> build target. This codifies a workflow the pilot operator did by hand every
> session but never saved as a skill.

## Why this exists

The methodology's central backlog insight is **cluster-not-individual**: a
backlog of N issues is overwhelming; the same backlog seen as a handful of
clusters is not. The pilot's most productive mode was working a cluster of
related issues together in one coherent pair session (see the
[case study](../../../../case-study/) — the retrospective's load-bearing
finding). This skill is the *planning* half of that mode; `fix-epic` is the
*execution* half.

## What this skill will do

Turn the open backlog into a proposed epic the operator can immediately work.

## Planned workflow

1. **Gather the backlog.** `gh issue list --state open --json
   number,title,labels,body` (exclude existing epics). Order high→low by
   severity (`code-quality:critical` → `moderate` → `nice-to-have`, plus `bug`),
   so clustering starts from what matters most.
2. **Propose 2–3 candidate epics.** Each candidate is a *cluster*, not an
   arbitrary group. The cluster boundary is the synthesis's rule: **"if you fix
   one without the others, you do the others' work badly."** Good cluster seeds:
   same code area, shared root cause, a linchpin that gates several issues, the
   same half-applied pattern across sites. For each candidate, present: a name,
   the constituent issue numbers (with severities), a one-line rationale for why
   they belong together, any intra-cluster ordering (linchpins first), and a
   rough size. Bias toward clusters anchored on the highest-severity open issues.
3. **Operator picks.** Surface the candidates and let the operator choose one,
   adjust membership, or ask for different cuts. **Create nothing until the
   operator confirms** (batch-and-confirm discipline).
4. **Create the epic.** `gh issue create` with the `epic` label, a title, a short
   scope statement, and a task-list body (`- [ ] #N — title`) listing the
   constituents in execution order. Optionally cross-link the epic from each
   constituent for traceability.
5. **Hand off.** Report the new epic number and tell the operator to run
   `/agent-ready:fix-epic <id>` to execute it.

## Principles to encode

- **Severity-ordered.** Clustering starts from the top of the severity stack;
  don't bury a critical inside a nice-to-have epic.
- **Real clusters only.** Don't pad an epic to hit a count. Two tightly-coupled
  issues are a better epic than five loosely-related ones.
- **Bounded scope.** Epics should be small enough to finish in a focused
  session — the "productive from minute one" payoff depends on it.
- **Respect linchpins.** If constituents have prerequisite relationships, encode
  the order in the task list so `fix-epic` inherits it.
- **Propose, then confirm.** Never auto-create the epic.

## Relationship to the audit

`area-audit` groups findings by *area* at audit time and can stamp an epic per
cluster there. `plan-epic` is the *fix-time* path: it re-clusters the live
backlog by severity across areas, which catches groupings the per-area audit
didn't. Both produce epics that `fix-epic` executes — they are complementary
entry points, not alternatives.
