# Cross-session register

This register records **cross-session decisions** made during a multi-area audit — the judgments that live outside any single session's prompt and shape how the audit's areas are ordered, split, paused, or extended.

The register's role is to provide the **input data** for the eventual orchestration / meta-process artifact (synthesis §9 Artifact 5, deferred until after a second codebase). The pilot's cross-session decisions survive only in the orchestrator's memory and in scattered process-notes sections of area reports. The next codebase onward needs this data captured deliberately. Two data points (the pilot + a second codebase) is the minimum baseline from which to build the orchestration artifact; one data point would lock in pilot-specific habits.

## What goes in the register

Any decision the operator makes **between sessions** that shapes the audit's structure. The kinds the synthesis §4 names as load-bearing:

- **Area ordering** — including reordering mid-audit.
- **Area splits** — when an area gets broken into sub-areas during the run.
- **Stop-the-line detour scope** — whether to fix inline within an area or carve out a separate session.
- **Mid-audit deliverable introduction** — adding a new required output to subsequent area reports.
- **Investment in a new reference-document type** — promoting a one-off shape into a recurring deliverable.
- **Re-scope events** — when a session's findings exceeded its upper-bound trigger and the audit-plan got revisited.

Day-to-day prompt-construction decisions and within-session corrections do NOT go here — those live in the session's own prompt and report.

## What does NOT go in the register

- Per-session findings, severities, agent-friendly calls. Those go in the issue tracker and the area report.
- Self-corrections the agent made inside a session before sending for approval. Those are not overrides — only operator-driven adjustments count, and per-session overrides go in the area report's **override register** (see [reference-document-types/](./reference-document-types/) for placement), not here.
- Process notes about how a single session ran. Those go in that session's report's "Process notes" section.

## Convention: append after each session

After each session report is filed, before moving to the next area, append any cross-session decisions made during or after that session. Do not batch — context rolls and details degrade with time.

Convert relative dates to absolute when recording. "Thursday" → the actual date. The register lives across multi-month timelines; relative dates lose meaning.

## Format

A markdown table. Six columns. Append rows in chronological order.

| Date | Session / context | Cross-session decision | What prompted it | What was decided | Overrode agent? |
|---|---|---|---|---|---|

Column notes:

- **Date** — absolute (YYYY-MM-DD).
- **Session / context** — the session being run when the decision crystallized, OR "between {N} and {N+1}" for between-session decisions.
- **Cross-session decision** — short phrase naming the decision (e.g. "split Area 4 into 4a/4b-1/4b-2/4c").
- **What prompted it** — the signal that triggered the decision. The signal IS the data the orchestration artifact will eventually be built from.
- **What was decided** — the resolution. Concrete enough that a reader six months later can act on it.
- **Overrode agent?** — yes/no. Did the operator override an agent proposal? (e.g. agent proposed "4a → 4b → 4c"; operator decided "4a → 4c → 4b". That's a yes.)

## The register

| Date | Session / context | Cross-session decision | What prompted it | What was decided | Overrode agent? |
|---|---|---|---|---|---|

_(empty — append your first session's cross-session decisions here)_

---

## A note on retroactive backfilling

The synthesis §10 names retroactive recollection as an explicit risk: "retroactive recollection across multi-week audits is not reliable enough to falsify anything." Backfilling a phase's entries in full from memory reproduces that problem at one degree of remove.

The register's value compounds forward. Append in real time rather than reconstructing after the fact. By the time three or four phases of cross-session decisions exist, the patterns the orchestration artifact (synthesis §9 Artifact 5) is meant to encode will be visible. Until then, append rather than infer. (The pilot's own populated register — including its honest record of where the convention slipped — lives in the case study as a worked example.)

## Cross-references

- [conventions.md](./conventions.md) names "keep the cross-session register current" as one of the two load-bearing methodology practices.
- Per-session overrides (severity, agent-friendly, scope, area-split) go in each area report's **override register**, not here. See [reference-document-types/](./reference-document-types/) and `../../skills/area-audit/references/report-shape.md`.
- The case study's synthesis §9 Artifact 5 is the eventual artifact this register feeds.
