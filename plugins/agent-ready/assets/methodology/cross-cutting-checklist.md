# Cross-cutting findings checklist

The pilot audit found several patterns *by accident* that future audits should look for *on purpose*. This document is the checklist. It is the fourth artifact in the methodology stack, alongside the area-audit skill, the prompt template, and the reference-document-type specs.

The checklist is **deliberately small**. Six items grounded in real pilot findings — five concrete pattern items, plus a framing disposition the other five sit inside. The authority of the checklist comes from the grounding, not from comprehensiveness. Resist the temptation to grow it from imagination; grow it only from what the next audits surface.

## How to read this document

Each pattern item below is framed as a **hypothesis from one codebase**, not a law. Every item carries:

- **What to look for** — the pattern, concretely.
- **Worked example(s)** — the real instance(s) from the pilot, tagged `PIC-WORKED-EXAMPLE` so a future installation pass can find and substitute them when this directory is adopted for a new repo. (Full instances live in the case study.)
- **What would falsify it being general** — what a second codebase onward would need to show for the pattern to be confirmed general vs revealed pilot-specific. Several items carry §10 falsification language verbatim.
- **How it's checked** — where in an area audit the item is surfaced (start) and recorded (end).

Item 0 (the orchestrator's prior as a check) is structurally different — it is a *disposition the orchestrator brings to each area*, not a code pattern to find. It is the frame the other five sit inside. The report sub-section handles it separately from the others — see [`../../skills/area-audit/references/report-shape.md`](../../skills/area-audit/references/report-shape.md).

## The discipline IS half the value

A checklist whose items mostly come back "checked, absent" is **still doing its job**. The discipline of running it captures the disconfirmation evidence that a second codebase's synthesis needs to tell pilot-specific patterns apart from general structural ones. "Area 6 found partial-correction debt everywhere; Area 1 checked and found none" is exactly the cross-area prevalence signal the methodology cannot get any other way.

Frame the checklist as **things to actively look for**, NOT as **issues to file unless found**. The output is a disposition per item per area, every time — not a filing instruction.

## The disposition vocabulary

Three values for the five pattern items. Distinct on purpose — do not collapse.

- **Fired** — the pattern was found in this area. Record the issue numbers.
- **Checked, absent** — looked for it; this area doesn't exhibit it. This is **prevalence data** and it is the point.
- **Not applicable** — the item structurally can't apply to this area, with a one-line why. Distinct from "checked, absent": absent is prevalence data (sought, not found); not-applicable is coverage scope (the question didn't make sense here). A frontend public area marking "swallowed-failure umbrella" as N/A because there is no service-error tier is not the same signal as a backend service area marking it absent because the wrappers were clean.

Item 0 does not use this vocabulary — see Item 0 below.

---

## Item 0 — The orchestrator's prior as a check (the framing item)

### What it is

This is the deepest reframe the methodology offers, and it sits at the top of the checklist for a reason. It is not a pattern to find in the code — it is a discipline the orchestrator brings to each area:

**Before running an area audit, write down the priors. After running it, compare the priors against the findings.**

The places where priors held are evidence the orchestrator's mental model of the codebase is calibrated. The places where they didn't are the audit's most valuable discoveries.

### Why it sits at the top

What this reframes is the orchestrator's *role*. The default mental model — *"the human reviews the agent's work"* — casts the orchestrator as a quality gate, which is mostly the babysitting work the methodology already wants to automate away. The audit-as-experiment frame casts the orchestrator instead as the one who **states the hypotheses the agent's session is set up to test**. The audit becomes the experiment; the report becomes the result set; the surprises become the load-bearing findings. **The orchestrator is an experimenter, not a reviewer.**

This frame is what distinguishes the methodology from *"have an agent read your code."* It is also what makes the cross-session work feel like skilled labor rather than supervision. The other five items sit inside this frame — they are the patterns the experimenter knows to test for; the dispositions are the result set.

### `PIC-WORKED-EXAMPLE`

**Example (from the pilot)** — across the 14 prompts the operator routinely pre-figured findings concretely enough that the agent's job was verify-or-refute, not discover (full instances in the case study):

- **Area 2 (payments):** *"Approach the PayPal portion of this audit assuming the integration may be dead code. Verify before assuming anything works."* The Area 2 audit spent its first 45 minutes producing the dead-code verdict; the prior held.
- **Area 3 (auth):** *"A few thousand requests per second cracks it in minutes"* — pre-figuring the rate-limit finding on the 6-digit code; the prior held.
- **Area 4b-2 (article pipeline):** *"What happens to an APPROVED, published article if regeneration is triggered?"* — pre-figuring #99; the prior held and the bug was already firing in production (articles 39 and 40).
- **Prompt 13 (backlog snapshot):** *"If the counts are significantly different, flag that immediately — it means something closed that I don't remember closing."* Ground-truth-the-state framing applied to the orchestrator's own belief.

### How it's checked — separately from the pattern items

Item 0 does not use the fired/absent/N-A vocabulary. It uses a short paragraph in the report sub-section:

- **Priors stated** — the priors the operator wrote down before this area.
- **Priors that held** — evidence the orchestrator's mental model was calibrated for the area.
- **Priors that broke** — the surprises; these are the audit's most valuable findings.

If the operator didn't state any priors for an area, the report says so explicitly. "No priors stated for this area" is itself a data point — it tells a second codebase's synthesis where the orchestrator was operating without a mental model to test against.

### What would falsify it being general

Item 0 falsifies on a different axis than the pattern items. The §10 framing applies here:

> On a less-familiar codebase or one with more sessions between the audit and the synthesis, the prior may be wrong by enough margin that the snapshot's role shifts from *"ground-truth the orchestrator's belief"* to *"construct the orchestrator's belief from scratch."*

If on a second codebase the operator's pre-area priors are consistently absent (no calibrated mental model yet) or consistently wrong (the codebase is too unfamiliar), the framing still applies but the *content* of the discipline shifts: from "verify a calibrated prior" to "build a calibrated prior over the audit's life." The experimenter role survives; the experimenter's starting position changes.

---

## Item 1 — Partial-correction debt

### What to look for

The right pattern half-applied. A fix-shape that appears at some call sites and not others; sibling code that should share a discipline but doesn't; "the auditor noticed the duplication and fixed only half of it" as the dominant tech-debt shape.

### `PIC-WORKED-EXAMPLE`

**Example (from the pilot)** — found at least five times across four areas (full instances in the case study):

- **Area 4c (services):** `educator_service._send_*_email` helpers log the bool result but the same-file callers discard it.
- **Area 4b-2 vs 4b-1 (pipelines):** the LLM pipeline guards regeneration in four of five flows and misses the fifth — #99 (series-sections, raw-SQL concat) vs #91 (educational materials, schema-guarded).
- **Area 5 (frontend public):** `EducatorAuthContext` wraps `JSON.parse` defensively; sibling `CartContext` does not — a whole-site blank-page crash if the localStorage cart is malformed.
- **Area 4b-2 (article pipeline):** `_generate_references_section` duplication where the auditor noticed the duplication and fixed only half of it.
- **Area 6 (frontend admin):** *"Every Area 6 finding is the same finding. Six issues, one shape: a good pattern, half-applied"* — #117 and its siblings.

### What would falsify it being general

The deeper hypothesis is that partial-correction is the dominant tech-debt shape of a long stop-start project under one developer — but it could equally be the dominant shape of an LLM-edited codebase. §10's falsification frame:

> Run a comparable audit against a codebase with different authorship history (multi-developer continuous; clean-team-rewrite; pure-agent-built). If partial-correction debt continues to be a dominant pattern, it is a general structural signature. If it drops away, it is calibrated to the pilot's authorship history.

### How it's checked

**Start-of-area:** surface as a thing to watch for, especially in the working-style block — when the area is likely to surface fix-shaped findings (most are), name partial-correction explicitly so the agent sweeps for siblings before declaring a pattern fixed.

**End-of-area:** record disposition. If fired, the disposition note also captures the remediation discipline: when this area's findings introduce a fix-shape, the corresponding remediation PR sweeps across all sibling call sites in the same change.

---

## Item 2 — Swallowed-failure as an umbrella theme

### What to look for

Error conditions silently dropped. Treat as a **cross-area theme** that any single area's audit names as an instance, not as an independent finding. The umbrella tends to predate any single area's audit (the pilot's was a Phase 0 tracking issue).

Distinguish carefully from Item 1 (partial-correction debt) — they overlap on some sites (a vendor wrapper can have both) but they are distinct ideas. Partial-correction is *"the right fix was applied, but only halfway across the relevant call sites."* Swallowed-failure is *"an error condition is silently dropped."* Partial-correction is the meta-pattern; swallowed-failure is one of its concrete instances when an existing recovery pattern wasn't extended to a new site.

### `PIC-WORKED-EXAMPLE`

**Example (from the pilot)** — the umbrella was Phase 0 #8 (*"sweep services for swallowed exceptions"*); concrete instances filed during the area audits (full instances in the case study):

- Area 2: #37 (Composio swallow-on-failure during contact form).
- Area 3: #59 (educator email send returns bool, caller discards).
- Area 4a: #67 (Composio wrapper contract), #70 (notifications wrapper), #74 (mailing_list wrapper).
- Area 4c: #83 (image_storage thumbnail), #84 (orders.py PayPal cancel), #85 (media_scoring broad catch).
- Area 6: #117 (admin frontend — inline action error handlers `console.error`-only).

Roughly nine issues, one theme. The Area 4c systematic-sweep produced the structured catalogue that compresses the umbrella.

### What would falsify it being general

If a second codebase's audit names a different umbrella theme (timeouts, race conditions, unchecked null returns) but no swallowed-failure cluster, the umbrella is pilot-specific — calibrated to Python-on-FastAPI services with sync SQLAlchemy and external vendor wrappers. If a swallowed-failure cluster shows up regardless of language and framework, the pattern generalizes — the umbrella is structural to systems with external integration boundaries.

### How it's checked

**Start-of-area:** if a swallowed-failure tracking issue exists, name it in Slot 2's read-this-first inputs and instruct the agent to roll instances up to the umbrella rather than file independent issues.

**End-of-area:** record disposition. If fired, the disposition note cites the tracking issue under which instances were rolled up, or — if the systematic-sweep adaptation is active — points to the catalogue.

---

## Item 3 — Danger is not where complexity is

### What to look for

Critical findings that live in the code that "looked too simple to merit scrutiny," not in the high-complexity nodes the audit was set up to scrutinize. Complexity attracts attention; simple-code-that-also-mutates-production-data is the systematic blind spot.

### `PIC-WORKED-EXAMPLE`

**Example (from the pilot)** — the Area 4b-2 audit found its only critical (**#99**) not in the heavy LLM regeneration paths the audit was set up to scrutinize, but in the simple string-concatenation flow nobody was watching (full instance in the case study):

> The pipeline learned the #91 lesson four times out of five and missed it in the flow that looked too simple to get wrong.

The article pipeline guarded regeneration correctly in four mutating flows (outline generation, article writing, translation) and missed it in `series-sections` — the unguarded flow is the one that makes no LLM call at all; it is a raw-SQL `UPDATE` that concatenates strings. It is also the most-exercised flow in the pipeline (all 51 published articles went through it).

### What would falsify it being general

If every codebase's criticals consistently cluster in the high-complexity nodes the audit set up to scrutinize, the pattern is pilot-specific — likely an artifact of how the pilot's prompts framed scrutiny (heavy emphasis on LLM call sites, light emphasis on plumbing). If "too simple to be wrong" criticals recur across codebases with different scrutiny framings, the pattern is structural to how human attention allocates against complexity.

### How it's checked

**Start-of-area:** none — this is an end-of-area check by construction. The agent cannot know what looked too simple until it has spent time on the area.

**End-of-area:** record disposition. The check is a deliberate question: *what code in this area looked too simple to merit scrutiny, and did I read it at least once?* If fired, the disposition cites the simple-looking finding. If checked-absent, the disposition states the simple code was read and nothing surfaced.

---

## Item 4 — Two-dimensional severity (blast-radius × evidence-of-impact)

### What to look for

Critical findings where the two dimensions diverge. A finding may be critical-by-blast-radius but **dormant** (the code path is not exercised; the bug cannot fire today); a different finding may be lower-by-blast-radius but **live** (the bug is currently triggering on real production data). A dormant critical and a live moderate are not obviously co-ranked.

### `PIC-WORKED-EXAMPLE`

**Example (from the pilot)** — among the 15 critical issues, the cleanest examples of the divergence (full instances in the case study):

- **Dormant criticals:** #32 / #33 / #34 (the PayPal webhook trio) — critical-by-blast-radius, but Area 2's forensic verdict established the PayPal integration is unexercised dead code. They cannot fire today.
- **Live critical:** #99 — critical AND has evidence of live production impact (articles 39 and 40 already carry doubled nav blocks; the corruption is on the public site).

The Area 4b-2 report names the underlying pattern:

> The prod query raised a severity instead of lowering one… aggregates don't just de-escalate — they tell you the truth in whichever direction it runs.

### What would falsify it being general

If no codebase ever has dormant criticals (every critical-by-blast-radius is also live), the second dimension collapses to one and the methodology can simplify. This would happen on a codebase with no dead integrations, no feature flags gating critical paths, no environment-specific code paths — possible in a mature high-traffic system. If even mature systems produce dormant criticals (deprecated paths, fallback code, environment-specific branches), the two-dimensional scoring earns its place permanently.

### How it's checked

**Start-of-area:** when an area is likely to have dormant-vs-live ambiguity (areas with vendor integrations, feature flags, or environment-specific code), the prompt should signal the dimension explicitly.

**End-of-area:** record disposition. The discipline: for each critical filed in the area, the disposition note states both dimensions — *potential blast radius if the code runs* AND *current evidence the code is running*. If fired, the disposition cites the dormant-vs-live ordering implication.

---

## Item 5 — Latent-but-uncrystallized risk

### What to look for

Severity-relevant production state that lowered a finding's apparent risk. The bug exists; the data has not crystallized it yet. The audit's tendency when live data is clean is to drop severity — the honest reading is that the finding's underlying bug is unchanged; only the current evidence of impact is absent.

### `PIC-WORKED-EXAMPLE`

**Example (from the pilot)** — several audits found severity-relevant prod state that lowered a finding's apparent risk (full instances in the case study):

- **Area 2:** zero rows for PayPal forensic fingerprints (`Order.paypal_invoice_id IS NOT NULL`, webhook-attributed `BookingStatusLog`). PayPal integration findings dropped one rung accordingly.
- **Area 3:** zero rows for `RENEW_PAYMENT` and `CANCEL_BOOKING` magic links. The magic-link replay risk on those code paths is latent.
- **Area 4b-1:** the `material_type="slides"` enum collision in `edu_materials` — research-only and blog-only rows share the table, no `CHECK` constraint, and `material_type="slides"` is produced by both flows. Production is clean (no collision rows yet); the discriminated union (#95) was filed at the lower severity the clean data argued for.

### What would falsify it being general

If codebases with mature/high-traffic production never produce latent-but-uncrystallized findings (live data always crystallizes everything), the pattern is calibrated to the pilot's low-traffic state. If even high-traffic codebases produce findings whose impact is latent because the specific triggering state hasn't appeared, the pattern is structural — it tells the methodology that prod-state-as-severity-input is *always* a calibration risk that needs surfacing.

### How it's checked

**Start-of-area:** when the area's findings are likely to be severity-recalibrated by prod queries, the prompt's Production Data Access Policy (Slot 6) should signal that severities lowered by clean data must be flagged.

**End-of-area:** record disposition. If fired, the disposition cites the affected findings AND records the **"becomes live if state X appears"** flag — that bit rides with the issue forever, so a future remediation engineer who sees clean prod data does not silently re-drop the severity.

---

## A note for future readers

The six items above are calibrated to the pilot's domains, the pilot's authorship history, and the pilot's production-state characteristics. They are the v1 of the checklist; the next repos will refine the list (some items will be confirmed, some demoted, possibly new ones added). The point of v1 is not to be right about all six items — the point is to have a deliberately-small set grounded in real evidence that can be tested against the next codebases.

The discipline of running the checklist matters more than the checklist's content. Even if every item on a second codebase comes back "checked, absent," the methodology will have learned something real about the cross-codebase prevalence of these patterns.

When adopting this directory for a new repo, replace the `PIC-WORKED-EXAMPLE` blocks with that repo's equivalents. Keep the structure of "five hypotheses framed for falsification, plus the orchestrator's-prior framing item the others sit inside" intact, but never carry pilot content into a different codebase's audit.

## Cross-references

- **`../../skills/area-audit/SKILL.md`** — the skill surfaces this checklist at start-of-area (Slot 7 working-style) and enforces a closing gate at end-of-area (no area complete without dispositions).
- **`../../skills/area-audit/references/cross-cutting-checklist.md`** — the operational summary the skill reads; the document you are reading is authoritative.
- **`../../skills/area-audit/references/report-shape.md`** — defines the required **Cross-cutting checklist dispositions** sub-section every area report from a second codebase onward must include.
- **[conventions.md](./conventions.md)** — the gate-not-guideline meta-principle. This checklist is the second instance of that principle in the methodology (the first is the area-audit skill's fill-gate).
- The case study's synthesis §8 (the six items as hypotheses), §9 Artifact 4 (the spec this document fulfills), §10 (the falsifiability frame several items inherit).
