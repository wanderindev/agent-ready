# The four named adaptations

Each adaptation is a coherent reshape of the 10-slot template. They are **composable** — an area can be both forensic-first and call-graph-first, or both model-summary-first and call-graph-first. They are *not* mutually exclusive triggers; they are modes the operator selects based on the area's nature.

Select by reading the area, not the area's label.

**Example (from the pilot):** Auth was model-summary-first because the area was defined by an invariant whose violations were the bugs — not because "auth" is model-summary-first by convention. The next codebase's auth may need forensic-first instead if its auth code's aliveness is uncertain. (Full instance in the case study.)

If no adaptation clearly applies, default to the bare 10-slot template. That is the case for ~60% of areas — **example (from the pilot):** the data-layer area was the bare template, no adaptation.

---

## Forensic-first

### When it applies

The aliveness of a code path is genuinely uncertain — dead code, dormant integration, half-finished feature, or code that "looks alive but has zero evidence in prod." The verdict on aliveness reshapes every subsequent severity decision: if the path is dead, half the findings drop to nice-to-have; if it's live, near-miss findings become criticals retroactively.

Trigger conditions you can scan for:

- A vendor integration whose Sentry breadcrumbs are conspicuously absent
- A code path with credentials that have drifted from the production vendor console
- A feature whose schema exists but whose business owner says they "do it out of band"
- A worker / cron / webhook whose execution evidence is sparse in logs
- Code added by a previous developer whose intentions are no longer accessible

### What it adds to the standard slots

**Slot 3 (Why this area matters)** carries the framing prior explicitly: *"approach assuming the integration may be dead code. Verify before assuming anything works."* The prior is injected so the agent's first job is to test it, not to discover it.

**A new section appears between Slot 5 and Slot 6** — the **Forensic question**. Format:

> ## Forensic question: is [X] alive?
>
> This is the single most important question this audit answers, and it needs to be answered before any of the other findings can be properly prioritized. If [X] is dead, half the issues filed for the [X] code path are moot; if it's live, [recent near-miss] was a near-miss.
>
> The investigation:
> 1. Read the [X] integration code first. Map every code path that should touch a real [X] API.
> 2. Check for any logging, Sentry breadcrumbs, or audit-log writes that would leave evidence in prod if the path executed.
> 3. Query prod (via the gated method below) for: [the forensic fingerprints — typically `WHERE column IS NOT NULL` counts on integration-specific fields, plus audit-log row counts attributed to the integration]
> 4. Cross-reference [time-bounded discovery — e.g. credential drift dates]
> 5. Report a clear conclusion: "[X] appears live, with evidence A, B, C" or "[X] appears dead/never-used, with evidence A, B, C" or "Inconclusive — here's what we'd need to determine it."

**Slot 8 (End-of-session report)** requires the **forensic verdict** as an area-specific section. The verdict format is specified in the methodology docs' `reference-document-types/forensic-verdict.md` (installed by the methodology-install skill, default `docs/methodology/`).

**Slot 10 (Begin by)** ends with: *"Wait for my approval on the plan before starting any prod queries."* The forensic plan gets approval before the queries that drive it.

### Verbatim phrasings from the corpus

**Examples (from the pilot):** (full instances in the case study)

- *"Approach the PayPal portion of this audit assuming the integration may be dead code. Verify before assuming anything works."*
- *"PayPal-specific findings drop one rung if the bug only fires when the integration is live. They stay at the original severity if: (a) the bug class is broader than PayPal; (b) the bug is dormant only because of operational accident, not by design; (c) the bug guarantees a failure mode the moment the integration is turned on."*
- *"What changes if the verdict is wrong"* — every forensic verdict carries a risk register naming the ways the conclusion could be wrong.

### Composability notes

- **Forensic-first + call-graph-first** works well. The call graph helps locate the forensic fingerprints, and the forensic verdict reshapes which call-graph nodes matter.
- **Forensic-first + systematic-sweep** is unusual but possible. A sweep that catalogues *something* (e.g. swallowed exceptions) within a code path of uncertain aliveness — emit the catalogue and note explicitly which entries become moot under the dead-code verdict.
- **Forensic-first + model-summary-first** is rare in practice — the model-summary deliverable presumes the code is alive enough to have a model worth summarizing.

---

## Model-summary-first

### When it applies

The area is defined by an invariant whose violations *are* the bugs. Auth, error handling, transactions, money flow, state machines, anything with a "should always" property. Building the model first makes the deviations countable: every finding ends up framed as "intended-X / actual-Y / gap-Z."

Trigger conditions:

- The area's purpose can be stated as a single invariant ("every admin route requires a valid token", "every external call has a timeout", "every transition is atomic and logged").
- Most expected findings will be deviations from that invariant rather than independent bugs.
- The area's correctness is more about *what's missing* than *what's wrong* — and missing things are best surfaced against a model that says what *should* be there.

### What it adds to the standard slots

**Slot 8 (End-of-session report)** requires the **model summary** as an area-specific section, with explicit intended-vs-actual gap rows. See the methodology docs' `reference-document-types/intended-vs-actual-matrix.md`.

**Slot 10 (Begin by)** changes shape:

> Begin by:
> 1. Reading the audit plan, the prior reports' newly-observed sections, and any relevant phase-0 findings.
> 2. Mapping the [area] surface: list every route, every middleware, every dependency, every state transition. The map itself is half the audit — many [area] bugs are about gaps in the map.
> 3. Proposing a session structure. My suggestion: **build the [area] model summary first** (read everything, produce the section that goes into the report), then audit against it. The summary doubles as the mental model the audit uses.
>
> Wait for my approval on the structure before starting any prod queries.

The session ordering is "model first, deviations second" rather than the default "read, find, file."

### Verbatim phrasings from the corpus

**Examples (from the pilot):** (full instances in the case study)

- *"A clear, concise statement of how auth actually works in this project right now: who can authenticate, what session/token mechanism is used, what the authorization boundaries are, what state transitions an account can go through."*
- *"If the audit reveals that the intended model differs from the actual model, both should be documented with the gap called out."*
- *"My suggestion: build the [area] model summary first, then audit against it. The summary doubles as the mental model the audit uses."*

### Composability notes

- **Model-summary-first + call-graph-first** is common. The call graph names the nodes; the model says what each node should and shouldn't do.
- **Model-summary-first + forensic-first** is rare (see Forensic-first composability notes).
- **Model-summary-first + systematic-sweep** is contradictory — the model-summary approach trades enumeration for structured comparison; the sweep approach trades structured comparison for completeness. Pick one.

---

## Systematic-sweep

### When it applies

The deliverable is a taxonomy, not a judgment-sequence. The area's pattern repeats so widely across the codebase that filing each instance independently would produce ~30 nearly-identical issues; what the audit actually needs is one well-structured catalogue with a few standalone follow-ups for genuinely-different cases.

Trigger conditions:

- A previously-filed cross-cutting issue exists (e.g. "sweep services for swallowed exceptions").
- The instances of the pattern are mostly resolvable by fixing one or two *root* causes, not by per-instance work.
- The value of the audit is in the **rationale** (this is intentional / this is wrapper-induced / this is a pattern variant) more than in the *count*.

### What it adds to the standard slots

**Slot 1 inverts the default framing**: *"This is a systematic sweep, not an audit. The output is a single comprehensive comment on issue [#N], structured as a catalogue, with line-level references."*

**Slot 5 (What to look for)** becomes a **catalogue structure proposal** — what categories the catalogue will distinguish (wrapper-induced / genuinely independent / pattern variants / inverse patterns), what columns it will carry, what the "structurally novel" bar is for a separate filing.

**Slot 7 (Working style)** drops batch-and-confirm explicitly: *"No batch-and-confirm for catalogue work. This is mechanical transcription against a clear structure. Just produce the catalogue."* But it KEEPS batch-and-confirm for the standalone-issue filings at the end: *"DO batch-and-confirm for separate issue filings. When you've finished the synthesis and identified candidates for standalone issues, propose them as a single batch."*

**Slot 8 (End-of-session report)** is shorter than usual because the substance lives in the catalogue comment. Required sections shrink to: executive summary, by-the-numbers, **catalogue location reference**, what's filed separately and why, methodological notes (calibration data for the next areas), newly observed, what surprised me.

**Slot 9 (Scope estimate)** carries a different upper-bound: not "20+ findings" but "30+ catalogue entries" — and a separate "10+ standalone issues" upper-bound that triggers re-scope (because too-many standalone issues means the sweep failed to roll up).

### Verbatim phrasings from the corpus

**Examples (from the pilot):** (full instances in the case study)

- *"This is a systematic sweep, not an audit."*
- *"No batch-and-confirm for catalogue work."*
- *"The intent is to make [the tracking issue] itself the primary deliverable — a single comprehensive reference — rather than a scattering of 30+ tiny issues."*
- *"Restrict separate filings to: (1) Active bug-masking [instances]. (2) Structurally novel patterns. (3) Already-named items from prior areas that need a proper issue."*

### Composability notes

- **Systematic-sweep + call-graph-first** can work when the sweep is over flows that share infrastructure. But typically the sweep is over files, not over the call graph.
- **Systematic-sweep + model-summary-first** is contradictory (see Model-summary-first composability notes).
- **Systematic-sweep + forensic-first** is unusual but possible (see Forensic-first composability notes).

---

## Call-graph-first

### When it applies

The area is structurally a set of flows that share infrastructure but not control flow. Pipeline-shaped areas (research → guides → slides, or suggestions → research → article → translation → publication), routing-heavy areas (many endpoints over a shared service layer), or any area where reading individual files in isolation misses the seam where flows meet.

Trigger conditions:

- The area's findings will likely live "in the seams between flows" rather than inside any single file.
- The flows share a vocabulary (the same model, the same wrapper, the same DB table) but trigger from different entry points.
- A reader who walks files alphabetically will produce a less-good audit than a reader who walks flows.

### What it adds to the standard slots

**Slot 8 (End-of-session report)** requires the **call graph** as an area-specific section, presented as a diagram or structured ASCII map. See the methodology docs' `reference-document-types/per-area-call-graph.md`.

**Slot 10 (Begin by)** explicitly demands the call graph BEFORE any deeper read:

> Begin by:
> 1. Reading the inputs above.
> 2. Producing the [area]-pipeline call graph (which modules call which, in what order, with what data flowing through).
> 3. Verifying the in-scope module list against the actual directory.
> 4. Proposing a session structure — probably: call-graph first, then per-stage audit walking the pipeline, then state/recovery analysis, then [the area-specific deliverable].
>
> Wait for my approval on the call graph and structure before starting the per-stage audit.

The call graph is itself an approval-gate artifact. Wrong call graphs waste hours.

### Verbatim phrasings from the corpus

**Examples (from the pilot):** (full instances in the case study)

- *"The 30 minutes spent producing the call graph paid for itself three times over — most findings live in the seams between flows."*
- *"The pipeline is five flows, not one. This is the load-bearing structural fact."*
- *"Wait for my approval on the call graph and structure before starting the per-stage audit."*

### Composability notes

- **Call-graph-first + forensic-first** works well (see Forensic-first notes).
- **Call-graph-first + model-summary-first** is common (the call graph names the nodes; the model says what each should do).
- **Call-graph-first + systematic-sweep** is unusual — typically the sweep is file-based, not flow-based.

---

## A fifth, smaller adaptation worth naming

### Build-the-bundle-not-estimate-it (and similar measurement disciplines)

Not a full adaptation but a discipline worth carrying across. When the audit can cheaply ground a claim in a measurement rather than re-estimating from a previous report, **run the measurement**.

**Examples (from the pilot):** (full instances in the case study)

- Area 5 ran `npm run build` and reported the actual byte count (2,649,933) rather than re-estimating Phase 0's "2.6 MB" claim.
- Area 4b-1 ran prod aggregate queries early and let them recalibrate severities (three severities adjusted as a result).

Pattern: when a prior report's claim can be checked in five minutes, check it. The audit's credibility — and the operator's calibrated priors — both benefit.

---

## Quick decision table

| Area shape | Likely adaptations |
|---|---|
| Payments / money flow / vendor integration with uncertain aliveness | forensic-first (+ model-summary-first if there's an invariant) |
| Auth / access control / authorization | model-summary-first (+ call-graph-first if the route surface is large) |
| Error handling / transactions / state machines | model-summary-first |
| Cross-cutting pattern sweep (exceptions, logging, validation) | systematic-sweep |
| Multi-stage domain pipeline (research → content → output) | call-graph-first (+ model-summary-first if it has a clear invariant) |
| Service layer with many wrappers | call-graph-first (the dependency graph IS the audit) |
| Frontend public site | bare template (with measurement discipline for bundle size, etc.) |
| Frontend admin CMS | model-summary-first applied to admin route + auth surface |
| Data layer / models / migrations | bare template (no adaptation has obviously fit this area class) |

This table is the pilot calibration. Subsequent repos will refine it.
