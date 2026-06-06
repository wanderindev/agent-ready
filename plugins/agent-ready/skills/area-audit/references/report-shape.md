# End-of-session report shape

The report is the audit's primary written deliverable alongside the issue backlog. It serves three audiences: the operator (who reads it end-to-end), the next area's session (which cites the "newly observed" subsections as input), and the eventual synthesis (which composes process notes and surprises across sessions).

## Standard sections — present in every report

These appear in every area-audit report, regardless of adaptation. Adjust depth per area but never skip.

1. **Executive summary** — 3-6 sentences. The headline finding(s), the area's overall posture, what the operator most needs to know.
2. **By the numbers** — counts: issues filed, severity distribution, agent-friendly count, hours spent, files read in full, prod queries run.
3. **What was audited** — the actual reading list. Split by sub-area (backend / frontend / models / etc.) and note files read in full vs. files only spot-checked. Include prod queries (count, what they returned in aggregate).
4. **Item-by-item findings** — table or per-finding section. Issue number, title, severity, agent-friendly classification.
5. **Stop-the-line discussion** — explicit, even when there were none. State whether any finding met the stop-the-line bar; if none did, say so and briefly why (e.g. "the regen-overwrite bug is data-destruction-shaped but not actively corrupting prod"). If one did, document the inline fix and the decision logic.
6. **What's filed vs. deferred** — every finding either gets a filed issue or a documented reason for deferral. No silent drops.
7. **Newly observed — for other audit areas** — subsections per future area (`### For Area N+1`, `### For Area N+k`, `### Cross-area / for whenever`). The next area's prompt cites these as inputs to verify, not findings to rediscover.
8. **What surprised me** — the audit's most valuable section. Surprises ARE the load-bearing results. Where did the orchestrator's priors fail? What turned out cleaner than expected? Where did a prod query change the severity calibration?
9. **Process notes for the next area** — methodology calibration. What worked in this prompt that should carry forward. What didn't.

## Area-specific required additions — a menu

Pick one or more from the menu below based on the area's nature. Each maps to a reference-document-type spec in the methodology docs' `reference-document-types/` directory (installed by the methodology-install skill, default `docs/methodology/`).

| Required addition | When to require it | Spec |
|---|---|---|
| **Service surface map** | Area covers a large set of modules that need to be sliced before the deep read; classification → defer-with-rationale shape | `service-surface-map.md` |
| **Vendor failure-mode summary** | Area owns external integration boundaries; per-vendor matrix of behavior on success/error/timeout/outage | `vendor-failure-mode-summary.md` |
| **Intended-vs-actual matrix** (auth / public-error / admin-route / other invariants) | Area's findings are mostly deviations from an invariant; build the invariant first, then count deviations | `intended-vs-actual-matrix.md` |
| **Per-area call graph** | Area is structurally a set of flows that share infrastructure; most findings live in seams | `per-area-call-graph.md` |
| **Structured catalogue** (swallowed exceptions, dependency drift, etc.) | Systematic-sweep adaptation is active | `swallowed-exceptions-catalogue.md` |
| **Fix-ordering analysis** | Area's backlog is large enough that order matters; cluster-not-individual framing | `fix-ordering-analysis.md` |
| **Global-ordering bridge section** | This is not the first area to produce a fix-ordering; the bridge composes with prior orderings | `global-ordering-bridge.md` |
| **Forensic verdict** | Forensic-first adaptation is active | `forensic-verdict.md` |

Order in the report: standard section 4 (item-by-item findings), then standard section 5 (stop-the-line), then the area-specific additions, then the rest of the standard sections. Stop-the-line goes before the additions because it's the most time-sensitive read; the additions belong after the findings they contextualize.

## REQUIRED: the override register

**This block must appear in every report from repo 2 onward.** It is the falsifiability hook the methodology owes itself — see the case study's Phase 1 synthesis §10 note on instrumentation.

The §4 autonomy claim ("the agent's judgment was sound within a well-constructed prompt; override rate across 110 issues was on the order of twice") is the methodology's most consequential and most fragile claim. It cannot be checked against a new repo without measuring it deliberately. Generic recollection across multi-week audits is not data.

### Block to include in Slot 8 of the prompt

> **Required: override register.** At the end of the session report, include a section titled "Override register" with two parts:
>
> 1. **Counts.** A simple table:
>
>    | Override type | Count |
>    |---|---|
>    | Severity (proposed → adjusted by operator) | 0 |
>    | Agent-friendly (proposed → adjusted by operator) | 0 |
>    | Scope (in-area vs newly-observed call, adjusted by operator) | 0 |
>    | Area-split or area-ordering (adjusted by operator) | 0 |
>
> 2. **One-liners.** For each override, one line: what was proposed, what it became, why. Example: *"#NN proposed moderate, adjusted to critical because the live prod row count argues the bug is currently triggering."* If there were zero overrides in a category, write *"none."*
>
> The register's purpose is to test whether the methodology's autonomy claim survives this codebase. Record every override, including small ones. If you reflexively self-correct a proposal before sending it for approval, that is *not* an override (the agent corrected itself); only operator-driven adjustments count.

### Why this block matters

Without per-session override counts, the audit's most consequential claim (§4 autonomy) cannot be falsified by repo 2 or any subsequent repo. The register is small, mechanical, and high-signal. It is the difference between "recollection" and "data" — and the difference between a v1 methodology and a methodology that can survive contact with a second codebase.

If the operator pushes back ("seems bureaucratic"), surface the reasoning above: the methodology made the claim; the methodology owes itself the measurement. The register's presence is non-negotiable.

## REQUIRED: the cross-cutting checklist dispositions

**This block must appear in every report from repo 2 onward**, immediately after the override register. It is the second falsifiability hook the methodology owes itself — see the case study's Phase 1 synthesis §8 (the six items as hypotheses) and §9 Artifact 4 (the spec this block fulfills).

The §8 hypotheses are one-codebase evidence. They cannot be confirmed-as-general or revealed-as-pilot-specific without **per-area prevalence data** from repo 2 onward. The dispositions are how that data lands in the durable record — even when most items come back "checked, absent," the record carries the disconfirmation evidence that the next synthesis needs. The discipline of running the checklist matters as much as the items themselves; the block ensures the discipline produces a written output.

The authoritative checklist is the methodology docs' `cross-cutting-checklist.md` (installed by the methodology-install skill, default `docs/methodology/`). The skill-side enforcement (the closing gate that refuses to mark an area complete without the block) is documented in `references/cross-cutting-checklist.md`.

### Block to include in Slot 8 of the prompt

> **Required: cross-cutting checklist dispositions.** At the end of the session report, include a section titled "Cross-cutting checklist dispositions" with two parts.
>
> **Part 1 — Pattern items (5 rows).** One disposition per item; use the vocabulary exactly:
>
>    | Item | Disposition | Notes |
>    |---|---|---|
>    | 1. Partial-correction debt | fired / checked, absent / N/A | issue numbers if fired; one-line why if N/A |
>    | 2. Swallowed-failure umbrella | fired / checked, absent / N/A | issue numbers if fired; tracking-issue reference if rolled up |
>    | 3. Danger isn't where complexity is | fired / checked, absent / N/A | which simple code was read; one-line outcome |
>    | 4. Two-dimensional severity | fired / checked, absent / N/A | dormant-vs-live ordering note for any criticals filed |
>    | 5. Latent-but-uncrystallized risk | fired / checked, absent / N/A | "becomes live if X" flag-bit for severity-lowered findings |
>
>    The vocabulary distinguishes:
>    - **fired** — the pattern was found in this area; record issue numbers.
>    - **checked, absent** — sought, not found; this is prevalence data, the point of the discipline.
>    - **not applicable** — the item structurally can't apply here, with a one-line why; distinct from absent (coverage scope vs. prevalence data — do not collapse).
>
> **Part 2 — Orchestrator's priors (short paragraph).** A short structured note with three parts:
>
>    - **Priors stated** — the priors the operator wrote down before this area (often in Slot 3 / Slot 5).
>    - **Priors that held** — evidence the orchestrator's mental model was calibrated.
>    - **Priors that broke** — the surprises; these are the audit's most valuable findings.
>
>    If no priors were stated for this area, say so explicitly — *"No priors stated for this area"* is itself a valid disposition. Silence is not.
>
> The block's presence is non-negotiable. The skill's closing gate refuses to mark the area complete without it. Authoritative spec: the methodology docs' `cross-cutting-checklist.md`.

### Why this block matters

Without per-area dispositions, the §8 pattern-prevalence hypotheses cannot be falsified by repo 2 or any subsequent repo. The dispositions are small, mechanical, and high-signal — the same shape as the override register and for the same reason. "Area 6 found partial-correction debt everywhere; Area 1 checked and found none" is exactly the cross-area prevalence signal the methodology cannot get any other way.

The block is double-enforced on purpose: the skill's closing gate ensures the dispositions are produced in-session (so the agent does not silently skip them when wrapping up under time pressure); this report-shape spec ensures the dispositions land in the durable record (so the next synthesis can read them across all areas of all repos). A checklist is the most "I'll fill it in later" artifact type there is — the double enforcement reflects the gate-not-guideline meta-principle in the methodology docs' `conventions.md`.

If the operator pushes back ("the absent items feel like busywork"), surface the reasoning above: the absent items are prevalence data the synthesis needs; collapsing them to silence loses the disconfirmation evidence. The block is non-negotiable for the same reason the override register is.

## Voice notes for the report

- First-person past tense for the audit's actions ("I audited [file]", "I queried prod").
- Headline severities and counts up front. Prose narrative second.
- Footnote-style citations to issue numbers (#NN) so the reader can navigate.
- The "what surprised me" section should be uncensored — surprises that disconfirm priors are the audit's most valuable output, and softening them blunts the methodology's feedback loop.

## What the report is NOT

- Not a stream-of-consciousness of the session. Process notes belong in the dedicated section.
- Not a place to file new findings — anything reportable belongs in an issue (or the catalogue, or the "newly observed" subsection).
- Not a summary of the codebase — the audit's job is to find what's wrong or what's worth noting, not to document what's there.
- Not a fix proposal. Fixes belong in Phase 2+ work, not in the audit's voice.
