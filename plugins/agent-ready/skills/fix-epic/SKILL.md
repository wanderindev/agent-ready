---
name: fix-epic
description: "Execute a GitHub epic in pair-mode — work its constituent issues together as one coherent session, on a single branch/PR, in dependency order, closing each issue and the epic when done. Invoked as \"/fix-epic <epic_id>\". Use when the operator says any of \"fix epic N\", \"work epic N\", \"let's do epic N\", \"resolve the epic\", \"start on epic N\", or wants to work a pre-grouped cluster of related issues collaboratively. This is the pair-mode counterpart to fix-issue (which dispatches single agent-friendly issues autonomously); fix-epic deliberately keeps the whole cluster in one pair session for low merge friction. Works on any epic — whether created by plan-epic or during the audit."
---

# fix-epic

Drives an existing epic to completion in one collaborative session. The pilot's
most productive mode — and the honest conclusion of its retrospective — was
working a cluster of related issues together rather than fanning them out to
parallel autonomous agents. Parallel dispatch worked but produced **merge
friction** (N PRs against a moving `main`); the clustered single-session
approach gave better visibility and far less friction. This skill codifies it.

It is the deliberate counterpart to `fix-issue`:

| | `fix-issue` | `fix-epic` |
|---|---|---|
| Mode | autonomous dispatch | pair-mode, in-session |
| Unit | one agent-friendly issue | a cluster (epic) |
| Output | one PR per issue, parallel worktrees | **one coherent branch/PR for the cluster** |
| Merge friction | per-PR, against moving main | minimal — issues land together |

## Prerequisites

- Run from the target repo root. `gh` authenticated.
- An epic issue with a `- [ ] #N` task-list body (from `plan-epic` or the audit).

## Workflow

### Step 1 — Load the epic
Read the epic's scope and extract its constituents in order:
```
bash "${CLAUDE_PLUGIN_ROOT}/skills/fix-epic/scripts/epic-constituents.sh" <epic#>
```
Then `gh issue view` the epic for the scope statement and each constituent for
its body.

### Step 2 — Second-pass verification (the reliability mechanism)
For **each** constituent, re-verify the issue's claims against the *current*
source before any plan is written — the two-pass discipline the case study
credits for fix accuracy (the audit was pass one; this is pass two). Surface:
stale line numbers, APIs the issue assumes that don't exist, edge cases, and any
change the existing test suite won't cover. The issue body may be weeks old; the
source is ground truth, and the plan is the reconciliation.

### Step 3 — Propose an execution order
Respect intra-epic linchpins (a prerequisite issue before the ones it gates).
**Surface which constituents are `agent-friendly`** for visibility — but do NOT
auto-dispatch them; this is pure pair-mode by design. Get the operator's nod on
the order before writing code.

### Step 4 — Work the cluster on one branch
Branch off the (protected) default branch. Resolve the constituents in order, a
commit (or small group) per issue, so related changes stay coupled and
reviewable together. Keep tests and lint green as you go. If a constituent turns
out to be blocked or wrong, stop and surface it rather than forcing it — and
re-scope the epic with the operator.

### Step 5 — One PR for the epic
Open a single PR that `Closes #N` for each constituent **and** the epic issue,
with a description mapping commits to issues. Split into a small number of PRs
only if the cluster genuinely decomposes — the default is one. Let CI run; never
self-merge (the operator merges).

### Step 6 — Close out
After the operator merges, the constituents and the epic auto-close. Confirm the
epic's task list is fully checked; if any box is unchecked, the epic isn't done.

## Principles / gates

- **Two-pass verification before planning** — never implement from the issue body
  alone.
- **One coherent branch/PR for the cluster** — the low-friction win; do not fan
  out to parallel worktrees.
- **Pure pair-mode** — surface agent-friendly constituents, never auto-dispatch.
- **Respect linchpin order** within the epic.
- **Standard guardrails** — branch off the protected default branch, tests + lint
  pass before the PR, never push directly to the protected branch, never
  self-merge.
- **Don't close the epic early** — it closes when every constituent has landed.

## Provenance of the epic

Accepts any epic with the `epic` label and a task-list body, whether created by
`plan-epic` (fix-time clustering) or by `area-audit` (audit-time grouping).

## Files this skill uses

- `scripts/epic-constituents.sh` — extract constituent issue numbers in order.
