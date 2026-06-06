---
name: fix-epic
description: "Execute a GitHub epic in pair-mode — work its constituent issues together as one coherent session, on a single branch/PR, in dependency order, closing each issue and the epic when done. Invoked as \"/fix-epic <epic_id>\". Use when the operator says any of \"fix epic N\", \"work epic N\", \"let's do epic N\", \"resolve the epic\", \"start on epic N\", or wants to work a pre-grouped cluster of related issues collaboratively. This is the pair-mode counterpart to fix-issue (which dispatches single agent-friendly issues autonomously); fix-epic deliberately keeps the whole cluster in one pair session for low merge friction. Works on any epic — whether created by plan-epic or during the audit. STATUS: scaffold — not yet implemented."
---

# fix-epic

> **STATUS: scaffold.** Specified, not yet implemented. The design below is the
> build target.

## Why this exists

The pilot's most productive mode — and the honest conclusion of its
[retrospective](../../../../case-study/) — was working a cluster of related
issues together in one pair session rather than fanning them out to parallel
autonomous agents. Parallel dispatch worked but produced **merge friction**
(N PRs against a moving `main`); the clustered single-session approach gave
better visibility and far less friction. `fix-epic` codifies that mode.

It is the deliberate counterpart to `fix-issue`:

| | `fix-issue` | `fix-epic` |
|---|---|---|
| Mode | autonomous dispatch | pair-mode, in-session |
| Unit | one agent-friendly issue | a cluster (epic) |
| Output | one PR per issue, parallel worktrees | **one coherent branch/PR for the cluster** |
| Merge friction | per-PR, against moving main | minimal — issues land together |

## What this skill will do

Drive an existing epic to completion in a single collaborative session.

## Planned workflow

1. **Load the epic.** `gh issue view <id>` — read the scope and extract the
   constituent issue numbers from the task list.
2. **Second-pass verification (the reliability mechanism).** For each
   constituent, re-verify the issue's claims against the *current* source before
   any plan is written — the same two-pass discipline the case study credits for
   fix accuracy. Surface discrepancies, edge cases, and any change that won't be
   covered by the existing test suite. This is where the issue body (possibly
   weeks old) gets reconciled against the code as it is now.
3. **Propose an execution order.** Respect intra-epic linchpins (a prerequisite
   issue before the ones it gates). **Surface which constituents are
   `agent-friendly`** for visibility — but do NOT auto-dispatch them (pure
   pair-mode by design). Get the operator's nod on the order.
4. **Work the cluster on one branch.** Branch off the (protected) default
   branch. Resolve the constituents in order, a commit (or small group) per
   issue, so related changes stay coupled and reviewable together. Keep tests
   and lint green as you go.
5. **One PR for the epic.** Open a single PR that `Closes #N` for each
   constituent and the epic issue, with a description that maps commits to
   issues. (Split into a small number of PRs only if the cluster genuinely
   decomposes — the default is one.)
6. **Close out.** After the operator merges, the constituents and the epic
   auto-close. Confirm the epic's task list is fully checked.

## Principles / gates to encode

- **Two-pass verification before planning** — never implement from the issue
  body alone.
- **One coherent branch/PR for the cluster** — the low-friction win; do not fan
  out to parallel worktrees.
- **Pure pair-mode** — surface agent-friendly constituents, never auto-dispatch.
- **Respect linchpin order** within the epic.
- **Standard guardrails** — branch off the protected default branch, tests +
  lint pass before the PR, never push directly to the protected branch, never
  self-merge (the operator merges).
- **Don't close the epic early** — it closes when every constituent has landed.

## Provenance of the epic

Accepts any epic with the `epic` label and a task-list body, whether created by
`plan-epic` (fix-time clustering) or by `area-audit` (audit-time per-area
grouping).
