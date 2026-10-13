---
name: area-audit
description: Scaffold the prompt for an area audit inside a multi-area codebase-audit project, and enforce the per-area closing gates when a session reports back. Use at start-of-area when the operator says any of "audit the X area", "start area N", "next audit area is Y", "scaffold the auth audit", "draft the prompt for the payments audit", "extend the audit methodology to this repo", or otherwise indicates they are about to brief a fresh session that will read code, file issues, and produce an end-of-session report. Also use at end-of-area when the operator says any of "close out area N", "the area N report is done", "check the area report", "verify the dispositions", or otherwise returns with a completed area report — the skill walks the report and refuses to mark the area complete until the override register and the cross-cutting checklist dispositions sub-section are both present and well-formed. Also use when the operator has an existing area-by-area audit plan and is about to begin or resume one of its areas. The skill produces the prompt the operator hands to a fresh session and enforces the per-area gates — it does not run the audit itself, does not read the codebase deeply, does not file issues. Always invoke this skill before drafting an area-audit prompt from scratch.
---

# Area-audit prompt scaffolder

## What this skill does — and what it doesn't

This skill produces a **prompt-shaped brief** for one area of a multi-area codebase audit. The brief follows the 10-slot template that emerged across 14 sessions of a real audit (the pilot — see `references/worked-examples.md` for the corpus this is extracted from).

It does **not** execute the audit. It does **not** read the codebase. It does **not** file issues. It is a scaffolding tool the operator runs *before* opening a fresh session.

The skill's central design move is the **skeleton/fill split**:

- The **skeleton** transfers verbatim across repositories: the 10 slots, the four named adaptations, the working-style discipline, the report shape, the override-instrumentation hook.
- The **fill** is irreducibly per-area, per-repo, per-orchestrator: severity-calibration examples grounded in the area, stop-the-line triggers stated as concrete vulnerabilities, agent-friendly examples specific to the code shape, the in-scope/out-of-scope file list, the prior-area "newly observed" pointers, the area's blast-radius framing.

**This skill refuses to emit a complete prompt until the fill is supplied.** That is the central methodology discipline. Worked examples for severity calibration are not optional and cannot be papered over; they are the irreducible per-area work, and a generic substitute degrades the audit. See the Per-Area Fill Checklist below.

## Workflow

1. **Confirm the area.** Ask the operator: which audit area is this? Is there an existing audit plan document the area lives in? What area-class is it (services / domain pipeline / auth / payments / frontend public / frontend admin / data layer / cross-cutting sweep)?
2. **Run the Per-Area Fill Checklist.** Walk the operator through the six fills below. Do NOT proceed past missing fills. If the operator says "skip, just emit the skeleton" — emit the skeleton with each missing fill marked `[TODO — fill before sending to session]` and tell them the prompt is not ready to ship.
3. **Select adaptation(s).** Use the decision table below. Adaptations are composable.
4. **Choose the area-specific required-additions** from the report-shape menu (see `references/report-shape.md`).
5. **Assemble the prompt** by walking the 10 slots, weaving in the chosen adaptations. Slot 7 includes the cross-cutting checklist surfacing block; Slot 8 includes the cross-cutting checklist dispositions block alongside the override register — see `references/cross-cutting-checklist.md` for both blocks verbatim.
6. **Emit a fill audit alongside the prompt** — a short summary of which fills are present, which are weakly supported, and which adaptations are active. The operator reads this before shipping the prompt.
7. **At end-of-area: enforce the closing gate.** When the operator returns with a completed area report, the skill walks the report looking for the required **Cross-cutting checklist dispositions** sub-section. The skill refuses to mark the area complete until all seven dispositions are recorded (5 fired/absent/N-A for the pattern items + 3 prior-paragraph parts for the orchestrator's-prior framing item). See `references/cross-cutting-checklist.md` and the **Closing gate** section near the end of this document.

## The 10-slot template

The 10 slots appear in roughly this order in every well-constructed area-audit prompt. Each slot exists to pre-empt a specific failure mode. Always emit all 10. Length per slot ranges from one paragraph to a page.

### Slot 1 — Identification + audit-plan pointer

Open the prompt with: "We're starting Phase N Part X Area Y." Cite the audit plan document by path. Add: "Read it again if context has rolled." Pre-empts the failure mode where a fresh session has no shared frame for what area means or how it relates to other areas.

### Slot 2 — Read-this-first inputs

Explicit, named list of prior-area reports and relevant issues to load. Include the "newly observed for Area Y" subsections from prior reports — those are *inputs to verify*, not findings to rediscover. Pre-empts the failure mode where the agent rediscovers what was already filed in a previous area.

### Slot 3 — Why this area matters (FILL REQUIRED)

One paragraph. Concrete blast-radius framing — "highest-financial-blast-radius area in the codebase" (payments), "narrow surface, high blast radius" (auth), "user-visible, not data-corruption-shaped" (frontend public). This is where the orchestrator's priors get injected. Pre-empts the failure mode where every finding is treated as equally consequential.

### Slot 4 — Scope (FILL REQUIRED)

In-scope files (often "read all in full"). Out-of-scope files with per-area pointers ("Area 3 territory; note in *newly observed*"). Pre-empts scope drift and re-audit of areas already covered.

### Slot 5 — What to look for (FILL REQUIRED)

Multi-headed checklist organized **by concern, not by file**. Headings name the things the orchestrator wants the agent to *think about*. Examples: "Order state machine", "Webhook handling", "Booking ↔ Order ↔ Payment reconciliation". Pre-empts the file-walk-as-audit failure mode where the agent reads files in order without ever raising its head to see patterns.

### Slot 6 — Production data access policy (conditional)

Include when prod queries are likely useful; omit when they aren't (frontend audits, catalogue sweeps). Always gate with: "Surface for explicit approval before any prod query — aggregates only, no row-level PII." Pre-empts two failure modes simultaneously — careless reads and PII exfiltration into the agent's context.

### Slot 7 — Working style (FILL REQUIRED for severity, agent-friendly, stop-the-line)

Five bullets, repeated every session:

1. **Batch-and-confirm** — group findings, propose titles + labels + agent-friendly classification, get approval before filing.
2. **Severity calibration** with worked critical / moderate / nice-to-have examples *grounded in this area*. THIS IS THE FILL THE SKILL DEMANDS. Generic severity scales do not work — the agent needs domain-specific anchors.
3. **Agent-friendly calibration** — apply the six-criterion rubric with bias toward NO. Borderline cases default to NO. Provide 1-2 examples of what would qualify in this area.
4. **Stop-the-line triggers** — listed as *concrete vulnerabilities*, never abstract. "Unsigned webhook endpoint accepting writes" not "security issues." THIS IS THE FILL THE SKILL DEMANDS. Stop-the-line is the most-likely-in-payments-or-auth, less-likely-in-frontend asymmetry the operator must declare.
5. **Don't re-audit prior-area concerns.** Reference; don't re-file.
6. **Cross-cutting checklist — surface at start, record at end.** Six patterns the methodology asks every area to actively look for (partial-correction debt; swallowed-failure umbrella; danger isn't where complexity is; two-dimensional severity; latent-but-uncrystallized risk; orchestrator's-prior framing). Surface them in Slot 7 as things-to-watch-for; record dispositions in Slot 8's required sub-section. Verbatim block and gate behavior in `references/cross-cutting-checklist.md`. Even "checked, absent" is signal; the discipline is half the value.

Catalogue-sweep adaptations may explicitly drop batch-and-confirm — see `references/adaptations.md`.

### Slot 8 — End-of-session report shape (FILL REQUIRED for area-specific additions)

Standard sections (executive summary, by-the-numbers, what was audited, item-by-item findings, what's filed vs. deferred, newly observed, what surprised me, process notes) plus the **area-specific required additions** — pick from `references/report-shape.md`'s menu of reference-document types.

**REQUIRED in every report on every area, from this point forward**: an **override register** capturing how many times the operator overrode the agent on severity / agent-friendly classification / scope / area-split, with a one-line description of each. This is the falsifiability hook the methodology owes itself — the §4 autonomy claim cannot be checked against repo 2 without this measurement. Generic recollection ("on the order of twice") is not data. Build the override register into the prompt's report ask so it is captured by default. See `references/report-shape.md` for the exact wording.

**ALSO REQUIRED in every report**: a **Cross-cutting checklist dispositions** sub-section — 5 fired/checked-absent/N-A dispositions for the pattern items + a short priors-stated/held/broke paragraph for the orchestrator's-prior framing item. This is the second falsifiability hook the methodology owes itself — without per-area dispositions, the §8 pattern-prevalence hypotheses cannot be checked against repo 2+. The block is non-negotiable and the skill's closing gate enforces it. Verbatim block and disposition vocabulary in `references/cross-cutting-checklist.md`; authoritative checklist in the methodology docs (installed by the methodology-install skill, default `docs/methodology/cross-cutting-checklist.md`).

### Slot 9 — Scope estimate (FILL REQUIRED)

Hours and an issue-count band. **Always include the upper-bound trigger**: "If you're approaching 25+ findings, something is wrong — either the area has more rot than expected (surface and we'll regroup) or you've drifted into Area N+k territory." Pre-empts unbounded fan-out.

### Slot 10 — Begin by (FILL REQUIRED — must end at an approval gate)

A numbered 1–4 lead-in. Some variant of:
1. Re-read the inputs above.
2. Produce a map / call graph / inventory.
3. Propose a session structure.
4. **Wait for my approval on [the structure / the call graph / the route map] before starting [the per-stage audit / any prod queries].**

The approval gate at the end is non-negotiable. Approval gates sit at decision boundaries where a wrong turn would waste hours — not at fixed progress checkpoints. Pre-empts the failure mode where the agent burns half a session pursuing the wrong angle and surfaces only when the report is being drafted.

## Per-Area Fill Checklist

Before the skill emits the assembled prompt, walk the operator through these six fills. Hard gate — if any are missing, emit the skeleton with `[TODO]` markers and call out the gap.

| # | Fill | Why required |
|---|---|---|
| 1 | **Severity examples** — concrete critical / moderate / nice-to-have findings grounded in this area's domain | Generic rubrics underperform; the agent needs domain anchors to calibrate. This is the largest single irreducible per-area cost. |
| 2 | **Stop-the-line triggers** — listed as concrete vulnerabilities (e.g. "unsigned webhook endpoint accepting writes") | Abstract triggers ("security issues") do not bind; concrete ones do. |
| 3 | **Agent-friendly examples** — 1–2 examples of what would qualify in this area | Default is NO; the operator must say what would land on the YES side here. |
| 4 | **In-scope files + out-of-scope files** with per-area pointers | Scope drift is the dominant single failure mode; explicit out-of-scope routing kills it. |
| 5 | **Prior-area "newly observed" pointers** to load | Treats prior findings as inputs to verify, not to rediscover. |
| 6 | **Blast-radius framing** — one concrete sentence | Sets the severity priors for the whole session. |

If the operator pushes back ("just use generic severity, agent will figure it out"), surface the failure mode explicitly: across the reference pilot audit, generic rubrics led to consistent over-classification on the moderate band and missed criticals. The fill is cheap (5–10 minutes per area); the audit's quality depends on it.

## Adaptation selection

Four named adaptations. **Composable** — an area can be both forensic-first and call-graph-first. See `references/adaptations.md` for full detail.

| Adaptation | When it applies |
|---|---|
| **Forensic-first** | Aliveness of the code path is genuinely uncertain (dead code? dormant integration? half-finished feature?). Verdict shapes every subsequent severity decision. |
| **Model-summary-first** | The area is defined by an invariant whose violations *are* the bugs (auth, error handling, transactions, money flow). Build the model before listing the deviations. |
| **Systematic-sweep** | Deliverable is a taxonomy / catalogue, not a judgment-sequence of findings. Drop batch-and-confirm; output is one structured comment, not fan-out issues. |
| **Call-graph-first** | Area is a set of flows that share infrastructure but not control flow. Most findings live in the seams between flows, so the call graph is half the audit. |

Selection rule: read the area's nature, not the area's label.

**Example (from the pilot):** Payments was forensic-first because PayPal might be dead, not because "payments" is forensic-first by convention. The next codebase's payments area may be call-graph-first instead. (Full instance in the case study.)

If no adaptation clearly applies, default to the bare 10-slot template — that is the case for ~60% of areas.

## Working-style discipline

These items live inside Slot 7 but they are reusable across areas and worth surfacing here:

- **Batch-and-confirm.** Don't open issues one at a time. Group 3–5 logically related findings, propose titles + labels + agent-friendly classification, get approval, then file. EXCEPTION: catalogue sweeps drop this and emit the catalogue directly.
- **"Newly observed but don't file."** Findings the agent surfaces that belong to a later area get listed in the report's "newly observed" section, not filed. The next area's prompt cites those listings as inputs.
- **Don't re-audit prior areas.** Reference prior findings; do not re-file. The prior area's report is authoritative for its scope.
- **The promo-credit framing.** When the audit needs depth but not scope, say so explicitly: "If you hit subscription cap, continue rather than stop — but 'be thorough' is not 'expand scope' — stay in [the area]." Single instruction that buys depth without buying scope creep.
- **"What this is NOT" device.** When the session is at risk of scope drift (snapshot sessions, prep sessions), enumerate what *not* to do as well as what to do. Positive specification alone is insufficient when a default failure mode wants to happen.
- **Pre-figured findings as priors.** When the operator has a strong prior, inject it. **Example (from the pilot):** "approach the PayPal portion of this audit assuming the integration may be dead code — verify before assuming anything works." The agent's job is verify-or-refute, not discover. After the audit, check priors against findings — the surprises are the load-bearing results. (Full instance in the case study.)
- **Approval gates sit at decision boundaries, not progress checkpoints.** Gate at the call-graph-before-deep-read, the structure-before-prod-queries, the candidate-batch-before-filing. Don't gate every read; don't ungate the high-stakes branch points.
- **The agent-friendly default is NO.** Borderline cases default to NO. The label is a promise that a fresh agent can land the change with low operator review cost; if the rubric is murky on any of its six criteria, the promise is shaky.

## How the skill emits its output

Two artifacts per invocation:

1. **The assembled prompt** — the 10 slots filled with the operator's fills, the adaptations woven in, the report-shape additions named, the working-style block tuned.
2. **A fill audit** — a short summary listing: which slots have strong fills (named examples, concrete pointers), which have weak fills (generic phrasing, missing anchors), which are TODO. The operator reads this before shipping the prompt to a fresh session.

If any fill is missing, the prompt's affected slot contains `[TODO — fill before sending to session]` with a one-line note on what the fill should look like. The skill does NOT silently substitute defaults for missing fills.

## Reference files

- **`references/adaptations.md`** — the four named adaptations with their triggering conditions, verbatim phrasing patterns, and composability notes.
- **`references/report-shape.md`** — the standard report sections, the area-specific required-additions menu mapped to the reference-document types in the methodology docs (installed by the methodology-install skill, default `docs/methodology/reference-document-types/`), the override-instrumentation block, and the cross-cutting checklist dispositions block (both falsifiability hooks).
- **`references/cross-cutting-checklist.md`** — the operational summary of the six-item checklist the skill surfaces at start-of-area and enforces at end-of-area. Authoritative document is the methodology docs' `cross-cutting-checklist.md` (installed by the methodology-install skill, default `docs/methodology/`).
- **`references/worked-examples.md`** — real fills from the pilot for the per-area-irreducible slots. Marked `PIC-WORKED-EXAMPLE` so the methodology-install skill can find them and help an operator replace them with their own repo's equivalents.

Read the references on demand — for example, when an adaptation is selected, load just `adaptations.md`'s section on that adaptation; when assembling the report-shape block of Slot 8, load `report-shape.md` and `cross-cutting-checklist.md` (both contribute required sub-sections to Slot 8).

## Cross-references

This skill is part of a methodology stack. The methodology docs are installed by the methodology-install skill (default `docs/methodology/`):

- **`prompt-template.md`** — the fill-in form an operator works from outside the skill. Same skeleton, different surface: the template is what you copy-and-edit; the skill is what walks you through the fills interactively.
- **`reference-document-types/`** — the eight reusable document-type specs an area audit may produce. The skill's Slot-8 menu pulls from this directory.
- **`cross-session-register.md`** — the register the operator appends to after each session. Cross-session decisions (area ordering, mid-audit deliverable introduction, stop-the-line scope) live there, not in the per-session prompt.
- **`conventions.md`** — the practices the methodology depends on (preserve verbatim prompts; keep the register current).

## Closing gate

The skill enforces two structural gates. Both exist because the methodology depends on a discipline that decays under the time pressure that makes the discipline matter — and the methodology docs' `conventions.md` names *prefer gates to guidelines* as a meta-principle for exactly this reason.

- **Fill-gate (start-of-area).** The skill refuses to emit a complete prompt until per-area fills are supplied (severity examples, stop-the-line triggers, agent-friendly examples, scope, prior-area pointers, blast-radius framing). Worked examples for severity calibration are the irreducible per-area cost; a generic substitute degrades the audit. See the **Per-Area Fill Checklist** above.

- **Checklist-dispositions-gate (end-of-area).** The skill refuses to mark an area complete until the report contains the required **Cross-cutting checklist dispositions** sub-section, with all seven dispositions present (5 fired/checked-absent/N-A for the pattern items + 3 prior-paragraph parts for the orchestrator's-prior framing item). A checklist is the most "I'll fill it in later" artifact type there is, so the gate is double-enforced: this skill catches missing dispositions in-session; the report-shape spec catches them in the durable record. See `references/cross-cutting-checklist.md` for the gate's mechanics and `references/report-shape.md` for the persistence-side enforcement.

The gates do not silently default. If a fill is missing, the affected slot contains `[TODO]` and the operator is told the prompt is not ready to ship. If a disposition is missing, the closing summary names what is absent and the area is not marked complete. The operator can override only by explicit re-prompt — never by silence.

## What this skill is not

- Not an auditor — it does not read code or file issues.
- Not a methodology document — the methodology docs (installed by the methodology-install skill, default `docs/methodology/`) are the canonical reference; this skill is the operational entry point.
- Not a substitute for cross-session judgment — area ordering, stop-the-line detour scope, and mid-audit deliverable introduction are explicitly human decisions the synthesis identifies as load-bearing; the skill scaffolds *one* session, not the orchestration across sessions.
- Not a once-built artifact — the skeleton is stable; the fills are repo-specific. Building the fills is the methodology's irreducible per-area cost and the skill exists to demand them.
