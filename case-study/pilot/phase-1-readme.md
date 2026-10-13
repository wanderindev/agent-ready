# Phase 1 — Audit & Backlog

**Goal:** Walk the codebase end-to-end, file every finding as a GitHub issue, label and route it, and produce a triaged backlog. **Phase 1 does not fix things.** Fixes happen in Phase 4 and later, against the issues filed here.

Two exceptions to "no fixes" — see [Stop the line](agent-friendly-criteria.md#stop-the-line) in the agent-friendly criteria doc.

---

## How the labels work

Apply **at most one severity** label per code-quality issue, plus `agent-friendly` independently if it qualifies.

| Label | When to apply |
|---|---|
| `bug` | An actual defect (filed via the Bug report template). Default GitHub label. |
| `enhancement` | A new feature or significant enhancement (Feature request template). Default GitHub label. |
| `code-quality:critical` | Real risk to security, data integrity, or production stability. Should be on a near-term roadmap even if not fixed this week. |
| `code-quality:moderate` | Meaningful tech debt — costs time, increases risk, but the sky is not falling. The bulk of Phase 1 findings will land here. |
| `code-quality:nice-to-have` | Cosmetic or low-impact. We may never get to these; that's fine. |
| `agent-friendly` | The work is scoped for autonomous agent execution. See [agent-friendly-criteria.md](agent-friendly-criteria.md). Orthogonal to severity — a `critical` issue can be `agent-friendly`. |

---

## How the templates map to the work

Four templates live in [`.github/ISSUE_TEMPLATE/`](../../.github/ISSUE_TEMPLATE/):

- **Bug report** → bugs found in production or local testing. Auto-applies `bug`.
- **Feature request** → net-new features or significant enhancements. Auto-applies `enhancement`.
- **Code quality** → refactors, tech debt, drift, code smells. The Phase 1 workhorse. Apply one `code-quality:*` label after filing.
- **Agent task** → work specifically scoped for agent execution. Auto-applies `agent-friendly`. The template's checkbox section forces a criteria check before submission.

Blank issues are disabled. If none of the templates fit, that's a signal the work doesn't belong in this repo yet — write it up in the session output instead.

---

## Determining `agent-friendly`

Read [`agent-friendly-criteria.md`](agent-friendly-criteria.md). All six criteria must hold. The doc has worked examples for clear-yes, clear-no, and borderline cases.

If borderline, **don't** apply the label. The cost of a human pairing on the work once is far lower than the cost of an agent making a quiet wrong call in a sensitive area.

---

## What Phase 1 explicitly does NOT do

- **No fixes** beyond stop-the-line.
- **No refactors**, even tiny ones, "while we're in the file."
- **No new features.**
- **No schema migrations.**
- **No opening issues for hypothetical future problems** — only for things that exist today.

If you find yourself wanting to fix something, file the issue and move on. The discipline of the audit is what makes the resulting backlog trustworthy.

---

## Pointers

- [Phase 0 report](phase-0-report.md) — what's already been done and the deferred backlog Phase 1 inherits.
- [Agent-friendly criteria](agent-friendly-criteria.md) — the rubric and the stop-the-line policy.
- [Issue templates](../../.github/ISSUE_TEMPLATE/) — the four YAML forms and their config.

When Phase 1 ends, the deliverable is a labeled GitHub backlog and a Phase 1 report following the same shape as the Phase 0 report.
