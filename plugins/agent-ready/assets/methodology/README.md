# Methodology

This directory holds the area-audit methodology in its **portable, codebase-agnostic form**. It is the shareable unit: a clean copy of this directory is all a new codebase needs to inherit the methodology.

The methodology was extracted from a 14-session audit pilot. The pilot's full materials live in the case study (this repo's `case-study/` directory) — the prompts, the area reports, the synthesis. This directory is what the pilot produced as **reusable** output; the case study is the worked example the methodology was built from.

Pilot-specific content (worked examples, vendor names, file paths) inside this directory is tagged so a future installation pass can find and swap it when adopting the methodology for a new repo. The structure is intentionally codebase-agnostic; the examples are the calibration anchors that make the structure useful. The `methodology-install` skill performs that swap — it copies this directory into the adopting repo and walks the tagged blocks so they can be replaced with the new repo's domain-appropriate equivalents.

## What's in this directory

| File / directory | What it is |
|---|---|
| [prompt-template.md](./prompt-template.md) | The 10-slot area-audit prompt as a fill-in form, with the four named adaptations as switchable headers, plus a snippet library for cross-session investments |
| [reference-document-types/](./reference-document-types/) | Eight specs for the reference documents an area audit may produce alongside its issue backlog (service surface map, vendor failure-mode summary, intended-vs-actual matrix, per-area call graph, swallowed-exceptions catalogue, fix-ordering analysis, global-ordering bridge, forensic verdict) |
| [cross-cutting-checklist.md](./cross-cutting-checklist.md) | The cross-cutting findings checklist — patterns one audit found by accident that future audits should look for on purpose |
| [cross-session-register.md](./cross-session-register.md) | Scaffolding for the cross-session decision log — the data the eventual orchestration artifact will be built from |
| [conventions.md](./conventions.md) | The two load-bearing methodology practices: preserve every session's verbatim prompt; keep the cross-session register current |
| [agent-friendly-criteria.md](./agent-friendly-criteria.md) | The authoritative criteria for whether an issue should be labelled `agent-friendly` |

The companion to this directory is the **area-audit skill**, installed at `../../skills/area-audit/`. The skill is the interactive entry point — it walks the operator through the 10-slot template and refuses to emit a complete prompt until the per-area fills are supplied. The prompt template in this directory is the same skeleton in copy-and-edit form, for operators who prefer the document over the interactive walkthrough.

## What the methodology is

The methodology is a structured approach to auditing an existing codebase, area by area, with an agent. Its core claim — calibrated to one codebase, one agent, one orchestrator, and explicitly v1 — is the **two-layer pattern**:

- **Per-session execution** is highly autonomous when the prompt is well-constructed. Across the pilot's 9 area-audit sessions and ~110 filed issues, the operator overrode the agent's judgment on the order of twice (severity calibration; agent-friendly classification; in-area-vs-newly-observed scope). The agent's judgment was sound *within a well-constructed prompt*.

- **Constructing the prompt** is the cross-session human work. The 10-slot skeleton transfers; the fills (severity examples grounded in the area, stop-the-line triggers as concrete vulnerabilities, agent-friendly examples specific to the area's code shape) are irreducibly per-area.

The methodology's primary automation target is therefore not audit execution — it is audit **design and orchestration**. The area-audit skill encodes the skeleton and demands the fills; the prompt template surfaces the same skeleton; the reference-document types surface the per-area deliverables alongside the issue backlog; the cross-session register collects the data the eventual orchestration artifact will need.

## What the methodology is NOT

- Not a checklist. Reading any of these documents as a checklist would be a misuse — the methodology is a starting position, not a destination.
- Not finished. It is explicitly v1, calibrated to the pilot. Every claim is a hypothesis the next 3–5 codebases will test rather than a law.
- Not a substitute for cross-session judgment. Area ordering, stop-the-line detour scope, mid-audit deliverable introduction, area splits — these are explicitly human decisions the synthesis identifies as load-bearing. The methodology scaffolds them; it does not replace them.
- Not an executable thing. The methodology does not run; it briefs sessions that do.

## What's deferred — by design

One artifact the synthesis specified is **deliberately deferred**:

| Deferred artifact | Why |
|---|---|
| The orchestration / meta-process artifact (synthesis §9 Artifact 5) | **Deliberately deferred** until after a second codebase. Building it now from the pilot alone would lock in pilot-specific habits that a second repo might immediately need to override. The cross-session register in this directory is the *input data* for the eventual Artifact 5, not a substitute for it. |

The methodology's claims are explicit hypotheses; the next codebase is the test plan, not a confirmation.

## Cross-references

- The case study's synthesis (`case-study/pilot/phase-1-synthesis.md`) — the synthesis document this methodology was extracted from. Read it for the *reasoning* behind the methodology's shape; read this directory for the *form* the reasoning takes.
- The case study's prompt corpus (`case-study/pilot/prompts.txt`) — the corpus the methodology was extracted from. The corpus is the ground truth; this directory is the abstraction.
- The case study's area reports (`case-study/pilot/phase-1-area-*-report.md`) — the reports that produced the reference-document types. Each report contains a real instance of one or more of the document types specified in [reference-document-types/](./reference-document-types/).
- `../../skills/area-audit/` — the interactive skill that walks an operator through scaffolding an area-audit prompt.

## Adopting this directory for a new repo

When a new codebase begins its first area audit using this methodology (the `methodology-install` skill automates these steps):

1. Copy this `methodology/` directory into the new repo's documentation tree.
2. Make the area-audit skill available to the new repo.
3. Scan all files for `PIC-WORKED-EXAMPLE` blocks and replace each with the new repo's domain-appropriate equivalent. The block structure stays; the content changes.
4. Set up the new repo's `{phase-name}/prompts/` directory (per [conventions.md](./conventions.md)'s first practice).
5. Start the cross-session register ([cross-session-register.md](./cross-session-register.md)) empty — it ships empty, ready for the new repo's first session.

The installation pass is the methodology's seam between the pilot and the next codebase. The structure transfers verbatim; the domain content does not.
