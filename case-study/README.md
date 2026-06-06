# Case study — the pilot that produced this methodology

This is the worked example the [Agent Ready](../README.md) methodology was
extracted from: the **Panama In Context (PIC)** audit-to-autonomy run
(March–June 2026), which took a stalled, vibe-coded bilingual content-and-booking
site to **138 issues filed and closed, 165 PRs merged, zero breakages of `main`**.

Everything here keeps PIC's **real numbers and names** — it is the proof and the
calibration anchor. The codebase-agnostic abstraction lives under
[`plugins/agent-ready/`](../plugins/agent-ready/). When a worked example in the
skills or methodology docs points to "the pilot," this is where the full instance
lives.

## The narrative spine

| Document | What it is |
|---|---|
| [retrospective.md](retrospective.md) | First-person account of the whole journey — the continuity/clarity win, the two-pass verification mechanism, the pivot from parallel autonomy to clustered pairing, and why `main` never broke. |
| [pilot/phase-1-synthesis.md](pilot/phase-1-synthesis.md) | The auditing-phase methodology, v1 — the 10-slot template, the automatability map, the cross-cutting checklist, the reference-document types. |
| [pilot/phase-2-addendum.md](pilot/phase-2-addendum.md) | The fixing-phase methodology, v1 — brief-tightness, the agent-vs-brief taxonomy, the failure-mode escape hatch, the three-layer auto-approve fence. |
| [pilot/public-article.md](pilot/public-article.md) | The tight autonomous-agent thesis (16 PRs, zero interventions). |

## The corpus (ground truth)

| Directory | Contents |
|---|---|
| [pilot/](pilot/) | Phase 0 + Phase 1: the audit plan, the nine area reports, the synthesis, the verbatim prompt corpus (`pilot/prompts/`), the agent-friendly criteria, the backlog snapshot. |
| [phase-2/](phase-2/) | Phase 2: the 21 fixing-session reports, the verbatim prompts (`phase-2/prompts/`), and the agent-friendly outcomes log (16 autonomous runs). |
| [agent-fixes/prompts/](agent-fixes/prompts/) | Phase 3: the `fix-issue` autonomous-fix briefs (the local-only outcomes log is intentionally omitted). |

The verbatim prompt corpora are the methodology's primary source — the
[conventions](../plugins/agent-ready/assets/methodology/conventions.md) name
"preserve every session's verbatim prompt" as a load-bearing practice, and these
directories are why the synthesis was possible.

> Note: internal cross-references inside these archived documents use the original
> pilot repository's `docs/` layout (e.g. `docs/pilot/...`). They are preserved
> verbatim as historical record rather than rewritten to this repo's paths.
